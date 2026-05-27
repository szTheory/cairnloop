---
gsd_state_version: 1.0
milestone: vM013
milestone_name: Support-Triggered Outbound Lifecycle
status: vM013 milestone complete
stopped_at: vM013 closed and archived
last_updated: "2026-05-27T12:30:00.000Z"
last_activity: 2026-05-27 — Milestone vM013 completed and archived
progress:
  total_phases: 5
  completed_phases: 5
  total_plans: 9
  completed_plans: 9
  percent: 100
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-05-27 after vM013 milestone close)

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** Planning next milestone

## Current Position

Phase: Milestone vM013 complete
Plan: —
Status: Awaiting next milestone
Last activity: 2026-05-27 — Milestone vM013 completed and archived

## Accumulated Context

### Decisions (carried for next milestone)

- Workflow truth in Phoenix/Ecto/Oban; LiveView reflects persisted state and never owns execution. (vM011 → vM013 — consistently honored.)
- `ToolExecutionWorker` is the sole `run/3` caller for governed tools; new write-action types should follow this pattern.
- `Tool.run/3` must NEVER be called from MCP handlers or from the Outbound facade — hard architectural constraint.
- Integration harness (`MIX_ENV=test mix test.integration`) is available for DB-backed proof lanes; CI shift-left used to close vM013 Phase 25's former human-UAT gap.
- Telemetry uses enum-only labels; no actor_id/conversation_id/payload in metric event names.
- All approval-surface prose reads from snapshotted columns on `cairnloop_tool_proposals` — never call live `Preview.render` from approval or execution context.
- **Sealed public contracts + additive opts:** when a sealed contract needs a new caller, keep the original signature byte-for-byte stable and add an optional opt. Proven across `Governance.propose/3` (vM011), MCP `tools/call` (vM012), and `Outbound.trigger/2` (vM013).
- **Audit row both-lanes pattern:** record both successful submissions and fail-closed refusals on the same audit table with a `status` enum (vM013 `BulkEnvelope` `:submitted | :refused_cap_exceeded`); OBS-02 reads see both lanes from one query.
- **Envelope-boundary safety enforcement:** fail-closed caps (`max_batch_size`) live at the envelope function boundary — defense-in-depth across LiveView, MCP, console, and future callers.
- **D-14 narrow facade gate:** web-layer reads from domain tables go through `Cairnloop.Governance.<purpose>_<read>/1`; a negative grep on the LiveView file is the architectural test.
- **OI traces alongside, never replacing:** OpenInference traces emit in parallel with sealed `:telemetry.span/3` bounded-metrics on a disjoint 4-segment namespace. Mirrors vM011 Phase 17.
- **Three-layer at-most-once execution** (Oban unique + terminal guard + SHA-256 per-attempt run key) for any new write action; pattern reused for vM013 outbound delivery.
- **CI shift-left after the fact:** former human-UAT items that needed a real Postgres host can be backfilled into the integration test lane within the milestone close window.

### Pending Todos

- Centralize duplicated fail-closed search guards before more retrieval-adjacent surfaces appear. (Carried from vM009.)
- Root `SECURITY.md` carries 5 open threats (T-10-09..T-10-13) from vM010 — pre-existing debt.

### Blockers/Concerns

(none — vM013 closed cleanly; previous Phase 25 operator-host migrate + integration-verify blockers were resolved by the CI shift-left commits `5bad851` → `23e700b` on 2026-05-27)

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Tech Debt | Root SECURITY.md carries 5 pre-existing open threats (T-10-09..T-10-13) from vM010 | Open | vM011 close |
| Tech Debt | AR-14-02: governed-actions rail lacks pagination (acceptable at current volume) | Open | vM011 Phase 14 |
| Tech Debt | Centralize duplicated fail-closed search guards before more retrieval-adjacent surfaces appear | Open | vM009 retrospective |
| Tech Debt | D-10 brand-token CSS extraction (inline `var(--cl-<token>, <hex>)` strings are the headless-test contract for v1) | Open | vM013 Phase 26 |
| Scope | Marketing/Newsletter drip campaigns | Out of Scope | vM013 planning |
| Scope | In-browser rich text template editing | Out of Scope | vM013 planning |
| Scope | SMS/WhatsApp delivery in the outbound lane | Out of Scope | vM013 planning |

## Session Continuity

Last session: 2026-05-27T12:30:00.000Z
Stopped at: vM013 closed and archived
Next step: Start the next milestone with `/gsd:new-milestone`.

## Operator Next Steps

- Start the next milestone with `/gsd:new-milestone`
