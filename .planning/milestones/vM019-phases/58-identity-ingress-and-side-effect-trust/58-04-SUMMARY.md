---
phase: 58-identity-ingress-and-side-effect-trust
plan: "04"
subsystem: security
tags: [email-webhook, mcp, bearer-auth, ingress, docs-trust, tdd]

requires:
  - phase: 57-evidence-and-trust-audit
    provides: "Ingress and MCP auth gaps for Phase 58"
  - phase: 58-identity-ingress-and-side-effect-trust
    provides: "TRUST-01 customer/operator identity separation from Plan 01"
provides:
  - "Email webhook verifier seam with fail-closed missing/wrong auth behavior"
  - "EmailWebhookPlug auth before body parsing and ProcessMessage enqueue"
  - "MCP initialize, tools/list, and tools/call Bearer-token method gate"
  - "MCP guide source-scan coverage for live auth docs truth"
affects: [phase-58-widget-verifier, phase-58-telemetry-logs, phase-60-docs, mcp-clients, ingress-auth]

tech-stack:
  added: []
  patterns:
    - "Configured verifier/token seams at ingress boundaries"
    - "Router-level token-required method gate after JSON-RPC parse and before metadata/write dispatch"
    - "Docs source scans for auth-module and token-shape drift"

key-files:
  created:
    - lib/cairnloop/ingress/email_webhook_verifier.ex
    - test/cairnloop/ingress/email_webhook_plug_test.exs
    - test/cairnloop/docs_trust_test.exs
  modified:
    - lib/cairnloop/ingress/email_webhook_plug.ex
    - lib/cairnloop/web/mcp/router.ex
    - guides/05-mcp-clients.md
    - test/cairnloop/web/mcp/router_test.exs
    - .planning/phases/58-identity-ingress-and-side-effect-trust/deferred-items.md

key-decisions:
  - "Email webhook auth accepts a host verifier or shared token and fails closed when neither is configured."
  - "MCP initialize, tools/list, and tools/call are token-required; malformed JSON and unsupported non-token methods keep JSON-RPC error envelopes."
  - "MCP raw tokens are documented as opaque copy-once values, not values with a fixed public prefix."

patterns-established:
  - "Use a narrow verifier module for host-owned ingress auth callbacks."
  - "Keep well-known MCP metadata public while gating JSON-RPC capability/tool/write methods."
  - "Pair auth docs changes with source-scan tests that reject stale module and token claims."

requirements-completed: [TRUST-03, TRUST-04, OPS-04]

duration: 12 min
completed: 2026-06-29
status: complete
---

# Phase 58 Plan 04: Email and MCP Ingress Trust Summary

**Email webhook and MCP JSON-RPC ingress now fail closed before unsafe parsing, tool metadata exposure, or governed write dispatch.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-06-29T23:37:56Z
- **Completed:** 2026-06-29T23:49:27Z
- **Tasks:** 3
- **Files modified:** 8

## Accomplishments

- Added `Cairnloop.Ingress.EmailWebhookVerifier.verify/1` with host verifier and shared-token seams.
- Updated `EmailWebhookPlug` so missing/wrong auth returns halted JSON 401 before `read_body/1` and before enqueue.
- Added DB-free email webhook tests proving missing, wrong, configured-token, and configured-verifier behavior.
- Updated `Cairnloop.Web.MCP.Router` so `initialize`, `tools/list`, and `tools/call` require a valid Bearer token before exposing metadata or write paths.
- Updated MCP client docs and added source-scan coverage for `AuthPlug`, opaque raw token behavior, public well-known discovery, and token-required methods.

## Task Commits

1. **Task 1 RED: email webhook auth tests** - `6805dc5` (test)
2. **Task 1 GREEN: email verifier and halted auth failures** - `6a34ce4` (feat)
3. **Task 2 RED: MCP token-required method tests** - `678626a` (test)
4. **Task 2 GREEN: MCP router Bearer method gate** - `45d82fd` (feat)
5. **Task 3 RED: MCP auth docs source scan** - `7f39e09` (test)
6. **Task 3 GREEN: MCP guide auth alignment** - `43ce242` (docs)
7. **Verification cleanup: format Task 1 test assertions** - `fb73fa4` (style)

## Files Created/Modified

- `lib/cairnloop/ingress/email_webhook_verifier.ex` - New host-configured verifier/shared-token auth seam.
- `lib/cairnloop/ingress/email_webhook_plug.ex` - Verifies before body read, halts unauthorized responses, keeps default `Oban.insert/1` enqueue behavior.
- `test/cairnloop/ingress/email_webhook_plug_test.exs` - Covers fail-closed auth and configured enqueue paths without a live Oban instance.
- `lib/cairnloop/web/mcp/router.ex` - Adds private token-required method gate for `initialize`, `tools/list`, and `tools/call`.
- `test/cairnloop/web/mcp/router_test.exs` - Adds missing/invalid token coverage for MCP metadata and write methods.
- `guides/05-mcp-clients.md` - Aligns MCP mounting, token, well-known discovery, and fail-closed method docs with live code.
- `test/cairnloop/docs_trust_test.exs` - Source-scans MCP docs for stale auth module, token prefix, and method-auth claims.
- `.planning/phases/58-identity-ingress-and-side-effect-trust/deferred-items.md` - Reconfirms out-of-scope integration-lane failure.

## Decisions Made

- `:email_webhook_verifier` supports one-arity functions, modules exporting `verify/1`, and `{module, function}` callback tuples; invalid verifier config fails closed.
- The retained `:email_webhook_token` seam uses exact shared-token matching and remains the simple host-owned option.
- `EmailWebhookPlug` accepts an `:enqueue` plug option for DB-free tests while preserving `Oban.insert/1` as the production default.
- MCP auth stays centralized in `AuthPlug`; the router decides which JSON-RPC methods require a valid assigned token.

## Deviations from Plan

None - plan scope was implemented as written.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope expansion; unrelated dirty-worktree changes were left unstaged.

## Issues Encountered

- The checkout had extensive pre-existing dirty changes. I staged only 58-04 files and the phase deferred-items note.
- `mix ci.integration` failed with 18 LiveView-heavy integration failures in existing inbox/governance/widget paths. Focused 58-04 router tests with `--include integration` passed, and the failure was deferred as the same broader integration-lane state already recorded by Plan 01.

## Verification

- Task 1 RED: `mix test test/cairnloop/ingress/email_webhook_plug_test.exs --warnings-as-errors` failed as expected with missing verifier, missing halt, unsupported host verifier, and hard-wired Oban enqueue failures.
- Task 1 GREEN: `mix test test/cairnloop/ingress/email_webhook_plug_test.exs --warnings-as-errors` passed, 5 tests, 0 failures.
- Task 1 GREEN: `mix compile --warnings-as-errors` passed.
- Task 2 RED: `mix test --include integration test/cairnloop/web/mcp/router_test.exs --warnings-as-errors` failed as expected with 4 unauthenticated initialize/tools-list failures.
- Task 2 GREEN: `mix test --include integration test/cairnloop/web/mcp/auth_plug_test.exs test/cairnloop/web/mcp/router_test.exs --warnings-as-errors` passed, 17 tests, 0 failures.
- Task 2 GREEN: `mix compile --warnings-as-errors` passed.
- Task 3 RED: `mix test test/cairnloop/docs_trust_test.exs --warnings-as-errors` failed as expected with 4 stale guide claims.
- Task 3 GREEN: `mix test test/cairnloop/docs_trust_test.exs test/cairnloop/web/mcp/router_test.exs test/cairnloop/ingress/email_webhook_plug_test.exs --warnings-as-errors` passed, 9 tests, 0 failures, 14 excluded.
- Task 3 GREEN: `mix test --include integration test/cairnloop/docs_trust_test.exs test/cairnloop/web/mcp/router_test.exs test/cairnloop/ingress/email_webhook_plug_test.exs --warnings-as-errors` passed, 23 tests, 0 failures.
- Plan focused: targeted `mix format --check-formatted`, focused DB-free tests, focused integration-included tests, and `mix compile --warnings-as-errors` passed.
- Wave gate: `mix ci.fast` passed, 1103 tests, 0 failures, 62 excluded.
- DB-backed MCP token gate: `mix ci.integration` failed with 18 unrelated LiveView-heavy failures; deferred.
- Docs/package gate: `mix ci.quality` passed.
- Acceptance scan: `rg` checks confirmed email verifier-before-read, halted auth, MCP token-required gate, and guide source-scan claims.

## Known Stubs

None.

## Threat Flags

None - the new email verifier seam, MCP router method gate, and docs source-scan coverage were all planned mitigations in the 58-04 threat model.

## User Setup Required

Hosts that mount the email webhook must configure either `:email_webhook_verifier` or `:email_webhook_token`; absent config now intentionally returns 401. MCP clients must use the raw Bearer token copied from Settings.

## Next Phase Readiness

Ready for 58-05 Scrypath opt-in side-effect hardening and later 58-06 logs/telemetry cleanup. The broader integration lane should be revisited after the pre-existing dirty LiveView/config state is reconciled.

## Self-Check: PASSED

- Found key source, test, guide, summary, and deferred-items files on disk.
- Found task commits `6805dc5`, `6a34ce4`, `678626a`, `45d82fd`, `7f39e09`, `43ce242`, and `fb73fa4` in git history.
- Summary records the integration-lane deferral and all 58-04 verification commands.

---
*Phase: 58-identity-ingress-and-side-effect-trust*
*Completed: 2026-06-29*
