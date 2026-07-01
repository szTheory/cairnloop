# Deferred Items - Phase 58 Plan 01

## Out-of-Scope Verification Failure

- **Command:** `mix ci.integration`
- **Observed:** Failed with 18 LiveView-heavy integration failures in existing inbox/governance/widget paths. The failures shared the same Phoenix render-error stack shape and were outside the customer_ref schema/migration assertions introduced by 58-01.
- **Disposition:** Deferred as pre-existing dirty-worktree/broader integration state. Focused 58-01 tests, source scans, warnings-clean compile, and `mix ci.fast` passed.

## Out-of-Scope Verification Failure Reconfirmed In Plan 04

- **Command:** `mix ci.integration`
- **Observed:** Failed again with 18 LiveView-heavy integration failures in existing inbox/governance/widget paths, all outside the email webhook, MCP router, and MCP guide files touched by 58-04.
- **Disposition:** Deferred as the same broader integration-lane state. Focused 58-04 DB-free tests, MCP router tests with `--include integration`, warnings-clean compile, `mix ci.fast`, and `mix ci.quality` passed.

## Out-of-Scope Verification Failure Reconfirmed In Plan 02

- **Command:** `mix ci.integration`
- **Observed:** Failed again with 18 LiveView-heavy integration failures in existing inbox/governance/widget paths. The widget-channel integration case failed before channel join at `live(conn, "/inbox")` with the same Phoenix render-error stack shape.
- **Disposition:** Deferred as the same broader integration-lane state. Focused 58-02 socket/channel/chat tests, warnings-clean compile, and `mix ci.fast` passed.

## Out-of-Scope Verification Failure Reconfirmed In Plan 03

- **Command:** `mix ci.fast`
- **Observed:** Failed at `mix format --check-formatted` for a pre-existing unstaged `lib/cairnloop/web/conversation_live.ex` dashboard-path/manual-draft hunk around `open_manual_draft/3` indentation. The focused Plan 03 tests, UI token gates, and warnings-clean compile passed.
- **Disposition:** Deferred as pre-existing dirty-worktree formatting state. Plan 03 staged only identity trust-state, actor-source, and test-format hunks needed for TRUST-01.

## Out-of-Scope Verification Failure Reconfirmed In Plan 06

- **Command:** `mix ci.fast`
- **Observed:** Failed at `mix format --check-formatted` for the same pre-existing unstaged `lib/cairnloop/web/conversation_live.ex` dashboard-path/manual-draft hunk around lines 192-195 (`record_editor_handoff/2` indentation). Touched Plan 06 files pass `mix format --check-formatted`, focused telemetry/log tests pass, warnings-clean compile passes, and the DB-free test suite passes.
- **Disposition:** Deferred as pre-existing dirty-worktree formatting state. Plan 06 staged only bounded telemetry/logging code and tests needed for TRUST-05.

## Wave 2 Orchestrator Follow-Up

- **Command:** `mix format --check-formatted lib/cairnloop/web/conversation_live.ex && mix compile --warnings-as-errors && mix ci.fast`
- **Observed:** Passed after a formatter-only indentation fix in the already-dirty Phase 58 web file. `mix ci.fast` reported 1131 tests, 0 failures, 62 excluded.
- **Disposition:** The earlier Plan 03/06 executor-local `mix ci.fast` failure is no longer an active wave gate failure. The broader `mix ci.integration` LiveView-heavy failures remain deferred as recorded above.
