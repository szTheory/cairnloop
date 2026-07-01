---
phase: 56-demo-smoke-ci-gate
plan: 01
subsystem: ci
tags: [github-actions, docker, compose, exunit, demo-smoke]

requires:
  - phase: 53-demo-runtime-contract
    provides: Docker demo runtime and Compose smoke contract
  - phase: 54-demo-wrapper-experience
    provides: Canonical ./bin/demo smoke wrapper behavior
  - phase: 55-docker-first-adopter-docs
    provides: Docker-first adopter documentation surface
provides:
  - Dedicated read-only Demo smoke GitHub Actions workflow
  - Symmetric push and pull_request path filters for demo-relevant drift
  - DB-free ExUnit workflow source contract in the fast CI lane
  - Tracked Docker build-context exclusions for the demo stack
affects: [demo-smoke, docker-demo, ci, adopter-dx, verification]

tech-stack:
  added: []
  patterns:
    - DB-free workflow source contract tests
    - Wrapper-owned Docker smoke behavior delegated from CI
    - Dedicated read-only workflow for demo proof

key-files:
  created:
    - .github/workflows/demo-smoke.yml
    - .dockerignore
    - test/cairnloop/demo_smoke_workflow_contract_test.exs
  modified: []

key-decisions:
  - "Kept Demo smoke as a separate read-only workflow so demo proof cannot mutate release state."
  - "Pinned workflow drift with a DB-free ExUnit source scan instead of adding a YAML parser dependency."
  - "Delegated runtime smoke behavior to ./bin/demo smoke rather than duplicating Compose or curl logic in workflow YAML."

patterns-established:
  - "Demo CI workflows use symmetric push and pull_request path filters for source that can break first-run Docker proof."
  - "Workflow source contracts assert forbidden release/secrets tokens inside the workflow source only."

requirements-completed: [VER-03, VER-04]

duration: 8 min
completed: 2026-06-28
status: complete
---

# Phase 56 Plan 01: Demo Smoke CI Gate Summary

**Dedicated read-only GitHub Actions workflow runs `./bin/demo smoke` for demo-relevant changes, with a DB-free ExUnit contract test guarding workflow drift.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-06-28T21:45:00Z
- **Completed:** 2026-06-28T21:53:19Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added `Cairnloop.DemoSmokeWorkflowContractTest`, a DB-free async ExUnit source scan that pins triggers, path filters, permissions, timeout, Docker preflight, and the exact `run: ./bin/demo smoke` command.
- Hardened `.github/workflows/demo-smoke.yml` with `workflow_dispatch`, weekly schedule, push on `main`/`master`, and symmetric `pull_request` filters for the locked demo-relevant path list.
- Tracked `.dockerignore` so generated Mix/docs/coverage/temp/example asset outputs stay out of the Docker build context while source and docs inputs remain available.
- Verified the full Docker smoke path locally; the isolated stack reached `/health` and passed every locked route check.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the workflow source contract test** - `54ab19f` (test)
2. **Task 2: Harden demo-smoke workflow and Docker context** - `7da6492` (ci)

**Plan metadata:** committed with this summary.

## Files Created/Modified

- `.github/workflows/demo-smoke.yml` - Dedicated read-only Demo smoke workflow with manual, scheduled, push, and pull request triggers.
- `.dockerignore` - Docker build-context exclusions for generated artifacts and local agent/cache state.
- `test/cairnloop/demo_smoke_workflow_contract_test.exs` - DB-free workflow source contract included in `mix ci.fast`.

## Decisions Made

- Kept the workflow separate from release publishing and limited permissions to `contents: read`.
- Used source assertions rather than a YAML parser package, matching existing DB-free contract test patterns.
- Preserved wrapper ownership of smoke behavior; workflow YAML only checks Docker/Compose versions and runs `./bin/demo smoke`.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** No scope change.

## Issues Encountered

- The first RED-check shell wrapper used `status` as a zsh variable name after the intended failing test output; rerunning the same command under bash produced the expected clean RED verification. No source changes were needed for this.

## Verification

- `mix test test/cairnloop/demo_smoke_workflow_contract_test.exs --warnings-as-errors` - passed, 3 tests, 0 failures.
- `mix ci.fast` - passed, 1 doctest and 1074 tests, 0 failures.
- `mix compile --warnings-as-errors` - passed.
- `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` - passed.
- `./bin/demo smoke` - passed; `/`, `/support`, `/support/inbox`, `/chat`, `/support/knowledge-base`, `/support/knowledge-base/gaps`, `/support/knowledge-base/suggestions`, `/support/audit-log`, and `/support/settings` all returned ok.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 56 verification is automated and complete. The Demo smoke check is branch-protection-ready under the stable `demo-smoke` job name; configuring branch protection remains outside this repository phase.

---
*Phase: 56-demo-smoke-ci-gate*
*Completed: 2026-06-28*
