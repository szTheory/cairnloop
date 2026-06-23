# Phase 37: Component Primitives - Pattern Map

**Mapped:** 2026-06-03
**Files analyzed:** 3 modified files (2 source + 1 test) holding 8 new components, 1 narrowed attr, 3 tokens, 3 utilities, 1 scroll-wrapper class, 4 inline call-site wrappers
**Analogs found:** 8 / 8 components have an in-repo analog (no net-new-from-scratch primitives)

> **Read first:** `37-CONTEXT.md` (D-01..D-13), `37-RESEARCH.md` (patterns 1–5, pitfalls), `37-UI-SPEC.md`
> (per-primitive visual/interaction contract). This file maps each new artifact to the closest
> **existing** code in `lib/cairnloop/web/components.ex`, `priv/static/cairnloop.css`, and
> `test/cairnloop/web/components_test.exs`, with file:line excerpts to copy from. Every locked decision
> is upstream; this file does not re-litigate — it grounds the planner/executor in concrete analogs.

---

## File Classification

| New/Modified Artifact | Role | Data Flow | Closest Analog | Match Quality |
|-----------------------|------|-----------|----------------|---------------|
| `cl_page/1` (components.ex) | component (shell/layout) | request-response (render-only) | `cl_card/1` (components.ex:56) + `cl_shell/1` (components.ex:161) | role-match (slotted container) |
| `cl_hero/1` (components.ex) | component (display tile) | request-response (render-only) | `cl_stat/1` (components.ex:137) + `cl_button/1` (CTA, components.ex:41) | exact (count tile sibling) |
| `cl_stat/1` narrowing (components.ex:128) | component (attr contract) | request-response (render-only) | itself — `attr :count, :any` → `:integer` | exact (in-place edit) |
| `cl_disclosure/1` (components.ex) | component (native disclosure) | event-driven (BROWSER-owned open) | `.cl-details` CSS (cairnloop.css:477) + `cl_card` slot idiom | role-match (wraps `<details>`) |
| `cl_fact_list/1` (components.ex) | component (dl/dt/dd list) | request-response (render-only) | `.cl-details dl/dt/dd` (cairnloop.css:483) + `cl_stat` `:for` idiom | role-match (label/value pairs) |
| `cl_source_card/1` (components.ex) | component (status surface) | request-response (render-only) | `cl_banner/1` (components.ex:95) + `cl_chip/1` variant+icon (components.ex:76) | exact (variant→token+icon) |
| `cl_status_cell/1` (components.ex) | component (thin wrapper) | request-response (render-only) | `cl_chip/1` (components.ex:76) — delegates directly | exact (composition wrapper) |
| `cl_switch/1` (components.ex) | component (toggle control) | event-driven (SERVER-owned `checked`) | `cl_button/1` (components.ex:41) — `:rest` global + `<button>` | exact (button + `:rest`) |
| 3 layout tokens (cairnloop.css) | config (CSS tokens) | n/a | `:root` control-sizing block (cairnloop.css:130-133) | exact (token-block convention) |
| 3 inert utilities (cairnloop.css) | utility (CSS) | n/a | `.cl-row`/`.cl-stack` family (cairnloop.css:423-427) | role-match (single-purpose flex) |
| `.cl-table-scroll` (cairnloop.css + 4 inline wraps) | utility + markup | n/a | `.cl-focusable:focus-visible` (cairnloop.css:236) for focus ring | role-match (a11y wrapper) |
| 8 render tests (components_test.exs) | test | n/a | existing `rendered_to_string(~H...)` tests (components_test.exs:12-102) | exact (established idiom) |

**Tier-correctness flag (from RESEARCH §Architectural Responsibility Map):** `cl_disclosure` open state is
**browser-owned** (native `<details>` + `phx-update="ignore"`); `cl_switch` `checked` is **server-owned**
(LiveView assign via `:rest` `phx-click`). These sit on opposite tiers by design — do not bind disclosure
`open` to an assign, and do not make the switch client-only.

---

## Shared Patterns

### Pattern A — Variant→class string interpolation (status primitives)
**Source:** `cl_chip/1` (components.ex:81) and `cl_banner/1` (components.ex:100)
**Apply to:** `cl_source_card` (`cl-source-card--#{@source_variant}`), `cl_status_cell` (passes `variant` through to `cl_chip`).
```elixir
# components.ex:81 (cl_chip) — the variant-suffix class idiom + :rest passthrough
<span class={["cl-chip", "cl-chip--#{@variant}", @class]} {@rest}>
  <.cl_icon name={@resolved_icon} class="cl-chip__icon" />
  <span>{@label}{render_slot(@inner_block)}</span>
</span>
```
The enum is declared once as a module attribute and reused — copy this convention:
```elixir
# components.ex:27 — single source for the 6 status variants
@status_variants ~w(success info warning danger ai neutral)
# used as: attr(:variant, :string, default: "neutral", values: @status_variants)
```

### Pattern B — Distinct-silhouette icon per variant (never-color-alone, §7.5)
**Source:** `status_icon/1` map (components.ex:245-250) + `assign_new` resolution (components.ex:78, 97)
**Apply to:** `cl_source_card` (header icon), `cl_status_cell` (via `cl_chip`).
```elixir
# components.ex:78 (cl_chip) — resolve icon from variant unless explicitly overridden
assign_new(assigns, :resolved_icon, fn -> assigns.icon || status_icon(assigns.variant) end)
```
```elixir
# components.ex:245-250 — the variant→silhouette map (reuse, do NOT hand-author new SVG)
defp status_icon("success"), do: "check-circle"
defp status_icon("info"),    do: "info"
defp status_icon("warning"), do: "alert-triangle"
defp status_icon("danger"),  do: "x-circle"
defp status_icon("ai"),      do: "waypoint"
defp status_icon(_),         do: "clock"
```
**Invariant:** every status-bearing primitive renders color + `cl_icon` (distinct silhouette) + a visible
text label. UI-SPEC §Color maps `success`=`check-circle`, `info`=`info`, etc. — same map already shipped.

### Pattern C — `:rest` global with explicit `include:` allowlist
**Source:** `cl_button/1` (components.ex:35-37)
**Apply to:** `cl_switch` (so `phx-click`/`phx-value-*` reach the caller's LiveView).
```elixir
# components.ex:35-37 (cl_button) — the global-attr passthrough template
attr(:rest, :global,
  include: ~w(disabled form name value phx-click phx-value-id phx-disable-with data-confirm)
)
```
For `cl_switch`, RESEARCH Pitfall 5 requires the allowlist to carry the toggle wiring:
`include: ~w(phx-click phx-value-id phx-value-key disabled form name value)` — `phx-value-*` are NOT
default globals, so omitting them silently drops the toggle binding.

### Pattern D — Optional-slot emptiness guard
**Source:** `cl_card/1` (components.ex:59), `cl_empty/1` (components.ex:118)
**Apply to:** `cl_page` `:actions`/`:breadcrumb`/`:subnav`, `cl_hero` `:detail`, `cl_source_card` `:meta`, `cl_fact_list` `inner_block`.
```elixir
# components.ex:59 (cl_card) — render a named slot only when the caller supplied it
<header :if={@header != []} class="cl-card__header">{render_slot(@header)}</header>
```

### Pattern E — Token-purity (NO hex / inline style in .ex)
**Source:** moduledoc rule (components.ex:16-24) — components emit `.cl-*` classes only; all color/spacing
lives in `cairnloop.css` as bare `var(--cl-*)`.
**Enforced by:** `test/cairnloop/web/brand_token_gate_test.exs` (scans `lib/cairnloop/web/**/*.ex` for
`var(--cl-token, #hex)` via `@hex_fallback_pattern ~r/var\(--cl-[a-z-]+,\s*#/`) + the new per-primitive
`refute html =~ ~r/#[0-9a-fA-F]{3,6}/`. The gate passes for free if no `.ex` emits hex — keep all CSS in
`cairnloop.css`. **Anti-pattern to avoid:** the drifted `conversation_live.ex` `<details style="…#hex…">`
(RESEARCH Pitfall 4) — do NOT copy that into the new primitive.

### Pattern F — CSS token-block + bare `var(--cl-*)` convention
**Source:** `:root` control-sizing block (cairnloop.css:130-133); the `--cl-space-*` ladder (cairnloop.css:87-101).
**Apply to:** the 3 new layout tokens (place near control-sizing block).
```css
/* cairnloop.css:130-133 — token-block convention to mirror */
/* ---- Control sizing (buttons + inputs share heights) ------------------- */
--cl-control-h-sm: 28px; --cl-control-px-sm: 10px;
--cl-control-h-md: 36px; --cl-control-px-md: 14px;
--cl-control-h-lg: 44px; --cl-control-px-lg: 20px;
```
New tokens (D-09 / UI-SPEC §Spacing) — values grounded in existing magic numbers (`.cl-main` max-width
1200px at cairnloop.css:254; `.evidence-rail` width 352px at cairnloop.css:509):
```css
--cl-content-max: 1200px;
--cl-rail-width:  352px;
--cl-page-gutter: var(--cl-space-5);   /* = 16px */
```
**Footgun honored (D-09):** `var()` is illegal inside `@media` conditions — these tokens drive `max-width`
*values* only, never breakpoint *conditions*. Breakpoints stay literal (that work is P43).

---

## Pattern Assignments

### `cl_page/1` (component, render-only) — UIC-01 / D-08

**Analogs:** `cl_card/1` (components.ex:56, multi-slot container) + `cl_shell/1` (components.ex:161, page chrome).

**Slot/attr API to copy** — enum width attr (single attr, NOT two booleans), required default slot + optional named slots:
```elixir
# Derived from cl_card (slot + :if guard) — see RESEARCH Pattern 2
attr(:title, :string, required: true)
attr(:subtitle, :string, default: nil)
attr(:width, :string, values: ~w(wide reading), default: "wide")
slot(:actions)
slot(:breadcrumb)
slot(:subnav)
slot(:inner_block, required: true)
```
**Container + slot-guard markup** (mirror `cl_card` components.ex:56-62, reuse `.cl-row`/`.cl-row--between` from cairnloop.css:423-424):
```elixir
<div class={["cl-page", "cl-page--#{@width}"]}>
  <header class="cl-page__header">
    <div :if={@breadcrumb != []}>{render_slot(@breadcrumb)}</div>
    <div class="cl-row cl-row--between">
      <div>
        <h1 class="cl-page__title">{@title}</h1>
        <p :if={@subtitle} class="cl-page__subtitle">{@subtitle}</p>
      </div>
      <div :if={@actions != []}>{render_slot(@actions)}</div>
    </div>
  </header>
  <div :if={@subnav != []} class="cl-page__subnav">{render_slot(@subnav)}</div>
  <div class="cl-page__body">{render_slot(@inner_block)}</div>
</div>
```
**CSS analog for width modifiers** — token-referencing modifier classes (new `.cl-page*` rules):
```css
.cl-page--wide    { max-width: var(--cl-content-max); margin: 0 auto; padding: 0 var(--cl-page-gutter); }
.cl-page--reading { max-width: var(--cl-rail-width);  margin: 0 auto; padding: 0 var(--cl-page-gutter); }
```
**Compose note:** `cl_page` renders *inside* `cl_shell`'s `.cl-main` (components.ex:182); the existing
`cl_breadcrumb/1` (components.ex:194) is passed into the `:breadcrumb` slot — do not re-author breadcrumb markup.

---

### `cl_hero/1` (component, render-only) — UIC-02 / D-02

**Analogs:** `cl_stat/1` (components.ex:137, count tile) for structure; `cl_button/1` (components.ex:41) for the primary CTA.

**`cl_stat` structure to mirror** (the count-tile anatomy `cl_hero` is a heavier sibling of):
```elixir
# components.ex:137-149 (cl_stat) — copper count + job label + meta; cl_hero ~2-3× weight
<.link navigate={@href} class="cl-stat cl-focusable" {@rest}>
  <span class="cl-stat__job">…{@job}</span>
  <span class={["cl-stat__count", @calm? && "cl-stat__count--calm"]}>{@count}</span>
  <span :if={@meta} class="cl-stat__meta">{@meta}</span>
  …
</.link>
```
**CSS analog** — copy `.cl-stat__count` and clone heavier into `.cl-hero__count`:
```css
/* cairnloop.css:413-414 — the copper display numeral + calm variant to clone at 48px */
.cl-stat__count       { font-family: var(--cl-font-display); font-size: 32px; line-height: 1; color: var(--cl-primary, #A94F30); }
.cl-stat__count--calm { color: var(--cl-success, #4A6238); }
```
New `.cl-hero__count` = same family/color at **48px** (UI-SPEC §Typography "Hero count"); `--calm` switches
to `--cl-success`. **CTA precedence** (RESEARCH Open Q1, planner-pinned): explicit `:detail`/CTA slot wins;
when no CTA slot, render `<.cl_button variant="primary" navigate={@href}>{@cta}</.cl_button>` (analog: components.ex:41).

---

### `cl_stat/1` narrowing (attr contract) — UIC-02 / D-01

**Analog:** itself — a single-line attr type change.
```elixir
# components.ex:128 — CHANGE this one line:
attr(:count, :any, required: true)      # before (semantics-bug: accepts number OR health string)
attr(:count, :integer, required: true)  # after  (single-purpose numeric tile)
```
All other `cl_stat` attrs (`job`, `meta`, `href`, `cta`, `icon`, `calm?`, `:rest`, `inner_block`) and the
`.cl-stat` CSS stay unchanged. No P37-scope caller passes a non-integer (RESEARCH A2; `home_live` passes
integers) — narrowing is safe with no migration task. Health strings route through `cl_chip` in P39, not here.

---

### `cl_disclosure/1` (component, browser-owned open) — UIC-03 / D-03

**Analogs:** existing `.cl-details` CSS (cairnloop.css:477-485) — reuse, emit no new disclosure CSS; `cl_card` slot idiom for the `:summary` + `inner_block`.

**CSS already shipped — reuse verbatim (cairnloop.css:477-485):**
```css
.cl-details > summary { cursor: pointer; color: var(--cl-info, #3F6F80); font-size: var(--cl-font-small, 13px); list-style: none; }
.cl-details > summary::-webkit-details-marker { display: none; }
.cl-details dl { margin: var(--cl-space-3, 8px) 0 0; font-size: var(--cl-font-small, 13px); }
.cl-details dt { color: var(--cl-text-muted, #677066); font-size: var(--cl-font-micro, 12px); }
.cl-details dd { margin: 0 0 var(--cl-space-3, 8px); }
```
**THE critical pattern (RESEARCH Pattern 3 / Pitfall 1) — patch-safe native disclosure:**
```elixir
attr(:id, :string, required: true)     # REQUIRED — phx-update="ignore" mandates a unique DOM id
attr(:open, :boolean, default: false)  # static-at-mount ONLY; NEVER an assign-driven toggle
slot(:summary, required: true)
slot(:inner_block, required: true)

def cl_disclosure(assigns) do
  ~H"""
  <details class="cl-details cl-disclosure" id={@id} phx-update="ignore" open={@open}>
    <summary class="cl-details__summary">{render_slot(@summary)}</summary>
    {render_slot(@inner_block)}
  </details>
  """
end
```
`phx-update="ignore"` + stable `id` is the verified diff-survival mechanism (a PubSub re-render cannot snap
the panel shut). HEEx renders `open={@open}` as a boolean attribute (present when `true`). **Forward-compat
guardrail to carry to P41 (RESEARCH Pitfall 2):** the ignored subtree freezes child content after mount, so
any live-updating content an adopter places inside must live *outside* the `<details>`.

---

### `cl_fact_list/1` (component, render-only) — UIC-04 / D-05

**Analogs:** `.cl-details dl/dt/dd` styling (cairnloop.css:483-485) for the visual idiom; the `:for` comprehension from `cl_stat`/`cl_shell` (components.ex:171) for row iteration.

**Decision (UI-SPEC §5, ratified):** dedicated `.cl-fact-list` CSS, NOT reuse of `.cl-details dl` — because
the `.cl-details dl/dt/dd` rules are scoped *inside* `.cl-details` and `cl_fact_list` is a standalone primitive.
**Markup:**
```elixir
attr(:facts, :list, default: [])   # [%{label: string, value: string}]
slot(:inner_block)

def cl_fact_list(assigns) do
  ~H"""
  <dl class="cl-fact-list">
    <div :for={fact <- @facts} class="cl-fact-list__row">
      <dt class="cl-fact-list__label">{fact.label}</dt>
      <dd class="cl-fact-list__value">{fact.value}</dd>
    </div>
    {render_slot(@inner_block)}
  </dl>
  """
end
```
New `.cl-fact-list*` CSS mirrors the `.cl-details dt`/`dd` color/size tokens (muted micro label, body value).

---

### `cl_source_card/1` (component, render-only) — UIC-04 / D-06

**Analogs:** `cl_banner/1` (components.ex:95, variant surface + icon + slot) and `cl_chip/1` variant idiom; `cl_icon` for the header silhouette.

**`cl_banner` structure to mirror (components.ex:95-104):**
```elixir
# variant→class + resolved icon + slotted body — the same shape cl_source_card needs
def cl_banner(assigns) do
  assigns = assign_new(assigns, :resolved_icon, fn -> assigns.icon || status_icon(assigns.variant) end)
  ~H"""
  <div class={["cl-banner", "cl-banner--#{@variant}", @class]} role="status" {@rest}>
    <.cl_icon name={@resolved_icon} class="cl-banner__icon" />
    <div>{render_slot(@inner_block)}</div>
  </div>
  """
end
```
**`cl_source_card` API** (uses `source_variant` per D-06; `:title` required slot + optional `:meta`):
```elixir
attr(:source_variant, :string, values: ~w(success info neutral warning danger ai), default: "neutral")
slot(:title, required: true)
slot(:meta)
slot(:inner_block)
```
Emit `cl-source-card--#{@source_variant}` (Pattern A) + a header `cl_icon` resolved from the variant (Pattern B).
**Drift-map contract (UI-SPEC §Color / P40 swap):** `success` replaces inline `#4A6238`; `info` replaces `#3F6F80`.
New `.cl-source-card--{variant}` CSS uses the **same status-token triplet** the chips use:
```css
/* cairnloop.css:344-348 (cl_chip variants) — copy the surface/border/text triplet shape */
.cl-chip--success { background: var(--cl-success-surface); border-color: var(--cl-success-border); color: var(--cl-success-text); }
.cl-chip--info    { background: var(--cl-info-surface);    border-color: var(--cl-info-border);    color: var(--cl-info-text); }
```

---

### `cl_status_cell/1` (component, thin wrapper) — UIC-04 / D-07

**Analog:** `cl_chip/1` (components.ex:76) — delegates directly; do NOT re-author chip markup.
```elixir
attr(:variant, :string, values: ~w(success info warning danger ai neutral), default: "neutral")
attr(:label, :string, required: true)   # always-visible label — never color alone (§7.5)
attr(:icon, :string, default: nil)

def cl_status_cell(assigns) do
  ~H"""
  <span class="cl-status-cell">
    <.cl_chip variant={@variant} label={@label} icon={@icon} />
  </span>
  """
end
```
**Grounding correction (D-07, verified):** `AuditLogPresenter.action_tone/1` does NOT exist — only
`action_label/1` (`lib/cairnloop/web/audit_log_presenter.ex`). `cl_status_cell` takes `variant`+`label`
**directly**; it MUST NOT call a non-existent fn. The tone-mapping is added in P38/P40 at adoption time.
Only new CSS is a minimal `.cl-status-cell` wrapper span; chip CSS is unchanged.

---

### `cl_switch/1` (component, server-owned `checked`) — UIC-04 / D-04

**Analog:** `cl_button/1` (components.ex:41) — `<button>` + `:rest` global passthrough.
```elixir
attr(:checked, :boolean, required: true)
attr(:label, :string, required: true)    # always-visible label — never color alone (§7.5)
attr(:rest, :global, include: ~w(phx-click phx-value-id phx-value-key disabled form name value))

def cl_switch(assigns) do
  ~H"""
  <button type="button" class="cl-switch" role="switch" aria-checked={to_string(@checked)} {@rest}>
    <span class="cl-switch__track"><span class="cl-switch__thumb"></span></span>
    <span class="cl-switch__label">{@label}</span>
  </button>
  """
end
```
**Critical (RESEARCH Pitfall 3):** `aria-checked={to_string(@checked)}` — a raw boolean would emit a boolean
HTML attribute (present/absent); ARIA needs the literal string `"true"`/`"false"`. **`:rest` (Pitfall 5):**
`phx-value-*` are not default globals — they MUST be in `include:` or the toggle binding silently drops.
**44px tap target (UI-SPEC §Spacing exception, P43 RESP-02 preemptive):** `.cl-switch { min-height: 44px;
min-width: 44px }`. Disabled style mirrors `.cl-button:disabled` (cairnloop.css:304: `opacity: 0.5; cursor: not-allowed`).

---

### 3 inert utilities (CSS) — UIC-05 / D-10

**Analog:** `.cl-row`/`.cl-stack` family (cairnloop.css:423-427) — single-purpose flex composables.
```css
/* cairnloop.css:423-427 — the existing composite layout primitives (PREFERRED; keep using these) */
.cl-row         { display: flex; align-items: center; gap: var(--cl-space-3, 8px); }
.cl-row--between { justify-content: space-between; }
.cl-row--wrap   { flex-wrap: wrap; }
.cl-stack       { display: flex; flex-direction: column; gap: var(--cl-space-3, 8px); }
.cl-stack--lg   { gap: var(--cl-space-5, 16px); }
```
Define **exactly three** new escape-hatch utilities (no utility framework — D-10):
```css
.cl-gap-2          { gap: var(--cl-space-2); }
.cl-align-center   { align-items: center; }
.cl-justify-between { justify-content: space-between; }
```
These sit on a flex container; `.cl-row`/`.cl-stack` remain the preferred composites.

---

### `.cl-table-scroll` wrapper (CSS + 4 inline markup sites) — UIC-05 / D-11

**Analog:** `.cl-focusable:focus-visible` (cairnloop.css:236-239) for the focus-ring token reuse; no new component (D-11).
```css
/* cairnloop.css:236-239 — focus-ring convention to mirror on .cl-table-scroll:focus-visible */
.cl-focusable:focus-visible {
  outline: none;
  box-shadow: var(--cl-focus-ring);
  border-radius: var(--cl-radius-xs, 4px);
}
```
New CSS:
```css
.cl-table-scroll { overflow-x: auto; -webkit-overflow-scrolling: touch; }
.cl-table-scroll:focus-visible { box-shadow: var(--cl-focus-ring); border-radius: var(--cl-radius-xs); }
```
**Inline wrapper markup applied at the 4 confirmed `.cl-table` call sites** (verified by grep, below):
```heex
<div class="cl-table-scroll" role="region" tabindex="0" aria-label="{descriptive label}">
  <table class="cl-table">…</table>
</div>
```
| Call site | Line | `<table>` (note) | Recommended `aria-label` |
|-----------|------|------------------|--------------------------|
| `lib/cairnloop/web/audit_log_live.ex` | 129 | `class="cl-table"` | "Audit log" |
| `lib/cairnloop/web/knowledge_base_live/index.ex` | 78 | `class="cl-table"` | "Knowledge base articles" |
| `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` | 220 | `class="cl-table"` | "Suggested KB edits" |
| `lib/cairnloop/web/settings_live.ex` | 246 | `class="cl-table cl-mb-7"` (keep the extra `cl-mb-7`) | "Policies" |

---

### 8 render tests (test, headless) — UIC-01..05 / D-12

**Analog:** the existing `rendered_to_string(~H...)` Repo-free idiom (components_test.exs:12-102).
```elixir
# components_test.exs:6-39 — the exact harness + assertion idiom to extend (NOT replace the file)
use ExUnit.Case, async: true
import Phoenix.Component
import Phoenix.LiveViewTest
import Cairnloop.Web.Components

test "cl_chip pairs color + icon + text (never state-by-color-alone)" do
  assigns = %{}
  html =
    rendered_to_string(~H"""
    <.cl_chip variant="warning" label="Needs review" />
    """)
  assert html =~ "cl-chip--warning"
  assert html =~ "<svg"            # distinct-silhouette icon present, not color alone
  assert html =~ "Needs review"
end
```
**Per-primitive structural markers to assert (UI-SPEC §Token-Purity Verification + RESEARCH §Validation):**
- every primitive: `refute html =~ ~r/#[0-9a-fA-F]{3,6}/` (token-purity, UIC-04 / SC-4)
- `cl_disclosure`: `assert html =~ "<details"`, `=~ ~s(phx-update="ignore")`, `=~ ~s(id=)`, `=~ "open"`
- `cl_switch`: `=~ ~s(role="switch")`, `=~ ~s(aria-checked="false")` (string, not boolean), `=~ label`, `=~ ~s(phx-click="…")` (`:rest` passthrough)
- `cl_status_cell`: `=~ "cl-chip"` + visible label text
- `cl_source_card`: `=~ "<svg"` (icon present, never color alone) + `=~ "cl-source-card--success"`
- `cl_page`: `=~ title`, `=~ "cl-page--wide"`/`"cl-page--reading"`, slots present
- `cl_hero`: `=~ "cl-hero__count"`, copper count rendered as integer
- `.cl-table-scroll` (asserted at primitive-pattern or call-site level): `=~ ~s(role="region")`, `=~ ~s(tabindex="0")`

**Note:** all tests are Repo-free / fast default suite — **no `# REPO-UNAVAILABLE` markers needed** (D-12).
LV 1.1 test parser is `lazy_html`, not Floki — keep string `=~` assertions (parser-agnostic), do not add Floki
DOM selectors (RESEARCH Pitfall 6). Optional: a tiny CSS-presence ExUnit test reading `priv/static/cairnloop.css`
for the 3 tokens / 3 utilities / `.cl-table-scroll` literals to machine-verify UIC-05's CSS half (planner's call).

---

## No Analog Found

None. Every new primitive composes or mirrors an existing `components.ex`/`cairnloop.css` analog. The genuinely
net-new **CSS** (`.cl-hero`, `.cl-page*`, `.cl-fact-list*`, `.cl-source-card*`, `.cl-switch*`, `.cl-table-scroll`,
3 layout tokens, 3 utilities) follows established token-block / BEM conventions (Patterns A, F) — no novel
architecture, no external dependency, no registry surface. RESEARCH confirms ~half the phase is composition of
already-shipped primitives.

---

## Metadata

**Analog search scope:** `lib/cairnloop/web/components.ex` (319 lines, full read), `priv/static/cairnloop.css`
(token block 125-149, control sizing 130-133, button 290-317, card 322-328, chip 336-348, banner 352-354,
stat 403-415, row/stack 423-427, details 477-485, main 254, evidence-rail 509),
`test/cairnloop/web/components_test.exs` (full read), `test/cairnloop/web/brand_token_gate_test.exs` (gate regex),
`lib/cairnloop/web/audit_log_presenter.ex` (D-07 grounding via upstream RESEARCH).
**Files scanned for `.cl-table` call sites:** 4 confirmed via `grep -rn 'cl-table' lib/cairnloop/web/`.
**Pattern extraction date:** 2026-06-03

---

## PATTERN MAPPING COMPLETE

**Phase:** 37 - Component Primitives
**Files classified:** 3 modified files holding 8 new components + 1 attr narrowing + 3 tokens + 3 utilities + 1 scroll-wrapper + 4 inline wraps + 8 tests
**Analogs found:** 8 / 8 components (plus CSS-token, utility, test, and a11y-wrapper analogs)

### Coverage
- Components with exact analog: 5 (`cl_hero`→`cl_stat`/`cl_button`, `cl_source_card`→`cl_banner`/`cl_chip`, `cl_status_cell`→`cl_chip`, `cl_switch`→`cl_button`, `cl_stat` narrowing→itself)
- Components with role-match analog: 3 (`cl_page`→`cl_card`/`cl_shell`, `cl_disclosure`→`.cl-details`, `cl_fact_list`→`.cl-details dl`)
- Components with no analog: 0

### Key Patterns Identified
- All status primitives use `cl-x--#{@variant}` interpolation + the shared `@status_variants` enum + `status_icon/1` silhouette map (never color alone, §7.5) — `cl_chip`/`cl_banner` are the templates.
- `:rest` global with an explicit `include:` allowlist is the toggle-wiring pattern (`cl_button` template); `phx-value-*` must be listed or it drops.
- `cl_disclosure` is browser-owned (`phx-update="ignore"` + required stable `id`, reusing shipped `.cl-details` CSS); `cl_switch` is server-owned (`checked` assign, `aria-checked={to_string(...)}`) — opposite tiers by design.
- Tests extend the established `rendered_to_string(~H...)` Repo-free idiom with `refute html =~ ~r/#hex/` token-purity + structural markers; no Floki, no `REPO-UNAVAILABLE`.

### File Created
`/Users/jon/projects/cairnloop/.planning/phases/37-component-primitives/37-PATTERNS.md`

### Ready for Planning
Pattern mapping complete. Every new artifact is anchored to a concrete `components.ex`/`cairnloop.css`/
`components_test.exs` analog with file:line excerpts. The planner can reference these directly in PLAN.md action steps.
