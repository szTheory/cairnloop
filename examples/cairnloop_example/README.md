# Cairnloop Example Application

This is an example host application demonstrating how to embed **Cairnloop** into an existing Phoenix application.

Cairnloop turns support conversations into answers, product signals, knowledge-base improvements, and safe automated actions—directly inside your existing monolith. 

**Support that leaves a trail.**

## Requirements

The Docker demo has no local Elixir or Postgres requirement beyond Docker Desktop / Docker Compose
v2. Manual local setup needs:

1. Elixir 1.19+ / OTP 27+
2. Postgres 16+ with `pgvector` extension installed.

## Setup

### Docker demo

From the repository root:

```bash
./bin/demo
```

The command builds the example app, starts a private pgvector Postgres service, runs migrations,
loads the realistic Trailmark seed data, waits for the health probe, and prints the exact URLs to
open.

The default Docker path publishes only the Phoenix UI on `127.0.0.1` using a dynamic port range, so
it can run next to other local admin UI demos without colliding on `4000`, `5432`, or `5433`.

Useful commands:

```bash
./bin/demo
./bin/demo start
./bin/demo up
./bin/demo urls
./bin/demo logs
./bin/demo status
./bin/demo ps
./bin/demo stop
./bin/demo down
./bin/demo reset
./bin/demo smoke
./bin/demo help
```

`start` and `up` build or start the Docker demo and print the clickable URLs. `urls` prints the
current URLs for an already-running demo. `logs` follows the web and database logs. `status` and
`ps` show Compose service status.

`stop` stops containers and preserves named volumes. `down` removes the containers and network but
also preserves named volumes. `reset` removes containers, network, and volumes, then rebuilds and
reseeds the Trailmark demo from scratch.

`./bin/demo smoke` boots a local isolated stack, waits for health, checks the main HTTP routes,
reports the failing route plus recent web logs on errors, and cleans up its containers and volumes
when it exits. It is an HTTP route smoke, not a browser E2E suite.

### Manual local setup

To start the demo app directly on your machine:

1. Setup the project dependencies and database:

   ```bash
   # Make sure your database has pgvector installed.
   # You can run `PGPORT=5433 docker compose up -d db` from the parent repository if you need one.
   mix setup
   ```

2. Start the Phoenix endpoint:

   ```bash
   mix phx.server
   ```

The example dogfoods `schema_prefix: "cairnloop"` so new installs create Cairnloop support tables
in the dedicated `cairnloop` Postgres schema:

```elixir
config :cairnloop, :schema_prefix, "cairnloop"
```

Existing public-schema adopters can set `schema_prefix: "public"` as an intentional existing-install compatibility switch while planning a data migration:

```elixir
config :cairnloop, :schema_prefix, "public"
```

## Demo Index

With Docker, start at the demo index URL printed by `./bin/demo`. With the manual local Phoenix
path after `mix setup && mix phx.server`, start at **http://localhost:4000**. The index frames the
Trailmark scenario (a small dev-tools SaaS support desk) and links to every stage of the JTBD
lifecycle. The seed places 20 conversations across all lifecycle states — including four
pre-positioned in specific JTBD states (a pending AI draft, an action awaiting approval, an executed
action, and an outbound follow-up) — so every screen is live and clickable with no setup.

> **Port in use?** `PORT=4010 mix phx.server` (and `PGPORT=...` if Postgres isn't on 5433).

## Two-Tab Demo

Run `./bin/demo` from the repository root, then open two browser tabs from the printed base URL:

- **Tab 1 — Operator inbox:** printed base URL plus `/support`
- **Tab 2 — Customer chat:** printed base URL plus `/chat`

Type a message in the customer chat tab. The message enters Cairnloop through the real customer
chat ingress and lands in the operator inbox as a new conversation. Open the conversation and reply.
The reply appears in the customer chat tab.

For the manual local Phoenix path, run `mix setup && mix phx.server` in the
`examples/cairnloop_example/` directory, then use **http://localhost:4000/support** and
**http://localhost:4000/chat**.

## Screenshots

The PNGs in the library's `guides/` (the JTBD walkthrough) are captured from this app's seeded
state by the Playwright tool in [`screenshots/`](screenshots/). To refresh them:

```bash
mix ecto.reset && mix phx.server          # boot the seeded demo
cd screenshots && npm install && npm run capture
```

The capture is **non-gating** — it asserts nothing and is not part of CI. The deterministic
`test/integration/golden_path_test.exs` (`Phoenix.LiveViewTest`) remains the source of CI truth.

## Browser E2E port

`mix test.e2e` starts the test endpoint on `127.0.0.1:4002` by default. If another local demo is
using that port, choose a free one:

```bash
PHX_TEST_PORT=4102 mix test.e2e
```

## Included Integrations

This example app includes:

1. **Oban**: `mix oban.install` has been run and Oban is configured in `config.exs`.
2. **pgvector**: A migration exists to add the `vector` extension, enabling Cairnloop's Knowledge Base embeddings.
3. **Cairnloop Core**: `mix cairnloop.install` and `mix cairnloop.add_draft_table` have been run.
4. **Cairnloop Dashboard**: Mounted at `/support` for Operator access.
5. **Customer Chat (real ingress):** A `/chat` LiveView wired to `Cairnloop.Channels.WidgetSocket` so customer messages flow into the operator inbox in real time.

## Routing

Cairnloop's dashboard is mounted in `lib/cairnloop_example_web/router.ex`:

```elixir
require Cairnloop.Router

scope "/" do
  pipe_through :browser

  Cairnloop.Router.cairnloop_dashboard("/support",
    session: {CairnloopExampleWeb.OperatorAuth, :cairnloop_session, []}
  )
end
```

With Docker, use the printed base URL from `./bin/demo` plus `/support` to view the operator
interface and `/chat` to use the real customer chat ingress. With the manual local Phoenix path
after `mix setup && mix phx.server`, use **http://localhost:4000/support** and
**http://localhost:4000/chat**.

The Docker smoke and printed URL block cover these mounted demo routes:

- `/` — Demo index
- `/support` — Operator cockpit
- `/support/inbox` — Inbox
- `/chat` — Customer chat
- `/support/knowledge-base` — Knowledge Base
- `/support/knowledge-base/gaps` — Gaps
- `/support/knowledge-base/suggestions` — Suggestions
- `/support/audit-log` — Audit log
- `/support/settings` — Settings
