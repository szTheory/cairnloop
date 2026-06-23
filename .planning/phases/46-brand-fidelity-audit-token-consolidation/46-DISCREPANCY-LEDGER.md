# Phase 46 — Brand Discrepancy Ledger

**Produced:** 2026-06-23
**Scope:** FIDELITY-01 (per-token drift between canonical and all derivatives) + FIDELITY-02 (canonical-source
designation + per-derivative provenance notes). Both requirements are addressed in this single file per planner
decision (the designation and drift rows are read together; Phase 48 consumes them as one worklist).

---

## Part A: Canonical-Source Designation (FIDELITY-02, D-02/D-03)

### Single canonical token source

**`priv/static/cairnloop.css` `:root` is the single canonical token source for the Cairnloop design system.**

Rationale: this file ships in the hex package, serves the live operator UI directly via
`<link rel="stylesheet" href="/cairnloop.css">`, carries all ~470 `--cl-*` references across
both light (`:root`) and dark (`[data-theme="dark"]`) theme blocks, and is what every
adopter's browser actually consumes. It is the definition of record for all `--cl-*` values.

### Derivatives — documented as expressions-of-canonical (D-03)

The three derivative sources below express a subset or summary of the canonical `:root`. None
are deleted or restructured in this phase per D-03. The drift worklist they generate is Phase 48's
job (D-01). No `--cl-*` value is changed here; every cell is an observation.

| Derivative | Format | Coverage | Existing provenance marker |
|------------|--------|----------|----------------------------|
| `prompts/cairnloop.tokens.json` | JSON — `color.primitive` (15 raw hex), `semantic_light` (14 keys), `semantic_dark` (14 keys), `typography` (3 font stacks), `voice` | Colors + type + voice only; no non-color scales (spacing, radius, shadow, z-index, motion, control, layout) by design — it is a color/type/voice derivative, not a full token dump | None (no explicit marker; implicitly derives from the canonical palette) |
| `examples/cairnloop_example/assets/css/app.css` `@theme` + `@layer base :root` + `[data-theme="dark"]` | Tailwind CSS `@theme` (15 primitive colors as `--color-cl-*` for Tailwind utilities) + `@layer base :root` (15 primitives re-declared as `--cl-color-*` + 14 core semantics + 3 typography + 3 radius + 1 shadow) + dark overrides (14 core semantics) | Partial: primitives complete; semantic partial (~14 of ~20+); many semantic tokens absent; no status triads; no spacing/z/motion/control/layout scales; non-color scales mostly absent | **EXISTING comment lines 4–7:** `"Cairnloop design system — single source of truth (shipped in the hex package at priv/static/cairnloop.css). The :root token block below mirrors it for the Tailwind @theme primitives; keep both in sync with priv/static/cairnloop.css."` This is the existing informal provenance marker — cited as-is per D-03. Additionally, `app.css` line 7 `@import "../../../../priv/static/cairnloop.css"` means at runtime canonical wins (the Tailwind `:root` re-declaration is overridden by the imported canonical). |
| `prompts/cairnloop_brand_book.md` §7 prose | Markdown — §7.2 primitive table (15 rows), §7.4 semantic table (14 rows, light+dark), §7.5 accessible-pairings rules | Brand-book color summary; omits non-color scales, status triads, and derivative-specific tokens. Authored as the text *seed* of the design system, not a machine-readable derivative | None (prose seed; no sync comment) |

**NOTHING is deleted or restructured in this phase (D-03).** The provenance notes above are recorded in this
document for Phase 48 to consume; Phase 48 is the right place to edit derivatives to eliminate drift.

---

## Part B: Discrepancy Ledger (FIDELITY-01, D-01)

### Legend

- **Canonical value** — resolved hex from `priv/static/cairnloop.css` `:root` (light) or `[data-theme="dark"]` (dark).
- **tokens.json** — value from `color.primitive` or `semantic_light`/`semantic_dark`.
- **app.css** — value from `@layer base :root` / `[data-theme="dark"]` block.
- **brand-book §7** — value from §7.2 primitive table or §7.4 semantic table.
- **—** = token not expressed by that derivative (COVERAGE gap, not a value drift).
- **Drift?** = `CLEAN` | `VALUE DRIFT` | `COVERAGE GAP` | `ALIAS` | `OPEN QUESTION`

**This drift list is Phase 48's worklist.** Phase 48 SC2 requires a diff confirming all derivatives match canonical
exactly after the token evolution is applied. Pre-evolution drift is recorded here and deferred per D-01.

---

### Layer 1: Primitives (15 tokens)

Both `tokens.json` and `app.css @layer base` re-declare all 15 primitives; brand-book §7.2 lists them as a table.
`app.css @theme` block also re-expresses them as `--color-cl-*` for Tailwind utilities.

| Token | Canonical hex | tokens.json | app.css :root | brand-book §7.2 | Drift? |
|-------|--------------|-------------|---------------|-----------------|--------|
| `--cl-color-basalt` | `#18211F` | `#18211F` | `#18211F` | `#18211F` | CLEAN |
| `--cl-color-moss-ink` | `#263A2E` | `#263A2E` | `#263A2E` | `#263A2E` | CLEAN |
| `--cl-color-trailpaper` | `#F5F0E6` | `#F5F0E6` | `#F5F0E6` | `#F5F0E6` | CLEAN |
| `--cl-color-warm-stone` | `#FBF7EE` | `#FBF7EE` | `#FBF7EE` | `#FBF7EE` | CLEAN |
| `--cl-color-granite` | `#D8D0BF` | `#D8D0BF` | `#D8D0BF` | `#D8D0BF` | CLEAN |
| `--cl-color-slate-lichen` | `#677066` | `#677066` | `#677066` | `#677066` | CLEAN |
| `--cl-color-path-copper` | `#A94F30` | `#A94F30` | `#A94F30` | `#A94F30` | CLEAN |
| `--cl-color-copper-glow` | `#C46A3A` | `#C46A3A` | `#C46A3A` | `#C46A3A` | CLEAN |
| `--cl-color-lichen` | `#A8B56C` | `#A8B56C` | `#A8B56C` | `#A8B56C` | CLEAN |
| `--cl-color-deep-lichen` | `#4A6238` | `#4A6238` | `#4A6238` | `#4A6238` | CLEAN |
| `--cl-color-glacier-mist` | `#DDE8E3` | `#DDE8E3` | `#DDE8E3` | `#DDE8E3` | CLEAN |
| `--cl-color-waypoint-blue` | `#3F6F80` | `#3F6F80` | `#3F6F80` | `#3F6F80` | CLEAN |
| `--cl-color-heather` | `#7A5D78` | `#7A5D78` | `#7A5D78` | `#7A5D78` | CLEAN |
| `--cl-color-ember` | `#8B531E` | `#8B531E` | `#8B531E` | `#8B531E` | CLEAN |
| `--cl-color-fault-clay` | `#B54C36` | `#B54C36` | `#B54C36` | `#B54C36` | CLEAN |

**Primitives verdict: ALL 15 are CLEAN across all three derivatives.** tokens.json `color.primitive` matches exactly.
app.css `@theme` (`--color-cl-*`) and `@layer base :root` (`--cl-color-*`) match exactly. Brand-book §7.2 matches exactly.

---

### Layer 2: Semantic Tokens — Light Theme (`:root`)

| Token | Canonical light | tokens.json `semantic_light` | app.css `@layer base :root` | brand-book §7.4 light | Drift? |
|-------|----------------|------------------------------|-----------------------------|-----------------------|--------|
| `--cl-bg` | `#F5F0E6` (via trailpaper) | `#F5F0E6` | `#F5F0E6` (via `--cl-color-trailpaper`) | `#F5F0E6` | CLEAN |
| `--cl-surface` | `#FBF7EE` (via warm-stone) | `#FBF7EE` | `#FBF7EE` (via `--cl-color-warm-stone`) | `#FBF7EE` | CLEAN |
| `--cl-surface-raised` | `#FFFFFF` | `#FFFFFF` | `#FFFFFF` | `#FFFFFF` | CLEAN |
| `--cl-surface-sunken` | `#EFE9DC` | — | — | — | COVERAGE GAP (absent from both tokens.json and app.css; app.css uses it in rules but doesn't define it) |
| `--cl-text` | `#18211F` (via basalt) | `#18211F` | `#18211F` (via `--cl-color-basalt`) | `#18211F` | CLEAN |
| `--cl-text-muted` | `#677066` (via slate-lichen) | `#677066` | `#677066` (via `--cl-color-slate-lichen`) | `#677066` | CLEAN |
| `--cl-text-soft` | `#8A8C82` | — | — | — | COVERAGE GAP (absent from both derivatives) |
| `--cl-border` | `#D8D0BF` (via granite) | `#D8D0BF` | `#D8D0BF` (via `--cl-color-granite`) | `#D8D0BF` | CLEAN |
| `--cl-border-strong` | `#BFB6A2` | — | — | — | COVERAGE GAP (absent from all three derivatives) |
| `--cl-primary` | `#A94F30` (via path-copper) | `#A94F30` | `#A94F30` (via `--cl-color-path-copper`) | `#A94F30` | CLEAN |
| `--cl-primary-hover` | `#97462A` | — | — | — | COVERAGE GAP (absent from all three derivatives) |
| `--cl-primary-text` | `#FFFFFF` | `#FFFFFF` | `#FFFFFF` | `#FFFFFF` | CLEAN |
| `--cl-on-primary` | `var(--cl-primary-text)` = `#FFFFFF` (alias) | — | `var(--cl-primary-text)` (present in app.css) | — | ALIAS — sealed render code alias; app.css carries it; tokens.json and brand book omit it (expected) |
| `--cl-success` | `#4A6238` (via deep-lichen) | `#4A6238` | `#4A6238` (via `--cl-color-deep-lichen`) | `#4A6238` | CLEAN |
| `--cl-info` | `#3F6F80` (via waypoint-blue) | `#3F6F80` | `#3F6F80` (via `--cl-color-waypoint-blue`) | `#3F6F80` | CLEAN |
| `--cl-ai` | `#7A5D78` (via heather) | `#7A5D78` | `#7A5D78` (via `--cl-color-heather`) | `#7A5D78` | CLEAN |
| `--cl-warning` | `#8B531E` (via ember) | `#8B531E` | `#8B531E` (via `--cl-color-ember`) | `#8B531E` | CLEAN |
| `--cl-danger` | `#B54C36` (via fault-clay) | `#B54C36` | `#B54C36` (via `--cl-color-fault-clay`) | `#B54C36` | CLEAN |
| `--cl-focus` | `#A94F30` (via path-copper) | `#A94F30` | `#A94F30` (via `--cl-color-path-copper`) | `#A94F30` | CLEAN |
| `--cl-overlay` | `rgba(24, 33, 31, 0.44)` | — | — | — | COVERAGE GAP (absent from all three derivatives) |

**Light semantic verdict:** 14 of 20 semantic tokens CLEAN; 5 COVERAGE GAP (surface-sunken, text-soft, border-strong, primary-hover, overlay); 1 ALIAS (on-primary, expected).

---

### Layer 3: Semantic Tokens — Dark Theme (`[data-theme="dark"]`)

app.css carries a partial dark block inside `@layer base`. tokens.json `semantic_dark` covers 14 keys. Brand book §7.4 covers 14.

| Token | Canonical dark | tokens.json `semantic_dark` | app.css dark block | brand-book §7.4 dark | Drift? |
|-------|---------------|------------------------------|---------------------|----------------------|--------|
| `--cl-bg` | `#101614` | `#101614` | `#101614` | `#101614` | CLEAN |
| `--cl-surface` | `#18211F` | `#18211F` | `#18211F` | `#18211F` | CLEAN |
| `--cl-surface-raised` | `#1F2C28` | `#1F2C28` | `#1F2C28` | `#1F2C28` | CLEAN |
| `--cl-surface-sunken` | `#0C110F` | — | — | — | COVERAGE GAP |
| `--cl-text` | `#F5F0E6` | `#F5F0E6` | `#F5F0E6` | `#F5F0E6` | CLEAN |
| `--cl-text-muted` | `#B7C0B2` | `#B7C0B2` | `#B7C0B2` | `#B7C0B2` | CLEAN |
| `--cl-text-soft` | `#8A9488` | — | — | — | COVERAGE GAP |
| `--cl-border` | `#34443D` | `#34443D` | `#34443D` | `#34443D` | CLEAN |
| `--cl-border-strong` | `#44564D` | — | — | — | COVERAGE GAP |
| `--cl-primary` | `#D98A4A` | `#D98A4A` | `#D98A4A` | `#D98A4A` | CLEAN |
| `--cl-primary-hover` | `#E69A5C` | — | — | — | COVERAGE GAP |
| `--cl-primary-text` | `#18211F` | `#18211F` | `#18211F` | `#18211F` | CLEAN |
| `--cl-success` | `#A8B56C` | `#A8B56C` | `#A8B56C` | `#A8B56C` | CLEAN |
| `--cl-info` | `#9EC3CF` | `#9EC3CF` | `#9EC3CF` | `#9EC3CF` | CLEAN |
| `--cl-ai` | `#C9A7C6` | `#C9A7C6` | `#C9A7C6` | `#C9A7C6` | CLEAN |
| `--cl-warning` | `#D98A4A` | `#D98A4A` | `#D98A4A` | `#D98A4A` | OPEN QUESTION — `--cl-warning` dark == `--cl-primary` dark (both `#D98A4A`). Research A3 flags this: intentional palette choice or accidental alias? Do not assume either way; surface to Phase 47 for explicit sign-off during palette exploration. |
| `--cl-danger` | `#E18C7D` | `#E18C7D` | `#E18C7D` | `#E18C7D` | CLEAN |
| `--cl-focus` | `#D98A4A` | `#D98A4A` | `#D98A4A` | `#D98A4A` | CLEAN |
| `--cl-overlay` | `rgba(0, 0, 0, 0.58)` | — | — | — | COVERAGE GAP |

**Dark semantic verdict:** 13 CLEAN; 5 COVERAGE GAP (surface-sunken, text-soft, border-strong, primary-hover, overlay); 1 OPEN QUESTION (warning == primary in dark).

---

### Layer 4: Status Triads (6 groups × 3 tokens each = 18 light + 18 dark = 36 tokens)

**Status triads are entirely absent from both `tokens.json` and `app.css` `@layer base` derivative blocks.**
The brand book does not enumerate status triads in §7.2/§7.4. All 36 tokens are COVERAGE GAP in all three derivatives.

Light theme status triad values (canonical source, for Phase 48 reference):

| Group | `*-surface` | `*-border` | `*-text` |
|-------|-------------|------------|---------|
| `success` | `#EDF1E2` | `#C9D3A6` | `#3C5430` |
| `info` | `#DDE8E3` | `#B7CDD4` | `#335A68` |
| `warning` | `#F6ECDD` | `#E3C9A0` | `#7A4818` |
| `danger` | `#F6E3DE` | `#E3B6AC` | `#9A3E2C` |
| `ai` | `#ECE4EB` | `#CDB6CB` | `#5F4A5D` |
| `neutral` | `#EFEADF` | `var(--cl-border)` = `#D8D0BF` | `var(--cl-text-muted)` = `#677066` |

Dark theme status triad values (canonical source, for Phase 48 reference):

| Group | `*-surface` | `*-border` | `*-text` |
|-------|-------------|------------|---------|
| `success` | `#1E2A1C` | `#38492E` | `#BFD194` |
| `info` | `#16252A` | `#2E4750` | `#AFD3DE` |
| `warning` | `#2A2014` | `#4A3A22` | `#E8B488` |
| `danger` | `#2A1A16` | `#4A302A` | `#ECA99C` |
| `ai` | `#241E29` | `#433A48` | `#D6BCD3` |
| `neutral` | `#1C2622` | `var(--cl-border)` = `#34443D` | `var(--cl-text-muted)` = `#B7C0B2` |

Legacy aliases (canonical only; no derivative carries them):
- `--cl-warning-bg` → `var(--cl-warning-surface)` — alias for sealed render code; both light and dark
- `--cl-danger-soft` → `var(--cl-danger-surface)` — alias for sealed render code; both light and dark

These are aliases, not drift.

---

### Layer 5: Non-Color Scales (typography, spacing, radius, shadow, z-index, layout, motion, controls, focus ring)

tokens.json is a **color + type + voice derivative by design** — absent spacing/z/motion/control/layout tokens are a
scope note, not value drift. The brand book §7 covers only color. app.css carries a small radius/shadow subset for its
`@layer base` block. The table below notes which derivative covers which scale (not "drift" for absent ones).

| Scale group | Canonical tokens | tokens.json | app.css @layer base | brand-book | Notes |
|-------------|------------------|-------------|---------------------|-----------|-------|
| Typography (`--cl-font-*`, `--cl-leading-*`, `--cl-weight-*`) | 14 tokens (lines 70–84) | `typography.sans/display/mono` — 3 font-stack strings (no size/leading/weight) | 3 font stacks (sans/display/mono), identical to canonical | §8 prose (no hex; out of §7 scope) | PARTIAL in tokens.json; app.css carries only font stacks |
| Spacing (`--cl-space-0..11`, `--cl-space-gutter/stack/inline`) | 15 tokens (lines 87–101) | — | — | — | Not in any derivative (scope: color/type/voice derivatives) |
| Radius (`--cl-radius-xs/sm/md/lg/full`) | 5 tokens (lines 104–108) | — | `--cl-radius-sm: 6px`, `--cl-radius-md: 10px`, `--cl-radius-lg: 14px` (3 of 5) | — | app.css covers 3 of 5; xs and full absent from app.css |
| Shadow (`--cl-shadow-1..4`, `--cl-shadow-raised/shadow/shadow-card/shadow-overlay/shadow-modal`) | 9 tokens (lines 111–119) | — | `--cl-shadow-raised: 0 1px 2px rgba(24, 33, 31, 0.08), 0 8px 24px rgba(24, 33, 31, 0.06)` (1 of 9) | — | **VALUE DRIFT on `--cl-shadow-raised`**: app.css value `0 1px 2px rgba(24,33,31,0.08), 0 8px 24px rgba(24,33,31,0.06)` differs from canonical `var(--cl-shadow-1)` = `0 1px 2px rgba(24,33,31,0.06)` (single-layer, lower opacity 0.06; no second shadow layer). At runtime canonical wins via `@import` (line 7). **Phase 48 worklist item #1.** |
| Z-index (`--cl-z-base/dropdown/sticky/overlay/modal/popover/toast`) | 7 tokens (lines 122–128) | — | — | — | Not in any derivative |
| Controls (`--cl-control-h-sm/md/lg`, `--cl-control-px-sm/md/lg`) | 6 tokens (lines 131–133) | — | — | — | Not in any derivative |
| Layout (`--cl-content-max`, `--cl-rail-width`, `--cl-page-gutter`) | 3 tokens (lines 138–140) | — | — | — | Not in any derivative |
| Motion (`--cl-dur-*`, `--cl-ease-*`, `--cl-stagger`) | 12 tokens (lines 143–153) | — | — | — | Not in any derivative |
| Focus ring (`--cl-focus-ring`) | 1 token (line 156) | — | — | — | Not in any derivative |

---

## Confirmed Drift Summary (Phase 48 Worklist)

Two concrete drifts found (per D-01, documented-only; Phase 48 must zero them out):

### Drift Item 1 — VALUE DRIFT: `--cl-shadow-raised` in `app.css`

| Property | Value |
|----------|-------|
| **File** | `examples/cairnloop_example/assets/css/app.css` line 77 |
| **app.css value** | `0 1px 2px rgba(24, 33, 31, 0.08), 0 8px 24px rgba(24, 33, 31, 0.06)` |
| **Canonical value** | `var(--cl-shadow-1)` = `0 1px 2px rgba(24, 33, 31, 0.06)` (single layer, lower base opacity) |
| **Runtime impact** | At runtime canonical wins (app.css `@import` at line 7 loads canonical which overrides this). No user-visible bug today. |
| **Phase 48 action** | Replace app.css `--cl-shadow-raised` with `var(--cl-shadow-1)` to match canonical |

### Drift Item 2 — COVERAGE GAP: `app.css` omits the following canonical tokens

app.css `@layer base :root` does not define these tokens, which means Tailwind utilities and local styles cannot
reference them without the canonical import. Since app.css `@import`s canonical at line 7, the tokens resolve at
runtime — but the local re-declaration is incomplete. Phase 48 must decide: extend the app.css mirror, or remove
the partial mirror entirely and rely purely on the import.

Absent semantic tokens in app.css:
`--cl-surface-sunken`, `--cl-text-soft`, `--cl-border-strong`, `--cl-primary-hover`, `--cl-overlay`

Absent from all derivatives (tokens.json + app.css + brand-book):
- All 6 status triads × 3 tokens = 18 light + 18 dark = 36 status-triad tokens
- All spacing, z-index, controls, layout, motion, focus-ring tokens
- `--cl-radius-xs`, `--cl-radius-full` (in canonical, absent from app.css)
- `--cl-shadow-1`, `--cl-shadow-2`, `--cl-shadow-3`, `--cl-shadow-4`, `--cl-shadow-card`, `--cl-shadow-overlay`, `--cl-shadow-modal` (app.css only carries the one drifted `--cl-shadow-raised`)

### Open Question for Phase 47 (Research A3)

`--cl-warning` dark == `--cl-primary` dark (both `#D98A4A`). Both `tokens.json` and `app.css` reproduce this
equality from canonical, so it is consistently expressed across derivatives. Whether this is intentional (orange
route-marker color doing double duty as the warning accent in dark mode) or an oversight is a palette-level
question for Phase 47 to answer explicitly. Record it in the Phase 47 plan as a sign-off item.

### tokens.json clean verdict

tokens.json `color.primitive` (15 keys) and `semantic_light`/`semantic_dark` (14 keys each) are CLEAN — every
expressed value matches canonical. tokens.json does not cover status triads or non-color scales by design (it is a
color/type/voice derivative). No value drift found in tokens.json.

---

## Out-of-scope Exclusion

`examples/cairnloop_example/assets/css/app.css` also defines two daisyUI `@plugin` theme blocks (lines 110–186)
using `oklch(...)` Phoenix/Elixir-inspired colors. These are the example app's daisyUI scaffolding noise — they
are not `--cl-*` brand tokens and are explicitly excluded from this ledger.

---

## Phase Hygiene Attestation

**Appended by Task 3 — 2026-06-23**

### Throwaway script disposal (D-07)

The WCAG relative-luminance Python script was written exclusively to the session scratchpad:
`/private/tmp/claude-501/-Users-jon-projects-cairnloop/51946c5d-70cc-47db-b8ab-0d781cf35c24/scratchpad/wcag_contrast.py`

It was used to compute all contrast ratios for `46-CONTRAST-BASELINE.md`, then deleted before any commit.

Confirmation: `git ls-files --error-unmatch '*luminance*'` → **no match** (not tracked anywhere in repo tree)

### Brand source files — zero mutation (D-01)

`git status --porcelain` at Task 3 completion showed the following relevant lines:

```
 M .planning/STATE.md   ← GSD orchestrator bookkeeping only
```

The following files show **zero modifications** (clean):
- `priv/static/cairnloop.css`
- `prompts/cairnloop.tokens.json`
- `examples/cairnloop_example/assets/css/app.css`
- `prompts/cairnloop_brand_book.md`
- `mix.exs`

No `--cl-*` value was changed. No derivative file was edited. No script was committed. No `mix.exs` change.
No new mix/npm/pip dependency was introduced. D-01 and D-07 satisfied.

### Phase artifacts produced (the only repo additions in this phase)

- `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-DISCREPANCY-LEDGER.md` (this file)
- `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md`
- `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-01-SUMMARY.md` (metadata)
