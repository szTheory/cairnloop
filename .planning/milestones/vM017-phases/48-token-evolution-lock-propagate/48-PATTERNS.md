# Phase 48: Token Evolution: Lock & Propagate - Pattern Map

**Mapped:** 2026-06-24
**Files analyzed:** 6
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `priv/static/cairnloop.css` | config | transform | `priv/static/cairnloop.css` | exact |
| `examples/cairnloop_example/assets/css/app.css` | config | transform | `examples/cairnloop_example/assets/css/app.css` | exact |
| `prompts/cairnloop.tokens.json` | config | transform | `prompts/cairnloop.tokens.json` | exact |
| `test/cairnloop/web/brand_token_gate_test.exs` | test | batch | `test/cairnloop/web/brand_token_gate_test.exs` | exact |
| `test/cairnloop/web/token_drift_test.exs` | test | batch | `test/cairnloop/web/brand_token_gate_test.exs` + `test/cairnloop/web/cairnloop_css_test.exs` | role-match |
| `.planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md` | config | transform | `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md` | role-match |

## Pattern Assignments

### `priv/static/cairnloop.css` (config, transform)

**Analog:** `priv/static/cairnloop.css`

**Canonical token header and source-of-truth pattern** (lines 1-18):
```css
/* ============================================================================
   Cairnloop Design System — cairnloop.css  (v1)
   ----------------------------------------------------------------------------
   Shipped, self-contained operator-UI stylesheet. No Tailwind / daisyUI needed.
   Adopters include this one file and (optionally) override `--cl-*` tokens to
   theme. All `.cl-*` rules read semantic tokens with a baked fallback, so the
   file renders correctly even before the host defines any token.

   Layers:  tokens (:root) → dark theme → reduced-motion → base → components.
   ============================================================================ */

:root {
```

**Primitive + semantic token pattern** (lines 19-56):
```css
/* ---- Primitive colors (raw, context-free) ------------------------------ */
--cl-color-basalt:        #18211F;
--cl-color-trailpaper:    #F5F0E6;
--cl-color-path-copper:   #A94F30;
--cl-color-fault-clay:    #B54C36;

/* ---- Semantic colors (intent; reference primitives) -------------------- */
--cl-bg:             var(--cl-color-trailpaper);
--cl-surface:        var(--cl-color-warm-stone);
--cl-text:           var(--cl-color-basalt);
--cl-text-muted:     var(--cl-color-slate-lichen);
--cl-primary:        var(--cl-color-path-copper);
--cl-primary-hover:  #97462A;
--cl-primary-text:   #FFFFFF;
--cl-on-primary:     var(--cl-primary-text);   /* alias for sealed render code */
--cl-danger:         var(--cl-color-fault-clay);
--cl-focus:          var(--cl-color-path-copper);
```

**Status triad pattern** (lines 58-67):
```css
/* Status triplets (surface / border / text) — for badges, banners, chips.
   Text step is darker than fill so text-on-surface keeps 4.5:1 contrast. */
--cl-success-surface: #EDF1E2;  --cl-success-border: #C9D3A6;  --cl-success-text: #3C5430;
--cl-info-surface:    #DDE8E3;  --cl-info-border:    #B7CDD4;  --cl-info-text:    #335A68;
--cl-warning-surface: #F6ECDD;  --cl-warning-border: #E3C9A0;  --cl-warning-text: #7A4818;
--cl-danger-surface:  #F6E3DE;  --cl-danger-border:  #E3B6AC;  --cl-danger-text:  #9A3E2C;
--cl-neutral-surface: #EFEADF;  --cl-neutral-border: var(--cl-border);  --cl-neutral-text: var(--cl-text-muted);
```

**Dark override pattern** (lines 159-194):
```css
/* ---- Dark theme: override semantic tokens only ------------------------- */
[data-theme="dark"] {
  --cl-bg:             #101614;
  --cl-surface:        #18211F;
  --cl-surface-raised: #1F2C28;
  --cl-text:           #F5F0E6;
  --cl-text-muted:     #B7C0B2;
  --cl-primary:        #D98A4A;
  --cl-primary-hover:  #E69A5C;
  --cl-primary-text:   #18211F;
  --cl-danger:         #E18C7D;
  --cl-focus:          #D98A4A;

  --cl-danger-surface:  #2A1A16; --cl-danger-border:  #4A302A; --cl-danger-text:  #ECA99C;
  --cl-neutral-surface: #1C2622; --cl-neutral-border: var(--cl-border); --cl-neutral-text: var(--cl-text-muted);

  --cl-shadow-1: 0 1px 2px rgba(0, 0, 0, 0.30);
}
```

**Component pairing pattern to preserve while changing tokens** (lines 313-323, 343-356):
```css
.cl-button--primary {
  background: var(--cl-primary, #A94F30); color: var(--cl-primary-text, #FFFFFF);
  border-color: transparent;
}
.cl-button--primary:hover { background: var(--cl-primary-hover, #97462A); border-color: transparent; }
.cl-button--danger {
  background: var(--cl-danger, #B54C36); color: #FFFFFF; border-color: transparent;
}
.cl-button--danger:hover { background: #9A3E2C; }

.cl-chip {
  border: 1px solid var(--cl-neutral-border); background: var(--cl-neutral-surface); color: var(--cl-neutral-text);
}
.cl-chip--danger  { background: var(--cl-danger-surface);  border-color: var(--cl-danger-border);  color: var(--cl-danger-text); }
```

**Apply to Phase 48:** Change values in `:root` first. Preserve existing `--cl-*` names. Add only needed semantic tokens, likely `--cl-danger-button-text`, then wire `.cl-button--danger` to the token so dark danger can pass AA without reopening component behavior.

---

### `examples/cairnloop_example/assets/css/app.css` (config, transform)

**Analog:** `examples/cairnloop_example/assets/css/app.css`

**Provenance and import pattern** (lines 4-9):
```css
/* Cairnloop design system — single source of truth (shipped in the hex package
   at priv/static/cairnloop.css). The :root token block below mirrors it for the
   Tailwind @theme primitives; keep both in sync with priv/static/cairnloop.css. */
@import "../../../../priv/static/cairnloop.css";

@import "tailwindcss" source(none);
```

**Tailwind primitive mirror pattern** (lines 11-28):
```css
@theme {
  /* 15 primitive color tokens — generates bg-cl-*, text-cl-*, border-cl-*, etc. */
  --color-cl-basalt: #18211F;
  --color-cl-trailpaper: #F5F0E6;
  --color-cl-path-copper: #A94F30;
  --color-cl-fault-clay: #B54C36;
}
```

**Local `--cl-*` mirror pattern** (lines 30-78):
```css
@layer base {
  :root {
    /* Primitives (mirror @theme — so var(--cl-color-*) refs resolve cleanly) */
    --cl-color-basalt: #18211F;
    --cl-color-trailpaper: #F5F0E6;
    --cl-color-path-copper: #A94F30;
    --cl-color-fault-clay: #B54C36;

    /* Semantic tokens — resolve to primitives */
    --cl-bg: var(--cl-color-trailpaper);
    --cl-surface: var(--cl-color-warm-stone);
    --cl-text: var(--cl-color-basalt);
    --cl-text-muted: var(--cl-color-slate-lichen);
    --cl-primary: var(--cl-color-path-copper);
    --cl-primary-text: #FFFFFF;
    --cl-danger: var(--cl-color-fault-clay);
    --cl-focus: var(--cl-color-path-copper);

    /* Alias for sealed render code (Pitfall 3 — additive, zero churn) */
    --cl-on-primary: var(--cl-primary-text);

    --cl-shadow-raised: 0 1px 2px rgba(24, 33, 31, 0.08), 0 8px 24px rgba(24, 33, 31, 0.06);
  }
```

**Dark mirror pattern** (lines 80-96):
```css
/* D-07 — dark-theme overrides immediately follow :root in the same @layer base */
[data-theme="dark"] {
  --cl-bg: #101614;
  --cl-surface: #18211F;
  --cl-surface-raised: #1F2C28;
  --cl-text: #F5F0E6;
  --cl-text-muted: #B7C0B2;
  --cl-primary: #D98A4A;
  --cl-primary-text: #18211F;
  --cl-danger: #E18C7D;
  --cl-focus: #D98A4A;
}
```

**Apply to Phase 48:** Mirror only expressed values from canonical. Update `@theme` primitives and the `@layer base` light/dark semantics after canonical CSS changes. Correct known drift by replacing `--cl-shadow-raised` with `var(--cl-shadow-1)` per the Phase 46 ledger.

---

### `prompts/cairnloop.tokens.json` (config, transform)

**Analog:** `prompts/cairnloop.tokens.json`

**Primitive JSON shape** (lines 9-70):
```json
"color": {
  "primitive": {
    "basalt": {
      "value": "#18211F",
      "description": "core text / dark surface"
    },
    "trailpaper": {
      "value": "#F5F0E6",
      "description": "main canvas"
    },
    "path_copper": {
      "value": "#A94F30",
      "description": "primary action / active route"
    },
    "fault_clay": {
      "value": "#B54C36",
      "description": "danger text / blocked policy"
    }
  }
}
```

**Semantic light/dark shape** (lines 72-103):
```json
"semantic_light": {
  "bg": "#F5F0E6",
  "surface": "#FBF7EE",
  "surface_raised": "#FFFFFF",
  "text": "#18211F",
  "text_muted": "#677066",
  "primary": "#A94F30",
  "primary_text": "#FFFFFF",
  "danger": "#B54C36",
  "focus": "#A94F30"
},
"semantic_dark": {
  "bg": "#101614",
  "surface": "#18211F",
  "surface_raised": "#1F2C28",
  "text": "#F5F0E6",
  "text_muted": "#B7C0B2",
  "primary": "#D98A4A",
  "primary_text": "#18211F",
  "danger": "#E18C7D",
  "focus": "#D98A4A"
}
```

**Typography mirror pattern** (lines 105-109):
```json
"typography": {
  "sans": "Atkinson Hyperlegible Next, Atkinson Hyperlegible, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif",
  "display": "Fraunces, Atkinson Hyperlegible Next, Georgia, serif",
  "mono": "Martian Mono, Atkinson Hyperlegible Mono, ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace"
}
```

**Apply to Phase 48:** Keep this as a color/type/voice derivative, not a full token dump. Update existing expressed primitive and semantic values to match resolved canonical values exactly. Additive semantic keys are only needed if the new canonical token is a real downstream prompt-facing semantic, not merely a CSS implementation helper.

---

### `test/cairnloop/web/brand_token_gate_test.exs` (test, batch)

**Analog:** `test/cairnloop/web/brand_token_gate_test.exs`

**Imports / module pattern** (lines 1-23):
```elixir
defmodule Cairnloop.Web.BrandTokenGateTest do
  @moduledoc """
  Brand-token CI gate — BRAND-04 (Phase 29 D-10) + GATE-01 (Phase 40).

  This test is DB-free (pure File.read!/string scan).
  # REPO-UNAVAILABLE: no assertions require a Postgres round-trip.
  """

  use ExUnit.Case, async: true
```

**Path expansion pattern** (lines 40-47):
```elixir
@web_dir Path.expand("../../../lib/cairnloop/web", __DIR__)
@example_live_dir Path.expand(
                    "../../../examples/cairnloop_example/lib/cairnloop_example_web/live",
                    __DIR__
                  )
```

**Batch scan pattern** (lines 164-192):
```elixir
test "no hex-fallback strings remain in lib/cairnloop/web/ or examples/cairnloop_example/lib/cairnloop_example_web/live/ (BRAND-04, Phase 29 D-10 closure)" do
  files =
    Path.wildcard(Path.join(@web_dir, "**/*.ex")) ++
      Path.wildcard(Path.join(@example_live_dir, "**/*.ex"))

  refute files == [],
         "Expected to find .ex files in both #{@web_dir} and #{@example_live_dir}; got empty list — check path resolution"

  violations =
    for file <- files,
        {line, line_no} <- file |> File.read!() |> String.split("\n") |> Enum.with_index(1),
        Regex.match?(@hex_fallback_pattern, line) do
      {Path.basename(file), line_no, String.trim(line)}
    end

  assert violations == [],
         """
         BRAND-04 contract violated — hex fallbacks found in sealed render files.

         Canonical token source: priv/static/cairnloop.css

         Violations:
         #{Enum.map_join(violations, "\n", fn {file, line_no, line} -> "  #{file}:#{line_no} — #{line}" end)}
         """
end
```

**Apply to Phase 48:** This existing file should remain focused on render-source hardcoded colors. If touched, keep it DB-free, async, and scoped to `.ex` render files; do not expand it into CSS drift checks. Put CSS/token assertions in `token_drift_test.exs`.

---

### `test/cairnloop/web/token_drift_test.exs` (test, batch)

**Analogs:** `test/cairnloop/web/brand_token_gate_test.exs`, `test/cairnloop/web/cairnloop_css_test.exs`

**Pure file setup pattern** from `cairnloop_css_test.exs` (lines 1-15):
```elixir
defmodule Cairnloop.Web.CairnloopCssTest do
  @moduledoc """
  Machine-verification that the required CSS literals are present in `priv/static/cairnloop.css`.

  This is a pure file-content test — no DB, no Repo, no `# REPO-UNAVAILABLE` marker needed.
  """
  use ExUnit.Case, async: true

  setup_all do
    css_path = Path.join(File.cwd!(), "priv/static/cairnloop.css")
    css = File.read!(css_path)
    {:ok, css: css}
  end
```

**Describe/test organization pattern** from `cairnloop_css_test.exs` (lines 17-29, 69-83):
```elixir
describe "layout tokens (D-09 / UIC-05)" do
  test "defines --cl-content-max", %{css: css} do
    assert css =~ "--cl-content-max"
  end
end

describe "responsive normalization (D3 / RESP-01)" do
  test "no max-width width media conditions remain (mobile-first)", %{css: css} do
    refute css =~ ~r/@media\s*\(\s*max-width/, "all media queries must be min-width (mobile-first)"
  end
end
```

**Violation reporting pattern** from `brand_token_gate_test.exs` (lines 203-227):
```elixir
all_violations =
  for file <- files do
    content = File.read!(file)
    lines = String.split(content, "\n")
    lines_with_index = Enum.with_index(lines, 1)
    allowed = allowed_line_numbers(lines)
    file_violations = collect_violations(lines_with_index, allowed)

    Enum.map(file_violations, fn {line_no, trimmed} ->
      {Path.relative_to(file, File.cwd!()), line_no, trimmed}
    end)
  end
  |> List.flatten()

assert all_violations == [],
       """
       GATE-01 violated — hardcoded color literals found in render files.

       Violations:
       #{Enum.map_join(all_violations, "\n", fn {file, line_no, line} -> "  #{file}:#{line_no} — #{line}" end)}
       """
```

**Recommended core test shape:** Use pure helpers in the test file:
```elixir
@canonical_css Path.join(File.cwd!(), "priv/static/cairnloop.css")
@example_css Path.join(File.cwd!(), "examples/cairnloop_example/assets/css/app.css")
@tokens_json Path.join(File.cwd!(), "prompts/cairnloop.tokens.json")

setup_all do
  {:ok,
   canonical_css: File.read!(@canonical_css),
   example_css: File.read!(@example_css),
   tokens: @tokens_json |> File.read!() |> Jason.decode!()}
end
```

**Apply to Phase 48:** Cover three gates in this new test: no existing `--cl-*` token names were removed, expressed derivative values in `app.css` and `tokens.json` match canonical, and the Phase 46 contrast rows recompute to passing or documented decorative status. Keep it async and DB-free.

---

### `.planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md` (config, transform)

**Analog:** `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md`

**Document header pattern** (lines 1-7):
```markdown
# Phase 46 — WCAG-AA Contrast Baseline

**Produced:** 2026-06-23
**Method:** WCAG 2.x relative-luminance algorithm (w3.org/TR/WCAG22). Ratios computed with a throwaway
Python 3 stdlib script (D-07) — run once, results pasted here, script deleted before commit.
**Scope:** Every shipped fg/bg pairing from `cairnloop.css` component rules...
**Thresholds (D-06):** 4.5:1 normal text · 3.0:1 large text...
```

**Matrix table pattern** (lines 23-25, 82-84):
```markdown
### Text Pairings (4.5:1 threshold)

| # | Pairing | FG token | FG hex (L/D) | BG token | BG hex (L/D) | Theme | Ratio | Threshold | Verdict |

### Non-Text UI Component Pairings (3.0:1 threshold — borders, focus rings)

| # | Pairing | FG token | FG hex | BG token | BG hex | Theme | Ratio | Threshold | Verdict |
```

**Failure-remediation pattern** (lines 199-229, 244-252):
```markdown
**Row 13 Dark — white `#FFFFFF` on `--cl-danger #E18C7D` = 2.55:1**
...
**Row 14 Light — `--cl-text-muted #677066` on `--cl-surface-sunken #EFE9DC` = 4.25:1**
...
**Row 22 Light — `--cl-neutral-text (text-muted) #677066` on `--cl-neutral-surface #EFEADF` = 4.28:1**
...
**Rows 24/25 — Quiet and strong borders on canvas/surface (1.35–2.10:1)**
...
**Rows 28a–e (light and dark) — Status chip borders on chip surfaces (1.32–1.60:1)**
```

**Summary pattern** (lines 259-280):
```markdown
## Summary of Findings

| Category | Count | Status |
|----------|-------|--------|

**Three real failures requiring resolution in Phase 47/48:**
1. Row 13 Dark — white on dark danger (`#E18C7D`) = 2.55:1 (below even 3.0)
2. Row 14 Light — text-muted on surface-sunken = 4.25:1 (ghost button hover / nav-link hover)
3. Row 22 Light — neutral chip text on neutral surface = 4.28:1 (12px chip label)

**Border failures (12 rows):** Likely decorative under WCAG 1.4.11. Must be explicitly classified
```

**Apply to Phase 48:** Reuse the same row IDs and threshold columns so Phase 46 and Phase 48 can be compared mechanically. Update values, ratios, verdicts, and remediation notes. Include exact required labels from the UI spec: `Selected palette: Refined`, `Selected type: current stack`, `Canonical source: priv/static/cairnloop.css :root`, `Derivative status: zero drift`, `Contrast status: AA re-verified`, and `Logo assets remain Phase 49`.

## Shared Patterns

### Canonical Source

**Source:** `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-DISCREPANCY-LEDGER.md` lines 10-21
**Apply to:** `priv/static/cairnloop.css`, `app.css`, `cairnloop.tokens.json`, `token_drift_test.exs`, `48-CONTRAST-REVERIFY.md`
```markdown
**`priv/static/cairnloop.css` `:root` is the single canonical token source for the Cairnloop design system.**

### Derivatives — documented as expressions-of-canonical (D-03)
```

### Derivative Drift Worklist

**Source:** `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-DISCREPANCY-LEDGER.md` lines 196-208
**Apply to:** `examples/cairnloop_example/assets/css/app.css`, `test/cairnloop/web/token_drift_test.exs`
```markdown
## Confirmed Drift Summary (Phase 48 Worklist)

### Drift Item 1 — VALUE DRIFT: `--cl-shadow-raised` in `app.css`

| **Phase 48 action** | Replace app.css `--cl-shadow-raised` with `var(--cl-shadow-1)` to match canonical |
```

### DB-Free Source Tests

**Source:** `test/cairnloop/web/brand_token_gate_test.exs` lines 19-23 and `test/cairnloop/web/cairnloop_css_test.exs` lines 11-15
**Apply to:** all token/source-gate ExUnit files
```elixir
use ExUnit.Case, async: true

setup_all do
  css_path = Path.join(File.cwd!(), "priv/static/cairnloop.css")
  css = File.read!(css_path)
  {:ok, css: css}
end
```

### Contrast Thresholds

**Source:** `.planning/phases/46-brand-fidelity-audit-token-consolidation/46-CONTRAST-BASELINE.md` lines 4-7 and 23-25
**Apply to:** `token_drift_test.exs`, `48-CONTRAST-REVERIFY.md`
```markdown
**Method:** WCAG 2.x relative-luminance algorithm (w3.org/TR/WCAG22).
**Thresholds:** 4.5:1 normal text · 3.0:1 large text · 3.0:1 non-text UI components.

| # | Pairing | FG token | FG hex (L/D) | BG token | BG hex (L/D) | Theme | Ratio | Threshold | Verdict |
```

### Validation Commands

**Source:** `.planning/phases/48-token-evolution-lock-propagate/48-VALIDATION.md` lines 20-23 and 50-53
**Apply to:** planner verification sections
```markdown
| **Framework** | ExUnit + Mix aliases + Playwright E2E alias |
| **Quick run command** | `mix test test/cairnloop/web/token_drift_test.exs test/cairnloop/web/brand_token_gate_test.exs` |
| **Full suite command** | `mix test && mix test.integration && mix test.e2e` |

- [ ] `test/cairnloop/web/token_drift_test.exs` - covers TOKEN-02 no-renames, TOKEN-03 derivative parity, and TOKEN-04 contrast revalidation.
- [ ] `.planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md` - durable evidence table for Phase 46 baseline rows recomputed against the evolved palette.
```

## No Analog Found

All scoped files have close analogs in the current codebase or Phase 46 artifacts.

## Metadata

**Analog search scope:** `priv/static/`, `examples/cairnloop_example/assets/css/`, `prompts/`, `test/cairnloop/web/`, `.planning/phases/46-brand-fidelity-audit-token-consolidation/`, `.planning/phases/48-token-evolution-lock-propagate/`
**Files scanned:** 15+ via `rg --files`, targeted `rg`, `wc -l`, and line-numbered reads
**Pattern extraction date:** 2026-06-24
