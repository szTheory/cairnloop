# Phase 37: Component Primitives - Context

**Gathered:** 2026-06-03
**Status:** Ready for planning

> **Discussion mode:** Advisor / `minimal_decisive` tier + repo shift-left policy. The vM016
> directions are *ratified* in `.planning/vM016-UI-ITERATION-BRIEF.md` and requirements UIC-01..05
> are locked — this phase only refines HOW. All gray areas below were **auto-decided with rationale**
> rather than bounced back (per `USER-PROFILE.md` decision-handling + `CLAUDE.md` decision policy).
> One mildly notable, easily-reversible call (D-02, hero shape) is flagged for cheap veto.

<domain>
## Phase Boundary

Deliver the **additive** component + CSS primitives that every later vM016 screen depends on —
nothing in this phase migrates a screen, redesigns Home, or remediates drift. Scope is exactly
`lib/cairnloop/web/components.ex` (new function components + `cl_stat` de-polymorphization) and
`priv/static/cairnloop.css` (new component classes, layout tokens, define the inert utilities, the
`.cl-table` scroll-wrapper).

**In scope:** `cl_page`, `cl_hero`, `cl_stat` (narrowed to numeric-only), `cl_disclosure`,
`cl_fact_list`, `cl_source_card`, `cl_status_cell`, `cl_switch`; layout tokens
(`--cl-content-max`, `--cl-rail-width`, `--cl-page-gutter`); CSS definitions for the inert
`cl-gap-2`/`cl-align-center`/`cl-justify-between`; an accessible `.cl-table` scroll-wrapper applied
to existing `.cl-table` instances; headless render tests proving token-purity.

**Out of scope (own later phases):** page-shell *migration* of screens (P38), Home redesign (P39),
hex→token drift remediation in `conversation_live`/`search_modal` (P40), gate *hardening* (P40),
rail progressive disclosure (P41), threading (P42), responsive normalization (P43), motion (P44),
seed/screenshots (P45). New components are *built and unit-tested* here; they are *adopted* later.

</domain>

<decisions>
## Implementation Decisions

### Component set & API shape
- **D-01 — De-polymorphize `cl_stat` to numeric-only (locked by UIC-02).** Replace the
  semantics-bug attr `count :any` (which today accepts a number *or* a health string) with
  `count :integer, required: true`. `cl_stat` stays a single-purpose navigable number tile
  (`job`, `count`, optional `meta`/`cta`/`href`, `calm?`). Health strings no longer flow through
  it — system health routes through `cl_chip` in P39. Keep the existing `.cl-stat` CSS as-is.
- **D-02 — Hero is a *separate* `cl_hero/1` component, NOT a `cl_stat variant="hero"`.** UIC-02 and
  the brief offer "(or)"; we pick the distinct component. Rationale: the whole point of D-01 is to
  *narrow* `cl_stat` — adding a `variant="hero"` re-polymorphizes the component we are deliberately
  shrinking, and the hero has a different anatomy (full-width, ~2–3× weight, a primary `cl_button`
  CTA, and a `:detail` slot for the quiet Recover-resolved sub-line). `cl_hero` carries:
  `count :integer` (copper), a title/job label, a `:detail` slot, and a primary CTA (slot or
  `cta`/`href` attrs). New `.cl-hero` CSS gives the ~2–3× count weight. **[FLAG for cheap veto:
  this adds one public function to `Cairnloop.Web.Components`; additive and reversible pre-adoption.]**
- **D-03 — `cl_disclosure/1` wraps native `<details class="cl-details">`/`<summary>`; open state is
  NEVER bound to a server assign (locked by UIC-03).** Reuse the existing `.cl-details` CSS
  (`priv/static/cairnloop.css:477`). Slots: `:summary` (required) + `inner_block`; attrs: a plain
  boolean `open` rendered **only as the static HTML `open` attribute at initial render** (so P41 can
  auto-expand blocking cards) and a stable `id`. The component must survive a LiveView PubSub
  re-render without snapping shut. **Patch-safety mechanism to confirm in research:** prefer
  `phx-update="ignore"` on the `<details>` element (or a verified stable-id + static-`open` pattern)
  so LiveView diffing never re-drives `open`. No `phx-click`/assigns toggling inside the primitive.
- **D-04 — `cl_switch/1` is a real `role="switch"` button, not a checkbox.** Renders
  `<button role="switch" aria-checked={...}>` with a `checked` boolean, a `label`, and `:rest`
  global (for `phx-click`/`phx-value-*`). It is a server-controlled toggle (LiveView idiom for
  settings), token-pure, with the never-color-alone label always present.
- **D-05 — `cl_fact_list/1` renders a `<dl>` of label/value pairs.** Attr `facts` =
  `[%{label, value}]` plus an optional `inner_block` for custom rows. Highest-reuse primitive — keep
  it minimal; lean on the existing `.cl-details dl/dt/dd` styling idiom or a small `.cl-fact-list`.
- **D-06 — `cl_source_card/1` takes `source_variant` mapping to status tokens.** Variants cover at
  least `success`/`info`/`neutral` (this is what deletes search-modal's `*_style/1` helpers in P40:
  `#4A6238`→success, `#3F6F80`→info). Slots for title/meta + inner body. Token-pure; no inline hex.
- **D-07 — `cl_status_cell/1` is tone-agnostic; it accepts a `variant` (+ `label`) and renders a
  `cl_chip` sized for a table cell.** **Grounding correction:** the brief cites
  `AuditLogPresenter.action_tone/1`, but that function does **not exist yet** — the presenter only
  has `action_label/1` (`lib/cairnloop/web/audit_log_presenter.ex`). So phase 37 builds the generic
  primitive only; the audit-action→tone mapping (adding `action_tone/1` and calling it) belongs to
  the audit-log adoption in P38/P40, not here. `cl_status_cell` must not depend on a non-existent fn.
- **D-08 — `cl_page/1` shell (locked by UIC-01).** Attrs `title`, `subtitle`, and a width attr
  `width :string in ~w(wide reading), default "wide"` (a single enum attr, not two booleans). Slots:
  `:actions`, `:breadcrumb`, `:subnav`, `inner_block`. `:reading` vs `:wide` produce visibly
  different inner `max-width` framing via the new layout tokens (D-09). Renders *inside* the existing
  `.cl-main` shell — `cl_page` is the **inner** frame, `cl_shell` stays the outer chrome.

### CSS / tokens / layout
- **D-09 — Add real *layout* tokens, never tokenize breakpoints.** Add `--cl-content-max`,
  `--cl-rail-width`, `--cl-page-gutter` to the token block. Footgun honored: `var()` is illegal in
  `@media` conditions, so breakpoints stay literal constants (that work lands in P43). `cl_page`
  `:wide`/`:reading` and `.cl-hero` reference these tokens.
- **D-10 — Define exactly the three inert utilities, no more.** `cl-gap-2`, `cl-align-center`,
  `cl-justify-between` are referenced in markup but undefined (confirmed inert). Define them as
  single-purpose composables (`.cl-gap-2{gap:var(--cl-space-2)}`, `.cl-align-center{align-items:
  center}`, `.cl-justify-between{justify-content:space-between}`) meant to sit on a flex container.
  **Do NOT** grow a utility framework — the existing `.cl-row`/`.cl-row--between`/`.cl-row--wrap`/
  `.cl-stack` (`cairnloop.css:423-427`) remain the preferred composite layout primitives; the three
  named utilities are the fine-grained escape hatch only. (Guardrail: BEM + minimal `.cl-`
  utilities, no Tailwind.)
- **D-11 — `.cl-table` scroll-wrapper: CSS class + inline wrapper markup, no new component.** Add
  `.cl-table-scroll { overflow-x:auto }` and wrap existing `.cl-table` instances in
  `<div class="cl-table-scroll" role="region" tabindex="0" aria-label="…">`. Phase 37 fixes the
  latent overflow bug on *current* tables; P43 verifies it as part of responsive acceptance. A
  `cl_table` wrapper component is **not** introduced (tables are hand-authored at varied call sites;
  a 2-line wrapper per site is lower-risk than a markup-shape refactor). Planner may revisit only if
  call-site count makes inline wrapping clearly worse.

### Testing
- **D-12 — Token-purity is proved by headless `render_component/2` tests.** All eight primitives are
  pure `Phoenix.Component` functions — test via `Phoenix.LiveViewTest.render_component/2` (no Repo,
  no live DB), extending `test/cairnloop/web/components_test.exs`. Assert rendered HTML contains no
  `#`-prefixed hex (UIC-04 / success criterion 4) and that `role="switch"` / `<details>` /
  `role="region"` markers are present. None of these need the `REPO-UNAVAILABLE` marker.
- **D-13 — Components must already pass the *current* brand-token gate.** Gate *hardening* is P40,
  but everything shipped here is token-only today so the existing
  `test/cairnloop/web/brand_token_gate_test.exs` stays green.

### Claude's Discretion
- Exact attr names/defaults and slot ordering within each component (researcher/planner finalize).
- Whether `cl_fact_list` reuses `.cl-details dl/dt/dd` styling or gets a dedicated `.cl-fact-list`.
- The precise `cl_disclosure` patch-safety guard (`phx-update="ignore"` vs verified static-`open`) —
  decided by research against the LiveView diffing behavior; the *invariant* (no assigns-bound open)
  is locked.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Ratified milestone direction (read first)
- `.planning/vM016-UI-ITERATION-BRIEF.md` — ratified D1–D3, the drift map, the "design-system
  dividends / componentize" list (defines every primitive in this phase), and the captured footguns.
  **Do not re-litigate — refine.**
- `.planning/REQUIREMENTS.md` §UIC-01..05 — the locked requirements for this phase.
- `.planning/ROADMAP.md` → "Phase 37: Component Primitives" — the 5 success criteria this phase is
  verified against.

### Brand / persona authority
- `prompts/cairnloop_brand_book.md` — §7.5 never-state-by-color-alone, copper=route-marker 70/20/10,
  raw-terms-behind-expanders, §15 motion (motion itself is P44, but primitives must not preclude it).
- `docs/cairnloop-jtbd-and-user-flows.md` — persona/JTBD/IA narrative behind `cl_page`/`cl_hero`.

### Code to read / extend (see Code Context below for specifics)
- `lib/cairnloop/web/components.ex` — existing primitives + the `cl_stat` `count :any` to narrow.
- `priv/static/cairnloop.css` — token system, existing `.cl-details`/`.cl-row`/`.cl-stack`/
  `.cl-table`/`.cl-stat` rules to reuse rather than duplicate.
- `lib/cairnloop/web/audit_log_presenter.ex` — has `action_label/1`; **lacks** `action_tone/1`
  (see D-07).
- `test/cairnloop/web/components_test.exs` — extend for the new primitives.
- `test/cairnloop/web/brand_token_gate_test.exs` — the gate the new components must pass now.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`.cl-details` CSS already exists and is styled** (`cairnloop.css:477-485`, with
  `summary::-webkit-details-marker` reset + `dl/dt/dd` rules) — `cl_disclosure` emits this class
  instead of new CSS (D-03).
- **`.cl-row` / `.cl-row--between` / `.cl-row--wrap` / `.cl-stack` / `.cl-stack--lg`**
  (`cairnloop.css:423-427`) are the established flex layout primitives — prefer over the three
  named utilities (D-10).
- **`.cl-stat` + `__job`/`__count`(copper)/`__count--calm`(success)/`__meta`**
  (`cairnloop.css:403-415`) — keep as-is; `cl_hero` adds a heavier sibling, not a variant (D-02).
- **`cl_chip`** (`components.ex:76`) is the never-color-alone primitive `cl_status_cell` and the
  P39 health indicator delegate to.
- **`cl_button`** (`components.ex:41`, variants default/primary/danger/ghost) — `cl_hero` CTA and
  the P40 footer reuse it.
- **`--cl-dur-panel: 260ms`** motion token already documented "drawer/rail/source-card reveal"
  (`cairnloop.css:139`) — available for P44; nothing here should hardcode durations.

### Established Patterns
- Components are **stateless `Phoenix.Component` functions emitting `.cl-*` classes; CSS is the
  single source of visual truth; tokens only, never inline hex** (`components.ex` moduledoc). All
  new primitives follow this exactly.
- Status components **always pair color + distinct-silhouette icon + text label** (§7.5). `cl_switch`
  and `cl_status_cell` must carry a text label, not color alone.
- `cl_icon` is a self-contained inline-SVG set — new primitives reuse it; no icon-font dependency.

### Integration Points
- `cl_page` renders *inside* the existing `cl_shell`'s `.cl-main` — it is the inner frame; the outer
  nav chrome is untouched this phase.
- Layout tokens (D-09) are referenced by `cl_page`/`cl_hero` now and by P43 responsive rules later.
- Confirmed absent today (this phase must create): the three layout tokens, the three inert-utility
  CSS definitions, `.cl-table-scroll`, and `.cl-hero` — verified via grep of `cairnloop.css`.

</code_context>

<specifics>
## Specific Ideas

- The brief's **drift map is the contract** for `cl_source_card source_variant` and the hex→token
  pairs — build the primitives so the P40 remediation is a clean swap (`#4A6238`→success,
  `#3F6F80`→info; border/text/danger/warning families).
- `cl_hero`'s `:detail` slot exists specifically to host the P39 "Recover-resolved quiet sub-line" —
  design the slot generic enough to hold a sub-line + link without baking Home semantics into P37.
- "~2–3× the weight of a standard stat" (success criterion 2) is a **visual** target met via
  `.cl-hero` count typography, not a structural requirement on `cl_stat`.

</specifics>

<deferred>
## Deferred Ideas

- **`AuditLogPresenter.action_tone/1`** — needed by the audit-log *adoption* of `cl_status_cell`;
  add it in P38/P40 when the audit screen wires the cell, not in this primitives phase (D-07).
- **A `cl_table` wrapper component** — not built now (D-11); reconsider only if many call sites make
  inline `.cl-table-scroll` wrappers unwieldy (P43 responsive work is the natural place to judge).
- **Adoption of every primitive into live screens** — that is the entire point of P38–P45; P37 stops
  at built + unit-tested.

None of the above are scope creep — they are correctly-sequenced into later vM016 phases.

</deferred>

---

*Phase: 37-Component Primitives*
*Context gathered: 2026-06-03*
