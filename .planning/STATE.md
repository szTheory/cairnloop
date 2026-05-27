---
gsd_state_version: 1.0
milestone: vM014
milestone_name: Adoption Proof
status: executing
stopped_at: Phase 29 context gathered
last_updated: "2026-05-27T22:59:06.624Z"
last_activity: 2026-05-27
progress:
  total_phases: 6
  completed_phases: 2
  total_plans: 11
  completed_plans: 11
  percent: 33
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-05-27 — vM014 Adoption Proof kicked off)

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** Phase 28 — customer-chat-wired-to-real-ingress

## Current Position

Phase: 29
Plan: Not started
Status: Executing Phase 28
Last activity: 2026-05-27

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
- **vM014 SECURITY split (2026-05-27):** T-10-09 + T-10-11 bundle with Phase 30 (same files: `editor.ex` + `suggestion_review.ex`). T-10-10 + T-10-12 + T-10-13 defer to vM015 (domain layer, different file: `knowledge_automation.ex`).

### Pending Todos

- Centralize duplicated fail-closed search guards before more retrieval-adjacent surfaces appear. (Carried from vM009.)
- Root `SECURITY.md` carries 3 open threats (T-10-10, T-10-12, T-10-13) deferred to vM015 — T-10-09 + T-10-11 close in Phase 30.

### Blockers/Concerns

(none — vM013 closed cleanly; vM014 roadmap formalized from assessment thread.)

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Tech Debt | Root SECURITY.md threats T-10-10 / T-10-12 / T-10-13 (domain layer in `knowledge_automation.ex`) — defer to vM015 | Open | vM014 planning (2026-05-27) |
| Tech Debt | AR-14-02: governed-actions rail lacks pagination (acceptable at current volume) | Open | vM011 Phase 14 |
| Tech Debt | Centralize duplicated fail-closed search guards before more retrieval-adjacent surfaces appear | Open | vM009 retrospective |
| Scope | Wallaby / Selenium browser-driven smoke tests | Out of Scope (vM014) | vM014 planning (2026-05-27) |
| Scope | PhoenixTest as a new test dependency | Out of Scope (vM014) | vM014 planning (2026-05-27) |
| Scope | Brand-token migration to named CSS classes (Option A) | Out of Scope (vM014) | vM014 planning (2026-05-27) |
| Scope | Real `SettingsLive` overhaul (MCP tokens / Notifier health / retrieval health / dark mode) | Deferred to vM015 | vM014 planning (2026-05-27) |
| Scope | `/health` + `/metrics` HTTP endpoints | Deferred to vM015 | vM014 planning (2026-05-27) |
| Scope | Marketing/Newsletter drip campaigns | Out of Scope | vM013 planning |
| Scope | In-browser rich text template editing | Out of Scope | vM013 planning |
| Scope | SMS/WhatsApp delivery in the outbound lane | Out of Scope | vM013 planning |

## Session Continuity

Last session: 2026-05-27T22:59:06.621Z
Stopped at: Phase 29 context gathered
Next step: `/gsd:discuss-phase 27` (gather Phase 27 context) or `/gsd:plan-phase 27` (skip discussion, plan directly)

## Operator Next Steps

- Phase 27 (Realistic Demo Fixtures — FIX-01..FIX-04) is up next.
- Canonical scope context for all vM014 subagents: `.planning/threads/vM014-adoption-proof-assessment.md` + `/Users/jon/.claude/plans/can-u-decide-this-greedy-balloon.md`.
- 4-agent project research step skipped — research already done in the vM014 adoption-proof assessment cycle.
