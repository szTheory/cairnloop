---
phase: 52-collateral-wiring-qa-validation-sweep
plan: 01
subsystem: brand-collateral
tags: [readme, logo, svg, raster, package-hygiene, static-tests]

requires:
  - phase: 49-chosen-logo-finalization-asset-family
    provides: "Approved logo, favicon, OG raster, and usage inventory"
provides:
  - "Logo-family sign-off record before collateral wiring"
  - "README header wired to the approved horizontal SVG logo"
  - "DB-free collateral source guard for README, logo inventory, SVG safety, raster budget, and package allowlist"
affects: [phase-52, collateral-wiring, release-qa]

tech-stack:
  added: []
  patterns:
    - "DB-free ExUnit source guard for static collateral and package-boundary assertions"
    - "README brand header uses repo-relative SVG collateral while keeping Hex package policy unchanged"

key-files:
  created:
    - .planning/phases/52-collateral-wiring-qa-validation-sweep/52-LOGO-FAMILY-SIGNOFF.md
    - test/cairnloop/web/collateral_wiring_test.exs
    - .planning/phases/52-collateral-wiring-qa-validation-sweep/52-01-SUMMARY.md
  modified:
    - README.md

key-decisions:
  - "Owner approved the committed Phase 49 logo family for Phase 52 wiring before README or example-app collateral edits."
  - "README uses logo/cairnloop-lockup-horizontal.svg as the first visible line with exact alt text Cairnloop and keeps badges directly below."
  - "Collateral source hygiene is enforced in a DB-free ExUnit module rather than a rendered human verification task."

patterns-established:
  - "Static collateral tests use git ls-files '*.svg' plus xmllint and explicit safe-subset scans so new committed SVGs enter the gate automatically."
  - "Package-boundary tests assert the exact Hex files allowlist and keep brandbook/, logo/, and scripts/ unshipped."

requirements-completed: [WIRE-02, HYGIENE-01, HYGIENE-02, HYGIENE-03]

duration: 3 min
completed: 2026-06-26
status: complete
---

# Phase 52 Plan 01: Collateral Source Guard Summary

**README logo wiring plus DB-free collateral source guard for SVG, raster, and package hygiene**

## Performance

- **Duration:** 3 min
- **Started:** 2026-06-26T02:53:56Z
- **Completed:** 2026-06-26T02:56:46Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Recorded the Phase 52 logo-family sign-off before any collateral surface edits.
- Replaced the old README emoji H1 with the approved repo-relative horizontal SVG logo and exact `alt="Cairnloop"`.
- Added `Cairnloop.Web.CollateralWiringTest`, a DB-free static guard covering README placement, approved logo inventory, all tracked SVG XML/safe-subset rules, source raster budget, and the Hex package files allowlist.

## Task Commits

Each task was committed atomically:

1. **Task 1: Record logo-family sign-off before collateral edits** - `21afc94` (`docs`)
2. **Task 2: Wire the restrained README logo header** - `2ab1eee` (`docs`)
3. **Task 3: Add DB-free collateral source and hygiene guard** - `21dcea2` (`test`)

## Files Created/Modified

- `.planning/phases/52-collateral-wiring-qa-validation-sweep/52-LOGO-FAMILY-SIGNOFF.md` - Owner approval record and automated-verification policy.
- `README.md` - First visible line now uses `logo/cairnloop-lockup-horizontal.svg` with `alt="Cairnloop"` and width `260`.
- `test/cairnloop/web/collateral_wiring_test.exs` - Static collateral, SVG, raster, and package-boundary guard.

## Decisions Made

- Treated the user's Phase 52 approval as the required subjective logo-family sign-off.
- Kept README treatment restrained and OSS-native: logo, existing badges, then existing install/docs content.
- Used `git ls-files '*.svg'` in the static guard so future committed SVGs are included automatically.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The plan's Ruby README check initially hit the local asdf guard because no Ruby version is set for this repo. Re-running the same check with `ASDF_RUBY_VERSION=3.3.4` passed.

## Verification Evidence

- `ASDF_RUBY_VERSION=3.3.4 ruby -e '...'` - PASS; README first visible line is the approved logo, badges remain directly below, and the old emoji identity is absent.
- `mix test test/cairnloop/web/collateral_wiring_test.exs` - PASS; 5 tests, 0 failures.
- `xmllint --noout $(git ls-files '*.svg')` - PASS.
- `du -ck logo/*.png logo/*.ico` - PASS; total source raster footprint is 68KB, under the 150KB budget.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 02 can copy the approved assets into the example app and extend `Cairnloop.Web.CollateralWiringTest` for runtime collateral and browser E2E coverage.

## Self-Check: PASSED

- Found all created files on disk.
- Found task commits `21afc94`, `2ab1eee`, and `21dcea2`.
- Re-ran the focused source guard after formatting and it passed.
- Confirmed the plan-level SVG and raster commands passed.

---
*Phase: 52-collateral-wiring-qa-validation-sweep*
*Completed: 2026-06-26*
