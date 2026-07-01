# Phase 50: Brandbook Scaffold & Token-Derivation Pipeline - Context

**Gathered:** 2026-06-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 50 creates the repo-local, self-contained `brandbook/` scaffold and the token-derivation
substrate for the future full HTML brand book. It proves that `brandbook/index.html` opens directly
from `file://`, uses only relative/local assets, consumes derived Cairnloop tokens, and gives Phase
51 a clean folder/data structure to fill.

This phase does **not** assemble the full brand book. It does not render the full logo gallery,
do/don't panels, contrast badge tables, downloads, motion specimens, or the light/dark toggle that
belong to Phase 51. It does not wire assets into README, the example app, favicon metadata, or
package/docs surfaces; Phase 52 owns wiring.

</domain>

<spec_lock>
## Requirements and UI Contract Locked

`50-UI-SPEC.md` is present and approved. Downstream agents MUST read it before planning or
implementing. It locks the Phase 50 visual boundary, required artifact list, copy labels, token
derivation contract, registry safety rules, and verification expectations.

**In scope (from UI-SPEC / roadmap):**
- `brandbook/index.html` as a compact static scaffold shell that opens from `file://`.
- `brandbook/assets/css/tokens.css` derived from canonical `priv/static/cairnloop.css`.
- `brandbook/assets/css/brandbook.css` for scaffold-only layout that consumes `--cl-*` variables.
- `brandbook/color/swatches.json` as structured generated/mirrored swatch data.
- `brandbook/TOKENS.md` documenting source, derivation method, regeneration, and drift checks.
- Placeholder or copy destinations for `brandbook/logo/` and `brandbook/raster/`.

**Out of scope (from UI-SPEC / roadmap):**
- Full brand book content assembly, logo usage gallery, do/don't panels, contrast badge tables, and
  downloads.
- JavaScript theme toggle unless a later plan explicitly authorizes it.
- Network fonts, CDNs, remote assets, analytics, registries, shadcn, npm UI packages, or third-party
  design blocks.
- Package, Phoenix endpoint, README, example-app, favicon, or OG wiring.

</spec_lock>

<decisions>
## Implementation Decisions

### Token Derivation Method

- **D-50-01:** Use a repo-local Elixir derivation script invoked with `mix run`, for example
  `mix run scripts/derive_brandbook_tokens.exs`, rather than a shipped Mix task, POSIX shell
  extraction, a manual mirror, or a Node design-token pipeline.
- **D-50-02:** The script should generate or verify both `brandbook/assets/css/tokens.css` and
  `brandbook/color/swatches.json` from `priv/static/cairnloop.css` `:root` and
  `[data-theme="dark"]`. It should support a `--check` mode that fails loudly on drift, missing CSS
  blocks, malformed output, or unresolved required token groups.
- **D-50-03:** Do not place this helper under `lib/mix/tasks` for Phase 50. A custom Mix task is
  idiomatic in Elixir, but this repo's package includes all of `lib`, and the brandbook helper is
  internal repo collateral, not a public Hex package feature.
- **D-50-04:** Do not introduce Style Dictionary, Node tooling, or a new token source. Those tools
  are valuable for multi-platform token publishing, but Phase 50's source of truth is already CSS
  and the brandbook must remain local, lightweight, and unshipped.

### Swatch JSON Shape

- **D-50-05:** Use a lean grouped schema for `brandbook/color/swatches.json`, not a flat
  token/value dump and not a full contrast-matrix data model.
- **D-50-06:** The schema should include file-level provenance such as `schema_version`,
  `source_file`, `generated_at` or equivalent, and the derivation command/check command. Color rows
  should be grouped as `primitive`, `semantic_light`, and `semantic_dark`.
- **D-50-07:** Each swatch row should preserve the token name, hex value, group, role/description
  where available, and theme where relevant. It may resolve simple aliases to their canonical hex
  values for display, but it must not become a new design authority.
- **D-50-08:** Do not compute or store pairwise contrast badges in Phase 50. Phase 51 can render
  contrast content from the Phase 48 contrast evidence and the generated swatch rows. Keeping
  contrast out of `swatches.json` avoids stale metadata and a fourth palette source.

### Scaffold Proof Content

- **D-50-09:** Build a compact professional scaffold shell, not a bare placeholder and not a rich
  Phase 51 preview. The page should feel like the first page of a serious brand reference while
  remaining intentionally incomplete.
- **D-50-10:** `index.html` should include only: compact title/provenance header, three status cells
  (`Self-contained`, `Canonical tokens`, `Ready for Phase 51`), a small live token preview, restrained
  type specimens using the approved fallback stacks, a minimal light/dark token proof block, a
  folder/file readiness list, and a footer provenance note.
- **D-50-11:** Required copy should stay operational and exact: `Cairnloop brand book`,
  `Canonical source: priv/static/cairnloop.css :root`, `Token status: derived from canonical CSS`,
  `Network dependency: none`, `Full brand book assembly is Phase 51`, and
  `Brandbook is git-tracked and unshipped`.
- **D-50-12:** Avoid marketing hero patterns, oversized landing-page composition, stock/remote
  imagery, decorative gradients/orbs, nested cards, generic launch copy, live-text recreation of the
  wordmark, and exposing parser/backend implementation details in the user-facing page. Provenance
  belongs in concise maintainer-facing copy, not as implementation guts.
- **D-50-13:** Every visual state or proof cue must pair color with text. Use the locked Cairnloop
  type stacks, token-driven focus ring if any focusable anchor exists, and graceful local fallbacks.

### Verification Strictness

- **D-50-14:** Require automated `file://` browser proof plus source checks. A manual smoke note is
  not enough because the project has ratified that browser-required behavior is automated, not
  human UAT.
- **D-50-15:** Do not route the brandbook through Phoenix or the example app just to reuse the
  existing PhoenixTest/Playwright E2E lane. The brandbook is self-contained, repo-local, and
  unshipped; serving it from the example app would blur the Phase 50 package boundary.
- **D-50-16:** Verification evidence should include: required file layout exists; `mix.exs` package
  `files` still excludes `brandbook/`; source grep proves no `http://`, `https://`, protocol-relative
  `//`, CDN, `@import`, remote `url(...)`, iframe, beacon, or root-relative production paths; the
  derivation script `--check` passes; `TOKENS.md` documents source, command, regeneration, and drift
  prevention; and a focused Playwright run opens the absolute `file://.../brandbook/index.html` with
  zero console errors and zero failed/remote network requests.
- **D-50-17:** Keep Phase 50 verification focused. It may live as a small script or documented
  command invoked by the phase plan. Do not expand CI or release gates unless the planner finds a
  low-friction way to do so without coupling `brandbook/` to the shipped package or example app.

### Claude's Discretion

Planner/executor may choose the exact Elixir parser structure, generated JSON ordering, CSS class
names, file comments, and Playwright harness location as long as the outputs are deterministic,
easy to review, and preserve the decisions above. Prefer simple, boring, repo-local tooling over a
generalized design-token platform.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 50 Contract

- `.planning/phases/50-brandbook-scaffold-token-derivation-pipeline/50-UI-SPEC.md` — locked visual,
  interaction, copywriting, token derivation, and verification contract.
- `.planning/ROADMAP.md` — Phase 50 goal, dependencies, success criteria, and phase boundary.
- `.planning/REQUIREMENTS.md` — BOOK-01 and BOOK-02 requirements; Phase 51/52 boundaries.
- `.planning/STATE.md` — vM017 token discipline, repo hygiene, and automated rendered-behavior
  verification policy.
- `.planning/PROJECT.md` — current milestone goal, brand constraints, and project posture.

### Brand and Token Sources

- `priv/static/cairnloop.css` — canonical `--cl-*` token source for `:root` and
  `[data-theme="dark"]`.
- `prompts/cairnloop.tokens.json` — existing structured token mirror; useful as a shape reference,
  not a new source of truth.
- `prompts/cairnloop.css` — pointer confirming the old prompt CSS moved to
  `priv/static/cairnloop.css`.
- `prompts/cairnloop_brand_book.md` — brand voice, positioning, visual motifs, typography, and
  competitive avoidance guidance; superseded by later phase artifacts where values differ.
- `.planning/phases/48-token-evolution-lock-propagate/48-UI-SPEC.md` — selected Refined palette,
  type stack, and token propagation contract.
- `.planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md` — Phase 48 contrast
  evidence that Phase 51 can render as brandbook content.

### Logo and Future Brandbook Inputs

- `logo/USAGE.md` — Phase 51 source for logo gallery, clearspace, minimum-size, and do/don't content;
  do not render the full gallery in Phase 50.
- `logo/cairnloop-lockup-horizontal.svg` — final primary lockup available for later Phase 51/52 use.
- `logo/cairnloop-mark.svg` — final mark available for later Phase 51/52 use.
- `.planning/phases/49-chosen-logo-finalization-asset-family/49-CONTEXT.md` — asset family decisions
  and Phase 51/52 handoff boundaries.
- `.planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md` — selected C3.6
  mark, Refined palette, and current type stack.

### Package and Verification Patterns

- `mix.exs` — package `files` list; `brandbook/` must remain absent.
- `.github/workflows/ci.yml` — existing quality, integration, and E2E gate structure; Phase 50 should
  not casually expand CI.
- `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs` — current project pattern for
  automated browser geometry checks with explicit anti-false-pass preconditions.
- `examples/cairnloop_example/test/e2e/rail_disclosure_test.exs` — current Playwright/PhoenixTest
  pattern for client/browser behavior checks.

### External Research References

- `https://hexdocs.pm/mix/Mix.Task.html` — Mix task conventions; relevant to why a public task is
  idiomatic but not chosen for this unshipped collateral helper.
- `https://hexdocs.pm/phoenix/asset_management.html` — Phoenix asset tooling favors lightweight
  repo-local asset handling without unnecessary Node/Webpack dependence.
- `https://playwright.dev/docs/network` — Playwright network monitoring for failed/remote request
  checks.
- `https://playwright.dev/docs/api/class-page` — Playwright page events and console/error inspection.
- `https://styledictionary.com/info/tokens/` — mature multi-platform token-system reference; useful
  as contrast for why Phase 50 should not add a broad token platform.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `priv/static/cairnloop.css` already contains the evolved Refined palette, semantic light/dark
  variables, spacing, typography, radius, shadow, focus, and motion tokens that the brandbook should
  mirror.
- `prompts/cairnloop.tokens.json` already separates primitive colors from semantic light/dark
  mappings; use it as a schema precedent while keeping CSS canonical.
- `logo/USAGE.md` and committed `logo/*.svg`/raster assets are ready for Phase 51/52, but Phase 50
  should only create destinations/proof paths, not render the full logo system.
- Existing E2E files show how the repo writes browser checks: explicit preconditions, real rendered
  behavior, and no human verification fallback for browser-only facts.

### Established Patterns

- `priv/static/cairnloop.css` is the single canonical token source; derivatives are mirrors.
- Repo collateral such as `logo/` and `brandbook/` stays git-tracked but unshipped. `mix.exs` package
  files are currently `lib priv guides mix.exs README.md LICENSE CHANGELOG.md`.
- Cairnloop avoids new build/runtime dependencies unless they pay for themselves. For Phase 50, an
  Elixir script preserves repo-local DX without adding Node or public package surface.
- Visual work must stay calm, explicit, accessible, and OSS-maintainer friendly: no chatbot trope,
  no generic SaaS blue/AI-gradient language, no marketing-heavy hero.

### Integration Points

- Phase 51 consumes `brandbook/`, `swatches.json`, `TOKENS.md`, `logo/USAGE.md`, and Phase 48
  contrast evidence to assemble the full HTML brand book.
- Phase 52 consumes the final logo assets and completed brand book before wiring README, example app,
  favicon, and OG metadata.
- Future maintainers use the derivation script plus `TOKENS.md` to regenerate or verify brandbook
  token outputs without guessing.

</code_context>

<specifics>
## Specific Ideas

- Recommended command shape: `mix run scripts/derive_brandbook_tokens.exs` and
  `mix run scripts/derive_brandbook_tokens.exs --check`.
- `tokens.css` should preserve `--cl-*` names and include provenance comments naming
  `priv/static/cairnloop.css`.
- `swatches.json` should be deterministic and reviewable: stable ordering, no generated noise, and
  no per-run churn unless token values changed.
- The Phase 50 page should read as a maintainer proof surface: "the scaffold and canonical token
  mirror are ready," not "the brand book is done."

</specifics>

<deferred>
## Deferred Ideas

- Full color swatches with contrast badges, type system sections, logo gallery, clearspace diagrams,
  do/don't panels, light/dark toggle, and voice/imagery guidance belong to Phase 51.
- README header, example-app logo replacement, favicon metadata, OG image wiring, and rendered
  example-app verification belong to Phase 52.
- A public `mix cairnloop.brandbook` or package-consumer regeneration task is deferred unless a
  later milestone intentionally ships brandbook tooling as part of the Hex package.
- A Style Dictionary or DTCG-style multi-platform token pipeline is deferred unless Cairnloop later
  needs design-token outputs beyond CSS/HTML/JSON for this repo.

</deferred>

---

*Phase: 50-Brandbook Scaffold & Token-Derivation Pipeline*
*Context gathered: 2026-06-25*
