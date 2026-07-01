# Phase 50: Brandbook Scaffold & Token-Derivation Pipeline - Research

**Researched:** 2026-06-25
**Domain:** repo-local static brandbook scaffold, CSS-token derivation, offline browser verification
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Token Derivation Method

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

#### Swatch JSON Shape

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

#### Scaffold Proof Content

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

#### Verification Strictness

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

### the agent's Discretion

Planner/executor may choose the exact Elixir parser structure, generated JSON ordering, CSS class
names, file comments, and Playwright harness location as long as the outputs are deterministic,
easy to review, and preserve the decisions above. Prefer simple, boring, repo-local tooling over a
generalized design-token platform.

### Deferred Ideas (OUT OF SCOPE)

- Full color swatches with contrast badges, type system sections, logo gallery, clearspace diagrams,
  do/don't panels, light/dark toggle, and voice/imagery guidance belong to Phase 51.
- README header, example-app logo replacement, favicon metadata, OG image wiring, and rendered
  example-app verification belong to Phase 52.
- A public `mix cairnloop.brandbook` or package-consumer regeneration task is deferred unless a
  later milestone intentionally ships brandbook tooling as part of the Hex package.
- A Style Dictionary or DTCG-style multi-platform token pipeline is deferred unless Cairnloop later
  needs design-token outputs beyond CSS/HTML/JSON for this repo.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BOOK-01 | A self-contained `brandbook/` folder opens from `file://` with no network dependency and no console or failed-network errors. [VERIFIED: .planning/REQUIREMENTS.md] | Use relative static HTML/CSS only, no JS requirement, no remote URLs, and a Playwright `file://` verification harness that records console, pageerror, request, and requestfailed events. [VERIFIED: 50-CONTEXT.md] [CITED: https://playwright.dev/docs/api/class-page] |
| BOOK-02 | `brandbook/assets/css/tokens.css` is derived from canonical `cairnloop.css` `:root`, documented in `brandbook/TOKENS.md` with regeneration note. [VERIFIED: .planning/REQUIREMENTS.md] | Use `mix run scripts/derive_brandbook_tokens.exs` with `--check`, parse `:root` and `[data-theme="dark"]`, resolve simple `var(--cl-*)` aliases for JSON display, and fail on drift. [VERIFIED: 50-CONTEXT.md] |
</phase_requirements>

## Summary

Phase 50 should be planned as a repo-collateral build, not a Phoenix feature: create `brandbook/`, generate deterministic token mirrors from `priv/static/cairnloop.css`, document regeneration in `TOKENS.md`, and prove direct `file://` loading with automated browser evidence. [VERIFIED: 50-CONTEXT.md] The existing canonical CSS already contains the full `:root` token block and `[data-theme="dark"]` semantic overrides the phase needs. [VERIFIED: priv/static/cairnloop.css]

The best implementation unit is a small Elixir script under `scripts/`, invoked by `mix run`, because the locked decision rejects a shipped Mix task and this repo's package includes all of `lib`. [VERIFIED: 50-CONTEXT.md] Official Mix docs confirm public Mix tasks conventionally live under `lib/mix/tasks` and expose task documentation through `mix help`, which supports avoiding that public surface for unshipped brandbook collateral. [CITED: https://hexdocs.pm/mix/Mix.Task.html]

**Primary recommendation:** Plan three tightly scoped slices: derivation script plus generated outputs, static scaffold files, then focused source/browser/package verification. [VERIFIED: 50-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Token derivation | Build / Repo Tooling | CDN / Static | A repo-local Elixir script transforms canonical CSS into static CSS/JSON artifacts; runtime Phoenix code does not own this. [VERIFIED: 50-CONTEXT.md] |
| Offline brandbook scaffold | Browser / Client | CDN / Static | `index.html` opens directly from `file://` and consumes relative CSS assets. [VERIFIED: 50-UI-SPEC.md] |
| Canonical token authority | CDN / Static | Browser / Client | `priv/static/cairnloop.css` is the source of truth and browsers consume its `--cl-*` variables. [VERIFIED: priv/static/cairnloop.css] |
| Package exclusion | Build / Package Config | — | `mix.exs` package `files` allowlist controls what ships to Hex, and currently excludes `brandbook/`. [VERIFIED: mix.exs] |
| Browser proof | Test / Verification | Browser / Client | Playwright is the standard way to observe real console, page, and network events for the local file. [CITED: https://playwright.dev/docs/api/class-page] |

## Project Constraints (from CLAUDE.md)

- Research and decide without asking the owner for normal gray-area choices; escalate only very impactful decisions. [VERIFIED: CLAUDE.md]
- Builds must be warnings-clean with `mix compile --warnings-as-errors`. [VERIFIED: CLAUDE.md]
- Run `mix test` before declaring implementation done, while reporting baseline Repo caveats honestly. [VERIFIED: CLAUDE.md]
- Prefer headless/pure tests when a live DB is unnecessary. [VERIFIED: CLAUDE.md]
- Operator/brand copy must be calm, fail-closed, reason-forward, honest, and never state-by-color-alone. [VERIFIED: CLAUDE.md]
- Prefer brand tokens over hardcoded hex, especially `var(--cl-primary, #A94F30)`. [VERIFIED: CLAUDE.md]
- Do not add new reads through web-layer schema queries; this phase should not touch web data reads. [VERIFIED: CLAUDE.md]

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Elixir / Mix | Elixir 1.19.5, Mix 1.19.5 installed locally | Run `scripts/derive_brandbook_tokens.exs` and pure ExUnit checks. | Existing project runtime; no new dependency or package surface. [VERIFIED: local command] |
| `Jason` | `~> 1.2` in `mix.exs` | Emit deterministic `swatches.json`. | Already a project dependency; avoids custom JSON formatting. [VERIFIED: mix.exs] |
| Playwright via existing example-app tooling | npm `playwright` 1.60.0 in `examples/cairnloop_example/assets/package-lock.json` | Browser-load `file://.../brandbook/index.html` and capture console/network failures. | Existing real-browser stack and CI lane use Playwright; no human fallback for browser-only facts. [VERIFIED: examples/cairnloop_example/assets/package-lock.json] [VERIFIED: .planning/STATE.md] |
| Static HTML/CSS | browser-native | Render scaffold from `file://` with relative paths. | Phase requires no Phoenix route, no asset pipeline, and no network dependency. [VERIFIED: 50-CONTEXT.md] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `rg` | available locally | Source guards for forbidden URLs/imports/root-relative paths and package allowlist checks. | Use in verification tasks. [VERIFIED: local command] |
| ExUnit | bundled with Elixir | Pure file tests for derivation drift, layout existence, and package exclusion. | Prefer for deterministic source checks that do not need a browser. [VERIFIED: test/cairnloop/web/token_drift_test.exs] |
| PhoenixTest Playwright | 0.14.0 locked in example app | Existing browser E2E pattern. | Reference its style, but do not route brandbook through Phoenix just to reuse it. [VERIFIED: examples/cairnloop_example/mix.lock] [VERIFIED: 50-CONTEXT.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `mix run scripts/derive_brandbook_tokens.exs` | `lib/mix/tasks/cairnloop.brandbook.ex` | Public Mix tasks are idiomatic but would live under shipped `lib`; locked decision says this helper is internal collateral. [VERIFIED: 50-CONTEXT.md] [CITED: https://hexdocs.pm/mix/Mix.Task.html] |
| Elixir CSS extraction | POSIX shell/awk pipeline | Shell parsing is more brittle and less portable for balanced CSS blocks, alias resolution, JSON output, and `--check` failures. [VERIFIED: 50-CONTEXT.md] |
| CSS source of truth | Style Dictionary / DTCG token pipeline | Style Dictionary is designed to transform token sets to many platforms; Phase 50 only needs CSS and JSON mirrors from existing CSS. [CITED: https://styledictionary.com/getting-started/installation/] |
| Direct `file://` page | Phoenix route / example app | Serving through Phoenix would blur the unshipped package boundary and would not prove direct local brandbook use. [VERIFIED: 50-CONTEXT.md] |

**Installation:**
```bash
# No new package install for Phase 50.
```

**Version verification:** `elixir --version`, `mix --version`, `npm view playwright@1.60.0 version`, and `mix hex.info phoenix_test_playwright` were checked during research. [VERIFIED: local command]

## Package Legitimacy Audit

Phase 50 should install no external packages. [VERIFIED: 50-CONTEXT.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `playwright` | npm | Existing repo dependency; 1.60.0 locked in package-lock | Latest package has ~62M weekly downloads per legitimacy seam | github.com/microsoft/playwright | SUS for latest due too-new seam signal | Do not install latest; reuse existing locked dependency only. [VERIFIED: package-legitimacy seam] |

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** `playwright` latest only; planner should not add or upgrade it for this phase. [VERIFIED: package-legitimacy seam]

## Architecture Patterns

### System Architecture Diagram

```text
priv/static/cairnloop.css
  (:root + [data-theme="dark"] canonical --cl-* declarations)
        |
        v
scripts/derive_brandbook_tokens.exs
  parse blocks -> preserve token declarations -> resolve simple aliases for JSON
        |
        +--> brandbook/assets/css/tokens.css
        |      derived --cl-* variables + provenance comment
        |
        +--> brandbook/color/swatches.json
        |      primitive / semantic_light / semantic_dark groups
        |
        v
brandbook/TOKENS.md
  source, regeneration command, --check command, drift contract
        |
        v
brandbook/index.html + assets/css/brandbook.css
  relative CSS links only -> file:// browser proof
        |
        v
verification
  derivation --check + grep source guards + package files guard + Playwright file:// load
```

### Recommended Project Structure

```text
brandbook/
├── index.html                  # compact static proof shell
├── TOKENS.md                   # provenance and regeneration contract
├── assets/
│   └── css/
│       ├── tokens.css          # generated from priv/static/cairnloop.css
│       └── brandbook.css       # scaffold-only layout consuming --cl-* vars
├── color/
│   └── swatches.json           # generated grouped swatch data
├── logo/                       # Phase 51 relative destination
└── raster/                     # Phase 51/52 allowed favicon/OG destination
scripts/
└── derive_brandbook_tokens.exs # repo-local generator/checker
```

### Pattern 1: Deterministic CSS Block Extraction

**What:** Extract only `:root` and `[data-theme="dark"]` declarations whose names start with `--cl-`, preserve names/values for CSS, and resolve single-step or recursive `var(--cl-*)` aliases only for swatch display values. [VERIFIED: priv/static/cairnloop.css]
**When to use:** Use for `tokens.css` and `swatches.json` generation. [VERIFIED: 50-CONTEXT.md]
**Example:**
```elixir
# Source: adapted from existing token_drift_test.exs parsing pattern.
defp css_block(css, selector) do
  pattern = ~r/#{Regex.escape(selector)}\s*\{(?<block>.*?)^\s*\}/ms
  Regex.named_captures(pattern, css) || raise "Missing CSS block #{selector}"
end

defp declarations(block) do
  ~r/(--cl-[a-z0-9-]+)\s*:\s*([^;]+);/
  |> Regex.scan(block)
  |> Map.new(fn [_match, token, value] -> {token, String.trim(value)} end)
end
```

### Pattern 2: Check Mode Compares Generated Bytes

**What:** Generate expected `tokens.css` and `swatches.json` in memory, read committed files, and fail if bytes differ. [VERIFIED: 50-CONTEXT.md]
**When to use:** `mix run scripts/derive_brandbook_tokens.exs --check` should be the drift gate. [VERIFIED: 50-CONTEXT.md]
**Example:**
```elixir
# Source: Phase 50 locked command shape from 50-CONTEXT.md.
check? = "--check" in System.argv()
outputs = build_outputs("priv/static/cairnloop.css")

for {path, expected} <- outputs do
  if check? do
    actual = File.read!(path)
    if actual != expected, do: raise("#{path} is stale; rerun mix run scripts/derive_brandbook_tokens.exs")
  else
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, expected)
  end
end
```

### Pattern 3: File-URL Browser Verification

**What:** Launch Chromium, attach `console`, `pageerror`, `request`, and `requestfailed` listeners, navigate to an absolute `file://` URL, then assert no console errors, no page errors, no failed requests, and no remote request schemes. [CITED: https://playwright.dev/docs/api/class-page]
**When to use:** Use for BOOK-01 because source grep cannot prove actual browser loading. [VERIFIED: .planning/STATE.md]
**Example:**
```javascript
// Source: Playwright Page and Request official docs.
page.on('console', msg => {
  if (msg.type() === 'error') consoleErrors.push(msg.text());
});
page.on('pageerror', err => pageErrors.push(String(err)));
page.on('request', req => requests.push(req.url()));
page.on('requestfailed', req => failed.push(`${req.url()} ${req.failure()?.errorText || ''}`));
await page.goto(`file://${process.cwd()}/brandbook/index.html`);
```

### Anti-Patterns to Avoid

- **Manual token mirror:** creates a fourth palette source and breaks BOOK-02 drift proof. [VERIFIED: 50-CONTEXT.md]
- **Remote fonts/assets/CDNs:** violates direct `file://` and no-network requirements. [VERIFIED: 50-UI-SPEC.md]
- **Shipped Mix task under `lib/mix/tasks`:** exposes internal collateral through package code paths. [VERIFIED: 50-CONTEXT.md]
- **Phoenix route wrapper:** proves the wrong deployment surface and blurs package boundary. [VERIFIED: 50-CONTEXT.md]
- **Full contrast matrix in `swatches.json`:** duplicates Phase 48 contrast evidence and risks stale metadata. [VERIFIED: 50-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON serialization | String-concatenated JSON | `Jason.encode!/2` | Existing dependency produces valid JSON escaping and stable pretty output. [VERIFIED: mix.exs] |
| Browser network proof | Manual browser smoke note | Playwright event listeners | Project policy requires automated rendered-behavior proof. [VERIFIED: .planning/STATE.md] |
| CSS token authority | New brandbook palette | `priv/static/cairnloop.css` parsed declarations | Canonical source already locked by Phase 46/48. [VERIFIED: .planning/STATE.md] |
| Multi-platform token build | Style Dictionary pipeline | Simple Elixir derivation script | Style Dictionary is for multi-platform token transforms; Phase 50 has two local outputs. [CITED: https://styledictionary.com/reference/hooks/transforms/] |

**Key insight:** The hard problem is not creating static files; it is preventing token drift and accidental network/package coupling. [VERIFIED: 50-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: CSS Parsing Too Broad

**What goes wrong:** The script copies component rules or reduced-motion blocks into `tokens.css`. [VERIFIED: priv/static/cairnloop.css]
**Why it happens:** Grep-based extraction does not isolate `:root` and `[data-theme="dark"]`. [VERIFIED: test/cairnloop/web/token_drift_test.exs]
**How to avoid:** Parse named blocks and declarations, then fail if either required block is missing. [VERIFIED: 50-CONTEXT.md]
**Warning signs:** Generated `tokens.css` contains `.cl-`, `@media`, or non-token selectors. [VERIFIED: priv/static/cairnloop.css]

### Pitfall 2: Alias Resolution Becomes Authority

**What goes wrong:** `swatches.json` stores resolved aliases as if they were the source design tokens. [VERIFIED: 50-CONTEXT.md]
**Why it happens:** Display-friendly hex values are confused with canonical declarations. [VERIFIED: 50-CONTEXT.md]
**How to avoid:** Preserve token name and raw value, optionally include resolved hex as display metadata, and document CSS as authority. [VERIFIED: 50-CONTEXT.md]
**Warning signs:** Future maintainers edit `swatches.json` to change colors. [VERIFIED: 50-CONTEXT.md]

### Pitfall 3: `file://` Fails Due Root-Relative Paths

**What goes wrong:** `/assets/...`, `/logo/...`, or `url(/...)` works under a server but fails from `file://`. [VERIFIED: 50-UI-SPEC.md]
**Why it happens:** Browser resolves root-relative URLs against filesystem root under `file://`. [VERIFIED: 50-UI-SPEC.md]
**How to avoid:** Use `assets/css/tokens.css`, `./...`, or fragment links only; source-grep root-relative paths. [VERIFIED: 50-CONTEXT.md]
**Warning signs:** Playwright `requestfailed` events mention local filesystem asset misses. [CITED: https://playwright.dev/docs/api/class-request]

### Pitfall 4: Checking Only `requestfailed`

**What goes wrong:** HTTP 404/503 responses are missed because Playwright treats HTTP error responses as completed requests. [CITED: https://playwright.dev/docs/api/class-request]
**Why it happens:** `requestfailed` is for transport-level failures, not HTTP error status codes. [CITED: https://playwright.dev/docs/api/class-request]
**How to avoid:** Also collect all requests and responses if a server is used; for Phase 50, fail any non-`file:`/`data:` request and use source grep for remote URLs. [CITED: https://playwright.dev/docs/api/class-request]
**Warning signs:** The test reports no failed requests but source contains `https://` or `//cdn`. [VERIFIED: 50-CONTEXT.md]

## Code Examples

### Swatch Group Shape

```json
{
  "schema_version": 1,
  "source_file": "priv/static/cairnloop.css",
  "generated_by": "mix run scripts/derive_brandbook_tokens.exs",
  "check_command": "mix run scripts/derive_brandbook_tokens.exs --check",
  "groups": {
    "primitive": [
      {
        "token": "--cl-color-basalt",
        "value": "#141B19",
        "resolved": "#141B19",
        "role": "core text / dark surface"
      }
    ],
    "semantic_light": [],
    "semantic_dark": []
  }
}
```

### Source Guard Command

```bash
mix run scripts/derive_brandbook_tokens.exs --check &&
test -f brandbook/index.html &&
test -f brandbook/assets/css/tokens.css &&
test -f brandbook/assets/css/brandbook.css &&
test -f brandbook/color/swatches.json &&
test -d brandbook/logo &&
test -d brandbook/raster &&
! rg -n 'https?://|(^|[^:])//|@import|<iframe|sendBeacon|url\((["'\'']?)https?:|url\((["'\'']?)/' brandbook &&
rg -n 'files: ~w\(lib priv guides mix\.exs README\.md LICENSE CHANGELOG\.md\)' mix.exs &&
! rg -n 'files: .*brandbook' mix.exs
```

### Token Output Header

```css
/* Generated from priv/static/cairnloop.css :root and [data-theme="dark"].
   Regenerate with: mix run scripts/derive_brandbook_tokens.exs
   Check drift with: mix run scripts/derive_brandbook_tokens.exs --check */
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Webpack / Node as default Phoenix asset posture | Phoenix 1.7+ uses Elixir esbuild/tailwind wrappers and avoids Node/Webpack by default for new apps | Phoenix docs current v1.8.8 | Supports avoiding a new Node asset pipeline for this static collateral. [CITED: https://hexdocs.pm/phoenix/asset_management.html] |
| Manual brand-token mirrors | Canonical CSS plus generated/documented derivatives | vM017 Phase 46/48 | Planner must create drift checks instead of a hand-maintained palette. [VERIFIED: .planning/STATE.md] |
| Manual browser UAT | Automated Playwright E2E for browser-only facts | Ratified 2026-06-04 | BOOK-01 proof must be automated. [VERIFIED: .planning/STATE.md] |

**Deprecated/outdated:**
- Manual smoke note for local browser loading: rejected by Phase 50 verification strictness. [VERIFIED: 50-CONTEXT.md]
- New Style Dictionary pipeline for this phase: over-scoped and explicitly deferred. [VERIFIED: 50-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|

All claims in this research were verified or cited; no user confirmation is needed.

## Open Questions (RESOLVED)

1. **Where should the Playwright file-url harness live?**
   - RESOLVED: Phase 50 plans `scripts/verify_brandbook_file_load.mjs` as the standalone file-url harness location.
   - What we know: Phase 50 allows a small script or documented command and says not to route through Phoenix. [VERIFIED: 50-CONTEXT.md]
   - What's unclear: The repo has no existing root-level standalone Playwright script pattern. [VERIFIED: codebase search]
   - Recommendation: Put the harness in `scripts/verify_brandbook_file_load.mjs` or document a `node -e` equivalent using the existing example-app Playwright dependency; do not add a new package. [VERIFIED: examples/cairnloop_example/assets/package-lock.json]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir | derivation script and tests | yes | 1.19.5 | none needed. [VERIFIED: local command] |
| Mix | `mix run`, `mix test`, package checks | yes | 1.19.5 | none needed. [VERIFIED: local command] |
| Node | standalone Playwright harness if used | yes | 22.14.0 | Use existing PhoenixTest Playwright pattern only if planner decides a test file is lower friction. [VERIFIED: local command] |
| npm | verifying existing Playwright package | yes | 11.1.0 | none needed. [VERIFIED: local command] |
| Playwright | file-url browser proof | yes in example app assets lockfile | 1.60.0 | Avoid browser proof only if planner explicitly replaces it with equivalent existing Playwright lane, not manual UAT. [VERIFIED: examples/cairnloop_example/assets/package-lock.json] |
| ripgrep | source guards | yes | available | use `grep` only if unavailable. [VERIFIED: local command] |

**Missing dependencies with no fallback:** none found. [VERIFIED: local command]
**Missing dependencies with fallback:** none found. [VERIFIED: local command]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit for source/drift checks; Playwright 1.60.0 for file-url browser proof. [VERIFIED: examples/cairnloop_example/assets/package-lock.json] |
| Config file | `mix.exs`, `examples/cairnloop_example/mix.exs`, `examples/cairnloop_example/test/test_helper.exs`. [VERIFIED: codebase read] |
| Quick run command | `mix run scripts/derive_brandbook_tokens.exs --check && mix test test/cairnloop/web/brandbook_scaffold_test.exs` |
| Full suite command | `mix compile --warnings-as-errors && mix test && node scripts/verify_brandbook_file_load.mjs` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| BOOK-01 | `brandbook/index.html` opens from `file://` with no console errors, page errors, failed requests, or remote requests. [VERIFIED: .planning/REQUIREMENTS.md] | browser smoke | `node scripts/verify_brandbook_file_load.mjs` | no, Wave 0 |
| BOOK-01 | All paths/assets are relative and no forbidden remote/root dependencies exist. [VERIFIED: 50-CONTEXT.md] | source guard | `! rg -n 'https?://|(^|[^:])//|@import|<iframe|sendBeacon|url\\((["'\\'']?)https?:|url\\((["'\\'']?)/' brandbook` | no, Wave 0 |
| BOOK-02 | `tokens.css` and `swatches.json` match canonical CSS derivation. [VERIFIED: .planning/REQUIREMENTS.md] | unit/source | `mix run scripts/derive_brandbook_tokens.exs --check` | no, Wave 0 |
| HYGIENE-03 support | `brandbook/` is absent from Hex package files. [VERIFIED: .planning/REQUIREMENTS.md] | source guard | `rg -n 'files: ~w\\(lib priv guides mix\\.exs README\\.md LICENSE CHANGELOG\\.md\\)' mix.exs && ! rg -n 'files: .*brandbook' mix.exs` | existing `mix.exs` yes |

### Sampling Rate

- **Per task commit:** `mix run scripts/derive_brandbook_tokens.exs --check` plus focused source guards. [VERIFIED: 50-CONTEXT.md]
- **Per wave merge:** `mix compile --warnings-as-errors && mix test` plus file-url browser proof. [VERIFIED: CLAUDE.md]
- **Phase gate:** all success criteria source guards, derivation `--check`, package exclusion guard, and Playwright `file://` proof green. [VERIFIED: 50-CONTEXT.md]

### Wave 0 Gaps

- [ ] `scripts/derive_brandbook_tokens.exs` - covers BOOK-02 derivation and drift checks. [VERIFIED: 50-CONTEXT.md]
- [ ] `scripts/verify_brandbook_file_load.mjs` or equivalent focused Playwright command - covers BOOK-01 browser proof. [VERIFIED: 50-CONTEXT.md]
- [ ] `test/cairnloop/web/brandbook_scaffold_test.exs` - optional pure ExUnit source/layout/package guard. [VERIFIED: existing test patterns]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | No authentication surface in static repo-local brandbook. [VERIFIED: 50-CONTEXT.md] |
| V3 Session Management | no | No sessions or cookies. [VERIFIED: 50-CONTEXT.md] |
| V4 Access Control | no | No server route or protected resource is introduced. [VERIFIED: 50-CONTEXT.md] |
| V5 Input Validation | yes | Validate parsed CSS blocks, token names, JSON schema groups, and command args; fail closed on malformed input. [VERIFIED: 50-CONTEXT.md] |
| V6 Cryptography | no | No cryptographic operation or secret handling. [VERIFIED: 50-CONTEXT.md] |

### Known Threat Patterns for Static Offline Brandbook

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Accidental remote asset or analytics URL leaks browsing context | Information Disclosure | Source guard forbids `http://`, `https://`, protocol-relative URLs, iframes, beacons, `@import`, and remote `url(...)`. [VERIFIED: 50-CONTEXT.md] |
| Token mirror drift changes brand authority | Tampering | Generate from canonical CSS and fail `--check` on committed drift. [VERIFIED: 50-CONTEXT.md] |
| Shipping internal brandbook collateral in Hex package | Information Disclosure | Keep package `files` allowlist unchanged and assert no `brandbook/`. [VERIFIED: mix.exs] |
| Browser proof false-pass | Repudiation | Capture console, page errors, all requests, and request failures; fail on any remote URL. [CITED: https://playwright.dev/docs/api/class-page] |

## Sources

### Primary (HIGH confidence)

- `50-CONTEXT.md` - locked implementation decisions, scaffold boundary, verification strictness. [VERIFIED: codebase read]
- `50-UI-SPEC.md` - static scaffold visual/copy/path contract. [VERIFIED: codebase read]
- `.planning/REQUIREMENTS.md` - BOOK-01 and BOOK-02 wording. [VERIFIED: codebase read]
- `.planning/STATE.md` - rendered-behavior automation policy and vM017 token discipline. [VERIFIED: codebase read]
- `priv/static/cairnloop.css` - canonical `:root` and `[data-theme="dark"]` token source. [VERIFIED: codebase read]
- `mix.exs` - package `files` allowlist and existing dependencies. [VERIFIED: codebase read]
- `test/cairnloop/web/token_drift_test.exs` - existing CSS parsing, alias resolution, and drift-test patterns. [VERIFIED: codebase read]

### Secondary (MEDIUM confidence)

- https://hexdocs.pm/mix/Mix.Task.html - Mix task public module conventions and task args. [CITED: official docs]
- https://hexdocs.pm/phoenix/asset_management.html - Phoenix asset-management posture and no-Node default. [CITED: official docs]
- https://playwright.dev/docs/api/class-page - Page events for console/page/network observation. [CITED: official docs]
- https://playwright.dev/docs/api/class-request - `requestfailed` semantics and HTTP error caveat. [CITED: official docs]
- https://styledictionary.com/getting-started/installation/ - Style Dictionary multi-platform token build purpose. [CITED: official docs]
- https://styledictionary.com/reference/hooks/transforms/ - Style Dictionary transform semantics. [CITED: official docs]

### Tertiary (LOW confidence)

- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new stack; all core tools are existing repo/local tools. [VERIFIED: codebase read]
- Architecture: HIGH - phase context and UI spec lock ownership and boundaries. [VERIFIED: 50-CONTEXT.md]
- Pitfalls: HIGH - pitfalls derive from explicit phase constraints and existing parser/test patterns. [VERIFIED: 50-CONTEXT.md]

**Research date:** 2026-06-25
**Valid until:** 2026-07-25 for repo-local architecture; re-check Playwright docs/package state if upgrading browser tooling.
