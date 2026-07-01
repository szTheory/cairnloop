# Phase 51: Full HTML Brand Book Assembly - Research

**Researched:** 2026-06-25
**Domain:** Static offline HTML brand-book assembly with repo-local Elixir generation/checking, token-driven CSS, local logo assets, and Playwright file-url verification
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-51-01:** Use one ordered long-form `brandbook/index.html` page with a sticky desktop in-page navigation and a static anchored contents list on mobile.
- **D-51-02:** Use this section order unless implementation uncovers a strong local reason to adjust: Header, Contents, Color, Typography, Spacing/Radius/Shadow/Motion tokens, Logo system, Voice/Microcopy, Imagery, Motion guidance, Downloads, Footer.
- **D-51-03:** Do not hide core brand rules in accordions or progressive disclosure. Every required section must show at least one rendered example, one source/provenance cue, and one usage rule. Native `<details>` is allowed only for secondary provenance/regeneration notes.
- **D-51-04:** The first viewport should feel like a dense reference document, not a marketing hero: page title `Cairnloop brand book`, tagline, provenance, network status, theme toggle, and a visible hint of the Color section.
- **D-51-05:** Optimize for maintainers, designers, future agents, and OSS contributors answering: "What should I use?", "Why does this rule exist?", "Where is the file?", and "What must I avoid?" Do not expose parser internals or implementation guts in primary user-facing copy.
- **D-51-06:** Use a repo-local Elixir generation/check approach for Phase 51 content assembly, modeled on `mix run scripts/derive_brandbook_tokens.exs`. The output remains plain static HTML/CSS committed under `brandbook/`.
- **D-51-07:** Essential brandbook content should be generated or checked at build time from repo-local sources, not fetched at runtime. Do not rely on `fetch("./color/swatches.json")` for required content because `file://` JSON loading is browser-fragile and can blank important sections.
- **D-51-08:** JavaScript is allowed only as a small local progressive enhancement for the light/dark toggle, optional session persistence, and nonessential computed-style enhancement. With JavaScript unavailable, the core document content must remain visible and useful.
- **D-51-09:** Keep `priv/static/cairnloop.css` canonical. `brandbook/assets/css/tokens.css`, `brandbook/color/swatches.json`, and any Phase 51 generated HTML are derivatives or rendered references, not new sources of truth.
- **D-51-10:** Keep generated output deterministic and reviewable: stable ordering, no timestamps in generated HTML unless required by an existing provenance contract, clear comments on generated files, and loud `--check` failures for drift or missing inputs.
- **D-51-11:** Render contrast badges from Phase 48 contrast evidence and token values, not from a new contrast matrix inside `swatches.json`. Badges should read as `AA pass`, `UI pass`, or `Decorative exempt` and must pair status color with text/icon labels.
- **D-51-12:** Render `logo/USAGE.md` facts into friendly HTML: approved-file gallery, clearspace diagram, minimum-size table, do/don't panels, and relative download links. Do not expose Markdown parsing details to brandbook readers.
- **D-51-13:** Do not add Style Dictionary, Storybook, Docusaurus, zeroheight-style tooling, a public Mix task under `lib/mix/tasks`, or a Node design-token pipeline in Phase 51.
- **D-51-14:** Use a layered gate, not manual UAT, for browser-required facts. Static ExUnit/source checks should cover required sections, forbidden dependencies, package boundary, generated token freshness, swatch/logo/download inventory, and required contrast badge text.
- **D-51-15:** Extend `scripts/verify_brandbook_file_load.mjs` for browser-only facts: `file://` load, zero console/page errors, zero failed or remote requests, light/dark toggle state changes, keyboard-visible focus, local asset failure copy, and responsive smoke across mobile/tablet/desktop.
- **D-51-16:** Rendered checks must prove preconditions before claiming success. Failure messages should name the file, selector, state, and next action.
- **D-51-17:** Keep Playwright verification focused and independent of Phoenix routing.
- **D-51-18:** Use targeted geometry/pixel sanity checks for blank-page, clipped-layout, theme, and viewport regressions. Do not add broad visual-diff snapshot baselines in Phase 51.
- **D-51-19:** Axe-core or equivalent automated accessibility scanning is useful but not required unless the planner can add it with a small local dependency and clear CI ergonomics. Automated a11y scans must never be described as complete WCAG sign-off.
- **D-51-20:** If CI is touched, keep it as a small explicit brandbook verification lane using the existing Playwright install pattern.

### the agent's Discretion

Planner/executor may choose exact CSS class names, Elixir module/script shape, EEx or string-builder organization, parsing helpers, generated HTML formatting, and verification helper boundaries. Prefer simple data-first generation and readable committed output over clever templating. Keep the page calm, precise, accessible, and OSS-maintainer friendly.

### Deferred Ideas (OUT OF SCOPE)

- Generated multi-page docs, hosted docs, search, versioned routes, print/PDF export, component playgrounds, analytics, and full-text filtering are deferred beyond Phase 51.
- Style Dictionary, Storybook, Docusaurus, zeroheight-style workflows, public Mix tasks, and a new design-token schema are deferred unless a later milestone creates a public multi-platform design system.
- README, example-app, favicon, OG, HexDocs, Phoenix route, and package metadata wiring remains Phase 52 scope.
- Broad screenshot visual-diff baselines and axe-core gating are deferred unless a later plan accepts their dependency and maintenance cost explicitly.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BOOK-03 | Brand book renders all live HTML sections: swatches, type, spacing/radius/shadow/motion, voice/microcopy/imagery guidance. [VERIFIED: .planning/REQUIREMENTS.md] | Use generated/checkable static HTML from `tokens.css`, `swatches.json`, Phase 48 contrast evidence, and `prompts/cairnloop_brand_book.md`; no required runtime `fetch`. [VERIFIED: codebase grep] |
| BOOK-04 | Brand book presents chosen logo system with gallery, clearspace/min-size diagrams, do/don't panels, and download links. [VERIFIED: .planning/REQUIREMENTS.md] | Render `logo/USAGE.md` plus committed `logo/*` assets as friendly HTML with relative links and asset inventory checks. [VERIFIED: codebase grep] |
| BOOK-05 | Brand book supports light/dark toggle and never communicates state by color alone. [VERIFIED: .planning/REQUIREMENTS.md] | Use local progressive JS for theme only, text/icon labels for status and do/don't states, WCAG 1.4.1/1.4.11 checks, and Playwright focus/theme proof. [CITED: https://www.w3.org/TR/WCAG22/] |
</phase_requirements>

## Summary

Phase 51 should be planned as an offline static-document assembly phase, not as an app, route, docs platform, or design-system tooling phase. The repo already contains the Phase 50 scaffold, generated `tokens.css`, generated `swatches.json`, a deterministic Elixir generator/checker, a focused Playwright file-url verifier, and DB-free ExUnit source guards. [VERIFIED: codebase grep]

The most reliable implementation path is to extend the existing repo-local generation/check pattern: parse or embed data from canonical local sources, generate deterministic `brandbook/index.html`, keep layout in `brandbook/assets/css/brandbook.css`, and strengthen `test/cairnloop/web/brandbook_scaffold_test.exs` plus `scripts/verify_brandbook_file_load.mjs`. [VERIFIED: codebase grep] Essential content should be in committed HTML, because MDN documents `file:///` CORS failures for `fetch()` and related browser loads. [CITED: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS/Errors/CORSRequestNotHttp]

**Primary recommendation:** Use one repo-local Elixir assembly/check seam plus the existing CSS and Playwright verifier; add no new package or app runtime. [VERIFIED: codebase grep]

## Project Constraints (from CLAUDE.md)

- Warnings-clean builds are mandatory: `mix compile --warnings-as-errors`. [VERIFIED: CLAUDE.md]
- Run `mix test` before declaring implementation done; report failures honestly. [VERIFIED: CLAUDE.md]
- Prefer headless/pure tests where `Cairnloop.Repo` may be unavailable. [VERIFIED: CLAUDE.md]
- Operator copy must be calm, fail-closed, reason-forward, honest, humanized, and never state-by-color-alone. [VERIFIED: CLAUDE.md]
- Use brand tokens over hardcoded hex, with primary fallback `var(--cl-primary, #A94F30)`. [VERIFIED: CLAUDE.md]
- Do not churn sealed product code paths for downstream display concerns; Phase 51 is collateral/static brandbook work. [VERIFIED: CLAUDE.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Brandbook content assembly | Repo-local build/check script | Static HTML | Local Elixir script owns deterministic extraction and committed output; browser only renders committed static files. [VERIFIED: codebase grep] |
| Token authority | Canonical CSS source | Generated brandbook mirror | `priv/static/cairnloop.css` remains canonical; `brandbook/assets/css/tokens.css` and `swatches.json` are derivatives. [VERIFIED: codebase grep] |
| Visual layout and responsive behavior | Static CSS | Browser | `brandbook/assets/css/brandbook.css` owns layout, tables, specimens, theme state, and responsive behavior using `--cl-*` tokens. [VERIFIED: 51-UI-SPEC.md] |
| Theme toggle | Browser / Client | Static HTML fallback | Small local JS may switch `data-theme`; content must remain useful without JS. [VERIFIED: 51-CONTEXT.md] |
| Logo gallery and downloads | Static HTML | Local filesystem assets | Committed `logo/*` assets are rendered and linked relatively; Phase 52 owns shipped-surface wiring. [VERIFIED: codebase grep] |
| Verification | ExUnit source checks + Playwright file-url script | CI optional | Source checks cover deterministic facts; Playwright covers browser-only facts without Phoenix routing. [VERIFIED: codebase grep] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Elixir / Mix | 1.19.5 local | Run repo-local generation/check scripts with `mix run`. [VERIFIED: local command] | Existing `scripts/derive_brandbook_tokens.exs` uses this pattern; Mix docs describe `mix run` as running commands inside the project. [CITED: https://mix.hexdocs.pm/Mix.html] |
| Jason | 1.4.5 locked | Decode/encode swatch/token JSON. [VERIFIED: mix.lock] | Already present in project deps and used by token derivation tests/script. [VERIFIED: codebase grep] |
| Static HTML/CSS | browser-native | Offline document rendering, responsive tables, specimens, theme states. [VERIFIED: 51-UI-SPEC.md] | Phase contract forbids framework/runtime/docs tooling. [VERIFIED: 51-CONTEXT.md] |
| Playwright | 1.60.0 locked in example app assets | `file://` load, console/page/network, theme, focus, viewport checks. [VERIFIED: package-lock.json + npm registry] | Playwright docs expose page events and network monitoring needed for the existing verifier. [CITED: https://playwright.dev/docs/api/class-page] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| ExUnit | Elixir 1.19.5 local | DB-free source/package/content checks. [VERIFIED: local command] | Extend `Cairnloop.Web.BrandbookScaffoldTest` for required sections, forbidden dependencies, asset inventory, badges, and package boundary. [VERIFIED: codebase grep] |
| `xmllint` | system `/usr/bin/xmllint` | Optional SVG sanity if logo asset links/inventory are rechecked. [VERIFIED: local command] | Use only for asset validation support; do not modify logo SVGs in Phase 51. [VERIFIED: 51-CONTEXT.md] |
| `rg` | available locally | Fast source/path/dependency guards. [VERIFIED: local command] | Use for no-remote/no-root-path and scope guards. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Repo-local Elixir generation | Style Dictionary / Node token pipeline | Explicitly out of scope and creates a second tooling stack for a single offline document. [VERIFIED: 51-CONTEXT.md] |
| Static HTML | Storybook / Docusaurus / Phoenix route | Violates standalone `file://` and no hosted docs/platform boundary. [VERIFIED: 51-CONTEXT.md] |
| Focused Playwright checks | Broad visual-diff baselines | Phase context says broad snapshots are brittle and deferred. [VERIFIED: 51-CONTEXT.md] |
| Existing local Playwright | Upgrade to latest npm package | Latest `playwright` exists at 1.61.1 but legitimacy seam flags it `SUS` due to freshness; reuse locked 1.60.0. [VERIFIED: npm registry] |

**Installation:**

```bash
# No new package install for Phase 51.
mix deps.get
npm --prefix examples/cairnloop_example/assets ci
```

## Package Legitimacy Audit

Phase 51 should not install new external packages. [VERIFIED: 51-CONTEXT.md] Existing verification reuses locked Playwright from `examples/cairnloop_example/assets/node_modules`. [VERIFIED: codebase grep]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `playwright` | npm | Latest modified 2026-06-25; locked local version 1.60.0 [VERIFIED: npm registry] | 62,633,817/wk [VERIFIED: package-legitimacy seam] | github.com/microsoft/playwright [VERIFIED: npm registry] | SUS for latest package freshness [VERIFIED: package-legitimacy seam] | Do not upgrade; reuse locked local 1.60.0 |
| `jason` | Hex | 1.4.5 release listed 2026-05-05 [VERIFIED: Hex registry] | 446,210 last 7 days [VERIFIED: Hex registry] | github.com/michalmuskala/jason [VERIFIED: Hex registry] | OK existing dependency | Approved existing use |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** `playwright` latest only; planner should avoid upgrade/install and use the lockfile.

## Architecture Patterns

### System Architecture Diagram

```text
Local source files
  priv/static/cairnloop.css
  brandbook/assets/css/tokens.css
  brandbook/color/swatches.json
  .planning/phases/48-.../48-CONTRAST-REVERIFY.md
  logo/USAGE.md + logo/*
  prompts/cairnloop_brand_book.md
        |
        v
Repo-local Elixir assembly/check script
  - parse/validate local sources
  - build deterministic section data
  - fail loudly on missing/drifted inputs
        |
        v
Committed static outputs
  brandbook/index.html
  brandbook/assets/css/brandbook.css
        |
        v
Browser opens file://brandbook/index.html
  |-- JS available: local theme toggle enhances data-theme
  `-- JS unavailable: all core content remains visible
        |
        v
Verification
  ExUnit source/package/content guards + Playwright file-url browser proof
```

### Recommended Project Structure

```text
brandbook/
├── index.html                  # generated or checked complete one-page brand reference
├── TOKENS.md                   # existing token derivation handoff
├── assets/css/
│   ├── tokens.css              # generated mirror; do not hand-edit
│   └── brandbook.css           # hand-authored layout/specimen CSS
├── color/swatches.json         # generated lean swatch data
├── logo/                       # optional copied specimens only if planner chooses local brandbook copies
└── raster/                     # optional copied favicon/OG rasters only if planner chooses local brandbook copies
scripts/
├── derive_brandbook_tokens.exs # existing token derivation/check script
└── verify_brandbook_file_load.mjs
test/cairnloop/web/
└── brandbook_scaffold_test.exs # extend into full source/content/package guard
```

### Pattern 1: Deterministic Local Assembly

**What:** Generate or check `brandbook/index.html` from repo-local files with stable ordering, no timestamps, and loud failures. [VERIFIED: 51-CONTEXT.md]
**When to use:** Required sections depend on token, contrast, logo, and voice inputs. [VERIFIED: 51-UI-SPEC.md]

```elixir
# Source: scripts/derive_brandbook_tokens.exs local pattern
def run(argv) do
  check? = "--check" in argv
  outputs = build_outputs()

  if check? do
    check_outputs!(outputs)
  else
    write_outputs!(outputs)
  end
end
```

### Pattern 2: Browser Facts Stay in Playwright

**What:** Keep file-url browser assertions in `scripts/verify_brandbook_file_load.mjs`, collecting console, page error, request, failed request, viewport, theme, and focus facts. [VERIFIED: codebase grep]
**When to use:** Any claim about browser rendering, JS toggle behavior, network absence, keyboard focus, or viewport geometry. [CITED: https://playwright.dev/docs/network]

```javascript
// Source: scripts/verify_brandbook_file_load.mjs + Playwright Page docs
page.on("pageerror", (error) => pageErrors.push(error.message));
page.on("request", (request) => requests.push(request.url()));
page.on("requestfailed", (request) => {
  failedRequests.push(`${request.url()} ${request.failure()?.errorText || "request failed"}`);
});
```

### Anti-Patterns to Avoid

- **Runtime fetch for required JSON:** `file://` CORS behavior can fail and blank required sections; embed/generate required content instead. [CITED: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS/Errors/CORSRequestNotHttp]
- **Hand-maintained contrast matrix in `swatches.json`:** Phase 50 intentionally kept swatches lean; render badges from Phase 48 evidence and token values. [VERIFIED: 51-CONTEXT.md]
- **New docs/design-system platform:** Storybook, Docusaurus, shadcn, Style Dictionary, remote fonts, CDNs, and npm UI packages are out of scope. [VERIFIED: 51-CONTEXT.md]
- **Color-only status:** WCAG 2.2 states color must not be the only visual means of conveying information. [CITED: https://www.w3.org/TR/WCAG22/]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Browser event/network verification | Custom browser harness | Existing Playwright script | Playwright Page exposes request, requestfailed, pageerror, console, viewport, and interaction APIs. [CITED: https://playwright.dev/docs/api/class-page] |
| JSON encoding/decoding | String-concatenated JSON | Jason | Jason is already locked and used in the token script. [VERIFIED: mix.lock] |
| Token source of truth | New token schema or duplicated palette | `priv/static/cairnloop.css` + generated mirrors | Phase decisions lock canonical source and derivative status. [VERIFIED: 51-CONTEXT.md] |
| Accessibility sign-off | Color-only badges or manual UAT | Text/icon labels + ExUnit/Playwright checks | WCAG requires non-color cues and non-text contrast for UI components. [CITED: https://www.w3.org/TR/WCAG22/] |
| Logo interpretation | Recreated SVG/text logo | Committed `logo/*` assets | Phase 51 must render assets exactly and not redraw/recompose them. [VERIFIED: logo/USAGE.md] |

**Key insight:** Phase 51 complexity is in deterministic assembly and verification coverage, not in framework selection. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: `file://` Fetch Fragility

**What goes wrong:** Required sections load from local JSON with `fetch()` and fail under direct file open. [CITED: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS/Errors/CORSRequestNotHttp]
**Why it happens:** Browser CORS behavior treats local file schemes differently from HTTP/HTTPS. [CITED: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS/Errors/CORSRequestNotHttp]
**How to avoid:** Generate/commit essential content into HTML; allow JS only for nonessential enhancement. [VERIFIED: 51-CONTEXT.md]
**Warning signs:** Required content appears only after JS `fetch`, or Playwright sees `requestfailed` for `file://...json`. [VERIFIED: codebase grep]

### Pitfall 2: Swatches Become a Second Contrast Authority

**What goes wrong:** Planner adds contrast rows into `swatches.json`, creating drift from Phase 48 evidence. [VERIFIED: codebase grep]
**Why it happens:** Color rendering and contrast proof are adjacent but intentionally separate. [VERIFIED: 51-CONTEXT.md]
**How to avoid:** Keep swatches lean and render badge labels from `.planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md`. [VERIFIED: codebase grep]
**Warning signs:** `swatches.json` contains `contrast`, `ratio`, or pairwise matrices. [VERIFIED: codebase grep]

### Pitfall 3: Pretty Page, Weak Reference Utility

**What goes wrong:** The document becomes a marketing hero or decorative brand surface instead of a maintainer reference. [VERIFIED: 51-UI-SPEC.md]
**Why it happens:** Brand-book work invites visual flourish, but the locked first viewport is dense reference content. [VERIFIED: 51-CONTEXT.md]
**How to avoid:** Every section must include a rendered example, provenance cue, and usage rule. [VERIFIED: 51-CONTEXT.md]
**Warning signs:** Oversized hero, hidden accordions for core rules, prose-only guidance, or no visible Color section hint in the first viewport. [VERIFIED: 51-UI-SPEC.md]

### Pitfall 4: Color-Only State

**What goes wrong:** Do/don't panels, current nav, active theme, or contrast badges rely only on green/red/copper. [VERIFIED: 51-UI-SPEC.md]
**Why it happens:** Status color is easy to style but inaccessible alone. [CITED: https://www.w3.org/WAI/WCAG21/Understanding/use-of-color.html]
**How to avoid:** Pair every status with text such as `AA pass`, `UI pass`, `Decorative exempt`, `Do`, `Do not`, `Current`, `Light selected`, or accessible icon text. [VERIFIED: 51-UI-SPEC.md]
**Warning signs:** CSS class names imply state but visible labels do not. [VERIFIED: codebase grep]

## Code Examples

### Source Guard Pattern

```elixir
# Source: test/cairnloop/web/brandbook_scaffold_test.exs
@forbidden_dependency_pattern ~r/https?:\/\/|(^|[^:])\/\/|@import|<iframe|\bsendBeacon\b|url\((['"]?)https?:|url\((['"]?)\//i

test "brandbook source has no remote, import, iframe, beacon, or root-relative dependencies" do
  files = Path.wildcard("brandbook/**/*") |> Enum.filter(&File.regular?/1)
  assert files != []
end
```

### Theme Toggle Verification Shape

```javascript
// Source: Playwright Page docs + scripts/verify_brandbook_file_load.mjs
await page.goto(brandbookUrl, { waitUntil: "load", timeout: 15000 });
await page.getByRole("button", { name: /dark/i }).click();
const theme = await page.locator("html").getAttribute("data-theme");
if (theme !== "dark") failures.push("Theme toggle did not set html[data-theme=dark]");
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Runtime docs/design-system platform | Committed static offline HTML | Locked for Phase 51 on 2026-06-25 [VERIFIED: 51-CONTEXT.md] | Planner should not add Storybook/Docusaurus/Phoenix routing. |
| Manual brandbook content | Generated or checked local assembly | Phase 50/51 handoff [VERIFIED: codebase grep] | Planner should add `--check` drift behavior before implementation claims. |
| Color-only badges | Text/icon plus color | Required by BOOK-05 and WCAG 1.4.1 [CITED: https://www.w3.org/TR/WCAG22/] | Planner must test visible state labels. |
| Broad screenshots | Targeted geometry/pixel sanity checks | Locked in D-51-18 [VERIFIED: 51-CONTEXT.md] | Planner should avoid snapshot baseline churn. |

**Deprecated/outdated:**
- `Full brand book assembly is Phase 51` scaffold copy should be replaced by complete Phase 51 content and retained only if a provenance note needs it. [VERIFIED: brandbook/index.html]
- Empty `brandbook/logo/.gitkeep` and `brandbook/raster/.gitkeep` are placeholders; Phase 51 may either link to root `logo/*` relatively or copy approved assets into brandbook-local directories if the plan preserves source truth and scope. [VERIFIED: codebase grep]

## Assumptions Log

All implementation-shaping claims in this research were verified against local project files, registries, or cited official docs. No `[ASSUMED]` claims are intentionally used.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | — | — | — |

## Resolved Questions

1. **Should logo files be copied into `brandbook/logo/` or linked from `../logo/`?**
   - What we know: UI spec allows relative brandbook copies or links; context lists root `logo/*` as source inputs. [VERIFIED: 51-UI-SPEC.md]
   - Resolution: Phase 51 plans use relative links to committed root assets as `../logo/<asset>`, not copied brandbook-local logo files. This keeps `logo/` as the single committed asset family while preserving direct `file://brandbook/index.html` resolution from a repository checkout. [VERIFIED: 51-CONTEXT.md]
   - Planner impact: `scripts/assemble_brandbook.exs`, `brandbook/index.html`, `test/cairnloop/web/brandbook_scaffold_test.exs`, and `scripts/verify_brandbook_file_load.mjs` must validate the `../logo/*` links and fail loudly if a referenced committed asset is missing. [VERIFIED: codebase grep]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | generation and tests | yes [VERIFIED: local command] | Elixir 1.19.5 / Mix 1.19.5 | none needed |
| Node.js | Playwright verifier | yes [VERIFIED: local command] | v22.14.0 | none needed |
| npm | local Playwright install restore | yes [VERIFIED: local command] | 11.1.0 | use existing node_modules if present |
| Playwright local module | file-url browser proof | yes [VERIFIED: local command] | 1.60.0 locked | run `npm --prefix examples/cairnloop_example/assets ci` |
| `rg` | source guards | yes [VERIFIED: local command] | available | Elixir file scans |
| `xmllint` | optional SVG sanity | yes [VERIFIED: local command] | system tool | skip unless logo inventory validation needs XML parsing |

**Missing dependencies with no fallback:** none
**Missing dependencies with fallback:** none

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with DB-free source tests; Playwright 1.60.0 Node script for file-url browser proof. [VERIFIED: codebase grep] |
| Config file | `mix.exs`; `examples/cairnloop_example/assets/package-lock.json`. [VERIFIED: codebase grep] |
| Quick run command | `mix run scripts/derive_brandbook_tokens.exs --check && mix test test/cairnloop/web/brandbook_scaffold_test.exs && node scripts/verify_brandbook_file_load.mjs` |
| Full suite command | `mix compile --warnings-as-errors && mix test && node scripts/verify_brandbook_file_load.mjs` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| BOOK-03 | Required live token/type/voice/imagery/motion sections are present, sourced, non-stubbed, and no required content depends on runtime fetch. [VERIFIED: 51-UI-SPEC.md] | source + browser | `mix test test/cairnloop/web/brandbook_scaffold_test.exs && node scripts/verify_brandbook_file_load.mjs` | existing test/script need extension |
| BOOK-04 | Every approved logo/raster asset has visible specimen and relative download link; usage diagrams and do/don't panels include required rules. [VERIFIED: logo/USAGE.md] | source + browser | `mix test test/cairnloop/web/brandbook_scaffold_test.exs && node scripts/verify_brandbook_file_load.mjs` | existing test/script need extension |
| BOOK-05 | Theme toggle works, focus is visible, state is not color-only, and light/dark content remains readable. [VERIFIED: 51-UI-SPEC.md] | browser + source | `node scripts/verify_brandbook_file_load.mjs` | existing script needs extension |

### Sampling Rate

- **Per task commit:** `mix run scripts/derive_brandbook_tokens.exs --check && mix test test/cairnloop/web/brandbook_scaffold_test.exs`
- **Per wave merge:** `node scripts/verify_brandbook_file_load.mjs`
- **Phase gate:** `mix compile --warnings-as-errors && mix test && node scripts/verify_brandbook_file_load.mjs`

### Wave 0 Gaps

- [ ] Extend `test/cairnloop/web/brandbook_scaffold_test.exs` for Phase 51 labels, required sections, badge text, logo/download inventory, forbidden dependencies, and package boundary. [VERIFIED: codebase grep]
- [ ] Extend `scripts/verify_brandbook_file_load.mjs` for theme toggle, focus-visible, viewport geometry, blank-page/clipping sanity, and local asset failure copy. [VERIFIED: codebase grep]
- [ ] Add or extend repo-local assembly/check script for deterministic `brandbook/index.html` generation/checking. [VERIFIED: 51-CONTEXT.md]

## Security Domain

Security enforcement is enabled by default because `.planning/config.json` does not set `security_enforcement: false`. [VERIFIED: .planning/config.json]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Static file has no auth boundary. [VERIFIED: 51-CONTEXT.md] |
| V3 Session Management | limited | Optional `localStorage` theme persistence must degrade safely and store no sensitive data. [VERIFIED: 51-CONTEXT.md] |
| V4 Access Control | no | No backend/API route or shipped app surface in Phase 51. [VERIFIED: 51-CONTEXT.md] |
| V5 Input Validation | yes | Validate local parsed sources and fail closed on missing/unknown required inputs. [VERIFIED: codebase grep] |
| V6 Cryptography | no | No cryptographic behavior in static brandbook. [VERIFIED: 51-CONTEXT.md] |

### Known Threat Patterns for Static Offline Brandbook

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Accidental remote dependency or beacon | Information Disclosure | Source regex guard plus Playwright request capture forbidding HTTP(S), protocol-relative URLs, imports, iframes, and beacons. [VERIFIED: codebase grep] |
| Drifted generated collateral | Tampering | Deterministic generator/check script with byte comparison and no manual edits to derived token outputs. [VERIFIED: codebase grep] |
| Blank or partial page passing source checks | Denial of Service / Repudiation | Browser proof asserts required visible text, zero page errors, viewport geometry, and nonblank rendered content. [CITED: https://playwright.dev/docs/api/class-page] |
| Misleading logo usage | Spoofing | Render committed logo files only; do not redraw/recolor/recompose; link to local approved assets. [VERIFIED: logo/USAGE.md] |

## Sources

### Primary (HIGH confidence)

- `CLAUDE.md` - project build/test, copy, token, and architecture constraints. [VERIFIED: codebase grep]
- `.planning/phases/51-full-html-brand-book-assembly/51-CONTEXT.md` - locked Phase 51 decisions and boundaries. [VERIFIED: codebase grep]
- `.planning/phases/51-full-html-brand-book-assembly/51-UI-SPEC.md` - approved UI contract, sections, layout, color, typography, logo, interactions, verification expectations. [VERIFIED: codebase grep]
- `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/ROADMAP.md` - BOOK-03/04/05 and phase dependencies. [VERIFIED: codebase grep]
- `scripts/derive_brandbook_tokens.exs`, `scripts/verify_brandbook_file_load.mjs`, `test/cairnloop/web/brandbook_scaffold_test.exs` - existing implementation and verification patterns. [VERIFIED: codebase grep]
- `brandbook/*`, `logo/USAGE.md`, `logo/*`, `.planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md` - concrete Phase 51 inputs. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- Playwright Page API and Network docs - event and network-monitoring basis. [CITED: https://playwright.dev/docs/api/class-page] [CITED: https://playwright.dev/docs/network]
- Mix docs - `mix run` and project-local alias context. [CITED: https://mix.hexdocs.pm/Mix.html]
- W3C WCAG 2.2 and Understanding docs - use-of-color, contrast minimum, non-text contrast. [CITED: https://www.w3.org/TR/WCAG22/] [CITED: https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html]
- MDN CORS local file docs - `file:///` fetch risk. [CITED: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS/Errors/CORSRequestNotHttp]

### Tertiary (LOW confidence)

- None used for implementation recommendations.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - locked local stack and versions verified through repo files, local commands, npm/Hex checks.
- Architecture: HIGH - Phase context and UI spec are explicit and existing Phase 50 files provide concrete seams.
- Pitfalls: HIGH - most pitfalls are directly locked by context or backed by official browser/WCAG docs.

**Research date:** 2026-06-25
**Valid until:** 2026-07-25 for local architecture; 2026-07-02 for npm package/version freshness.
