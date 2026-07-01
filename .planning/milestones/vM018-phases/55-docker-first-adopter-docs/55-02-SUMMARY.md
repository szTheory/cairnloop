---
phase: 55-docker-first-adopter-docs
plan: "02"
subsystem: docs
tags: [docker, demo, docs, phoenix, smoke]

requires:
  - phase: 54-demo-wrapper-experience
    provides: Canonical ./bin/demo command surface, dynamic printed URLs, smoke route list, and volume semantics.
  - phase: 53-demo-runtime-contract
    provides: Example app routes, /health readiness, seeded Trailmark data, and real customer chat ingress.
provides:
  - Example README Docker-first Demo Index and Two-Tab Demo guidance.
  - Example README wrapper command vocabulary with stop/down/reset volume semantics.
  - Example README local isolated HTTP smoke and locked route inventory documentation.
affects: [phase-55-docs, phase-56-demo-smoke-ci, example-readme]

tech-stack:
  added: []
  patterns:
    - Docker-facing docs use the base URL printed by ./bin/demo instead of fixed localhost ports.
    - http://localhost:4000 appears only in manual local Phoenix context.
    - Smoke is documented as local HTTP route coverage, not browser E2E or CI workflow wiring.

key-files:
  created:
    - .planning/phases/55-docker-first-adopter-docs/55-02-SUMMARY.md
  modified:
    - examples/cairnloop_example/README.md

key-decisions:
  - "Kept the example README scoped to adopter docs only; no wrapper, router, runtime, screenshot, or UI changes were introduced."
  - "Used ./bin/demo help and the Phase 54 route list as the command and route source of truth."

patterns-established:
  - "Nested example README mirrors ./bin/demo command vocabulary when it lists demo operations."
  - "Nested example README gives Docker users printed-base-URL instructions before manual localhost examples."

requirements-completed:
  - DOC-02
  - DOC-04

duration: 3 min
completed: 2026-06-28
status: complete
---

# Phase 55 Plan 02: Example README Docker Docs Summary

**Example-app README now sends Docker adopters through ./bin/demo printed URLs with canonical command, volume, smoke, and route guidance.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-28T19:27:58Z
- **Completed:** 2026-06-28T19:30:58Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Reworked Demo Index, Two-Tab Demo, and Routing copy so Docker users start from the URL printed by `./bin/demo` and append route paths.
- Kept `http://localhost:4000` examples explicitly scoped to the manual local Phoenix path after `mix setup && mix phx.server`.
- Expanded example README command, volume, smoke, and route guidance to match the Phase 54 wrapper contract.

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite example Demo Index and Two-Tab flow around printed URLs** - `b4f88a4` (docs)
2. **Task 2: Align example command semantics and route inventory** - `9dc612a` (docs)

**Plan metadata:** committed separately by `docs(55-02): complete example README Docker docs plan`.

## Files Created/Modified

- `examples/cairnloop_example/README.md` - Docker-aware example README flow, command semantics, smoke wording, and route inventory.
- `.planning/phases/55-docker-first-adopter-docs/55-02-SUMMARY.md` - Plan execution summary.

## Decisions Made

- Kept the change docs-only and did not modify `bin/demo`, router code, screenshots, runtime behavior, UI files, or CI workflows.
- Mirrored the command vocabulary and route list from `./bin/demo help`, `bin/demo`, and Phase 54 verification rather than inventing a separate docs-only command surface.

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope changes.

## Issues Encountered

None. `mix ci.fast` emitted existing test warning/log output but passed with 1 doctest, 1067 tests, 0 failures, and 57 excluded.

## Verification

| Command | Status | Notes |
|---|---:|---|
| `elixir -e 's=File.read!("examples/cairnloop_example/README.md"); Enum.each(["Operator inbox:** http://localhost:4000/support","Customer chat:** http://localhost:4000/chat","Visit [`localhost:4000/support`","Visit [`localhost:4000/chat`"], fn bad -> if String.contains?(s,bad), do: raise("stale primary hard-coded URL: #{bad}") end); unless String.contains?(s,"printed") and String.contains?(s,"/support") and String.contains?(s,"/chat"), do: raise("missing printed URL route guidance")'` | PASS | No stale primary hard-coded Docker URL guidance remained. |
| `rg -n 'printed|/support|/chat|manual local|localhost:4000' examples/cairnloop_example/README.md` | PASS | Remaining localhost hits are manual-local Phoenix context. |
| `./bin/demo help` | PASS | Help lists start/up, smoke, urls, logs, stop, down, reset, ps/status, and help. |
| `elixir -e 's=File.read!("examples/cairnloop_example/README.md"); Enum.each(["./bin/demo","urls","logs","status","ps","stop","down","reset","smoke","help"], fn token -> unless String.contains?(s,token), do: raise("missing command token #{token}") end)'` | PASS | README contains all wrapper command tokens and aliases required by the plan. |
| `elixir -e 's=File.read!("examples/cairnloop_example/README.md"); Enum.each(["/support","/support/inbox","/chat","/support/knowledge-base","/support/knowledge-base/gaps","/support/knowledge-base/suggestions","/support/audit-log","/support/settings"], fn route -> unless String.contains?(s,route), do: raise("missing route #{route}") end)'` | PASS | README contains the locked route inventory. |
| `rg -n 'localhost:4000' examples/cairnloop_example/README.md` | PASS | Hits are under manual local Phoenix context at lines 84, 104-105, and 157-158. |
| `mix ci.fast` | PASS | 1 doctest, 1067 tests, 0 failures, 57 excluded. |
| `rg -n 'not available|coming soon|placeholder|TODO|FIXME|=\[\]|=\{\}|=null|=""' examples/cairnloop_example/README.md` | PASS | No stub patterns found; `rg` exited 1 because there were no matches. |

## Known Stubs

None.

## Threat Surface Scan

No new endpoints, auth paths, file access patterns, schema changes, package installs, or runtime trust boundaries were introduced. The README changes mitigate the plan's documentation threats by using printed Docker URLs, wrapper command vocabulary, volume semantics, and bounded smoke/log wording.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 55-02 is ready for downstream Phase 55 docs validation. The orchestrator owns shared `STATE.md` and `ROADMAP.md` tracking for this wave.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/55-docker-first-adopter-docs/55-02-SUMMARY.md`.
- Task commits `b4f88a4` and `9dc612a` exist in git history.
- `examples/cairnloop_example/README.md` contains printed URL guidance, full wrapper command vocabulary, and locked route coverage.

---
*Phase: 55-docker-first-adopter-docs*
*Completed: 2026-06-28*
