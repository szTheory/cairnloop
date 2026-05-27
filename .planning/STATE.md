---
gsd_state_version: 1.0
milestone: vM013
milestone_name: Support-Triggered Outbound Lifecycle
status: executing
stopped_at: "Phase 25 — Bulk Selection & Fan-out: CONTEXT.md written; awaiting plan-phase trigger."
last_updated: "2026-05-27T06:42:24.779Z"
last_activity: 2026-05-27 -- Phase 25 planning complete
progress:
  total_phases: 5
  completed_phases: 0
  total_plans: 3
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** vM013 — Support-Triggered Outbound Lifecycle

## Current Position

Phase: 25
Plan: pending
Status: Ready to execute
Last activity: 2026-05-27 -- Phase 25 planning complete

Progress bar: `██████░░░░ 60%` (3/5 phases)

## Accumulated Context

### Decisions (carried for next milestone)

- MCP write surfaces (MCP-02, MCP-03) and remote OAuth were proven in vM012; they are available for use in outbound triggers if needed.
- `ToolExecutionWorker` is the sole `run/3` caller — any new action type should follow this pattern.
- Integration harness (`MIX_ENV=test mix test.integration`) is available for DB-backed proof lanes — prefer it for Oban worker + LiveView + repo round-trips.
- Telemetry must use enum-only labels; no actor_id/conversation_id/payload in metric event names.
- All approval-surface prose must read from snapshotted columns on `cairnloop_tool_proposals` — never call live `Preview.render` from approval or execution context.
- `Tool.run/3` must NEVER be called from MCP handlers or directly from the Outbound facade — hard architectural constraint.
- **[2026-05-26 roadmap]** Outbound messages are treated as `system_outbound` records appended to the `Conversation` timeline for context continuity.
- **[2026-05-26 roadmap]** Use Oban for scheduling delayed recovery messages (e.g., "Check back in 2 hours").
- **[2026-05-26 roadmap]** Bulk outbound actions require a confirmation preview and batch size limits to prevent resource exhaustion.
- **[2026-05-26 Phase 22]** `system_outbound` messages require `template_id` in metadata and default to `status: "pending"`.
- **[2026-05-26 Phase 23]** All outbound triggers go through `OutboundWorker` for durability and status tracking.
- **[2026-05-26 Phase 24]** The first manual operator affordance is a resolved-only fixed sidebar action that uses a configured recovery template and appends a `system_outbound` card to the thread.
- **[2026-05-27 Phase 25 D-01/D-02]** Bulk selection in `InboxLive` is restricted to resolved conversations and to currently-rendered/filtered rows only — no cross-page selection in v1.
- **[2026-05-27 Phase 25 D-03/D-04/D-05]** Selection model is explicit checkbox multi-select + sticky bulk action bar + "select all visible". State is a LiveView-local `MapSet`, cleared on filter change / navigate; no persistence across reloads.
- **[2026-05-27 Phase 25 D-06/D-07/D-08]** Bulk send reuses the configured recovery template (no free-form composition in v1). A mandatory confirmation modal must show recipient count, first-5 recipient sample, and the rendered template body before sending.
- **[2026-05-27 Phase 25 D-09/D-10/D-11]** Hard fail-closed at `max_batch_size = 25` (env-configurable). No silent chunking or partial sends. Per-recipient `OutboundWorker` jobs carry a bulk-envelope-keyed idempotency token for at-most-once delivery.
- **[2026-05-27 Phase 25 D-12/D-13]** `Cairnloop.Outbound.trigger/2` stays sealed; a new `bulk_trigger/2`-shaped envelope wraps the fan-out, snapshots template + cohort at confirmation time, and emits a single OBS-02-shaped audit row per bulk action.
- **[2026-05-27 Phase 25 D-14]** Cohort eligibility reads from the web layer go through the narrow `Cairnloop.Governance` facade — no direct `Ecto` queries from `InboxLive`.

### Pending Todos

- Centralize duplicated fail-closed search guards before more retrieval-adjacent surfaces appear.
- Root `SECURITY.md` carries 5 open threats (T-10-09..T-10-13) from vM010 — pre-existing debt.

### Blockers/Concerns

- None.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Tech Debt | Root SECURITY.md carries 5 pre-existing open threats (T-10-09..T-10-13) from vM010 | Open | vM011 close |
| Tech Debt | AR-14-02: governed-actions rail lacks pagination (acceptable at current volume) | Open | vM011 Phase 14 |
| Scope | Marketing/Newsletter drip campaigns | Out of Scope | vM013 planning |

## Session Continuity

Last session: 2026-05-27T00:00:00.000Z
Stopped at: Phase 25 — Bulk Selection & Fan-out: CONTEXT.md written; awaiting plan-phase trigger.
Next step: `/gsd:plan-phase 25` (owner will trigger; do NOT auto-route).
Resume file: `.planning/phases/25-bulk-selection-fan-out/25-CONTEXT.md`
