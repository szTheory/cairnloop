# Phase 29: Brand-Token CSS Extraction (D-10 Closure) - Pattern Map

**Mapped:** 2026-05-27
**Files analyzed:** 7 (1 CSS, 4 source Elixir, 3 integration test, 1 new gate test)
**Analogs found:** 7 / 7

## Scope note

Phase 29 is a CSS / source-string contract phase, not a feature phase. There is no
"controller" or "service" surface. Roles below are the styling-stack analogues described
in the RESEARCH.md "Architectural Responsibility Map" (CSS asset, sealed render code,
integration test re-pin, headless source-scan gate). All seven files have strong analogs
in the existing tree, so PATTERNS.md is dense with concrete excerpts and short on
"no analog found."

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `examples/cairnloop_example/assets/css/app.css` | config / CSS asset | transform (Tailwind compile-time) | Itself (existing 4-token stub) + `prompts/cairnloop.css` (verbatim source) | exact — replace-in-place |
| `lib/cairnloop/web/inbox_live.ex` | LiveView render module (sealed) | request-response (render) | Itself (10 hex sites) + `lib/cairnloop/web/conversation_live.ex` (sibling render) | exact — mechanical suffix drop |
| `lib/cairnloop/web/conversation_live.ex` | LiveView render module (sealed) | request-response (render) | Itself (7 hex sites) + `inbox_live.ex` (sibling render) | exact — mechanical suffix drop |
| `lib/cairnloop/web/search_modal_component.ex` | Phoenix.Component (sealed) | request-response (render) | `inbox_live.ex` / `conversation_live.ex` (same inline-style convention) | exact — mechanical suffix drop |
| `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` | LiveView render (example app, sealed P28) | request-response (render) | `inbox_live.ex` (same convention, just lives in example app) | exact — mechanical suffix drop (RESEARCH A3 / Q1: flagged scope extension) |
| `test/cairnloop/web/brand_token_gate_test.exs` *(NEW)* | test (headless source-scan gate) | file-I/O (read + regex) | `test/cairnloop/web/conversation_live_test.exs:1948-1981` (3 source-scan tests in same file) | exact — established project idiom |
| `test/integration/approval_footer_live_test.exs` | integration test (LiveView assertion) | request-response (render assertion) | Itself (existing assertion) + `bulk_recovery_live_test.exs` (same form) | exact — literal-string re-pin |
| `test/integration/tool_execution_outcome_live_test.exs` | integration test (3 LiveView assertions) | request-response (render assertion) | Itself (existing assertions) | exact — literal-string re-pin |
| `test/integration/bulk_recovery_live_test.exs` | integration test (2 LiveView assertions) | request-response (render assertion) | Itself (existing assertions) | exact — literal-string re-pin |

## Pattern Assignments

### `examples/cairnloop_example/assets/css/app.css` (config / CSS asset, transform)

**Analog (REPLACE):** itself, the existing 4-token `@theme` + `:root` stub.
**Analog (SOURCE OF TRUTH):** `prompts/cairnloop.css` — copy verbatim per D-04.

**Existing structure to REPLACE** (`examples/cairnloop_example/assets/css/app.css:6-22`):
```css
@theme {
  --color-cl-basalt: #18211F;
  --color-cl-trailpaper: #F5F0E6;
  --color-cl-warm-stone: #FBF7EE;
  --color-cl-primary: #A94F30;
}

@layer base {
  :root {
    --cl-color-basalt: #18211F;
    --cl-color-trailpaper: #F5F0E6;
    --cl-color-warm-stone: #FBF7EE;
    --cl-color-path-copper: #A94F30;
    --cl-bg: var(--cl-color-trailpaper);
    --cl-primary: var(--cl-color-path-copper);
  }
}
```

**Replacement pattern** (research Example A — paste in same byte range):
```css
@theme {
  /* 15 primitive color tokens — generates bg-cl-*, text-cl-*, border-cl-*. */
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
    /* Primitives (mirror @theme — so var(--cl-color-*) refs resolve cleanly) */
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

    /* Semantic tokens — resolve to primitives */
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

    /* Alias for sealed render code (Pitfall 3 — additive, zero churn) */
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

  /* D-07 — dark-theme overrides immediately follow :root in the same @layer base */
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
```

**Preserve byte-for-byte** (everything outside the replaced range):
- Lines 1-5 — `@import "tailwindcss" source(none);` header
- Lines 24-26 — `@source` directives
- Lines 28-123 — heroicons plugin, daisyUI plugins, `@custom-variant`, LiveView wrapper rule

**Why this analog:** The existing `app.css` is *itself* the closest analog — the canonical
block is a strict superset of the stub it replaces (D-06). The stub establishes the exact
ordering (`@theme` → `@layer base { :root }`) and the `--color-cl-*` (theme) vs `--cl-color-*`
(semantic mirror) namespace split that the canonical block extends. Replacing in-place
preserves all the unrelated daisyUI / heroicons / LiveView wiring untouched.

---

### `lib/cairnloop/web/inbox_live.ex` (sealed render, request-response)

**Analog:** itself — same file is the analog because the pattern is "drop the
`, #<hex>` suffix from every `var(--cl-<token>, #<hex>)` substring on every line, and
update the moduledoc."

**Imports pattern** (`inbox_live.ex:1-5` — UNCHANGED):
```elixir
defmodule Cairnloop.Web.InboxLive do
  @moduledoc """
  Inbox surface — list of conversations + Phase 25 bulk-recovery cockpit.
```

**Existing inline-style hex pattern** (`inbox_live.ex:163-180` — sample for byte-exact drop):
```elixir
class="bulk-action-bar"
style="position: sticky; bottom: 0; background: var(--cl-surface-raised, #FFFFFF); border-top: 1px solid var(--cl-border, #D8D0BF); padding: 12px 16px; display: flex; gap: 12px; align-items: center; z-index: 10;"
>
  <span><%= MapSet.size(@selected_ids) %> selected</span>
  <button
    type="button"
    phx-click="clear_selection"
    style="min-height: 44px; padding: 10px 16px; border-radius: 8px; border: 1px solid var(--cl-border, #D8D0BF); background: transparent; color: var(--cl-text, #2f241d);"
  >
    Clear selection
  </button>
  <button
    type="button"
    phx-click="open_bulk_confirm"
    style="background: var(--cl-primary, #A94F30); color: var(--cl-on-primary, #fffdf8); border-radius: 8px; min-height: 44px; padding: 10px 16px; border: none; font-weight: 600;"
  >
```

**Drop pattern (Pattern 3 from research):**
Every `var(--cl-<token>, #<hex>)` becomes `var(--cl-<token>)`. ONLY remove `, #<hex>`.
No whitespace changes, no reordering, no class extraction. **Multiple hex per line is
common** (line 164 has 2; line 170 has 2; line 177 has 2) — Pitfall 1 from research.

After drop (same byte range):
```elixir
style="position: sticky; bottom: 0; background: var(--cl-surface-raised); border-top: 1px solid var(--cl-border); padding: 12px 16px; display: flex; gap: 12px; align-items: center; z-index: 10;"
...
style="min-height: 44px; padding: 10px 16px; border-radius: 8px; border: 1px solid var(--cl-border); background: transparent; color: var(--cl-text);"
...
style="background: var(--cl-primary); color: var(--cl-on-primary); border-radius: 8px; min-height: 44px; padding: 10px 16px; border: none; font-weight: 600;"
```

**Moduledoc update pattern** (`inbox_live.ex:28-46` — Pitfall 2 from research):
Existing text:
```elixir
## Brand tokens (WR-03)

Every color in this file is expressed as `var(--cl-<name>, <hex-or-rgba>)`
so a host stylesheet can override the cascade without touching this file.
The fallback values are inline so headless tests can assert the brand-token
vocabulary in rendered HTML (see `inbox_live_test.exs` "var(--cl-primary" /
"var(--cl-danger" gates). Future cleanup may extract the duplicated button
declarations (`min-height: 44px; padding: 10px 16px; border-radius: 8px;`)
to a stylesheet class once the project has a CSS pipeline; until then,
keeping the brand tokens visible in HTML is the test contract.
```

Replacement text (planner / executor crafts; keep the existing structure, just update
the convention statement):
```elixir
## Brand tokens (WR-03 / Phase 29 D-10 closure)

Every brand color in this file uses the bare `var(--cl-<name>)` form.
Canonical token values are defined in
`examples/cairnloop_example/assets/css/app.css` (copied from
`prompts/cairnloop.css`). The negative-grep gate
`test/cairnloop/web/brand_token_gate_test.exs` (BRAND-04) fails the build
if a `var(--cl-<name>, #<hex>)` fallback re-appears.

Token vocabulary still in use (see `prompts/cairnloop.css` for definitions):
`--cl-primary`, `--cl-on-primary` (aliased to `--cl-primary-text` in app.css),
`--cl-surface`, `--cl-surface-raised`, `--cl-border`, `--cl-text`,
`--cl-text-muted`, `--cl-danger`.

Non-canonical tokens that retain `rgba(...)` fallbacks (deferred to vM015):
`--cl-text-soft`, `--cl-overlay`, `--cl-shadow`, `--cl-danger-soft`,
`--cl-primary-disabled`, `--cl-surface-translucent`.
```

**Error handling / sealed-code constraint:** No `try/rescue`, no logic change. The phase
mandate (CLAUDE.md "Seal completed phases") means the render code is byte-perfect except
for the dropped `, #<hex>` suffix. No new functions, no new clauses, no reordering.

---

### `lib/cairnloop/web/conversation_live.ex` (sealed render, request-response)

**Analog:** itself + `inbox_live.ex` (sibling render with identical convention).

**Sample hex sites** (`conversation_live.ex` — confirmed line numbers from grep):
```elixir
# Line 530-531 — two hexes on adjacent lines
border: 1px solid var(--cl-primary, #A94F30);
background: var(--cl-primary, #A94F30);

# Line 992 — multiple style props on one line (single hex)
<button type="submit" style="padding: 6px 12px; background: var(--cl-primary, #A94F30); color: white; border: none; border-radius: 4px; cursor: pointer; align-self: flex-start;">Propose</button>

# Line 1378 — hex in a comment (Pitfall 1 candidate — gate regex WILL match)
Brand token var(--cl-primary, #A94F30) for primary affordance color (§2.2/§7). --%>

# Line 1388 — TWO hexes on one line
style="padding: 8px 16px; border-radius: 6px; border: 1px solid var(--cl-primary, #A94F30); background: var(--cl-primary, #A94F30); color: #fffdf8; font-size: 0.85rem; font-weight: 600; min-height: 36px; cursor: pointer;"
```

**Drop pattern:** Identical to `inbox_live.ex` — drop EVERY `, #<hex>` suffix the gate
regex `var\(--cl-[a-z-]+,\s*#` would match, including ones inside `<%!-- … --%>` HEEx
comments (line 1378). The bare `#fffdf8` literal on line 1388 (not preceded by `--cl-`)
is NOT in scope — gate regex requires the `var(--cl-...` prefix.

**Note on rgba fallback survival** (`conversation_live.ex:791` — keeps its rgba):
```elixir
style="margin: 6px 0 0; font-size: 14px; line-height: 1.4; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62));"
```
Gate regex `var\(--cl-[a-z-]+,\s*#` does NOT match `rgba(`. Stays as-is per A4
(deferred to vM015).

**Moduledoc:** `conversation_live.ex:1-5` is a bare `defmodule … use Phoenix.LiveView`
header with no moduledoc — NO doc update needed here (only `inbox_live.ex` has the
brand-tokens moduledoc).

---

### `lib/cairnloop/web/search_modal_component.ex` (sealed render, request-response)

**Analog:** `inbox_live.ex` / `conversation_live.ex` — same inline-style + hex-fallback
convention. This file was missed in REQUIREMENTS.md but is in scope per CONTEXT.md D-01.

**Sample hex sites** (`search_modal_component.ex` — confirmed line numbers from grep):
```elixir
# Line 71 — outline-color
style="width: 100%; padding: 16px; font-size: 16px; line-height: 1.5; border: 1px solid rgba(64, 51, 43, 0.12); border-radius: 12px; outline-color: var(--cl-primary, #A94F30); background: #fffdfa;"

# Line 78 — danger color
<div style="margin-bottom: 16px; padding: 16px; border-radius: 12px; background: rgba(181, 76, 54, 0.08); color: var(--cl-danger, #B54C36);">

# Line 151 — primary color in nested div
<div style="margin-top: 12px; font-size: 14px; color: var(--cl-primary, #A94F30); font-weight: 600;">

# Line 195 — long button style with primary
style="display: inline-flex; align-items: center; justify-content: center; min-height: 44px; padding: 0 16px; border-radius: 999px; text-decoration: none; background: var(--cl-primary, #A94F30); color: white; font-weight: 600;"
```

**Drop pattern:** Same as the two siblings. The bare `#fffdfa` / `#fff` literals NOT
preceded by `var(--cl-` are out of gate scope and stay as-is (these are background
literals, not token fallbacks).

---

### `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` (sealed P28 render, request-response)

**Analog:** `inbox_live.ex` — same hex-fallback convention, different host (example app
instead of library).

**Scope flag — RESEARCH A3 / Q1:** CONTEXT.md scope is `lib/cairnloop/web/` ONLY. The
researcher recommends extending to this file because (a) phase Goal mentions "example app
and library render surfaces," and (b) the file uses `--cl-error` (NOT canonical;
canonical is `--cl-danger`). **The planner must decide whether to fold this into Plan 2
or defer.** Recommended fold per A3.

**Sample hex sites** (`chat_live.ex`):
```elixir
# Line 50 — text-muted with hex
<span style="font-size: 13px; color: var(--cl-text-muted, #677066);">

# Line 58 — uses --cl-error (NOT canonical — needs rename to --cl-danger)
<p role="alert" style="font-size: 13px; color: var(--cl-error, #B23B2C); margin-bottom: 8px;">

# Line 72 — text-muted again
<p class="italic text-center mt-10" style="font-size: 15px; color: var(--cl-text-muted, #677066);">

# Line 100 — --cl-error again
<p role="alert" style="font-size: 13px; color: var(--cl-error, #B23B2C); margin-top: 4px;">
```

**Drop pattern:** Same suffix-removal mechanic, PLUS two rename sites:
`var(--cl-error, #B23B2C)` → `var(--cl-danger)` (lines 58, 100). The rename is required
because `--cl-error` is undefined in the canonical block — without the fallback the color
won't resolve.

**Gate test extension:** If this file is in scope, the BRAND-04 gate must add a second
`Path.wildcard` for `examples/cairnloop_example/lib/cairnloop_example_web/live/*.ex`.

---

### `test/cairnloop/web/brand_token_gate_test.exs` *(NEW)* (test, file-I/O)

**Analog:** `test/cairnloop/web/conversation_live_test.exs:1948-1998` — three source-scan
tests in the same file demonstrate the exact `__ENV__.file` walk-up + `File.read!` +
`assert source =~` / `refute source =~` idiom the gate needs.

**Imports + module pattern** (`conversation_live_test.exs` — header style):
```elixir
defmodule Cairnloop.Web.ConversationLiveTest do
  use ExUnit.Case, async: true
  ...
end
```

**Core source-scan pattern** (`conversation_live_test.exs:1948-1963` — direct excerpt):
```elixir
test "brand token var(--cl-primary) used in footer (§2.2/§7 — no hardcoded hex for affordance)" do
  # Source assertion: var(--cl-primary) must appear at least once (footer affordances)
  project_root =
    __ENV__.file
    |> Path.expand()
    |> Path.dirname()
    |> Path.dirname()
    |> Path.dirname()
    |> Path.dirname()

  source =
    File.read!(Path.join([project_root, "lib", "cairnloop", "web", "conversation_live.ex"]))

  assert source =~ "var(--cl-primary",
         "brand token var(--cl-primary) must be used in conversation_live (§2.2/§7)"
end
```

**Counter-example (negative scan)** (`conversation_live_test.exs:1965-1981`):
```elixir
test "no streams used in conversation_live (P14 D-02 plain-assign invariant)" do
  project_root =
    __ENV__.file
    |> Path.expand()
    |> Path.dirname()
    |> Path.dirname()
    |> Path.dirname()
    |> Path.dirname()

  source =
    File.read!(Path.join([project_root, "lib", "cairnloop", "web", "conversation_live.ex"]))

  refute source =~ "LiveView.stream(",
         "no Phoenix.LiveView.stream/3 must be used (P14 D-02 plain-assign invariant)"

  refute source =~ ~r/stream\([^)]+\).*stream/s
end
```

**New gate test (research Example D — full file to write):**
```elixir
defmodule Cairnloop.Web.BrandTokenGateTest do
  @moduledoc """
  BRAND-04 (Phase 29, D-10 closure): negative-grep gate that fails the build
  if any `var(--cl-<token>, #<hex>)` fallback string re-appears in
  `lib/cairnloop/web/`. After Phase 29, every brand-color reference uses the
  bare `var(--cl-<token>)` form; canonical token values are defined in
  `examples/cairnloop_example/assets/css/app.css` (copied from
  `prompts/cairnloop.css`).
  """
  use ExUnit.Case, async: true

  @web_dir Path.expand("../../../lib/cairnloop/web", __DIR__)
  @hex_fallback_pattern ~r/var\(--cl-[a-z-]+,\s*#/

  test "no hex-fallback strings remain in lib/cairnloop/web/ (BRAND-04)" do
    files = Path.wildcard(Path.join(@web_dir, "*.ex"))
    refute files == [], "expected .ex files under #{@web_dir}"

    violations =
      for file <- files,
          {line, line_no} <-
            file |> File.read!() |> String.split("\n") |> Enum.with_index(1),
          Regex.match?(@hex_fallback_pattern, line) do
        {Path.basename(file), line_no, String.trim(line)}
      end

    assert violations == [], """
    BRAND-04 contract violated — hex-fallback strings found in lib/cairnloop/web/.

    Phase 29 dropped all `var(--cl-<token>, #<hex>)` fallbacks. Use the bare
    `var(--cl-<token>)` form. Canonical token values live in
    examples/cairnloop_example/assets/css/app.css (copied from prompts/cairnloop.css).

    Violations (#{length(violations)}):
    #{Enum.map_join(violations, "\n", fn {f, n, l} -> "  #{f}:#{n} — #{l}" end)}
    """
  end
end
```

**Path-depth note:** `@web_dir` uses `../../../lib/...` (three `..`) because the file
lives at `test/cairnloop/web/brand_token_gate_test.exs`. The four-deep `Path.dirname`
walk-up in `conversation_live_test.exs` and the `Path.expand` form here are equivalent;
this PATTERNS.md recommends the `Path.expand("../../../...", __DIR__)` form because it's
a single module attribute (computed once, no per-test walk-up).

**Tagging (Pitfall 5):** NO `@tag :integration`. NO `@tag :slow`. `use ExUnit.Case,
async: true` so it runs under the default `mix test` fast lane.

**Optional: gate extension for example app** (only if Q1 = yes):
Add a second `Path.wildcard` for the example app's live dir:
```elixir
@example_live_dir Path.expand(
  "../../../examples/cairnloop_example/lib/cairnloop_example_web/live",
  __DIR__
)

# inside test:
files =
  Path.wildcard(Path.join(@web_dir, "*.ex")) ++
    Path.wildcard(Path.join(@example_live_dir, "*.ex"))
```

---

### `test/integration/approval_footer_live_test.exs` (integration test, request-response)

**Analog:** itself + `bulk_recovery_live_test.exs` (identical assertion form).

**Existing assertion** (`approval_footer_live_test.exs:48-58` — full context):
```elixir
test "footer renders Approve/Reject/Defer with a text label AND the brand color token", ctx do
  {:ok, view, html} = live(ctx.conn, "/governance/#{ctx.conversation.id}")

  # never-color-alone (brand §7.5): the affordance carries BOTH a text label and the token.
  assert html =~ "var(--cl-primary, #A94F30)"
  assert has_element?(view, "button[phx-click='approve_action']")
  ...
end
```

**Re-pin pattern (Pitfall 8 — keep the closing paren for strictness):**
```elixir
# BEFORE (line 52)
assert html =~ "var(--cl-primary, #A94F30)"

# AFTER
assert html =~ "var(--cl-primary)"
```

**Why the closing paren matters:** `"var(--cl-primary)"` is a strict substring — it asserts
the bare token IS present AND excludes the hex-fallback form. `"var(--cl-primary"` (no
paren) would also match `"var(--cl-primary, #foo)"` and silently allow regression.

---

### `test/integration/tool_execution_outcome_live_test.exs` (integration test, request-response)

**Analog:** itself — 3 assertions, identical form to `approval_footer_live_test.exs:52`.

**Existing assertion sample** (`tool_execution_outcome_live_test.exs:316-317`):
```elixir
assert html =~ "var(--cl-primary, #A94F30)",
       "Status chip must use brand token (never hardcoded hex)"
```

**Re-pin pattern:** Identical to approval_footer — drop `, #A94F30`, keep closing paren.
Apply at lines 316, 394, 443 (3 occurrences per CONTEXT.md D-03). The assertion message
strings stay byte-for-byte unchanged.

```elixir
# AFTER
assert html =~ "var(--cl-primary)",
       "Status chip must use brand token (never hardcoded hex)"
```

---

### `test/integration/bulk_recovery_live_test.exs` (integration test, request-response)

**Analog:** itself — 2 assertions: 1 primary (line 99), 1 danger (line 267).

**Existing primary assertion** (`bulk_recovery_live_test.exs:96-99`):
```elixir
assert html =~ "2 selected"
assert html =~ "Send recovery follow-up to 2"
# Brand §7.5 — text label AND token (never-color-alone).
assert html =~ "var(--cl-primary, #A94F30)"
```

**Existing danger assertion** (`bulk_recovery_live_test.exs:263-267`):
```elixir
# Refusal banner — never-color-alone: SVG icon + heading text + token.
assert html =~ "<svg"
assert html =~ "Batch too large."
assert html =~ "safe send limit of 2"
assert html =~ "var(--cl-danger, #B54C36)"
```

**Re-pin pattern (both forms):**
```elixir
# Line 99
assert html =~ "var(--cl-primary)"

# Line 267
assert html =~ "var(--cl-danger)"
```

Surrounding context comments and other assertions stay byte-for-byte unchanged.

---

## Shared Patterns

### Sealed-render invariant
**Source:** `CLAUDE.md` — "Seal completed phases. Don't churn sealed code paths."
**Apply to:** `inbox_live.ex`, `conversation_live.ex`, `search_modal_component.ex`,
`chat_live.ex` (example app, if Q1 = yes).
**Pattern:** The only allowed mutation is removing the `, #<hex>` suffix from
`var(--cl-<token>, #<hex>)`. No reordering of style attributes, no whitespace
normalization, no class extraction, no `defp` reshuffling. Diff hunks should be
single-line `,\s*#[0-9A-Fa-f]+\)` → `)` substitutions only (plus the optional
`inbox_live.ex` moduledoc update, which is a docstring change to a `@moduledoc`
string literal — no code semantic change).

### Headless source-scan idiom
**Source:** `test/cairnloop/web/conversation_live_test.exs:1948-1998` (3 examples).
**Apply to:** New gate test `test/cairnloop/web/brand_token_gate_test.exs`.
**Pattern:**
1. `use ExUnit.Case, async: true` (no `:integration` tag, no `:slow` tag).
2. Resolve project root with `Path.expand` + `__DIR__` (single module attribute) OR
   chained `Path.dirname` calls from `__ENV__.file`.
3. `File.read!` the target source files.
4. `Regex.match?` / `Regex.scan` / `String.split` + per-line check.
5. `assert violations == []` with a multi-line message identifying file + line + content.
6. No DB, no Endpoint, no LiveView setup — pure file-I/O.

### Integration-test re-pin (literal string)
**Source:** All 3 integration test files have identical `assert html =~ "var(--cl-…,
#<hex>)"` assertions.
**Apply to:** All 6 assertions across the 3 integration test files.
**Pattern:** Replace the substring `, #A94F30)` → `)` (or `, #B54C36)` → `)`). Keep the
closing paren in the assertion to maintain strictness (Pitfall 8). Keep any inline
comment / `assert ... , "message"` form unchanged.

### Tailwind v4 namespace split
**Source:** `examples/cairnloop_example/assets/css/app.css:6-22` (the stub being
replaced) + `prompts/cairnloop.css`.
**Apply to:** The single `app.css` edit.
**Pattern:**
- **`@theme { … }` block:** Only primitive color tokens (`--color-cl-basalt`,
  `--color-cl-fault-clay`, etc.) — generates Tailwind utility classes (`bg-cl-basalt`,
  `text-cl-fault-clay`).
- **`@layer base { :root { … } }` block:** Primitive mirrors (`--cl-color-*`) +
  semantic tokens (`--cl-primary`, `--cl-bg`, etc.) + typography + radius + shadow —
  CSS custom properties only, NOT Tailwind utilities.
- **`@layer base { [data-theme="dark"] { … } }` block:** Sibling to `:root` inside the
  same `@layer base`. Overrides the 14 semantic tokens only (no primitive overrides,
  no typography overrides).

### Decision-traceable moduledoc
**Source:** `inbox_live.ex:1-46` — moduledoc cites decision IDs (D-03, D-04, D-10, etc.)
inline.
**Apply to:** The updated `inbox_live.ex` moduledoc (Pitfall 2).
**Pattern:** New "Brand tokens" section cites Phase 29 D-10 closure, names the gate test
file, lists canonical tokens in use, and explicitly enumerates deferred non-canonical
tokens (so the next reader sees the gap without re-reading the rgba audit). Maintains
the project convention of decision-ID traceability in render-file moduledocs.

---

## Cross-cutting Constraints (from CLAUDE.md)

| Constraint | How Each File Honors It |
|------------|-------------------------|
| `mix compile --warnings-as-errors` clean | All edits are string substitutions or new ExUnit module — no API/typespec changes; new gate test follows established `ExUnit.Case` shape with no unused vars/aliases. Moduledoc edit is markdown-in-string. |
| `mix test` runs (Repo may be unavailable) | Gate test is pure `File.read!` — runs without Repo. All other edits don't change runtime behavior. Existing integration tests in `test/integration/` need Repo, but the changes are byte-replacements in literal strings, not new test logic. |
| Seal completed phases | `inbox_live.ex`, `conversation_live.ex`, `search_modal_component.ex`, `chat_live.ex` are sealed; only the suffix drop + moduledoc update touches them. Render-logic semantics unchanged. |
| Operator copy unchanged | No string visible to operators changes. The dropped hex was in `style=` attributes (not operator-facing prose), and the moduledoc is developer-facing. |
| Brand tokens over hardcoded hex | This phase IS this directive's D-10 closure. Hex moves OUT of render files INTO `app.css` `:root` (the canonical source). |
| Decide for me; don't ask | Researcher decided: (a) `File.read!` over `System.cmd("grep")`, (b) `--cl-on-primary` alias over rename, (c) extend scope to `chat_live.ex` (flagged Q1), (d) fold moduledoc into BRAND-02. Planner inherits these. |

---

## No Analog Found

None — every file in this phase has a strong analog. The gate test is novel only in name;
the pattern is established in `conversation_live_test.exs:1948-1998` and 4 other source-scan
tests across `test/cairnloop/`.

---

## Metadata

**Analog search scope:**
- `examples/cairnloop_example/assets/css/` (existing CSS asset)
- `lib/cairnloop/web/` (all sealed LiveView / Component modules)
- `test/cairnloop/web/` (headless unit tests with source-scan idiom)
- `test/integration/` (integration assertion form)
- `examples/cairnloop_example/lib/cairnloop_example_web/live/` (example app — scope flag)
- `prompts/cairnloop.css` (canonical source of truth)

**Files scanned:** 8 directly (`app.css`, `inbox_live.ex`, `conversation_live.ex`,
`search_modal_component.ex`, `chat_live.ex`, `conversation_live_test.exs`,
`approval_footer_live_test.exs`, `bulk_recovery_live_test.exs`,
`tool_execution_outcome_live_test.exs`) + 4 grep sweeps for `var(--cl-` and `File.read!`.

**Pattern extraction date:** 2026-05-27
