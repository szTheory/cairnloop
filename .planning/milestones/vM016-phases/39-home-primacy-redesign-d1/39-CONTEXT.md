# Phase 39: Home Primacy Redesign (D1) - Context

**Gathered:** 2026-06-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Restructure `lib/cairnloop/web/home_live.ex`'s render from today's flat 5-cell
`cl-home-grid` into the ratified **D1 two-tier primacy model**:

- A **full-width "Work the queue" hero** (`cl_hero`, ~2–3× the visual weight of
  secondary items) with a single **copper** open-conversation count and a primary
  `cl_button` CTA into the inbox.
- **Recover-resolved** folds into the hero as a **quiet sub-line** (omitted when
  zero) that deep-links to a **resolved-filtered** inbox (fixing the broken CTA).
- A **calmer 3-up "Tend the trail" band** — Tend knowledge / Audit / System health —
  with **neutral (non-copper)** counts; **System health renders as a `cl_chip`**
  (success "Healthy" / warning "Degraded"), never a numeric count slot.
- The **dead 6th grid cell removed**; a **calm all-caught-up zero state** (icon +
  text, never confetti).
- Counts use **scoped count queries** (not a full per-PubSub-tick re-query) and are
  **throttled**, preserving the fail-closed `safe/2` behavior.

**In scope:** Home render restructure; the additive `Chat.list_conversations/1` +
`Chat.count_conversations/1` scoped-query work that backs both the resolved deep-link
and the scoped counts; a minimal query-param resolved filter + applied-filter line on
`InboxLive` (just enough to make HOME-02 honest and non-disorienting).

**Out of scope (defer):** any standing inbox filter chrome (tab bar / segmented
control / dropdown / saved-views); filtering by statuses other than the resolved
deep-link; conversation-rail and other-screen work (later phases). Streams refactor of
the inbox list (additive later only if the list grows unbounded).
</domain>

<decisions>
## Implementation Decisions

These ratify and extend the milestone-level **D1** decision (see STATE.md /
PROJECT.md "vM016 ratified decisions"). D1 itself is NOT re-litigated here; the
decisions below resolve the remaining HOW gray areas.

### Resolved-filter mechanism (HOME-02) — researched & locked
Two independent research agents (architecture + product-IA) **converged on the same
answer**. This was the one genuinely open gray area; the owner delegated it with an
explicit "research deeply, one-shot a perfect recommendation" directive.

- **D-01 (LOCKED):** Implement the resolved filter as a **query param on the existing
  route** — `/inbox?status=resolved` — handled by a **new `handle_params/3`** in
  `InboxLive`. **No new route** (decisive for a host-owned library: a `live_action`
  route would force the library to dictate another route into every host's router per
  filter value; the query param is host-neutral, shareable, bookmarkable, and
  back-button-correct by construction). Home's CTA becomes a plain
  `href="/inbox?status=resolved"`.
  - **Rejected:** `live_action` route (bloats host routing), assign-only tabs (not
    URL-addressable → deep-link impossible), streams refactor (churns sealed
    Phase 25/28 bulk-selection + PubSub paths; filtered-insert leak risk — defer).
- **D-02:** Push the filter into the **`Chat` facade as a scoped Ecto `where`**, not an
  in-memory `Enum.filter`. Add **`Chat.list_conversations/1`** (optional opts;
  `:status` atom) and **`Chat.count_conversations/1`**, both delegating to one private
  `scope_status/2`. Preserve the existing **0-arity `list_conversations/0`** verbatim
  (additive / sealed-contract invariant). Honors the Governance/`Chat`-facade read
  posture.
- **D-03:** **Fail-closed param handling** — an explicit `normalize_status/1` whitelist
  maps known status strings to atoms; **unknown/garbage → `nil` → unfiltered "all"**
  view (never a crash, never `String.to_existing_atom` on raw input).
- **D-04:** **PubSub stays filter-aware** — `@status` is a durable socket assign;
  `handle_info({:conversations_changed}, …)` re-queries
  `Chat.list_conversations(status: @status)`, so a new `:open` conversation arriving
  while `status=resolved` is active **cannot leak in**. Route `prune_selected_ids/2`
  (existing, inbox_live ~line 579) through **both** `handle_params/3` and the PubSub
  handler so bulk-selection never retains now-hidden rows (silent-count-inflation
  footgun).
- **D-05:** **Applied-filter UX (minimal, non-disorienting).** When a filter is active,
  render a quiet **applied-filter line above the list**: a `cl_chip variant="success"
  label="Resolved"` + a plain `<.link patch={~p"/inbox"}>Show all</.link>` (navigation,
  not a button). Absent when no filter. This is the visible indicator + one-click clear
  (Baymard's #1 filtering rule). Filtered-empty state uses **`cl_empty`** —
  *"No resolved conversations to recover · Show all conversations."* **Copper is NOT
  spent** on the filter (resolved is a status, not a route → Lichen/success chip),
  protecting 70/20/10.

### Fail-closed count semantics — locked (owner-confirmed)
- **D-06:** `cl_hero`/`cl_stat` are now `count :integer` (de-polymorphized in P37), so
  the old `count_or_dash` returning `"—"` no longer type-checks. `safe/2` fails closed
  to **`0`** for the number — but `0` would render as the calm "all caught up" success
  state, which is **dishonest when a count is actually unavailable**. Resolve by showing
  a **distinct quiet neutral sub-line ("Count unavailable")** for the error case, so
  error ≠ calm-zero. Keeps the integer type clean and the copy honest/reason-forward.
  (Planner: thread an `unavailable?`/error signal separate from the numeric count;
  applies to both the hero and the band tiles.)

### Zero state composition (HOME-04) — locked (owner-confirmed)
- **D-07:** When the open queue is empty, the **hero region swaps** to a calm `cl_empty`
  success block (icon + "All caught up"); the secondary **"Tend the trail" band
  persists** below so the operator can still dip into Tend / Audit / Health. **Not** a
  whole-page celebration. No confetti.

### System health in the band (HOME-03) — locked (owner-confirmed)
- **D-08:** The health cell uses the **same secondary-tile shape** as Tend/Audit, but
  renders a **`cl_chip`** (success "Healthy" / warning "Degraded") **where the neutral
  number would go** — keeping the 3-up grid uniform while never occupying a numeric
  count slot. Reuses `InboxLive`-style variant mapping; state conveyed by icon + text,
  never color alone (brand §7.5).

### Scoped counts + throttle (HOME-05) — Claude's discretion (decided)
- **D-09:** Replace Home's full-list `Enum.count` loads with **scoped count queries**
  (`Chat.count_conversations(status: …)` — cheap `SELECT count(*) … WHERE`), sharing the
  same `scope_status/2` as the list query so the CTA badge count and the landed
  filtered list can never disagree. **Throttle** the PubSub-driven recount by coalescing
  bursts of `{:conversations_changed}` into at most one recount per window (e.g.
  ~500ms–1s) via a `Process.send_after` self-message + a "pending" flag — exact
  mechanism/interval is researcher/planner discretion. Preserve `safe/2` fail-closed.

### Pre-existing bug to fix in passing
- **D-10:** `home_live.ex`'s `cl_stat` for "Recover resolved" currently passes a
  **duplicate `href`** (lines ~74 and ~84); whichever wins is implementation-dependent.
  The planner must ensure the resolved CTA resolves **deterministically** to
  `/inbox?status=resolved`.

### Claude's Discretion
- Exact throttle interval/mechanism (D-09).
- Exact `cl_empty` icon choices, sub-line microcopy wording, and CSS class names for
  the applied-filter row (a single small `.cl-applied-filter` flex layout class at most
  — composed from existing `.cl-` utilities; no new component primitive).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone / roadmap / decisions
- `.planning/ROADMAP.md` § "Phase 39" — goal, 5 success criteria, depends-on, UI hint.
- `.planning/REQUIREMENTS.md` — HOME-01 … HOME-05 (full requirement text).
- `.planning/STATE.md` "vM016 ratified decisions" — D1/D2/D3 + gate + motion (do not
  re-litigate; D1 is this phase's anchor).
- `.planning/vM016-UI-ITERATION-BRIEF.md` § "D1 — Home: two-tier primacy model" —
  persona/JTBD/IA narrative, the decided design direction, rationale + footguns
  (esp. `assign_counts/1` per-PubSub-tick re-query footgun; copper-as-route-marker;
  egalitarian-grid antipattern).
- `.planning/PROJECT.md` "Architectural Invariants" — facade reads, additive/sealed
  contract, snapshot-at-decision, fail-closed envelope cap.

### Brand / design system
- `prompts/cairnloop_brand_book.md` — voice (calm/fail-closed/reason-forward/honest),
  70/20/10 color discipline, copper = route marker, chip rules, empty-state rules,
  §7.5 never-state-by-color-alone.
- `prompts/elixir-lib-customer-support-automation-deep-research.md` §296–323 —
  host-owned routing posture (router macro, not separate endpoint; route placement is
  host-owned) — the constraint behind D-01 (no new routes).

### Prior phase context (primitives this phase consumes)
- `.planning/phases/37-component-primitives/37-CONTEXT.md` — `cl_hero` (with `:detail` +
  `:cta_slot` slots), `cl_stat` de-polymorphized to `count :integer`, `cl_chip`.
- `.planning/phases/38-shared-page-shell-migration/38-CONTEXT.md` — Home rendered
  through `cl_page` (`width="wide"`).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/cairnloop/web/components.ex`:
  - `cl_hero/1` (line ~167) — `count :integer`, `:job`, `:detail` slot, `:cta_slot`/`@cta`,
    `calm?` → success hue. **Use for the primary hero.**
  - `cl_stat/1` (line ~137) — `count :integer` (numeric-only), `:job`/`:meta`/`:href`/`:cta`/
    `:icon`/`calm?`. **Use for the two numeric secondary tiles (Tend knowledge, Audit).**
  - `cl_chip/1` (line ~76) — `variant` (success/warning/…) + icon + label. **Use for
    System health in the band AND the resolved applied-filter indicator.**
  - `cl_empty/1` (line ~113) — calm icon+title+body. **Use for the zero-state hero swap
    AND the filtered-empty inbox state.**
  - `cl_button/1`, `cl_page/1` (already wraps Home).
- `lib/cairnloop/chat.ex` `list_conversations/0` (line 10) — the facade query to extend
  additively (`/1` opts + `count_conversations/1` + private `scope_status/2`).
- `lib/cairnloop/web/inbox_live.ex` `prune_selected_ids/2` (~line 579) — reuse for
  selection reconciliation on filter change; `status_variant/1` (`:resolved → "success"`,
  line ~537) — reuse for the resolved chip.

### Established Patterns
- `home_live.ex` `safe/2` fail-closed helper (line 168) — preserve; counts degrade to a
  fallback, never crash.
- PubSub: both `HomeLive` and `InboxLive` subscribe to the `"conversations"` topic and
  recompute on `{:conversations_changed}` — the throttle (D-09) and filter-aware re-query
  (D-04) attach here.
- CSS: `priv/static/cairnloop.css` — `.cl-home-grid` (line ~425, mobile-first 1→2→3 col),
  `.cl-hero*` (line ~708), `.cl-stat*` (line ~410). BEM + `.cl-` utilities, no Tailwind,
  no build step. Restructure the Home markup to hero + 3-up band; remove the dead cell.

### Integration Points
- Route: `lib/cairnloop/router.ex:119-120` — `live("/", HomeLive, :index)` and
  `live("/inbox", InboxLive, :index)`, mounted by hosts under a configurable path. Filter
  rides the existing `/inbox` route (no new route).
- `InboxLive.mount/3` (line 81) gains `handle_params/3`; load the (filtered) list there,
  not in `mount` (avoid double-query).
</code_context>

<specifics>
## Specific Ideas

- Owner wants the resolved filter done "toward the ideal," not half-assed — hence the
  deep two-agent research pass. The deferral boundary (no standing tab/saved-views chrome
  now) is deliberate, not an omission: ship the minimal coherent slice that makes the
  deep-link honest, framed so a future inbox-filtering phase can grow from the
  applied-filter line without rework.
- Exact copy (owner-voice, from research): applied-filter line
  *"Showing **resolved** conversations · Show all"*; filtered-empty
  *"No resolved conversations to recover — Nothing is waiting for a recovery follow-up
  right now. … · Show all conversations."*
</specifics>

<deferred>
## Deferred Ideas

- **Standing inbox filter chrome** (All / Open / Resolved tab bar or segmented control;
  status dropdown; Linear/Help-Scout-style saved views; per-status counts) — a real
  "inbox filtering / saved-views" capability; its own future phase. The Phase 39
  applied-filter line is intentionally the seed it would grow from.
- **Phoenix streams refactor of the inbox list** — additive later only if the list grows
  unbounded; avoid churning the sealed bulk-selection/PubSub paths now.
- **"Next in queue" threading after a conversation** and **Audit-row → subject linking**
  — separate IA-threading work noted in the UI brief; later phases.

</deferred>

---

*Phase: 39-home-primacy-redesign-d1*
*Context gathered: 2026-06-04*
