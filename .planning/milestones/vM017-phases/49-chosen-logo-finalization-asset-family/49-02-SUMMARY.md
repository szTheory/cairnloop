---
phase: 49-chosen-logo-finalization-asset-family
plan: 02
subsystem: brand-assets
tags: [logo, favicon, og-image, imagemagick, svg]

requires:
  - phase: 47-brand-direction-exploration-selection-gate
    provides: "Locked C3.6 crowning-loop cairn direction, Refined palette, and current type stack"
  - phase: 48-token-evolution-lock-propagate
    provides: "Canonical refined brand tokens and contrast evidence"
provides:
  - "LOGO-05 simplified favicon SVG plus 16px PNG, 32px PNG, and 16/32 ICO exports"
  - "LOGO-05 1200x630 OG/social SVG master and compressed PNG export"
  - "Raster budget and package-hygiene evidence for Phase 49"
affects: [brandbook, collateral-wiring, phase-51, phase-52]

tech-stack:
  added: []
  patterns:
    - "Hand-authored standalone SVG masters with no external refs or embedded raster"
    - "ImageMagick-only raster export for favicon and OG deliverables"

key-files:
  created:
    - logo/favicon.svg
    - logo/favicon-16.png
    - logo/favicon-32.png
    - logo/favicon.ico
    - logo/cairnloop-og.svg
    - logo/cairnloop-og.png
  modified: []

key-decisions:
  - "Use a separately-authored 32px-viewBox favicon reduction rather than scaling a future production mark."
  - "Use a trailpaper OG card with restrained copper accents, C3.6 mark, wordmark, product line, and secondary tagline."
  - "Keep logo/ and brandbook/ out of mix.exs package files for this plan."

patterns-established:
  - "SVG ring geometry uses filled donut paths instead of stroked circles so ImageMagick and browser/social renderers agree."

requirements-completed: [LOGO-05]

duration: 4min
completed: 2026-06-25
status: complete
---

# Phase 49 Plan 02: LOGO-05 Small-Size and Social Assets Summary

**Simplified C3.6 favicon and 1200x630 OG/social card assets with ImageMagick raster exports under a 32KB committed raster footprint.**

## Performance

- **Duration:** 4min
- **Started:** 2026-06-25T15:13:47Z
- **Completed:** 2026-06-25T15:17:00Z
- **Tasks:** 3
- **Files modified:** 6 asset files plus this summary

## Accomplishments

- Created `logo/favicon.svg` as a separately-authored small-size reduction: compact copper ring, two flattened stones, transparent background, no cage.
- Exported `logo/favicon-16.png`, `logo/favicon-32.png`, and `logo/favicon.ico` with 16px and 32px entries only.
- Created `logo/cairnloop-og.svg` and `logo/cairnloop-og.png` as a solid trailpaper 1200x630 social card with C3.6 mark, wordmark, approved product line, and secondary tagline.
- Verified the exact raster set totals 32KB, below the 150KB Phase 49 budget.
- Confirmed `mix.exs` package files remain `lib priv guides mix.exs README.md LICENSE CHANGELOG.md`.

## Task Commits

1. **Task 1: Author simplified favicon SVG and raster exports** - `0556980` (feat)
2. **Task 2: Author OG/social SVG master and PNG export** - `5c93bf5` (feat)
3. **Task 3: Enforce raster budget and package hygiene** - `95f8d9c` (chore, empty verification commit)

## Files Created/Modified

- `logo/favicon.svg` - Clean standalone transparent SVG favicon source.
- `logo/favicon-16.png` - 16x16 favicon raster export.
- `logo/favicon-32.png` - 32x32 favicon raster export.
- `logo/favicon.ico` - ICO containing 16px and 32px entries.
- `logo/cairnloop-og.svg` - 1200x630 OG/social SVG master.
- `logo/cairnloop-og.png` - 1200x630 compressed PNG social preview.

## Decisions Made

- Used explicit filled donut paths for the copper ring so raster and SVG renderers preserve the selected ring-as-top-stone concept.
- Kept the OG card on solid trailpaper with copper only as a restrained accent, matching D-49-12.
- Included the tagline because it remained legible as secondary copy at the 1200x630 target size.

## Verification Evidence

### ImageMagick Identify

```text
logo/favicon-16.png PNG 16x16 16x16+0+0 16-bit sRGB 1119B 0.000u 0:00.001
logo/favicon-32.png PNG 32x32 32x32+0+0 8-bit sRGB 598B 0.000u 0:00.000
logo/favicon.ico[0] ICO 16x16 16x16+0+0 8-bit sRGB 0.000u 0:00.000
logo/favicon.ico[1] ICO 32x32 32x32+0+0 8-bit sRGB 3382B 0.000u 0:00.000
logo/cairnloop-og.png PNG 1200x630 1200x630+0+0 8-bit sRGB 80c 17977B 0.000u 0:00.000
```

### Raster Budget

```text
20	logo/cairnloop-og.png
4	logo/favicon-16.png
4	logo/favicon-32.png
4	logo/favicon.ico
32	total
```

### Automated Gates

- `xmllint --noout logo/favicon.svg logo/cairnloop-og.svg` - PASS
- SVG prohibited-reference scan - PASS
- Task favicon dimension checks - PASS
- Task OG 1200x630 dimension check - PASS
- `du -ck logo/*.png logo/*.ico` budget <= 150KB - PASS, 32KB total
- `mix test` - PASS, 1 doctest, 1030 tests, 0 failures, 57 excluded

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced stroked ring circles with filled donut paths**
- **Found during:** Task 1 and Task 2 raster preview
- **Issue:** ImageMagick raster output dropped the stroked SVG circle used for the copper ring, making the mark lose the selected ring-as-top-stone read in PNG exports.
- **Fix:** Reauthored the ring as explicit filled path geometry with `fill-rule="evenodd"` in both SVG masters, then regenerated all PNG/ICO outputs.
- **Files modified:** `logo/favicon.svg`, `logo/cairnloop-og.svg`, raster exports
- **Verification:** Visual preview plus `magick identify`, SVG hygiene scan, and raster budget checks all passed.
- **Committed in:** `0556980` and `5c93bf5`

---

**Total deviations:** 1 auto-fixed (Rule 1)
**Impact on plan:** The fix preserved the intended C3.6 visual concept across SVG and raster outputs without expanding scope.

## Issues Encountered

- Transparent favicon legibility is strongest on trailpaper/light hosts. On very dark basalt hosts the copper ring remains visible but the basalt base stone has less separation; Phase 52 wiring may choose a host-specific favicon source if rendered browser verification shows that is necessary.
- No package installs were needed.

## Known Stubs

None.

## Threat Flags

None. The plan introduced static SVG/PNG/ICO assets only, matching the plan threat model; no network endpoints, auth paths, file access code, or package-surface changes were added.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 51 can consume the OG/social source and favicon previews for brand-book rendering. Phase 52 can wire the favicon and OG PNG into README/example-app surfaces after logo-family sign-off.

## Self-Check: PASSED

- Created files exist: `logo/favicon.svg`, `logo/favicon-16.png`, `logo/favicon-32.png`, `logo/favicon.ico`, `logo/cairnloop-og.svg`, `logo/cairnloop-og.png`, and this summary.
- Task commits are reachable: `0556980`, `5c93bf5`, `95f8d9c`.
- Plan-level verification passed: SVG XML, SVG hygiene scan, ImageMagick identify, raster budget, and `mix test`.

---
*Phase: 49-chosen-logo-finalization-asset-family*
*Completed: 2026-06-25*
