---
phase: 58-identity-ingress-and-side-effect-trust
plan: "06"
subsystem: telemetry
tags: [telemetry, logging, trust-boundary, scrypath, tdd]

requires:
  - phase: 58-01
    provides: "Conversation.customer_ref separates customer identity from operator/governance identity"
  - phase: 58-05
    provides: "Scrypath bridge enqueues only a durable conversation_id pointer"
provides:
  - "Negative tests for unsafe conversation telemetry keys and support-content log leakage"
  - "Bounded conversation resolve/resolved telemetry metadata"
  - "Static default email-worker warning that excludes support bodies and raw payloads"
  - "Public telemetry docs describing observability-only bounded conversation metadata"
affects: [phase-58-doctor-readiness, telemetry, logging, scrypath]

tech-stack:
  added: []
  patterns:
    - "Conversation lifecycle telemetry uses an allow-listed metadata shape"
    - "Durable workflow truth remains in DB/audit/jobs; telemetry is observability only"
    - "Default unhandled-email logs use static diagnostic text, not request content"

key-files:
  created:
    - test/cairnloop/chat_telemetry_test.exs
    - .planning/phases/58-identity-ingress-and-side-effect-trust/58-06-SUMMARY.md
  modified:
    - lib/cairnloop/chat.ex
    - lib/cairnloop/telemetry.ex
    - lib/cairnloop/workers/process_message.ex
    - test/cairnloop/chat_telemetry_test.exs
    - test/cairnloop/chat_test.exs
    - test/cairnloop/workers/process_message_test.exs
    - .planning/phases/58-identity-ingress-and-side-effect-trust/deferred-items.md

key-decisions:
  - "58-06: Conversation resolve telemetry carries conversation_id plus bounded lifecycle labels, not actor/customer/operator IDs, raw metadata, support bodies, payloads, secrets, or full structs."
  - "58-06: The Scrypath bridge continues to rely on conversation_id as a durable pointer; support content is fetched inside the enabled worker path."
  - "58-06: The default unhandled-email worker log is static diagnostic text and never interpolates inbound content or raw payload details."

patterns-established:
  - "Attach telemetry tests to start/stop/resolved events and reject unsafe keys directly."
  - "Use existing durable jobs/audit rows for workflow facts instead of telemetry metadata."

requirements-completed: [TRUST-05]

duration: 6 min
completed: 2026-06-30
status: complete
---

# Phase 58 Plan 06: Bounded Telemetry and Log Privacy Summary

**Conversation lifecycle telemetry now exports only a durable conversation pointer plus bounded lifecycle labels, and default email logs no longer expose support bodies or raw payloads.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-06-30T03:03:11Z
- **Completed:** 2026-06-30T03:08:44Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Added `test/cairnloop/chat_telemetry_test.exs` to attach to conversation resolve start/stop/resolved events and reject unsafe telemetry keys, raw payload/body values, secrets, customer/operator IDs, arbitrary metadata, and full structs.
- Updated `Chat.resolve_conversation/2` so exported lifecycle telemetry carries only `conversation_id`, `operation`, and terminal `outcome`; durable jobs and audit rows still receive their existing workflow inputs.
- Updated the unhandled email worker to log static diagnostic text and strengthened the test so default logs reject message body and raw payload leakage.
- Updated `Cairnloop.Telemetry` module docs to describe bounded, observability-only conversation telemetry and the Scrypath pointer model.

## Task Commits

1. **Task 1 RED: unsafe telemetry/log tests** - `bd3d4f1` (test)
2. **Task 2 GREEN: bounded telemetry metadata** - `6006fed` (feat)

## Files Created/Modified

- `test/cairnloop/chat_telemetry_test.exs` - New TRUST-05 negative telemetry tests for unsafe keys and sensitive values.
- `test/cairnloop/workers/process_message_test.exs` - Strengthened default email log leakage regression coverage.
- `lib/cairnloop/chat.ex` - Replaced raw resolve telemetry metadata with an allow-listed metadata helper.
- `lib/cairnloop/telemetry.ex` - Documented bounded conversation telemetry and observability-only workflow truth.
- `lib/cairnloop/workers/process_message.ex` - Changed default email logging to static diagnostic text.
- `test/cairnloop/chat_test.exs` - Updated existing resolve telemetry assertions to the bounded metadata contract.
- `.planning/phases/58-identity-ingress-and-side-effect-trust/deferred-items.md` - Reconfirmed out-of-scope `mix ci.fast` format blocker.

## Decisions Made

- `conversation_id` remains the only durable pointer exported for the Scrypath bridge; support content is fetched inside `IngestScrypath` only after ready config validation.
- Conversation resolve telemetry keeps coarse lifecycle labels (`operation`, `outcome`) and does not export actor, host/customer/operator IDs, arbitrary metadata, payload/body fields, secrets, or full structs.
- The email worker’s unhandled-ingress warning is intentionally static so operators get a useful diagnostic without leaking support content.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Committed the safe default email worker log**
- **Found during:** Task 2 (Bound conversation telemetry and document safe defaults)
- **Issue:** The checkout already had an in-scope uncommitted `ProcessMessage` hunk that stopped interpolating email content. Leaving it uncommitted would make the new log leakage test depend on dirty working-tree state instead of committed code.
- **Fix:** Included the static email warning implementation in the GREEN commit.
- **Files modified:** `lib/cairnloop/workers/process_message.ex`
- **Verification:** `mix test test/cairnloop/chat_telemetry_test.exs test/cairnloop/workers/process_message_test.exs --warnings-as-errors`
- **Committed in:** `6006fed`

**2. [Rule 1 - Test Contract] Updated stale Chat telemetry assertions**
- **Found during:** Task 2 (Bound conversation telemetry and document safe defaults)
- **Issue:** Existing `test/cairnloop/chat_test.exs` asserted the old unsafe telemetry metadata shape, including actor and arbitrary metadata.
- **Fix:** Updated the existing test to assert the bounded metadata contract and reject unsafe keys.
- **Files modified:** `test/cairnloop/chat_test.exs`
- **Verification:** `mix test test/cairnloop/chat_telemetry_test.exs test/cairnloop/workers/process_message_test.exs test/cairnloop/chat_test.exs --warnings-as-errors`
- **Committed in:** `6006fed`

---

**Total deviations:** 2 auto-fixed (1 Rule 2, 1 Rule 1).
**Impact on plan:** Both fixes were required to make TRUST-05 true in committed code and the broader test suite. No new product surface or telemetry workflow truth was added.

## Issues Encountered

- The checkout had many pre-existing dirty files. Only 58-06 hunks were staged for the task commits.
- `mix ci.fast` failed at `mix format --check-formatted` for the pre-existing unstaged `lib/cairnloop/web/conversation_live.ex` dashboard-path/manual-draft indentation hunk around `record_editor_handoff/2`. This is documented in `deferred-items.md`. The touched 58-06 files pass the formatter.

## Verification

- RED: `mix test test/cairnloop/chat_telemetry_test.exs test/cairnloop/workers/process_message_test.exs --warnings-as-errors` failed as expected with unsafe conversation telemetry keys (`:metadata`, `:host_user_id`, `:actor`) before implementation.
- GREEN focused: `mix test test/cairnloop/chat_telemetry_test.exs test/cairnloop/workers/process_message_test.exs test/cairnloop/chat_test.exs --warnings-as-errors` passed, 35 tests, 0 failures.
- Plan focused: `mix test test/cairnloop/chat_telemetry_test.exs test/cairnloop/workers/process_message_test.exs --warnings-as-errors` passed, 3 tests, 0 failures.
- Build: `mix compile --warnings-as-errors` passed.
- Formatter scoped: `mix format --check-formatted lib/cairnloop/chat.ex lib/cairnloop/telemetry.ex lib/cairnloop/workers/process_message.ex test/cairnloop/chat_telemetry_test.exs test/cairnloop/chat_test.exs test/cairnloop/workers/process_message_test.exs` passed.
- Broad DB-free: `mix test --exclude integration --warnings-as-errors` passed, 1131 tests, 0 failures, 62 excluded.
- Wave gate: `mix ci.fast` failed only on the pre-existing unstaged `lib/cairnloop/web/conversation_live.ex` formatting issue documented above.

## Known Stubs

None. Stub scan only found existing nil/query assertions in tests, not placeholder UI or unwired behavior.

## Threat Flags

None - the changed telemetry/logging surface is the planned TRUST-05 threat mitigation. No new network endpoint, auth path, file access pattern, or schema trust boundary was introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 58-07 doctor/readiness work. Doctor output can describe TRUST-05 safe defaults knowing conversation telemetry and default email logs no longer expose support content or unsafe metadata.

## Self-Check: PASSED

- Found all created/modified 58-06 files on disk.
- Found task commits `bd3d4f1` and `6006fed` in git history.
- Verified touched files format cleanly and focused TRUST-05 tests pass.
- Recorded the out-of-scope `mix ci.fast` format blocker in `deferred-items.md`.

---
*Phase: 58-identity-ingress-and-side-effect-trust*
*Completed: 2026-06-30*
