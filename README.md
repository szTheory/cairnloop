# Cairnloop 🏔️

[![Hex.pm Version](https://img.shields.io/hexpm/v/cairnloop.svg)](https://hex.pm/packages/cairnloop)
[![HexDocs](https://img.shields.io/badge/hexdocs-online-blue.svg)](https://hexdocs.pm/cairnloop)
[![GitHub Actions CI](https://github.com/szTheory/cairnloop/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/cairnloop/actions)

An embedded, Phoenix-native customer support automation layer for Elixir applications.

## Installation

The fastest way to install Cairnloop is with the Igniter installer. First, add Igniter to your
dependencies if it is not already present, then run:

```bash
mix deps.get
mix cairnloop.install
```

The installer adds `{:cairnloop, "~> 0.1.0"}` to your `mix.exs` deps and generates a
`create_cairnloop_tables` migration against your detected Ecto repo.

### Manual install (without Igniter)

Add Cairnloop to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:cairnloop, "~> 0.1.0"}
  ]
end
```

Then run `mix deps.get` and generate the migration manually (see the quickstart guide for the
migration contents).

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

- [Quickstart](https://hexdocs.pm/cairnloop/01-quickstart.html) — Clone, install, boot the
  example app, and walk your first support conversation end-to-end.
- [JTBD Walkthrough](https://hexdocs.pm/cairnloop/02-jtbd-walkthrough.html) — A prose walkthrough
  of every Jobs-To-Be-Done stage in the seeded example: inbox → draft approval → governed tool
  proposal → resolve → outbound follow-up → bulk recovery.
- [Host Integration](https://hexdocs.pm/cairnloop/03-host-integration.html) — Wire up
  `ContextProvider`, `Notifier`, `AutomationPolicy`, and `SLAPolicyProvider` in your app. Includes
  telemetry patterns and Oban configuration.
- [Troubleshooting](https://hexdocs.pm/cairnloop/04-troubleshooting.html) — Common install errors,
  migration order, pgvector setup, and Oban worker timing.

## Contributing

Contributions are welcome. Open an issue or pull request on
[GitHub](https://github.com/szTheory/cairnloop). Please follow the existing code style and run
`mix test` before submitting.

## License

MIT. See [LICENSE](https://github.com/szTheory/cairnloop/blob/main/LICENSE).
