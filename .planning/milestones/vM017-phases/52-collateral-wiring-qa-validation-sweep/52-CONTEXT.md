# Phase 52: Collateral Wiring + QA/Validation Sweep - Context

**Gathered:** 2026-06-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 52 wires the approved Cairnloop collateral into the real repo surfaces that adopters and
contributors touch: the GitHub README, the example Phoenix app logo, the example app favicon, and
example app Open Graph metadata. It also performs the final milestone QA sweep for SVG validity,
raster budget, package boundary, diff hygiene, and rendered browser behavior.

This phase does not reopen the selected C3.6 logo, the Refined palette/type decisions, the brand
book content, product UI behavior, package naming, Hex package files, or new marketing-site scope.
It is a final credibility and verification pass, not a landing-page redesign or a shipped asset
delivery feature.

</domain>

<spec_lock>
## UI Contract Locked

`52-UI-SPEC.md` is present and approved. Downstream agents MUST read it before planning or
implementing. It locks collateral placement, copy, accessibility semantics, registry safety,
verification expectations, and the no-new-design-system boundary.

**In scope (from UI-SPEC / roadmap):**
- `README.md` leads with the approved horizontal SVG logo using a GitHub-renderable repo-relative
  path and `alt="Cairnloop"`.
- `examples/cairnloop_example/priv/static/images/logo.svg` is replaced with approved Cairnloop SVG
  geometry.
- Approved favicon and OG assets are copied/wired into the example app static tree.
- `examples/cairnloop_example/lib/cairnloop_example_web/components/layouts/root.html.heex` gets
  local favicon and OG/social metadata with Phoenix static paths.
- One gated `PhoenixTest.Playwright.Case` E2E proves the example app resolves and displays the logo,
  favicon link, and OG metadata through the app.
- Static/source/package QA records SVG validity, raster budget, package boundary, diff scope, and
  test results.

**Out of scope (from UI-SPEC / roadmap):**
- Changing selected C3.6 logo geometry, canonical token values, palette, type stack, or brandbook
  content.
- Creating new logo assets, new favicon packs, screenshots, marketing pages, analytics, remote
  assets, fonts, npm UI packages, or Phoenix routes for the brandbook.
- Shipping `brandbook/`, `logo/`, or `scripts/` inside the Hex package unless a future phase
  explicitly changes package policy.
- Human UAT for rendered logo/favicon behavior; browser-required facts are automated.

</spec_lock>

<decisions>
## Implementation Decisions

### Logo Sign-Off And Phase Entry

- **D-52-01:** Treat logo-family sign-off as the only subjective precondition. Planning may prepare
  the implementation path, but execution must not wire assets unless sign-off is already recorded or
  is recorded before the first collateral edit. After sign-off, all remaining verification is
  automated.
- **D-52-02:** Do not create new human UAT tasks for favicon/logo/metadata rendering. The owner gate
  is about subjective asset approval, not whether implementation worked.

### README Header Treatment

- **D-52-03:** Use a restrained OSS-library README header: first visible line is the approved
  horizontal SVG logo from `logo/cairnloop-lockup-horizontal.svg`, with alt text exactly
  `Cairnloop`; existing badges remain immediately below it.
- **D-52-04:** Remove or demote the current text/emoji H1 (`# Cairnloop 🏔️`) so the README does not
  duplicate the accessible brand name or mix the new mark with the old emoji identity. Keep install
  and guide content close to the top; do not turn the README into a marketing hero.
- **D-52-05:** The README logo path is for GitHub/repo rendering. Because `logo/` remains outside the
  Hex package allowlist, planners must not assume that packaged HexDocs can render that relative
  image unless they deliberately add a separate docs/package-safe strategy in a later phase.

### Example App Metadata And Static Wiring

- **D-52-06:** Use approved collateral only. Copy the approved favicon/OG assets into
  `examples/cairnloop_example/priv/static` as needed and reference them with Phoenix static paths
  from `root.html.heex`; do not serve library-owned branding assets from a new Plug or package
  surface.
- **D-52-07:** Keep the example app branded as a credible Cairnloop demo surface, not as a standalone
  SaaS product. Recommended document title posture: `Cairnloop` or `Cairnloop Example`, without the
  generated Phoenix suffix. Avoid exposing implementation trivia in browser chrome.
- **D-52-08:** Root metadata must use the approved copy from the UI spec:
  `og:title` = `Cairnloop`, `og:description` = `Embedded support automation for Phoenix apps.`,
  `og:type` = `website`, `og:image` points to the local copied `cairnloop-og.png`, and
  `og:image:alt` = `Cairnloop — Support that leaves a trail.` exactly as specified.
- **D-52-09:** Replace only the existing example static logo file and metadata/static references
  needed for this phase. Do not rework the example app header/navigation beyond making the approved
  logo render without distortion, clipping, cage, or low-contrast background.

### QA Gate Shape

- **D-52-10:** Use a hybrid gate. Put deterministic source/package/asset rules in fast ExUnit tests
  under the normal `mix test` lane; put browser-only static-path/rendering facts in one focused
  `examples/cairnloop_example/test/e2e/*_test.exs` module using
  `PhoenixTest.Playwright.Case` and `@moduletag :e2e`.
- **D-52-11:** Static tests should cover at minimum: README starts with a repo-relative approved SVG
  path and `alt="Cairnloop"`; approved logo inventory exists; SVGs are well-formed with `xmlns` and
  valid `viewBox`; SVGs contain no `<image>`, script, `foreignObject`, external/data hrefs, embedded
  raster, or editor metadata; `du -ck logo/*.png logo/*.ico` plus copied raster outputs stays within
  the 150KB budget; no PNG logo fallbacks are introduced; `mix.exs` package `files` remains
  `lib priv guides mix.exs README.md LICENSE CHANGELOG.md`; `brandbook/`, `logo/`, and `scripts/`
  remain unshipped.
- **D-52-12:** E2E must prove real browser behavior, not just source strings: page loads with the
  new logo visible and nonzero natural dimensions; favicon link(s) resolve to local static paths;
  OG image/title/description/type/image-alt meta tags exist; copied static asset URLs return
  successful responses; no collateral-caused console/page/request failures occur.
- **D-52-13:** Avoid false-pass tests. Browser assertions must include preconditions such as
  connected page, selector exists, bounding boxes/natural sizes are nonzero, and asset URL fetches
  succeeded. Static checks should prefer structured/XML parsing where practical and use explicit
  failure messages naming the path and next action.
- **D-52-14:** A final QA report or phase summary should include command evidence (`mix test`,
  `mix test.e2e`, SVG/raster/package/diff checks), but the report is evidence, not the gate. Tests
  and scripts must fail before the report can claim pass.

### Design, Accessibility, And DX Posture

- **D-52-15:** Use the brandbook's restrained operator-grade direction: calm, precise, OSS-native,
  no launch-copy, no AI-agent hype, no chat-bubble/headset/robot tropes, no decorative overuse of
  copper, and no new visual motifs.
- **D-52-16:** Accessibility semantics are simple: the sole README logo image and the example app
  logo image use `alt="Cairnloop"`; redundant duplicate logos near visible `Cairnloop` text may be
  decorative, but do not make the only brand identifier decorative. Favicon has no alt; OG metadata
  uses `og:image:alt`.
- **D-52-17:** Preserve developer ergonomics. Use idiomatic Phoenix `priv/static` assets and
  verified/static paths already available in the example app. Do not add dependencies, global build
  tooling, runtime asset services, or a custom branded asset delivery API for this phase.

### Claude's Discretion

Planner/executor may choose exact filenames for copied example-app assets, the exact ExUnit module
boundary, whether to extend existing brandbook source guards or create a Phase 52-specific test
module, and exact Playwright selectors. Keep the write set narrow, failure messages actionable, and
assertions tied directly to Phase 52 requirements.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 52 Contract

- `.planning/phases/52-collateral-wiring-qa-validation-sweep/52-UI-SPEC.md` - locked collateral
  placement, copy, accessibility, color/type, registry safety, and verification contract.
- `.planning/ROADMAP.md` - Phase 52 goal, dependencies, requirements, and success criteria.
- `.planning/REQUIREMENTS.md` - WIRE-01, WIRE-02, WIRE-03, HYGIENE-01, HYGIENE-02, HYGIENE-03.
- `.planning/STATE.md` - vM017 locked decisions, logo-family sign-off gate, repo hygiene, and
  automated rendered-behavior verification policy.
- `.planning/PROJECT.md` - milestone goal, brand constraints, package posture, and project
  positioning.

### Prior Phase Decisions

- `.planning/phases/51-full-html-brand-book-assembly/51-CONTEXT.md` - completed brandbook boundary
  and Phase 52 handoff.
- `.planning/phases/51-full-html-brand-book-assembly/51-UI-SPEC.md` - brandbook visual/content
  contract that Phase 52 must not reopen.
- `.planning/phases/50-brandbook-scaffold-token-derivation-pipeline/50-CONTEXT.md` - repo-local
  brandbook tooling, package boundary, and no-network collateral decisions.
- `.planning/phases/49-chosen-logo-finalization-asset-family/49-CONTEXT.md` - final logo asset
  family, favicon, OG, usage rules, and Phase 52 handoff.
- `.planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md` - selected C3.6
  mark, Refined palette, type stack, and rejected directions.

### Brand And Source Inputs

- `logo/USAGE.md` - approved files, allowed uses, clearspace, minimum sizes, and do/don't rules.
- `logo/cairnloop-lockup-horizontal.svg` - default public lockup for README and broad brand
  identification.
- `logo/cairnloop-mark.svg` - icon-only mark; use only where wordmark is too small or redundant.
- `logo/favicon.svg`, `logo/favicon-16.png`, `logo/favicon-32.png`, `logo/favicon.ico` - approved
  simplified favicon cut and raster fallbacks.
- `logo/cairnloop-og.png`, `logo/cairnloop-og.svg` - approved OG/social image output and source.
- `brandbook/index.html` - newer rendered brandbook; supersedes older prompt guidance where values
  differ.
- `brandbook/assets/css/tokens.css`, `brandbook/color/swatches.json`, `brandbook/TOKENS.md` -
  generated token collateral and package-boundary notes.
- `prompts/cairnloop_brand_book.md` - older but still useful brand strategy, voice, README opener,
  accessibility, and competitive-distinctiveness research; newer phase assets supersede conflicts.
- `prompts/elixir-lib-customer-support-automation-deep-research.md` - product/DX research; use for
  positioning lessons, not old placeholder naming.
- `prompts/cairnloop.tokens.json`, `prompts/cairnloop.css` - structured token/name references and
  pointer to canonical CSS.
- `priv/static/cairnloop.css` - canonical shipped token source.

### Existing Implementation Surfaces

- `README.md` - current text/emoji heading and badges to update.
- `mix.exs` - Hex package `files` allowlist; keep `brandbook/`, `logo/`, and `scripts/` excluded.
- `examples/cairnloop_example/lib/cairnloop_example_web/components/layouts/root.html.heex` - root
  document head for title, favicon, and OG tags.
- `examples/cairnloop_example/lib/cairnloop_example_web.ex` - static path allowlist currently
  includes `assets fonts images favicon.ico robots.txt`.
- `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex` - `Plug.Static` serves
  `priv/static`.
- `examples/cairnloop_example/priv/static/images/logo.svg` - existing placeholder logo replacement
  target.
- `examples/cairnloop_example/priv/static/favicon.ico` - favicon replacement target.
- `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs`,
  `examples/cairnloop_example/test/e2e/rail_disclosure_test.exs`,
  `examples/cairnloop_example/test/e2e/thread_navigation_test.exs` - existing E2E style:
  `PhoenixTest.Playwright.Case`, explicit preconditions, `evaluate/3`, `@moduletag :e2e`.
- `examples/cairnloop_example/mix.exs` - `test.e2e` alias and Playwright dependency live in the
  example app, not the published library.
- `.github/workflows/ci.yml` - existing E2E CI lane installs Playwright and runs `PW_TRACE=true mix
  test.e2e` from the example app.
- `test/cairnloop/web/brandbook_scaffold_test.exs` - closest static/source/package guard pattern.
- `scripts/derive_brandbook_tokens.exs`, `scripts/assemble_brandbook.exs`,
  `scripts/verify_brandbook_file_load.mjs` - existing collateral generation/verification patterns.

### External References Used During Discussion

- `https://phoenix.hexdocs.pm/Phoenix.VerifiedRoutes.html` - Phoenix verified/static path behavior;
  static paths can be compile-time verified and `static_path` generates static asset paths.
- `https://hex.pm/docs/publish` - Hex package metadata and `:files` behavior; package contents are
  governed by the project `mix.exs` configuration.
- `https://hex.hexdocs.pm/Mix.Tasks.Hex.Publish.html` - Hex package/documentation size and publish
  behavior; useful for package-boundary QA.
- `https://phoenix-test-playwright.hexdocs.pm/` and
  `https://github.com/ftes/phoenix_test_playwright/blob/main/lib/phoenix_test/playwright.ex` -
  PhoenixTest Playwright browser-backed ExUnit pattern and `evaluate/2`/browser helpers.
- `https://playwright.dev/` - Playwright reliability model, web-first assertions, and traceable
  browser automation.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `logo/` contains the approved SVG/raster asset family ready for README and example-app wiring.
- `logo/USAGE.md` inventories every approved file and explicitly says Phase 52 owns README,
  favicon, OG metadata, and example-app wiring after sign-off.
- The example app already serves `images` and `favicon.ico` from `priv/static`; new copied assets
  should fit this existing static tree.
- Existing E2E tests already use the required browser harness and explicit false-pass prevention.
- Existing brandbook tests already pin package allowlist and approved logo inventory patterns.

### Established Patterns

- `priv/static/cairnloop.css` is canonical; collateral wiring should not create another token or
  palette source.
- Browser-required facts are automated with gated Playwright E2E, never human verify.
- The published package stays narrow: `lib priv guides mix.exs README.md LICENSE CHANGELOG.md`.
- Repo collateral (`brandbook/`, `logo/`, `scripts/`) is git-tracked but unshipped.
- The example app owns its own static files and E2E dependency so adopters do not inherit browser
  testing dependencies from the library package.

### Integration Points

- README update connects at the top of `README.md`.
- Example logo replacement connects at `examples/cairnloop_example/priv/static/images/logo.svg`.
- Favicon/OG copies connect under `examples/cairnloop_example/priv/static/` and
  `examples/cairnloop_example/priv/static/images/`.
- Metadata connects in `root.html.heex` because Open Graph tags belong in the document head, not in
  LiveView body content.
- E2E connects under `examples/cairnloop_example/test/e2e/` and is discovered by existing
  `mix test.e2e`.

</code_context>

<specifics>
## Specific Ideas

- Recommended path: restrained OSS-library treatment, not a launch-page rewrite.
- README should look like successful OSS READMEs: logo/header, badges, concise value, install path,
  docs links.
- Example app should read as a Cairnloop demo host and not hide behind generated Phoenix branding.
- The QA sweep should be useful for a maintainer reviewing a release: clear PASS/FAIL evidence,
  exact failed path, and next action.
- Preserve the landmine in planning: `logo/` is not packaged, so README logo behavior on GitHub and
  HexDocs/package docs are different unless package policy changes later.

</specifics>

<deferred>
## Deferred Ideas

- A full marketing landing page, broader public docs homepage, or screenshot-led launch treatment
  belongs in a later phase.
- Shipping brand assets from the library package, a reusable branded asset Plug, or a HexDocs-safe
  packaged logo strategy is deferred unless package policy changes.
- Full PWA/apple-touch/android icon pack remains out of scope.
- Brandbook public hosting or Phoenix routing remains out of scope.

</deferred>

---

*Phase: 52-Collateral Wiring + QA/Validation Sweep*
*Context gathered: 2026-06-26*
