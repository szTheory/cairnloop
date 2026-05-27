# Phase 25: Bulk Selection & Fan-out - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in 25-CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 25-bulk-selection-fan-out
**Areas discussed:** Cohort eligibility, Selection model, Preview & message contract, Batch safety rails

---

## Provenance Note

The prior GSD session crashed mid-`/gsd:discuss-phase` after presenting these four areas with recommendations. On resume (2026-05-27), the owner approved **auto-ratification per CLAUDE.md shift-left posture** ("decide for me; do not surface gray areas you can resolve yourself") rather than re-running the Q&A. The decisions below match the recommendations the previous session surfaced, restated here with the alternatives that were considered. The owner-approved auto-ratification plan is at `/Users/jon/.claude/plans/terminal-crashed-here-was-witty-hinton.md`.

---

## Cohort eligibility

| Option | Description | Selected |
|--------|-------------|----------|
| Resolved-only conversations, visible/filtered rows only | Mirrors Phase 24's resolved-only single-conversation recovery. No cross-page selection. | ✓ |
| Resolved + tagged conversations | Adds tag-driven cohorts now. | |
| Any conversation in the inbox | Maximally flexible; no eligibility filter. | |

**User's choice:** Resolved-only, visible-rows-only (auto-ratified).
**Notes:** Tag-driven cohorts are a future phase; deferring them does not constrain the v1 selection model. The "visible rows only" rule explicitly avoids the hidden-footgun where an operator selects more than they can see.

---

## Selection model

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit checkbox multi-select + sticky bulk bar + "select all visible" | Discoverable affordance over today's thin 44-line inbox. LiveView-local `MapSet` state, cleared on filter/navigate. | ✓ |
| Long-press / shift-range power-user selection | Faster for power users, less discoverable; needs richer state. | |
| Modal-driven cohort picker (no inline checkboxes) | Selection lives in a dialog rather than on the row. | |

**User's choice:** Explicit checkboxes + sticky bar + select-all-visible (auto-ratified).
**Notes:** State is in LiveView assigns only — no persistence across reload, cleared on filter change and navigate-away. Power-user shortcuts deferred until usage signals demand.

---

## Preview & message contract

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse configured recovery template + mandatory confirmation modal (count, first-5 sample, rendered body) | Same template as Phase 24's per-conversation recovery. Hard confirmation gate, not a toast. | ✓ |
| Free-form composer for bulk one-off messages | Operator types a one-off message and sends it to the cohort. | |
| Template picker (choose among multiple templates) | Multiple recovery templates selectable at send time. | |

**User's choice:** Reuse the recovery template + mandatory modal (auto-ratified).
**Notes:** Template editing and free-form composition are out of scope for v1 — they belong to a separate (future) phase if ever in scope. The modal must show recipient count, first-5 recipient sample with calm "+N more" tail when applicable, and the rendered template body.

---

## Batch safety rails

| Option | Description | Selected |
|--------|-------------|----------|
| Hard fail-closed above `max_batch_size = 25` (env-configurable); per-recipient `OutboundWorker` jobs with idempotency key | No silent chunking, no partial sends. Calm reason-forward refusal copy on oversized cohorts. | ✓ |
| Silent chunking into 25-per-batch slices | Operator submits 100, system sends in 4 invisible batches. | |
| No cap; operator carries the risk | Trust the operator to self-limit. | |

**User's choice:** Hard fail-closed at 25, env-configurable, per-recipient idempotency (auto-ratified).
**Notes:** Cap of 25 is concrete, not a placeholder. Each per-conversation send still flows through `Cairnloop.Outbound.trigger/2 → OutboundWorker` (existing primitive sealed). A new envelope (`bulk_trigger/2` or equivalent — planner's naming call) wraps the fan-out, snapshots template + cohort at confirmation time, and threads a bulk envelope id through each per-recipient job for at-most-once delivery and audit correlation.

---

## Claude's Discretion

Surfaced as planner-/executor-choice in 25-CONTEXT.md "Claude's Discretion":
- Sticky bulk bar placement (top vs bottom of inbox panel).
- Internal name for the new envelope function (`bulk_trigger/2` vs alternatives).
- Whether `bulk_envelope_id` gets its own table or reuses existing structure.
- "Select all visible" header checkbox treatment (tristate vs binary).
- Location of the `max_batch_size` knob (`config/runtime.exs` vs `Cairnloop.Outbound.Config` vs raw `Application` env).

## Deferred Ideas

Captured in 25-CONTEXT.md `<deferred>`:
- Tag-driven cohorts.
- Cross-page selection.
- Free-form bulk composition.
- Per-recipient personalization preview in the modal.
- Long-press / shift-range selection.
- Marketing/Newsletter drip campaigns (already on project-level Out-of-Scope).
