---
phase: 60-installer-docs-upgrade-and-oss-trust
plan: "02"
subsystem: docs
tags: [installer, docs, upgrade, schema-prefix, source-scan]
requires:
  - phase: 60-01
    provides: DB-free install/upgrade truth source-scan guardrails
  - phase: 59
    provides: Dedicated `cairnloop` schema default and explicit public compatibility
  - phase: 58
    provides: Host-owned ingress, doctor, liveness, and side-effect trust boundaries
provides:
  - Docker-first README and Quickstart install story aligned with live installer output
  - Host Integration, Troubleshooting, and example README schema-prefix convergence
  - Concrete UPGRADING compatibility, data-move, verification, and rollback guidance
  - Stronger DB-free install/upgrade docs source-scan coverage
affects: [phase-60, installer-docs, upgrade-docs, schema-prefix, public-docs]
tech-stack:
  added: []
  patterns:
    - DB-free ExUnit source scans pin public docs to installer and schema-prefix truth
    - TDD doc rewrites use red source-scan assertions before public copy changes
key-files:
  created:
    - .planning/phases/60-installer-docs-upgrade-and-oss-trust/60-02-SUMMARY.md
  modified:
    - README.md
    - guides/01-quickstart.md
    - guides/03-host-integration.md
    - guides/04-troubleshooting.md
    - UPGRADING.md
    - examples/cairnloop_example/README.md
    - test/cairnloop/docs/install_upgrade_truth_test.exs
key-decisions:
  - "Public install docs mirror the live installer: host migrations first, Cairnloop dependency migrations second, and no dependency migration `--prefix cairnloop` shortcut."
  - "Existing public-schema installs are documented with explicit `schema_prefix: \"public\"`; legacy nil is not recommended in public docs."
  - "UPGRADING documents a manual maintenance-window data move rather than promising package-owned relocation of existing public tables."
patterns-established:
  - "README and Quickstart include a practical 'When not to use Cairnloop' boundary near the first-success path."
  - "Host Integration now carries host-owned route auth, operator identity, repo, Oban, secrets, monitoring, and deployment responsibilities."
requirements-completed: [DOC-01, DOC-02, DOC-03, DOC-05, DOC-06]
requirements-addressed: [DOC-01, DOC-02, DOC-03, DOC-05, DOC-06]
duration: 6 min
completed: 2026-06-30
status: complete
---

# Phase 60 Plan 02: Installer Docs Upgrade Summary

**Public install and upgrade docs now tell one Docker-first, installer-aligned, schema-prefix-aware adoption story.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-06-30T19:21:33Z
- **Completed:** 2026-06-30T19:27:45Z
- **Tasks:** 3
- **Files modified:** 7 plan files plus this summary

## Accomplishments

- Reworked README and Quickstart around the Docker demo first, then the Igniter host-app install path.
- Added practical "When not to use Cairnloop" copy and public production responsibility notes.
- Replaced stale `schema_prefix: nil` recommendations with explicit `"public"` compatibility.
- Removed public dependency-migration `--prefix cairnloop` commands and aligned migration order with the installer.
- Added Host Integration and example README schema-prefix guardrails and public docs copy.
- Expanded `UPGRADING.md` with a compatibility matrix, manual data-move outline, verification checklist, shared `vector` posture, and rollback limits.

## Task Commits

1. **Task 1: README and Quickstart Docker-first install rewrite** - `acb88f6` (docs)
2. **Task 2 RED: host integration/example docs guardrail** - `01209a8` (test)
3. **Task 2 GREEN: host integration/example docs alignment** - `1e8502d` (docs)
4. **Task 3 RED: upgrade compatibility/data-move guardrail** - `5b0d3ff` (test)
5. **Task 3 GREEN: upgrade prefix guidance** - `ac27978` (docs)

## Files Created/Modified

- `README.md` - Public front door now includes fit/non-fit boundaries, Docker-first path, installer-aligned schema-prefix config, and production responsibility notes.
- `guides/01-quickstart.md` - Docker-first quickstart now uses explicit `"public"` compatibility and dependency migrations without `--prefix`.
- `guides/03-host-integration.md` - Adds host-owned install boundary and schema-prefix settings.
- `guides/04-troubleshooting.md` - Removes stale `nil`/dependency-prefix guidance and points to installer-aligned commands.
- `UPGRADING.md` - Adds compatibility matrix, manual migration checks, rollback posture, Oban boundary, and shared `vector` posture.
- `examples/cairnloop_example/README.md` - Documents the example app dogfooding `schema_prefix: "cairnloop"` and explicit public compatibility.
- `test/cairnloop/docs/install_upgrade_truth_test.exs` - Adds Task 2 and Task 3 source-scan guardrails.

## Verification

- PASS: `mix test test/cairnloop/docs/install_upgrade_truth_test.exs --warnings-as-errors` (9 tests, 0 failures)
- PASS: `mix test test/cairnloop/docs/install_upgrade_truth_test.exs test/cairnloop/tasks/install_test.exs --warnings-as-errors` (14 tests, 0 failures)
- PASS: `mix test test/cairnloop/docs/install_upgrade_truth_test.exs test/cairnloop/docs/docker_first_docs_test.exs test/cairnloop/demo_runtime_contract_test.exs --warnings-as-errors` (16 tests, 0 failures)
- PASS: `mix test test/cairnloop/docs/install_upgrade_truth_test.exs test/cairnloop/tasks/install_test.exs test/cairnloop/docs/docker_first_docs_test.exs test/cairnloop/demo_runtime_contract_test.exs --warnings-as-errors` (24 tests, 0 failures)

## Decisions Made

- Kept the Docker demo as the first success path and made the host-app install path secondary.
- Treated `"public"` as the public compatibility setting and kept legacy `nil` out of recommendation copy.
- Documented public-to-dedicated moves as host-owned maintenance-window work with explicit verification, not a package-automated migration.

## TDD Gate Compliance

- Task 1 used the existing Wave 0 RED guardrail from Plan 60-01, as requested by the executor prompt, and produced the GREEN docs commit `acb88f6`.
- Task 2 produced RED commit `01209a8` and GREEN commit `1e8502d`.
- Task 3 produced RED commit `5b0d3ff` and GREEN commit `ac27978`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed Troubleshooting during Task 1 verification**
- **Found during:** Task 1 focused verification.
- **Issue:** Task 1's required test command scans all public install docs, so stale Troubleshooting `schema_prefix: nil` and dependency `--prefix cairnloop` lines blocked Task 1 even though Troubleshooting was listed under Task 2.
- **Fix:** Updated only the stale Troubleshooting migration/prefix lines in the Task 1 commit so the required global guardrail could pass.
- **Files modified:** `guides/04-troubleshooting.md`
- **Verification:** `mix test test/cairnloop/docs/install_upgrade_truth_test.exs test/cairnloop/docs/docker_first_docs_test.exs test/cairnloop/demo_runtime_contract_test.exs --warnings-as-errors`
- **Committed in:** `acb88f6`

---

**Total deviations:** 1 auto-fixed (Rule 3: blocking plan/test inconsistency).
**Impact on plan:** Narrow supporting edit only; it implemented Task 2's stale Troubleshooting acceptance early without broadening scope.

## Issues Encountered

- The phase was executed in a dirty checkout with unrelated and parallel 60-03 changes. Only 60-02 files and this summary were staged for this plan.
- A broader Wave gate was intentionally not run because Plan 60-04 owns post-Wave 1 `mix ci.fast` and `mix ci.quality` after 60-02 and 60-03 converge.

## Known Stubs

None. Stub scan hits were limited to intentional documentation about unsafe placeholder Scrypath config and test guardrail strings.

## Threat Flags

None. This plan changed public docs and DB-free source-scan tests only; it introduced no new endpoint, auth path, file access pattern, or schema boundary.

## User Setup Required

None.

## Next Phase Readiness

Plan 60-02 is complete. Public install and upgrade docs are ready for Plan 60-04's post-Wave 1 verification once Plan 60-03's package/security docs work is merged.

## Self-Check: PASSED

- Found all modified plan files on disk.
- Found task commits `acb88f6`, `01209a8`, `1e8502d`, `5b0d3ff`, and `ac27978` in git history.
- Verified plan-owned files are clean after task commits before writing this summary.
- Verified `.planning/STATE.md` and `.planning/ROADMAP.md` were not updated by this plan.

---
*Phase: 60-installer-docs-upgrade-and-oss-trust*
*Completed: 2026-06-30*
