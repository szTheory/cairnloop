# Phase 41: Conversation Rail Progressive Disclosure (D2) - Context

**Gathered:** 2026-06-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Restructure the conversation rail's cards (primarily the `governed-action-card`, and
the draft card where the safety quartet applies) into a **safety-pinned native-`<details>`
accordion**:

- **Tier 1 never collapses** — headline + status, the safety quartet (risk tier ·
  confidence/grounding · policy outcome · approval mode), and the pending
  Approve/Reject/Defer footer are always visible regardless of any `<details>` state.
- **Tier 2/3 detail lives in native `<details>`/`<summary>`** with **no assigns-bound open
  state**, surviving the conversation's PubSub reload handlers (no snapping shut).
- **Blocking/pending cards auto-expand** their Tier-2 group on first render.
- **Rail-level Expand-all / Collapse-all** and a **remembered density toggle** (localStorage)
  work via `Phoenix.LiveView.JS` — never touching Tier 1.

Requirements: **RAIL-01, RAIL-02, RAIL-03**. Success criteria (4) in ROADMAP.md fix *what*
ships; this file records the *how* decisions that were open.

**Not in scope (own phases):** cross-screen threading / next-in-queue (P42), responsive
normalization (P43), motion (P44), seed/screenshots (P45), cockpit-wide density.

</domain>

<decisions>
## Implementation Decisions

### A — Tier-3 raw placement (RAIL-02)
- **D-01: Nest Tier-3 inside its owning Tier-2 group; do not pool into one "raw" bucket.**
  The three existing nested raw expanders are already correct and D-22-compliant — keep
  them where they are:
  - Raw input snapshot inside **Inputs & scope** (`conversation_live.ex:1001`)
  - Per-event reason/metadata inside **History** event items (`conversation_live.ex:1018`)
  - Raw policy snapshot inside **Policy explanation** (`conversation_live.ex:1048`)
- **D-02: Move the always-visible trace-id `dl` into a standalone collapsed Tier-3 group.**
  The `governed-action-trace` `<dl>` (proposal id / tool_ref / version / idempotency key,
  `conversation_live.ex:1056-1063`) is currently always visible — that violates RAIL-02
  (trace ids are Tier 3). Wrap it in its own `cl_disclosure` ("Identifiers & trace") at the
  card bottom, default closed.
- **D-03: `phx-update="ignore"` on a Tier-2 group covers its whole subtree.** Nested Tier-3
  expanders inside an ignored Tier-2 group inherit patch-safety and need **no** additional
  guard. Only the standalone Trace group (not nested in an ignored parent) needs its own
  `cl_disclosure`/`phx-update="ignore"`. The 3 named Tier-2 groups + the Trace group all
  render via the existing `cl_disclosure/1` primitive (Phase 37 D-03).

### B — Density toggle (RAIL-03)
- **D-04: Density = spacing only, orthogonal to open-state.** `comfortable` (default) ↔
  `compact` controls rail card padding/gap via a `data-density` attribute on the rail
  container + CSS. It does **NOT** drive default open/closed of any `<details>` (disclosure
  and density are independent control systems so they never fight).
- **D-05: Rail-scoped, persisted in `localStorage`, applied on mount.** A small JS hook
  reads/writes the preference (suggested key `cl:rail:density`) and applies the attribute on
  mount to avoid churn. Cockpit-wide density is explicitly deferred.

### C — Expand-all / Collapse-all reach (RAIL-03, success criterion 3)
- **D-06: Operates on Tier-2 groups ONLY.** Mark Tier-2 groups (suggested `data-tier="2"`)
  so the JS scopes precisely; nested Tier-3 raw expanders and the standalone Trace group are
  left untouched (opening all raw dumps would be noisy debug detail).
- **D-07: Collapse-all MAY collapse a blocking card's Tier-2.** Tier 1 (quartet + pending
  footer) stays visible regardless, so the operator's decision is never hidden. This matches
  success-criterion-3 wording ("opens all Tier-2 `<details>` without touching Tier 1").

### D — Auto-expand trigger (RAIL-03, success criterion 3)
- **D-08: Auto-expand fires for pending-approval OR hard-block cards.** A card with a pending
  approval (`active_approval.status == :pending`) OR a hard block (`block_reason` =
  `scope_invalid` / `policy_denied`) gets a **static `open`** at initial render on its
  **Inputs & scope** Tier-2 group; when the block is `policy_denied`, also static-open the
  **Policy explanation** group. (Exact group selection per state is a detail the planner may
  tune; the *trigger set* and the *initial-render-only* mechanism are locked.)
- **D-09: Initial-render-only — NO PubSub re-snap-open (locked invariant, do not "fix").**
  Auto-expand is the static HTML `open` attribute at first render only. A card that
  *becomes* pending mid-session via a PubSub re-render will **not** auto-snap open — this is
  the accepted, deliberate cost of the no-assigns-bound-open invariant (D2 / P37 D-03 /
  UIC-03): we never let the server re-open a panel, because that would also snap shut a panel
  the operator manually opened. Recorded so the planner does not introduce an assign to
  "fix" it.

### E — Carried-forward invariants (locked upstream — do not re-litigate)
- **D2 (vM016 ratified):** native `<details>`/`<summary>` for all per-card progressive
  disclosure; **no server assigns bind open state**; `Phoenix.LiveView.JS` only for
  rail-level controls + localStorage density.
- **Phase 37 D-03:** `cl_disclosure/1` already exists and is the primitive to use —
  `<details class="cl-details cl-disclosure" id=… phx-update="ignore" open={@open}>` with a
  `:summary` slot; `open` is the static HTML attribute at initial render only.
- **Phase 40:** drift remediation already reduced hand-rolled markup; prefer migrating the
  rail's bespoke `<details style=…>` expanders to `cl_disclosure` (or carrying
  `phx-update="ignore"`) over adding new bespoke markup.
- **Brand §7.5:** never communicate state by color alone — the safety quartet chips must
  carry text + tone, never tone alone (already honored in current card markup).

### Claude's Discretion
- Exact `data-*` attribute names, localStorage key string, and CSS class names.
- Whether the density toggle and Expand/Collapse-all controls live in a single rail header
  control cluster (recommended) vs separate placements.
- Precise per-state choice of which Tier-2 group(s) auto-open (within the D-08 trigger set).
- Whether the draft card (non-governed-action) gains the same accordion treatment or only
  carries the Tier-1 quartet — planner to confirm against where the quartet actually renders.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase requirements & roadmap
- `.planning/ROADMAP.md` §"Phase 41" — goal + 4 success criteria (Tier-1 always visible;
  3 separate Tier-2 `<details>`; PubSub-survival; auto-expand; Expand-all; localStorage
  density; `cl_disclosure` unit test proving no server assign controls `open`).
- `.planning/REQUIREMENTS.md` — RAIL-01 (Tier-1 never collapses), RAIL-02 (Tier-2/3 in
  assigns-free `<details>`, PubSub-survivable), RAIL-03 (auto-expand + expand/collapse-all +
  remembered density).
- `.planning/PROJECT.md` "## Architectural Invariants" + vM016 D2 ratified decision.

### Component primitive & prior decisions
- `.planning/phases/37-component-primitives/37-CONTEXT.md` D-03 — `cl_disclosure/1`
  contract: native `<details>`, no assigns-bound open, `phx-update="ignore"` patch-safety,
  static `open` at initial render so P41 can auto-expand; reuses `.cl-details` CSS.
- `lib/cairnloop/web/components.ex:198` — `cl_disclosure/1` definition (the primitive to use).

### Code to restructure
- `lib/cairnloop/web/conversation_live.ex:957-1112` — `governed-action-card` template:
  Tier-1 (status chip `:967`, risk/approval meta `:973`, footer `:1068`), Tier-2 sections
  (Inputs `:993`, History `:1008`, Scope `:1038`, Policy `:1044`), and the always-visible
  trace `dl` `:1056` (→ D-02). Existing nested raw expanders at `:1001`, `:1018`, `:1048`.
- `priv/static/cairnloop.css` ~`:477` — `.cl-details` / `cl-disclosure` CSS
  (`summary::-webkit-details-marker` reset, `dl/dt/dd` rules); add `data-density` /
  `data-tier` styling here (no Tailwind, no build step — BEM + `.cl-` utilities).

### Brand
- `prompts/cairnloop_brand_book.md` §7.5 (`:505`) — never state-by-color-alone; calm,
  reason-forward operator copy; mono only for code/IDs/traces (`:591`).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`cl_disclosure/1`** (`components.ex:198`): the exact primitive Phase 37 built for this
  phase — native `<details>` + `phx-update="ignore"` + static `open`. Use for all 3 Tier-2
  groups and the standalone Trace group.
- **`.cl-details` / `cl-disclosure` CSS** (`cairnloop.css:~477`): marker reset + scoped
  `dl/dt/dd` styling already exist — emit these classes, don't write new disclosure CSS.
- **`cl_fact_list/1`** (`components.ex:217`): label/value `<dl>` — candidate for the
  Identifiers & trace group body (D-02) instead of the bespoke `governed-action-trace` dl.

### Established Patterns
- The card is a plain-assign render (P14 D-02, no streams); presenter values are computed in
  the assign block (`conversation_live.ex:839-955`) and rendered in the `~H` below.
- D-22 masking choke point: raw snapshots are only ever exposed behind an explicit expander —
  preserve this when nesting Tier-3.
- Status conveyed by text + tone, never color alone (brand §7.5 / D-13) — already in markup.

### Integration Points
- Rail-level controls (Expand-all / Collapse-all / density toggle) are new UI in the rail
  header; they target the cards' `<details>` via `Phoenix.LiveView.JS` + a small density hook.
  No new server `handle_event` for open-state (that would violate D2/D-09).

</code_context>

<specifics>
## Specific Ideas

- Tier-2 named groups are exactly three (success criterion 2): **Inputs & scope**, **History**,
  **Policy explanation**. The standalone **Identifiers & trace** group (D-02) is Tier-3 and is
  *not* one of the three named Tier-2 groups, so Expand-all does not reach it (D-06).
- The `cl_disclosure` unit test (success criterion 4) must assert no server assign controls
  `open` — i.e., `open` only ever appears as the static initial-render attribute.

</specifics>

<deferred>
## Deferred Ideas

- **Cockpit-wide density preference** (sharing the density toggle across all screens) — bigger
  scope; this phase is rail-scoped only (D-05).
- **Persisting individual panel open/closed state across refresh** — not required by RAIL-03
  (only density persists); would add per-`<details>` localStorage bookkeeping. Defer unless a
  later phase asks for it.

None of the above is in Phase 41 scope.

</deferred>

---

*Phase: 41-conversation-rail-progressive-disclosure-d2*
*Context gathered: 2026-06-04*
