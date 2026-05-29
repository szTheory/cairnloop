---
gsd_state_version: 1.0
milestone: vM015
milestone_name: Operator Polish + Maintenance Gates
status: Planning complete, ready for execution
last_updated: "2026-05-29T16:00:00.000Z"
last_activity: 2026-05-29
progress:
  total_phases: 4
  completed_phases: 1
  total_plans: 1
  completed_plans: 1
  percent: 25
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-05-29 — vM014 complete)

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** Execute vM015 Operator Polish + Maintenance Gates

## Current Position

Phase: N/A
Plan: N/A
Status: Ready to plan phase 34
Last activity: 2026-05-29

## Accumulated Context

### Decisions (carried for next milestone)

**5 patterns graduated to project-level architectural invariants 2026-05-27** — see `PROJECT.md` "## Architectural Invariants": (1) sealed-contract + additive-opts, (2) snapshot-at-decision, (3) fail-closed envelope-boundary cap, (4) three-layer at-most-once, (5) Governance-facade reads from the web layer. Subagents read these from `PROJECT.md`, not from this list.

Remaining carried decisions (milestone-scoped, not project-level):
- Workflow truth in Phoenix/Ecto/Oban; LiveView reflects persisted state and never owns execution.
- `ToolExecutionWorker` is the sole `run/3` caller for governed tools; new write-action types should follow this pattern.
- `Tool.run/3` must NEVER be called from MCP handlers or from the Outbound facade.
- Telemetry uses enum-only labels; no actor_id/conversation_id/payload in metric event names.
- All approval-surface prose reads from snapshotted columns on `cairnloop_tool_proposals`.
- **Audit row both-lanes pattern:** record both successful submissions and fail-closed refusals on the same audit table.
- **OI traces alongside, never replacing:** OpenInference traces emit in parallel with sealed `:telemetry.span/3` bounded-metrics.

### Pending Todos

- Ensure Phase 34 properly introduces the SettingsLive surface.

### Blockers/Concerns

- (None)

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Scope | Epic 13 Privacy-First Local AI (Nx/Bumblebee) | Deferred to vM016+ | vM015 planning |
| Scope | Epic 12 Advanced Routing & Team Collaboration | Deferred to vM016+ | vM015 planning |
| Scope | Epic 14 Mobile SDK Surface | Deferred to vM016+ | vM015 planning |
| Tech Debt | Centralize duplicated fail-closed search guards before more retrieval-adjacent surfaces appear | Open | vM009 retrospective |

## Session Continuity

Next step: `/gsd-plan-phase 34`

## Operator Next Steps

- Run `/gsd-plan-phase 34` to begin planning the next phase of vM015.