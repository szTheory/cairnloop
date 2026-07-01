# Cairnloop Logo Usage

This file is the Phase 51 source for the brand-book logo gallery, clearspace diagram, minimum-size table, and do/don't panels. Use these assets as committed; do not redraw, recolor, or recompose the mark.

## Approved files

| File | Use when | Notes |
| --- | --- | --- |
| `cairnloop-lockup-horizontal.svg` | Default public logo for README, docs headers, package surfaces, and broad brand identification. | Primary lockup. No subtitle. Use first unless the surface is square or size-constrained. |
| `cairnloop-lockup-stacked.svg` | Square or centered compositions, brand-book specimens, and social/card layouts that need a vertical rhythm. | Secondary lockup. Do not use as the dense docs/package default. |
| `cairnloop-mark.svg` | Icon-only placements, small badges, and brand-book mark specimens. | C3.6 mark only: copper ring is the top stone. |
| `cairnloop-lockup-horizontal-mono.svg` | One-color basalt lockup on trailpaper, white, or similarly light approved surfaces. | Use for print or constrained single-ink contexts. |
| `cairnloop-lockup-horizontal-reverse.svg` | One-color trailpaper lockup on basalt or similarly dark approved surfaces. | Use when the full-color lockup loses contrast. |
| `cairnloop-lockup-tagline.svg` | Promotional contexts where the tagline is intentionally part of the composition. | Separate tagline lockup only. Never replace the primary lockup with this in navigation, README headers, favicon, or package identity. |
| `favicon.svg` | SVG favicon source and small browser icon source. | Separately authored simplified cut. Do not substitute the full mark at 16px. |
| `favicon-16.png` | 16px raster favicon fallback. | Generated from `favicon.svg`. |
| `favicon-32.png` | 32px raster favicon fallback. | Generated from `favicon.svg`. |
| `favicon.ico` | Browser ICO fallback with 16px and 32px entries. | Generated from the approved favicon rasters. |
| `cairnloop-og.svg` | 1200x630 OG/social card master. | Source for social preview export. Not a general logo lockup. |
| `cairnloop-og.png` | 1200x630 OG/social preview raster. | Use for GitHub/social metadata after Phase 52 wiring. |

## Clearspace

Minimum clearspace equals the height of the top stone/ring unit. Measure the copper ring/top stone in the mark, then keep at least that much empty space around every side of the logo or mark.

Phase 51 diagram note: label the exclusion zone as `1x`, where `x = top stone/ring height`.

## Minimum sizes

| Asset | Minimum size | Rule |
| --- | ---: | --- |
| Icon mark | 24px digital | Use `cairnloop-mark.svg` at 24px or larger. |
| Favicon simplified cut | 16px digital | Use `favicon.svg`, `favicon-16.png`, or `favicon.ico`; do not scale the full mark down to 16px. |
| Horizontal lockup | 112px minimum width digital | Use `cairnloop-lockup-horizontal.svg` or a one-color horizontal variant at 112px wide or larger. |
| Print icon | 0.35in minimum height | Use the mono lockup or mark when print reproduction cannot hold full color. |

## Do

- Use `cairnloop-lockup-horizontal.svg` as the default public lockup.
- Use `cairnloop-mark.svg` only when the wordmark would be too small or redundant.
- Use the mono basalt or reverse trailpaper lockup when full color does not meet contrast.
- Keep the mark close to the wordmark; the logo should read as one composed unit.
- Preserve clearspace equal to the top stone/ring height.
- Keep the ring visually structural: it is the top stone, not a halo or decoration.
- Use the simplified favicon files for 16px and 32px browser icons.

## Do not

- Use no rectangular cage around the logo or mark.
- Use no chat bubble.
- Use no infinity symbol.
- Use no robot, no headset, and no support-agent trope.
- Use no loose icon-left-of-plain-text spacing.
- Use no subtitle on primary lockup.
- Use no stretching, squeezing, skewing, or rotation.
- Use no arbitrary recoloring outside the approved full-color, mono, and reverse files.
- Use no shadows.
- Use no gradients.
- Place the logo on no low-contrast arbitrary backgrounds.
- Recreate the wordmark with live text or a different font.

## Phase handoff

Phase 51 renders this Markdown into the HTML brand book: approved-file gallery, clearspace diagram, minimum-size table, and do/don't panels. Phase 52 wires the assets into README, favicon, OG metadata, and the example app only after the future owner logo-family sign-off gate.
