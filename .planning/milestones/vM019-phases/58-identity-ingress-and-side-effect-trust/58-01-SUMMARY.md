---
phase: 58-identity-ingress-and-side-effect-trust
plan: "01"
subsystem: identity
tags: [customer-ref, ecto, installer, migrations, trust-boundary, tdd]

requires:
  - phase: 57-evidence-and-trust-audit
    provides: "Identity conflation and migration parity risks for Phase 58"
provides:
  - "Conversation.customer_ref as the additive customer/browser identity field"
  - "Chat.create_customer_conversation/1 remaps customer identity away from host_user_id"
  - "Installer, test-host, and example-app conversation migrations create nullable customer_ref"
  - "Existing-install upgrade guidance for adding customer_ref"
affects: [phase-58-widget-verifier, phase-58-operator-identity, phase-59-schema-prefix, installer, example-app]

tech-stack:
  added: []
  patterns:
    - "Customer/browser identity persists as customer_ref; host_user_id remains operator/governance identity"
    - "Installer and example migration parity is pinned by source-scan tests"
    - "Selective staging preserved unrelated dirty worktree changes"

key-files:
  created:
    - test/cairnloop/tasks/install_test.exs
    - .planning/phases/58-identity-ingress-and-side-effect-trust/deferred-items.md
  modified:
    - lib/cairnloop/conversation.ex
    - lib/cairnloop/chat.ex
    - lib/mix/tasks/cairnloop/install.ex
    - priv/test_host/migrations/20260101000000_create_host_owned_tables.exs
    - examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs
    - test/cairnloop/chat_test.exs

key-decisions:
  - "Use customer_ref as the opaque additive customer/browser identity field for TRUST-01."
  - "Treat legacy create_customer_conversation/1 host_user_id input as a customer token compatibility input, not operator identity."
  - "Guide existing installs to add nullable customer_ref instead of repurposing host_user_id."

patterns-established:
  - "TDD red/green commits for trust-boundary persistence changes."
  - "Source-scan migration parity tests for installer, test-host, and example-app schema paths."

requirements-completed: [TRUST-01]

duration: 10 min
completed: 2026-06-29
status: complete
---

# Phase 58 Plan 01: Customer Identity Persistence Summary

**Customer/browser identity now persists as nullable `customer_ref` across runtime schema, customer conversation creation, installer output, test-host setup, and the example app.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-06-29T23:23:05Z
- **Completed:** 2026-06-29T23:33:20Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added `Conversation.customer_ref` and cast support while preserving `host_user_id` for operator/governance identity.
- Updated `Chat.create_customer_conversation/1` so new `customer_ref` input and legacy `host_user_id` customer-token input both persist to `customer_ref`, leaving `host_user_id` nil unless an explicitly named operator attr is provided.
- Added nullable `customer_ref` to installer-generated, test-host, and example-app conversation table creation paths.
- Added installer guidance for existing installs to add nullable `customer_ref` before enabling the Phase 58 widget verifier path.

## Task Commits

1. **Task 1 RED: customer_ref conversation tests** - `14cf69b` (test)
2. **Task 1 GREEN: customer_ref runtime semantics** - `5af7453` (feat)
3. **Task 2 RED: installer/migration parity tests** - `c0516fd` (test)
4. **Task 2 GREEN: installer/migration parity** - `1cc00f8` (feat)

## Files Created/Modified

- `lib/cairnloop/conversation.ex` - Added `customer_ref` field and changeset cast entry.
- `lib/cairnloop/chat.ex` - Remapped customer conversation identity to `customer_ref`; preserved `host_user_id` for explicit operator identity.
- `lib/mix/tasks/cairnloop/install.ex` - Added `customer_ref` to generated conversation migration and existing-install upgrade note.
- `priv/test_host/migrations/20260101000000_create_host_owned_tables.exs` - Added nullable `customer_ref`.
- `examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs` - Added nullable `customer_ref`.
- `test/cairnloop/chat_test.exs` - Added TRUST-01 behavior coverage for customer identity mapping.
- `test/cairnloop/tasks/install_test.exs` - Added source-scan coverage for installer/migration parity and upgrade guidance.
- `.planning/phases/58-identity-ingress-and-side-effect-trust/deferred-items.md` - Recorded out-of-scope integration-lane failure.

## Decisions Made

- `customer_ref` is the additive opaque customer/session identity field for this milestone.
- Compatibility input using `host_user_id` in `create_customer_conversation/1` is treated as a legacy customer token and remapped to `customer_ref`.
- Existing installs get additive nullable-column guidance; this plan does not implement Phase 59 dedicated-prefix behavior.

## Deviations from Plan

None - plan scope was implemented as written.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope expansion; out-of-scope dirty-worktree changes were left unstaged.

## Issues Encountered

- The checkout had pre-existing dirty changes in relevant files, including schema-prefix installer/schema work. I staged only 58-01 customer-ref hunks and left unrelated changes unstaged.
- `mix ci.integration` failed with 18 LiveView-heavy integration failures in existing inbox/governance/widget paths. Focused 58-01 tests, source scans, warnings-clean compile, and `mix ci.fast` passed. The failure is logged in `deferred-items.md`.

## Verification

- RED Task 1: `mix test test/cairnloop/chat_test.exs --warnings-as-errors` failed as expected with 4 customer-ref/legacy mapping failures before implementation.
- GREEN Task 1: `mix test test/cairnloop/chat_test.exs --warnings-as-errors` passed, 32 tests, 0 failures.
- GREEN Task 1: `mix compile --warnings-as-errors` passed.
- RED Task 2: `mix test test/cairnloop/tasks/install_test.exs --warnings-as-errors` failed as expected with 3 customer-ref parity/guidance failures before implementation.
- GREEN Task 2: `mix test test/cairnloop/tasks/install_test.exs --warnings-as-errors` passed, 6 tests, 0 failures.
- GREEN Task 2: `rg -n "customer_ref" ...` passed for installer, test-host migration, example migration, and installer tests.
- GREEN Task 2: `mix compile --warnings-as-errors` passed.
- Wave gate: `mix ci.fast` passed, 1096 tests, 0 failures, 57 excluded.
- DB-backed/schema gate: `mix ci.integration` failed with 18 unrelated LiveView integration failures; deferred.
- Plan focused: `mix test test/cairnloop/chat_test.exs test/cairnloop/tasks/install_test.exs --warnings-as-errors` passed, 38 tests, 0 failures.
- Plan focused: `rg -n "customer_ref" ...` passed across runtime schema, chat tests, installer, migrations, and installer tests.
- Plan build: `mix compile --warnings-as-errors` passed.

## Known Stubs

None.

## Threat Flags

None - the only new persistence trust surface, `customer_ref`, was already in the plan threat model.

## User Setup Required

None for this checkout. Existing adopters should follow the installer note and add a nullable `customer_ref` column to their Cairnloop conversations table before enabling the Phase 58 widget verifier path.

## Next Phase Readiness

Ready for 58-02 widget verifier work to route verified customer/session identity into `customer_ref`. The broader integration lane should be revisited after the pre-existing dirty schema-prefix/config work is reconciled.

## Self-Check: PASSED

- Found summary, deferred-items note, and installer test file on disk.
- Found task commits `14cf69b`, `5af7453`, `c0516fd`, and `1cc00f8` in git history.
- Summary file is non-empty and records the integration-lane deferral.

---
*Phase: 58-identity-ingress-and-side-effect-trust*
*Completed: 2026-06-29*
