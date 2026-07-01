---
phase: 52-collateral-wiring-qa-validation-sweep
plan: 02
subsystem: example-app-collateral
tags: [phoenix, static-assets, logo, favicon, open-graph, playwright, e2e]

requires:
  - phase: 52-collateral-wiring-qa-validation-sweep
    provides: "52-01 sign-off record, README wiring, and static source guard"
  - phase: 49-chosen-logo-finalization-asset-family
    provides: "Approved logo, favicon, and OG assets"
provides:
  - "Approved logo, favicon, SVG favicon, and OG raster copied into the example app static tree"
  - "Root title, favicon, and Open Graph metadata wired through local Phoenix static paths"
  - "Focused Playwright E2E proving rendered logo dimensions and static asset fetches"
  - "Extended static guard covering copied runtime assets and metadata source"
affects: [phase-52, example-app, collateral-wiring, release-qa]

tech-stack:
  added: []
  patterns:
    - "Example app collateral is copied byte-for-byte from logo/ sources and verified by DB-free tests"
    - "Rendered collateral proof uses PhoenixTest.Playwright.Case with explicit DOM, image, and fetch preconditions"

key-files:
  created:
    - examples/cairnloop_example/priv/static/images/favicon.svg
    - examples/cairnloop_example/priv/static/images/cairnloop-og.png
    - examples/cairnloop_example/test/e2e/collateral_wiring_test.exs
    - .planning/phases/52-collateral-wiring-qa-validation-sweep/52-02-SUMMARY.md
  modified:
    - examples/cairnloop_example/priv/static/images/logo.svg
    - examples/cairnloop_example/priv/static/favicon.ico
    - examples/cairnloop_example/lib/cairnloop_example_web/components/layouts/root.html.heex
    - examples/cairnloop_example/lib/cairnloop_example_web/components/layouts.ex
    - examples/cairnloop_example/lib/cairnloop_example_web/controllers/page_html/home.html.heex
    - test/cairnloop/web/collateral_wiring_test.exs

key-decisions:
  - "Example app collateral uses existing priv/static and verified/static path mechanics; no routes, Plugs, dependencies, or static path allowlist changes were added."
  - "The approved logo is rendered on the existing homepage header because the generated Layouts.app header is not used by current example routes."
  - "The E2E inspects root metadata on / and uses /chat for the LiveView connected-page precondition before static asset fetch checks."

patterns-established:
  - "Browser collateral tests prove nonzero rendered box and natural image dimensions, then fetch every copied static asset URL."
  - "Static guard checks copied runtime collateral byte equality and source-level metadata in the normal mix test lane."

requirements-completed: [WIRE-01, WIRE-03, HYGIENE-01, HYGIENE-02]

duration: 7 min
completed: 2026-06-26
status: complete
---

# Phase 52 Plan 02: Example App Collateral Wiring Summary

**Approved logo, favicon, and OG collateral wired into the Phoenix example app with Playwright browser proof**

## Performance

- **Duration:** 7 min
- **Started:** 2026-06-26T02:57:00Z
- **Completed:** 2026-06-26T03:03:50Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Copied the approved horizontal lockup, favicon ICO, SVG favicon, and OG PNG into the example app static tree.
- Updated root document title, favicon links, and Open Graph metadata to use local Phoenix static paths and exact Phase 52 copy.
- Updated example app logo markup with `alt="Cairnloop"` and removed Phoenix version text from the logo cluster.
- Added the approved logo to the existing homepage header after the browser test exposed that `Layouts.app` is not rendered by current routes.
- Extended `Cairnloop.Web.CollateralWiringTest` and added `CairnloopExampleWeb.CollateralWiringE2ETest`.

## Task Commits

Task work was committed atomically:

1. **Task 1: Copy approved assets and wire example app metadata** - `583b55f` (`feat`)
2. **Task 2 auto-fix: Render approved logo on example home** - `45cf8c6` (`fix`)
3. **Task 2: Extend static guard and add collateral Playwright E2E** - `c132295` (`test`)

## Files Created/Modified

- `examples/cairnloop_example/priv/static/images/logo.svg` - Byte-for-byte copy of `logo/cairnloop-lockup-horizontal.svg`.
- `examples/cairnloop_example/priv/static/favicon.ico` - Byte-for-byte copy of `logo/favicon.ico`.
- `examples/cairnloop_example/priv/static/images/favicon.svg` - Byte-for-byte copy of `logo/favicon.svg`.
- `examples/cairnloop_example/priv/static/images/cairnloop-og.png` - Byte-for-byte copy of `logo/cairnloop-og.png`.
- `examples/cairnloop_example/lib/cairnloop_example_web/components/layouts/root.html.heex` - Root title, favicon links, and OG metadata.
- `examples/cairnloop_example/lib/cairnloop_example_web/components/layouts.ex` - Accessible logo image and no Phoenix version text in the logo cluster.
- `examples/cairnloop_example/lib/cairnloop_example_web/controllers/page_html/home.html.heex` - Visible approved logo on the rendered homepage.
- `test/cairnloop/web/collateral_wiring_test.exs` - Runtime copied asset, metadata, E2E source, and raster budget coverage.
- `examples/cairnloop_example/test/e2e/collateral_wiring_test.exs` - Browser proof for logo dimensions, metadata, and asset fetch status.

## Decisions Made

- Kept all asset delivery inside existing Phoenix `priv/static` paths.
- Split browser proof between `/` for visible logo/root metadata and `/chat` for a LiveView connected-page precondition.
- Added no dependencies, routes, Plugs, CI jobs, static path entries, or package-surface changes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Rendered homepage needed the approved logo**
- **Found during:** Task 2 (collateral Playwright E2E)
- **Issue:** The initial E2E could not find `img[alt="Cairnloop"]` on `/` because the generated `Layouts.app` header is not used by the current homepage template.
- **Fix:** Added the approved `~p"/images/logo.svg"` image to the existing homepage header and retained the calm live-demo label.
- **Files modified:** `examples/cairnloop_example/lib/cairnloop_example_web/controllers/page_html/home.html.heex`
- **Verification:** Focused E2E passed after the fix.
- **Committed in:** `45cf8c6`

---

**Total deviations:** 1 auto-fixed (missing critical).
**Impact on plan:** The fix made WIRE-01/WIRE-03 real in the rendered example app without adding routes, dependencies, or a new asset service.

## Issues Encountered

- The first focused E2E failed because `/` did not render the logo. Fixed as documented above.

## Verification Evidence

- `cmp -s logo/cairnloop-lockup-horizontal.svg examples/cairnloop_example/priv/static/images/logo.svg` - PASS.
- `cmp -s logo/favicon.ico examples/cairnloop_example/priv/static/favicon.ico` - PASS.
- `cmp -s logo/favicon.svg examples/cairnloop_example/priv/static/images/favicon.svg` - PASS.
- `cmp -s logo/cairnloop-og.png examples/cairnloop_example/priv/static/images/cairnloop-og.png` - PASS.
- `mix compile --warnings-as-errors` - PASS.
- `cd examples/cairnloop_example && mix compile --warnings-as-errors` - PASS.
- `mix test test/cairnloop/web/collateral_wiring_test.exs` - PASS; 8 tests, 0 failures.
- `cd examples/cairnloop_example && mix test.e2e test/e2e/collateral_wiring_test.exs` - PASS; 1 test, 0 failures.
- `du -ck logo/*.png logo/*.ico examples/cairnloop_example/priv/static/favicon.ico examples/cairnloop_example/priv/static/images/cairnloop-og.png` - PASS; total source/runtime raster footprint is 128KB, under the 150KB budget.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 03 can run the full automated QA sweep, package unpack proof, diff-scope evidence, and final no-human-rendered-verification closeout.

## Self-Check: PASSED

- Found all copied static assets and E2E/source guard files on disk.
- Found task commits `583b55f`, `45cf8c6`, and `c132295`.
- Focused static and E2E checks passed after the homepage logo fix.
- Confirmed no changes to `CairnloopExampleWeb.static_paths/0` or `Endpoint` static serving.

---
*Phase: 52-collateral-wiring-qa-validation-sweep*
*Completed: 2026-06-26*
