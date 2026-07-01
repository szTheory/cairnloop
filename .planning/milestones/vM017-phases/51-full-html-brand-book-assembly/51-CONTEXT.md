# Phase 51: Full HTML Brand Book Assembly - Context

**Gathered:** 2026-06-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 51 upgrades the Phase 50 `brandbook/` scaffold into the complete standalone HTML brand book.
It renders the Cairnloop identity as a professional, offline, maintainer-friendly reference:
tokens, swatches, typography, spacing/radius/shadow/motion, logo system, usage rules, voice,
microcopy, imagery, downloads, and light/dark behavior.

This phase does **not** reopen the selected logo, palette, type stack, or token source. It does not
wire assets into README, the example app, favicon metadata, OG metadata, HexDocs, or shipped product
surfaces; Phase 52 owns wiring and the final collateral QA sweep. It does not turn the brand book
into a hosted docs platform, Storybook, Docusaurus site, Phoenix route, or public Mix task.

</domain>

<spec_lock>
## Requirements and UI Contract Locked

`51-UI-SPEC.md` is present and approved. Downstream agents MUST read it before planning or
implementing. It locks the Phase 51 visual boundary, required sections, copy labels, logo handling,
interaction rules, registry safety, and verification expectations.

**In scope (from UI-SPEC / roadmap):**
- `brandbook/index.html` as a complete single-page brand reference with all required sections
  rendered as live HTML.
- `brandbook/assets/css/brandbook.css` for full layout, tables, specimens, diagrams, theme states,
  and responsive behavior using `--cl-*` tokens.
- `brandbook/assets/css/tokens.css` as a generated token mirror; read from it, verify it, but do not
  hand-edit it.
- `brandbook/color/swatches.json` as lean generated swatch data, not a contrast authority.
- `logo/USAGE.md`, committed `logo/*` assets, and Phase 48 contrast evidence as source inputs for
  logo, downloads, and WCAG badge content.

**Out of scope (from UI-SPEC / roadmap):**
- Editing canonical token values in `priv/static/cairnloop.css`.
- Changing the selected C3.6 logo family, creating new logo assets, or recomposing/redrawing logos.
- Wiring README, example app, favicon, OG, Phoenix routes, package metadata, or HexDocs.
- Adding shadcn, registries, npm UI packages, CDN assets, remote fonts, analytics, iframes, or
  third-party docs/design-system platforms.

</spec_lock>

<decisions>
## Implementation Decisions

### Document Flow and Information Architecture

- **D-51-01:** Use one ordered long-form `brandbook/index.html` page with a sticky desktop in-page
  navigation and a static anchored contents list on mobile. This is the best fit for a `file://`,
  no-network reference that future contributors can inspect in one place.
- **D-51-02:** Use this section order unless implementation uncovers a strong local reason to adjust:
  Header, Contents, Color, Typography, Spacing/Radius/Shadow/Motion tokens, Logo system,
  Voice/Microcopy, Imagery, Motion guidance, Downloads, Footer.
- **D-51-03:** Do not hide core brand rules in accordions or progressive disclosure. Every required
  section must show at least one rendered example, one source/provenance cue, and one usage rule.
  Native `<details>` is allowed only for secondary provenance/regeneration notes.
- **D-51-04:** The first viewport should feel like a dense reference document, not a marketing hero:
  page title `Cairnloop brand book`, tagline, provenance, network status, theme toggle, and a visible
  hint of the Color section.
- **D-51-05:** Optimize for maintainers, designers, future agents, and OSS contributors answering:
  "What should I use?", "Why does this rule exist?", "Where is the file?", and "What must I avoid?"
  Do not expose parser internals or implementation guts in primary user-facing copy.

### Data, Automation, and Source of Truth

- **D-51-06:** Use a repo-local Elixir generation/check approach for Phase 51 content assembly,
  modeled on `mix run scripts/derive_brandbook_tokens.exs`. The output remains plain static HTML/CSS
  committed under `brandbook/`.
- **D-51-07:** Essential brandbook content should be generated or checked at build time from
  repo-local sources, not fetched at runtime. Do not rely on `fetch("./color/swatches.json")` for
  required content because `file://` JSON loading is browser-fragile and can blank important sections.
- **D-51-08:** JavaScript is allowed only as a small local progressive enhancement for the light/dark
  toggle, optional session persistence, and nonessential computed-style enhancement. With JavaScript
  unavailable, the core document content must remain visible and useful.
- **D-51-09:** Keep `priv/static/cairnloop.css` canonical. `brandbook/assets/css/tokens.css`,
  `brandbook/color/swatches.json`, and any Phase 51 generated HTML are derivatives or rendered
  references, not new sources of truth.
- **D-51-10:** Keep generated output deterministic and reviewable: stable ordering, no timestamps in
  generated HTML unless required by an existing provenance contract, clear comments on generated
  files, and loud `--check` failures for drift or missing inputs.
- **D-51-11:** Render contrast badges from Phase 48 contrast evidence and token values, not from a new
  contrast matrix inside `swatches.json`. Badges should read as `AA pass`, `UI pass`, or
  `Decorative exempt` and must pair status color with text/icon labels.
- **D-51-12:** Render `logo/USAGE.md` facts into friendly HTML: approved-file gallery, clearspace
  diagram, minimum-size table, do/don't panels, and relative download links. Do not expose Markdown
  parsing details to brandbook readers.
- **D-51-13:** Do not add Style Dictionary, Storybook, Docusaurus, zeroheight-style tooling, a public
  Mix task under `lib/mix/tasks`, or a Node design-token pipeline in Phase 51. Those are only
  justified if a later phase turns the brand system into a public multi-platform design-system site.

### Verification, Accessibility, and Developer Experience

- **D-51-14:** Use a layered gate, not manual UAT, for browser-required facts. Static ExUnit/source
  checks should cover required sections, forbidden dependencies, package boundary, generated token
  freshness, swatch/logo/download inventory, and required contrast badge text.
- **D-51-15:** Extend `scripts/verify_brandbook_file_load.mjs` for browser-only facts: `file://`
  load, zero console/page errors, zero failed or remote requests, light/dark toggle state changes,
  keyboard-visible focus, local asset failure copy, and responsive smoke across mobile/tablet/desktop.
- **D-51-16:** Rendered checks must prove preconditions before claiming success. Failure messages
  should name the file, selector, state, and next action so the gate is useful to a maintainer.
- **D-51-17:** Keep Playwright verification focused and independent of Phoenix routing. Do not serve
  the brandbook through the example app just to reuse existing E2E harnesses; Phase 51's core promise
  is standalone `file://` behavior.
- **D-51-18:** Use targeted geometry/pixel sanity checks for blank-page, clipped-layout, theme, and
  viewport regressions. Do not add broad visual-diff snapshot baselines in Phase 51; they are brittle
  for fonts/rendering and likely to create maintenance noise.
- **D-51-19:** Axe-core or equivalent automated accessibility scanning is useful but not required for
  Phase 51 unless the planner can add it with a small local dependency and clear CI ergonomics.
  Automated a11y scans must never be described as complete WCAG sign-off.
- **D-51-20:** If CI is touched, keep it as a small explicit brandbook verification lane using the
  existing Playwright install pattern. Avoid slowing unrelated release gates for unshipped collateral
  unless the plan makes the tradeoff explicit.

### Claude's Discretion

Planner/executor may choose exact CSS class names, Elixir module/script shape, EEx or string-builder
organization, parsing helpers, generated HTML formatting, and verification helper boundaries. Prefer
simple data-first generation and readable committed output over clever templating. Keep the page calm,
precise, accessible, and OSS-maintainer friendly.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 51 Contract

- `.planning/phases/51-full-html-brand-book-assembly/51-UI-SPEC.md` - locked visual, interaction,
  copywriting, content, logo, accessibility, and registry-safety contract.
- `.planning/ROADMAP.md` - Phase 51 goal, dependencies, success criteria, and Phase 52 boundary.
- `.planning/REQUIREMENTS.md` - BOOK-03, BOOK-04, and BOOK-05 requirement mapping.
- `.planning/STATE.md` - current vM017 status, repo hygiene, and automated verification policy.
- `.planning/PROJECT.md` - vM017 milestone goal, brand constraints, and project posture.

### Prior Phase Decisions

- `.planning/phases/50-brandbook-scaffold-token-derivation-pipeline/50-CONTEXT.md` - Phase 50 token
  derivation, scaffold, no-network, and verification decisions.
- `.planning/phases/50-brandbook-scaffold-token-derivation-pipeline/50-UI-SPEC.md` - scaffold and
  generated token contract that Phase 51 expands.
- `.planning/phases/49-chosen-logo-finalization-asset-family/49-CONTEXT.md` - final logo asset
  family, usage rules, small-size, OG, and Phase 51 handoff.
- `.planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md` - selected C3.6
  mark, Refined palette, current type stack, and rejected directions.
- `.planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md` - WCAG rows,
  pass/exempt classifications, and copper route-marker contrast evidence for badge content.

### Brand and Source Inputs

- `priv/static/cairnloop.css` - canonical `--cl-*` token source for light and dark themes.
- `brandbook/assets/css/tokens.css` - generated Phase 50 brandbook token mirror; do not hand-edit.
- `brandbook/color/swatches.json` - generated swatch data for Phase 51 color rendering.
- `brandbook/TOKENS.md` - token derivation, regeneration, and drift-check instructions.
- `logo/USAGE.md` - source for approved files, clearspace, minimum sizes, do/don't panels, and
  Phase 51 logo section content.
- `logo/cairnloop-lockup-horizontal.svg` - primary public lockup for brandbook rendering.
- `logo/cairnloop-lockup-stacked.svg` - secondary stacked lockup for square/centered specimens.
- `logo/cairnloop-mark.svg` - icon-only mark for size proofs and mark specimens.
- `logo/cairnloop-lockup-horizontal-mono.svg` - one-color basalt-on-light approved specimen.
- `logo/cairnloop-lockup-horizontal-reverse.svg` - one-color trailpaper-on-dark approved specimen.
- `logo/cairnloop-lockup-tagline.svg` - promotional-only tagline specimen.
- `logo/favicon.svg`, `logo/favicon-16.png`, `logo/favicon-32.png`, `logo/favicon.ico` - favicon
  proofs and download links.
- `logo/cairnloop-og.svg`, `logo/cairnloop-og.png` - OG/social card specimen and download links.
- `prompts/cairnloop_brand_book.md` - brand voice, naming, messaging, visual identity, imagery,
  motion, accessibility, and implementation token guidance; superseded by later phase artifacts
  where values differ.
- `prompts/cairnloop.tokens.json` - structured token mirror useful as a reference, not a new source
  of truth.
- `prompts/cairnloop.css` - pointer confirming canonical CSS moved to `priv/static/cairnloop.css`.

### Existing Scripts and Tests

- `scripts/derive_brandbook_tokens.exs` - existing Elixir generation/check pattern for repo-local
  brandbook derivatives.
- `scripts/verify_brandbook_file_load.mjs` - existing Playwright `file://` verification script to
  extend for Phase 51.
- `test/cairnloop/web/brandbook_scaffold_test.exs` - current static source/package/derivation guard.
- `test/cairnloop/web/token_drift_test.exs` - canonical token and contrast verification patterns.
- `mix.exs` - package `files` allowlist; `brandbook/` must remain absent.
- `.github/workflows/ci.yml` - existing quality, integration, and E2E gate structure.

### External Research References

- `https://carbondesignsystem.com/` - mature design-system docs pattern: design guidance plus
  developer resources in a navigable system.
- `https://polaris-react.shopify.com/tokens/color` - token tables pair names, values, and usage
  descriptions; useful precedent for token rendering.
- `https://m3.material.io/` - mature design-system precedent for color, type, motion, and adaptive
  component guidance.
- `https://mix.hexdocs.pm/1.12/Mix.html` - Mix aliases and project-local workflow guidance.
- `https://phoenix.hexdocs.pm/directory_structure.html` - Phoenix static asset conventions; useful
  contrast for why `brandbook/` remains repo collateral, not shipped `priv/static`.
- `https://github.com/elixir-lang/ex_doc` - Elixir ecosystem docs precedent: generated, responsive,
  offline-accessible static documentation with custom pages/assets.
- `https://playwright.dev/` - browser automation and page/network verification reference.
- `https://ex-doc.hexdocs.pm/0.29.1/Mix.Tasks.Docs.html` - ExDoc assets/custom pages precedent,
  useful as ecosystem context but not a Phase 51 tooling choice.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `brandbook/index.html` currently contains the compact Phase 50 scaffold shell, required labels,
  live token preview, type proof, light/dark proof, and folder readiness list.
- `brandbook/assets/css/brandbook.css` already establishes the static page shell, token-driven
  typography, surfaces, grids, focus ring, responsive single-column behavior, and reduced-motion
  baseline.
- `brandbook/assets/css/tokens.css` already mirrors canonical tokens for `:root` and
  `[data-theme="dark"]`.
- `brandbook/color/swatches.json` already groups primitive, semantic light, and semantic dark color
  rows with token, value, display hex, role, and theme.
- `scripts/derive_brandbook_tokens.exs` already has a deterministic `--check` pattern and loud
  missing-input/drift failure behavior.
- `scripts/verify_brandbook_file_load.mjs` already opens `brandbook/index.html` through `file://`
  and checks console errors, page errors, failed requests, remote requests, non-local requests, and
  required labels.
- `logo/USAGE.md` and committed `logo/*` assets are ready for the Phase 51 logo gallery, diagrams,
  usage rules, and download links.

### Established Patterns

- `priv/static/cairnloop.css` is the single canonical token source; derivatives are mirrors.
- Repo collateral such as `logo/` and `brandbook/` is git-tracked but unshipped. `mix.exs` package
  files currently remain `lib priv guides mix.exs README.md LICENSE CHANGELOG.md`.
- Browser-required facts are automated. Manual smoke notes are not acceptable substitutes for
  `file://`, console/network, theme, responsive, or focus behavior.
- Visual and copy work must stay calm, explicit, accessible, and OSS-maintainer friendly: no generic
  SaaS blue, no purple AI gradients, no chat bubbles, no headset/robot trope, no over-branded nouns,
  and no marketing-heavy hero.

### Integration Points

- Phase 51 consumes Phase 50 scaffold outputs plus Phase 49 logo assets and Phase 48 contrast
  evidence.
- Phase 52 consumes the completed brandbook and finalized logo assets before README/example
  app/favicon/OG wiring.
- Existing CI already has root Elixir quality gates and an example-app Playwright E2E lane. If Phase
  51 adds CI coverage, keep it focused and avoid coupling the brandbook to Phoenix routing.

</code_context>

<specifics>
## Specific Ideas

- The page should answer contributor JTBD directly: choose a token, choose a logo file, verify usage,
  copy approved voice/microcopy patterns, and download the right local asset without needing network
  access or backend knowledge.
- Use exact required labels from `51-UI-SPEC.md`: `Cairnloop brand book`,
  `Support that leaves a trail.`, `Canonical source: priv/static/cairnloop.css :root`,
  `Token status: derived from canonical CSS`, `Network dependency: none`, and
  `Brandbook is git-tracked and unshipped`.
- Keep copper as route-marker emphasis, not section-wide decoration. Use text/icon labels for every
  status and do/don't state.
- Treat mature systems such as Carbon, Polaris, Material, Primer, and Atlassian as inspiration for
  navigable foundations plus usage guidance, not as license to add their tooling or visual language.
- The brand metaphor should guide affordances and motifs, not turn the page into a themed novelty
  surface. Prefer route lines, labels, source cues, and precise specimens over illustration-heavy
  decoration.

</specifics>

<deferred>
## Deferred Ideas

- Generated multi-page docs, hosted docs, search, versioned routes, print/PDF export, component
  playgrounds, analytics, and full-text filtering are deferred beyond Phase 51.
- Style Dictionary, Storybook, Docusaurus, zeroheight-style workflows, public Mix tasks, and a new
  design-token schema are deferred unless a later milestone creates a public multi-platform design
  system.
- README, example-app, favicon, OG, HexDocs, Phoenix route, and package metadata wiring remains Phase
  52 scope.
- Broad screenshot visual-diff baselines and axe-core gating are deferred unless a later plan accepts
  their dependency and maintenance cost explicitly.

</deferred>

---

*Phase: 51-Full HTML Brand Book Assembly*
*Context gathered: 2026-06-25*
