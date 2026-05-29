# Quickstart

Get from a fresh clone to a running Cairnloop operator dashboard in a few minutes.
This guide follows the example app at `examples/cairnloop_example/` as its reference.

## Prerequisites

- **Elixir 1.15+ / OTP 26+**
- **Postgres 16+** with the `pgvector` extension installed

The `pgvector` extension powers Cairnloop's Knowledge Base embeddings. If you need a
containerized Postgres with pgvector, the example app ships a `docker-compose.yml`:

```bash
docker compose up -d db
```

## Install

Cairnloop ships an [Igniter](https://hexdocs.pm/igniter) installer that adds the
dependency and generates the database migration for you.

First, fetch deps:

```bash
mix deps.get
```

Then run the installer:

```bash
mix cairnloop.install
```

The installer does two things:

1. Adds `{:cairnloop, "~> 0.1.0"}` to your `mix.exs` dependencies.
2. Detects your Ecto repo via `Igniter.Libs.Ecto.select_repo/1` and generates a
   `create_cairnloop_tables` migration that creates `cairnloop_conversations` and
   `cairnloop_messages` with the correct schema.

If no Ecto repo is found, the installer emits:

```
No Ecto repo found. Please create a migration manually for cairnloop tables.
```

In that case, create a `priv/repo/migrations/<timestamp>_create_cairnloop_tables.exs`
migration by hand before running `mix ecto.migrate`.

### Manual install (without Igniter)

If you prefer not to use Igniter, add Cairnloop to your deps directly:

```elixir
# mix.exs
def deps do
  [
    {:cairnloop, "~> 0.1.0"}
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
  pipe_through :browser

  cairnloop_dashboard("/", session: %{"host_user_id" => "demo_operator"})
end
```

The `cairnloop_dashboard/2` macro mounts routes under whatever path you pass as its
first argument. With the `/support` scope above:

- **Inbox** is at `/support`
- **A conversation** is at `/support/:id`
- **Knowledge Base** is at `/support/knowledge-base`
- **Settings** is at `/support/settings`

This guide assumes `/support` as in the example app. Adjust paths to match your own
scope if you mount elsewhere.

> **Route convention:** Always use the path you pass to `cairnloop_dashboard/2`.
> The internal integration-test routes (not the shipped macro routes) will 404 for adopters.

## Boot

Set up the database and start the server:

```bash
mix setup
mix phx.server
```

Then visit [http://localhost:4000/support](http://localhost:4000/support).

You should see the Cairnloop operator inbox. If you have the example app's seeded
fixtures, 12–16 conversations across all lifecycle states are already there.

## Next Steps

- **[JTBD Walkthrough](02-jtbd-walkthrough.html)** — walk the full Jobs-To-Be-Done
  lifecycle in the seeded example: inbox → conversation workspace → cmd+k search →
  AI draft approval → governed tool approval → resolve → outbound trigger → bulk recovery.
- **[Host Integration](03-host-integration.html)** — implement the four host behaviour
  contracts (`ContextProvider`, `Notifier`, `AutomationPolicy`, `SLAPolicyProvider`)
  so Cairnloop knows your app's context and policy.
- **[Troubleshooting](04-troubleshooting.html)** — resolve common install, migration,
  pgvector, and mount-config errors.
