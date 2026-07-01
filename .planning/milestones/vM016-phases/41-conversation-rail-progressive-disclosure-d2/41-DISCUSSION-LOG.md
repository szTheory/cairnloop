# Phase 41: Conversation Rail Progressive Disclosure (D2) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-04
**Phase:** 41-conversation-rail-progressive-disclosure-d2
**Mode:** advisor (minimal_decisive tier — technical owner, opinionated philosophy)
**Areas discussed:** Tier-3 raw placement, Density toggle scope, Expand/Collapse-all reach, Auto-expand trigger

---

## Tier-3 raw placement

| Option | Description | Selected |
|--------|-------------|----------|
| Nest, don't pool | Keep each Tier-3 expander nested in its owning Tier-2 group; move the always-visible trace `dl` into its own collapsed group | ✓ |
| Pool into one "Raw / advanced" group | Collapse all Tier-3 content into a single flat group at the card bottom | |

**User's choice:** Nest (recommended).
**Notes:** Existing nested raw expanders (`conversation_live.ex:1001/1018/1048`) are already
D-22-compliant — keep them. Only the always-visible trace `dl` (`:1056-1063`) violates RAIL-02
and must collapse into a standalone "Identifiers & trace" `cl_disclosure`. A `phx-update="ignore"`
Tier-2 group covers its whole subtree, so nested Tier-3 needs no extra guard.

---

## Density toggle scope

| Option | Description | Selected |
|--------|-------------|----------|
| Spacing only, orthogonal | comfortable↔compact controls padding/gap via `data-density`; does not drive open-state; rail-scoped; localStorage | ✓ |
| Density also drives open-state | compact = Tier-2 collapsed, comfortable = Tier-2 open | |

**User's choice:** Spacing only, orthogonal (recommended).
**Notes:** Keeping density independent from disclosure means the two control systems never fight.
Cockpit-wide density deferred. Suggested key `cl:rail:density`, default `comfortable`, applied on
mount via a small JS hook.

---

## Expand/Collapse-all reach

| Option | Description | Selected |
|--------|-------------|----------|
| Tier-2 only | Operate on Tier-2 groups only; leave nested Tier-3 + Trace untouched; Collapse-all may collapse blocking-card Tier-2 (Tier-1 stays visible) | ✓ |
| Tier-2 + Tier-3 | Also open/close nested raw expanders | |

**User's choice:** Tier-2 only (recommended).
**Notes:** Matches success-criterion-3 wording exactly. Mark Tier-2 groups (`data-tier="2"`) so JS
scopes precisely. Opening all raw dumps would be noisy.

---

## Auto-expand trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Pending/blocking, initial-render only, no PubSub re-snap | Static `open` for pending-approval OR hard-block cards at first render; no re-open on PubSub transition (accepted invariant cost) | ✓ |
| Re-expand on PubSub transition | Re-open when a card becomes pending mid-session | (rejected — violates no-assigns-bound-open) |

**User's choice:** Pending/blocking, initial-render only (recommended).
**Notes:** Auto-expand Inputs & scope on pending/blocking; also Policy explanation when block is
`policy_denied`. A card that becomes pending mid-session via PubSub will NOT auto-snap-open — this
is the deliberate cost of the no-assigns-bound-open invariant (D2 / P37 D-03 / UIC-03). Recorded so
the planner does not introduce an assign to "fix" it.

---

## Claude's Discretion

- Exact `data-*` attribute names, localStorage key string, CSS class names.
- Whether rail controls (Expand/Collapse-all + density) share one header cluster (recommended).
- Precise per-state Tier-2 group selection within the D-08 trigger set.
- Whether the draft card gains the same accordion treatment or only carries the Tier-1 quartet.

## Deferred Ideas

- Cockpit-wide density preference (rail-scoped only this phase).
- Persisting individual panel open/closed state across refresh (only density persists per RAIL-03).
