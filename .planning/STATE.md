---
gsd_state_version: 1.0
milestone: vM014
milestone_name: Adoption Proof
status: planning
last_updated: "2026-05-27T13:07:26.160Z"
last_activity: 2026-05-27
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-05-27 — vM014 Adoption Proof kicked off)

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** vM014 Adoption Proof — Phase 27 (Realistic Demo Fixtures) up next

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-05-27 — Milestone vM014 started

## Accumulated Context

### Decisions (carried for next milestone)

**5 patterns graduated to project-level architectural invariants 2026-05-27** — see `PROJECT.md` "## Architectural Invariants": (1) sealed-contract + additive-opts, (2) snapshot-at-decision, (3) fail-closed envelope-boundary cap, (4) three-layer at-most-once, (5) Governance-facade reads from the web layer. Subagents read these from `PROJECT.md`, not from this list.

Remaining carried decisions (milestone-scoped, not project-level):

- Workflow truth in Phoenix/Ecto/Oban; LiveView reflects persisted state and never owns execution. (vM011 → vM013 — consistently honored.)
- `ToolExecutionWorker` is the sole `run/3` caller for governed tools; new write-action types should follow this pattern.
- `Tool.run/3` must NEVER be called from MCP handlers or from the Outbound facade — hard architectural constraint.
- Integration harness (`MIX_ENV=test mix test.integration`) is available for DB-backed proof lanes; CI shift-left used to close vM013 Phase 25's former human-UAT gap. **vM014 Phase 31 will reuse this harness for the golden-path JTBD smoke test.**
- Telemetry uses enum-only labels; no actor_id/conversation_id/payload in metric event names.
- All approval-surface prose reads from snapshotted columns on `cairnloop_tool_proposals` — never call live `Preview.render` from approval or execution context.
- **Audit row both-lanes pattern:** record both successful submissions and fail-closed refusals on the same audit table with a `status` enum (vM013 `BulkEnvelope` `:submitted | :refused_cap_exceeded`); OBS-02 reads see both lanes from one query.
- **OI traces alongside, never replacing:** OpenInference traces emit in parallel with sealed `:telemetry.span/3` bounded-metrics on a disjoint 4-segment namespace. Mirrors vM011 Phase 17.
- **CI shift-left after the fact:** former human-UAT items that needed a real Postgres host can be backfilled into the integration test lane within the milestone close window.
- **vM014 test harness decision (2026-05-27):** `Phoenix.LiveViewTest` + `Phoenix.ChannelTest` for JTBD smoke tests. NOT Wallaby (avoids Selenium/Chrome-in-CI flake), NOT PhoenixTest dep. Proven path across 9 existing integration tests.
- **vM014 D-10 closure path (2026-05-27):** Drop the hex fallback (Option B) in inline `var(--cl-token, #hex)` strings. NOT migrate to named CSS classes (Option A — bigger diff, churns sealed render code). Re-pin 5 headless-token assertions + add negative-grep gate.

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

Last session: 2026-05-27 — vM014 Adoption Proof kicked off via `/gsd-new-milestone vM014`
Stopped at: PROJECT.md + STATE.md updated; REQUIREMENTS.md + ROADMAP.md written; ready for Phase 27 discuss/plan
Next step: `/gsd:discuss-phase 27` (gather Phase 27 context) or `/gsd:plan-phase 27` (skip discussion, plan directly)

## Operator Next Steps

- Phase 27 (Realistic Demo Fixtures — FIX-01..FIX-04) is up next.
- Canonical scope context for all vM014 subagents: `.planning/threads/vM014-adoption-proof-assessment.md` + `/Users/jon/.claude/plans/can-u-decide-this-greedy-balloon.md`.
- 4-agent project research step skipped — research already done in the vM014 adoption-proof assessment cycle.
