# Phase 48: Token Evolution: Lock & Propagate - Research

**Researched:** 2026-06-24
**Domain:** CSS design tokens, Phoenix/LiveView visual system verification, WCAG contrast revalidation
**Confidence:** HIGH for local phase constraints; MEDIUM for external standards; LOW for optional implementation refinements

## User Constraints

### Locked Decisions

- Phase 48 is research-only for this agent; do not make code changes beyond this research artifact. [VERIFIED: user objective]
- Phase 48 currently has no `CONTEXT.md`; consume Phase 47 and Phase 46 artifacts as the locked handoff. [VERIFIED: `gsd-tools init.phase-op 48` + file scan]
- The owner-selected palette is `Refined`. [VERIFIED: `.planning/phases/47-brand-direction-exploration-selection-gate/47-SELECTION-GATE.md`]
- The owner-selected type direction is the current stack: Atkinson Hyperlegible, Fraunces, and Martian Mono. [VERIFIED: `.planning/phases/47-brand-direction-exploration-selection-gate/47-SELECTION-GATE.md`]
- The owner-selected logo is C3.6 crowning-loop cairn, but logo production assets are Phase 49 and must stay out of Phase 48. [VERIFIED: `.planning/phases/47-brand-direction-exploration-selection-gate/47-SELECTION-GATE.md`]
- `priv/static/cairnloop.css` `:root` is the single canonical token source. [VERIFIED: `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-DISCREPANCY-LEDGER.md`]
- Existing `--cl-*` token names must not be renamed or removed; Phase 48 may use value changes and additive new tokens only. [VERIFIED: `.planning/ROADMAP.md`]

### the agent's Discretion

- Exact adjacent semantic surfaces, status triads, border values, hover values, and additive tokens may be adjusted only to satisfy contrast and hierarchy requirements. [VERIFIED: `.planning/phases/48-token-evolution-lock-propagate/48-UI-SPEC.md`]
- The planner should choose an automated contrast/drift check approach without asking the owner, because project policy says to decide non-critical implementation details after research. [VERIFIED: `CLAUDE.md`]

### Deferred Ideas (OUT OF SCOPE)

- Production optimized SVG logo family, favicon, OG/social assets, README logo header, and example app logo wiring are Phase 49/52 work. [VERIFIED: `.planning/phases/47-brand-direction-exploration-selection-gate/47-SELECTION-GATE.md`]
- `brandbook/` token derivation and HTML brand book assembly are Phase 50/51 work. [VERIFIED: `.planning/ROADMAP.md`]
- Alternate palettes, alternate type directions, and rejected logo directions are not reopened unless the owner explicitly reopens the gate. [VERIFIED: `.planning/phases/47-brand-direction-exploration-selection-gate/47-CONTEXT.md`]

## Summary

Phase 48 is a token-source evolution phase, not a UI feature phase. [VERIFIED: `.planning/ROADMAP.md`] The plan should update canonical `priv/static/cairnloop.css` first, then propagate matching expressed values to `examples/cairnloop_example/assets/css/app.css` and `prompts/cairnloop.tokens.json`, then prove zero drift and re-run the Phase 46 contrast matrix. [VERIFIED: `.planning/phases/48-token-evolution-lock-propagate/48-UI-SPEC.md`]

The selected Refined baseline values are basalt `#141B19`, trailpaper `#F4EEE2`, warm stone `#FAF5EB`, light copper `#A8492A`, dark copper `#D98A4A`, muted `#5E665D`, and dark danger `#C96A55`. [VERIFIED: `.planning/phases/48-token-evolution-lock-propagate/48-UI-SPEC.md`] A local WCAG calculation shows `#C96A55` with white text is only 3.70:1, so the planner must not treat a dark-danger value swap alone as closure for the old dark danger button failure. [VERIFIED: local Node WCAG ratio script] Use an additive `--cl-danger-button-text` token with light `#FFFFFF` and dark `#141B19`, or choose a darker dark danger background; the additive token path preserves the selected color and satisfies no-renames discipline. [ASSUMED]

**Primary recommendation:** Plan one canonical-first token edit, one derivative propagation edit, one focused automated drift/contrast verifier, and one full gate run: `mix test`, `mix test.integration`, and `mix test.e2e`. [VERIFIED: `.planning/ROADMAP.md`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Canonical token evolution | CDN / Static CSS | Browser / Client | `priv/static/cairnloop.css` ships as the runtime stylesheet and defines the browser-consumed `--cl-*` values. [VERIFIED: `priv/static/cairnloop.css`] |
| Example app Tailwind primitive utility mirror | Frontend asset build | Browser / Client | `app.css` uses Tailwind `@theme` to generate utility classes from `--color-cl-*` primitive variables. [CITED: https://tailwindcss.com/docs/theme] |
| Machine-readable token mirror | Documentation / Prompt artifact | Static JSON | `prompts/cairnloop.tokens.json` expresses color/type/voice values for downstream prompt and brand consumers. [VERIFIED: `prompts/cairnloop.tokens.json`] |
| Contrast re-verification | Test / CI tier | Browser / Client | WCAG ratios can be computed from token values without a live browser, while existing E2E still validates rendered behavior after asset rebuild. [VERIFIED: `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md`] |
| Brand-token gate | Test / CI tier | Web render source | The existing ExUnit gate scans `.ex` render files for hardcoded color literals and excludes CSS structurally. [VERIFIED: `test/cairnloop/web/brand_token_gate_test.exs`] |

## Project Constraints (from CLAUDE.md)

- Make decisions for the owner after research; ask only for very impactful, expensive, or irreversible calls. [VERIFIED: `CLAUDE.md`]
- Warnings-clean builds are mandatory; `mix compile --warnings-as-errors` is expected before completion. [VERIFIED: `CLAUDE.md`]
- Run `mix test` before declaring work done and report failures honestly. [VERIFIED: `CLAUDE.md`]
- `Cairnloop.Repo` may be unavailable locally; prefer pure/headless tests when possible and mark true DB tests with `# REPO-UNAVAILABLE`. [VERIFIED: `CLAUDE.md`]
- Use brand tokens over hardcoded hex in render surfaces. [VERIFIED: `CLAUDE.md`]
- Do not churn sealed code paths for downstream display concerns; prefer additive changes. [VERIFIED: `CLAUDE.md`]
- Operator copy must be calm, fail-closed, reason-forward, honest, and never state-by-color-alone. [VERIFIED: `CLAUDE.md`]

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TOKEN-02 | Apply chosen palette/type to canonical `:root` via value changes and additive tokens; no token renames. [VERIFIED: `.planning/REQUIREMENTS.md`] | Use `priv/static/cairnloop.css` as canonical, preserve all existing names, add only the minimal danger-button text token if needed. [VERIFIED: `priv/static/cairnloop.css`] |
| TOKEN-03 | Propagate evolved tokens to example app `@theme` and `cairnloop.tokens.json` with zero drift. [VERIFIED: `.planning/REQUIREMENTS.md`] | Mirror expressed primitive and semantic values exactly; correct `--cl-shadow-raised` drift to `var(--cl-shadow-1)`. [VERIFIED: `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-DISCREPANCY-LEDGER.md`] |
| TOKEN-04 | Gates green and contrast baseline re-verified. [VERIFIED: `.planning/REQUIREMENTS.md`] | Recompute all Phase 46 rows, close the three real failures, classify border rows, and run `mix test`, `mix test.integration`, `mix test.e2e`. [VERIFIED: `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md`] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Elixir / Mix | Elixir 1.19.5, Mix 1.19.5 locally | Compile and run project tests. | Project is an Elixir/Phoenix library and existing aliases are Mix-based. [VERIFIED: `mix --version` + `mix.exs`] |
| Phoenix / LiveView example app | Phoenix `~> 1.8.7`, LiveView `~> 1.1.0` in example app | Render example app surfaces and E2E target. | Existing example app owns browser E2E and assets build. [VERIFIED: `examples/cairnloop_example/mix.exs`] |
| Tailwind CSS Mix integration | `{:tailwind, "~> 0.3"}` in example app | Build `@theme` primitive utilities. | Existing asset pipeline uses Tailwind `@theme` in `app.css`. [VERIFIED: `examples/cairnloop_example/mix.exs`; CITED: https://tailwindcss.com/docs/theme] |
| PhoenixTest Playwright | `phoenix_test_playwright` 0.14.0 in lockfile | Run gated real-browser E2E. | Existing `mix test.e2e` lane uses Playwright-backed ExUnit tests. [VERIFIED: `examples/cairnloop_example/mix.lock`] |
| Node / npm / Playwright | Node v22.14.0, npm 11.1.0, Playwright 1.60.0 in example assets | Install/run Playwright browser tooling for E2E. | Existing example assets package pins Playwright. [VERIFIED: `node --version`, `npm --version`, `examples/cairnloop_example/assets/package-lock.json`] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Pure script for token/contrast verification | Use Node or Elixir stdlib, no package install | Parse canonical/derivative values and compute WCAG ratios. | Use in Phase 48 rather than adding dependencies; Phase 46 used a throwaway stdlib script pattern. [VERIFIED: `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md`] |
| ripgrep | 15.1.0 locally | Scan token names, hardcoded colors, and changed files. | Use for scope guard and no-rename checks. [VERIFIED: `rg --version`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom stdlib contrast script | npm contrast package | External package adds legitimacy/audit overhead and is unnecessary for WCAG 2.x formula. [ASSUMED] |
| Derivative JSON as source | `prompts/cairnloop.tokens.json` | Violates canonical-source decision; JSON is derivative only. [VERIFIED: `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-DISCREPANCY-LEDGER.md`] |
| Tailwind `@theme` for every token | `@theme` full mirror | Tailwind docs say `@theme` drives generated utilities; use it only for utility-facing primitive namespace, not every runtime `--cl-*` semantic. [CITED: https://tailwindcss.com/docs/theme] |

**Installation:**
```bash
# No new packages for Phase 48.
```

## Package Legitimacy Audit

Phase 48 should install no new external packages. [VERIFIED: `.planning/phases/48-token-evolution-lock-propagate/48-UI-SPEC.md`]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none | — | — | — | — | — | No install required. [VERIFIED: research scope] |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: no package recommendations]
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: no package recommendations]

## Architecture Patterns

### System Architecture Diagram

```text
Owner Phase 47 selection
  -> canonical token edit in priv/static/cairnloop.css :root + [data-theme="dark"]
  -> no-rename check for existing --cl-* names
  -> derivative propagation
       -> app.css @theme primitive --color-cl-* values
       -> app.css @layer base expressed --cl-* values
       -> prompts/cairnloop.tokens.json expressed color/type values
  -> drift verifier compares expressed derivative values to canonical
       -> mismatch: fix derivative, rerun
       -> match: continue
  -> contrast verifier recomputes Phase 46 matrix
       -> text < 4.5: fix token
       -> meaningful UI boundary < 3.0: fix token
       -> decorative border < 3.0: document classification
  -> gates: mix test -> mix test.integration -> mix test.e2e
  -> Phase 48 verification artifact
```

### Recommended Project Structure

```text
priv/static/cairnloop.css                         # canonical token source [VERIFIED]
examples/cairnloop_example/assets/css/app.css     # Tailwind @theme + local mirror derivative [VERIFIED]
prompts/cairnloop.tokens.json                     # color/type/voice derivative [VERIFIED]
test/cairnloop/web/brand_token_gate_test.exs      # existing brand-token render gate [VERIFIED]
test/cairnloop/web/token_drift_test.exs           # recommended new pure drift/contrast test [ASSUMED]
.planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md # recommended evidence artifact [ASSUMED]
```

### Pattern 1: Canonical-First Token Evolution

**What:** Change `priv/static/cairnloop.css` token values first, preserve all existing `--cl-*` names, and add only truly needed new semantic tokens. [VERIFIED: `.planning/ROADMAP.md`]
**When to use:** Every Phase 48 token change. [VERIFIED: `.planning/phases/48-token-evolution-lock-propagate/48-UI-SPEC.md`]
**Example:**
```css
/* Source: priv/static/cairnloop.css current pattern */
:root {
  --cl-color-path-copper: #A8492A;
  --cl-primary: var(--cl-color-path-copper);
  --cl-danger-button-text: #FFFFFF;
}

[data-theme="dark"] {
  --cl-primary: #D98A4A;
  --cl-danger: #C96A55;
  --cl-danger-button-text: #141B19;
}
```

### Pattern 2: Expressed-Value Derivative Parity

**What:** If a derivative expresses a canonical token, it must match the resolved canonical value or alias exactly. [VERIFIED: `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-DISCREPANCY-LEDGER.md`]
**When to use:** `app.css` primitive `@theme`, `app.css` `@layer base`, and `tokens.json` expressed semantic keys. [VERIFIED: `examples/cairnloop_example/assets/css/app.css` + `prompts/cairnloop.tokens.json`]
**Example:**
```css
/* Source: Tailwind @theme docs + current app.css pattern */
@theme {
  --color-cl-path-copper: #A8492A;
}

@layer base {
  :root {
    --cl-color-path-copper: #A8492A;
    --cl-primary: var(--cl-color-path-copper);
  }
}
```

### Pattern 3: Pure Contrast Matrix Test

**What:** Recompute WCAG contrast from token values in a pure test/script and emit row-level evidence. [VERIFIED: `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md`]
**When to use:** Before full gate runs, to catch token regressions in seconds. [ASSUMED]
**Example:**
```elixir
# Source: WCAG 2.2 contrast thresholds + existing ExUnit pure-file test pattern
assert contrast("#5E665D", "#F4EEE2") >= 4.5
assert contrast("#A8492A", "#FAF5EB") >= 3.0
```

### Anti-Patterns to Avoid

- **Renaming `--cl-*` tokens:** breaks the sealed token contract and downstream adopters. [VERIFIED: `.planning/ROADMAP.md`]
- **Editing derivatives first:** creates a new source of truth and makes drift harder to detect. [VERIFIED: `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-DISCREPANCY-LEDGER.md`]
- **Assuming `#C96A55` fixes dark danger with white text:** local ratio is 3.70:1, below 4.5. [VERIFIED: local Node WCAG ratio script]
- **Putting all runtime semantics in Tailwind `@theme`:** `@theme` controls generated utilities and must stay top-level; ordinary runtime variables still belong in `:root`. [CITED: https://tailwindcss.com/docs/theme]
- **Treating all low-contrast borders as failures:** WCAG non-text contrast applies to visual information required to identify UI components/states; decorative separators may be classified separately. [CITED: https://www.w3.org/TR/WCAG22/]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Browser behavior verification | Manual visual UAT | Existing `mix test.e2e` Playwright lane | Project policy requires rendered behavior checks to be automated. [VERIFIED: `.planning/STATE.md`] |
| Token source hierarchy | New design-token registry | Existing canonical CSS + documented derivatives | Phase 46 designated `priv/static/cairnloop.css` as canonical. [VERIFIED: `46-DISCREPANCY-LEDGER.md`] |
| WCAG math dependency | New npm package | Tiny stdlib formula in ExUnit/Node | Formula is stable and Phase 46 already used stdlib script evidence. [VERIFIED: `46-CONTRAST-BASELINE.md`; ASSUMED for implementation language] |
| Tailwind token mirror | Custom generator during this phase | Direct `@theme` primitive updates and pure drift test | No build-step redesign is in Phase 48 scope. [VERIFIED: `48-UI-SPEC.md`] |

**Key insight:** Phase 48 is a controlled propagation problem; adding tooling or dependencies increases the chance of drift instead of reducing it. [ASSUMED]

## Common Pitfalls

### Pitfall 1: Dark Danger Looks Selected But Still Fails

**What goes wrong:** `--cl-danger: #C96A55` is applied in dark mode while `.cl-button--danger` keeps `color: #FFFFFF`. [VERIFIED: `priv/static/cairnloop.css`]
**Why it happens:** The chosen dark danger value was selected as a token, not as a white-text button pair. [VERIFIED: `48-UI-SPEC.md`; VERIFIED: local Node WCAG ratio script]
**How to avoid:** Add a semantic danger button text token or darken the dark danger background until the actual button pair passes 4.5. [ASSUMED]
**Warning signs:** Contrast output shows white on `#C96A55` as 3.70:1. [VERIFIED: local Node WCAG ratio script]

### Pitfall 2: Coverage Gap Mistaken for Drift

**What goes wrong:** The planner tries to mirror every canonical token into `tokens.json` or `@theme`. [VERIFIED: `46-DISCREPANCY-LEDGER.md`]
**Why it happens:** Phase 46 documented derivatives with partial coverage, not full token dumps. [VERIFIED: `46-DISCREPANCY-LEDGER.md`]
**How to avoid:** Require exact parity only for values the derivative expresses; add coverage only for real Phase 48 needs. [VERIFIED: `48-UI-SPEC.md`]
**Warning signs:** Plan expands spacing, motion, z-index, or full status triads into `tokens.json` without a requirement. [ASSUMED]

### Pitfall 3: Shadow Drift Survives Because It Is Not a Color

**What goes wrong:** Phase 48 fixes palette values but leaves app.css `--cl-shadow-raised` divergent. [VERIFIED: `46-DISCREPANCY-LEDGER.md`]
**Why it happens:** Token drift worklist includes a non-color alias value. [VERIFIED: `46-DISCREPANCY-LEDGER.md`]
**How to avoid:** Include `--cl-shadow-raised: var(--cl-shadow-1)` in derivative propagation. [VERIFIED: `46-DISCREPANCY-LEDGER.md`]
**Warning signs:** Drift test only compares hex color values. [ASSUMED]

### Pitfall 4: CSS Falls Outside Existing Brand Gate

**What goes wrong:** Hardcoded CSS values change but `brand_token_gate_test.exs` remains green. [VERIFIED: `test/cairnloop/web/brand_token_gate_test.exs`]
**Why it happens:** The gate intentionally scans render `.ex` files and excludes CSS. [VERIFIED: `test/cairnloop/web/brand_token_gate_test.exs`]
**How to avoid:** Add a Phase 48-specific pure CSS/token drift and contrast check. [ASSUMED]
**Warning signs:** Verification relies only on the existing brand-token gate for token correctness. [ASSUMED]

## Code Examples

### WCAG Contrast Helper

```javascript
// Source: WCAG 2.x relative luminance formula used by Phase 46 and W3C thresholds.
function luminance(hex) {
  const [r, g, b] = [0, 2, 4]
    .map((i) => parseInt(hex.replace("#", "").slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrast(fg, bg) {
  const a = luminance(fg);
  const b = luminance(bg);
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}
```

### Drift Check Shape

```elixir
# Source: current ExUnit pure file-content test style in test/cairnloop/web/cairnloop_css_test.exs
canonical = File.read!("priv/static/cairnloop.css")
app_css = File.read!("examples/cairnloop_example/assets/css/app.css")
tokens = Jason.decode!(File.read!("prompts/cairnloop.tokens.json"))

assert canonical =~ "--cl-color-path-copper:   #A8492A;"
assert app_css =~ "--color-cl-path-copper: #A8492A;"
assert tokens["color"]["primitive"]["path_copper"]["value"] == "#A8492A"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Static shipped seed palette treated as gospel | vM017 reopened palette/type as evolvable seed | vM017 planning | Phase 48 may change values but not token names. [VERIFIED: `.planning/STATE.md`] |
| One-off contrast baseline pasted from throwaway script | Recompute Phase 46 matrix after token evolution | Phase 48 success criteria | The planner should create repeatable evidence rather than relying on old ratios. [VERIFIED: `.planning/ROADMAP.md`] |
| Tailwind config JS theme | Tailwind v4 `@theme` CSS variables in app.css | Existing example app | Primitive mirror must stay top-level `@theme` and exact. [VERIFIED: `examples/cairnloop_example/assets/css/app.css`; CITED: https://tailwindcss.com/docs/theme] |

**Deprecated/outdated:**
- Treating `prompts/cairnloop.tokens.json` as canonical is deprecated by Phase 46. [VERIFIED: `46-DISCREPANCY-LEDGER.md`]
- Human UAT for rendered behavior is deprecated by project verification policy; use gated Playwright E2E. [VERIFIED: `.planning/STATE.md`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Additive `--cl-danger-button-text` is the chosen way to keep `#C96A55` and pass dark danger contrast. | Summary, Patterns, Pitfalls | If implementation discovers an impossible cascade conflict, it must document why and choose a darker danger value that proves 4.5. |
| A2 | Use a small stdlib contrast script/test instead of adding a package. | Standard Stack, Don't Hand-Roll | If the project already has hidden tooling, planner may reuse it instead. |
| A3 | Do not expand all missing token categories into derivatives unless a real Phase 48 need appears. | Common Pitfalls | Planner could under-document status triads if Phase 51 expects JSON coverage. |

## Resolved Research Decisions

1. **Dark danger uses an additive text token.**
   - What we know: `#C96A55` is selected for dark danger, but white text on it is 3.70:1. [VERIFIED: `48-UI-SPEC.md`; VERIFIED: local Node WCAG ratio script]
   - Resolution: Use additive `--cl-danger-button-text` with light `#FFFFFF` and dark `#141B19`; this preserves the selected dark danger background and gives the actual dark danger button pair a passing text contrast path. [ASSUMED]
   - Plan binding: Plan 48-01 Task 2 must add and consume this token; Plan 48-02 Task 1 must document the resulting contrast evidence. [VERIFIED: `48-01-PLAN.md`; VERIFIED: `48-02-PLAN.md`]

2. **Dark `--cl-warning` may remain equal to dark `--cl-primary` when documented.**
   - What we know: Phase 46 flagged equality as an open question, and Phase 47 selected Refined without naming a replacement dark warning value. [VERIFIED: `46-DISCREPANCY-LEDGER.md`; VERIFIED: `47-SELECTION-GATE.md`]
   - Resolution: Keep the equality if the evolved contrast/hierarchy checks pass and warning states still carry text/icon meaning; this is an intentional amber/copper overlap, not unresolved drift. If checks show a real issue, remediate in Plan 01 and document the replacement value. [ASSUMED]
   - Plan binding: Plan 48-02 Task 1 must include either `Dark warning/primary equality: intentional` or a remediation entry with the new value and passing ratio. [VERIFIED: `48-02-PLAN.md`]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | `mix test`, `mix test.integration`, compile checks | ✓ | Elixir 1.19.5 / Mix 1.19.5 | none |
| Node | contrast/drift script option; Playwright tooling | ✓ | v22.14.0 | Elixir stdlib script |
| npm | example app Playwright dependency install | ✓ | 11.1.0 | existing lockfile if already installed |
| Python 3 | optional contrast script fallback | ✓ | 3.14.4 | Node or Elixir stdlib |
| ripgrep | token/scope scans | ✓ | 15.1.0 | `grep` |
| Playwright | `mix test.e2e` browser lane | ✓ in lockfile | 1.60.0 | no human fallback; install via existing `assets.setup` lane |

**Missing dependencies with no fallback:** none detected from CLI probes. [VERIFIED: local probes]
**Missing dependencies with fallback:** none detected. [VERIFIED: local probes]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit plus PhoenixTest Playwright for example-app E2E. [VERIFIED: `mix.exs` + `examples/cairnloop_example/mix.exs`] |
| Config file | `test/test_helper.exs`; example E2E helper under `examples/cairnloop_example/test/test_helper.exs`. [VERIFIED: `rg`] |
| Quick run command | `mix test test/cairnloop/web/brand_token_gate_test.exs test/cairnloop/web/cairnloop_css_test.exs` [VERIFIED: existing files] |
| Full suite command | `mix test && mix test.integration && mix test.e2e` [VERIFIED: `.planning/ROADMAP.md`] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| TOKEN-02 | Canonical tokens updated with no existing `--cl-*` rename/removal. | unit/source | `mix test test/cairnloop/web/token_drift_test.exs` | ❌ Wave 0 |
| TOKEN-03 | `app.css` and `tokens.json` expressed values match canonical. | unit/source | `mix test test/cairnloop/web/token_drift_test.exs` | ❌ Wave 0 |
| TOKEN-04 | Contrast matrix passes or documents decorative border classifications; gates green. | unit + integration + e2e | `mix test && mix test.integration && mix test.e2e` | Partial ✅ existing gates; ❌ contrast reverify test |

### Sampling Rate

- **Per task commit:** `mix test test/cairnloop/web/token_drift_test.exs test/cairnloop/web/brand_token_gate_test.exs` [ASSUMED]
- **Per wave merge:** `mix test` [VERIFIED: `CLAUDE.md`]
- **Phase gate:** `mix test && mix test.integration && mix test.e2e` [VERIFIED: `.planning/ROADMAP.md`]

### Wave 0 Gaps

- [ ] `test/cairnloop/web/token_drift_test.exs` — covers TOKEN-02/TOKEN-03 no-renames and derivative parity. [ASSUMED]
- [ ] `test/cairnloop/web/token_contrast_test.exs` or same file section — covers TOKEN-04 Phase 46 matrix revalidation. [ASSUMED]
- [ ] `.planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md` — durable evidence table for Phase 48 verification. [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | No auth behavior changes in token-only phase. [VERIFIED: phase scope] |
| V3 Session Management | no | No session behavior changes in token-only phase. [VERIFIED: phase scope] |
| V4 Access Control | no | No access-control behavior changes in token-only phase. [VERIFIED: phase scope] |
| V5 Input Validation | yes | Validate local token file parsing and JSON shape with strict expected keys in tests. [ASSUMED] |
| V6 Cryptography | no | No crypto behavior changes in token-only phase. [VERIFIED: phase scope] |

### Known Threat Patterns for Token Propagation

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Hidden external asset or CDN introduced during type work | Information Disclosure / Tampering | No new fonts, CDN assets, or package installs; preserve existing font stacks. [VERIFIED: `48-UI-SPEC.md`] |
| Unreviewed hardcoded color in render code | Tampering | Existing ExUnit brand-token gate scans render `.ex` files. [VERIFIED: `brand_token_gate_test.exs`] |
| Token drift causing misleading status/readability | Tampering / Repudiation | Pure drift and contrast checks in CI. [ASSUMED] |

## Sources

### Primary (HIGH confidence)

- `.planning/STATE.md` — vM017 decisions, phase ordering, verification policy. [VERIFIED: file read]
- `.planning/ROADMAP.md` — Phase 48 goal and success criteria. [VERIFIED: file read]
- `.planning/REQUIREMENTS.md` — TOKEN-02, TOKEN-03, TOKEN-04. [VERIFIED: file read]
- `.planning/phases/48-token-evolution-lock-propagate/48-UI-SPEC.md` — selected values and UI contract. [VERIFIED: file read]
- `.planning/phases/47-brand-direction-exploration-selection-gate/47-SELECTION-GATE.md` — locked owner selection. [VERIFIED: file read]
- `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md` — contrast matrix and failures. [VERIFIED: file read]
- `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-DISCREPANCY-LEDGER.md` — canonical source and drift worklist. [VERIFIED: file read]
- `priv/static/cairnloop.css`, `examples/cairnloop_example/assets/css/app.css`, `prompts/cairnloop.tokens.json` — current token sources. [VERIFIED: file read]

### Secondary (MEDIUM confidence)

- W3C WCAG 2.2 — contrast thresholds for text and non-text UI components. [CITED: https://www.w3.org/TR/WCAG22/]
- Tailwind CSS theme variables documentation — `@theme` behavior. [CITED: https://tailwindcss.com/docs/theme]
- MDN CSS custom properties guide and `var()` reference — custom property fallback behavior. [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascading_variables/Using_custom_properties] [CITED: https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/var]

### Tertiary (LOW confidence)

- Additive `--cl-danger-button-text` recommendation and stdlib script implementation shape are local engineering recommendations, not locked owner decisions. [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing project files and local versions were inspected. [VERIFIED: local probes]
- Architecture: HIGH — canonical source and derivatives are explicitly documented by Phase 46. [VERIFIED: `46-DISCREPANCY-LEDGER.md`]
- Pitfalls: HIGH for known failures; LOW for exact remediation preferences. [VERIFIED: `46-CONTRAST-BASELINE.md`; ASSUMED]

**Research date:** 2026-06-24
**Valid until:** 2026-07-24 for local token architecture; 2026-07-01 for Tailwind/Playwright version-sensitive details. [ASSUMED]
