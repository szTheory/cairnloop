# Troubleshooting

Common setup, migration, and configuration issues when adopting Cairnloop, and how to
resolve them. Each section is grounded in the installer source and the example app.

## `mix cairnloop.install` Prerequisites

**Symptom:** Running `mix cairnloop.install` fails immediately or has no effect.

**Cause:** Cairnloop's installer is an [Igniter](https://hexdocs.pm/igniter) task
(`use Igniter.Mix.Task`). If Igniter is not present in your app's deps, Mix cannot
load the task.

**Fix:** Add `{:igniter, "~> 0.5"}` to your `mix.exs` deps and run `mix deps.get`
before running the installer.

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

**Fix:** Always run host-owned table migrations before library migrations. Pass both
`--migrations-path` flags to `ecto.migrate` in the correct order:

```bash
mix ecto.migrate \
  --migrations-path priv/my_app/migrations \
  --migrations-path priv/repo/migrations
```

Ecto merges and sorts by version timestamp, so host-owned tables (created first with
earlier timestamps such as `20260101…`) precede the library migrations, and the library's
foreign keys resolve.

The example app's `test.setup` alias follows exactly this pattern:

```elixir
# mix.exs  (the test.setup alias)
"test.setup": [
  "ecto.create --quiet -r Cairnloop.Repo -r Chimeway.Repo",
  "ecto.migrate --quiet --migrations-path priv/test_host/migrations --migrations-path priv/repo/migrations"
]
```

In production, adjust the paths to match your host app's migration directories and ensure
host tables run first.

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
