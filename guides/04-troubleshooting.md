# Troubleshooting

Common setup, migration, and configuration issues when adopting Cairnloop, and how to
resolve them. Each section is grounded in the installer source and the example app.

## Docker Demo

Start here when `./bin/demo` fails or the printed demo URL does not behave as expected. The demo
wrapper is the supported diagnostic surface; use `./bin/demo logs`, `./bin/demo status`,
`./bin/demo reset`, the failing route URL, and `/health` before digging into raw Compose internals
or sharing long command output.

### Docker is not installed or not on PATH

**Symptom:** `./bin/demo` exits with:

```
Docker is not installed or not on PATH.
```

**Cause:** The Docker demo needs Docker available on your shell `PATH`. It does not need local
Elixir, local Postgres, or local pgvector.

**Fix:** Install or start Docker Desktop, or install a Docker engine that exposes the `docker`
command. Then retry:

```bash
./bin/demo
```

### Docker Compose v2 is missing

**Symptom:** `./bin/demo` exits with:

```
Docker Compose v2 is required. Install Docker Desktop or the Compose plugin.
```

**Cause:** The wrapper calls `docker compose`, not the legacy `docker-compose` binary.

**Fix:** Install Docker Desktop or the Compose v2 plugin, then confirm the wrapper command surface:

```bash
./bin/demo help
```

### No available localhost port

**Symptom:** Startup reports a port conflict, a fixed `CAIRNLOOP_WEB_PORT` fails, or the wrapper
cannot find an available port in the default range.

**Cause:** The Docker demo publishes Phoenix on `127.0.0.1` and defaults to the
`4100-4199` range. If every port in that range is occupied, or if a fixed port is already owned by
another process, Compose cannot publish the web service.

**Fix:** Run `./bin/demo status` to see whether a previous demo stack is still running. Use
`./bin/demo stop` or `./bin/demo down` if you want to stop it while keeping the seeded database.
For a specific free port, set:

```bash
CAIRNLOOP_WEB_PORT=4010 ./bin/demo
```

Open the URL printed by the wrapper, not a guessed `localhost:4000` URL.

### The stack never becomes healthy

**Symptom:** Startup waits on `/health`, exits nonzero, or a printed route does not load.

**Cause:** The web service did not become ready after Compose started, or one of the mounted demo
routes is returning an error.

**Fix:** Check the bounded wrapper diagnostics first:

```bash
./bin/demo status
./bin/demo logs
```

Visit the printed health URL ending in `/health`. If one browser route fails, keep the failing route
URL handy and inspect the recent web logs from `./bin/demo logs`. The wrapper already prints recent
web logs on health and smoke failures, so you usually do not need to collect long Compose output.

### I need a clean seeded demo

**Symptom:** Demo data looks stale, a previous experiment changed the Trailmark state, or you want
to replay the first-run path from scratch.

**Cause:** `./bin/demo stop` and `./bin/demo down` preserve named volumes so repeat launches stay
fast. That also preserves the seeded Postgres database.

**Fix:** Use reset when you intentionally want to remove volumes and reseed:

```bash
./bin/demo reset
```

`reset` removes the demo containers, network, and volumes, then rebuilds, migrates, and reseeds the
Trailmark demo.

### Do I need local Postgres or pgvector?

**Symptom:** You are unsure whether to install Postgres 16 or the `pgvector` extension before trying
the demo.

**Cause:** Cairnloop has two local paths:

- The Docker demo keeps pgvector Postgres private inside Compose. It uses the
  `pgvector/pgvector:pg16` image, does not publish Postgres to your host, and needs no host
  Postgres setup.
- The manual local Phoenix path uses your machine's Elixir runtime and needs Postgres 16 plus
  pgvector. If you want a containerized database for that manual path, use the repository root
  database helper described in the Quickstart.

**Fix:** For first-run evaluation, prefer:

```bash
./bin/demo
```

Only install or start a manual local Postgres 16 plus pgvector database when you are running
`mix setup && mix phx.server` directly.

### Do I need `OPENAI_API_KEY`?

**Symptom:** You do not have an OpenAI key and want to know whether the demo can still boot.

**Cause:** `OPENAI_API_KEY` is optional for the Docker demo. It is not required for first-run boot,
route smoke, or clicking through the seeded Trailmark workflow.

**Fix:** Run the demo without credentials:

```bash
./bin/demo
```

Provider configuration can still matter for production host-app AI drafting, retrieval, or
embedding behavior. The credential-free claim is scoped to local demo boot, `./bin/demo smoke`, and
seeded click-through.

### `./bin/demo smoke` reports a route failure

**Symptom:** `./bin/demo smoke` exits nonzero and names a failing route.

**Cause:** Smoke boots an isolated Compose project, waits for `/health`, checks the locked local HTTP
route list, and cleans up its containers and volumes afterward. It is not a browser E2E suite and it
does not replace the CI workflow wiring planned separately for demo smoke.

**Fix:** Use the failing route URL and recent web logs printed by the wrapper. The smoke route list
is:

- `/`
- `/support`
- `/support/inbox`
- `/chat`
- `/support/knowledge-base`
- `/support/knowledge-base/gaps`
- `/support/knowledge-base/suggestions`
- `/support/audit-log`
- `/support/settings`

If a normal demo stack is already running, `./bin/demo smoke` uses an isolated project name and its
own cleanup path, so inspect the smoke output first, then use `./bin/demo status` and
`./bin/demo logs` for the ordinary stack if needed.

## `mix cairnloop.install` Prerequisites

**Symptom:** Running a Cairnloop installer command fails immediately or has no effect.

**Cause:** Fresh host apps cannot load `mix cairnloop.install` until Cairnloop itself is already
available. Use Igniter's package installer for first-time setup; it adds Cairnloop and then invokes
the package installer.

**Fix:** For first-time setup, run:

```bash
mix igniter.install cairnloop
```

If Cairnloop is already in `mix.exs` and `mix deps.get` has fetched it, you can re-run the package
task directly:

```bash
mix cairnloop.install
```

## Operational Trust Diagnostics

Run `mix cairnloop.doctor` when a production setup compiles but trust-sensitive Cairnloop surfaces
are blocked or unclear. Doctor separates likely failure domains:

| Finding area | Likely failure domain | What to check |
|---|---|---|
| Repo or schema access | DB state | Confirm the host repo config, migrations, and pgvector extension before debugging LiveView state. |
| Dashboard or operations routes | Cairnloop wiring | Confirm `cairnloop_dashboard/2` and `cairnloop_operations/1` are mounted in the host router. |
| Background work | Oban | Confirm the host owns and starts Oban before relying on queued jobs. |
| Notifier or Scrypath | external dependency | Confirm host callback modules and external credentials outside Cairnloop before retrying side effects. |
| Widget, email, MCP auth | host config | Confirm the host configured the explicit auth seam before accepting inbound traffic. |

`/health` is liveness only. It confirms the app can answer HTTP; it does not prove DB state, Oban,
pgvector, notifier, ingress, MCP, or Scrypath readiness.

### Widget ingress is blocked

**Symptom:** Browser widget sessions cannot join or doctor reports:

```
Widget ingress is blocked because no host verifier is configured.
```

**Cause:** Cairnloop no longer accepts arbitrary browser tokens by default. Production widget
ingress requires a host-owned verifier configured at `:widget_token_verifier`.

**Fix:** Configure a verifier module or `{module, opts}` pair that returns a customer reference for
valid customer/session tokens. The demo verifier is suitable only when explicitly configured for
demo or test hosts.

### Email webhook ingress is blocked

**Symptom:** Email webhook requests return unauthorized or doctor reports:

```
Email webhook ingress is blocked until the host configures request authentication.
```

**Cause:** Cairnloop authenticates email webhook requests before body parsing and before enqueue.
With no `:email_webhook_verifier` or `:email_webhook_token`, the request is rejected.

**Fix:** Configure a host verifier callback or a shared token. Do not paste raw webhook payloads,
provider secrets, or customer message bodies into shared debugging channels.

### MCP request blocked

**Symptom:** MCP clients receive HTTP 401 before `initialize`, `tools/list`, or `tools/call`.

**Cause:** MCP request blocked. Provide a valid Bearer token before Cairnloop lists tools or accepts
tool calls.

**Fix:** Generate a raw MCP token in Settings, copy it once, and configure the client with an
`Authorization: Bearer ...` header. Public well-known metadata can remain discoverable, but JSON-RPC
capability and tool methods require the token.

### Scrypath automation is disabled

**Symptom:** Resolved conversations do not enqueue Scrypath indexing.

**Cause:** Scrypath automation is disabled. Resolved conversations will stay inside Cairnloop unless
the host opts in.

**Fix:** No action is needed unless you intentionally want external indexing. This is the safe
default.

### Scrypath automation is enabled but not ready

**Symptom:** Doctor reports Scrypath as blocked, or worker jobs discard without contacting Scrypath.

**Cause:** Scrypath automation is enabled but not ready. The host enabled the side effect without a
real API URL and key, so Cairnloop will not enqueue external indexing.

**Fix:** Add real Scrypath configuration in host config and rerun doctor. Doctor reports the reason
without printing the URL or API key.

### Bounded telemetry defaults

Default telemetry is bounded. Cairnloop reports event names, durations, outcomes, and durable
pointers such as `conversation_id`, not customer message bodies, secrets, raw payloads, full
conversation structs, or actor/customer IDs. If a debugging session needs richer data, collect it in
a bounded host-owned diagnostic path and scrub it before sharing.

### No Ecto Repo Found

**Symptom:** The installer runs but prints an issue message similar to:

```
No Ecto repo found. Please create a migration manually for cairnloop tables.
```

**Cause:** The installer calls `Igniter.Libs.Ecto.select_repo/1` to detect your
application's Ecto repo. If no repo is found (e.g. your app does not yet have one, or
Igniter cannot detect it automatically), the installer cannot generate the migration for
you.

**Fix:** Either:

1. Ensure your application has a properly configured Ecto repo (generated via
   `mix ecto.gen.repo`).
2. Or create the `create_cairnloop_tables` migration by hand in
   `priv/repo/migrations/<timestamp>_create_cairnloop_tables.exs` with the
   `cairnloop_conversations` and `cairnloop_messages` tables. See the library source for
   the exact schema.

## Migration Order: Host Tables Before Library Tables

**Symptom:** `mix ecto.migrate` (or `mix test.setup`) fails with a foreign-key error,
such as a reference to `cairnloop_conversations` that does not yet exist.

**Cause:** Cairnloop's library migrations create foreign keys back to host-owned tables
(e.g. `cairnloop_conversations`). If the library migrations run before the host-owned
migrations, those references fail.

**Fix:** Always run host-owned table migrations before library migrations. Run them as
two ordered `ecto.migrate` calls:

```bash
mix ecto.migrate
mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations
```

New installs should run those commands with `config :cairnloop, :schema_prefix, "cairnloop"`.
Existing public-schema installs should pin explicit compatibility with
`config :cairnloop, :schema_prefix, "public"` while planning a data migration.

Do not add the broad `--prefix cairnloop` shortcut to the dependency migration command. Cairnloop
migrations read `:schema_prefix` and qualify their own tables in source; the CLI prefix flag can
move migrator bookkeeping and still will not fix raw SQL, triggers, or generated host DDL.

Do not pass both migration paths to one `ecto.migrate` call. Ecto merges and sorts all
configured paths by version timestamp, which can run a library migration before its
host-owned table dependency.

If both commands live in one Mix alias, re-enable `ecto.migrate` between phases because Mix
tasks run once per invocation:

```elixir
reenable_migrate = fn _ -> Mix.Task.reenable("ecto.migrate") end

"ecto.setup": [
  "ecto.create",
  "ecto.migrate",
  reenable_migrate,
  "ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations"
]
```

In production, adjust the path to match your dependency layout and ensure host tables run
first.

## pgvector: Missing Postgres Extension

**Symptom:** Migrations or Knowledge Base embedding operations fail with an error
referencing an unknown type `vector`, such as:

```
** (Postgrex.Error) ERROR 42704 (undefined_object) type "vector" does not exist
```

**Cause:** Cairnloop's Knowledge Base requires Postgres 16+ with the `pgvector` extension
installed. The `vector` column type (used for embedding storage) is provided by `pgvector`
and must be present in the database before the relevant migrations run.

**Fix:**

1. Verify your Postgres version is 16 or higher.
2. Install the `pgvector` extension in Postgres. For local development with Docker, the
   example app ships a `docker-compose.yml` that starts a pgvector-enabled Postgres:

   ```bash
   # from the repo root
   docker compose up -d db
   ```

3. Enable the extension in your database:

   ```sql
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

4. If using the example app's migrations, a migration for the `vector` extension is
   already included — run `mix ecto.migrate` (or `mix setup`) after the database is up.

## Common Mount Configuration Errors

**Symptom:** The Cairnloop dashboard mounts but AI drafting, retrieval, or outbound
delivery does not work. Console logs may show errors like "no context provider configured"
or function-clause errors on callbacks.

**Cause:** Cairnloop relies on four host-provided behaviour implementations. If these are
not configured, the corresponding features fail closed. The most common missing configs are:

| Config key | Behaviour | Required for |
|---|---|---|
| `:context_provider` | `Cairnloop.ContextProvider` | AI context snippets |
| `:notifier` | `Cairnloop.Notifier` | Outbound delivery callbacks |
| `:automation_policy` | `Cairnloop.AutomationPolicy` | AI drafting policy |
| `:sla_policy_provider` | `Cairnloop.SLAPolicyProvider` | SLA escalation rules |

**Fix:** Add the missing config entries in `config/config.exs` (or `config/runtime.exs`):

```elixir
config :cairnloop, :context_provider, MyApp.CairnloopContext
config :cairnloop, :notifier, MyApp.CairnloopNotifier
config :cairnloop, :automation_policy, MyApp.CairnloopPolicy
config :cairnloop, :sla_policy_provider, MyApp.CairnloopSLA
```

Each value must be a module that implements the corresponding behaviour. See the
[Host Integration guide](03-host-integration.html) for minimal working implementations
of all four.

Cairnloop also ships a generator for the Notifier:

```bash
mix cairnloop.gen.notifier
```

This scaffolds `MyApp.CairnloopNotifier` and injects the `:notifier` config line.

## `ChunkRevision` Oban Worker: Embeddings Are Asynchronous

**Symptom:** After seeding the Knowledge Base (e.g. running `mix run priv/repo/seeds.exs`),
cmd+k search returns empty or partial results even though articles are visible in the KB
index.

**Cause:** Cairnloop's Knowledge Base embeddings are generated asynchronously by the
`ChunkRevision` Oban worker. When articles or revisions are created, the worker is
enqueued — but it does not run inline. Depending on your Oban configuration and system
load, the queue may take several seconds to drain.

**Fix:** Wait for the Oban queue to drain before testing retrieval. In a local dev
environment, you can monitor the queue in `iex -S mix phx.server`:

```elixir
Oban.drain_queue(queue: :default)
```

Or simply wait a few seconds after seeding and refresh the search. Once the
`ChunkRevision` jobs complete, embeddings are stored and retrieval returns results.

## EditorHandoff Token Key

**Symptom:** Clicking "Open for manual edit" in the KB suggestions list crashes with a
500 error in dev, or the app fails to start in production with `RuntimeError: ...secret_key_base`.

**Cause:** the Cairnloop.KnowledgeAutomation.EditorHandoff module requires a `secret_key_base` in
application config. In the `:test` environment a persistent_term fallback is used; all other
environments require explicit config.

**Fix:** Add the config key. For local development, add this to `config/dev.exs`:

```elixir
config :cairnloop, Cairnloop.KnowledgeAutomation.EditorHandoff,
  secret_key_base: "dev_only_64_byte_minimum_secret_for_editor_handoff_tokens_cairnloop"
```

For production, use an environment variable in `config/runtime.exs`:

```elixir
config :cairnloop, Cairnloop.KnowledgeAutomation.EditorHandoff,
  secret_key_base: System.fetch_env!("CAIRNLOOP_HANDOFF_SECRET_KEY_BASE")
```

---

For host behaviour implementation details, see the
[Host Integration guide](03-host-integration.html).
