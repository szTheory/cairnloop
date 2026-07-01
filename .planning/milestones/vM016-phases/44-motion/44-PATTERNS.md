# Phase 44: Motion - Pattern Map

**Mapped:** 2026-06-05
**Files analyzed:** 8 (2 CSS, 1 component module, 3 LiveViews + 1 example shell, 2 new tests)
**Analogs found:** 8 / 8 (every surface has a concrete in-repo analog)

> Phase 44 is additive CSS motion + one new lib component. The motion *vocabulary*
> (tokens) and the reduced-motion handling already ship. There is **no new role**
> introduced — every file here copies an existing repo pattern. The two landmines
> from RESEARCH.md (`.cl-drawer` rendered nowhere; `.cl-motion-state` unused) are
> reflected in the attach-point assignments below.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `priv/static/cairnloop.css` (motion block additions) | config (stylesheet) | transform — static asset | self: existing `--cl-dur-*`/reduced-motion block `cairnloop.css:142-211` | exact (extend in-file) |
| `examples/cairnloop_example/priv/static/assets/css/app.css` (mirror) | config (stylesheet) | transform — static asset | the lib CSS it mirrors | exact (verbatim mirror) |
| `cl_flash/1` in `lib/cairnloop/web/components.ex` | component | event-driven (put_flash → render) | `cl_banner/1` + `cl_chip/1` (`components.ex:76-105`); example `flash/1` (`core_components.ex:56-86`) it replaces | role-match (hybrid) |
| `lib/cairnloop/web/home_live.ex` (hero count entrance) | LiveView (markup attach) | request-response (mount one-shot) | `search_modal_component.ex:65` (`phx-mounted={JS.focus()}`) | role-match |
| `lib/cairnloop/web/inbox_live.ex:204-206` (stagger container + `<li>`) | LiveView (markup attach) | event-driven (DOM insert) | self: existing `<ul class="cl-stack">` / `<li class="cl-row cl-list-row">` | exact (additive class) |
| `lib/cairnloop/web/conversation_live.ex:458,485` (gate flip + rail reveal) | LiveView (markup attach) | event-driven (class swap) + request-response (mount) | self: `message-status-chip` + `.evidence-rail`; `search_modal_component.ex:65` for the one-shot | exact (additive) |
| `examples/.../components/layouts.ex:85` (`flash_group` wiring) | component (shell) | event-driven | self: existing `flash_group/1` calling `flash/1` | exact (swap callee) |
| `test/cairnloop/web/motion_css_test.exs` (NEW) | test | file-I/O (string scan) | `test/cairnloop/web/brand_token_gate_test.exs` | exact (DB-free File.read! scan) |
| `examples/cairnloop_example/test/e2e/motion_test.exs` (NEW) | test (E2E) | request-response (browser) | `examples/cairnloop_example/test/e2e/rail_disclosure_test.exs` | exact |

---

## Pattern Assignments

### `priv/static/cairnloop.css` + example `app.css` (config, static asset)

**Analog:** itself — the existing Motion token block and reduced-motion block. ALL new rules
reuse these tokens; **do not define new `--cl-dur-*`/`--cl-stagger` values.**

**Token block to reuse** (`cairnloop.css:142-153`, identical at example `app.css:122-132`):
```css
--cl-dur-instant: 100ms;  /* press feedback, toggles */
--cl-dur-micro:   140ms;  /* tooltips, hover, icon swap */
--cl-dur-ui:      180ms;  /* dropdowns, badges, gate flip */
--cl-dur-panel:   260ms;  /* drawer / rail / source-card reveal */
--cl-dur-exit:    160ms;  /* dismissals — faster than entrance */
--cl-ease-out:    cubic-bezier(0.23, 1, 0.32, 1);
--cl-ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
--cl-ease-drawer: cubic-bezier(0.32, 0.72, 0, 1);
--cl-ease-linear: linear;
--cl-stagger:     50ms;
```

**Reduced-motion block to extend, NOT duplicate** (`cairnloop.css:197-211`). New entrance
animations must sit under `.cl-app` so this block zeroes them automatically. The
`.cl-motion-state` re-enable (lines 207-210) is the ONLY survivor — reuse that class name
for the gate flip so the survival is free:
```css
@media (prefers-reduced-motion: reduce) {
  .cl-app *, .cl-app *::before, .cl-app *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
  .cl-app .cl-motion-state {
    transition-duration: 120ms !important;
    transition-property: opacity, color, background-color, border-color !important;
  }
}
```

**New rules to author** (hex-free; transform+opacity only; all under `.cl-app`). Shape
from RESEARCH.md "Code Examples" — keyframes `cl-enter-up`, `cl-reveal-x`,
`cl-toast-enter`/`cl-toast-exit`; utility classes `.cl-motion-enter`, `.cl-motion-reveal`,
`.cl-list-stagger > li:nth-child(-n+5)` delays, `.cl-motion-state` transition, `.cl-toast`
surface. **Duration note (planner decision):** use `--cl-dur-micro` (140ms) for the hero
count entrance to be unambiguously `< 180ms` per MOTION-01 (`--cl-dur-ui` is exactly 180ms).

**Mirror rule (build-artifact landmine):** every new `@keyframes`/`.cl-motion-*`/`.cl-toast`
/stagger rule added to `cairnloop.css` (855 lines) must be copied **verbatim** into the
`.cl-*` region of example `app.css` (4166 lines — contains extra Tailwind/DaisyUI). Place
after the `.cl-app` block alongside existing `.cl-*` rules. **Do NOT touch** the DaisyUI
`@media (prefers-reduced-motion)` blocks at `app.css:3092` and `:3593` — they belong to the
example's own framework.

**Anti-patterns (string-testable):** no `width`/`height`/`top`/`left`/`max-height`/`max-width`
in any new rule; no `transition-property` on `.cl-hero__count` (`:770-773`) or
`.cl-stat__count` (`:421`); no `!important` motion outside `.cl-app`.

---

### `cl_flash/1` in `lib/cairnloop/web/components.ex` (component, event-driven)

**Analogs (hybrid):**
- **Markup shape / attr+slot conventions:** the lib's own `cl_banner/1` (`components.ex:88-105`)
  and `cl_chip/1` (`:76-86`) — `.cl-*` classes only, `role=`, auto-escaped slot.
- **Flash semantics (kind, dismiss idiom, phx-mounted):** the example `flash/1`
  (`core_components.ex:56-86`) it elevates/replaces.

**`use` + alias pattern at top of module** (`components.ex:25`): module currently only does
`use Phoenix.Component`. `cl_flash/1` needs `JS.transition` → **add
`alias Phoenix.LiveView.JS`** (the example flash uses `alias Phoenix.LiveView.JS` at
`core_components.ex:31`; the search component aliases it at `search_modal_component.ex:9`).

**attr/slot declaration pattern to copy** (lib `cl_banner/1`, `components.ex:88-93`):
```elixir
attr(:variant, :string, default: "neutral", values: @status_variants)
attr(:icon, :string, default: nil)
attr(:class, :string, default: nil)
attr(:rest, :global)
slot(:inner_block, required: true)
```
For flash, mirror the example's `kind`/`flash`/`id` attrs (`core_components.ex:48-54`):
```elixir
attr :id, :string
attr :flash, :map, default: %{}
attr :title, :string, default: nil
attr :kind, :atom, values: [:info, :error]
attr :rest, :global
slot :inner_block
```

**Brand-token markup pattern to copy** (lib `cl_banner/1`, `components.ex:99-104`) — `.cl-*`
classes + `role` + auto-escaped `{...}`, no hex:
```elixir
~H"""
<div class={["cl-banner", "cl-banner--#{@variant}", @class]} role="status" {@rest}>
  <.cl_icon name={@resolved_icon} class="cl-banner__icon" />
  <div>{render_slot(@inner_block)}</div>
</div>
"""
```

**Dismiss + enter/exit wiring to copy** (example `flash/1`, `core_components.ex:60-66`) —
keep the `lv:clear-flash` idiom; ADD the brand enter/exit transitions:
```elixir
# from example flash/1 — reuse the clear-flash dismiss idiom
phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
# ADD (D-08): enter on mount, exit faster on remove
phx-mounted={JS.transition("cl-toast-enter", time: 180)}
phx-remove={JS.transition("cl-toast-exit", time: 160)}
class="cl-toast"
```

**§7.5 + escaping guards:** keep the per-kind icon (distinct silhouette, like `cl_banner`'s
`status_icon/1`), use `{msg}` auto-escaped interpolation, NEVER `raw/1`, add
`aria-label="Dismiss"` on the close button.

**GATE-CRITICAL:** this file IS scanned by the brand-token gate (`lib/cairnloop/web/**/*.ex`).
Any bare hex, `var(--cl-x, #hex)` fallback, or raw `rgba()/rgb()/hsl()/hsla()` in the markup
fails it. Use only `var(--cl-*)` / `.cl-*`. (See Shared Patterns → Brand-Token Gate.)

---

### `lib/cairnloop/web/home_live.ex` — hero count entrance (LiveView, request-response)

**Analog:** `search_modal_component.ex:65` — the existing one-shot `phx-mounted` pattern.

**One-shot mount pattern to copy** (`search_modal_component.ex:59-72`):
```elixir
<input
  ...
  phx-mounted={JS.focus()}   # <-- the existing one-shot mount form
  class="cl-input"
/>
```
Apply the `JS.transition` sibling form to the hero count. The count is rendered inside
`cl_hero/1` (`components.ex:171`): `<span class={["cl-hero__count", ...]}>{@count}</span>`.
Two valid placements (planner call): add `phx-mounted` in `cl_hero/1`/`cl_stat/1` via a passed
attr, **or** at the `home_live.ex:124` call site. Either way:
```elixir
phx-mounted={JS.transition("cl-motion-enter", time: 140)}
```

**Negative assertion (criterion 3):** the `.cl-hero__count` text node must keep **no
`transition-property`** so live count ticks are instant; the entrance is an `animation`
(one-shot), which morphdom does not replay on in-place text patches. No number-roll/count-up.

---

### `lib/cairnloop/web/inbox_live.ex:204-221` — list stagger (LiveView, event-driven / DOM insert)

**Analog:** itself — the existing list. Additive class only; do NOT restructure or convert
to streams.

**Current markup** (`inbox_live.ex:204-206`):
```elixir
<ul class="cl-stack cl-inbox-list--bulk-clearance">
  <%= for conv <- @conversations do %>
    <li class="cl-row cl-list-row">
```
**Change:** add `cl-list-stagger` to the `<ul>`; the CSS `nth-child(-n+5)` delays drive the
≤5-item stagger on the existing `<li>`. Animation fires on DOM insert; morphdom does not
replay on attribute-only patches (bulk-select toggle at `:211`, filter, count change).

**D-05 INSERT-ONLY trade-off (carry into plan summary):** this is a plain `for` comprehension
(NOT a `stream/3`) — VERIFIED at `:205`. A CSS-only stagger WILL replay on navigate-away-and-back
because LiveView re-mounts the list. RESEARCH auto-decision (honor "seal completed phases / no
over-engineering"): **ship `nth-child` first-paint stagger; accept navigate-back replay** as a
calm, bounded (≤200ms, ≤5 items) behavior. Do NOT convert to streams. Flag for owner veto.

---

### `lib/cairnloop/web/conversation_live.ex` — gate flip (458) + rail reveal (485)

**Analog:** itself (both attach points) + `search_modal_component.ex:65` for the rail one-shot.

**(a) Gate state-flip — REUSE `.cl-motion-state`.** Target = the `message-status-chip`
(`conversation_live.ex:458`):
```elixir
<span class={["message-status-chip", outbound_status_class(msg)]}>
  <%= outbound_status %>
</span>
```
The class swap is driven by `outbound_status_class/1` (`:741-750`):
`status-pending` → `status-sent`/`status-failed`. **Change:** add `cl-motion-state` to the
class list so the morphdom class swap cross-fades at 180ms (survives reduced-motion at 120ms).

> **§7.5 verification task (RESEARCH A2 — NOT yet confirmed):** the chip already renders
> `<%= outbound_status %>` (label text from `outbound_status_label/1`). The planner MUST
> confirm that label text differs per state (e.g. "Pending"/"Sent"/"Failed") — `:457-460`
> renders one `outbound_status` var, and `:741-750` only swaps the *class*. If the visible
> label is identical across states, that is a §7.5 violation the motion would worsen; add
> distinct labels when wiring `.cl-motion-state`. (`.message-status-chip`/`.status-*` have no
> CSS rule today — the flip CSS is new.)

**(b) Rail reveal — one-shot mount (landmine: no drawer exists).** `.cl-drawer` is rendered
NOWHERE; the real rail is `.evidence-rail` (`conversation_live.ex:485`), a statically-present
flex column that mounts fresh per conversation:
```elixir
<div class="evidence-rail" data-density="comfortable" phx-hook=".RailDensity" id="evidence-rail-density">
```
**Interpretation (auto-decided):** treat "reveal" as a one-shot mount entrance — add
`phx-mounted={JS.transition("cl-motion-reveal", time: 260)}` (translateX(16px)→0 + opacity,
`--cl-dur-panel`/`--cl-ease-drawer`). Additive only — do NOT restructure the P41-sealed rail,
do NOT add `width`/`max-height` transitions. Flag this interpretation in the plan summary.

**Negative assertion:** the "Send Reply" `<.cl_button type="submit">` (`:480`) must carry NO
new `cl-motion-*` class. `.cl-button` already has a shipped universal micro-affordance
(`cairnloop.css:298-311`) — do NOT strip it; the assertion is "no NEW send-specific motion."

---

### `examples/.../components/layouts.ex:85-114` — flash_group wiring (component shell)

**Analog:** itself — the existing `flash_group/1` that calls `<.flash kind={:info} .../>`.

**Current** (`layouts.ex:85-89`):
```elixir
def flash_group(assigns) do
  ~H"""
  <div id={@id} aria-live="polite">
    <.flash kind={:info} flash={@flash} />
    <.flash kind={:error} flash={@flash} />
```
**Change (RESEARCH A4):** swap (or add alongside) the lib `cl_flash` so the new toast actually
renders and the E2E can see it. Keep the existing `phx-disconnected`/`phx-connected`
client-error/server-error flashes (`:91-113`) as-is — those are framework reconnection toasts,
not in scope. Import `cl_flash` from `Cairnloop.Web.Components` into the example components.

---

### `test/cairnloop/web/motion_css_test.exs` (NEW test, file-I/O string scan)

**Analog:** `test/cairnloop/web/brand_token_gate_test.exs` — copy its DB-free, pure-`File.read!`
string-scan shape exactly.

**Module/header pattern to copy** (`brand_token_gate_test.exs:1-23`):
```elixir
defmodule Cairnloop.Web.MotionCssTest do
  @moduledoc """
  ...
  This test is DB-free (pure File.read!/string scan).
  # REPO-UNAVAILABLE: no assertions require a Postgres round-trip.
  """
  use ExUnit.Case, async: true
```

**Path-resolution pattern to copy** (`:42-46`) — `Path.expand(..., __DIR__)`:
```elixir
@lib_css   Path.expand("../../../priv/static/cairnloop.css", __DIR__)
@example_css Path.expand(
  "../../../examples/cairnloop_example/priv/static/assets/css/app.css", __DIR__)
```

**Read-and-scan pattern to copy** (`:172-177`) — `File.read!` + `String.split("\n")` +
`Enum.with_index(1)` + `Regex.match?`:
```elixir
violations =
  for {line, line_no} <- css |> File.read!() |> String.split("\n") |> Enum.with_index(1),
      Regex.match?(@forbidden_layout_prop, line) do
    {line_no, String.trim(line)}
  end
assert violations == [], "..."
```

**Assertions to encode (Wave 0):**
1. No new motion rule names a forbidden layout property (`width`/`height`/`top`/`left`/
   `max-height`/`max-width`). Regex over `@keyframes cl-*` / `.cl-motion-*` / `.cl-toast` blocks.
2. Mirror parity: every new `@keyframes`/`.cl-motion-*`/`.cl-toast` block present in BOTH
   `cairnloop.css` and example `app.css` (substring presence in each file).
3. `.cl-hero__count` / `.cl-stat__count` rules contain no `transition-property`.

---

### `examples/cairnloop_example/test/e2e/motion_test.exs` (NEW E2E)

**Analog:** `examples/cairnloop_example/test/e2e/rail_disclosure_test.exs`.

**Header/case pattern to copy** (`rail_disclosure_test.exs:1-31`):
```elixir
defmodule CairnloopExampleWeb.MotionE2ETest do
  @moduledoc """..."""
  use PhoenixTest.Playwright.Case, async: false
  @moduletag :e2e
  import CairnloopExample.RailFixtures   # or the relevant fixture

  setup do
    %{conv_id: conv_id} = pending_governed_action_conversation()
    %{conv_id: conv_id}
  end
```

**Visit + phx-connected gate pattern to copy** (`:38-43`) — wait for connect before asserting
JS-driven state:
```elixir
conn
|> visit("/support/#{conv_id}")
|> assert_has("body .phx-connected")
```

**Computed-style assertion uses `evaluate/3`** (`rail_disclosure_test.exs:81-83` shows the
`evaluate(conn, js, fn value -> ... end)` shape; reuse it with `getComputedStyle`):
```elixir
evaluate(conn, "getComputedStyle(document.querySelector('.cl-hero__count')).animationName", fn v ->
  assert v == "cl-enter-up"
end)
```

**Assertions to encode:** hero `animation-name: cl-enter-up` + duration < 180ms and no
`transition-property` on the count text; rail transition is transform/opacity only; reply-send
button carries no `cl-motion-*` class; under `emulateMedia({reducedMotion: 'reduce'})` the
transform animations ~0.01ms but `.cl-motion-state` stays 120ms.

---

## Shared Patterns

### One-shot mount entrance (`phx-mounted={JS.transition(...)}`)
**Source:** `lib/cairnloop/web/search_modal_component.ex:65` (`phx-mounted={JS.focus()}` — same JS family).
**Apply to:** hero count (`home_live.ex`/`cl_hero`), `.evidence-rail` (`conversation_live.ex:485`),
`cl_flash/1` enter. Requires `alias Phoenix.LiveView.JS` in the module (already present in the
search component `:9` and example flash `core_components.ex:31`; **must be added** to
`components.ex` which currently only does `use Phoenix.Component`).
```elixir
phx-mounted={JS.transition("cl-motion-enter", time: 140)}   # hero
phx-mounted={JS.transition("cl-motion-reveal", time: 260)}  # rail
phx-mounted={JS.transition("cl-toast-enter", time: 180)}    # toast
phx-remove={JS.transition("cl-toast-exit", time: 160)}      # toast exit
```

### Reduced-motion survival via `.cl-motion-state`
**Source:** `priv/static/cairnloop.css:207-210` (re-enable block, already shipped + mirrored).
**Apply to:** the gate-flip chip ONLY (`conversation_live.ex:458`). Reusing this exact class
name is what makes the meaning-bearing cross-fade survive reduced-motion for free — do not
invent a second reduced-motion exception.

### Brand-token gate safety (criterion 4)
**Source:** `test/cairnloop/web/brand_token_gate_test.exs:28-35` (the three scanned patterns).
**Apply to:** `cl_flash/1` in `components.ex` and the `layouts.ex` wiring (both `.ex` =
scanned). CSS files are NOT scanned (structurally excluded). Keep scanned `.ex` clear of:
```elixir
@hex_fallback_pattern ~r/var\(--cl-[a-z-]+,\s*#/   # var(--cl-x, #hex) — FORBIDDEN
@hex_color            ~r/#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b/  # bare hex
@func_color           ~r/\b(?:rgba?|hsla?)\(/      # raw rgba/hsl
```
Use only bare `var(--cl-*)` and `.cl-*` classes in `cl_flash/1`. The existing gate test
auto-covers the new component — no new gate test needed for this.

### Two-file CSS mirror (build-artifact sync)
**Source:** established convention; token block parity `cairnloop.css:142-153` ≡ `app.css:122-132`.
**Apply to:** every new `.cl-*`/`@keyframes` rule. Lib canonical `priv/static/cairnloop.css`
(855 lines) → example `app.css` (4166 lines). Verbatim copy into the `.cl-*` region; never
touch the DaisyUI sections (`app.css:3092`, `:3593`). The `motion_css_test.exs` mirror-parity
assertion guards this.

### `.ex` markup escaping (XSS in toast)
**Source:** lib component convention (`cl_fact_list/1` docstring `components.ex:216`: "never `raw/1`").
**Apply to:** `cl_flash/1` — interpolate flash strings with auto-escaped `{msg}`, never `raw/1`.

---

## No Analog Found

None. Every Phase 44 file copies an existing in-repo pattern. The two RESEARCH landmines are
**missing render targets**, not missing patterns:

| Item | Role | Data Flow | Note |
|------|------|-----------|------|
| `.cl-drawer` reveal target | LiveView markup | request-response | `.cl-drawer` CSS exists but is rendered nowhere; re-targeted to `.evidence-rail` one-shot mount (analog: `search_modal_component.ex:65`). Not a missing pattern. |
| `.cl-motion-state` consumer | LiveView markup | event-driven | Class defined but zero usages; first consumer is the `message-status-chip` (`conversation_live.ex:458`). Pattern (class-swap cross-fade) is standard CSS. |

---

## Metadata

**Analog search scope:** `lib/cairnloop/web/` (components, home/inbox/conversation LiveViews,
search modal), `priv/static/cairnloop.css`, `examples/cairnloop_example/` (core_components,
layouts, app.css, test/e2e), `test/cairnloop/web/`.
**Files scanned:** 11 read (+ targeted greps).
**Pattern extraction date:** 2026-06-05
