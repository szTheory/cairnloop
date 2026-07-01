# Phase 49: Chosen-Logo Finalization & Asset Family - Research

**Researched:** 2026-06-25
**Domain:** hand-authored SVG brand asset family, favicon/OG raster export, usage-spec content
**Confidence:** HIGH for repo scope and asset decisions; MEDIUM for ImageMagick export details; LOW for platform behavior beyond official docs.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
## Implementation Decisions

### Asset Family Shape

- **D-49-01:** Ship a compact SVG-first production family rooted at `logo/`, replacing the contest
  artifact as the source for future brand use. Recommended file set:
  `logo/cairnloop-lockup-horizontal.svg`, `logo/cairnloop-lockup-stacked.svg`,
  `logo/cairnloop-mark.svg`, `logo/cairnloop-lockup-horizontal-mono.svg`,
  `logo/cairnloop-lockup-horizontal-reverse.svg`, and
  `logo/cairnloop-lockup-tagline.svg`.
- **D-49-02:** The primary horizontal lockup is the default public mark: C3.6 mark + plain lowercase
  `cairnloop` wordmark in Fraunces, optically tight, with the mark centered to the wordmark cap
  height. The wordmark remains plain; the rejected `oo` ring echo stays rejected.
- **D-49-03:** The stacked lockup is secondary for square-ish contexts, brand book specimens, and
  social/card composition. Do not make it the dense docs/package default.
- **D-49-04:** Mono and reverse variants are first-class authored SVGs, not lazy color swaps.
  Basalt-on-trailpaper and trailpaper-on-basalt are required; the one-color mark must still read as
  ring-as-top-stone.
- **D-49-05:** The tagline lockup is separate and promotional only. It may use the locked tagline
  **"Support that leaves a trail."** for OG/brandbook/landing contexts, but it must never become the
  primary lockup, README header default, app nav mark, or favicon source.
- **D-49-06:** Prefer outlined/path-authored wordmark SVGs for committed logo assets to avoid
  runtime font drift in GitHub, HexDocs, and local `file://` contexts. Keep source SVG clean and
  optimized: valid `viewBox`, no editor metadata, no embedded raster, no external references.

### Small-Size Reduction

- **D-49-07:** Create a separately-authored small-size favicon reduction rather than scaling down
  the 48px production mark. The 16/32 favicon keeps the C3.6 concept but is optically tuned:
  compact ring, two flattened stones, simplified geometry, no extra detail, no cage.
- **D-49-08:** Ship `logo/favicon.svg`, `logo/favicon-16.png`, `logo/favicon-32.png`, and
  `logo/favicon.ico` with 16/32 entries. Do not add a full PWA/app-icon pack in this phase; it is
  over-scoped and fights the <=~150KB raster budget.
- **D-49-09:** Validate favicon legibility on light and dark host surfaces. If one transparent SVG
  cannot read clearly in both, planner may authorize separate light/dark SVG sources, but the wired
  browser favicon path in Phase 52 should stay minimal.

### OG / Social Card

- **D-49-10:** Use a hybrid OG/social card, not logo-only and not tagline-only: C3.6 mark, `cairnloop`
  wordmark, one restrained product line, and the tagline as a secondary line only if it remains
  legible. Recommended product line: **"Embedded support automation for Phoenix apps."**
- **D-49-11:** Author a 1200x630 SVG master at `logo/cairnloop-og.svg` and one PNG export at
  `logo/cairnloop-og.png`. Keep the composition inside a conservative safe zone so GitHub/social
  crops do not cut off the mark or text.
- **D-49-12:** Use a solid brand background, not transparency. Trailpaper background is the default
  recommendation; basalt is acceptable if contrast is proven and the card still reads calmly. Copper
  remains an accent, not a filled-card dominant color.
- **D-49-13:** Avoid "AI chatbot", "helpdesk SaaS", generic autonomy copy, chat bubbles, infinity
  loops, glowing gradients, and text-dense marketing claims. The card should answer "what is this?"
  for an OSS adopter while still feeling like Cairnloop.

### Usage Rules Strictness

- **D-49-14:** Use concise, measurable, diagrammatic rules rather than a loose prose note or a
  corporate brand manual. Phase 49 should create usage guidance that Phase 51 can render directly:
  clearspace diagram, minimum-size table, lockup gallery, and do/don't panels.
- **D-49-15:** Clearspace uses the height of the top stone/ring unit as the minimum exclusion zone,
  consistent with the seed brand book. Minimum sizes stay: icon mark 24px digital, favicon 16px
  simplified cut, horizontal lockup 112px minimum width digital, print icon 0.35in minimum height.
- **D-49-16:** Do/don't panels must explicitly include: no rectangular cage; no chat bubble; no
  infinity symbol; no robot/headset/support-agent trope; no loose icon-left-of-plain-text spacing;
  no subtitle on primary lockup; no stretching, recoloring, shadows, gradients, or low-contrast
  arbitrary backgrounds.
- **D-49-17:** Usage guidance should be contributor-friendly: show approved files and when to use
  each one. Hide implementation guts from brand users; only expose asset names, intended contexts,
  min sizes, clearspace, and misuse examples.

### Rejected Direction Cleanup

- **D-49-18:** Delete rejected contest directions only after the production family is committed and
  the final asset family supersedes `logo/_contest/`. Preserve the durable rationale in Phase 47
  artifacts and mention cleanup in the Phase 49 SUMMARY. Do not delete Phase 47 planning records.

### the agent's Discretion
Planner/executor may choose the exact SVG coordinate grid, optical spacing, path simplification,
export tooling, and final filenames if they improve implementation quality while preserving the
decisions above. Keep assets lightweight and repo-local; do not introduce a heavyweight design or
Node build pipeline just to export SVG/PNG/ICO.

### Deferred Ideas (OUT OF SCOPE)
- Wiring final assets into README, example-app favicon, `og:image`, and rendered E2E verification
  belongs to Phase 52.
- Full `brandbook/` scaffold and token derivation belongs to Phase 50.
- Full rendered brand book assembly, including live logo gallery and do/don't panels, belongs to
  Phase 51.
- Full PWA/apple-touch/android icon pack is deferred unless a later milestone makes the example app
  installable or mobile-home-screen polish a real requirement.
- Animated logo, motion/Lottie variants, slide templates, stickers, and swag assets remain out of
  scope for vM017.
</user_constraints>

## Summary

Phase 49 should produce a package-free, hand-authored SVG asset family under `logo/`: final horizontal and stacked lockups, icon-only mark, mono/reverse variants, tagline lockup, favicon reduction, OG SVG master, and required PNG/ICO exports. The chosen direction is already locked as C3.6, where the copper ring is the top stone; research should not reopen direction, palette, type, or the rejected `oo` typemark. [VERIFIED: .planning/phases/49-chosen-logo-finalization-asset-family/49-CONTEXT.md] [VERIFIED: .planning/phases/47-brand-direction-exploration-selection-gate/47-SELECTION-GATE.md]

The implementation path should stay deliberately simple: author clean standalone SVGs with explicit `viewBox`, inline paths/shapes, outlined wordmark paths where feasible, no embedded raster, no external `href`, no scripts, and no editor metadata; export the small raster deliverables with local ImageMagick 7.1.1-44; validate XML, SVG hygiene, dimensions, and raster budget with shell commands. [VERIFIED: local tool probe] [CITED: https://imagemagick.org/convert/] [CITED: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/use]

**Primary recommendation:** Use no new package or build pipeline; create clean SVG masters and export only `favicon-16.png`, `favicon-32.png`, `favicon.ico`, and `cairnloop-og.png` with ImageMagick, keeping total raster size under the milestone's <=~150KB budget. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: local tool probe]

## Project Constraints (from AGENTS.md)

No `AGENTS.md` file exists at the repository root, so there are no project-specific AGENTS directives to apply. [VERIFIED: filesystem check]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Final SVG asset family | Static repository assets | Brand book consumer | Logo files are repo collateral under `logo/`; Phase 51 consumes them for rendered documentation. [VERIFIED: 49-CONTEXT.md] |
| Favicon PNG/ICO exports | Static repository assets | Browser/client in Phase 52 | Phase 49 creates files only; Phase 52 wires them into layouts/meta. [VERIFIED: 49-CONTEXT.md] |
| OG/social card source and PNG | Static repository assets | GitHub/social platforms | Phase 49 creates `1200x630` SVG/PNG; Phase 52 wires repository/example-app surfaces. [VERIFIED: 49-CONTEXT.md] |
| Usage spec content | Documentation/content | Brand book renderer | Phase 49 writes rules and diagrams-ready content; Phase 51 renders it in HTML. [VERIFIED: ROADMAP.md] |
| Rejected direction cleanup | Repository hygiene | Planning records | Delete `logo/_contest/` only after the production family supersedes it; preserve Phase 47 planning records. [VERIFIED: 49-CONTEXT.md] |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LOGO-04 | Finalized optimized-SVG family: horizontal, stacked, icon-only, mono/reverse, tagline lockup, unified mark+wordmark. | Use the C3.6 geometry and locked file family from 49-CONTEXT; validate SVGs with `xmllint` plus hygiene grep. [VERIFIED: .planning/REQUIREMENTS.md] |
| LOGO-05 | Separately authored favicon reduction and OG/social card with raster exports under budget. | Use separate simplified favicon SVG, ImageMagick raster exports, and byte-size checks; official social docs support 1200x630/large previews, while repo budget is stricter. [VERIFIED: .planning/REQUIREMENTS.md] [CITED: https://developers.facebook.com/docs/sharing/webmasters/images/] |
| LOGO-06 | Usage rules for clearspace, minimum sizes, and do/don't panels. | Base the spec on brand-book §6.4 plus D-49-14..17 so Phase 51 can render diagrams directly. [VERIFIED: prompts/cairnloop_brand_book.md] [VERIFIED: 49-CONTEXT.md] |
</phase_requirements>

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Hand-authored SVG | SVG 1.1/2-compatible static markup | Primary logo, lockup, icon, favicon source, and OG master | Repo requires hand-authored SVG and no embedded raster/external refs. [VERIFIED: .planning/STATE.md] |
| ImageMagick `magick` | 7.1.1-44 | Export SVG masters to PNG and ICO | Installed locally and official docs identify `magick` as the conversion/resizing CLI. [VERIFIED: local tool probe] [CITED: https://imagemagick.org/convert/] |
| `xmllint` | libxml 2.9.13 | Validate SVG XML well-formedness | Installed locally and sufficient for a fast asset hygiene gate. [VERIFIED: local tool probe] |
| POSIX shell + `rg` + `du` + `file` | local tools | Check forbidden SVG references, raster budget, and file types | Already available in repo workflow; no package install needed. [VERIFIED: local tool probe] |

### Supporting
| Library / Tool | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `sips` | 316 | Optional macOS dimension inspection fallback | Use only if ImageMagick `identify` output is insufficient. [VERIFIED: local tool probe] |
| `iconutil` | system macOS tool | Not recommended for favicon `.ico` creation | It converts `.iconset` to `.icns`, not browser `.ico`; avoid for this phase. [VERIFIED: local tool probe] |
| Mix/ExUnit | Mix 1.19.5 / OTP 28 | Repo regression checks | Use `mix test` after asset/docs changes; Phase 49 itself is mostly static-asset validation. [VERIFIED: local tool probe] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ImageMagick | Inkscape CLI | Inkscape is not installed; requiring it would add a heavyweight design/export dependency. [VERIFIED: local tool probe] |
| ImageMagick | librsvg `rsvg-convert` | `rsvg-convert` is not installed; do not block Phase 49 on it. [VERIFIED: local tool probe] |
| Manual SVG optimization | npm `svgo` | Avoid because no new package is needed and package legitimacy would add install/checkpoint overhead. [VERIFIED: package policy from 49-CONTEXT.md] |
| Favicon-only SVG | SVG + PNG + ICO | Requirements explicitly call for PNG and ICO raster exports. [VERIFIED: .planning/REQUIREMENTS.md] |

**Installation:**
```bash
# No new packages. Use installed ImageMagick, xmllint, rg, du, and mix.
```

## Package Legitimacy Audit

No external package installation is recommended for Phase 49, so the package legitimacy gate is not applicable. [VERIFIED: research recommendation; local tools available]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none | n/a | n/a | n/a | n/a | n/a | No package install |

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

## Architecture Patterns

### System Architecture Diagram

```text
Phase 47 selection artifacts
  |  C3.6 geometry, Refined palette, Fraunces wordmark
  v
Hand-authored SVG masters in logo/
  |-- horizontal / stacked / mark / mono / reverse / tagline
  |-- simplified favicon.svg
  |-- cairnloop-og.svg at 1200x630
  |
  +--> SVG hygiene checks
  |      xmllint + rg forbidden refs + viewBox checks
  |
  +--> ImageMagick raster export
         favicon-16.png + favicon-32.png + favicon.ico + cairnloop-og.png
         |
         v
       file size + dimension checks <=~150KB total raster budget

Usage spec markdown/data
  |
  v
Phase 51 brandbook rendering

Final assets
  |
  v
Phase 52 README/example-app/favicon/OG wiring
```

### Recommended Project Structure
```text
logo/
├── cairnloop-mark.svg
├── cairnloop-lockup-horizontal.svg
├── cairnloop-lockup-stacked.svg
├── cairnloop-lockup-horizontal-mono.svg
├── cairnloop-lockup-horizontal-reverse.svg
├── cairnloop-lockup-tagline.svg
├── cairnloop-og.svg
├── cairnloop-og.png
├── favicon.svg
├── favicon-16.png
├── favicon-32.png
├── favicon.ico
└── USAGE.md
```

`logo/_contest/direction-boards.html` is contest evidence only and should be deleted after the production family exists; Phase 47 planning records remain. [VERIFIED: 49-CONTEXT.md]

### Pattern 1: Standalone SVG Asset
**What:** Each committed SVG is a complete standalone file with `xmlns="http://www.w3.org/2000/svg"`, explicit `viewBox`, inline shapes/paths, and explicit fill/stroke colors. [VERIFIED: 47-DISCUSSION-LOG.md]
**When to use:** All logo family members and SVG masters. [VERIFIED: .planning/REQUIREMENTS.md]
**Example:**
```svg
<!-- Source: Phase 47 discussion log; production Phase 49 should redraw/optimize, not copy blindly. -->
<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Cairnloop">
  <circle cx="24" cy="15" r="5.4" fill="none" stroke="#A8492A" stroke-width="2.8"/>
  <rect x="12" y="25" width="24" height="7" rx="3.5" fill="#1E2A24"/>
  <rect x="7" y="34" width="34" height="8" rx="4" fill="#141B19"/>
</svg>
```

### Pattern 2: Purpose-Built Favicon Reduction
**What:** Draw `favicon.svg` as its own simplified 16/32-friendly artwork: compact ring, two flattened stones, no extra details, no cage. [VERIFIED: 49-CONTEXT.md]
**When to use:** Browser favicon raster exports and future favicon wiring. [VERIFIED: .planning/REQUIREMENTS.md]

### Pattern 3: Renderable Usage Spec
**What:** `logo/USAGE.md` should contain structured sections that Phase 51 can translate directly into HTML: approved assets table, clearspace rule, minimum-size table, do/don't panels, and source/raster notes. [VERIFIED: 49-CONTEXT.md]
**When to use:** LOGO-06 closure and Phase 51 handoff. [VERIFIED: ROADMAP.md]

### Anti-Patterns to Avoid
- **Live-font wordmark in committed logo SVGs:** GitHub/HexDocs/file contexts can render different fonts; prefer outlined/path wordmark. [VERIFIED: 49-CONTEXT.md]
- **Scaled master as favicon:** Requirement says the favicon is separately authored and optically tuned. [VERIFIED: 49-CONTEXT.md]
- **External SVG refs:** MDN documents external `<use>` loading and same-origin restrictions; avoid `href`, `xlink:href`, external styles, and data URLs in logo assets. [CITED: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/use]
- **Shipping contest artifacts as production assets:** `logo/_contest/` is evidence, not the final source. [VERIFIED: 47-SELECTION-GATE.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Raster export engine | Custom SVG rasterizer script | ImageMagick `magick` | Installed and official conversion/resizing tool. [VERIFIED: local tool probe] [CITED: https://imagemagick.org/convert/] |
| SVG XML validation | Custom parser | `xmllint --noout` | Fast local well-formedness check. [VERIFIED: local tool probe] |
| Multi-package icon pipeline | PWA/app icon generator | Only required favicon SVG/PNG/ICO | Full icon pack is deferred and conflicts with raster budget. [VERIFIED: 49-CONTEXT.md] |
| Brand-book rendering | Build HTML brandbook now | `logo/USAGE.md` content only | Phase 51 owns rendered brand book assembly. [VERIFIED: ROADMAP.md] |
| Example app/README wiring | Edit live surfaces now | Defer to Phase 52 | Phase 52 owns `README`, example app logo/favicon, and `og:image` wiring. [VERIFIED: ROADMAP.md] |

**Key insight:** The hard part is not tooling; it is preserving the selected C3.6 read across sizes and contexts while keeping assets standalone, small, and easy for later phases to consume. [VERIFIED: 49-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: The Ring Becomes a Halo, Chat Bubble, or Infinity Mark
**What goes wrong:** The copper ring reads as decoration rather than the top stone. [VERIFIED: 47-SELECTION-GATE.md]
**Why it happens:** Too much gap, too circular/iconic a loop, or loose lockup spacing. [VERIFIED: 47-DISCUSSION-LOG.md]
**How to avoid:** Keep the ring compact, aligned to the stack, and visually structural; use one copper accent only. [VERIFIED: 49-CONTEXT.md]
**Warning signs:** The icon still looks meaningful after removing the stones, or resembles a chat/infinity glyph at 16px. [VERIFIED: 49-CONTEXT.md]

### Pitfall 2: Font Drift in Wordmark Assets
**What goes wrong:** `cairnloop` changes weight/spacing when rendered on GitHub, HexDocs, or local `file://`. [VERIFIED: 49-CONTEXT.md]
**Why it happens:** SVG `<text>` depends on available fonts. [ASSUMED]
**How to avoid:** Convert the Fraunces wordmark to paths for committed production lockups, or at minimum verify a path-authored equivalent before sign-off. [VERIFIED: 49-CONTEXT.md]
**Warning signs:** The SVG contains `<text` in final lockup files. [VERIFIED: 49-CONTEXT.md]

### Pitfall 3: OG Card Exceeds Budget
**What goes wrong:** `cairnloop-og.png` dominates the <=~150KB raster budget. [VERIFIED: .planning/REQUIREMENTS.md]
**Why it happens:** 1200x630 PNG with antialiased text and multiple colors can be much larger than tiny favicon rasters. [ASSUMED]
**How to avoid:** Use flat fills, few colors, no gradients/noise/photos, and inspect byte size immediately after export. [VERIFIED: 49-CONTEXT.md]
**Warning signs:** `du -ck logo/*.png logo/*.ico` reports over 150KB total. [VERIFIED: .planning/REQUIREMENTS.md]

### Pitfall 4: Phase Boundary Creep
**What goes wrong:** Planner edits README, example app layout, root meta tags, or brandbook HTML. [VERIFIED: 49-CONTEXT.md]
**Why it happens:** Assets are tempting to wire immediately once created. [ASSUMED]
**How to avoid:** Phase 49 should stop at asset creation, `USAGE.md`, validation, and rejected contest cleanup. [VERIFIED: ROADMAP.md]

## Code Examples

### Export Raster Deliverables
```bash
# Source: ImageMagick official CLI docs + local installed tool.
magick -background none logo/favicon.svg -resize 16x16 logo/favicon-16.png
magick -background none logo/favicon.svg -resize 32x32 logo/favicon-32.png
magick logo/favicon-16.png logo/favicon-32.png logo/favicon.ico
magick -background '#F4EEE2' logo/cairnloop-og.svg -resize 1200x630 logo/cairnloop-og.png
```

### Validate SVG Hygiene
```bash
xmllint --noout logo/*.svg
rg -n '(<image|<script|<foreignObject|href="https?:|href="data:|xlink:href|data:image|base64|<metadata|sodipodi:|inkscape:)' logo/*.svg
rg -n '<text\\b' logo/cairnloop-lockup-*.svg logo/cairnloop-og.svg
```

### Validate Dimensions and Raster Budget
```bash
magick identify logo/favicon-16.png logo/favicon-32.png logo/favicon.ico logo/cairnloop-og.png
du -ck logo/*.png logo/*.ico
```

### Validate Package Hygiene
```bash
rg -n 'files:' mix.exs
git diff --stat
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Contest HTML proof in `logo/_contest/` | Production SVG asset family rooted at `logo/` | Phase 49 | Treat contest artifact as replaceable evidence, not production source. [VERIFIED: 49-CONTEXT.md] |
| Scaling the same mark down everywhere | Separate favicon reduction | Phase 49 decision | Better 16px legibility and avoids detail loss. [VERIFIED: 49-CONTEXT.md] |
| Transparent/social-logo-only card | Solid-background hybrid OG card | Phase 49 decision + GitHub docs | Solid background is safer across platforms; hybrid card explains the project. [VERIFIED: 49-CONTEXT.md] [CITED: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview] |

**Deprecated/outdated:**
- The `oo` ring typemark is rejected and must not be revived in production assets. [VERIFIED: 47-SELECTION-GATE.md]
- Full PWA/app icon packs are deferred. [VERIFIED: 49-CONTEXT.md]
- Rejected contest directions should be removed only after final assets supersede them. [VERIFIED: 49-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | SVG `<text>` can drift across render contexts when fonts are unavailable. | Common Pitfalls | If wrong, path-authored wordmark is still acceptable but may add unnecessary manual effort. |
| A2 | Large 1200x630 PNGs can exceed the raster budget if visually complex. | Common Pitfalls | If wrong, budget risk is lower, but flat/simple OG art remains aligned with brand constraints. |
| A3 | Phase boundary creep happens because wiring is tempting after asset creation. | Common Pitfalls | Low implementation risk; boundary is explicitly locked in repo context. |

## Open Questions (RESOLVED)

1. **How will the wordmark be converted to paths?**
   - What we know: Production assets should prefer outlined/path-authored wordmark SVGs. [VERIFIED: 49-CONTEXT.md]
   - Resolution: Use manual/path-authored SVG approximation within Phase 49 and verify no `<text>` remains in final logo lockups. Exact external font conversion is not required because Inkscape is absent and Phase 49 should not add a package pipeline solely for wordmark conversion. [VERIFIED: local tool probe] [VERIFIED: 49-CONTEXT.md]

2. **Can one transparent favicon read on both light and dark host surfaces?**
   - What we know: D-49-09 allows separate light/dark SVG sources if one transparent SVG cannot read clearly. [VERIFIED: 49-CONTEXT.md]
   - Resolution: Plan 49-02 requires validating the transparent favicon on light trailpaper and dark basalt host surfaces and recording the result in the summary. Use one transparent source unless that validation fails; separate light/dark sources remain optional future source assets only if the single transparent source fails, while Phase 52 browser wiring stays minimal. [VERIFIED: 49-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| ImageMagick `magick` | PNG/ICO export and dimension checks | yes | 7.1.1-44 | Manual export outside repo only if command fails. [VERIFIED: local tool probe] |
| `xmllint` | XML well-formedness validation | yes | libxml 2.9.13 | Browser parse/manual review. [VERIFIED: local tool probe] |
| `rg` | Hygiene scans | yes | installed | `grep -R`, less ergonomic. [VERIFIED: local usage] |
| Node/npm | Optional ad hoc checks | yes | Node 22.14.0 / npm 11.1.0 | Not needed. [VERIFIED: local tool probe] |
| Mix | Repo tests | yes | Mix 1.19.5 / OTP 28 | None for repo test gate. [VERIFIED: local tool probe] |
| Inkscape | Optional text-to-path/export workflow | no | n/a | Manual path authoring or external one-off conversion; do not add pipeline. [VERIFIED: local tool probe] |
| `rsvg-convert` | Optional SVG raster export | no | n/a | ImageMagick. [VERIFIED: local tool probe] |
| `oxipng` / `pngquant` | Optional PNG compression | no | n/a | Keep OG flat/simple and rely on ImageMagick output plus budget check. [VERIFIED: local tool probe] |

**Missing dependencies with no fallback:** none.

**Missing dependencies with fallback:**
- Inkscape, `rsvg-convert`, `oxipng`, and `pngquant` are absent; ImageMagick and manual SVG cleanup are sufficient for Phase 49. [VERIFIED: local tool probe]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix 1.19.5 plus shell asset checks. [VERIFIED: mix.exs] |
| Config file | `mix.exs`; no separate asset-lint config exists. [VERIFIED: filesystem scan] |
| Quick run command | `xmllint --noout logo/*.svg && rg -n '(<image|<script|<foreignObject|href="https?:|href="data:|xlink:href|data:image|base64|<metadata|sodipodi:|inkscape:)' logo/*.svg; test $? -eq 1` |
| Full suite command | `mix test` plus asset checks and `du -ck logo/*.png logo/*.ico` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LOGO-04 | Final SVG family exists and is standalone/valid. | static asset | `test -f logo/cairnloop-lockup-horizontal.svg && xmllint --noout logo/*.svg` | no - Wave 0 creates assets |
| LOGO-04 | Final lockups avoid live-font drift. | static asset | `! rg -n '<text\\b' logo/cairnloop-lockup-*.svg` | no - Wave 0 creates assets |
| LOGO-05 | Favicon/OG raster exports exist with correct dimensions. | static asset | `magick identify logo/favicon-16.png logo/favicon-32.png logo/favicon.ico logo/cairnloop-og.png` | no - Wave 0 creates assets |
| LOGO-05 | Total raster budget is <=~150KB. | static asset | `du -ck logo/*.png logo/*.ico` | no - Wave 0 creates assets |
| LOGO-06 | Usage rules are documented for Phase 51 rendering. | docs/static | `rg -n 'clearspace|minimum|Do|Don.t|no rectangular cage|no-icon-left' logo/USAGE.md` | no - Wave 0 creates file |

### Sampling Rate
- **Per task commit:** run SVG hygiene checks for touched SVGs and `magick identify` for touched rasters.
- **Per wave merge:** run all asset checks plus `mix test`.
- **Phase gate:** asset checks green, raster budget recorded, `mix test` green, and rejected contest assets deleted only after final family exists.

### Wave 0 Gaps
- [ ] `logo/*.svg` production masters - required for LOGO-04/05.
- [ ] `logo/favicon-16.png`, `logo/favicon-32.png`, `logo/favicon.ico`, `logo/cairnloop-og.png` - required for LOGO-05.
- [ ] `logo/USAGE.md` - required for LOGO-06 and Phase 51 handoff.
- [ ] Optional script/check command in phase SUMMARY or plan - no repo-level script currently exists for asset validation. [VERIFIED: filesystem scan]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Static asset phase; no auth surface. [VERIFIED: phase scope] |
| V3 Session Management | no | Static asset phase; no session surface. [VERIFIED: phase scope] |
| V4 Access Control | no | Static repository files only. [VERIFIED: phase scope] |
| V5 Input Validation | yes | Validate SVG XML and forbid external/data/script/raster references. [CITED: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/use] |
| V6 Cryptography | no | No cryptographic material. [VERIFIED: phase scope] |

### Known Threat Patterns for Static SVG Assets

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Embedded scripts or `foreignObject` in SVG | Elevation of privilege | Reject `<script>` and `<foreignObject>` in committed logo SVGs. [CITED: https://www.w3.org/wiki/SVG_Security] |
| External resource fetches via `href`, `<image>`, styles, or data URLs | Information disclosure / tampering | Keep SVGs standalone; grep for external/data refs and embedded raster. [CITED: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/use] |
| Oversized raster artifacts | Denial of service / repo bloat | Enforce <=~150KB raster budget with `du -ck`. [VERIFIED: .planning/REQUIREMENTS.md] |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/49-chosen-logo-finalization-asset-family/49-CONTEXT.md` - locked Phase 49 decisions, boundaries, and file set. [VERIFIED: codebase read]
- `.planning/phases/47-brand-direction-exploration-selection-gate/47-SELECTION-GATE.md` - C3.6 selection and rejected directions. [VERIFIED: codebase read]
- `.planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md` - concept geometry and lockup defaults. [VERIFIED: codebase read]
- `.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md` - LOGO-04..06 and phase boundaries. [VERIFIED: codebase read]
- `prompts/cairnloop_brand_book.md` - clearspace, minimum size, brand avoidance, tagline, and positioning. [VERIFIED: codebase read]
- `priv/static/cairnloop.css`, `prompts/cairnloop.tokens.json`, `examples/cairnloop_example/assets/css/app.css`, `48-CONTRAST-REVERIFY.md` - final Refined palette and contrast evidence. [VERIFIED: codebase read]
- Local tool probes - ImageMagick, xmllint, sips, Node/npm, Mix availability; Inkscape/librsvg/pngquant/oxipng absence. [VERIFIED: shell probe]

### Secondary (MEDIUM confidence)
- `https://imagemagick.org/convert/` - ImageMagick `magick` converts and resizes image formats. [CITED: official docs]
- `https://imagemagick.org/command-line-options/` - ImageMagick option reference. [CITED: official docs]

### Tertiary (LOW confidence)
- `https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview` - GitHub social preview image format/size guidance. [CITED: official docs via websearch confidence]
- `https://developers.facebook.com/docs/sharing/webmasters/images/` - Open Graph image size guidance. [CITED: official docs via websearch confidence]
- `https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/use` - SVG `<use>` external/data URI behavior and security notes. [CITED: docs via websearch confidence]
- `https://www.w3.org/wiki/SVG_Security` - SVG external resource/security notes. [CITED: W3C wiki via websearch confidence]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - based on repo constraints and local tool probes; no new package install recommended.
- Architecture: HIGH - phase boundaries are explicit in 49-CONTEXT, ROADMAP, and REQUIREMENTS.
- Pitfalls: MEDIUM - key pitfalls are grounded in locked decisions; font/raster behavior includes marked assumptions.

**Research date:** 2026-06-25
**Valid until:** 2026-07-25 for repo-bound guidance; re-check external platform docs before changing OG/social constraints.
