---
phase: 50-brandbook-scaffold-token-derivation-pipeline
plan: 01
subsystem: brandbook
tags: [brandbook, design-tokens, static-html, playwright, exunit]

requires:
  - phase: 48-token-evolution-lock-propagate
    provides: Refined canonical tokens and derivative token discipline
  - phase: 49-chosen-logo-finalization-asset-family
    provides: Logo usage source and Phase 51/52 asset handoff boundaries
provides:
  - Self-contained static brandbook scaffold that opens from file://
  - Generated token CSS and swatch JSON derived from priv/static/cairnloop.css
  - Automated derivation, source, package, and file-url browser verification gates
affects: [phase-51, phase-52, brandbook, design-tokens, collateral]

tech-stack:
  added: []
  patterns:
    - Repo-local mix run script for unshipped derived brand collateral
    - Generated token mirrors checked by byte-for-byte --check mode
    - File-url Playwright verification without Phoenix or package coupling

key-files:
  created:
    - scripts/derive_brandbook_tokens.exs
    - scripts/verify_brandbook_file_load.mjs
    - test/cairnloop/web/brandbook_scaffold_test.exs
    - brandbook/index.html
    - brandbook/TOKENS.md
    - brandbook/assets/css/tokens.css
    - brandbook/assets/css/brandbook.css
    - brandbook/color/swatches.json
    - brandbook/logo/.gitkeep
    - brandbook/raster/.gitkeep
  modified: []

key-decisions:
  - "Use scripts/derive_brandbook_tokens.exs as repo-local collateral tooling rather than a shipped Mix task."
  - "Keep swatches.json lean: grouped primitive/light/dark rows with resolved display hex, no contrast badge matrix."
  - "Verify direct file:// loading with the existing locked Playwright install under the example app instead of adding packages or Phoenix routing."

patterns-established:
  - "Brandbook token outputs are derived artifacts: edit priv/static/cairnloop.css, regenerate, then run --check."
  - "Unshipped brand collateral can have focused source/browser gates while remaining outside mix.exs package files."

requirements-completed: [BOOK-01, BOOK-02]

duration: 12min
completed: 2026-06-25
status: complete
---

# Phase 50 Plan 01: Brandbook Scaffold and Token Derivation Summary

**Offline static brandbook scaffold with deterministic token mirrors, provenance docs, and source/browser/package gates.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-06-25T17:49:00Z
- **Completed:** 2026-06-25T18:01:07Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments

- Created `scripts/derive_brandbook_tokens.exs`, which generates and checks `brandbook/assets/css/tokens.css` and `brandbook/color/swatches.json` from canonical `priv/static/cairnloop.css`.
- Added a compact `brandbook/index.html` scaffold with relative stylesheets, required Phase 50 copy, live token preview, type proof, light/dark token proof, and folder readiness list.
- Documented token provenance and drift prevention in `brandbook/TOKENS.md`.
- Added pure ExUnit source/package guards and a Playwright `file://` browser proof that captures console, page, request, and failed-request failures.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build the canonical token derivation script and generated mirrors** - `3f4211a` (feat)
2. **Task 2: Create the offline static brandbook scaffold and token provenance documentation** - `433ccdb` (feat)
3. **Task 3: Add source, package, and file-url browser verification gates** - `f5d3317` (test)

## Files Created/Modified

- `scripts/derive_brandbook_tokens.exs` - Repo-local Elixir generator/checker for brandbook token mirrors.
- `brandbook/assets/css/tokens.css` - Generated `:root` and `[data-theme="dark"]` `--cl-*` token mirror.
- `brandbook/color/swatches.json` - Generated grouped primitive/light/dark swatch data with provenance.
- `brandbook/index.html` - Static offline scaffold shell using only relative local CSS.
- `brandbook/assets/css/brandbook.css` - Scaffold-only layout CSS consuming derived `--cl-*` tokens.
- `brandbook/TOKENS.md` - Maintainer contract for canonical source, regeneration, checks, and package boundary.
- `brandbook/logo/.gitkeep` and `brandbook/raster/.gitkeep` - Tracked Phase 51/52 destination folders.
- `scripts/verify_brandbook_file_load.mjs` - File-url Playwright verification script using the existing locked install.
- `test/cairnloop/web/brandbook_scaffold_test.exs` - Async DB-free ExUnit guard for scaffold, provenance, drift, package, and dependency boundaries.

## Decisions Made

- Kept token derivation in `scripts/` so the helper remains repo-local collateral and does not enter the shipped `lib/` package surface.
- Used byte-for-byte generated-output comparison in `--check`; maintainers change canonical CSS, regenerate, then review the generated diff.
- Reused the existing Playwright install under `examples/cairnloop_example/assets/node_modules` rather than adding or upgrading Node dependencies.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The initial `--check` failed before generation because generated outputs were missing; this matched the planned RED behavior.
- `mix run scripts/derive_brandbook_tokens.exs` emits the repo's known Chimeway.Repo missing-database noise in this workspace, but the generator and check commands exit successfully.
- The first browser proof required the package-boundary label as a standalone text node; adjusted the verifier to assert body-text containment so the exact label can live in the footer provenance sentence.

## Verification

| Command | Result | Evidence |
| --- | --- | --- |
| `mix run scripts/derive_brandbook_tokens.exs --check` before generation | PASS expected failure | Failed on missing generated output with a clear rerun command. |
| `mix run scripts/derive_brandbook_tokens.exs && mix run scripts/derive_brandbook_tokens.exs --check` | PASS | Generated both outputs and reported token outputs current. |
| Deliberate edit to `brandbook/assets/css/tokens.css` then `--check` | PASS expected failure | Failed with generated output drift; restored file afterward. |
| Task 1 provenance and selector guards | PASS | Found required provenance strings; no `.cl-`, `.brandbook-`, or `@media` selectors in generated token CSS. |
| Task 2 scaffold/docs/scope guards | PASS | Required labels and TOKENS.md notes present; Phase 51/52 forbidden copy absent. |
| `mix test test/cairnloop/web/brandbook_scaffold_test.exs` | PASS | 7 tests, 0 failures. |
| `node scripts/verify_brandbook_file_load.mjs` | PASS | Opened `file:///Users/jon/projects/cairnloop/brandbook/index.html` with no console/page/request failures. |
| `mix compile --warnings-as-errors` | PASS | Command exited 0. |
| `mix test` | PASS | 1 doctest, 1037 tests, 0 failures, 57 excluded. |
| Package and remote-dependency guards | PASS | `brandbook/` absent from `mix.exs` files; no remote/root/import/iframe/beacon dependency in `brandbook/`. |
| Forbidden collateral diff guard | PASS | README, example app logo/root layout, `mix.exs`, CI, and example package files unchanged. |

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 51 can assemble the full HTML brand book using `brandbook/`, derived token artifacts, `brandbook/TOKENS.md`, `logo/USAGE.md`, and the Phase 48 contrast evidence. Phase 52 package and collateral wiring remain untouched and ready for the later wiring phase.

## Self-Check: PASSED

- Found all ten planned Phase 50 artifacts.
- Found task commits `3f4211a`, `433ccdb`, and `f5d3317`.
- Focused derivation, source, package, browser, compile, and full test gates passed.
- `brandbook/` remains git-tracked collateral and absent from `mix.exs` package files.

---
*Phase: 50-brandbook-scaffold-token-derivation-pipeline*
*Completed: 2026-06-25*
