---
gsd_state_version: 1.0
milestone: vM013
milestone_name: Support-Triggered Outbound Lifecycle
status: "Phase 24 implemented; next step is Phase 25 planning/execution"
stopped_at: Phase 24: Individual Outbound UI
last_updated: "2026-05-26T16:30:00.000Z"
last_activity: "2026-05-26 — Phase 24 implemented: outbound timeline cards and resolved-only recovery follow-up trigger added to ConversationLive."
progress:
  total_phases: 5
  completed_phases: 3
  total_plans: 3
  completed_plans: 3
  percent: 60
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** vM013 — Support-Triggered Outbound Lifecycle

## Current Position

Phase: 24
Plan: 24-01
Status: Phase 24 completed in code.
Last activity: 2026-05-26 — Phase 24 implemented (Individual Outbound UI).

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

Last session: 2026-05-26T16:30:00.000Z
Stopped at: Phase 24: Individual Outbound UI completed.
Next step: Phase 25 — Bulk Selection & Fan-out
