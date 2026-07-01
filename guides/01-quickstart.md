# Quickstart

Get from a fresh clone to a running Cairnloop operator dashboard in a few minutes.
This guide follows the example app at `examples/cairnloop_example/` as its reference.

## When not to use Cairnloop

- Cairnloop is not a hosted helpdesk; it embeds into a Phoenix app you operate.
- Cairnloop is not a replacement for host auth or authorization; your router and session code stay
  responsible for operator access.
- Cairnloop is not autonomous customer-visible support; use it for governed drafts, approvals, and
  host-owned workflows.
- Cairnloop is not a tenant-isolation layer; keep tenant boundaries in your own application model.
- Cairnloop is not a managed outbound campaign system; outbound delivery routes through your
  configured notifier and policies.

## Fastest path: Docker demo

If your goal is to click around the operator UI and understand the product, start here:

```bash
./bin/demo
```

That single command starts a private pgvector Postgres container, builds the example Phoenix app,
runs migrations, loads the realistic Trailmark seed data, waits for `/health`, and prints the URLs
you need next. Start with the demo index URL printed by `./bin/demo`:

- demo index (`/`)
- operator cockpit (`/support`)
- inbox (`/support/inbox`)
- customer chat (`/chat`)
- knowledge base, gaps, suggestions, audit log, settings, and health probe

The demo intentionally does **not** publish Postgres to your host machine. The app talks to `db:5432`
inside Docker, which avoids the common `5432` / `5433` conflicts when you run several OSS demos at
once. The browser-facing Phoenix port is published on `127.0.0.1` from a dynamic range
(`4100-4199`) and the wrapper prints the actual URL.

Useful commands:

```bash
./bin/demo          # start the Docker demo and print clickable URLs
./bin/demo start    # same as the default command
./bin/demo up       # alias for start
./bin/demo urls     # print URLs for the running stack
./bin/demo logs     # follow the web and db logs
./bin/demo status   # show Compose service status
./bin/demo ps       # alias for status
./bin/demo stop     # stop containers and preserve named volumes
./bin/demo down     # remove containers/network and preserve named volumes
./bin/demo reset    # remove volumes, rebuild, migrate, and reseed
./bin/demo smoke    # boot an isolated stack, check main routes, clean up
./bin/demo help     # show wrapper help
```

`stop` and `down` keep the seeded database volume for fast repeat launches. Use `reset` when you
want a clean database: it removes volumes, rebuilds the app image as needed, runs migrations, and
reseeds Trailmark data.

Prefer a fixed port for a screencast or bookmark?

```bash
CAIRNLOOP_WEB_PORT=4010 ./bin/demo
```

Working from multiple checkouts at once? The wrapper derives a Compose project name from the repo
path. You can still override it:

```bash
CAIRNLOOP_COMPOSE_PROJECT=cairnloop_demo_a ./bin/demo
```

## Prerequisites

- **Elixir 1.19+ / OTP 27+**
- **Postgres 16+** with the `pgvector` extension installed

You only need these prerequisites for the manual local workflow below. The Docker demo carries its
own Elixir runtime and pgvector Postgres.

The `pgvector` extension powers Cairnloop's Knowledge Base embeddings. If you want to run the app
with local Elixir but a containerized Postgres, the repository ships a root `docker-compose.yml` for
database-only workflows. The example app defaults to `PGPORT=5433`, so start the database like this
when you are using the manual path:

```bash
PGPORT=5433 docker compose up -d db
```

## Install

For a real host application, Cairnloop ships an [Igniter](https://hexdocs.pm/igniter) installer
that adds the dependency and generates the database migration for you. This is the production
host-app path; the Docker demo above remains the fastest evaluation path.

From the host app, run Igniter's package installer:

```bash
mix igniter.install cairnloop
```

The installer does two things:

1. Adds `{:cairnloop, "~> 0.5.1"}` to your `mix.exs` dependencies.
2. Detects your Ecto repo via `Igniter.Libs.Ecto.select_repo/1` and generates a
   `create_cairnloop_tables` migration that creates `cairnloop_conversations` and
   `cairnloop_messages` with the correct schema.

If Cairnloop is already in `mix.exs` and your deps are fetched, re-run the package task directly
with `mix cairnloop.install`.

Before running the app, configure Cairnloop with your repo:

```elixir
# config/config.exs
config :cairnloop, :repo, MyApp.Repo
config :cairnloop, :schema_prefix, "cairnloop"
```

New installs use the dedicated `cairnloop` Postgres schema by default. If you are upgrading an
existing app that already has `public.cairnloop_*` tables, pin explicit public compatibility while
you plan the migration steps in `UPGRADING.md`:

```elixir
config :cairnloop, :schema_prefix, "public"
```

If no Ecto repo is found, the installer emits:

```
No Ecto repo found. Please create a migration manually for cairnloop tables.
```

In that case, create a `priv/repo/migrations/<timestamp>_create_cairnloop_tables.exs`
migration by hand before running `mix ecto.migrate`.

### Run migrations

After the installer has run, apply both your host app's migrations and the Cairnloop
library's own migrations:

```bash
# Run host migrations (generated by the installer or written by hand)
mix ecto.migrate

# Run the Cairnloop library's own migrations
mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations
```

The library ships 15+ additional migrations (knowledge base, retrieval corpus, gap
candidates, article suggestions, outbound, and more) that `mix ecto.migrate` alone will
not apply. Skipping this second command will cause `Postgrex.Error` relation-not-found
errors the first time any non-chat feature is exercised.

Do not add the broad `--prefix cairnloop` shortcut to the dependency migration command. Cairnloop
migrations read `:schema_prefix` and qualify their own tables in source; the CLI prefix flag can
move migrator bookkeeping and still will not fix raw SQL, triggers, or generated host DDL.

> **Tip:** Add both commands to your `ecto.setup` alias in `mix.exs` so they always run
> together:
>
> ```elixir
> reenable_migrate = fn _ -> Mix.Task.reenable("ecto.migrate") end
>
> "ecto.setup": [
>   "ecto.create",
>   "ecto.migrate",
>   reenable_migrate,
>   "ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations",
>   "run priv/repo/seeds.exs"
> ]
> ```

### Manual install (without Igniter)

If you prefer not to use Igniter for host-app setup, add Cairnloop to your deps directly:

```elixir
# mix.exs
def deps do
  [
    {:cairnloop, "~> 0.5.1"}
  ]
end
```

Then create the `create_cairnloop_tables` migration manually.

## Mount the Dashboard

Import the `cairnloop_dashboard/2` macro and mount it under a scope in your router.
The example app uses `/support`:

```elixir
# lib/my_app_web/router.ex
import Cairnloop.Router, only: [cairnloop_dashboard: 2]

scope "/support", MyAppWeb do
  pipe_through [:browser, :require_admin]

  cairnloop_dashboard "/",
    on_mount: [{MyAppWeb.UserAuth, :ensure_admin}],
    session: {MyAppWeb.UserAuth, :cairnloop_session, []}
end
```

Static session maps such as `%{"host_user_id" => "demo_operator"}` are demo-only. In production,
use the MFA tuple above so Phoenix builds `host_user_id` from the current request.

The `cairnloop_dashboard/2` macro mounts routes under whatever path you pass as its
first argument. With the `/support` scope above:

- **Cockpit Home** (the task-oriented landing) is at `/support`
- **Inbox** is at `/support/inbox`
- **A conversation** is at `/support/:id`
- **Knowledge Base** is at `/support/knowledge-base`
- **Settings** is at `/support/settings`

This guide assumes `/support` as in the example app. Adjust paths to match your own
scope if you mount elsewhere.

> **Route convention:** Always use the path you pass to `cairnloop_dashboard/2`.
> The internal integration-test routes (not the shipped macro routes) will 404 for adopters.

## Styling

Cairnloop ships a self-contained, themeable stylesheet in the package at
`priv/static/cairnloop.css`. It defines the design tokens (`--cl-*`) and the `.cl-*`
component classes the dashboard renders — no Tailwind or daisyUI required in your app.
Include it once.

If you bundle CSS (esbuild/Tailwind), import it from your own stylesheet:

```css
@import "../../deps/cairnloop/priv/static/cairnloop.css";
```

Or serve the packaged asset directly and link it from your root layout:

```elixir
# endpoint.ex
plug Plug.Static, at: "/cairnloop", from: {:cairnloop, "priv/static"}, only: ["cairnloop.css"]
```

```html
<link rel="stylesheet" href="/cairnloop/cairnloop.css" />
```

**Theming:** override any `--cl-*` token in CSS loaded *after* `cairnloop.css` to re-skin
the dashboard to your brand, and toggle dark mode by setting `data-theme="dark"` on `<html>`.

## Manual boot

The commands below are for the example app when you want to run Elixir directly on your machine.
Switch into it first, then set up the database and start the server:

```bash
cd examples/cairnloop_example
mix setup
mix phx.server
```

Then visit [http://localhost:4000](http://localhost:4000) for the guided demo index — it frames
the Trailmark scenario and links to every stage of the [JTBD Walkthrough](02-jtbd-walkthrough.html).
Or jump straight to the operator inbox at
[http://localhost:4000/support](http://localhost:4000/support).

You should see the Cairnloop operator inbox. The example app's seed places 20 conversations across
all lifecycle states — including ones pre-positioned in each JTBD state — so every screen is live
and clickable immediately.

> **Port already in use?** Start the server with a different port: `PORT=4010 mix phx.server`
> (and set `PGPORT` if your Postgres isn't on 5433). The example honors both.

## Docker troubleshooting

**Another project is already using the port.** Run `./bin/demo` normally and use the printed URL.
The default Docker path chooses from `4100-4199`. For a fixed port, set `CAIRNLOOP_WEB_PORT`.

**You want to inspect Postgres from the host.** The demo does not publish Postgres by default. Use
`./bin/demo logs` first; if you need `psql`, add a temporary Compose override rather than changing
the default demo path.

**You want a clean demo state.** Use `./bin/demo reset`. `./bin/demo stop` and `./bin/demo down`
preserve named volumes so repeat launches stay fast.

**You run a local proxy such as Traefik or Caddy.** Keep it as an advanced local setup. The default
demo avoids Docker socket access and global `80` / `443` ownership so first run stays predictable.

## Next Steps

- **[JTBD Walkthrough](02-jtbd-walkthrough.html)** — walk the full Jobs-To-Be-Done
  lifecycle in the seeded example: inbox → conversation workspace → cmd+k search →
  AI draft approval → governed tool approval → resolve → outbound trigger → bulk recovery.
- **[Host Integration](03-host-integration.html)** — implement the four host behaviour
  contracts (`ContextProvider`, `Notifier`, `AutomationPolicy`, `SLAPolicyProvider`)
  so Cairnloop knows your app's context and policy.
- **[Auth & Operator Identity](07-auth-and-operator-identity.html)** — wire your real
  authenticated operator into the dashboard so the audit log attributes actions correctly.
  **Read this before going past the demo** — the hardcoded `host_user_id` shown in quickstarts
  is a trap in production.
- **[Troubleshooting](04-troubleshooting.html)** — recover from Docker demo failures, pgvector
  versus manual Postgres confusion, reset/log flows, install errors, migrations, and mount-config
  issues.
