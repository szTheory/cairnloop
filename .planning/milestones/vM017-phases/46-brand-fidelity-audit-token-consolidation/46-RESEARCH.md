# Phase 46: Brand Fidelity Audit & Token Consolidation - Research

**Researched:** 2026-06-23
**Domain:** Design-token reconciliation + WCAG-AA contrast auditing (pure analysis / documentation)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 (owner-selected): Document-only — defer all edits to Phase 48.** When the ledger finds drift
  between canonical `:root` and its derivatives (`app.css` `@theme`, `cairnloop.tokens.json`), Phase 46
  **records it but does not edit any file.** The drift items in the ledger become the explicit worklist
  Phase 48 must zero out.
- **D-02:** `priv/static/cairnloop.css` `:root` is the **single canonical token source** (it ships, carries
  the live ~470 `--cl-*` references, and is what the operator UI actually consumes).
- **D-03:** `prompts/cairnloop.tokens.json`, the example-app `assets/css/app.css` `@theme` block, and the
  prose color rules in `prompts/cairnloop_brand_book.md` are each documented in the ledger as
  **derivatives/expressions** of canonical `:root` — **none are deleted or restructured** in this phase.
  Cite `app.css`'s existing "keep both in sync with priv/static/cairnloop.css" comment as the existing
  (informal) provenance marker.
- **D-04:** Two Markdown artifacts in the phase dir: `46-DISCREPANCY-LEDGER.md` and `46-CONTRAST-BASELINE.md`.
  The contrast baseline is a clean, self-contained Markdown table (hex + token name + pairing + ratio +
  AA pass/fail/large badge) designed so **Phase 51 lifts it verbatim** into the brand book.
- **D-05:** Cover **both light AND dark themes** (the operator UI ships a dark mode; pairings differ per theme).
- **D-06:** WCAG 2.x thresholds — **4.5:1** normal text, **3.0:1** large text (≥24px, or ≥18.66px bold),
  **3.0:1** non-text UI components (borders, focus rings, route marker as semantic indicator).
- **D-07 (tooling):** Compute ratios with a **throwaway relative-luminance script** (deterministic, run-once);
  **nothing committed to the library** — the deliverable is the static table, not a tool or runtime dependency.
- **D-08 (failures):** Any AA failure documented in the baseline table **with a remediation note**, surfaced as
  explicit input to Phase 47 palette exploration / Phase 48 re-verify. The palette is **not** adjusted here.

### Claude's Discretion
- Exact ledger table columns/grouping, how pairings are enumerated, and the script implementation are
  planner/executor discretion within the above constraints.

### Deferred Ideas (OUT OF SCOPE)
- **Automated drift-guard test** (diffs derivatives against canonical) — Phase 48 (its SC2 already requires the diff).
- **Editing/regenerating derivatives to eliminate drift** — Phase 48 per D-01.
- **Type/font-stack inventory & evolution** — Phase 47 (TOKEN-01).
- **Making `tokens.json` a generated artifact** (true derivation pipeline) — Phase 50 (BOOK-02).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FIDELITY-01 | A discrepancy ledger documents every drift between `cairnloop_brand_book.md`, `cairnloop.tokens.json`, and the live `--cl-*` values in `cairnloop.css`. | Full token inventory (light + dark) extracted from canonical CSS below; derivative cross-reference identifies the four concrete drift classes already present. The ledger is a fill-in-the-table exercise over the enumerated tokens. |
| FIDELITY-02 | A single canonical token source is established (`cairnloop.css` `:root`); the example-app `app.css` block and `cairnloop.tokens.json` are documented as derivatives of it. | D-02/D-03 already designate canonical; research locates the existing provenance comment in `app.css` (line 4-7) and documents each derivative's expressed-token coverage. |
| FIDELITY-03 | A WCAG-AA contrast baseline table covers every fg/bg brand pairing used in the brand book and operator UI, flagging failures. | Complete pairing enumeration derived directly from the component CSS rules (not guessed); validated relative-luminance method + sample ratios precomputed below. |
</phase_requirements>

## Summary

Phase 46 is a pure paper-and-table audit: zero runtime code, zero file edits to the brand sources, one
throwaway script that is run and discarded. The three deliverables are documentation artifacts whose
"correctness" is an **artifact-completeness** property — every canonical token is accounted for in the
ledger, every shipped fg/bg pairing is scored in the contrast table, and each derivative carries a
provenance note.

The single highest-value finding for the planner is that **the raw material already exists in the
codebase and is fully enumerable** — there is no research uncertainty to resolve. The canonical
`priv/static/cairnloop.css` carries 15 primitives + a complete semantic layer in both a light `:root`
block (lines 18–157) and a `[data-theme="dark"]` block (lines 160–194). The component CSS rules
(lines 216–479) literally encode every fg/bg pairing as `color: var(--cl-…)` over `background:
var(--cl-…)`, so the contrast table can be built mechanically from the source rather than estimated.
The status chips/banners use self-consistent `*-surface` / `*-border` / `*-text` triads, making those
the cleanest pairings to score.

A second key finding: the example-app `app.css` `@theme`/`:root` block is **already drifted** from
canonical — it omits a large swath of semantic tokens (`surface-sunken`, `text-soft`, `border-strong`,
`primary-hover`, the status `*-surface/*-border/*-text` triads, `overlay`, all spacing/z/motion/control/
layout scales) and carries a **different `--cl-shadow-raised` value** than canonical. These are exactly
the drift items the ledger must capture (and Phase 48 must zero out). The `tokens.json` is the cleanest
derivative — its `color.primitive` block matches canonical primitive-for-primitive, and its
`semantic_light`/`semantic_dark` resolve correctly.

**Primary recommendation:** Build the ledger directly off the token inventory tables below
(primitive-by-primitive, then semantic-by-semantic, per theme), and build the contrast table directly off
the component-rule pairing enumeration below, scored with a ~25-line Python relative-luminance script.
Flag the near-miss `text-muted #677066 → bg` (4.52:1, barely passes) and the copper route-marker pairings
as the headline AA-attention items. No external libraries, no installs — this phase touches nothing on any
package registry.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Token inventory / canonical designation | Static CSS / Storage (the shipped `cairnloop.css`) | Docs (`tokens.json`, brand book) | Tokens live in the shipped CSS that the operator UI consumes; the audit reads, never executes. |
| Derivative cross-reference | Docs / Static assets | — | `tokens.json` + `app.css @theme` + brand-book prose are all build-time/doc expressions, not runtime. |
| fg/bg pairing enumeration | Static CSS (component rules) | Browser (rendered theme) | The shipped pairings are declared in `cairnloop.css` component rules; the browser only resolves them per `[data-theme]`. |
| Contrast computation | Throwaway local script (build/dev tier) | — | Run-once, off-repo; produces a static table — never a runtime dependency (D-07). |
| Deliverable artifacts | Docs (phase dir Markdown) | — | Two `.md` files in the phase dir; one is forward-consumed verbatim by Phase 51. |

## Standard Stack

This phase installs **no packages** and adds **no runtime dependency**. The only "stack" is a throwaway
script run locally and discarded (D-07).

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Python 3 | 3.14.4 (verified `python3 --version`) | Throwaway WCAG relative-luminance / contrast-ratio script | Already on this machine `[VERIFIED: local shell]`; stdlib-only, zero deps, deterministic. |
| Node | v22.14.0 (verified `node --version`) | Alternative throwaway script runtime if preferred | Already on this machine `[VERIFIED: local shell]`. |

**Recommendation:** Use Python 3 stdlib (no `pip install`). The full algorithm is ~25 lines (provided in
Code Examples). Do **not** add a contrast library, a `mix` dep, or commit the script — write it to the
scratchpad / a `# REMOVE` scratch file, run it, paste results into `46-CONTRAST-BASELINE.md`, delete it.

### Supporting
None. No installs.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Throwaway local script | An online contrast checker (WebAIM) | Manual, error-prone for ~30 pairings × 2 themes, not reproducible. D-07 mandates the script. |
| Throwaway local script | A committed Elixir contrast module | Violates D-07 (nothing committed) and repo hygiene; this is analysis, not a feature. |

**Installation:** None. (`python3` and `node` already present.)

## Package Legitimacy Audit

> Not applicable — this phase installs **no external packages** and adds no dependency to `mix.exs`,
> `package.json`, or any lockfile. The only tooling is a stdlib-only throwaway script that is never committed
> (D-07). No registry lookups were required.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
                          THREE BRAND SOURCES (read-only this phase)
                          ───────────────────────────────────────────

   priv/static/cairnloop.css  ─────────────┐  CANONICAL (D-02)
     :root (light)  lines 18–157           │  15 primitives + full semantic layer
     [data-theme="dark"] lines 160–194     │  + status triads + scales (space/radius/
                                           │    shadow/z/motion/control/layout)
                                           │
            (expressed-by ▼ derivatives, documented not edited — D-03)
                                           │
   prompts/cairnloop.tokens.json           │  color.primitive (15) + semantic_light +
     (primitives + semantic maps) ─────────┤    semantic_dark + typography + voice
                                           │
   examples/.../assets/css/app.css         │  @theme (15 color primitives, Tailwind)
     @theme + @layer base :root/dark ──────┤    + PARTIAL :root/dark semantic mirror
     (carries "keep in sync" comment)      │    ← ALREADY DRIFTED (subset + shadow delta)
                                           │
   prompts/cairnloop_brand_book.md         │  §7.2 primitives, §7.4 semantic, §7.5
     §7 color prose ───────────────────────┘    accessible-pairings, §7.6 state meanings
                                           │
                ┌──────────────────────────┴───────────────────────────┐
                ▼                                                        ▼
   ╔═══════════════════════════╗                          ╔══════════════════════════════╗
   ║  46-DISCREPANCY-LEDGER.md  ║                          ║  46-CONTRAST-BASELINE.md       ║
   ║  (FIDELITY-01/02)          ║                          ║  (FIDELITY-03)                 ║
   ║  per-token drift rows +    ║                          ║  fg/bg pairing × theme × ratio ║
   ║  provenance notes          ║                          ║  × verdict (AA/AA-large/FAIL)  ║
   ╚═══════════════════════════╝                          ╚══════════════╤═══════════════╝
                                                                          │ lifted verbatim
                          throwaway WCAG script ─── feeds ────────────────┘  → Phase 51 (BOOK-03)
                          (run-once, discarded, D-07)                        → Phase 48 SC4 (re-verify)
```

The diagram traces the primary flow: read three sources → reconcile on paper into the ledger; enumerate
shipped pairings + score with the throwaway script → contrast table. No arrow returns to the source files
(document-only, D-01).

### Recommended Artifact Structure
```
.planning/phases/46-brand-fidelity-audit-token-consolidation/
├── 46-RESEARCH.md            # this file
├── 46-DISCREPANCY-LEDGER.md  # FIDELITY-01 + FIDELITY-02 provenance
└── 46-CONTRAST-BASELINE.md   # FIDELITY-03 — Phase-51-liftable table
```
(Throwaway script lives in scratchpad, never in the repo tree.)

### Pattern 1: Canonical-vs-derivative diff table
**What:** For the ledger, group by layer (primitives → semantic-light → semantic-dark → scales). For each
canonical token, one row: `Token | Canonical value | tokens.json | app.css @theme | brand-book prose | Drift?`.
A cell is "—" when that derivative does not express the token (itself a documented gap, not a value drift).
**When to use:** FIDELITY-01/02 ledger.
**Example:** (drift classes found in research, below in Don't Hand-Roll / Pitfalls).

### Pattern 2: Self-contained contrast row (Phase-51-liftable)
**What:** `Pairing | FG token (hex) | BG token (hex) | Theme | Ratio | Threshold | Verdict`. Threshold column
is explicit (4.5 / 3.0) so the row is self-documenting when lifted into the brand book with no surrounding prose.
**When to use:** FIDELITY-03 contrast table.
**Why:** D-04 requires verbatim reuse in Phase 51; design the row to stand alone.

### Anti-Patterns to Avoid
- **Editing any brand source to "fix" drift:** Violates D-01. Record it; Phase 48 fixes it.
- **Vague "every pairing" prose instead of an enumerated table:** The pairings are finite and listed below; enumerate them.
- **Committing the contrast script or adding a contrast dep:** Violates D-07 + repo hygiene.
- **Scoring only light theme:** D-05 requires both; dark pairings have different values and different risk profile.
- **Treating `tokens.json`'s missing scales as "drift":** It is a *color+type+voice* derivative by design; note coverage scope, don't flag absent spacing/z tokens as value drift.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Relative luminance / contrast ratio | A bespoke "eyeball it" estimate or a committed module | The exact WCAG 2.x sRGB formula in a throwaway script (Code Examples below) | The formula is fixed and standardized; eyeballing is wrong, a committed module violates D-07. |
| Enumerating shipped pairings | Guessing pairings from the palette table | Read them off the component CSS rules (lines 216–479) | The CSS *declares* the real fg-on-bg combinations; the palette table alone over/under-counts. |
| Provenance marker | Inventing a new sync convention | Cite the existing `app.css` comment (lines 4–7) | D-03 says reuse the existing informal marker. |

**Key insight:** Everything this phase needs is already in the repo and finite. The work is transcription +
arithmetic + verdicts, not discovery. The biggest failure mode is *under-enumeration* (missing a pairing or a
token), not getting a ratio wrong.

## Token Inventory (extracted from canonical `priv/static/cairnloop.css`)

### Primitives (15) — `:root` lines 20–34; identical names mirrored in `tokens.json` + `app.css @theme`
| Token | Hex | Role (brand book §7.2) |
|-------|-----|------------------------|
| `--cl-color-basalt` | `#18211F` | core text / dark surface |
| `--cl-color-moss-ink` | `#263A2E` | secondary dark / deep UI |
| `--cl-color-trailpaper` | `#F5F0E6` | main canvas |
| `--cl-color-warm-stone` | `#FBF7EE` | card surface |
| `--cl-color-granite` | `#D8D0BF` | quiet border |
| `--cl-color-slate-lichen` | `#677066` | muted text / disabled |
| `--cl-color-path-copper` | `#A94F30` | primary action / active route |
| `--cl-color-copper-glow` | `#C46A3A` | decorative accent only |
| `--cl-color-lichen` | `#A8B56C` | success accent / safe sourced answer |
| `--cl-color-deep-lichen` | `#4A6238` | success text / positive state |
| `--cl-color-glacier-mist` | `#DDE8E3` | info surface / retrieval panel |
| `--cl-color-waypoint-blue` | `#3F6F80` | info text / links |
| `--cl-color-heather` | `#7A5D78` | AI/eval accent |
| `--cl-color-ember` | `#8B531E` | warning text / budget risk |
| `--cl-color-fault-clay` | `#B54C36` | danger text / blocked policy |

### Semantic — light `:root` (lines 37–67) vs dark `[data-theme="dark"]` (lines 161–188)
| Semantic token | Light | Dark | Notes |
|----------------|-------|------|-------|
| `--cl-bg` | `var(trailpaper)` `#F5F0E6` | `#101614` | dark bg is a NEW value, no light primitive |
| `--cl-surface` | `var(warm-stone)` `#FBF7EE` | `#18211F` (=basalt) | |
| `--cl-surface-raised` | `#FFFFFF` | `#1F2C28` | literal, no primitive |
| `--cl-surface-sunken` | `#EFE9DC` | `#0C110F` | **absent from `app.css` derivative** |
| `--cl-text` | `var(basalt)` `#18211F` | `#F5F0E6` | |
| `--cl-text-muted` | `var(slate-lichen)` `#677066` | `#B7C0B2` | |
| `--cl-text-soft` | `#8A8C82` | `#8A9488` | **absent from `app.css` derivative** |
| `--cl-border` | `var(granite)` `#D8D0BF` | `#34443D` | |
| `--cl-border-strong` | `#BFB6A2` | `#44564D` | **absent from `app.css` derivative** |
| `--cl-primary` | `var(path-copper)` `#A94F30` | `#D98A4A` | dark primary ≠ any light primitive |
| `--cl-primary-hover` | `#97462A` | `#E69A5C` | **absent from `app.css` derivative** |
| `--cl-primary-text` | `#FFFFFF` | `#18211F` | |
| `--cl-on-primary` | alias→primary-text | (inherits) | alias for sealed render code |
| `--cl-success` | `var(deep-lichen)` `#4A6238` | `#A8B56C` (=lichen) | |
| `--cl-info` | `var(waypoint-blue)` `#3F6F80` | `#9EC3CF` | |
| `--cl-ai` | `var(heather)` `#7A5D78` | `#C9A7C6` | |
| `--cl-warning` | `var(ember)` `#8B531E` | `#D98A4A` (=primary, by design?) | flag for ledger: dark warning == dark primary |
| `--cl-danger` | `var(fault-clay)` `#B54C36` | `#E18C7D` | |
| `--cl-focus` | `var(path-copper)` `#A94F30` | `#D98A4A` | |
| `--cl-overlay` | `rgba(24,33,31,0.44)` | `rgba(0,0,0,0.58)` | **absent from `app.css` derivative** |

### Status triads — light (lines 60–67) / dark (lines 181–188); **entirely absent from `app.css` derivative**
| Group | Light surface / border / text | Dark surface / border / text |
|-------|-------------------------------|------------------------------|
| success | `#EDF1E2` / `#C9D3A6` / `#3C5430` | `#1E2A1C` / `#38492E` / `#BFD194` |
| info | `#DDE8E3` / `#B7CDD4` / `#335A68` | `#16252A` / `#2E4750` / `#AFD3DE` |
| warning | `#F6ECDD` / `#E3C9A0` / `#7A4818` | `#2A2014` / `#4A3A22` / `#E8B488` |
| danger | `#F6E3DE` / `#E3B6AC` / `#9A3E2C` | `#2A1A16` / `#4A302A` / `#ECA99C` |
| ai | `#ECE4EB` / `#CDB6CB` / `#5F4A5D` | `#241E29` / `#433A48` / `#D6BCD3` |
| neutral | `#EFEADF` / `var(border)` / `var(text-muted)` | `#1C2622` / `var(border)` / `var(text-muted)` |
| legacy aliases | `--cl-warning-bg`→warning-surface; `--cl-danger-soft`→danger-surface | (same aliases) |

### Non-color scales (canonical only — NOT in `tokens.json`/`app.css`; scope-note in ledger, not "drift")
Typography (`--cl-font-*`, `--cl-leading-*`, `--cl-weight-*`, lines 70–84), spacing (`--cl-space-0..11` +
gutter/stack/inline, 87–101), radius (104–108), shadow (`--cl-shadow-1..4` + aliases, 111–119), z-index
(122–128), layout (`--cl-content-max/rail-width/page-gutter`, 138–140), motion (`--cl-dur-*`/`--cl-ease-*`/
`--cl-stagger`, 143–153), controls (`--cl-control-h/px-*`, 131–133), focus-ring composite (156).
`app.css` carries only a 3-row radius subset + one shadow token. Typography appears in `tokens.json` and the
brand book §8. The ledger should note *which derivative covers which scale*, not flag absent scales as value drift.

## Derivative Cross-Reference (raw material for FIDELITY-01/02 ledger)

| Derivative | Expresses | Existing provenance marker | Drift found in research |
|------------|-----------|----------------------------|--------------------------|
| `prompts/cairnloop.tokens.json` | 15 primitives (`color.primitive`), semantic_light (14 keys), semantic_dark (14 keys), typography (3), voice | none (implicit) | **CLEAN on primitives + the 14 semantic keys it carries.** Omits: `surface-sunken`, `text-soft`, `border-strong`, `primary-hover`, `on-primary`, status triads, overlay, all non-color scales. (Scope gap, not value drift — note as coverage.) |
| `examples/.../assets/css/app.css` `@theme` + `@layer base` | 15 primitives (`@theme` → Tailwind utilities) re-declared as `--cl-color-*` in `:root`; PARTIAL semantic mirror (14 of the core semantics) + dark block | **EXISTING comment lines 4–7**: "keep both in sync with priv/static/cairnloop.css" — cite this (D-03). | **VALUE drift:** `--cl-shadow-raised` = `0 1px 2px rgba(24,33,31,0.08), 0 8px 24px rgba(24,33,31,0.06)` here vs `var(--cl-shadow-1)` = `0 1px 2px rgba(24,33,31,0.06)` in canonical. **COVERAGE drift:** omits `surface-sunken`, `text-soft`, `border-strong`, `primary-hover`, `overlay`, status triads, spacing/z/motion/control/layout scales, full radius set, font sizes/leading/weight. Also imports canonical via `@import "../../../../priv/static/cairnloop.css"` (line 7) so at runtime canonical wins — but the literal re-declared block can silently drift. |
| `prompts/cairnloop_brand_book.md` §7 | §7.2 primitives table (15, hex), §7.4 semantic table (14, light+dark), §7.5 accessible-pairings + a11y rules, §7.6 state meanings | none (prose seed) | Cross-check §7.2/§7.4 hex against canonical — research spot-check shows **MATCH** primitive-for-primitive and semantic-for-semantic. Brand book is the *seed*; ledger should confirm no hex has drifted from it. §7.5 rules (4.5 normal / 3.0 large+UI, "never color alone") are the policy the contrast table operationalizes. |

**Note (Tailwind/daisyUI noise):** `app.css` also defines two daisyUI `@plugin` theme blocks (lines 110–186)
using `oklch(...)` Phoenix/Elixir-inspired colors. These are the **example app's daisyUI scaffolding, not the
Cairnloop brand** — exclude them from the ledger (they are not `--cl-*` tokens). Flag in ledger as
"out-of-scope: example-app daisyUI defaults, not a brand derivative."

## Operator-UI fg/bg Pairing Enumeration (raw material for FIDELITY-03)

Pairings read directly off component CSS rules in `cairnloop.css` (lines 216–479). Each row is a real shipped
fg-on-bg combination. **All recur in dark theme via the `[data-theme]` overrides** — score every row in BOTH themes.

| # | Pairing (component) | FG token | BG token | Threshold | Source line |
|---|---------------------|----------|----------|-----------|-------------|
| 1 | App body text on canvas | `--cl-text` | `--cl-bg` | 4.5 | 217–218 |
| 2 | Body text on card surface | `--cl-text` | `--cl-surface` | 4.5 | 329 |
| 3 | Body text on raised surface (inputs/buttons) | `--cl-text` | `--cl-surface-raised` | 4.5 | 304, 381 |
| 4 | Muted/secondary text on canvas | `--cl-text-muted` | `--cl-bg` | 4.5 | 250, 283 |
| 5 | Muted text on surface (table th, breadcrumb, stat meta, tabs) | `--cl-text-muted` | `--cl-surface` | 4.5 | 393, 423, 468, 475 |
| 6 | Soft text (empty-icon, breadcrumb sep) on surface | `--cl-text-soft` | `--cl-surface`/`--cl-bg` | 4.5 (decorative? note) | 407, 469 |
| 7 | Link / info text on canvas | `--cl-info` | `--cl-bg` | 4.5 | 238 |
| 8 | Nav brand-mark (copper) on surface | `--cl-primary` | `--cl-surface` | 3.0 (icon/large) / 4.5 if text | 277 |
| 9 | Stat count (copper, 32px display) on surface | `--cl-primary` | `--cl-surface` | 3.0 (large ≥24px) | 421 |
| 10 | Calm stat count (success) on surface | `--cl-success` | `--cl-surface` | 3.0 (large) | 422 |
| 11 | Primary button text on copper | `--cl-primary-text` | `--cl-primary` | 4.5 | 314 |
| 12 | Primary button hover text on copper-hover | `--cl-primary-text` | `--cl-primary-hover` | 4.5 | 317 |
| 13 | Danger button white text on danger | `#FFFFFF` (=primary-text) | `--cl-danger` | 4.5 | 319 |
| 14 | Ghost button muted text on sunken (hover) | `--cl-text-muted`/`--cl-text` | `--cl-surface-sunken` | 4.5 | 322–323 |
| 15 | Nav active link text on sunken | `--cl-text` | `--cl-surface-sunken` | 4.5 | 292–293 |
| 16 | Field error text on surface | `--cl-danger-text` | `--cl-surface`/`--cl-bg` | 4.5 | 388 |
| 17 | Chip/banner: success text on success surface | `--cl-success-text` | `--cl-success-surface` | 4.5 | 352, 367 |
| 18 | Chip/banner: info text on info surface | `--cl-info-text` | `--cl-info-surface` | 4.5 | 353, 368 |
| 19 | Chip/banner: warning text on warning surface | `--cl-warning-text` | `--cl-warning-surface` | 4.5 | 354, 369 |
| 20 | Chip/banner: danger text on danger surface | `--cl-danger-text` | `--cl-danger-surface` | 4.5 | 355, 370 |
| 21 | Chip/banner: ai text on ai surface | `--cl-ai-text` | `--cl-ai-surface` | 4.5 | 356 |
| 22 | Chip: neutral text on neutral surface | `--cl-neutral-text` | `--cl-neutral-surface` | 4.5 | 349 |
| 23 | Code block (mono) on sunken | `--cl-text` | `--cl-surface-sunken` | 4.5 | 446 |
| **Non-text UI components (3.0 threshold)** | | | | | |
| 24 | Quiet border on canvas/surface | `--cl-border` | `--cl-bg`/`--cl-surface` | 3.0 | 270, 330, 337, 395 |
| 25 | Strong border (hover) on surface | `--cl-border-strong` | `--cl-surface` | 3.0 | 310, 386 |
| 26 | Route-active left border (copper) on surface | `--cl-primary` | `--cl-surface` | 3.0 | 341 |
| 27 | Active-link copper inset rule + tab underline | `--cl-primary` | `--cl-surface`/`--cl-surface-sunken` | 3.0 | 294, 479 |
| 28 | Status chip borders on their surfaces | `--cl-*-border` | `--cl-*-surface` | 3.0 | 352–356 |
| 29 | Focus ring copper against surface | `--cl-focus` | `--cl-surface` | 3.0 | 156, 245 |

**Brand-book accessible-pairings (§7.5, lines 514–521)** — score these too (FIDELITY-03 says "brand book AND
operator UI"). They overlap rows 1–13 plus: Moss Ink `#263A2E` on Trailpaper (headings), Trailpaper on Basalt
(dark hero blocks), Waypoint Blue on Trailpaper. Include them so the table is a superset usable by Phase 51.

**Headline AA-attention items (validated, see Code Examples for full method):**
- **`--cl-text-muted #677066 → --cl-bg #F5F0E6` = 4.52:1** — passes 4.5 by a hair; flag as fragile (any palette
  evolution in Phase 47 risks pushing it below). On `--cl-surface #FBF7EE` it is 4.81:1.
- **Copper `#A94F30` as body text on bg = 4.80:1** (passes normal); as a large/UI route marker the 3.0 threshold
  is met comfortably. The brand book §7.5 already warns: never white text on Copper *Glow* `#C46A3A`, only on
  Path Copper — verify white-on-copper = 5.46:1 (pass).
- **Dark `--cl-primary #D98A4A` as text on dark bg = 6.70:1** (pass); `--cl-primary-text #18211F` on it = 6.02:1.
- The copper route-marker is the explicitly-flagged highest-risk pairing per CONTEXT specifics — call it out in
  both themes even though current values pass, because Phase 47 may shift it.

## WCAG Ratio Method (for the throwaway script — D-07)

WCAG 2.x contrast ratio uses sRGB relative luminance `[CITED: w3.org/TR/WCAG22 — referenced in brand book §11 line 1152]`:

1. For each channel `c ∈ {R,G,B}`, normalize `c8/255`; then linearize:
   `c_lin = c/12.92` if `c ≤ 0.04045`, else `((c+0.055)/1.055)^2.4`.
2. `L = 0.2126·R_lin + 0.7152·G_lin + 0.0722·B_lin`.
3. `ratio = (L_lighter + 0.05) / (L_darker + 0.05)`.

**Thresholds (D-06):** normal text **4.5:1**; large text **3.0:1** (≥24px regular, or ≥18.66px/14pt bold);
non-text UI components & graphical objects (borders-as-UI, focus rings, route marker) **3.0:1**.

This formula is fixed and standardized — there is no version ambiguity for WCAG 2.0/2.1/2.2 (all share it).
WCAG 3.0 / APCA is a *different* model and is **out of scope** (D-06 says WCAG 2.x).

## Code Examples

### Throwaway WCAG contrast script (Python 3 stdlib — run once, do NOT commit)
```python
# Source: WCAG 2.x relative-luminance algorithm (w3.org/TR/WCAG22).
# THROWAWAY — D-07: run once, paste results into 46-CONTRAST-BASELINE.md, delete.
def _lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def luminance(hexs):
    h = hexs.lstrip("#")
    r, g, b = (int(h[i:i+2], 16) for i in (0, 2, 4))
    return 0.2126 * _lin(r) + 0.7152 * _lin(g) + 0.0722 * _lin(b)

def ratio(fg, bg):
    a, b = luminance(fg), luminance(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)

def verdict(r, large_or_ui=False):
    thresh = 3.0 if large_or_ui else 4.5
    if r >= 4.5: return "AA"
    if r >= 3.0: return "AA-large/UI" if large_or_ui else "FAIL (passes large only)"
    return "FAIL"

# Feed the enumerated pairings (light + dark) as (label, fg_hex, bg_hex, large_or_ui) tuples.
```

### Precomputed sample ratios (method validation — already run this session)
```
14.49:1  basalt #18211F on bg #F5F0E6                    -> AA
 4.52:1  text-muted #677066 on bg #F5F0E6                -> AA (fragile near-miss)
 4.81:1  text-muted #677066 on surface #FBF7EE           -> AA
 4.80:1  primary copper #A94F30 on bg #F5F0E6            -> AA
 5.46:1  white on primary copper #A94F30                 -> AA
 4.87:1  info #3F6F80 on bg #F5F0E6                       -> AA
 7.30:1  success-text #3C5430 on success-surface #EDF1E2 -> AA
 6.49:1  warning-text #7A4818 on warning-surface #F6ECDD -> AA
 5.47:1  danger-text #9A3E2C on danger-surface #F6E3DE   -> AA
 6.43:1  ai-text #5F4A5D on ai-surface #ECE4EB           -> AA
 6.70:1  DARK primary #D98A4A on bg #101614              -> AA
14.49:1  DARK text #F5F0E6 on surface #18211F            -> AA
 8.60:1  DARK warning-text #E8B488 on warning-surface #2A2014 -> AA
 6.02:1  DARK primary-text #18211F on primary #D98A4A    -> AA
```
These 14 are a representative slice; the executor expands to the full ~29-row × 2-theme matrix. Early signal:
the shipped light palette is largely AA-clean, with `text-muted on bg` the single fragile pass to flag for Phase 47.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| WCAG 2.x luminance contrast (this phase, D-06) | WCAG 3.0 / APCA (perceptual) | Draft, not ratified (as of 2026) | APCA is **out of scope**; D-06 locks WCAG 2.x. Do not switch models. |
| Forked palette copies drifting silently | Single canonical `:root` + documented derivatives (this milestone) | vM017 | Phase 46 establishes provenance; Phase 48 enforces zero-drift with a diff. |

**Deprecated/outdated:** none relevant. The `--cl-warning-bg` and `--cl-danger-soft` tokens are explicitly
labeled "legacy alias" in canonical (lines 63, 65) — note them in the ledger as aliases, not as drift.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The full set of shipped fg/bg pairings is captured by component rules in `cairnloop.css` lines 216–479; HEEx templates add no inline-styled pairings (the brand-token gate forbids inline hex/rgba in render `.ex`). | Pairing enumeration | A pairing rendered via a Tailwind utility class (`text-cl-*`/`bg-cl-*`) in the example app could exist outside the lib CSS. Mitigated: example app imports canonical and the gate scans its live dir; executor should still `grep` example-app HEEx for `text-cl-`/`bg-cl-` utility pairings to confirm completeness. |
| A2 | Brand-book §7.2/§7.4 hex values match canonical (spot-check matched). | Derivative cross-reference | If a hex silently drifted, the ledger row catches it — this is exactly what the ledger is for, so low risk. |
| A3 | `--cl-warning == --cl-primary` in dark (`#D98A4A`) is intentional, not a bug. | Token inventory | If unintentional it is a real drift/contrast concern; flag in ledger as a question for Phase 47, do not assume either way. |
| A4 | The `text-soft` tokens are decorative (icons, separators) so the 4.5 text threshold may be advisory. | Pairing row 6 | If `text-soft` carries meaningful text anywhere, it must hit 4.5; executor should confirm usage context before assigning threshold. |

## Open Questions (RESOLVED)

Both questions are answered-by-execution in the Phase 46 plan (`46-01-PLAN.md`, Task 2) — neither remains open for planning.

1. **(RESOLVED — folded into Task 2)** Does the example app render any `--cl-*` pairing via Tailwind utilities not present in lib CSS?
   - What we know: `app.css @theme` generates `bg-cl-*`/`text-cl-*` utilities from the 15 primitives.
   - What's unclear: whether example-app HEEx uses a primitive-on-primitive combo not in the component rules.
   - Recommendation: executor greps `examples/.../lib/**/*.heex` for `text-cl-`/`bg-cl-` and folds any new pairing into the table (cheap, completeness insurance for A1).
   - **Resolution:** Task 2 explicitly greps the example-app HEEx for `text-cl-`/`bg-cl-` utility pairings and folds any not already covered by the lib component rules into the contrast table.

2. **(RESOLVED — folded into Task 2)** Threshold for `text-soft` (row 6) and the route-marker-as-text vs route-marker-as-indicator.
   - What we know: D-06 splits 4.5 (text) vs 3.0 (UI/large). Copper is both a 32px stat count (large→3.0) and a 1px border (UI→3.0) and potentially link-sized text (4.5).
   - Recommendation: score copper at BOTH thresholds where it appears in both roles; annotate the verdict column with the role so Phase 51 reuse is unambiguous.
   - **Resolution:** Task 2 scores the copper route-marker at BOTH 3.0 (UI/large) and 4.5 (text) thresholds with a role-annotated verdict; `text-soft` (row 6) is scored against the threshold matching its confirmed usage context.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3 | throwaway WCAG script (D-07) | ✓ | 3.14.4 | Node v22 (same algorithm) |
| Node | alt script runtime | ✓ | v22.14.0 | Python 3 |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none — both runtimes present. No installs, no `mix` deps, no `Cairnloop.Repo`
needed (this phase reads files only; the known Repo-unavailable caveat is irrelevant here).

## Validation Architecture

> This phase ships **documentation artifacts**, not runtime code. "Validation" = artifact-completeness checks,
> not ExUnit tests. `workflow.nyquist_validation` framing adapted accordingly: the checks below are the
> deterministic, re-runnable gates a reviewer (or a future drift-guard in Phase 48) applies.

### "Test" Framework
| Property | Value |
|----------|-------|
| Framework | None (no code). Validation is artifact inspection + a re-runnable count check. |
| Config file | none |
| Quick run command | `grep -c '^\| ' .planning/phases/46-*/46-CONTRAST-BASELINE.md` (row count sanity) |
| Full suite command | Manual completeness review against the inventory tables in this RESEARCH.md |

### Phase Requirements → Validation Map
| Req ID | Behavior | Check Type | Concrete Check | Artifact |
|--------|----------|------------|----------------|----------|
| FIDELITY-01 | Every drift between the 3 sources is recorded | completeness | Every canonical token (15 primitives + ~20 semantic + status triads + scale groups) appears as a ledger row with a per-derivative cell; the 2 known drifts (`app.css` shadow value; `app.css` coverage gaps) are present. | `46-DISCREPANCY-LEDGER.md` |
| FIDELITY-02 | Canonical designated; derivatives documented | presence | Ledger states `cairnloop.css :root` is canonical and gives each derivative a provenance note (incl. citing the `app.css` lines 4–7 comment). | `46-DISCREPANCY-LEDGER.md` |
| FIDELITY-03 | Every fg/bg pairing scored, failures flagged | completeness + correctness | Every enumerated pairing (rows 1–29 + brand-book §7.5 pairings) has a row × {light, dark} with hex, ratio, threshold, verdict; ratios reproduce from the throwaway script; any `< threshold` carries a remediation note (D-08). | `46-CONTRAST-BASELINE.md` |

### Sampling / Re-runnability
- **Ledger completeness:** count canonical tokens vs ledger rows — they must reconcile (no token unaccounted).
- **Contrast completeness:** every pairing in the enumeration table above is scored in both themes; cross-check the
  precomputed sample ratios match the executor's script output (regression anchor for Phase 48 SC4 re-verify).
- **Forward-reuse gate:** `46-CONTRAST-BASELINE.md` must be a self-contained Markdown table (no surrounding
  narrative needed) so Phase 51 lifts it verbatim — verify by reading the table in isolation.

### Wave 0 Gaps
- None — no test infrastructure to stand up. The throwaway script (Code Examples) is the only tooling and is run-once.

## Project Constraints (from CLAUDE.md)

- **Document-only, sealed-phase respect:** Do not churn sealed code paths; this phase edits no `.ex`/`.css`/`.json`
  brand source (reinforced by D-01). The sealed brand-token gate gets **no new logic** (Phase 48's job).
- **Brand tokens over hardcoded hex:** The audit *records* hex values in the deliverable tables (that is the
  point of a discrepancy ledger / contrast table) — this is documentation, not render code, so it does not violate
  the gate. Keep raw hex confined to the two `.md` artifacts.
- **Calm, honest operator copy** does not apply to internal planning docs, but the brand-book-bound contrast table
  (Phase 51 reuse) should use plain, honest verdict language (AA / AA-large / FAIL) — no euphemism for failures.
- **Warnings-clean build / `mix test`:** N/A — no compilation, no tests added. Confirm `git status` shows only the
  two new `.md` artifacts (no stray script committed — D-07).
- **`Cairnloop.Repo` may be unavailable:** irrelevant; this phase is file-read + arithmetic only.
- **Shift-left decision policy:** All gray-area calls (table columns, pairing grouping, script lang) are explicitly
  Claude's discretion per CONTEXT; decide and proceed, no owner questions.

## Sources

### Primary (HIGH confidence)
- `priv/static/cairnloop.css` lines 18–479 — canonical token inventory (light + dark) + component pairing rules `[VERIFIED: codebase read]`
- `prompts/cairnloop.tokens.json` (full) — primitive + semantic derivative `[VERIFIED: codebase read]`
- `examples/cairnloop_example/assets/css/app.css` lines 1–199 — `@theme`/`:root` derivative + existing provenance comment + daisyUI noise `[VERIFIED: codebase read]`
- `prompts/cairnloop_brand_book.md` §7 (lines 435–532), §7.5 a11y rules + accessible pairings `[VERIFIED: codebase read]`
- `test/cairnloop/web/brand_token_gate_test.exs` — sealed gate scope (render `.ex` only, `.css` excluded) `[VERIFIED: codebase read]`
- WCAG 2.x relative-luminance formula `[CITED: w3.org/TR/WCAG22 — linked from brand book §11 line 1152]`; sample ratios `[VERIFIED: throwaway script run this session]`

### Secondary (MEDIUM confidence)
- none required

### Tertiary (LOW confidence)
- none

## Metadata

**Confidence breakdown:**
- Token inventory: HIGH — read verbatim from canonical CSS, both themes.
- Derivative cross-reference / drift: HIGH — diffed the three sources directly; the two `app.css` drifts are concrete.
- Pairing enumeration: HIGH — read off component CSS rules; A1 (Tailwind-utility completeness) is the only open edge, cheaply closed by a grep.
- WCAG method: HIGH — standardized formula, validated against precomputed ratios.

**Research date:** 2026-06-23
**Valid until:** 2026-07-23 (stable; the brand sources change only in Phase 48, which this phase precedes)
