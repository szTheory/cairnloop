<img src="logo/cairnloop-lockup-horizontal.svg" alt="Cairnloop" width="260">

[![Hex.pm Version](https://img.shields.io/hexpm/v/cairnloop.svg)](https://hex.pm/packages/cairnloop)
[![HexDocs](https://img.shields.io/badge/hexdocs-online-blue.svg)](https://hexdocs.pm/cairnloop)
[![GitHub Actions CI](https://github.com/szTheory/cairnloop/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/cairnloop/actions)

An embedded, Phoenix-native customer support automation layer for Elixir applications.

## What Cairnloop Is For

Cairnloop belongs inside a Phoenix app that already owns customers, operators, authorization,
Postgres, Oban, and deployment. Use it when you want support conversations, AI-assisted drafts,
knowledge-base maintenance, governed tool proposals, audit history, and outbound follow-up to stay
in your app instead of syncing through a separate helpdesk service.

## When not to use Cairnloop

- Cairnloop is not a hosted helpdesk; you run it inside your Phoenix application.
- Cairnloop is not a replacement for host auth or authorization; protect routes and inject
  operator identity from your own app.
- Cairnloop is not autonomous customer-visible support; keep AI replies and governed actions behind
  your operators and policies.
- Cairnloop is not a tenant-isolation layer; design tenant boundaries in your own app and database.
- Cairnloop is not a managed outbound campaign system; outbound follow-up stays host-owned and
  routed through your configured notifier.

## Installation

### Try the live demo first

From a fresh clone, the fastest way to see Cairnloop working is the Docker demo:

```bash
./bin/demo
```

The command starts the example Phoenix app, a private pgvector Postgres container, migrations, and
the realistic Trailmark seed data. Start with the demo index URL printed by `./bin/demo`; it also
prints the exact local URLs to click: the demo index,
operator cockpit, inbox, customer chat, knowledge base, audit log, settings, and health probe.

The demo publishes only the Phoenix UI on `127.0.0.1` and uses a dynamic port range by default, so
it can run alongside other local Dockerized UI demos without fighting over `4000`, `5432`, or
`5433`. Use `./bin/demo reset` when you want a clean reseeded database, and `./bin/demo smoke` to
boot an isolated stack and verify the main demo routes end to end.

### Install in your app

After you have tried the Docker demo, use this host-app path to install Cairnloop in a Phoenix
application. The fastest host-app install uses Igniter's package installer:

```bash
mix igniter.install cairnloop
```

The installer adds `{:cairnloop, "~> 0.5.1"}` to your `mix.exs` deps and generates a
`create_cairnloop_tables` migration against your detected Ecto repo.

If Cairnloop is already in `mix.exs` and your deps are fetched, you can re-run Cairnloop's package
task directly with `mix cairnloop.install`.

After the installer runs, configure Cairnloop with your repo and run both host and dependency
migrations:

```elixir
config :cairnloop, :repo, MyApp.Repo
config :cairnloop, :schema_prefix, "cairnloop"
```

New installs use the dedicated `cairnloop` Postgres schema. Existing public-schema installs should
pin explicit public compatibility while following [UPGRADING.md](UPGRADING.md):

```elixir
config :cairnloop, :schema_prefix, "public"
```

```bash
mix ecto.migrate
mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations
mix cairnloop.doctor
```

Inside this repository, `examples/cairnloop_example/mix.exs` dogfoods local source with
`{:cairnloop, path: "../.."}`. Adopter apps should use the Hex dependency form above.

### Manual install (without Igniter)

For manual host-app setup, add Cairnloop to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:cairnloop, "~> 0.5.1"}
  ]
end
```

Then run `mix deps.get` and generate the migration manually (see the quickstart guide for the
migration contents).

Configure the host repo and schema prefix:

```elixir
config :cairnloop, :repo, MyApp.Repo
config :cairnloop, :schema_prefix, "cairnloop"
```

New installs use the dedicated `cairnloop` Postgres schema so Cairnloop tables do not pollute the
host app's `public` namespace. Existing public-schema installs should pin
`config :cairnloop, :schema_prefix, "public"` while following [UPGRADING.md](UPGRADING.md).

## Why Cairnloop?

- **Host-owned support truth.** Conversations, drafts, governed actions, and outbound follow-ups
  all live in your Postgres database — no external CRM sync required.
- **Safe automation by default.** The AI drafts; your operators approve. Every proposed action
  passes through a durable approval state machine before execution.
- **KB substrate built in.** Hybrid pgvector + full-text retrieval keeps AI answers grounded in
  your published knowledge base, not hallucinated context.
- **Additive, not invasive.** Cairnloop is a library embedded in your existing Phoenix monolith.
  No separate service, no separate deploy.
- **Observable without lock-in.** Bounded `:telemetry` spans on every meaningful operation.
  Export to any APM; your app stays in control.

## What it does

Cairnloop turns support conversations into answers, product signals, knowledge-base improvements,
and safe automated actions — all inside your existing Phoenix app. Incoming messages route through
Phoenix Channels to a durable Ecto-backed conversation record. An Oban worker drafts an
AI-grounded reply using your published KB and offers it to the operator for approval. Resolved
conversations feed back into the KB maintenance queue through a governed review workflow, and
support-triggered outbound follow-ups route durably through a configurable Notifier behaviour.

## Explore the guides

- [Quickstart](https://hexdocs.pm/cairnloop/01-quickstart.html) — Start with the Docker demo,
  then use the manual install path when you are ready to wire Cairnloop into a host app.
- [JTBD Walkthrough](https://hexdocs.pm/cairnloop/02-jtbd-walkthrough.html) — A prose walkthrough
  of every Jobs-To-Be-Done stage in the seeded example: inbox → draft approval → governed tool
  proposal → resolve → outbound follow-up → bulk recovery.
- [Host Integration](https://hexdocs.pm/cairnloop/03-host-integration.html) — Wire up
  `ContextProvider`, `Notifier`, `AutomationPolicy`, and `SLAPolicyProvider` in your app. Includes
  telemetry patterns and Oban configuration.
- [Troubleshooting](https://hexdocs.pm/cairnloop/04-troubleshooting.html) — Docker demo failure
  recovery, dynamic ports, reset/log flows, install errors, migration order, pgvector setup, and
  Oban worker timing.

## Production Notes

Host apps own route authentication and authorization, per-request operator identity, repo config,
Oban supervision, secrets, monitoring, and deployment. Cairnloop supplies install scaffolding,
bounded telemetry, liveness/metrics plugs, and `mix cairnloop.doctor` so those host-owned seams are
visible before production traffic reaches them.

## Contributing

Contributions are welcome. Open an issue or pull request on
[GitHub](https://github.com/szTheory/cairnloop). Please follow the existing code style and run
`mix ci.fast` before submitting. Run `mix ci` before release-sized changes. For focused checks:
docs/package changes use `mix ci.quality`, DB-backed workflow changes use `mix ci.integration`, and
the example browser journey uses `cd examples/cairnloop_example && mix test.e2e`. Docker demo smoke
stays separate from default `mix ci`; run `./bin/demo smoke` for Docker/demo/docs/example adoption
changes.

## License

MIT. See [LICENSE](https://github.com/szTheory/cairnloop/blob/main/LICENSE).
