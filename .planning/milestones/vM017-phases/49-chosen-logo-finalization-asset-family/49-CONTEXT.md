# Phase 49: Chosen-Logo Finalization & Asset Family - Context

**Gathered:** 2026-06-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 49 productionizes the already-selected **C3.6 crowning-loop cairn** into a complete, optimized
brand asset family and usage spec. It creates the final SVG lockups, icon, mono/reverse variants,
separately-authored favicon reduction, OG/social source, raster exports required by LOGO-05, and
clear usage rules that Phase 51 can render in the brand book.

This phase does **not** reopen the logo direction, palette, or type selection. It does **not** wire
assets into README or the example app; Phase 52 owns wiring. It does **not** assemble `brandbook/`;
Phases 50-51 own the brandbook scaffold and rendered sections.

</domain>

<decisions>
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

### Claude's Discretion

Planner/executor may choose the exact SVG coordinate grid, optical spacing, path simplification,
export tooling, and final filenames if they improve implementation quality while preserving the
decisions above. Keep assets lightweight and repo-local; do not introduce a heavyweight design or
Node build pipeline just to export SVG/PNG/ICO.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Locked Logo Direction

- `.planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md` - owner-selected
  C3.6 logo, Refined palette, current type stack, and rejected `oo` typemark.
- `.planning/phases/47-brand-direction-exploration-selection-gate/47-SELECTION-GATE.md` - durable
  selection handoff for Phases 48 and 49.
- `.planning/phases/47-brand-direction-exploration-selection-gate/47-DISCUSSION-LOG.md` - concept
  SVG geometry for C3.6, lockup defaults, rejected directions, and selection rationale.
- `logo/_contest/direction-boards.html` - visual evidence and proof rows for the selected concept;
  concept artifact only, not production source.

### Brand Source Of Truth

- `prompts/cairnloop_brand_book.md` - visual identity, lockups, clearspace, minimum sizes, voice,
  competitive avoidance, and tagline.
- `priv/static/cairnloop.css` - canonical evolved brand token source after Phase 48.
- `prompts/cairnloop.tokens.json` - structured token derivative after Phase 48.
- `examples/cairnloop_example/assets/css/app.css` - example-app token mirror after Phase 48.
- `.planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md` - final contrast
  evidence for evolved brand colors.

### Milestone Governance

- `.planning/ROADMAP.md` - Phase 49 success criteria, plus Phase 50-52 boundaries.
- `.planning/REQUIREMENTS.md` - LOGO-04, LOGO-05, LOGO-06 and hygiene constraints.
- `.planning/STATE.md` - vM017 locked decisions D-A/D-B/D-C, two human gates, repo hygiene, and
  phase dependencies.
- `.planning/PROJECT.md` - current milestone goal, brand constraints, and repo hygiene.
- `mix.exs` - package `files` list; `logo/` and `brandbook/` remain out of the Hex package unless a
  later phase explicitly changes policy.

### External Platform References

- `https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview`
  - GitHub social preview accepts PNG/JPG/GIF under 1MB and recommends large preview dimensions.
- `https://developers.facebook.com/documentation/sharing/webmasters/images` - Open Graph image
  guidance for 1200x630 high-resolution display.
- `https://evilmartians.com/chronicles/how-to-favicon-in-2021-six-files-that-fit-most-needs` -
  practical favicon guidance: use a special small-size version when the master does not downscale.
- `https://hexdocs.pm/phoenix/asset_management.html` - Phoenix asset ergonomics favor lightweight,
  repo-local asset handling without unnecessary external build tooling.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `logo/_contest/direction-boards.html` contains the C3.6 concept SVG and proof rows at 16/24/48/256px.
- `prompts/cairnloop_brand_book.md` already defines clearspace, minimum sizes, logo lockups, brand
  voice, competitive avoidance, and imagery/shape language.
- `priv/static/cairnloop.css` now contains the evolved Refined palette from Phase 48.

### Established Patterns

- `priv/static/cairnloop.css` is the canonical token source; asset colors should align with it, not
  invent a fourth palette copy.
- `mix.exs` package files are intentionally narrow: `lib priv guides mix.exs README.md LICENSE
  CHANGELOG.md`. `logo/` assets are repo collateral, not Hex package payload, unless policy changes.
- The example app currently has the stock Phoenix logo at
  `examples/cairnloop_example/priv/static/images/logo.svg`; replacement is Phase 52, not Phase 49.
- The example app root layout currently has no favicon or OG meta tags; wiring is Phase 52.

### Integration Points

- Phase 50/51 consume the final Phase 49 assets for `brandbook/` logo gallery, usage diagrams, and
  download links.
- Phase 52 consumes the final horizontal/header mark, favicon, and OG PNG for README and example-app
  wiring plus gated rendered-behavior verification.

</code_context>

<specifics>
## Specific Ideas

- Final icon should preserve the owner-selected read: the copper ring is the top stone, not a halo,
  infinity loop, or chat bubble.
- Use copper as the single waymark accent. Do not flood the wordmark or OG card with copper.
- OG card copy recommendation: `cairnloop` + "Embedded support automation for Phoenix apps." +
  optional secondary "Support that leaves a trail."
- The asset family should feel OSS-library credible first: calm, precise, easy to use from README,
  HexDocs, GitHub preview, and future brandbook download links.

</specifics>

<deferred>
## Deferred Ideas

- Wiring final assets into README, example-app favicon, `og:image`, and rendered E2E verification
  belongs to Phase 52.
- Full `brandbook/` scaffold and token derivation belongs to Phase 50.
- Full rendered brand book assembly, including live logo gallery and do/don't panels, belongs to
  Phase 51.
- Full PWA/apple-touch/android icon pack is deferred unless a later milestone makes the example app
  installable or mobile-home-screen polish a real requirement.
- Animated logo, motion/Lottie variants, slide templates, stickers, and swag assets remain out of
  scope for vM017.

</deferred>

---

*Phase: 49-Chosen-Logo Finalization & Asset Family*
*Context gathered: 2026-06-25*
