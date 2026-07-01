---
phase: 58-identity-ingress-and-side-effect-trust
plan: "02"
subsystem: identity
tags: [widget-ingress, verifier, customer-ref, phoenix-channel, trust-boundary, tdd]

requires:
  - phase: 58-identity-ingress-and-side-effect-trust
    provides: "58-01 customer_ref persistence and Chat.create_customer_conversation/1 identity semantics"
provides:
  - "Cairnloop.Widget.Verifier behaviour with fail-closed default and explicit demo verifier"
  - "WidgetSocket.connect/3 fails closed unless :widget_token_verifier is explicitly configured"
  - "WidgetSocket assigns verified customer_ref and never stores widget tokens as user_token"
  - "WidgetChannel.join/3 creates conversations from verified customer_ref without host_user_id"
  - "Focused TRUST-01/TRUST-02 widget ingress regression coverage"
affects: [phase-58-operator-identity, phase-58-telemetry-logs, widget-ingress, example-app]

tech-stack:
  added: []
  patterns:
    - "Configured verifier modules use verify/2 and return {:ok, %{customer_ref: binary}} or {:error, reason}"
    - "Demo/test widget acceptance is explicit config, not a production fallback"
    - "Channel joins require verified customer_ref before durable conversation creation"

key-files:
  created:
    - lib/cairnloop/widget/verifier.ex
    - lib/cairnloop/widget/verifier/fail_closed.ex
    - lib/cairnloop/widget/verifier/demo.ex
    - test/cairnloop/channels/widget_socket_test.exs
  modified:
    - lib/cairnloop/channels/widget_socket.ex
    - lib/cairnloop/channels/widget_channel.ex
    - examples/cairnloop_example/config/dev.exs
    - examples/cairnloop_example/config/test.exs
    - test/cairnloop/channels/widget_channel_test.exs
    - test/integration/widget_channel_test.exs
    - .planning/phases/58-identity-ingress-and-side-effect-trust/deferred-items.md

key-decisions:
  - "Widget ingress uses an explicit :widget_token_verifier module or {module, opts}; absent/invalid config fails closed through FailClosed."
  - "Cairnloop.Widget.Verifier.Demo is acceptable only when explicitly configured by demo/test hosts."
  - "WidgetChannel treats socket.assigns.customer_ref as the only browser/customer identity allowed into Chat.create_customer_conversation/1."

patterns-established:
  - "Fail-closed verifier seam for host-owned browser/customer identity."
  - "TDD red/green commits for widget ingress trust-boundary changes."

requirements-completed: [TRUST-01, TRUST-02]

duration: 9 min
completed: 2026-06-29
status: complete
---

# Phase 58 Plan 02: Widget Identity Ingress Summary

**Widget ingress now requires an explicit host verifier and routes verified browser identity into `customer_ref`, never `host_user_id`.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-06-30T00:07:46Z
- **Completed:** 2026-06-30T00:15:55Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- Added `Cairnloop.Widget.Verifier`, `FailClosed`, and `Demo` modules.
- Changed `WidgetSocket.connect/3` to reject missing/invalid verifier config and assign only verified `:customer_ref`.
- Explicitly configured the example app dev/test environments to use the demo verifier.
- Changed `WidgetChannel.join/3` to require `:customer_ref`, create conversations through `%{customer_ref: value}`, and leave `host_user_id` nil.
- Added focused socket/channel regression tests for missing verifier, demo verifier, rejecting verifier, customer_ref persistence, missing customer_ref fail-closed behavior, and server-assigned conversation id use.

## Task Commits

1. **Task 1 RED: widget socket verifier tests** - `78d023c` (test)
2. **Task 1 GREEN: explicit widget verifier seam** - `c9a5b16` (feat)
3. **Task 2 RED: widget channel customer_ref tests** - `c3a3de7` (test)
4. **Task 2 GREEN: customer_ref channel joins** - `bc10438` (feat)

## Files Created/Modified

- `lib/cairnloop/widget/verifier.ex` - Host-owned verifier behaviour contract.
- `lib/cairnloop/widget/verifier/fail_closed.ex` - Default verifier that rejects all widget ingress.
- `lib/cairnloop/widget/verifier/demo.ex` - Explicit demo/test verifier for non-empty tokens.
- `lib/cairnloop/channels/widget_socket.ex` - Configured verifier lookup and `customer_ref` socket assignment.
- `lib/cairnloop/channels/widget_channel.ex` - Verified `customer_ref` join requirement and conversation creation.
- `examples/cairnloop_example/config/dev.exs` - Explicit demo verifier opt-in.
- `examples/cairnloop_example/config/test.exs` - Explicit demo verifier opt-in.
- `test/cairnloop/channels/widget_socket_test.exs` - TRUST-02 socket regression coverage.
- `test/cairnloop/channels/widget_channel_test.exs` - TRUST-01 channel regression coverage.
- `test/integration/widget_channel_test.exs` - Direct socket fixture updated to provide `customer_ref`.
- `.planning/phases/58-identity-ingress-and-side-effect-trust/deferred-items.md` - Reconfirmed integration-lane deferral.

## Decisions Made

- Use `:widget_token_verifier` as the single widget verifier config key, accepting either a module or `{module, opts}`.
- Treat absent, malformed, unloaded, or non-callback verifier config as unauthorized widget ingress.
- Keep demo verifier intentionally simple: non-empty binary token maps to `customer_ref`, and it only runs when explicitly configured.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Loaded verifier modules before checking callbacks**
- **Found during:** Task 1 GREEN
- **Issue:** `function_exported?/3` returned false for the explicitly configured demo verifier before the module was loaded, causing valid demo config to fail closed.
- **Fix:** Added `Code.ensure_loaded/1` before checking and invoking `verify/2`.
- **Files modified:** `lib/cairnloop/channels/widget_socket.ex`
- **Verification:** `mix test test/cairnloop/channels/widget_socket_test.exs --warnings-as-errors`
- **Committed in:** `c9a5b16`

**2. [Rule 3 - Blocking] Updated direct integration socket fixture for verified customer_ref**
- **Found during:** Task 2 GREEN
- **Issue:** `test/integration/widget_channel_test.exs` bypasses `WidgetSocket.connect/3` and still seeded `user_token`, which no longer represents verified channel identity.
- **Fix:** Updated the fixture to seed `customer_ref` and corrected comments so the integration path matches the new trust boundary.
- **Files modified:** `test/integration/widget_channel_test.exs`
- **Verification:** Root focused channel/socket/chat tests passed; `mix ci.integration` still fails before channel join on the pre-existing LiveView render-error baseline.
- **Committed in:** `bc10438`

---

**Total deviations:** 2 auto-fixed (Rule 1: 1, Rule 3: 1).
**Impact on plan:** Both fixes were required to make the planned verifier/customer_ref behavior work without expanding product scope.

## Issues Encountered

- `mix ci.integration` failed with the same 18 LiveView-heavy integration failures already recorded by earlier Phase 58 plans. In the widget-channel integration case, execution failed at `live(conn, "/inbox")` before reaching channel join. Focused 58-02 tests, warnings-clean compile, and `mix ci.fast` passed.
- `state.update-progress` reported 63% progress but left the STATE.md frontmatter percent at 20; the field was corrected to match the tool-reported completed count.

## Verification

- RED Task 1: `mix test test/cairnloop/channels/widget_socket_test.exs --warnings-as-errors` failed as expected with 4 verifier/config/customer_ref failures.
- GREEN Task 1: `mix test test/cairnloop/channels/widget_socket_test.exs --warnings-as-errors` passed, 4 tests, 0 failures.
- GREEN Task 1: `mix compile --warnings-as-errors` passed.
- RED Task 2: `mix test test/cairnloop/channels/widget_channel_test.exs --warnings-as-errors` failed as expected with 2 customer_ref/missing-customer_ref failures.
- GREEN Task 2: `mix test test/cairnloop/channels/widget_channel_test.exs --warnings-as-errors` passed, 5 tests, 0 failures.
- Plan focused: `mix test test/cairnloop/channels/widget_socket_test.exs test/cairnloop/channels/widget_channel_test.exs test/cairnloop/chat_test.exs --warnings-as-errors` passed, 41 tests, 0 failures.
- Plan build: `mix compile --warnings-as-errors` passed.
- Source prohibition scan: no production `user_token` assignment or widget identity to `host_user_id` copy remained in widget ingress files.
- Wave gate: `mix ci.fast` passed, 1116 tests, 0 failures, 62 excluded.
- DB-backed/schema gate: `mix ci.integration` failed with 18 unrelated LiveView render-error failures; deferred.

## Known Stubs

None.

## Threat Flags

None - the new verifier and customer_ref trust surfaces were explicitly covered by the plan threat model.

## User Setup Required

Host applications must configure `:widget_token_verifier` with their own verifier module or `{module, opts}` before enabling production widget ingress. The example app dev/test configs explicitly use `Cairnloop.Widget.Verifier.Demo`.

## Next Phase Readiness

Ready for 58-03 to thread dashboard session operator identity through `ConversationLive` actions. Widget-created conversations now carry customer/browser identity in `customer_ref`, so follow-on operator/governance work should not read browser identity from `host_user_id`.

## Self-Check: PASSED

- Found summary and all new verifier/test files on disk.
- Found task commits `78d023c`, `c9a5b16`, `c3a3de7`, and `bc10438` in git history.
- Summary file is non-empty and records the integration-lane deferral.

---
*Phase: 58-identity-ingress-and-side-effect-trust*
*Completed: 2026-06-29*
