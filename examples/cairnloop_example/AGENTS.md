# Cairnloop Example App Agent Notes

Read the repository root `CLAUDE.md`, `AGENTS.md`, and `docs/operator-ui-principles.md` before UI
or e2e work.

This Phoenix app is the realistic adoption/demo host for Cairnloop. Its own demo index and chat
surface may use normal Phoenix app styling, but the mounted `/support` Cairnloop dashboard must keep
using the shipped library design system from `priv/static/cairnloop.css`.

## Demo And E2E Rules

- Keep seeds realistic and deterministic. The Trailmark demo data should exercise Inbox,
  Conversation, Knowledge, Audit, Settings, customer chat, governed actions, and outbound recovery.
- Keep browser tests narrow and behavior-focused. Avoid sleeps, fixed host ports, and brittle
  selectors tied to incidental visual placement.
- Use `mix test.e2e` for the example app's browser lane. Use `./bin/demo smoke` from the repo root
  when validating Docker adoption flow.
- If local browser tests collide on `4002`, rerun with `PHX_TEST_PORT=<free-port> mix test.e2e`;
  CI keeps the default `4002`.
- Docker demo docs must point users to the URL printed by `./bin/demo`; only manual local Phoenix
  boot assumes `http://localhost:4000`.
