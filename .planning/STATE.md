---
gsd_state_version: 1.0
milestone: vM015
milestone_name: Operator Polish + Maintenance Gates
status: executing
last_updated: "2026-05-29T17:37:58.637Z"
last_activity: 2026-05-29
progress:
  total_phases: 4
  completed_phases: 4
  percent: 100
  note: "All vM015 phases (33–36) executed; released as v0.2.0, then remediated and released as v0.2.1 — published to hex.pm via the new release-please pipeline. Milestone audit gaps closed except the pre-existing integration-suite failures (tracked follow-up)."
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-05-29 — vM014 complete)

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** Execute vM015 Operator Polish + Maintenance Gates

## Current Position

Phase: 36 (all vM015 phases 33–36 executed)
Plan: Complete
Status: vM015 fully executed and released as **v0.2.0**. The milestone audit
(`.planning/vM015-MILESTONE-AUDIT.md`, verdict **gaps_found**) found three shipped
defects — AUDIT-01 (audit log was a no-op stub), OPS-01/OPS-02 (health/metrics plugs
mounted in no router), and REL-01 (CHANGELOG `[0.2.0]` section missing). All remediated
as **v0.2.1**, now **shipped and published to hex.pm** (releases: 0.2.1, 0.2.0, 0.1.0).
The remediation merged via PR #2; the repo was put on the canonical szTheory
**release-please** pipeline (`release-please-config.json`, `.github/workflows/release-please.yml`,
`release_gate` in `ci.yml`), which then cut the `chore(main): release 0.2.1` PR #3, auto-merged
it, tagged `v0.2.1`, and ran `publish-hex` to Hex with zero manual steps. Future releases are a
`fix:`/`feat:` commit on `main` → bot PR → publish. `release_gate` gates on the headless suite
(218 tests, green); the DB-backed `integration` suite is pre-existing-red (10 failures, 3
clusters) and tracked in `.planning/INTEGRATION-SUITE-FOLLOWUP.md` — add it to
`release_gate.needs` once green.
Last activity: 2026-05-30

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

- None

### Blockers/Concerns

- **Integration CI suite red (pre-existing)** — 10 failures in 3 clusters; tracked in
  `.planning/INTEGRATION-SUITE-FOLLOWUP.md`. Not in `release_gate` until green. Not a v0.2.1
  regression (red since before v0.2.0).
- **Verification debt** — phases 33/34/35 have no `VERIFICATION.md` (executed and released
  without GSD verification artifacts). Nyquist `*-VALIDATION.md` missing for 33/34/35
  (only 36 has one).
- **Build gate** — confirm `mix compile --warnings-as-errors` + full `mix test` green in CI;
  the DB-backed LiveView tests (incl. AuditLogLive) are not runnable in this workspace.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Scope | Epic 13 Privacy-First Local AI (Nx/Bumblebee) | Deferred to vM016+ | vM015 planning |
| Scope | Epic 12 Advanced Routing & Team Collaboration | Deferred to vM016+ | vM015 planning |
| Scope | Epic 14 Mobile SDK Surface | Deferred to vM016+ | vM015 planning |
| Tech Debt | Centralize duplicated fail-closed search guards before more retrieval-adjacent surfaces appear | Open | vM009 retrospective |

## Session Continuity

v0.2.1 is shipped/published. Next: `/gsd-complete-milestone vM015` to archive. Future releases
flow through release-please automatically (commit `fix:`/`feat:` to `main`). Optionally close
the integration-suite follow-up and verification debt first.

## Operator Next Steps

- Run `/gsd-complete-milestone vM015` to archive the milestone.
- Fix the pre-existing `integration` CI suite (`.planning/INTEGRATION-SUITE-FOLLOWUP.md`); when
  green, add `integration` to `release_gate.needs` in `ci.yml`.
- (Optional) `/gsd-verify-work 35` (and 33/34) to backfill missing VERIFICATION.md.
- Releases: just commit `fix:`/`feat:` to `main` — release-please cuts + publishes automatically.

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 34 P02 | 20 | 4 tasks | 4 files |