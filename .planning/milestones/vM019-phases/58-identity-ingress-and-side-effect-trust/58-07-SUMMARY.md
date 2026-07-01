---
phase: 58-identity-ingress-and-side-effect-trust
plan: "07"
subsystem: ops
tags: [doctor, health, readiness, docs-trust, scrypath, telemetry, tdd]

requires:
  - phase: 58-identity-ingress-and-side-effect-trust
    provides: "58-02 widget verifier posture, 58-04 email/MCP ingress auth, 58-05 Scrypath status helper, and 58-06 bounded telemetry defaults"
provides:
  - "Liveness-only `/health` contract with no dependency readiness claims"
  - "Doctor trust diagnostics for widget, email, MCP, notifier, Oban, pgvector, mounted operations/dashboard surfaces, and Scrypath states"
  - "Operational trust troubleshooting docs and source-scan tests for health, telemetry, ingress, MCP, Scrypath, and failure-domain truth"
affects: [phase-58, phase-60-docs, ops, readiness, troubleshooting]

tech-stack:
  added: []
  patterns:
    - "Doctor findings distinguish Ready, Blocked, and Not checked here without querying unverified dependencies"
    - "Docs source scans pin public liveness/readiness and bounded telemetry claims"
    - "Patch staging preserved unrelated pre-existing troubleshooting guide changes"

key-files:
  created:
    - .planning/phases/58-identity-ingress-and-side-effect-trust/58-07-SUMMARY.md
  modified:
    - lib/cairnloop/doctor.ex
    - lib/mix/tasks/cairnloop.doctor.ex
    - lib/cairnloop/web/health_plug.ex
    - lib/cairnloop/router.ex
    - guides/03-host-integration.md
    - guides/04-troubleshooting.md
    - test/cairnloop/doctor_test.exs
    - test/cairnloop/web/health_plug_test.exs
    - test/cairnloop/docs_trust_test.exs

key-decisions:
  - "58-07: `/health` remains liveness-only; doctor and docs carry richer readiness/trust truth."
  - "58-07: Doctor reports only what it can prove locally and labels DB, Oban queue, pgvector index, Scrypath reachability, and stored MCP token rows as not checked here."
  - "58-07: Public docs use bounded telemetry examples with `conversation_id` and no support bodies, secrets, raw payloads, full conversation structs, or actor/customer IDs."

patterns-established:
  - "Reason-forward doctor findings use Ready/Blocked/Not checked here copy instead of raw inspect output."
  - "Docs trust tests source-scan guide claims for health liveness, Scrypath opt-in, troubleshooting failure domains, and bounded telemetry defaults."

requirements-completed: [OPS-01, OPS-02, OPS-03, OPS-04]

duration: 8 min
completed: 2026-06-30
status: complete
---

# Phase 58 Plan 07: Doctor, Liveness, and Trust Docs Summary

**Doctor now carries Phase 58 readiness/trust diagnostics while `/health` stays shallow liveness and docs pin the same operational truth.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-30T03:19:52Z
- **Completed:** 2026-06-30T03:27:06Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Extended `Cairnloop.Doctor.checks/2` with injected-config-friendly findings for widget verifier, email webhook auth, MCP token method posture, notifier callbacks, Oban availability, pgvector library availability, mounted operations/dashboard routes, and Scrypath disabled/ready/misconfigured states.
- Kept `Cairnloop.Web.HealthPlug` as static `{"status":"ok"}` liveness JSON and documented that it does not check DB, Oban, pgvector, notifier, ingress, MCP, or Scrypath readiness.
- Updated host integration and troubleshooting docs so readiness/trust diagnosis points to `mix cairnloop.doctor`, Scrypath remains opt-in/no-enqueue when misconfigured, and telemetry examples use bounded `conversation_id` metadata.
- Added source-scan tests covering `/health` liveness wording, Scrypath opt-in docs, doctor/troubleshooting failure domains, and bounded telemetry defaults.

## Task Commits

1. **Task 1 RED: doctor and health trust diagnostics tests** - `35ac98e` (test)
2. **Task 1 GREEN: doctor trust posture and liveness docs** - `d770bff` (feat)
3. **Task 2 RED: docs trust source scans** - `3b94c71` (test)
4. **Task 2 GREEN: operational trust docs** - `3646c24` (docs)

## Files Created/Modified

- `lib/cairnloop/doctor.ex` - Adds Ready/Blocked/Not checked here trust diagnostics without DB queries or secret output.
- `lib/mix/tasks/cairnloop.doctor.ex` - Documents the expanded doctor trust seam and honest non-check language.
- `lib/cairnloop/web/health_plug.ex` - Documents liveness-only JSON and delegates readiness/trust checks to doctor.
- `lib/cairnloop/router.ex` - Corrects public operations helper docs from liveness/readiness to liveness only.
- `guides/03-host-integration.md` - Updates operations, Scrypath, and telemetry sections.
- `guides/04-troubleshooting.md` - Adds operational trust diagnostics and failure-domain guidance.
- `test/cairnloop/doctor_test.exs` - Covers doctor trust diagnostics and secret-safe output.
- `test/cairnloop/web/health_plug_test.exs` - Pins the shallow health response shape.
- `test/cairnloop/docs_trust_test.exs` - Source-scans docs for Phase 58 trust claims.

## Decisions Made

- Doctor reports dependency availability where it can check loaded modules, but does not claim DB, Oban queue, pgvector index, external Scrypath, or stored MCP token row readiness.
- Missing widget and email auth seams are warning-level blocked findings because the library can run but production ingress remains fail-closed.
- Scrypath disabled is documented as an inert host choice, while enabled but unsafe config is a blocked/no-enqueue state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Corrected public router health docs**
- **Found during:** Task 2 (Pin troubleshooting, telemetry, and liveness docs truth)
- **Issue:** `lib/cairnloop/router.ex` still described `/health` as a liveness/readiness probe, which contradicted D-13 even after guide docs were corrected.
- **Fix:** Updated the operations helper doc to say `/health` is liveness only.
- **Files modified:** `lib/cairnloop/router.ex`
- **Verification:** `rg -n "liveness/readiness|readiness probe|ready when the database|checks DB|checks Oban|checks pgvector|checks notifier|checks MCP|checks Scrypath" lib guides` returned no matches.
- **Committed in:** `3646c24`

**2. [Rule 1 - Test Contract] Narrowed docs scan to allow bounded `conversation_id`**
- **Found during:** Task 2 GREEN
- **Issue:** The new docs trust test rejected `metadata.conversation_id` because it matched a broad `metadata.conversation` substring, even though `conversation_id` is the intended bounded pointer.
- **Fix:** Narrowed the rejection to the old full-struct assignment pattern while still rejecting actor, host_user_id, raw payload, raw_body, and full Conversation examples.
- **Files modified:** `test/cairnloop/docs_trust_test.exs`
- **Verification:** `mix test test/cairnloop/docs_trust_test.exs --warnings-as-errors`
- **Committed in:** `3646c24`

---

**Total deviations:** 2 auto-fixed (Rule 1: 1, Rule 2: 1).
**Impact on plan:** Both fixes tightened the planned trust/docs contract without adding new runtime surface.

## Issues Encountered

- `guides/04-troubleshooting.md` had a pre-existing dirty migration-prefix hunk before this plan. I preserved it and staged only the new trust-diagnostics hunk for `3646c24`; the unrelated hunk remains unstaged.

## Verification

- RED Task 1: `mix test test/cairnloop/doctor_test.exs test/cairnloop/web/health_plug_test.exs --warnings-as-errors` failed as expected with missing doctor trust diagnostics.
- GREEN Task 1: `mix test test/cairnloop/doctor_test.exs test/cairnloop/web/health_plug_test.exs --warnings-as-errors` passed, 11 tests, 0 failures.
- Task 1 web gate: `mix test test/cairnloop/web/token_drift_test.exs test/cairnloop/web/brand_token_gate_test.exs test/cairnloop/web/components_test.exs test/cairnloop/web/responsive_markup_test.exs test/cairnloop/web/motion_css_test.exs --warnings-as-errors` passed, 62 tests, 0 failures.
- Task 1 build: `mix compile --warnings-as-errors` passed.
- RED Task 2: `mix test test/cairnloop/docs_trust_test.exs --warnings-as-errors` failed as expected on stale health, Scrypath, troubleshooting, and telemetry docs.
- GREEN Task 2: `mix test test/cairnloop/docs_trust_test.exs --warnings-as-errors` passed, 8 tests, 0 failures.
- Task 2 focused: `mix test test/cairnloop/docs_trust_test.exs test/cairnloop/doctor_test.exs test/cairnloop/chat_telemetry_test.exs --warnings-as-errors` passed, 18 tests, 0 failures.
- Plan focused: `mix test test/cairnloop/doctor_test.exs test/cairnloop/web/health_plug_test.exs test/cairnloop/docs_trust_test.exs --warnings-as-errors` passed, 19 tests, 0 failures.
- Plan web gate: `mix test test/cairnloop/web/token_drift_test.exs test/cairnloop/web/brand_token_gate_test.exs test/cairnloop/web/components_test.exs test/cairnloop/web/responsive_markup_test.exs test/cairnloop/web/motion_css_test.exs --warnings-as-errors` passed, 62 tests, 0 failures.
- Build: `mix compile --warnings-as-errors` passed.
- Wave gate: `mix ci.fast` passed, 1140 tests, 0 failures, 62 excluded.
- Docs/package gate: `mix ci.quality` passed, including Credo, `mix hex.build`, ExDoc warnings-as-errors, and deps audit.
- Stale health claim scan: `rg -n "liveness/readiness|readiness probe|ready when the database|checks DB|checks Oban|checks pgvector|checks notifier|checks MCP|checks Scrypath" lib guides` returned no matches.

## Known Stubs

None. Stub scan found only intentional documentation about unsafe placeholder Scrypath config and an existing placeholder-id warning in router docs.

## Threat Flags

None - no new network endpoint, auth path, file access pattern, or schema trust boundary was introduced. The existing health plug and operations helper were documented more narrowly.

## User Setup Required

None - no external service configuration required. Hosts should run `mix cairnloop.doctor` to inspect their own trust/readiness posture.

## Next Phase Readiness

Phase 58 is complete from this plan's perspective: `/health` remains liveness-only, doctor carries the richer readiness/trust truth, and docs/source scans pin the same claims for adopters. Phase 60 can build on these docs without re-litigating the Phase 58 trust boundaries.

## Self-Check: PASSED

- Found all modified plan files on disk.
- Found task commits `35ac98e`, `d770bff`, `3b94c71`, and `3646c24` in git history.
- Verified plan-level focused tests, web gate, warnings-clean compile, `mix ci.fast`, and `mix ci.quality`.
- Confirmed the unrelated troubleshooting migration-prefix hunk remains unstaged.

---
*Phase: 58-identity-ingress-and-side-effect-trust*
*Completed: 2026-06-30*
