---
phase: 55-docker-first-adopter-docs
plan: "01"
subsystem: docs
tags: [docker, demo, quickstart, hexdocs, adopter-docs]

# Dependency graph
requires:
  - phase: 54-demo-wrapper-experience
    provides: Canonical ./bin/demo wrapper command vocabulary, dynamic URL printing, and smoke route proof.
provides:
  - README Docker-first first-run path aligned with ./bin/demo and current package version.
  - Quickstart Docker demo command vocabulary aligned with ./bin/demo help.
  - Secondary manual host-app setup guidance for Igniter, direct dependency install, and manual boot.
affects:
  - 55-docker-first-adopter-docs
  - 56-demo-smoke-ci-gate
  - HexDocs README and Quickstart extras

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Docker-first docs lead with ./bin/demo and printed URLs.
    - Manual local and host-app setup stay secondary to first-run evaluation.

key-files:
  created:
    - .planning/phases/55-docker-first-adopter-docs/55-01-SUMMARY.md
  modified:
    - README.md
    - guides/01-quickstart.md

key-decisions:
  - "Kept ./bin/demo as the first fresh-clone command in README and Quickstart."
  - "Updated touched dependency snippets to {:cairnloop, \"~> 0.5.1\"} from mix.exs."
  - "Documented the complete Phase 54 wrapper vocabulary in Quickstart instead of inventing alternate commands."

patterns-established:
  - "Docker URL guidance: docs tell adopters to open the URL printed by ./bin/demo."
  - "Wrapper command vocabulary: start/up, urls, logs, status/ps, stop, down, reset, smoke, and help."

requirements-completed: [DOC-01, DOC-04]

# Metrics
duration: 3m 19s
completed: 2026-06-28
status: complete
---

# Phase 55 Plan 01: README and Quickstart Docker-First Docs Summary

**README and Quickstart now tell the same Docker-first first-run story using ./bin/demo, printed URLs, current 0.5.1 dependency snippets, and secondary manual host-app setup.**

## Performance

- **Duration:** 3m 19s
- **Started:** 2026-06-28T19:27:46Z
- **Completed:** 2026-06-28T19:31:05Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Kept the README first-run path centered on `./bin/demo` before Igniter or manual setup.
- Updated README and Quickstart touched dependency examples from `~> 0.1.0` to `~> 0.5.1`.
- Expanded Quickstart wrapper commands to match Phase 54: default/start/up, urls, logs, status/ps, stop, down, reset, smoke, and help.
- Preserved the stop/down/reset volume distinction and kept `localhost:4000` tied to manual local Phoenix boot.

## Task Commits

Each task was committed atomically:

1. **Task 1: Keep README Docker-first and current-version consistent** - `756c008` (docs)
2. **Task 2: Align Quickstart command vocabulary and manual-path boundary** - `b0528ba` (docs)

**Plan metadata:** created in the final `docs(55-01)` summary commit.

## Files Created/Modified

- `README.md` - Host-app and manual install paths are secondary after Docker demo, touched dependency snippets use `~> 0.5.1`, and guide links point to Docker demo troubleshooting.
- `guides/01-quickstart.md` - Useful commands mirror `./bin/demo help`, volume semantics are explicit, host-app setup is secondary, touched dependency snippets use `~> 0.5.1`, and troubleshooting link copy covers Docker demo recovery.
- `.planning/phases/55-docker-first-adopter-docs/55-01-SUMMARY.md` - Plan completion record.

## Decisions Made

- Kept README edits narrow rather than adding a full command table there, because Quickstart is the detailed command reference and `./bin/demo help` remains source of truth.
- Treated the Quickstart `Install` section as the production host-app path and left manual boot as the local Phoenix path.
- Did not update `.planning/STATE.md` or `.planning/ROADMAP.md`; the execution request reserved shared tracking for the orchestrator after the wave.

## Verification

| Command | Status | Notes |
|---|---|---|
| `elixir -e 's=File.read!("README.md"); {d,_}=:binary.match(s,"### Try the live demo first"); {i,_}=:binary.match(s,"### Install in your app"); if d >= i, do: raise("README Docker demo heading must precede install heading")'` | PASS | README Docker demo heading precedes install heading. |
| `rg -n '\./bin/demo' README.md` | PASS | README contains the wrapper command and printed URL guidance. |
| `rg -n '\{:cairnloop, "~> 0\.5\.1"\}' README.md` | PASS | README touched dependency snippets use 0.5.1. |
| `sh -c 'if rg -n "~> 0\\.1\\.0" README.md; then exit 1; fi'` | PASS | No stale README 0.1.0 snippets remain. |
| `./bin/demo help` | PASS | Wrapper help printed start/up, smoke, urls, logs, stop, down, reset, ps/status, help, and environment variables. |
| `elixir -e 's=File.read!("guides/01-quickstart.md"); {d,_}=:binary.match(s,"## Fastest path: Docker demo"); {p,_}=:binary.match(s,"## Prerequisites"); if d >= p, do: raise("Quickstart Docker demo section must precede prerequisites")'` | PASS | Quickstart Docker demo section precedes prerequisites. |
| `rg -n 'start|up|urls|logs|status|ps|stop|down|reset|smoke|help' guides/01-quickstart.md` | PASS | Quickstart includes the required wrapper vocabulary. |
| `sh -c 'if rg -n "~> 0\\.1\\.0" guides/01-quickstart.md; then exit 1; fi'` | PASS | No stale Quickstart 0.1.0 snippets remain. |
| `mix ci.fast` | PASS | 1 doctest, 1067 tests, 0 failures, 57 excluded. |
| `mix ci.quality` | PASS | Credo found no issues; `mix hex.build`, docs with warnings as errors, and deps audit passed. |
| `rg -n '\./bin/demo|CAIRNLOOP_WEB_PORT|Troubleshooting' README.md guides/01-quickstart.md` | PASS | Docker command, dynamic port, and troubleshooting cross-link copy present. |
| `sh -c 'if rg -n "~> 0\\.1\\.0" README.md guides/01-quickstart.md; then exit 1; fi'` | PASS | No stale 0.1.0 snippets remain in plan-owned docs. |

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed.
**Impact on plan:** None.

## Issues Encountered

None. The worktree contained unrelated pre-existing modified and untracked files; they were left untouched and unstaged.

## Authentication Gates

None.

## Known Stubs

None found in the files modified by this plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 55-02 can update the example README against the same wrapper vocabulary and printed-URL guidance. Plan 55-03 can expand troubleshooting with Docker demo failure recovery and smoke workflow details.

## Self-Check

PASSED

- Found `.planning/phases/55-docker-first-adopter-docs/55-01-SUMMARY.md`.
- Found task commits `756c008` and `b0528ba` in git history.
- No stub patterns were found in `README.md`, `guides/01-quickstart.md`, or this summary.
- `.planning/STATE.md` and `.planning/ROADMAP.md` were not modified.

---
*Phase: 55-docker-first-adopter-docs*
*Completed: 2026-06-28*
