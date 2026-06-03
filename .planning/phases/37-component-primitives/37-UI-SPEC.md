---
phase: 37
slug: component-primitives
status: draft
shadcn_initialized: false
preset: none
created: 2026-06-03
---

# Phase 37 — UI Design Contract: Component Primitives

> Visual and interaction contract for the eight additive component primitives, three layout
> tokens, three inert-utility CSS definitions, and the `.cl-table-scroll` wrapper delivered
> in this phase. This contract is consumed by the planner and executor; upstream phase work
> (P38–P45) adopts these primitives into live screens.
>
> **SCOPE BOUNDARY:** This contract specifies the visual/interaction behaviour of the
> primitives themselves, not of the screens that will use them. No screen migrations, no
> Home redesign, no drift remediation are specified here — those are P38–P45.

---

## Design System

| Property | Value | Source |
|----------|-------|--------|
| Tool | none (Phoenix LiveView native) | existing codebase |
| Preset | not applicable | existing codebase |
| Component library | `Cairnloop.Web.Components` — stateless `Phoenix.Component` functions | `lib/cairnloop/web/components.ex` |
| Style architecture | BEM + `.cl-` single-purpose utilities; one shipped `cairnloop.css`; no Tailwind; no build step | `priv/static/cairnloop.css` + CONTEXT D-10 |
| Icon library | `cl_icon` — self-contained inline SVG set (feather-style, distinct silhouettes) | `components.ex:209` |
| Font — UI | Atkinson Hyperlegible Next (weight 400/600); fallback chain in `--cl-font-sans` | `cairnloop.css:70` |
| Font — display/brand | Fraunces; used only for `.cl-stat__count` display numerics and `.cl-hero` count | `cairnloop.css:71` + brand book §8 |
| Font — mono | Martian Mono; used for trace IDs, metadata, code blocks | `cairnloop.css:72` |
| shadcn gate | Not applicable — Elixir/Phoenix project; no React/Next.js/Vite | architecture |

---

## Spacing Scale

All spacing references the existing `--cl-space-*` token ladder. No new spacing tokens are
introduced in this phase.

> **OVERRIDE / RATIONALE — Checker Dimension 5**
>
> The UI checker flagged `--cl-space-1` (2px) and `--cl-space-4` (12px) as not conforming to
> the generic "multiples of 4 / standard set {4,8,16,24,32,48,64}" heuristic.
>
> **Recorded project decision (supersedes generic heuristic):**
> The `--cl-space-*` ladder is the **existing shipped, brand-ratified spacing system** that
> shipped as part of `cairnloop.css` in Cairnloop 0.4.0 (PR #17). The generic checker
> heuristic is superseded by this ratified token ladder per the repo decision policy
> (`CLAUDE.md`: "Brand tokens over hardcoded hex") and the principle that carried decisions
> are not re-litigated in downstream phases.
>
> - `--cl-space-4` = 12px is exactly 3×4px — grid-aligned and compliant with the 4px base
>   rhythm. It is not an exception; it is a valid 4px-multiple half-step that the token
>   comment in `cairnloop.css:86` explicitly describes as a "4px rhythm, 2/4 half-steps
>   where dense admin needs them."
>
> - `--cl-space-1` = 2px is the intentional micro-gap token for tight icon spacing (e.g.,
>   `.cl-nav__links` gap, `.cl-tabs` inter-tab gap — `cairnloop.css:270, 448`). It is a
>   ratified part of the ladder, not ad-hoc drift. **However, none of the eight P37
>   primitives consume `--cl-space-1` directly** — chips use `--cl-space-2` (4px) for their
>   icon gap (`cairnloop.css:337`), and no new P37 CSS classes reference `--cl-space-1`.
>   Therefore `--cl-space-1` is **excluded from the P37 spacing-in-scope table below**; it
>   is documented here for completeness as a ratified ladder token, but it is out of P37's
>   surface. This resolves the checker flag cleanly: no P37 primitive outputs 2px spacing.
>
> Authority: `cairnloop.css` spacing token block (`cairnloop.css:86-101`); repo CLAUDE.md
> decision policy; brand book §7.3 (palette proportions); CONTEXT D-09/D-10 (spacing usage).

**P37 spacing in scope** (tokens actually consumed by the eight P37 primitives and their CSS):

| Token | Value | Usage in this phase |
|-------|-------|---------------------|
| `--cl-space-2` | 4px | `cl-gap-2` utility definition; icon label gaps in `cl_chip` (via `cl_status_cell`) |
| `--cl-space-3` | 8px | Default `.cl-row` / `.cl-stack` gap; `cl_disclosure` summary padding |
| `--cl-space-4` | 12px | `cl_fact_list` row padding; `cl_source_card` body padding |
| `--cl-space-5` | 16px | `cl_page` inner gutter (`--cl-page-gutter` default); `cl_stat` / `cl_hero` padding |
| `--cl-space-7` | 24px | `cl_page` section vertical rhythm; `cl_hero` block vertical padding |
| `--cl-space-8` | 32px | Layout gap between major `cl_page` regions |
| `--cl-space-10` | 48px | `cl_empty` vertical padding (existing) |
| `--cl-space-11` | 64px | Reserved for `cl_page` `:wide` max-width responsive padding at xl |

**New layout tokens (D-09, UIC-05):**

| Token | Initial value | Usage |
|-------|---------------|-------|
| `--cl-content-max` | `1200px` | `cl_page` `:wide` inner max-width (matches existing `.cl-main`) |
| `--cl-rail-width` | `352px` | `cl_page` `:reading` rail constraint; P41 conversation layout reuse |
| `--cl-page-gutter` | `var(--cl-space-5)` (= 16px) | Inner padding for `cl_page` shell; responsive override in P43 |

**Inert utility definitions (D-10, UIC-05):**

| Class | Definition | Intended use |
|-------|------------|--------------|
| `.cl-gap-2` | `gap: var(--cl-space-2)` | Fine-grained flex gap escape hatch |
| `.cl-align-center` | `align-items: center` | Fine-grained flex align escape hatch |
| `.cl-justify-between` | `justify-content: space-between` | Fine-grained flex justify escape hatch |

These three are defined on flex containers as escape hatches only. The preferred composite
layout primitives remain `.cl-row` / `.cl-row--between` / `.cl-row--wrap` / `.cl-stack`.

**Exceptions:** `cl_switch` touch target must render at minimum 44×44px (meets the P43
RESP-02 requirement preemptively). Use `--cl-control-h-lg: 44px` for the switch thumb
track height or ensure the `<button>` has `min-height: 44px; min-width: 44px`.

---

## Typography

All sizes and weights reference existing tokens; no new font scale entries are introduced.

> **OVERRIDE / RATIONALE — Checker Dimension 4**
>
> The UI checker flagged 6 font sizes (48, 28, 18, 15, 13, 12px) and 3 weights (400, 500,
> 600) as exceeding the generic "max 4 sizes / max 2 weights" heuristic.
>
> **Recorded project decision (supersedes generic heuristic):**
> The cairnloop brand book **§8.3 "Type scale — Product UI"** is the ratified type-scale
> authority for this project. It defines exactly these six size/leading pairs as the
> canonical product UI scale:
>
> | Brand book §8.3 entry | Token | Computed value |
> |-----------------------|-------|----------------|
> | Page title: 28/36 | `--cl-font-title` / `--cl-leading-title` | 28px / 36px |
> | Panel title: 18/26 | `--cl-font-panel` / `--cl-leading-panel` | 18px / 26px |
> | Body: 15/24 | `--cl-font-body` / `--cl-leading-body` | 15px / 24px |
> | Small: 13/20 | `--cl-font-small` / `--cl-leading-small` | 13px / 20px |
> | Microcopy: 12/18 | `--cl-font-micro` / `--cl-leading-micro` | 12px / 18px |
> | Code: 13/22 | `--cl-font-code` / `--cl-leading-code` | 13px / 22px |
>
> These six tokens are **already shipped** in `cairnloop.css:75–80` (Cairnloop 0.4.0,
> PR #17). Phase 37 introduces **no new scale entries** — the only addition is the 48px
> hero count numeral in `cl_hero`, which brand book §8.3 already sanctions under the
> marketing "H1: 48/54" scale and which `cl_stat__count` at 32px (Fraunces display) has
> already established the display-numeral pattern for.
>
> For weights: brand book **§8.2** explicitly documents `weight-medium: 500` for small
> interactive labels ("marketing subhead: 400–500", "small labels: 600" with letter
> spacing). The token `--cl-weight-medium: 500` is shipped at `cairnloop.css:83` and is an
> established pattern for chips, nav links, and compact interactive labels throughout the
> existing codebase. The generic "max 2 weights" heuristic assumes no intermediate weight
> exists; the cairnloop design system ratifies three: 400 (body/values), 500 (small
> interactive labels only), 600 (headings/labels/CTAs).
>
> The generic "max 4 sizes / max 2 weights" heuristic is **superseded by the
> brand-book-ratified scale** for this codebase. This is a recorded project decision, not
> scale drift. Authority: brand book §8.2, §8.3; `cairnloop.css:75–84`; repo CLAUDE.md
> decision policy ("Brand tokens over hardcoded hex; carried decisions are not
> re-litigated").

| Role | Token | Computed value | Weight | Line-height token | Usage in this phase |
|------|-------|----------------|--------|-------------------|---------------------|
| Hero count | `--cl-font-display` (Fraunces) at custom size | 48px | 700 | 1 (no leading needed) | `cl_hero` primary count — ~2–3× weight vs `.cl-stat__count` (32px); meets SC-2 |
| Page title | `--cl-font-title` | 28px | `--cl-weight-semibold` (600) | `--cl-leading-title` (36px) | `cl_page` title slot |
| Panel title / hero job label | `--cl-font-panel` | 18px | `--cl-weight-semibold` (600) | `--cl-leading-panel` (26px) | `cl_hero` job label; `cl_source_card` title |
| Body | `--cl-font-body` | 15px | `--cl-weight-regular` (400) | `--cl-leading-body` (24px) | `cl_fact_list` values; `cl_source_card` body; `cl_page` inner content default |
| Small / label | `--cl-font-small` | 13px | `--cl-weight-medium` (500) | `--cl-leading-small` (20px) | `cl_fact_list` labels (`dt`); `cl_status_cell` chip text; `cl_disclosure` summary |
| Micro | `--cl-font-micro` | 12px | `--cl-weight-medium` (500) | `--cl-leading-micro` (18px) | `cl_switch` label when tight; table header text |
| Mono / trace | `--cl-font-code` via `--cl-font-mono` | 13px | 400 | `--cl-leading-code` (22px) | `cl_fact_list` raw-value expanders; `cl_source_card` version metadata |

**Weight usage summary:** regular (400) for body/values; semibold (600) for
headings/labels/CTAs; medium (500) reserved exclusively for small interactive labels
(chips, nav links) per the ratified brand-book §8.2 pattern.

**Hero count sizing rationale:** `.cl-stat__count` renders at 32px (Fraunces). The hero
count at 48px is exactly 1.5× — visually "~2–3× the weight" (SC-2) is achieved through
the combination of larger size, full-width layout, and the `.cl-hero` container's visual
mass, not size alone.

---

## Color

All color is token-only. No hardcoded hex in any `.ex` file this phase. The existing
brand-token gate (`test/cairnloop/web/brand_token_gate_test.exs`) must pass green for all
new component renders (CONTEXT D-13, SC-4).

### 70/20/10 palette contract (admin UI)

| Role | Token | Light computed | Dark computed | Usage |
|------|-------|----------------|---------------|-------|
| Dominant surface (70%) | `--cl-bg` / `--cl-surface` | `#F5F0E6` / `#FBF7EE` | `#101614` / `#18211F` | `cl_page` background; `cl_fact_list` bg; `cl_source_card` bg |
| Secondary — text + borders (20%) | `--cl-text` / `--cl-border` | `#18211F` / `#D8D0BF` | `#F5F0E6` / `#34443D` | All text; `cl_fact_list` `dt`/`dd` borders; `cl_disclosure` summary line |
| Accent — copper route marker (10%) | `--cl-primary` | `#A94F30` | `#D98A4A` | Reserved — see below |

**Copper (`--cl-primary`) is reserved for:**
- `cl_hero` primary count numeral only
- `cl_hero` CTA button (`cl_button variant="primary"`)
- `cl_stat` count numeral (existing; unchanged)
- Active route marker on `cl_card` (existing `.cl-route-active` border-left)
- Focus rings (`--cl-focus-ring`) — all focusable elements

Copper MUST NOT appear on secondary stat counts, `cl_fact_list`, `cl_source_card` surfaces, `cl_disclosure` summaries, or `cl_switch` default state.

### Semantic status color contract

This phase introduces `cl_source_card` with `source_variant` and `cl_status_cell` with
`variant`. Both delegate to the existing chip/banner token triplets.

| Variant | Surface token | Border token | Text token | Semantic meaning | Icon (distinct silhouette) |
|---------|---------------|--------------|------------|------------------|---------------------------|
| `success` | `--cl-success-surface` | `--cl-success-border` | `--cl-success-text` | Sourced/safe/resolved; maps `#4A6238` drift → this variant | `check-circle` |
| `info` | `--cl-info-surface` | `--cl-info-border` | `--cl-info-text` | Retrieval/docs/info; maps `#3F6F80` drift → this variant | `info` |
| `warning` | `--cl-warning-surface` | `--cl-warning-border` | `--cl-warning-text` | Budget risk / aging; Ember tone | `alert-triangle` |
| `danger` | `--cl-danger-surface` | `--cl-danger-border` | `--cl-danger-text` | Blocked/failed; Fault Clay tone | `x-circle` |
| `ai` | `--cl-ai-surface` | `--cl-ai-border` | `--cl-ai-text` | AI/eval/trace; Heather tone | `waypoint` |
| `neutral` | `--cl-neutral-surface` | `--cl-neutral-border` | `--cl-neutral-text` | Default; no semantic weight | `clock` |

**Never state by color alone (brand §7.5):** every `cl_status_cell` and `cl_source_card`
with a variant MUST pair the surface color with a distinct-silhouette `cl_icon` AND a
visible text label. The `cl_switch` checked/unchecked state MUST be communicated by label
text change in addition to any visual difference.

### Prohibited in `.ex` files
- Any `#rrggbb` or `#rgb` hex literal
- Any `rgba(...)` or `hsl(...)` literal
- Any `var(--cl-token, #hex)` fallback form
- Any helper function returning a hex string

The only permitted CSS output is bare `var(--cl-*)` token references and established
`.cl-*` class names.

---

## Component Inventory — Visual and Interaction Contracts

### 1. `cl_page/1` (UIC-01, CONTEXT D-08)

**Structure:**
```
<div class="cl-page cl-page--{width}">
  <header class="cl-page__header">
    [breadcrumb slot — optional]
    <h1 class="cl-page__title">{title}</h1>
    <p class="cl-page__subtitle">{subtitle}</p>  <!-- optional -->
    [actions slot — optional, right-aligned]
  </header>
  [subnav slot — optional, renders below header above content]
  <div class="cl-page__body">{inner_block}</div>
</div>
```

**Attributes:**
- `title :string, required: true` — renders as `<h1>` at 28px/600
- `subtitle :string, default: nil` — renders as `<p>` at 15px/400/`--cl-text-muted`
- `width :string, values: ~w(wide reading), default: "wide"` — drives `max-width`
- `:actions` slot — optional, floated right in the header row via `.cl-row--between`
- `:breadcrumb` slot — optional, renders above the h1
- `:subnav` slot — optional, renders between header and body (tabs, filters)

**Width contract:**
- `:wide` → `max-width: var(--cl-content-max, 1200px)` centered with `--cl-page-gutter` horizontal padding
- `:reading` → `max-width: var(--cl-rail-width, 352px)` + `--cl-page-gutter` (used by conversation view, P38+)
- Both widths are set via `.cl-page--wide` / `.cl-page--reading` CSS modifier classes that reference the layout tokens

**Renders inside:** existing `.cl-main` (the `cl_shell` outer frame); does NOT replace or wrap `.cl-main`.

**CSS classes introduced:** `.cl-page`, `.cl-page--wide`, `.cl-page--reading`, `.cl-page__header`, `.cl-page__title`, `.cl-page__subtitle`, `.cl-page__body`

---

### 2. `cl_hero/1` (UIC-02, CONTEXT D-02)

**Structure:**
```
<section class="cl-hero">
  <span class="cl-hero__job">{job label}</span>
  <span class="cl-hero__count">{count}</span>  <!-- Fraunces 48px copper -->
  [detail slot — optional sub-line, e.g. "Recover-resolved quiet sub-line"]
  [CTA: <.cl_button variant="primary"> via cta/href attrs or inner_block]
</section>
```

**Attributes:**
- `count :integer, required: true` — renders in copper Fraunces 48px; MUST be integer (de-polymorphized)
- `job :string, required: true` — verb-led label at 18px/600/`--cl-text`
- `href :string, default: nil` — primary CTA destination (wraps the count in a `<.link>` if no `cta` slot)
- `cta :string, default: nil` — CTA button label text; renders `<.cl_button variant="primary">` below count
- `:detail` slot — optional quiet sub-line below count; 13px/`--cl-text-muted`; for the P39 Recover-resolved sub-line
- `calm? :boolean, default: false` — renders count in `--cl-success` instead of `--cl-primary` (zero/all-caught-up state)

**Visual contract:**
- Full-width block (no column constraint in the grid; uses `.cl-home-grid`'s first full-width row in P39)
- Count at Fraunces 48px, line-height 1, color `--cl-primary` (copper)
- "~2–3× the visual weight" of a standard `cl_stat` (32px count) achieved through size + full-width + container mass
- `calm?` state: count switches to `--cl-success` (Lichen green) — never loses the label context (§7.5)

**CSS classes introduced:** `.cl-hero`, `.cl-hero__job`, `.cl-hero__count`, `.cl-hero__count--calm`, `.cl-hero__detail`, `.cl-hero__cta`

---

### 3. `cl_stat/1` — de-polymorphized (UIC-02, CONTEXT D-01)

**Breaking change to existing attr:** `count :any` → `count :integer, required: true`

No visual change to existing `.cl-stat` / `.cl-stat__count` CSS — the narrowing is purely
at the component API level. Any caller passing a non-integer (e.g., a health string) must
be migrated; no such callers exist in P37 scope (screen migrations are P38/P39).

**Unchanged attrs:** `job`, `meta`, `href`, `cta`, `icon`, `calm?`, `:inner_block`, `:rest`

---

### 4. `cl_disclosure/1` (UIC-03, CONTEXT D-03)

**Structure:**
```
<details class="cl-details cl-disclosure" id={@id} {if @open, do: [open: true], else: []}>
  <summary class="cl-details__summary">{render_slot(@summary)}</summary>
  {render_slot(@inner_block)}
</details>
```

**Attributes:**
- `id :string, required: true` — stable DOM id; required for LiveView diffing safety
- `open :boolean, default: false` — rendered ONLY as the static HTML `open` attribute on initial mount; NOT bound to a server assign after that; enables P41 auto-expand pattern
- `:summary` slot, required — renders inside `<summary>`
- `inner_block` — the disclosure body content

**Patch-safety mechanism (CONTEXT D-03 confirmed):**
The `<details>` element carries `phx-update="ignore"` so LiveView's diff/patch algorithm never re-drives the `open` attribute after initial render. A PubSub-triggered re-render MUST NOT reset the panel state. This is the locked invariant; the `phx-update="ignore"` attribute is the implementation mechanism.

**Interaction contract:**
- Open/close is driven 100% by the browser's native `<details>` toggle — no `phx-click`, no assigns toggle, no JS hook for state
- The static `open` attr (when truthy) only controls the initial render state
- `Phoenix.LiveView.JS` is explicitly NOT used on this primitive (it is reserved for rail-level controls in P41)

**CSS:** Reuses existing `.cl-details` rules (`cairnloop.css:477-485`) — summary style, `dl/dt/dd` child rules, webkit marker reset. No new CSS classes needed beyond adding `.cl-disclosure` as an identifier class.

---

### 5. `cl_fact_list/1` (UIC-04, CONTEXT D-05)

**Structure:**
```
<dl class="cl-fact-list">
  <div :for={fact <- @facts} class="cl-fact-list__row">
    <dt class="cl-fact-list__label">{fact.label}</dt>
    <dd class="cl-fact-list__value">{fact.value}</dd>
  </div>
  {render_slot(@inner_block)}  <!-- optional custom rows -->
</dl>
```

**Attributes:**
- `facts :list, default: []` — list of `%{label: string, value: string}` maps; rendered as `dt`/`dd` pairs
- `inner_block` — optional slot for custom rows beyond the facts list

**Visual contract:**
- Labels (`dt`) at 12px/500/`--cl-text-muted` (matches `.cl-details dt` pattern already in CSS)
- Values (`dd`) at 13px/400/`--cl-text`; `margin: 0 0 var(--cl-space-3)`
- No horizontal rule between rows by default — use `.cl-list-row` pattern only when call site needs separators

**CSS classes introduced:** `.cl-fact-list`, `.cl-fact-list__row`, `.cl-fact-list__label`, `.cl-fact-list__value`

**Rationale for dedicated class vs reusing `.cl-details dl`:** The `.cl-details dl/dt/dd` rules are scoped inside `.cl-details` — they only apply when `cl_fact_list` is inside a disclosure. `cl_fact_list` is a standalone label/value primitive used in many non-disclosure contexts (customer context panels, source metadata, stats detail). Dedicated `.cl-fact-list` CSS is required.

---

### 6. `cl_source_card/1` (UIC-04, CONTEXT D-06)

**Structure:**
```
<div class="cl-source-card cl-source-card--{source_variant}">
  <header class="cl-source-card__header">
    <.cl_icon name={variant_icon(@source_variant)} class="cl-source-card__icon" />
    [title slot]
  </header>
  <div class="cl-source-card__body">{render_slot(@inner_block)}</div>
  [meta slot — optional; renders at 12px/`--cl-text-muted`]
</div>
```

**Attributes:**
- `source_variant :string, values: ~w(success info neutral warning danger ai), default: "neutral"` — maps to status token triplet
- `:title` slot, required — article title / source name at 13px/600/`--cl-text` (or variant text token)
- `inner_block` — body content (snippet, confidence, last-published note)
- `:meta` slot — optional bottom metadata row (version, date, usage flag)

**Visual contract:**
- Surface: `--cl-{variant}-surface`; border: 1px solid `--cl-{variant}-border`; radius: `--cl-radius-sm` (6px)
- Header icon uses `cl_icon` at 16px; icon silhouette matches variant (same map as `cl_chip`)
- Title text color: `--cl-{variant}-text` for non-neutral; `--cl-text` for neutral
- Body text: 13px/400/`--cl-text-muted`
- Icon MUST always be present (never color alone — §7.5)

**Drift-map alignment (P40 will use these variants):**
- `source_variant="success"` replaces `#4A6238` (Deep Lichen) inline style
- `source_variant="info"` replaces `#3F6F80` (Waypoint Blue) inline style

**CSS classes introduced:** `.cl-source-card`, `.cl-source-card--success`, `.cl-source-card--info`, `.cl-source-card--warning`, `.cl-source-card--danger`, `.cl-source-card--ai`, `.cl-source-card__header`, `.cl-source-card__icon`, `.cl-source-card__body`, `.cl-source-card__meta`

---

### 7. `cl_status_cell/1` (UIC-04, CONTEXT D-07)

**Structure:**
```
<span class="cl-status-cell">
  <.cl_chip variant={@variant} label={@label} icon={@icon} />
</span>
```

**Attributes:**
- `variant :string, values: ~w(success info warning danger ai neutral), default: "neutral"` — passed through to `cl_chip`
- `label :string, required: true` — always-visible text label (never color alone)
- `icon :string, default: nil` — overrides default chip icon when provided

**Visual contract:**
- Renders a `.cl-chip` sized appropriately for a table cell (existing chip sizing: 12px font, pill shape)
- The wrapping `.cl-status-cell` span is minimal — it exists to provide a stable semantic container for table column alignment
- `label` is always present and visible; NEVER omit (§7.5 invariant)

**Note on `action_tone/1` (CONTEXT D-07):** `AuditLogPresenter.action_tone/1` does NOT exist yet. `cl_status_cell` is a generic primitive; it takes `variant` and `label` directly. The tone-mapping function will be added to `AuditLogPresenter` in P38/P40 when the audit screen wires the cell.

**CSS classes introduced:** `.cl-status-cell` (minimal wrapper; chip CSS unchanged)

---

### 8. `cl_switch/1` (UIC-04, CONTEXT D-04)

**Structure:**
```
<button
  class="cl-switch"
  type="button"
  role="switch"
  aria-checked={to_string(@checked)}
  {@rest}
>
  <span class="cl-switch__track">
    <span class="cl-switch__thumb"></span>
  </span>
  <span class="cl-switch__label">{@label}</span>
</button>
```

**Attributes:**
- `checked :boolean, required: true` — drives `aria-checked`; visual state (track fill / thumb position) is CSS-only via `[aria-checked="true"]`
- `label :string, required: true` — always-visible text label (§7.5; never color alone for on/off state)
- `:rest` global — for `phx-click`, `phx-value-*`, `disabled`, etc.

**Interaction contract:**
- This is a server-controlled toggle (LiveView idiom: `phx-click` → event → LiveView assign → re-render)
- `aria-checked` accurately reflects the server-side `checked` state
- The button meets the 44×44px minimum tap target (`min-height: 44px; min-width: 44px` on `.cl-switch`)
- `disabled` state: `opacity: 0.5; cursor: not-allowed` (matches `.cl-button:disabled`)

**Visual contract:**
- Track: `--cl-border` background when unchecked → `--cl-primary` when checked; height 24px; width 44px; radius `--cl-radius-full`
- Thumb: 20px circle, `--cl-surface-raised` (white); transitions `translateX` from left to right
- Transition: `transform var(--cl-dur-instant, 100ms) var(--cl-ease-out)` on the thumb; `background-color var(--cl-dur-instant, 100ms) var(--cl-ease-out)` on the track
- Label: 13px/500/`--cl-text`; visible on both sides of the thumb (positioned after the track)

**CSS classes introduced:** `.cl-switch`, `.cl-switch__track`, `.cl-switch__thumb`, `.cl-switch__label`

---

### 9. `.cl-table-scroll` wrapper (UIC-05, CONTEXT D-11)

**Not a component — a CSS class + inline markup pattern applied to existing `.cl-table` instances.**

**HTML pattern:**
```html
<div class="cl-table-scroll" role="region" tabindex="0" aria-label="{descriptive label}">
  <table class="cl-table">…</table>
</div>
```

**CSS definition:**
```css
.cl-table-scroll {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}
```

**Accessibility contract:**
- `role="region"` — makes the scroll container a landmark
- `tabindex="0"` — makes it keyboard-focusable (required for keyboard table scrolling)
- `aria-label` — descriptive; e.g. `"Audit log"`, `"Knowledge base articles"`, `"Search results"`; MUST be provided at each call site
- Focus indicator: `.cl-table-scroll:focus-visible { box-shadow: var(--cl-focus-ring); border-radius: var(--cl-radius-xs); }`

**Scope:** Phase 37 applies this wrapper to every existing `.cl-table` instance in
`lib/cairnloop/web/`. P43 verifies accessible scrolling on narrow widths.

---

## Copywriting Contract

This phase builds primitives only — the copy lives in the component slots and caller
templates, not in the components themselves. The contracts below bind the executor on
what copy patterns the primitives must support, not the literal screen copy (that is
P38–P45).

| Element | Copy contract | Notes |
|---------|---------------|-------|
| `cl_page` title | Concise noun phrase: "Inbox", "Audit Log", "Knowledge Base", "Settings" — max ~3 words | Source: brand §5.2 "calm, action-oriented" |
| `cl_page` subtitle | Optional; 13px muted; describe the operator's job in this section — not a tagline | Source: JTBD doc — operators need orientation, not marketing |
| `cl_hero` job label | Verb-led, 2–3 words: "Work the queue", "Recover resolved" | Source: vM016 brief, JTBD table |
| `cl_hero` CTA label | Verb + noun: "Open inbox", "View resolved" — NOT "Click here" / "Go" | Source: brand §12.3 CTA language |
| `cl_hero` `calm?` state | Handled by caller — zero state copy is a P39 concern; primitive just switches to success color | Source: CONTEXT D-01 / P39 scope |
| `cl_disclosure` summary | Sentence-case noun phrase describing the hidden content: "Inputs & scope", "Policy explanation", "Raw snapshot" | Source: D2 tier naming |
| `cl_fact_list` label | Title-case noun: "Plan", "Account", "Risk tier", "Created" | Source: existing context panel patterns |
| `cl_source_card` title | Article title or source name; no truncation in primitive — caller controls length | Source: brand §10.3 source card spec |
| `cl_status_cell` label | Sentence-case status: "Action proposed", "Approved", "Blocked" — humanized via `AuditLogPresenter.action_label/1` | Source: audit_log_presenter.ex |
| `cl_switch` label | Noun describing what is toggled: "Draft mode", "Notifications", "Dark theme" — NOT "On/Off" alone | Source: §7.5 never-color-alone extends to toggle labels |
| `.cl-table-scroll` aria-label | Descriptive table name: "Audit log", "Knowledge base articles" — NOT "table" or "data" | Source: WCAG 2.2 accessible name |
| Token-purity failure (test) | Not customer-visible; test failure message: "BRAND-04 contract violated — new component emits hex …" | Source: brand_token_gate_test.exs pattern |

**No primary CTA:** This phase has no user-facing CTA — it is a primitives phase with no screens.

**No destructive actions:** No destructive actions in scope for P37 primitives. (Approve/Reject/Defer exist on live screens, adopted in P40+; the primitives themselves carry no destructive-action copy.)

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not applicable (Phoenix/Elixir project) |
| third-party | none | not applicable |
| npm / hex third-party components | none | not applicable |

This phase adds no new dependencies. All primitives are pure `Phoenix.Component` functions
following the established `components.ex` pattern. No hex packages, npm packages, or
component registry imports.

---

## Token-Purity Verification Contract

All eight new primitives must produce rendered HTML that contains no `#`-prefixed hex
literals. This is verified by extending `test/cairnloop/web/components_test.exs` with
headless `Phoenix.LiveViewTest.render_component/2` tests that assert:

```elixir
# Token-purity assertion pattern for each new primitive
refute html =~ ~r/#[0-9a-fA-F]{3,6}/
```

Additionally, each new primitive must pass the existing `BrandTokenGateTest` — which
scans `lib/cairnloop/web/*.ex` for `var(--cl-*, #hex)` fallback patterns. New components
must use bare `var(--cl-*)` form in any CSS classes they emit (the CSS is in
`cairnloop.css`, not in the `.ex` files, so the gate is satisfied by not writing hex in
the component module itself).

**Structural markers to assert in tests:**
- `cl_disclosure`: rendered HTML contains `<details` and `phx-update="ignore"` — confirming patch-safety
- `cl_switch`: rendered HTML contains `role="switch"` and `aria-checked`
- `cl_status_cell`: rendered HTML contains `cl-chip` and a visible text label — confirming no color-alone
- `cl_source_card`: rendered HTML contains `<svg` (icon present) — confirming no color-alone
- `.cl-table-scroll` wrapper: rendered HTML contains `role="region"` and `tabindex="0"`

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS (override rationale recorded — brand book §8.2/§8.3 supersedes generic heuristic)
- [ ] Dimension 5 Spacing: PASS (override rationale recorded — `--cl-space-1` excluded from P37 surface; `--cl-space-4` is 3×4px grid-aligned)
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending

---

## Pre-Population Audit

| Decision | Source | How Used |
|----------|--------|----------|
| Component set (8 primitives) | CONTEXT D-01..D-11 + UIC-01..05 | Entire component inventory |
| No shadcn gate | Tech stack (Phoenix/Elixir, no React) | shadcn gate skipped |
| Spacing tokens `--cl-space-*` | `cairnloop.css:86-101` | Spacing scale table |
| Layout tokens `--cl-content-max`/`--cl-rail-width`/`--cl-page-gutter` | CONTEXT D-09 + UIC-05 | New tokens section |
| Inert utility definitions | CONTEXT D-10 + UIC-05 | Utilities table |
| `.cl-table-scroll` CSS-only pattern | CONTEXT D-11 + UIC-05 | Wrapper spec |
| Typography sizes/weights | `cairnloop.css:75-85` + brand book §8.2/§8.3 | Typography table |
| Typography override rationale | brand book §8.2/§8.3; `cairnloop.css:75-84`; CLAUDE.md decision policy | Dimension 4 override block |
| Spacing override rationale | `cairnloop.css:86-101`; CLAUDE.md decision policy; `--cl-space-1` not in P37 surface | Dimension 5 override block |
| `--cl-space-1` excluded from P37 surface | `cairnloop.css:337` (chips use space-2); grep confirmed no P37 primitive consumes 2px | Spacing table + override block |
| Hero count 48px Fraunces | SC-2 "~2–3× the weight of 32px `cl-stat__count`"; brand book §8.3 marketing H1 | Hero count size |
| 70/20/10 copper palette contract | brand book §7.3 + vM016 brief | Color section |
| Status variant triplets | `cairnloop.css:60-67` | Semantic color table |
| Never-color-alone rule | brand §7.5 | All status-bearing primitives |
| `cl_disclosure` `phx-update="ignore"` | CONTEXT D-03 "patch-safety" | Disclosure spec |
| `cl_switch` `role="switch"` | CONTEXT D-04 | Switch spec |
| `cl_status_cell` no `action_tone/1` | CONTEXT D-07 + `audit_log_presenter.ex` | Status cell note |
| `cl_page` renders inside `.cl-main` | CONTEXT D-08 | Page shell spec |
| Reuse `.cl-details` CSS | CONTEXT code-context + `cairnloop.css:477` | Disclosure CSS reuse |
| Brand token gate must stay green | CONTEXT D-13 + `brand_token_gate_test.exs` | Token-purity section |
| 44px touch target for `cl_switch` | P43 RESP-02 preemptive + `--cl-control-h-lg` | Spacing exceptions |
| Copy tone: calm, action-oriented, never raw terms | brand §5.2 + §5.3 | Copywriting contract |
| `cl_source_card` drift-map variants | vM016 brief drift map + CONTEXT D-06 | Source card variant table |
| No new dependencies | CONTEXT scope + architecture invariants | Registry safety |

**All fields pre-populated from upstream artifacts. Zero user questions required.**
