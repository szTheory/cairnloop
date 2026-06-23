# Phase 37: Component Primitives - Research

**Researched:** 2026-06-03
**Domain:** Phoenix LiveView 1.1 stateless function components + design-system CSS (Elixir / Phoenix / Ecto host-owned library)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

All thirteen decisions D-01..D-13 are **RATIFIED and locked** (see `37-CONTEXT.md`). Research
refines HOW, never re-litigates. Verbatim digest:

### Locked Decisions
- **D-01** — De-polymorphize `cl_stat`: `count :any` → `count :integer, required: true`. Single-purpose
  navigable number tile; health strings no longer flow through it. `.cl-stat` CSS unchanged.
- **D-02** — Hero is a **separate** `cl_hero/1` component, NOT `cl_stat variant="hero"`. Carries
  `count :integer` (copper), title/job label, a `:detail` slot, and a primary CTA (slot or `cta`/`href`
  attrs). New `.cl-hero` CSS gives ~2–3× count weight. *(Flagged for cheap veto — additive, reversible.)*
- **D-03** — `cl_disclosure/1` wraps native `<details class="cl-details">`/`<summary>`. Open state is
  **NEVER bound to a server assign**. Slots `:summary` (required) + `inner_block`; attrs `open :boolean`
  (rendered ONLY as the static HTML `open` attribute at initial render) and a stable required `id`.
  **Patch-safety mechanism to pin in research** — confirmed below: `phx-update="ignore"` on `<details>`.
- **D-04** — `cl_switch/1` is a real `<button role="switch" aria-checked={...}>`, not a checkbox.
  Server-controlled toggle; `checked` boolean, `label`, `:rest` global for `phx-click`/`phx-value-*`.
  Token-pure; never-color-alone label always present.
- **D-05** — `cl_fact_list/1` renders a `<dl>` of `[%{label, value}]` + optional `inner_block`.
- **D-06** — `cl_source_card/1` takes `source_variant` mapping to status tokens (≥ success/info/neutral).
  Token-pure; no inline hex.
- **D-07** — `cl_status_cell/1` is tone-agnostic; takes `variant` (+ `label`) and renders a table-sized
  `cl_chip`. **Grounding correction (verified):** `AuditLogPresenter.action_tone/1` does NOT exist —
  presenter only has `action_label/1`. `cl_status_cell` MUST NOT depend on a non-existent fn.
- **D-08** — `cl_page/1` shell: `title`, `subtitle`, `width :string in ~w(wide reading) default "wide"`
  (single enum attr, not two booleans). Slots `:actions`, `:breadcrumb`, `:subnav`, `inner_block`.
  Renders **inside** the existing `.cl-main` (`cl_shell` stays the outer chrome).
- **D-09** — Add layout tokens `--cl-content-max`, `--cl-rail-width`, `--cl-page-gutter`. **Never
  tokenize breakpoints** — `var()` is illegal in `@media` conditions (P43 owns breakpoints).
- **D-10** — Define exactly three inert utilities: `.cl-gap-2`, `.cl-align-center`, `.cl-justify-between`.
  Do NOT grow a utility framework. `.cl-row`/`.cl-stack` remain preferred composites.
- **D-11** — `.cl-table-scroll` CSS class + inline wrapper markup, no new component. Wrap existing
  `.cl-table` instances in `<div class="cl-table-scroll" role="region" tabindex="0" aria-label="…">`.
- **D-12** — Token-purity proved by headless `render_component/2` tests (no Repo/DB) extending
  `test/cairnloop/web/components_test.exs`.
- **D-13** — Components must already pass the **current** brand-token gate (hardening is P40).

### Claude's Discretion
- Exact attr names/defaults and slot ordering within each component.
- Whether `cl_fact_list` reuses `.cl-details dl/dt/dd` styling or gets a dedicated `.cl-fact-list`
  (UI-SPEC §5 resolves this to a **dedicated `.cl-fact-list`** — see Architecture below; rationale ratified).
- The precise `cl_disclosure` patch-safety guard — **resolved by this research to `phx-update="ignore"`**
  (the invariant "no assigns-bound open" is locked; the mechanism is now pinned).

### Deferred Ideas (OUT OF SCOPE)
- `AuditLogPresenter.action_tone/1` — added in P38/P40 when the audit screen wires `cl_status_cell`.
- A `cl_table` wrapper component — not built now (D-11); reconsider only if call-site count makes inline
  wrapping unwieldy (P43).
- Adoption of any primitive into a live screen — that is P38–P45. P37 stops at **built + unit-tested**.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UIC-01 | `cl_page` shell with `title`/`subtitle`/`:actions`/`:breadcrumb`/`:subnav` slots + `:wide`/`:reading` widths | Slot/attr API patterns (Pattern 2); layout-token width contract (Pattern 5); `cl_breadcrumb` already exists in `components.ex:194` and can be passed into the `:breadcrumb` slot |
| UIC-02 | `cl_stat` de-polymorphized to numeric-only + `cl_hero` primary hero count | `attr :integer, required: true` narrowing (Pattern 1); `.cl-hero` CSS at 48px Fraunces; no callers in P37 scope to migrate |
| UIC-03 | `cl_disclosure`/`cl_details` SSR/patch-safe with no server-assigns open state | **`phx-update="ignore"` confirmed** as the diff-survival mechanism (Pattern 3, Pitfall 1) — HIGH confidence, official LV bindings doc |
| UIC-04 | `cl_fact_list`, `cl_source_card` (`source_variant`), `cl_status_cell`, `cl_switch` (`role="switch"`), token-pure | `role="switch"`+`aria-checked` button pattern (Pattern 4); `to_string/1` on aria value (Pitfall 4); status-token delegation to existing `cl_chip`; refute-hex assertion idiom |
| UIC-05 | Layout tokens + inert-utility CSS defs + `.cl-table` overflow scroll wrapper | Token placement in `:root` block (Pattern 5); 3 utility defs (D-10); `.cl-table-scroll` applied to 4 confirmed call sites |
</phase_requirements>

---

## Summary

Phase 37 is a **pure additive primitives phase** in a Phoenix LiveView 1.1.30 / Phoenix 1.8.7
/ OTP 28 codebase. Every deliverable is either a stateless `Phoenix.Component` function in
`lib/cairnloop/web/components.ex` (which already houses 9 such components following a strict
"markup-only, CSS is the single source of visual truth, tokens-never-hex" convention) or a CSS
addition to the shipped `priv/static/cairnloop.css`. There are **no new dependencies**, no build
step, and no React/shadcn surface — the UI-SPEC's `shadcn_initialized: false` is correct.

The single load-bearing technical risk — D-03's patch-safety for `<details open>` — is now
**resolved with HIGH confidence**. The official Phoenix LiveView bindings documentation states
that `phx-update="ignore"` causes "updates from the server to the element's content and attributes
[to be] ignored, except for data attributes," and that "a unique DOM ID must always be set in the
container." This is exactly the locked CONTEXT D-03 mechanism: a stable required `id` plus
`phx-update="ignore"` on the `<details>` element means LiveView's diff/patch algorithm will never
re-drive the `open` attribute after the initial server render, so a PubSub-triggered re-render
cannot snap the panel shut. The browser's native `<details>` toggle owns the open state entirely.

The testing approach is already established in the repo: `test/cairnloop/web/components_test.exs`
uses `rendered_to_string(~H""" … """)` (the idiom the official `Phoenix.LiveViewTest` docs
*recommend* for complex/slotted components over `render_component/3`). These run in the fast
default suite with **no Repo and no live DB**, satisfying the `Cairnloop.Repo`-may-be-unavailable
caveat cleanly. Token-purity is asserted with `refute html =~ ~r/#[0-9a-fA-F]{3,6}/` plus
structural-marker assertions (`role="switch"`, `<details`, `phx-update="ignore"`, `role="region"`).

**Primary recommendation:** Build all eight primitives as stateless `Phoenix.Component` functions
following the exact existing `components.ex` conventions; pin `cl_disclosure` patch-safety to
`phx-update="ignore"` + required stable `id`; render `aria-checked` via `to_string(@checked)`;
test every primitive with `rendered_to_string(~H...)` Repo-free; add CSS to `cairnloop.css` using
bare `var(--cl-*)` tokens only. Wrap the 4 confirmed `.cl-table` instances inline.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `cl_page` page framing (title/width/slots) | Frontend render (HEEx component) | CSS (`cairnloop.css`) | Pure markup + class emission; width logic is a CSS modifier class, not server logic |
| `cl_hero` / `cl_stat` count tiles | Frontend render | CSS | Stateless presentation; count value supplied by caller's LiveView assigns (not this phase) |
| `cl_disclosure` open/close state | **Browser (native `<details>`)** | Frontend render (static `open` at mount only) | LOCKED invariant: open state lives client-side; server must NOT own it (`phx-update="ignore"`) |
| `cl_switch` toggle state | **API/LiveView server** (`checked` assign) | Frontend render (`aria-checked` reflects server state) | Server-controlled toggle; `:rest` carries `phx-click` back to the LiveView that owns the assign |
| `cl_fact_list` / `cl_source_card` / `cl_status_cell` | Frontend render | CSS | Pure presentation; status tokens delegate to existing `cl_chip` triplets |
| Layout tokens / inert utilities | **CSS (`cairnloop.css`)** | — | Design-system layer; referenced by components but owned by the stylesheet |
| `.cl-table-scroll` accessible wrapper | Frontend markup (inline) + CSS | — | Per-call-site `<div>` wrapper + one CSS rule; no component (D-11) |

**Tier-correctness note for the planner:** `cl_disclosure` open state and `cl_switch` checked state
sit on **opposite** tiers by design. The disclosure is client-owned (browser), the switch is
server-owned (LiveView assign). Do not let a task accidentally bind disclosure `open` to an assign
or make the switch client-only — both would violate locked decisions (D-03, D-04).

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix_live_view` | **1.1.30** (`mix.lock`) | `Phoenix.Component`, `attr`/`slot` macros, `~H` sigil, `phx-update` directive | The codebase's render layer; all primitives are `Phoenix.Component` functions |
| `phoenix` | **1.8.7** (`mix.lock`) | HEEx engine, HTML safety | Transitive host framework |
| `phoenix_html` | **4.3.0** (`mix.lock`) | `Phoenix.HTML.raw/1` (used by `cl_icon`), attribute rendering | Already used for inline SVG icons |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Phoenix.LiveViewTest` | bundled with LV 1.1.30 | `rendered_to_string/1`, `render_component/3` | Headless component tests (extend `components_test.exs`) |
| `lazy_html` | `~> 0.1` (LV 1.1 test parser) | HTML parsing in LiveViewTest | Pulled in transitively; **note** LV 1.1 uses `lazy_html`, not Floki — irrelevant for string-based `=~` assertions but relevant if any test uses `element/2` selectors |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `rendered_to_string(~H...)` | `render_component/3` | Both are non-deprecated and Repo-free. Official docs **recommend `~H`/`rendered_to_string` for complex/slotted components**; the repo already standardizes on it (all 6 existing component tests use it). Use `rendered_to_string`. CONTEXT/UI-SPEC say "`render_component/2`" loosely — treat as "headless component render"; the repo idiom is `rendered_to_string`. |
| Native `<details>` for `cl_disclosure` | `Phoenix.LiveView.JS` show/hide | Locked OUT for this primitive (D-03): JS-driven disclosure reintroduces a state surface. `JS` is reserved for P41 rail-level Expand-all/Collapse-all controls only. |
| `<button role="switch">` for `cl_switch` | `<input type="checkbox">` | Locked OUT (D-04): a real `role="switch"` button is the LiveView server-controlled-toggle idiom; checkbox semantics conflate form submission with a server-state toggle. |

**Installation:** None. Zero new dependencies (UI-SPEC Registry Safety: all "not applicable").

**Version verification:** `mix.lock` confirms `phoenix 1.8.7`, `phoenix_live_view 1.1.30`,
`phoenix_html 4.3.0` `[VERIFIED: mix.lock in repo]`. Note `mix.exs` pins `phoenix_live_view ~> 1.0`
but the lock resolved to **1.1.30** — the 1.1 line is what actually runs; `phx-update="ignore"`
and `render_component/3` semantics below are for the 1.1 docs `[VERIFIED: hexdocs phoenix_live_view 1.1.x]`.

## Package Legitimacy Audit

**Not applicable — this phase installs zero external packages.** All work is additive to two
existing files (`components.ex`, `cairnloop.css`) using already-locked dependencies. No npm, no
hex, no component registry. slopcheck not required (no install step). UI-SPEC Registry Safety
section confirms: shadcn none, third-party none, npm/hex none.

---

## Architecture Patterns

### System Architecture Diagram

```
                         caller LiveView (P38+ — NOT this phase)
                                      │ assigns (count, checked, facts, …)
                                      ▼
        ┌──────────────────────────────────────────────────────────────┐
        │  Cairnloop.Web.Components  (lib/cairnloop/web/components.ex)   │
        │  stateless Phoenix.Component functions — markup only          │
        │                                                               │
        │  cl_page ─┬─ header(title/subtitle/:breadcrumb/:actions)      │
        │           ├─ :subnav slot                                     │
        │           └─ .cl-page__body { inner_block }                   │
        │                                                               │
        │  cl_hero ── copper count + :detail + CTA(slot|cta/href attrs) │
        │  cl_stat ── (narrowed: count :integer)                        │
        │  cl_disclosure ── <details phx-update="ignore" id=.. open?>   │ ◀── open state
        │  cl_fact_list ── <dl> of facts + inner_block                  │     owned by
        │  cl_source_card ── variant→status tokens + cl_icon            │     BROWSER
        │  cl_status_cell ── delegates → cl_chip (sized for cell)       │     (never an
        │  cl_switch ── <button role="switch" aria-checked=..> {@rest}  │ ◀── assign)
        └───────────────┬──────────────────────────────────────────────┘
                        │ emits .cl-* class names ONLY (no inline style/hex)
                        ▼
        ┌──────────────────────────────────────────────────────────────┐
        │  priv/static/cairnloop.css  — single source of visual truth   │
        │  :root tokens (+ NEW --cl-content-max / --cl-rail-width /      │
        │                --cl-page-gutter)                              │
        │  .cl-page / .cl-hero / .cl-fact-list / .cl-source-card* /     │
        │  .cl-status-cell / .cl-switch* / .cl-table-scroll             │
        │  + 3 inert utilities (.cl-gap-2 / .cl-align-center /          │
        │                       .cl-justify-between)                   │
        └──────────────────────────────────────────────────────────────┘

   Data flow for switch toggle (server-owned): user click
     → phx-click (via :rest) → caller LiveView handle_event
     → updates `checked` assign → re-render → aria-checked reflects new state.

   Data flow for disclosure (browser-owned): user click <summary>
     → native browser toggles `open` → NO server round-trip
     → phx-update="ignore" guarantees a later PubSub re-render does NOT touch it.
```

### Recommended Project Structure
No new files. Two existing files extended:
```
lib/cairnloop/web/components.ex     # +8 component functions (+ helper fns for variant→icon, etc.)
priv/static/cairnloop.css           # +3 tokens, +3 utilities, +component classes, +.cl-table-scroll
test/cairnloop/web/components_test.exs  # +8 headless render tests (extend, don't replace)
# + inline <div class="cl-table-scroll" …> wrappers at 4 .cl-table call sites:
#   lib/cairnloop/web/audit_log_live.ex:129
#   lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:220
#   lib/cairnloop/web/knowledge_base_live/index.ex:78
#   lib/cairnloop/web/settings_live.ex:246
```

### Pattern 1: Narrowing an `attr` type (de-polymorphization — D-01)
**What:** Replace `attr(:count, :any, required: true)` with `attr(:count, :integer, required: true)`.
**When to use:** `cl_stat` (and `cl_hero` uses the same `:integer` typing for its count).
**Note:** Phoenix `attr` types are validated at **compile time** for literal/known assigns and emit
warnings (which become errors under `--warnings-as-errors`) when a literal violates the type — but
**runtime values from assigns are not strictly enforced** by `attr` typing. The de-polymorphization
is primarily an API-contract narrowing; no P37 caller passes a non-integer (screen migrations are
P38/P39), so the build stays warnings-clean. `[CITED: hexdocs Phoenix.Component attr/3]`
```elixir
# Source: existing components.ex:130 (cl_stat) — change `:any` → `:integer`
attr(:count, :integer, required: true)
```

### Pattern 2: `attr`/`slot` API ergonomics (cl_page, cl_hero, cl_fact_list, cl_source_card)
**What:** Phoenix.Component declarative `attr`/`slot` with enum `values:`, required slots, `:rest` global.
**Key gotchas surfaced (the planner asked for these):**
- **Enum attr with `values:`** → `attr(:width, :string, values: ~w(wide reading), default: "wide")`.
  A literal value outside the set is a **compile-time warning** (→ error under warnings-as-errors).
  This is the correct shape for D-08 (single enum attr, not two booleans) and D-06 `source_variant`.
- **Required slot** → `slot(:summary, required: true)`. Caller MUST provide it; omission is a compile warning.
  Use for `cl_disclosure :summary` and `cl_source_card :title`.
- **Optional slot emptiness check** → guard rendering with `:if={@slot_name != []}` (the repo idiom,
  see `cl_card` at `components.ex:59`). Applies to `cl_page :actions`/`:breadcrumb`/`:subnav`,
  `cl_hero :detail`, `cl_source_card :meta`, `cl_fact_list` optional `inner_block`.
- **Default (`inner_block`) vs named slots:** a component can have both a default `inner_block` AND
  named slots simultaneously (`cl_card` already does). `cl_fact_list` uses `facts :list` for the
  structured rows AND an optional `inner_block` for custom rows — both render in the same `<dl>`.
- **`:let` (slot args):** NOT needed for any P37 primitive — none of these slots need to pass data
  back to the caller. Keep slots simple (`render_slot(@slot)`); avoid `:let` complexity.
- **`:rest` global passthrough:** `attr(:rest, :global, include: ~w(phx-click phx-value-id …))`.
  The existing `cl_button` (`components.ex:35`) is the template. `cl_switch` needs
  `include: ~w(phx-click phx-value-id phx-value-key disabled)` so the caller can wire the toggle.
**Example (cl_page skeleton — matches UI-SPEC §1):**
```elixir
# Source: pattern derived from existing cl_card / cl_shell in components.ex
attr(:title, :string, required: true)
attr(:subtitle, :string, default: nil)
attr(:width, :string, values: ~w(wide reading), default: "wide")
slot(:actions)
slot(:breadcrumb)
slot(:subnav)
slot(:inner_block, required: true)

def cl_page(assigns) do
  ~H"""
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
  """
end
```

### Pattern 3: Patch-safe native disclosure (D-03 — THE critical pattern)
**What:** `cl_disclosure/1` wraps `<details>` with `phx-update="ignore"` + required stable `id`; the
`open` attribute is rendered ONLY as a static HTML attribute at initial mount.
**Why it survives LiveView diffing (verified):** Per the official LiveView bindings doc,
`phx-update="ignore"` means *"Updates from the server to the element's content and attributes are
ignored, except for data attributes,"* and *"a unique DOM ID must always be set in the container."*
After the initial render, LiveView's diff/patch engine treats the `<details>` subtree as
client-owned — a PubSub-triggered re-render cannot re-drive `open`, so the panel never snaps shut.
The browser's native `<details>`/`<summary>` toggle owns open/close entirely; no `phx-click`, no
assign, no JS hook. `[VERIFIED: hexdocs phoenix_live_view 1.1 bindings — phx-update="ignore"]`
**Example (matches UI-SPEC §4 exactly):**
```elixir
# Source: UI-SPEC §4 + verified phx-update="ignore" semantics
attr(:id, :string, required: true)        # REQUIRED — phx-update mandates a unique DOM id
attr(:open, :boolean, default: false)     # static-at-mount only; NOT an assign-driven toggle
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
Note: HEEx renders `open={@open}` as a **boolean attribute** — present when `true`, absent when
`false` — which is exactly correct for `<details open>`.

### Pattern 4: `role="switch"` server-controlled toggle (D-04)
**What:** `<button role="switch" aria-checked={to_string(@checked)}>` with `:rest` for `phx-click`.
**When to use:** `cl_switch` — the LiveView settings-toggle idiom (server owns `checked`, click
fires `phx-click` → `handle_event` → updates assign → re-render → `aria-checked` reflects new state).
**Accessibility contract:** `role="switch"` + `aria-checked` is the WAI-ARIA switch pattern; pairing
it with an always-visible text **label** satisfies brand §7.5 ("Never communicate state by color
alone. Pair color with text, icon, and/or shape." — `prompts/cairnloop_brand_book.md:505`).
```elixir
# Source: UI-SPEC §8 + brand §7.5
attr(:checked, :boolean, required: true)
attr(:label, :string, required: true)
attr(:rest, :global, include: ~w(phx-click phx-value-id phx-value-key disabled))

def cl_switch(assigns) do
  ~H"""
  <button type="button" class="cl-switch" role="switch" aria-checked={to_string(@checked)} {@rest}>
    <span class="cl-switch__track"><span class="cl-switch__thumb"></span></span>
    <span class="cl-switch__label">{@label}</span>
  </button>
  """
end
```

### Pattern 5: Layout tokens in `:root` (D-09)
**What:** Add three layout tokens to the existing `:root` token block in `cairnloop.css`, placed
alongside spacing/control tokens. Width modifier classes reference them.
**When to use:** `cl_page` `:wide`/`:reading` and `.cl-hero`.
**Critical footgun (honored):** `var()` is **illegal inside `@media` conditions** — so breakpoints
stay literal constants (P43 owns responsive). These tokens drive `max-width` *values*, never media-
query *conditions*. `[CITED: CSS spec — custom properties are not valid in media feature queries]`
```css
/* Source: UI-SPEC Spacing §; placed in :root near --cl-control-* (cairnloop.css:130) */
--cl-content-max: 1200px;             /* matches existing .cl-main max-width (cairnloop.css:254) */
--cl-rail-width:  352px;              /* matches existing .evidence-rail width (cairnloop.css:509) */
--cl-page-gutter: var(--cl-space-5);  /* = 16px */

.cl-page--wide    { max-width: var(--cl-content-max); margin: 0 auto; padding: 0 var(--cl-page-gutter); }
.cl-page--reading { max-width: var(--cl-rail-width);  margin: 0 auto; padding: 0 var(--cl-page-gutter); }
```
**Token-value grounding:** `--cl-content-max: 1200px` exactly matches the shipped `.cl-main`
`max-width: 1200px` (`cairnloop.css:254`); `--cl-rail-width: 352px` exactly matches the shipped
`.evidence-rail { width: 352px }` (`cairnloop.css:509`). Reusing these existing magic numbers as
named tokens is consistent and low-risk. `[VERIFIED: priv/static/cairnloop.css]`

### Anti-Patterns to Avoid
- **Binding `cl_disclosure` `open` to a server assign** — violates D-03; reintroduces the snap-shut
  bug. Open is browser-owned; `phx-update="ignore"` is the guard.
- **Rendering `aria-checked={@checked}` with a raw boolean** — HEEx would emit a boolean attribute
  (present/absent), but ARIA requires the literal string `"true"`/`"false"`. Always `to_string/1`.
- **Inline `style=` or hardcoded hex in `.ex` files** — fails the brand-token gate (D-13) and the
  refute-hex test. The existing `conversation_live.ex` `<details style="…#8b7355…">` (lines 1001–1049)
  is exactly the drift P40 remediates — do NOT copy that pattern into the new primitive.
- **`cl_status_cell` calling `AuditLogPresenter.action_tone/1`** — that function does not exist (D-07);
  the primitive takes `variant` + `label` directly. Verified against `audit_log_presenter.ex`.
- **Growing a utility framework** — define exactly the three D-10 utilities; nothing more.
- **A `cl_table` wrapper component** — D-11 forbids it; inline `<div class="cl-table-scroll">` only.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Open/close disclosure state | A `phx-click` toggle + assign + JS hook | Native `<details>`/`<summary>` + `phx-update="ignore"` | The browser already implements accessible disclosure; server state reintroduces the snap-shut bug (D-03) |
| Status chip styling | New per-variant chip markup in `cl_status_cell` | Delegate to existing `cl_chip` (`components.ex:76`) | `cl_chip` already pairs color+icon+text (§7.5) across all 6 variants with shipped CSS |
| Status icons | Hand-author SVG per variant | Reuse `cl_icon` + existing `status_icon/1` map (`components.ex:245`) | Distinct silhouettes already a11y-tuned; no icon-font dependency |
| Focus rings | Custom `box-shadow` per component | Existing `--cl-focus-ring` + `.cl-focusable` (`cairnloop.css:149,235`) | One ring token shows on light+dark; never remove an outline without replacement |
| Disclosure `dl/dt/dd` styling | New CSS | Existing `.cl-details dl/dt/dd` (`cairnloop.css:483-485`) for `cl_disclosure` body | Already styled; reuse per D-03 |
| Breadcrumb in `cl_page` | New breadcrumb markup | Existing `cl_breadcrumb` (`components.ex:194`) passed into the `:breadcrumb` slot | Already exists with `aria-label="Breadcrumb"` |

**Key insight:** ~half of P37 is *composition of already-shipped primitives*, not net-new UI.
`cl_status_cell` is a thin wrapper over `cl_chip`; `cl_source_card` reuses `cl_icon` + status
triplets; `cl_disclosure` reuses `.cl-details`; `cl_page` can host `cl_breadcrumb`. The genuinely
new visual CSS is `.cl-hero`, `.cl-page`, `.cl-fact-list`, `.cl-source-card*`, `.cl-switch*`,
`.cl-table-scroll`, and the 3 layout tokens + 3 utilities.

---

## Runtime State Inventory

> P37 is **greenfield-additive** (new component functions + new CSS classes), not a rename/refactor/
> migration. There is no stored data, live-service config, OS-registered state, secret, or build
> artifact that embeds a renamed string. The one API-narrowing (D-01 `cl_stat count :any → :integer`)
> is a **source code-edit only** with **no current callers passing non-integers in P37 scope**
> (verified: screen migrations that pass values are P38/P39). No data migration, no runtime state.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — pure presentation components, no datastore keys touched | none |
| Live service config | None — no external service references the new components/classes | none |
| OS-registered state | None — no scheduled tasks / process names involved | none |
| Secrets/env vars | None — no secret keys referenced | none |
| Build artifacts | None new. (Compiled BEAM for `Cairnloop.Web.Components` recompiles normally on edit.) | none |

**Caller-impact note (not runtime state, but plan-relevant):** D-01 narrows `cl_stat`'s `count`
attr. Verified there are **no P37-scope callers** passing a non-integer. The single existing
`cl_stat` caller pattern (`home_live`) passes integer counts. Screen adoption that might pass a
health string is explicitly P39 (where health routes through `cl_chip`, not `cl_stat`). So the
narrowing is safe to ship in P37 without a migration task.

---

## Common Pitfalls

### Pitfall 1: Disclosure snaps shut on PubSub re-render
**What goes wrong:** A native `<details open>` resets to its server-rendered state every time the
LiveView re-renders (e.g., a PubSub broadcast), collapsing a panel the operator just opened.
**Why it happens:** Without `phx-update="ignore"`, LiveView's diff/patch re-drives the `open`
attribute from the server's idea of it on every re-render.
**How to avoid:** Put `phx-update="ignore"` **and a stable unique `id`** on the `<details>` element.
The `id` is **mandatory** for `phx-update` (per the bindings doc); a missing/duplicate id breaks the
guarantee. Verified mechanism — HIGH confidence.
**Warning signs:** Test must assert `html =~ ~s(phx-update="ignore")` AND `html =~ ~s(id=)`. A
LiveView integration test (P41 territory, not P37) would catch the snap-shut behaviorally; in P37
the structural-marker assertion is the proxy.

### Pitfall 2: `phx-update="ignore"` freezes child content too (implication for adopters)
**What goes wrong:** Because "updates from the server to the element's **content** and attributes are
ignored," any *dynamically-changing* server-rendered content **inside** the `<details>` body also
stops updating after initial mount.
**Why it happens:** That's the whole point of `ignore` — the subtree is client-owned.
**How to avoid (P37):** `cl_disclosure` is a **pure stateless primitive**; its `inner_block` is
rendered once and doesn't depend on live-updating assigns *within the ignored subtree*. This is fine
for P37. **Flag for the planner / P41 adopters:** when a screen later places content that must
live-update (e.g., a count that changes via PubSub) inside a `cl_disclosure`, that dynamic content
must live **outside** the ignored `<details>`, or the adopter must accept it freezes at mount. Document
this as a forward-compat guardrail carried to P41. `[VERIFIED: hexdocs LV bindings — ignore semantics]`

### Pitfall 3: `aria-checked` rendered as a boolean attribute
**What goes wrong:** `aria-checked={@checked}` with a boolean assign emits `aria-checked` (present)
or nothing (absent) — but assistive tech needs the literal string `"false"` to announce "off".
**Why it happens:** HEEx treats boolean values on attributes as HTML boolean-attribute semantics.
**How to avoid:** `aria-checked={to_string(@checked)}` → always `"true"` or `"false"`. UI-SPEC §8
already specifies this; enforce in code review and assert `html =~ ~s(aria-checked="false")` in a test.

### Pitfall 4: Hardcoded hex / inline style sneaking into the `.ex`
**What goes wrong:** A component emits `style="…#hex…"` or a `var(--cl-x, #hex)` fallback, failing
the brand-token gate (D-13) and the refute-hex test (UIC-04 / SC-4).
**Why it happens:** Copying the existing drifted `conversation_live.ex` `<details style=…>` pattern.
**How to avoid:** Emit **only** `.cl-*` class names from the `.ex`; all color/spacing lives in
`cairnloop.css` as bare `var(--cl-*)`. The brand-token gate (`brand_token_gate_test.exs`) scans for
`var(--cl-…, #hex)`; the new refute-hex test scans rendered HTML for any `#[0-9a-fA-F]{3,6}`.

### Pitfall 5: `:rest` global drops needed phx-* attributes
**What goes wrong:** `cl_switch`'s `phx-click`/`phx-value-*` don't pass through because they aren't
in the `:global` `include:` allowlist (Phoenix.Component only forwards known global attrs + the
explicit `include:` list).
**Why it happens:** `phx-value-*` are not default globals.
**How to avoid:** Mirror `cl_button`'s pattern — `attr(:rest, :global, include: ~w(phx-click
phx-value-id phx-value-key disabled form name value))`. Assert the passthrough in a test
(`html =~ ~s(phx-click="toggle")`). `[CITED: hexdocs Phoenix.Component :global include]`

### Pitfall 6: LV 1.1 test parser is `lazy_html`, not Floki
**What goes wrong:** If any new test uses `Floki`-style selectors it may break — LV 1.1 swapped the
test HTML parser to `lazy_html`.
**Why it happens:** Documented LV 1.1 change (noted in the repo's own `mix.exs` comment).
**How to avoid:** The repo's component tests use **string `=~` assertions on `rendered_to_string`**,
not DOM selectors — keep that idiom; it's parser-agnostic. No action needed beyond not introducing
Floki selectors.

---

## Code Examples

### Headless component test (the established repo idiom — Repo-free)
```elixir
# Source: existing test/cairnloop/web/components_test.exs (extend this file)
use ExUnit.Case, async: true
import Phoenix.Component
import Phoenix.LiveViewTest
import Cairnloop.Web.Components

test "cl_disclosure is patch-safe (phx-update=ignore + stable id) and renders summary" do
  assigns = %{}
  html =
    rendered_to_string(~H"""
    <.cl_disclosure id="inputs-scope" open={true}>
      <:summary>Inputs &amp; scope</:summary>
      <p>body</p>
    </.cl_disclosure>
    """)

  assert html =~ "<details"
  assert html =~ ~s(phx-update="ignore")   # patch-safety mechanism present
  assert html =~ ~s(id="inputs-scope")     # required stable id present
  assert html =~ "open"                     # static open attr at initial render
  assert html =~ "Inputs"
  refute html =~ ~r/#[0-9a-fA-F]{3,6}/      # token-purity (UIC-04 / SC-4)
end

test "cl_switch is a real role=switch with string aria-checked and label (never color alone)" do
  assigns = %{}
  html =
    rendered_to_string(~H"""
    <.cl_switch checked={false} label="Draft mode" phx-click="toggle" />
    """)

  assert html =~ ~s(role="switch")
  assert html =~ ~s(aria-checked="false")  # string, not boolean attr
  assert html =~ "Draft mode"               # always-visible label (§7.5)
  assert html =~ ~s(phx-click="toggle")    # :rest passthrough works
  refute html =~ ~r/#[0-9a-fA-F]{3,6}/
end
```

### Token-purity assertion idiom (UIC-04 / SC-4)
```elixir
# Reusable across all 8 primitives — assert rendered HTML contains no #-prefixed hex
refute html =~ ~r/#[0-9a-fA-F]{3,6}/
```
**Caveat:** the regex also matches `#` in URL fragments or text content. None of the P37 primitives
emit `href="#..."` or hex-looking literals, so this is safe — but if a future test renders a primitive
with a fragment href, scope the assertion. For P37 the bare regex is correct.

### `.cl-table-scroll` inline wrapper (D-11) applied at each of 4 call sites
```heex
<%!-- Source: UI-SPEC §9. Apply at audit_log_live:129, suggestion_review:220,
      index:78, settings_live:246 — aria-label MUST be descriptive per call site --%>
<div class="cl-table-scroll" role="region" tabindex="0" aria-label="Audit log">
  <table class="cl-table">…</table>
</div>
```
```css
/* Source: UI-SPEC §9 */
.cl-table-scroll { overflow-x: auto; -webkit-overflow-scrolling: touch; }
.cl-table-scroll:focus-visible { box-shadow: var(--cl-focus-ring); border-radius: var(--cl-radius-xs); }
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `render_component/2` as the component-test entry | `rendered_to_string(~H...)` recommended for slotted/complex components | LV 1.x docs guidance | Use `rendered_to_string`; both work, repo already standardizes on it |
| Floki as LiveViewTest HTML parser | `lazy_html` | LV 1.1 | Only matters for DOM-selector tests; string `=~` assertions unaffected |
| `<details style="…#hex…">` inline-styled disclosures (current drift in `conversation_live.ex`) | Tokenized `cl_disclosure` primitive | This phase (built) / P40 (adopted) | The new primitive is the clean replacement; do not copy the drifted inline-style pattern |

**Deprecated/outdated:** Nothing in the P37 surface is deprecated. `phx-update="ignore"`,
`render_component/3`, `attr`/`slot`, and `:global` are all current in LV 1.1.30.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `--cl-content-max: 1200px` and `--cl-rail-width: 352px` are the right initial token values | Pattern 5 | LOW — grounded in existing shipped `.cl-main` (1200px) and `.evidence-rail` (352px); these are ratified in UI-SPEC. If a designer wants different framing, it's a one-line token edit, reversible. |
| A2 | No P37-scope `cl_stat` caller passes a non-integer count (so D-01 needs no migration task) | Runtime State Inventory | LOW — verified `home_live` passes integer counts; health-as-string is explicitly P39. If a hidden caller exists, `--warnings-as-errors` + `mix test` would surface it at build time. |
| A3 | `refute html =~ ~r/#[0-9a-fA-F]{3,6}/` is sufficient token-purity proof for all 8 primitives | Validation Architecture | LOW — matches D-12/UIC-04 exactly; the only false-positive vector (fragment hrefs) isn't emitted by any P37 primitive. |

**All other claims are VERIFIED (mix.lock, repo files, official LV docs) or CITED. The three
assumptions above are all LOW-risk and self-correcting at build/test time.**

---

## Open Questions

1. **`cl_hero` CTA precedence — slot vs `cta`/`href` attrs.**
   - What we know: UI-SPEC §2 allows both a CTA *slot* (inner_block) and `cta`/`href` *attrs*.
   - What's unclear: if a caller supplies both, which wins?
   - Recommendation: Prefer the explicit slot when present; fall back to rendering a
     `<.cl_button variant="primary">` from `cta`/`href` attrs when no CTA slot is given (guard with
     `:if={@cta_slot != []}` / `:if={@cta}`). Planner should pin this precedence in the task; it's a
     pure ergonomic call within Claude's Discretion (D-02 lists CTA as "slot or cta/href attrs").

2. **`.cl-table-scroll` `aria-label` text per call site.**
   - What we know: D-11/UI-SPEC require a descriptive `aria-label` at each of the 4 sites.
   - What's unclear: exact label strings.
   - Recommendation: audit_log → "Audit log"; suggestion_review → "Suggested KB edits"; index →
     "Knowledge base articles"; settings → "Policies". Planner can finalize; these are calm,
     descriptive WCAG names consistent with the screens' headings.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Erlang OTP | compile + test | ✓ | OTP 28 (erts 16.3) | — |
| `phoenix_live_view` | all primitives + tests | ✓ | 1.1.30 (mix.lock) | — |
| `phoenix` | HEEx engine | ✓ | 1.8.7 | — |
| `phoenix_html` | `Phoenix.HTML.raw` (icons) | ✓ | 4.3.0 | — |
| `Cairnloop.Repo` (Postgres) | **NOT required by P37** | n/a | — | All P37 tests are headless/pure; no DB. The Repo-may-be-unavailable caveat does not bite this phase. |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None — P37 needs no Repo; all tests run in the fast default
suite (`mix test` with `:integration` excluded, per `test_helper.exs`).

---

## Validation Architecture

> `workflow.nyquist_validation` is **absent** from `.planning/config.json` → treated as **enabled**.
> Section included. (Note: `config.json` has no `workflow.nyquist_validation: false`, so the Nyquist
> validation strategy applies.)

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (bundled) + `Phoenix.LiveViewTest` (LV 1.1.30) |
| Config file | `test/test_helper.exs` (`ExUnit.start(exclude: [:integration])`) |
| Quick run command | `mix test test/cairnloop/web/components_test.exs` |
| Full suite command | `mix test` (fast headless suite; `:integration` excluded by default) |
| Compile gate | `mix compile --warnings-as-errors` (mandatory per CLAUDE.md, SC-5) |
| Build/test note | All P37 tests are **Repo-free** — no `# REPO-UNAVAILABLE` markers needed (D-12). |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UIC-01 | `cl_page` renders title + width modifier class + slots | unit (render) | `mix test test/cairnloop/web/components_test.exs` | ⚠️ extend existing file |
| UIC-02 | `cl_stat` rejects non-integer at compile (warnings-clean) + `cl_hero` renders copper count | unit (render) + compile | `mix compile --warnings-as-errors && mix test …components_test.exs` | ⚠️ extend |
| UIC-03 | `cl_disclosure` emits `<details phx-update="ignore" id=…>` + static `open` | unit (render, structural marker) | `mix test …components_test.exs` | ⚠️ extend |
| UIC-04 | `cl_fact_list`/`cl_source_card`/`cl_status_cell`/`cl_switch` render with no hex; switch has `role="switch"`/string `aria-checked`; source-card has `<svg`; status-cell has visible label | unit (render + refute-hex) | `mix test …components_test.exs` | ⚠️ extend |
| UIC-05 | 3 tokens + 3 utilities + `.cl-table-scroll` defined in CSS; 4 tables wrapped with `role="region"` | CSS-presence + render-marker | `mix test …components_test.exs` (markup) + grep-style CSS assertion or manual | ⚠️ extend; CSS-presence may need a small file-read test |
| D-13 | New components pass existing brand-token gate | gate test (existing) | `mix test test/cairnloop/web/brand_token_gate_test.exs` | ✅ exists |

### Sampling Rate
- **Per task commit:** `mix compile --warnings-as-errors && mix test test/cairnloop/web/components_test.exs test/cairnloop/web/brand_token_gate_test.exs`
- **Per wave merge:** `mix test` (full fast suite) + `mix compile --warnings-as-errors`
- **Phase gate:** `mix test` green (incl. brand-token gate) + warnings-clean build before `/gsd:verify-work`.
  Integration lane (`mix test.integration`) is **not exercised by P37** (no DB-backed code), but per
  repo memory must be green before any claim of "milestone green" — that is a later-phase concern.

### Validation levels (what must be validated, at what level)
| Invariant | Level | Mechanism |
|-----------|-------|-----------|
| **Token-purity** (no `#hex` in rendered HTML) | headless render test | `refute html =~ ~r/#[0-9a-fA-F]{3,6}/` per primitive |
| **No hex-fallback in `.ex`** | existing gate test | `brand_token_gate_test.exs` (D-13) |
| **Patch-safety invariant** (disclosure) | headless render test (structural proxy) | `assert html =~ ~s(phx-update="ignore")` + `assert html =~ "id="` |
| **`role="switch"` + string `aria-checked`** | headless render test | `assert html =~ ~s(role="switch")`, `assert html =~ ~s(aria-checked="false")` |
| **never-color-alone** (switch/status-cell/source-card) | headless render test | assert visible label text present; assert `<svg` present (source-card icon) |
| **`.cl-table-scroll` a11y** (region/tabindex) | render-marker test at call sites OR primitive-pattern test | `assert html =~ ~s(role="region")`, `assert html =~ ~s(tabindex="0")` |
| **Warnings-clean build** | compile check | `mix compile --warnings-as-errors` (SC-5) |
| **CSS presence** (3 tokens + 3 utilities + `.cl-table-scroll`) | file-content assertion | small ExUnit test reading `priv/static/cairnloop.css` for the literal token/class names, OR a manual checklist in verify-work |

### Wave 0 Gaps
- [x] `test/cairnloop/web/components_test.exs` — **exists**; extend with 8 new primitive tests (no new file needed).
- [x] `test/cairnloop/web/brand_token_gate_test.exs` — **exists**; runs unchanged.
- [ ] (Optional) a tiny CSS-presence test reading `priv/static/cairnloop.css` to assert the 3 new
  tokens, 3 utilities, and `.cl-table-scroll` are defined — recommended so UIC-05's CSS half is
  machine-verified, not just eyeballed. Planner's call; otherwise verify-work checks it manually.
- [x] Framework install: none — ExUnit + LiveViewTest already present.

*No framework gaps. The only optional new test is the CSS-presence assertion for UIC-05.*

---

## Security Domain

> `security_enforcement` is not set in `.planning/config.json` (absent = enabled). However, P37 is a
> **pure presentational-primitives phase with no auth, no session, no input handling, no crypto, no
> data access**. The ASVS surface is minimal and limited to output-encoding / a11y correctness.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a — no auth in primitives |
| V3 Session Management | no | n/a |
| V4 Access Control | no | n/a — components are presentation-only; access control lives in the LiveViews that adopt them (P38+) |
| V5 Input Validation / Output Encoding | yes (output encoding) | HEEx auto-escapes interpolations by default. **Caveat:** `cl_icon` uses `Phoenix.HTML.raw/1` on a **fixed internal icon-path allowlist** (`icon_paths/1`), never on caller input — this is safe. New primitives MUST NOT pass caller-supplied strings to `raw/1`; render all caller text via normal `{…}` interpolation (auto-escaped). |
| V6 Cryptography | no | n/a |

### Known Threat Patterns for Phoenix LiveView function components
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stored/Reflected XSS via unescaped interpolation | Tampering / Elevation | HEEx auto-escapes `{user_value}`; never `raw/1` on caller input. `cl_icon`'s `raw/1` is on a fixed internal allowlist only — keep it that way. |
| `aria-*` / `role` correctness (a11y, not strictly security) | — | `role="switch"` + string `aria-checked`; `role="region"`+`tabindex`+`aria-label` on table scroller; verified by render tests. |
| `phx-update="ignore"` content freeze (info-staleness) | Repudiation (stale UI) | Documented as a forward-compat guardrail (Pitfall 2): live-updating content must live outside the ignored subtree. Not a P37 defect; a P41 adoption constraint. |

**Net:** No new security-sensitive surface. The one thing to enforce in code review: **no caller
input ever reaches `Phoenix.HTML.raw/1`** in any new primitive.

---

## Sources

### Primary (HIGH confidence)
- `phoenix_live_view` 1.1 bindings doc (hexdocs) — `phx-update="ignore"` semantics: "Updates from the
  server to the element's content and attributes are ignored, except for data attributes"; "a unique
  DOM ID must always be set in the container." Resolves D-03 patch-safety. `[VERIFIED]`
- `Phoenix.LiveViewTest` (hexdocs LV 1.1) — `render_component/3` exists, not deprecated;
  `rendered_to_string`/`~H` recommended for complex/slotted components. `[VERIFIED]`
- Repo files (read directly): `lib/cairnloop/web/components.ex`, `priv/static/cairnloop.css`,
  `test/cairnloop/web/components_test.exs`, `test/cairnloop/web/brand_token_gate_test.exs`,
  `lib/cairnloop/web/audit_log_presenter.ex` (confirms `action_label/1`, no `action_tone/1`),
  `mix.lock` (versions), `test/test_helper.exs` (integration-excluded default suite),
  `prompts/cairnloop_brand_book.md:505` (§7.5 never-color-alone). `[VERIFIED: repo]`
- `.planning/phases/37-component-primitives/37-CONTEXT.md` + `37-UI-SPEC.md` (ratified decisions/contract).
- Grep verification: all 3 layout tokens, 3 utilities, `.cl-table-scroll`, `.cl-hero` **confirmed
  absent** today; 4 `.cl-table` call sites enumerated. `[VERIFIED: repo grep]`

### Secondary (MEDIUM confidence)
- `Phoenix.Component` `attr`/`slot`/`:global` behavior (compile-time enum validation, `:global`
  `include:` allowlist, boolean-attribute rendering) — `[CITED: hexdocs Phoenix.Component]`, cross-
  checked against existing `cl_button`/`cl_card` usage in the repo.

### Tertiary (LOW confidence)
- None requiring validation. (`var()` illegal in `@media` is a well-established CSS rule and is
  already a captured footgun in the vM016 brief and CONTEXT D-09.)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versions read from `mix.lock`; zero new deps.
- Architecture / API patterns: HIGH — grounded in existing `components.ex` conventions + official docs.
- D-03 patch-safety (the critical question): HIGH — official LV bindings doc quote pins the mechanism.
- Testing idiom: HIGH — repo already uses `rendered_to_string(~H...)` Repo-free.
- Pitfalls: HIGH — each grounded in a verified source or the repo's existing drift.

**Research date:** 2026-06-03
**Valid until:** ~2026-07-03 (stable — LV 1.1 API + a self-contained design system; no fast-moving deps).

## RESEARCH COMPLETE

**Phase:** 37 - Component Primitives
**Confidence:** HIGH

### Key Findings
- **D-03 resolved (HIGH):** `phx-update="ignore"` + a **required stable `id`** on `<details>` is the
  verified mechanism — official LV bindings doc confirms server updates to the element's content AND
  attributes are ignored, so a PubSub re-render cannot snap the panel shut. Implication flagged: the
  ignored subtree also freezes child content (forward-compat guardrail for P41 adopters).
- **Testing idiom (HIGH):** Repo already standardizes on `rendered_to_string(~H...)` (the docs-
  recommended path for slotted components), Repo-free in the fast default suite — no `REPO-UNAVAILABLE`
  markers needed. `render_component/3` exists/works but `rendered_to_string` is the repo convention.
- **`aria-checked` must be `to_string(@checked)`** (string, not boolean attr) — and `cl_switch`/
  `cl_status_cell`/`cl_source_card` must carry visible label/icon (§7.5 line 505, verified).
- **D-07 grounding confirmed:** `audit_log_presenter.ex` has `action_label/1`, lacks `action_tone/1`
  — `cl_status_cell` takes `variant`+`label` directly; no dependency on a non-existent fn.
- **Scope is ~half composition:** `cl_status_cell`→`cl_chip`, `cl_source_card`→`cl_icon`+status
  triplets, `cl_disclosure`→`.cl-details`, `cl_page`→can host existing `cl_breadcrumb`. Net-new CSS:
  `.cl-hero/.cl-page/.cl-fact-list/.cl-source-card*/.cl-switch*/.cl-table-scroll` + 3 tokens + 3 utils.
- **4 `.cl-table` call sites** confirmed (audit_log:129, suggestion_review:220, index:78,
  settings:246); all target tokens/classes confirmed absent today.

### File Created
`/Users/jon/projects/cairnloop/.planning/phases/37-component-primitives/37-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | Versions from `mix.lock`; zero new deps |
| Architecture | HIGH | Existing `components.ex` conventions + official LV docs |
| Pitfalls | HIGH | Each grounded in verified source or existing repo drift |

### Open Questions
- `cl_hero` CTA precedence (slot vs `cta`/`href` attrs) — recommended: slot wins, attrs fallback.
- `.cl-table-scroll` aria-label strings per call site — recommended values provided.
Both are within Claude's Discretion; non-blocking.

### Ready for Planning
Research complete. The planner can create PLAN.md files; all five highest-leverage questions (D-03
patch-safety, `cl_switch` pattern, headless test shape, slot/attr ergonomics, layout tokens) are
answered with HIGH confidence, and the Validation Architecture section supports VALIDATION.md derivation.
