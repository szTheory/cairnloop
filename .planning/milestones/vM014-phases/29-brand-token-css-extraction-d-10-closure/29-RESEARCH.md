# Phase 29: Brand-Token CSS Extraction (D-10 Closure) - Research

**Researched:** 2026-05-27
**Domain:** CSS design tokens / Tailwind v4 `@theme` directive / ExUnit source-grep gate
**Confidence:** HIGH

## Summary

Phase 29 is a small, mechanical, and almost entirely additive cleanup phase that closes
the deferred D-10 decision from vM013. There are three concrete deliverables and one
contract gate: (1) replace the 4-token placeholder in
`examples/cairnloop_example/assets/css/app.css` with the canonical 15-primitive + 14-semantic
+ typography + radius + shadow `:root` block from `prompts/cairnloop.css` plus the
`[data-theme="dark"]` overrides; (2) drop `, #<hex>` (and only `, #<hex>`) suffixes from the
22 inline `var(--cl-<token>, #<hex>)` strings spread across `inbox_live.ex`,
`conversation_live.ex`, and `search_modal_component.ex`; (3) re-pin the 6 hex-fallback
test assertions in `test/integration/` to the bare `var(--cl-<token>)` form; (4) add a
file-read source-scan ExUnit test that fails the build if any `var(--cl-<token>, #` string
re-appears under `lib/cairnloop/web/`.

The phase is small, but it is **surgical**: 22 byte-exact edits across 3 sealed render
files, 6 assertion re-pins, 1 new gate test, and one CSS file replacement. The Tailwind v4
`@theme` block separately needs the 15 primitive color tokens (in `--color-cl-*` namespace)
because `@layer base :root` declarations alone do NOT generate Tailwind utility classes —
this is a Tailwind v4 mechanics fact that the existing 4-token stub already encodes
correctly and the planner must preserve when expanding to 15.

**Primary recommendation:** Treat this as a 3-plan phase — (Plan 1) CSS landing in
`app.css`, (Plan 2) hex-fallback drop across 3 lib files + gate test + assertion re-pins,
(Plan 3) example-app `chat_live.ex` sweep + token-vocabulary reconciliation (see
**Specific Idea: scope gap** below). Plan 2 is the load-bearing one; Plan 1 is independent
and unblocks Plan 3.

## Architectural Responsibility Map

This phase is a CSS/style-token contract phase — there is no business logic or new tier
assignment. The "responsibility" mapping below describes which **layer of the styling
stack** owns each concern, not application tiers.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Canonical token definition (semantic + primitive) | `prompts/cairnloop.css` `:root` block | — | Single source of truth per brand book §7.4; copied (not imported) into the example app to keep the library zero-dep at runtime |
| Tailwind utility-class generation (`bg-cl-*`, `text-cl-*`) | `app.css` `@theme` block | — | Tailwind v4 mechanics: only variables in `@theme` produce utility classes; `:root` alone makes them visible as CSS vars but not as Tailwind classes |
| CSS-var resolution at render time | Browser CSS engine | — | Inline `style="color: var(--cl-primary)"` resolves against the cascade from `app.css` — no Phoenix/LiveView responsibility |
| Headless test contract enforcement | `test/cairnloop/` (untagged unit lane) | — | Untagged tests run in default `mix test` (DB-free); the gate test must NOT be `:integration`-tagged or it won't run in fast inner loop |
| Hex-fallback regression gate | New file-read ExUnit test | — | File-read + Regex.scan idiom (per existing project source-scan tests) is more portable than `System.cmd("grep", ...)` and matches the established pattern in `conversation_live_test.exs:1965` |

## Standard Stack

This phase does NOT introduce new dependencies. All work is local to existing files plus
one new test file. The "stack" here is the tooling that already ships.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `tailwind` (Elixir) | `~> 0.3` (running Tailwind CSS v4.1.12) | Compiles `app.css` → `priv/static/assets/css/app.css` with `@theme` utility-class generation | [VERIFIED: examples/cairnloop_example/config/config.exs:40, mix.exs:61] Already in the example app — `@theme`-block utility generation requires Tailwind v4 (confirmed v4.1.12 [CITED: tailwindcss.com/docs/theme]) |
| `ExUnit` | stdlib | Headless gate test for negative-grep regression detection | [VERIFIED] Already used by 700+ project tests; gate test follows existing source-scan idiom from `conversation_live_test.exs:1965` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Regex` / `File.read!` | stdlib | Source-file scan for hex-fallback regression | Use INSTEAD OF `System.cmd("grep", …)` — established project pattern, no GNU/BSD grep portability issues, deterministic across CI hosts |
| `Path.expand` + `__ENV__.file` | stdlib | Resolve project root from test file location | Established idiom — see `conversation_live_test.exs:1950-1956` (4× `Path.dirname` walk-up) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `File.read!` + `Regex.scan/3` (recommended) | `System.cmd("grep", ["-rE", "var\\(--cl-[a-z-]*, #", "lib/cairnloop/web/"])` | `System.cmd` matches CONTEXT.md D-08 literally but adds an env dependency (BSD vs GNU `grep -E` behave the same for this pattern, but CI hosts running on alpine/scratch may lack grep entirely). The `File.read!` + `Regex.scan/3` form is what 5+ existing project source-scan tests use; it's more portable and matches the project's established gate idiom. **Recommend the file-read form.** |
| Copy `cairnloop.css` `:root` block verbatim (recommended per D-04) | `@import "../../../prompts/cairnloop.css"` relative import | Importing from `prompts/` couples the example app to a non-asset path and breaks if the example is ever extracted. The brand book treats `cairnloop.css` as a source of truth, not a deployment artifact — copy is the intended mode. **Recommend copy per D-04.** |
| Replace existing `:root` + `@theme` blocks per D-06 | Append new tokens alongside the 4-token stub | Stub uses `--cl-color-basalt` / `--cl-color-trailpaper` etc. — these ARE the same names as the canonical block, so appending creates duplicate declarations and ambiguous cascade ordering. Replace, don't append. |

**Installation:** None — no new deps.

**Version verification:**
```bash
# Tailwind version actually in use (verified via config/config.exs):
# tailwind: 4.1.12
# Elixir tailwind wrapper: ~> 0.3
# @theme directive: Tailwind CSS v4.0+ feature (✓ supported)
```
The 4.1.12 version has stable `@theme` support [CITED: https://tailwindcss.com/docs/theme].

## Package Legitimacy Audit

No new packages are installed by this phase. Existing dependencies (`tailwind ~> 0.3`,
`heroicons`, daisyUI vendored plugins) are unchanged. Skipping slopcheck — no install
surface to audit.

## Architecture Patterns

### System Architecture Diagram

```
                       prompts/cairnloop.css                 prompts/cairnloop.tokens.json
                       (canonical :root block,                (structured token
                        dark overrides)                        descriptions, ref-only)
                              │
                              │ COPY (D-04 / D-06)
                              ▼
   examples/cairnloop_example/assets/css/app.css
   ┌─────────────────────────────────────────────────────────────────────┐
   │  @import "tailwindcss" source(none);                                │
   │                                                                     │
   │  @theme { ─────────────────────── 15 --color-cl-* primitives        │
   │    --color-cl-basalt: #18211F;     (generates bg-cl-basalt,         │
   │    --color-cl-trailpaper: #F5F0E6; text-cl-basalt utilities)        │
   │    …                                                                │
   │  }                                                                  │
   │                                                                     │
   │  @layer base {                                                      │
   │    :root { ────────────────────── 15 primitive + 14 semantic +      │
   │      --cl-color-*: …                typography + radius + shadow    │
   │      --cl-bg: var(--cl-color-…)     (CSS vars only — no Tailwind    │
   │      …                              utility class generation here)  │
   │    }                                                                │
   │    [data-theme="dark"] { ──────── 14 dark overrides (D-07)          │
   │      --cl-bg: #101614;                                              │
   │      …                                                              │
   │    }                                                                │
   │  }                                                                  │
   └─────────────────────────────────────────────────────────────────────┘
                              │
                              │ Tailwind compiles → priv/static/assets/css/app.css
                              ▼
        Browser CSS engine resolves var(--cl-<token>) at render time
                              │
                              ▼
   ┌──────────────────────────────────────────────────────────────────────┐
   │  lib/cairnloop/web/inbox_live.ex          (10 hex-fallback drops)    │
   │  lib/cairnloop/web/conversation_live.ex   ( 7 hex-fallback drops)    │
   │  lib/cairnloop/web/search_modal_component.ex (5 hex-fallback drops)  │
   │                                                                      │
   │  style="background: var(--cl-primary);"   ◄── after drop             │
   │  style="background: var(--cl-primary, #A94F30);" ◄── before          │
   └──────────────────────────────────────────────────────────────────────┘
                              │
                              │ test contract
                              ▼
   ┌──────────────────────────────────────────────────────────────────────┐
   │  test/cairnloop/<new>_test.exs                                       │
   │    - File.read! on each of the 3 lib/cairnloop/web/ files            │
   │    - Regex.scan ~r/var\(--cl-[a-z-]+, #/                             │
   │    - refute matches > 0                                              │
   │  test/integration/approval_footer_live_test.exs    (1 assertion)     │
   │  test/integration/tool_execution_outcome_live_test.exs (3 assertions)│
   │  test/integration/bulk_recovery_live_test.exs      (2 assertions)    │
   │    - re-pin "var(--cl-primary, #A94F30)" → "var(--cl-primary)"       │
   │    - re-pin "var(--cl-danger, #B54C36)"  → "var(--cl-danger)"        │
   └──────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure (no change — phase touches existing tree only)

```
.
├── prompts/
│   ├── cairnloop.css                                # source of truth (READ-ONLY in this phase)
│   └── cairnloop.tokens.json                        # reference (READ-ONLY)
├── examples/cairnloop_example/assets/css/
│   └── app.css                                      # REPLACE :root + @theme blocks (BRAND-01)
├── lib/cairnloop/web/
│   ├── inbox_live.ex                                # 10 hex-fallback drops + moduledoc update (BRAND-02)
│   ├── conversation_live.ex                         # 7 hex-fallback drops (BRAND-02)
│   └── search_modal_component.ex                    # 5 hex-fallback drops (BRAND-02)
├── test/cairnloop/
│   └── brand_token_gate_test.exs                    # NEW — negative-grep gate (BRAND-04)
└── test/integration/
    ├── approval_footer_live_test.exs                # re-pin 1 assertion (BRAND-03)
    ├── tool_execution_outcome_live_test.exs         # re-pin 3 assertions (BRAND-03)
    └── bulk_recovery_live_test.exs                  # re-pin 2 assertions (BRAND-03)
```

### Pattern 1: Tailwind v4 `@theme` for utility class generation

**What:** `@theme` is special Tailwind v4 syntax — variables declared inside it become
both CSS custom properties AND generate Tailwind utility classes. Variables in
`@layer base :root` only do the former.

**When to use:** Put a token in `@theme` ONLY if you want a `bg-*` / `text-*` / `border-*`
utility for it. Semantic tokens (`--cl-bg`, `--cl-primary`, etc.) live in `:root` because
the project uses inline `style="…"` for semantic colors, not utility classes. Primitive
color tokens (`--color-cl-basalt`, `--color-cl-trailpaper`, etc.) go in `@theme` so
adopters writing their own templates can use `bg-cl-basalt`, `text-cl-trailpaper`.

**Example:**
```css
/* Source: https://tailwindcss.com/docs/theme (Tailwind v4.1) */
@import "tailwindcss" source(none);

@theme {
  /* These generate bg-cl-basalt, text-cl-basalt, border-cl-basalt, etc. */
  --color-cl-basalt: #18211F;
  --color-cl-trailpaper: #F5F0E6;
  /* … 13 more primitives … */
}

@layer base {
  :root {
    /* These are CSS variables ONLY — they resolve in var() refs, but
       no Tailwind utility classes are generated for them. */
    --cl-color-basalt: #18211F;            /* primitive (mirrors @theme) */
    --cl-bg: var(--cl-color-trailpaper);   /* semantic — refs primitive */
    --cl-primary: var(--cl-color-path-copper);
    /* … rest of canonical block … */
  }
}
```

### Pattern 2: Headless source-scan gate test (project idiom)

**What:** Read source files directly with `File.read!`, scan with `Regex`, assert
violations are absent. Runs in default `mix test` (no DB, no Endpoint).

**When to use:** When enforcing a code-level invariant that the type system can't enforce
(e.g., "no `LiveView.stream(` in this file", "no hex fallback in `var()`").

**Example:**
```elixir
# Source: project pattern — test/cairnloop/web/conversation_live_test.exs:1965-1981
defmodule Cairnloop.Web.BrandTokenGateTest do
  use ExUnit.Case, async: true

  @web_dir Path.expand("../../lib/cairnloop/web", __DIR__)
  @hex_fallback_pattern ~r/var\(--cl-[a-z-]+,\s*#/

  test "no hex-fallback strings in lib/cairnloop/web/" do
    files = Path.wildcard(Path.join(@web_dir, "*.ex"))
    assert files != [], "expected at least one .ex file under #{@web_dir}"

    violations =
      for file <- files,
          content = File.read!(file),
          [match | _] <- Regex.scan(@hex_fallback_pattern, content) do
        {Path.basename(file), match}
      end

    assert violations == [], """
    Hex-fallback strings found in lib/cairnloop/web/ — BRAND-04 contract violated.

    The hex fallback was dropped in Phase 29 (D-10 closure, Option B).
    Use bare `var(--cl-<token>)` form. The canonical token values come from
    `prompts/cairnloop.css` via the example app's `app.css`.

    Violations:
    #{Enum.map_join(violations, "\n", fn {f, m} -> "  - #{f}: #{m}" end)}
    """
  end
end
```

### Pattern 3: Mechanical hex-fallback drop (preserve structure, no churn)

**What:** Replace each `var(--cl-<token>, #<hex>)` with `var(--cl-<token>)`. ONLY remove
the `, #<hex>` suffix — no other change.

**When to use:** EVERY one of the 22 hex-fallback sites listed in CONTEXT.md. Do NOT
reorder, do NOT extract to classes, do NOT change whitespace.

**Example:**
```elixir
# BEFORE — inbox_live.ex:177
style="background: var(--cl-primary, #A94F30); color: var(--cl-on-primary, #fffdf8); border-radius: 8px; …"

# AFTER — only the , #<hex> suffix removed
style="background: var(--cl-primary); color: var(--cl-on-primary, #fffdf8); border-radius: 8px; …"
#                              ▲▲▲▲                  ▲▲▲▲ NOT a hex — `#fffdf8` IS a hex but it's NOT
#                              dropped               in the gate pattern's scope because the token
#                                                    name `--cl-on-primary` doesn't exist in the
#                                                    canonical block — see Pitfall 1 below.
```

WAIT — re-read: `, #fffdf8` IS a hex fallback string. The gate pattern `var\(--cl-[a-z-]+, #`
WILL match it. So it MUST be dropped too. See Pitfall 1.

### Anti-Patterns to Avoid

- **Importing `cairnloop.css` from `prompts/`:** The brand book treats `cairnloop.css`
  as a documentation artifact, not a build asset. Copy verbatim per D-04; do not
  `@import "../../../prompts/cairnloop.css";` — that couples the example app's build
  pipeline to a docs path and breaks if `prompts/` is ever moved.
- **Mixing semantic tokens into `@theme`:** Putting `--cl-bg` or `--cl-primary` in
  `@theme` would generate `bg-cl-bg` and `bg-cl-primary` utility classes. The
  project's inline-style convention doesn't need those, AND it would obscure the
  primitive/semantic split. Keep semantic tokens in `:root` only (D-05 explicit).
- **Using `System.cmd("grep", …)` for the gate:** CONTEXT.md D-08 mentions
  `System.cmd`, but the project's established pattern is `File.read!` + `Regex.scan`
  (5+ existing tests). The `Regex.scan` form is more portable, deterministic, and
  consistent. CONTEXT.md decisions are guidance, not constraints on implementation
  technique — match the project idiom.
- **Re-pinning assertions that aren't broken:** CONTEXT.md D-03 explicitly notes
  `test/cairnloop/web/inbox_live_test.exs:190` and
  `test/cairnloop/web/conversation_live_test.exs:1961` already use the
  prefix-only form `"var(--cl-primary"` (no comma, no hex) — they'll continue to
  pass after the drop. DO NOT touch them.
- **Touching sealed render code beyond the suffix removal:** No reordering of style
  attributes, no extraction to classes (that's Option A — explicitly out of scope per
  STATE.md and CONTEXT.md), no whitespace normalization. Sealed code stays
  byte-for-byte identical except for the dropped `, #<hex>` suffix.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tailwind utility class generation for brand colors | Custom utility-class plugin / hand-written `bg-cl-*` rules | `@theme` directive with `--color-cl-*` namespace | Tailwind v4's `@theme` block IS the supported, documented mechanism — generates `bg-*`, `text-*`, `fill-*`, `stroke-*`, `border-*` automatically [CITED: tailwindcss.com/docs/theme] |
| Token vocabulary documentation | A new internal docs file | The already-existing `prompts/cairnloop.tokens.json` + `cairnloop_brand_book.md §7.4` | Brand book already enumerates every semantic token with light/dark values; the JSON file has structured descriptions per token |
| Source-scan gate test infrastructure | A custom mix task / `lib/mix/tasks/check_brand_tokens.ex` | `File.read!` + `Regex.scan` in an ExUnit test | Established project pattern (5+ existing tests); runs in default `mix test`; failures show in the same lane as everything else; no new task surface to maintain |
| Dark-mode toggle wiring | A new `data-theme="dark"` toggle in this phase | Just land the override block; defer interactive toggle | `[data-theme="dark"]` overrides are part of the brand token contract; an actual user-facing toggle is `SET-01` (vM015 polish) — out of scope per OOS table in REQUIREMENTS.md |

**Key insight:** Phase 29 has zero "build something custom" surface. Every piece of
infrastructure it needs already exists in the project — the work is mechanical copy,
suffix removal, assertion re-pin, and one ExUnit gate test following an established
pattern.

## Runtime State Inventory

This is a **CSS / source-string rename** phase, not a data-migration phase. The
inventory below is per the rename/refactor protocol — all categories explicitly
addressed.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no database tokens, no persisted color values, no `--cl-*` strings in any Ecto schema or migration (verified via `grep -rn "cl-primary" priv/ 2>/dev/null` empty result) | None |
| Live service config | None — no external service stores brand-token strings; no n8n / Datadog / Tailscale config in this project | None |
| OS-registered state | None — no scheduled tasks, no system services depend on brand tokens | None |
| Secrets / env vars | None — no env var references `--cl-`; no SOPS keys involve color tokens | None |
| Build artifacts / installed packages | **Yes — `priv/static/assets/css/app.css` is generated**. After landing the canonical `app.css`, the example app must run `mix assets.build` to regenerate the compiled output. Existing `priv/static/assets/` is stale until rebuilt. | `cd examples/cairnloop_example && mix assets.build` after BRAND-01. Verify no `priv/static/assets/css/app.css` is checked into git that contradicts the source. |

**Nothing found in 4 of 5 categories:** verified by grep across `priv/`, `config/`,
external-service docs (none in this project), and `.env*` files (none in repo).
The only material artifact is the Tailwind-compiled `app.css` output, which is a
build step, not a runtime migration.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` / Elixir | Build & test | ✓ | 1.19+ per mix.exs | — |
| `tailwind` (Elixir wrapper) | `mix assets.build` for example app | ✓ | `~> 0.3` (Tailwind v4.1.12) | — |
| Postgres / Repo | Untagged unit tests (gate test) | Not required — gate test is headless `File.read!` only | — | — |
| Postgres / Repo | Integration assertions (`test/integration/*`) | Required for re-pinned assertions to actually run | — | Re-pin is byte-replacement in source; if the integration suite can't run locally, the change is verifiable by inspection + `mix compile --warnings-as-errors`. CI's integration lane is the proof. |
| `grep` (GNU/BSD) | NOT used — we recommend `File.read!` + `Regex.scan` | N/A | — | If CONTEXT.md D-08's `System.cmd("grep", …)` form is preferred, grep must be on PATH in CI (true for default Ubuntu runners, but adds a dep). Prefer the file-read form. |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None of consequence.

## Common Pitfalls

### Pitfall 1: The gate pattern matches MORE than CONTEXT.md's 22 instances
**What goes wrong:** The CONTEXT.md count is "22 hex-fallback instances." But the gate
regex `var\(--cl-[a-z-]+, #` matches any `var(--cl-<name>, #<anything>)` — including
fallbacks like `#fffdf8`, `#FFFFFF`, `#2f241d` which are NOT hex codes of the listed
canonical tokens (they're explicit hexes for `--cl-on-primary`, `--cl-surface-raised`,
`--cl-text`).
**Why it happens:** The 22-count was likely derived from a narrower search (e.g., only
`#A94F30` / `#B54C36`) or only the named token sites. The actual `grep -rE 'var\(--cl-[a-z-]+, #' lib/cairnloop/web/`
returns 22 matching LINES, but each line may contain MULTIPLE hex fallbacks (e.g.,
`inbox_live.ex:177` has `var(--cl-primary, #A94F30)` AND `var(--cl-on-primary, #fffdf8)` on
the same line).
**How to avoid:** Plan should NOT specify "drop 22 hex fallbacks" as the success metric.
Instead: "the negative-grep gate test passes" is the metric. Drop EVERY `, #<hex>` suffix
the gate would catch, on every line, not just one per line. Verify with
`grep -oE 'var\(--cl-[a-z-]+, #[0-9A-Fa-f]+\)' lib/cairnloop/web/ -r | wc -l` (counts
matches, not lines).
**Warning signs:** Gate test fails after the drop because hex fallbacks remain on lines
the planner thought were already done; multiple hex fallbacks per single style attribute.

### Pitfall 2: rgba fallbacks survive — by design, but documentation must reflect this
**What goes wrong:** 11 of the 30 total fallback instances in the 3 files use `rgba(...)`
or non-hex syntax (e.g., `var(--cl-text-muted, rgba(47, 36, 29, 0.62))`). The CONTEXT.md
D-09 gate pattern is `var(--cl-[a-z-]*, #` — only `#`. These rgba fallbacks pass through
the gate untouched.
**Why it happens:** D-09 is hex-only by design (the deferred D-10 was about hex
fallbacks specifically). But the moduledoc in `inbox_live.ex:30-34` says "Every color in
this file is expressed as `var(--cl-<name>, <hex-or-rgba>)`" — after the hex drops, that
moduledoc becomes inaccurate (hex is gone, rgba remains).
**How to avoid:** When dropping hex fallbacks, ALSO update the `inbox_live.ex` moduledoc
(lines 28-46) to reflect the new state: "Every color uses `var(--cl-<name>)`; some
non-canonical tokens (`--cl-overlay`, `--cl-shadow`, etc.) retain `rgba` fallbacks until
they're added to the canonical block (deferred to vM015)." Failing to update the
moduledoc leaves a misleading internal documentation trail.
**Warning signs:** Post-drop, the moduledoc still says "with hex" but the code has none;
a reviewer notices the discrepancy.

### Pitfall 3: Non-canonical tokens in use have no `:root` definition
**What goes wrong:** `inbox_live.ex` and friends use tokens like `--cl-on-primary`,
`--cl-text-muted`, `--cl-text-soft`, `--cl-overlay`, `--cl-shadow`, `--cl-danger-soft`,
`--cl-primary-disabled`, `--cl-surface-translucent`. After dropping their hex/rgba
fallbacks, only the ones defined in `prompts/cairnloop.css` `:root` will resolve. The
others will resolve to `unset` (browsers treat undefined custom properties as invalid
declarations).
**Why it happens:** Canonical block defines 14 semantic tokens; the LiveViews use more.
The fallback was masking the gap. Dropping the fallback exposes the gap.
**How to avoid:** Audit pre-drop which tokens used in `lib/cairnloop/web/` are present
in the canonical block. Tokens used in code that are NOT canonical:
  - `--cl-on-primary` (used 4×) — closest canonical = `--cl-primary-text` (rename in code OR add `--cl-on-primary: var(--cl-primary-text);` alias in `:root`)
  - `--cl-text-muted` (used 5×) — ✓ canonical exists
  - `--cl-text-soft` (used 1×) — NOT canonical, no close match (keeps rgba fallback)
  - `--cl-overlay` (used 1×) — NOT canonical (keeps rgba fallback)
  - `--cl-shadow` (used 1×) — partial — canonical has `--cl-shadow-raised`, NOT a 1:1 (keeps rgba fallback)
  - `--cl-danger-soft` (used 1×) — NOT canonical (keeps rgba fallback)
  - `--cl-primary-disabled` (used 1×) — NOT canonical (keeps rgba fallback)
  - `--cl-surface-translucent` (used 1×) — NOT canonical (keeps rgba fallback)
**Recommended decision:** Add 1 alias to `:root` for `--cl-on-primary` (it's used on
every primary button — the most visible affordance). Either:
  (a) Rename in code: `--cl-on-primary` → `--cl-primary-text` in the 4 sites — but this
      touches sealed render code and the rgba/non-canonical tokens still need fallbacks
      to be visible, so leave the others alone.
  (b) Add to `:root`: `--cl-on-primary: var(--cl-primary-text);` — keeps sealed code
      untouched, makes the alias explicit, documents the mapping.
**Recommend (b)** — additive in `app.css` only, zero churn to render code. Plan should
include this addition as part of BRAND-01.
**Warning signs:** Primary button looks "wrong" in dev after the drop because
`--cl-on-primary` resolves to nothing and the browser falls back to inherited color.

### Pitfall 4: The Tailwind v4 `@theme` block must replace, not append
**What goes wrong:** Existing `app.css` has 4 `@theme` entries (`--color-cl-basalt`,
`--color-cl-trailpaper`, `--color-cl-warm-stone`, `--color-cl-primary`). If the planner
appends 15 more, the 4 duplicates win or lose in unspecified order depending on Tailwind
processing.
**Why it happens:** D-06 says "replace, don't append" but a careless edit could leave
both blocks.
**How to avoid:** Read the existing `app.css` `@theme { … }` block (lines 6-11) and
REPLACE it entirely with the 15-primitive block. Same for the `@layer base { :root { … } }`
block (lines 13-22).
**Warning signs:** Two `@theme` blocks in the diff; duplicate `--color-cl-*` keys.

### Pitfall 5: The gate test must NOT be `:integration`-tagged
**What goes wrong:** Tagging the gate test `:integration` means it only runs under
`mix test.integration` (DB-backed, slow, dockerized). The fast inner-loop `mix test` skips
it. Regressions land before CI catches them.
**Why it happens:** `test/integration/` is the integration lane, but the gate test lives
in `test/cairnloop/` (per CONTEXT.md D-08) — easy to forget the tag rules.
**How to avoid:** Gate test goes in `test/cairnloop/` (e.g., `test/cairnloop/web/brand_token_gate_test.exs`
or `test/cairnloop/brand_token_gate_test.exs`), uses `use ExUnit.Case`, no `@tag :integration`.
Default `mix test` will pick it up. Verify: `mix test test/cairnloop/brand_token_gate_test.exs`
runs without `--include integration`.
**Warning signs:** `mix test` exits green but a re-introduced hex fallback survives;
the test only runs in `mix test.integration`.

### Pitfall 6: Example app's `chat_live.ex` (Phase 28 file) has 18 hex fallbacks NOT in scope
**What goes wrong:** `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex`
(rewritten in Phase 28) contains 18 hex-fallback strings. CONTEXT.md scope is
`lib/cairnloop/web/` only — gate scan won't catch these. They live in the example app,
not the library. But Success Criterion 1 says "the example app and library render
surfaces" both use canonical tokens.
**Why it happens:** Phase 28 wrote `chat_live.ex` using the pre-Phase-29 convention
(hex fallbacks) because the example app's `app.css` was still the 4-token stub. After
Phase 29 lands the canonical `:root` block in `app.css`, the example app's `chat_live.ex`
fallbacks become redundant — every `--cl-*` in it should resolve correctly without the
hex suffix.
**How to avoid:** Plan should explicitly decide: (a) extend the BRAND-02 scope to include
`chat_live.ex` and drop its 18 fallbacks (recommended — small, mechanical, consistent
with phase intent); OR (b) explicitly defer and document why (e.g., "example app's
sealed Phase 28 path stays unchanged"). **Recommend (a)** — phase Goal says "example
app and library render surfaces" — and extend BRAND-04 gate to scan
`examples/cairnloop_example/lib/cairnloop_example_web/live/` too. Also note
`chat_live.ex` uses `--cl-error` (line 58, 100) which is NOT canonical — canonical token
is `--cl-danger`. This needs renaming OR aliasing in `:root`. **Recommend rename in code**
(2 sites only, additive-only-impossible — `--cl-error` doesn't exist so any reference is
broken without the fallback; rename is the smallest correct fix).
**Warning signs:** Phase 29 ships and the example app's `/chat` page renders with stale
hex codes that no longer match the canonical palette if anyone tweaks the canonical
later; the gate "passes" but is incomplete.

### Pitfall 7: `mix compile --warnings-as-errors` after moduledoc edits
**What goes wrong:** Updating the `inbox_live.ex` moduledoc (Pitfall 2) might
inadvertently break a `@moduledoc` doctype or trip a warning if the formatting is wrong.
The project mandates warnings-clean builds (CLAUDE.md).
**Why it happens:** Moduledocs are markdown-in-string — Elixir will compile them
regardless, but the project's hex/CI lane runs `mix docs` which can fail on bad markdown.
**How to avoid:** After any moduledoc edit, run `mix compile --warnings-as-errors` AND
optionally `mix docs` to confirm. Don't introduce `@moduledoc false` either — keep the
public doc, just update the brand-tokens section.
**Warning signs:** Compile passes but `mix docs` fails; CI doc-generation step breaks.

### Pitfall 8: Test re-pin string must match the EXACT new form
**What goes wrong:** The 6 integration assertions assert `html =~ "var(--cl-primary, #A94F30)"`.
After re-pin to `html =~ "var(--cl-primary)"`, the substring `"var(--cl-primary)"` will
also match `"var(--cl-primary, #anything)"` (substring containment), so the test is
weaker than before. Both `"var(--cl-primary"` (no closing paren) and
`"var(--cl-primary)"` (with paren) would work, but the latter is stricter.
**Why it happens:** Elixir's `=~` is substring containment for binaries.
**How to avoid:** Re-pin with the closing paren `"var(--cl-primary)"` — closed string
asserts the bare-token form is present and excludes the comma-fallback form. This
matches the spirit of the test (token IS used, hex IS NOT used).
**Warning signs:** Re-pin uses `"var(--cl-primary"` (no closing paren) and accidentally
admits the hex-fallback form back into the corpus.

## Code Examples

### Example A: app.css canonical block landing (BRAND-01)

```css
/* Source: prompts/cairnloop.css (verbatim copy of :root and [data-theme="dark"]) */
/* See the Tailwind configuration guide for advanced usage
   https://tailwindcss.com/docs/configuration */

@import "tailwindcss" source(none);

@theme {
  /* 15 primitive color tokens — generates bg-cl-*, text-cl-*, border-cl-*, etc. */
  --color-cl-basalt: #18211F;
  --color-cl-moss-ink: #263A2E;
  --color-cl-trailpaper: #F5F0E6;
  --color-cl-warm-stone: #FBF7EE;
  --color-cl-granite: #D8D0BF;
  --color-cl-slate-lichen: #677066;
  --color-cl-path-copper: #A94F30;
  --color-cl-copper-glow: #C46A3A;
  --color-cl-lichen: #A8B56C;
  --color-cl-deep-lichen: #4A6238;
  --color-cl-glacier-mist: #DDE8E3;
  --color-cl-waypoint-blue: #3F6F80;
  --color-cl-heather: #7A5D78;
  --color-cl-ember: #8B531E;
  --color-cl-fault-clay: #B54C36;
}

@layer base {
  :root {
    /* Primitives (mirror @theme so inline var(--cl-color-*) refs resolve) */
    --cl-color-basalt: #18211F;
    --cl-color-moss-ink: #263A2E;
    --cl-color-trailpaper: #F5F0E6;
    --cl-color-warm-stone: #FBF7EE;
    --cl-color-granite: #D8D0BF;
    --cl-color-slate-lichen: #677066;
    --cl-color-path-copper: #A94F30;
    --cl-color-copper-glow: #C46A3A;
    --cl-color-lichen: #A8B56C;
    --cl-color-deep-lichen: #4A6238;
    --cl-color-glacier-mist: #DDE8E3;
    --cl-color-waypoint-blue: #3F6F80;
    --cl-color-heather: #7A5D78;
    --cl-color-ember: #8B531E;
    --cl-color-fault-clay: #B54C36;

    /* Semantic tokens (resolve to primitives) */
    --cl-bg: var(--cl-color-trailpaper);
    --cl-surface: var(--cl-color-warm-stone);
    --cl-surface-raised: #FFFFFF;
    --cl-text: var(--cl-color-basalt);
    --cl-text-muted: var(--cl-color-slate-lichen);
    --cl-border: var(--cl-color-granite);
    --cl-primary: var(--cl-color-path-copper);
    --cl-primary-text: #FFFFFF;
    --cl-success: var(--cl-color-deep-lichen);
    --cl-info: var(--cl-color-waypoint-blue);
    --cl-ai: var(--cl-color-heather);
    --cl-warning: var(--cl-color-ember);
    --cl-danger: var(--cl-color-fault-clay);
    --cl-focus: var(--cl-color-path-copper);

    /* Alias (Pitfall 3 — additive, keeps sealed render code unchanged) */
    --cl-on-primary: var(--cl-primary-text);

    /* Typography */
    --cl-font-sans: "Atkinson Hyperlegible Next", "Atkinson Hyperlegible", ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    --cl-font-display: "Fraunces", "Atkinson Hyperlegible Next", Georgia, serif;
    --cl-font-mono: "Martian Mono", "Atkinson Hyperlegible Mono", ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;

    /* Radius, shadow */
    --cl-radius-sm: 6px;
    --cl-radius-md: 10px;
    --cl-radius-lg: 14px;
    --cl-shadow-raised: 0 1px 2px rgba(24, 33, 31, 0.08), 0 8px 24px rgba(24, 33, 31, 0.06);
  }

  [data-theme="dark"] {
    --cl-bg: #101614;
    --cl-surface: #18211F;
    --cl-surface-raised: #1F2C28;
    --cl-text: #F5F0E6;
    --cl-text-muted: #B7C0B2;
    --cl-border: #34443D;
    --cl-primary: #D98A4A;
    --cl-primary-text: #18211F;
    --cl-success: #A8B56C;
    --cl-info: #9EC3CF;
    --cl-ai: #C9A7C6;
    --cl-warning: #D98A4A;
    --cl-danger: #E18C7D;
    --cl-focus: #D98A4A;
  }
}

@source "../css";
@source "../js";
@source "../../lib/cairnloop_example_web";

/* … rest of file unchanged (daisyUI plugins, custom variants, etc.) … */
```

### Example B: Mechanical hex-fallback drop (BRAND-02)

```elixir
# BEFORE — lib/cairnloop/web/inbox_live.ex:177
"""
<button … style="background: var(--cl-primary, #A94F30); color: var(--cl-on-primary, #fffdf8); border-radius: 8px; min-height: 44px; padding: 10px 16px; border: none; font-weight: 600;">
"""

# AFTER — drop BOTH , #<hex> suffixes (Pitfall 1 — multiple hexes per line)
"""
<button … style="background: var(--cl-primary); color: var(--cl-on-primary); border-radius: 8px; min-height: 44px; padding: 10px 16px; border: none; font-weight: 600;">
"""
```

### Example C: Re-pin a test assertion (BRAND-03)

```elixir
# BEFORE — test/integration/approval_footer_live_test.exs:52
assert html =~ "var(--cl-primary, #A94F30)"

# AFTER — re-pin to the bare-token form (Pitfall 8 — keep closing paren)
assert html =~ "var(--cl-primary)"
```

### Example D: Negative-grep gate test (BRAND-04)

```elixir
# test/cairnloop/web/brand_token_gate_test.exs (new file)
defmodule Cairnloop.Web.BrandTokenGateTest do
  @moduledoc """
  BRAND-04 (Phase 29, D-10 closure): negative-grep gate that fails the build
  if any `var(--cl-<token>, #<hex>)` fallback string re-appears in
  `lib/cairnloop/web/`. After Phase 29, every brand-color reference is the
  bare `var(--cl-<token>)` form; the canonical token values come from the
  example app's `app.css` (which copies `prompts/cairnloop.css` :root).
  """
  use ExUnit.Case, async: true

  @web_dir Path.expand("../../../lib/cairnloop/web", __DIR__)
  @hex_fallback_pattern ~r/var\(--cl-[a-z-]+,\s*#/

  test "no hex-fallback strings remain in lib/cairnloop/web/ (BRAND-04)" do
    files = Path.wildcard(Path.join(@web_dir, "*.ex"))
    refute files == [], "expected .ex files under #{@web_dir}"

    violations =
      for file <- files,
          line_with_match <- file |> File.read!() |> String.split("\n") |> Enum.with_index(1),
          {line, line_no} = line_with_match,
          Regex.match?(@hex_fallback_pattern, line) do
        {Path.basename(file), line_no, String.trim(line)}
      end

    assert violations == [], """
    BRAND-04 contract violated — hex-fallback strings found in lib/cairnloop/web/.

    Phase 29 dropped all `var(--cl-<token>, #<hex>)` fallbacks. Use the bare
    `var(--cl-<token>)` form. Canonical token values are defined in
    examples/cairnloop_example/assets/css/app.css (copied from prompts/cairnloop.css).

    Violations (#{length(violations)}):
    #{Enum.map_join(violations, "\n", fn {f, n, l} -> "  #{f}:#{n} — #{l}" end)}
    """
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline hex fallback `var(--cl-primary, #A94F30)` as the headless-test contract | Bare `var(--cl-<token>)` + canonical `:root` block in `app.css` + negative-grep gate | Phase 29 (vM014, 2026-05-27) | The brand book's `:root` block becomes the only source of truth; sealed render files stop carrying hex codes; future palette tweaks happen in one file |
| Tailwind v3 `tailwind.config.js` color extension | Tailwind v4 `@theme { --color-* }` directive | Tailwind v4.0 GA (2025) | Pure CSS — no JS config file; primitive tokens go in `@theme`, semantic tokens stay in `:root` |
| `System.cmd("grep", …)` for source-scan gates | `File.read!` + `Regex.scan` ExUnit test | Established project pattern (vM011+) | More portable, deterministic, lives in the same lane as everything else |

**Deprecated/outdated in scope of this phase:**
- The 4-token `@theme` stub in `app.css` (lines 6-11) and the 4-token `:root` stub (lines 13-22) — replaced by the canonical block per D-06.
- The hex-fallback test-contract convention documented in `inbox_live.ex` moduledoc — superseded by the bare-token convention + negative-grep gate.
- The deferred D-10 carried decision in STATE.md / PROJECT.md — closed by this phase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Tailwind v4.1.12's `@theme` directive supports the `--color-cl-*` namespace and generates `bg-cl-*`, `text-cl-*`, `border-cl-*` utility classes for all 15 primitive color tokens | Pattern 1, Example A | LOW — verified against official Tailwind v4 docs [CITED: tailwindcss.com/docs/theme]; existing `app.css` already uses this pattern for 4 tokens; expanding to 15 is mechanical |
| A2 | Adding `--cl-on-primary: var(--cl-primary-text);` as an alias in `:root` is safer than renaming 4 occurrences of `--cl-on-primary` in sealed render code | Pitfall 3 | LOW — additive in `app.css` only, zero churn to sealed code; the alias is a 1-line addition; documented decision |
| A3 | The `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` 18 hex-fallback drops are in-scope for Phase 29 (extending BRAND-02 to the example app) | Pitfall 6, Open Questions | MEDIUM — CONTEXT.md scope is `lib/cairnloop/web/` ONLY. But phase Goal says "example app and library render surfaces." If the user wants the example app to stay byte-for-byte from Phase 28, this should be deferred. **The planner should treat this as a flagged decision** — see Open Questions Q1. |
| A4 | The rgba fallbacks (8 instances) and the 8 non-canonical token names (`--cl-overlay`, `--cl-shadow`, `--cl-danger-soft`, `--cl-primary-disabled`, `--cl-surface-translucent`, `--cl-text-soft`, `--cl-error`) are explicitly out of scope and deferred | Pitfall 2, Pitfall 3, Pitfall 6 | LOW — the deferred D-10 closure is hex-fallback-specific; rgba fallback closure can be a future cleanup. Document the deferred items in CONTEXT.md ratification notes / STATE.md. |
| A5 | The gate test must use `File.read!` + `Regex.scan` (project idiom), NOT `System.cmd("grep", …)` as suggested in CONTEXT.md D-08 | Pattern 2, Anti-Patterns | LOW — CONTEXT.md decisions are guidance on intent; the implementation technique should match project conventions. Established by 5+ existing source-scan tests. |
| A6 | `inbox_live.ex` moduledoc (lines 28-46) needs updating to reflect the new "bare-token, no fallback" convention; this is in-scope for the BRAND-02 plan | Pitfall 2 | LOW — leaving stale docs is a quality issue; project mandates warnings-clean builds and care with docs. Update is small (a few lines). |

**Items A3, A4, A6 should be discussed with the user during plan-checker review** if
they aren't already explicitly addressed in CONTEXT.md.

## Open Questions (RESOLVED)

1. **Is the example app's `chat_live.ex` (Phase 28 file, 18 hex fallbacks, uses non-canonical `--cl-error`) in-scope for Phase 29?**
   - What we know: Phase Goal mentions "example app and library render surfaces." CONTEXT.md scope is `lib/cairnloop/web/` only.
   - What's unclear: User intent — is the example app a frozen Phase 28 artifact, or part of the same "single source of truth" net Phase 29 is casting?
   - Recommendation: **Extend scope to include `chat_live.ex`.** It's small (18 sites), mechanical, prevents a stale-styling foot-gun, and the phase Goal explicitly mentions the example app. Also rename `--cl-error` → `--cl-danger` in the 2 sites (it's broken without the fallback anyway). Have the planner add a Plan-3 (or fold into Plan-2) covering this. If the user objects in discuss-phase, narrow back to `lib/` only. Flag clearly in CONTEXT.md ratification.
   - **RESOLVED — YES, extend scope.** `chat_live.ex` included in BRAND-02 per ROADMAP phase goal ("example app and library render surfaces"). Ratified in CONTEXT.md as D-10. Plan 02 Task 5 handles it.

2. **Should the gate test also scan `examples/cairnloop_example/lib/cairnloop_example_web/`?**
   - What we know: CONTEXT.md D-09 gate pattern targets `lib/cairnloop/web/`.
   - What's unclear: Same as Q1 — if `chat_live.ex` is in scope, the gate should scan there too.
   - Recommendation: **If Q1 = yes, extend gate to `lib/cairnloop/web/` AND `examples/cairnloop_example/lib/cairnloop_example_web/live/`.** Use two `Path.wildcard` calls, combine results, scan both. The gate then enforces the contract across both surfaces.
   - **RESOLVED — YES, extend gate.** Q1 resolved YES; gate extended to scan both surfaces. Plan 02 Task 1 implements the dual-scope gate.

3. **Should `--cl-on-primary` be aliased in `:root` (additive) or renamed in sealed code (4 sites)?**
   - What we know: `--cl-on-primary` is used 4× in `inbox_live.ex` + `conversation_live.ex`; it has no canonical definition. Closest match is `--cl-primary-text`.
   - What's unclear: Whether the user prefers additive (alias) or churn (rename).
   - Recommendation: **Alias.** Project convention is "additive only" and "seal completed phases" (CLAUDE.md). Adding 1 line in `app.css`'s `:root` keeps the sealed render code byte-perfect. The rename can be a vM015 cleanup if desired.
   - **RESOLVED — ALIAS.** `--cl-on-primary: var(--cl-primary-text);` added to `:root` in Plan 01 Task 1 (additive; zero sealed-code churn). Honors CLAUDE.md "Seal completed phases" directive.

4. **Should the moduledoc updates in `inbox_live.ex` (and any equivalent in `conversation_live.ex`) be a separate Plan or folded into BRAND-02 Plan?**
   - What we know: The moduledoc explicitly documents the hex-fallback test contract (lines 28-46). After the drop, those paragraphs become inaccurate.
   - What's unclear: Whether the planner wants a doc-only Plan or to bundle.
   - Recommendation: **Fold into BRAND-02 Plan** — same file, same commit, same review boundary. A separate doc-only Plan would be over-engineered for a paragraph-level update.
   - **RESOLVED — FOLDED.** `inbox_live.ex` moduledoc update (lines 28-46) folded into Plan 02 Task 2 per recommendation.

## Validation Architecture

> `workflow.nyquist_validation` is not present in `.planning/config.json` — defaults to enabled per researcher protocol.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir stdlib) |
| Config file | `config/test.exs` (Cairnloop.Repo sandbox, headless Endpoint) |
| Quick run command | `mix test` (DB-free, excludes `:integration`) |
| Full suite command | `mix test.integration` (DB-backed, requires Postgres + pgvector) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BRAND-01 | `app.css` contains canonical `:root` block + 15 `@theme` primitives + dark overrides | smoke (file-read assertion) | `mix test test/cairnloop/web/brand_token_gate_test.exs` (extend gate to also check `app.css` for canonical tokens) — OR simply rely on `mix assets.build` exit status + visual smoke | ❌ Wave 0 — new gate test file |
| BRAND-02 | Zero `var(--cl-<token>, #<hex>)` strings in `lib/cairnloop/web/` (and optionally `examples/cairnloop_example/lib/.../live/`) | unit (file-read + regex) | `mix test test/cairnloop/web/brand_token_gate_test.exs` | ❌ Wave 0 — new test file |
| BRAND-03 | 6 integration assertions match bare-token form, pass on `mix test.integration` | integration | `mix test.integration test/integration/approval_footer_live_test.exs test/integration/tool_execution_outcome_live_test.exs test/integration/bulk_recovery_live_test.exs` | ✓ — existing assertions, only the literal string changes |
| BRAND-04 | Gate test passes on default `mix test`; fails if a hex fallback is re-introduced | unit (file-read + regex) | `mix test test/cairnloop/web/brand_token_gate_test.exs` | ❌ Wave 0 — same file as BRAND-02 |

### Sampling Rate
- **Per task commit:** `mix test test/cairnloop/web/brand_token_gate_test.exs` (the gate runs in milliseconds, no DB needed) + `mix compile --warnings-as-errors`
- **Per wave merge:** `mix test` (full headless suite) + spot-check `mix test.integration test/integration/approval_footer_live_test.exs` if hex assertions were touched
- **Phase gate:** `mix test` green + `mix test.integration` green (or documented baseline failure per CLAUDE.md `Cairnloop.Automation.DraftTest`) + visual smoke of example app's `/inbox` and `/chat` pages after `mix assets.build`

### Wave 0 Gaps
- [ ] `test/cairnloop/web/brand_token_gate_test.exs` — covers BRAND-02 + BRAND-04 (the gate IS the test for both)
- [ ] No framework install needed; ExUnit + Elixir stdlib already present
- [ ] No new shared fixtures — gate test is self-contained file-read

## Security Domain

> `security_enforcement` config key is not set in `.planning/config.json`. Per researcher
> protocol (absent = enabled), security domain is included. However, **this phase is a
> CSS / inline-style refactor with no security surface**. ASVS categories below are
> evaluated for completeness.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a |
| V3 Session Management | no | n/a |
| V4 Access Control | no | n/a |
| V5 Input Validation | no | n/a — phase introduces no new inputs |
| V6 Cryptography | no | n/a |
| V7 Error Handling | no | n/a — phase doesn't change error paths |
| V14 Configuration | partial — `app.css` is a configuration file in the brand-token sense | Use canonical source (`prompts/cairnloop.css`); copy, don't fork; verify gate test passes |

### Known Threat Patterns for {CSS / Tailwind / inline styles}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| CSS injection via uncontrolled style attributes | Tampering | The phase TOUCHES inline `style=` attributes but the changes are byte-replacement of string literals in source code — no dynamic interpolation, no user input. **No risk introduced.** |
| Visual spoofing via brand-token misalignment (e.g., success-colored danger button) | Tampering / Spoofing | Brand book §7.5 mandates never-color-alone; existing tests assert "Refusal banner — SVG icon + heading text + token" (see `bulk_recovery_live_test.exs:264-267`). Phase 29 preserves these assertions. |

## Phase Constraints (from CLAUDE.md)

These directives from `./CLAUDE.md` constrain the plan and execution. The planner must
verify each is honored.

1. **Warnings-clean builds mandatory.** Every commit must pass `mix compile --warnings-as-errors`.
2. **`mix test` before declaring done.** Report failures honestly. (Note known baseline:
   `Cairnloop.Automation.DraftTest` — M005 drift — pre-existing, not a regression.)
3. **`Cairnloop.Repo` may be unavailable.** Prefer headless tests. ✓ Gate test is `File.read!` — no Repo needed.
4. **Seal completed phases.** Don't churn sealed render code (`propose/3`, idempotency,
   co-commit). ✓ Hex-fallback drop is a suffix removal — no semantic change to render
   logic; render structure stays byte-perfect except the removed `, #<hex>` suffix.
5. **Operator copy stays calm, fail-closed, reason-forward.** ✓ Phase doesn't change
   operator copy.
6. **Brand tokens over hardcoded hex.** ✓ Phase 29 IS this directive's closure (D-10).
7. **Decide for me; don't ask.** ✓ Research has decided on (a) `File.read!` over
   `System.cmd`, (b) alias `--cl-on-primary` over rename, (c) extend scope to
   `chat_live.ex` (flagged as Q1 for user veto), (d) fold moduledoc updates into BRAND-02
   plan. All flagged in Assumptions Log.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BRAND-01 | Canonical `:root` brand tokens (~30 semantic + ~15 primitive) imported into example app `app.css`; Tailwind `@theme` block extends them | Example A (full `app.css` block); Pattern 1 (Tailwind v4 `@theme` mechanics); D-04/D-05/D-06/D-07 specs in CONTEXT.md ratified |
| BRAND-02 | Inline `var(--cl-<token>, #<hex>)` strings dropped to bare `var(--cl-<token>)` in `lib/cairnloop/web/` (and per A3, optionally example app `chat_live.ex`) | Example B (mechanical drop); Pattern 3 (preserve byte-structure); Pitfalls 1, 2, 3, 6, 7 (gotchas) |
| BRAND-03 | 6 hex-fallback test assertions re-pinned to hex-free form across 3 files in `test/integration/` (NOT `test/cairnloop/web/` — those use prefix-only form already) | Example C; Pitfall 8 (closing-paren strictness); D-03 in CONTEXT.md corrects REQUIREMENTS.md file locations |
| BRAND-04 | Negative-grep gate enforces zero hex fallbacks; runs in `mix test` (default fast lane) | Example D (gate test); Pattern 2 (project idiom); Pitfall 5 (must NOT be `:integration`-tagged) |

## Sources

### Primary (HIGH confidence)
- `prompts/cairnloop.css` (verbatim canonical tokens) — Source of truth for BRAND-01
- `prompts/cairnloop.tokens.json` (token descriptions) — Token semantics reference
- `prompts/cairnloop_brand_book.md §7.3–7.5` (color proportions, semantic tokens, accessibility) — Brand book authority
- `tailwindcss.com/docs/theme` (Tailwind v4 `@theme` directive mechanics) — Verified utility-class generation behavior
- `.planning/REQUIREMENTS.md §Brand-Token CSS Extraction` (BRAND-01..04) — Phase requirements
- `.planning/STATE.md` (vM014 D-10 closure path) — Carried decision; Option B confirmed
- `.planning/phases/29-brand-token-css-extraction-d-10-closure/29-CONTEXT.md` — User-ratified decisions D-01..D-09
- Existing source tree (`lib/cairnloop/web/*.ex`, `examples/cairnloop_example/assets/css/app.css`, `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex`, `test/cairnloop/web/conversation_live_test.exs:1965`) — Counts, patterns, idioms verified by direct file read

### Secondary (MEDIUM confidence)
- (none — all critical claims verified against primary sources)

### Tertiary (LOW confidence)
- (none — phase is local and concretely scoped; no external research needed)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; Tailwind v4 + ExUnit already in place
- Architecture: HIGH — patterns are well-established project idioms (5+ existing source-scan tests)
- Pitfalls: HIGH — derived from direct file inspection (counts of hex per line, rgba fallbacks, non-canonical token names, moduledoc location, example app scope)
- Tailwind `@theme` behavior: HIGH — verified against current official docs

**Research date:** 2026-05-27
**Valid until:** 2026-06-27 (1 month — phase is mechanical and local; Tailwind v4 is GA stable; no fast-moving externals)
