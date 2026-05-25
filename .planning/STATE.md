---
gsd_state_version: 1.0
milestone: vM011
milestone_name: AI Tool Governance & MCP Integration
status: complete
stopped_at: Milestone closed 2026-05-25
last_updated: "2026-05-25"
last_activity: 2026-05-25
progress:
  total_phases: 5
  completed_phases: 5
  total_plans: 17
  completed_plans: 17
  percent: 100
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-05-25)

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** vM011 complete — run `/gsd:new-milestone` to start next milestone.

## Current Position

Phase: —
Status: vM011 milestone closed 2026-05-25
Last activity: 2026-05-25

## Accumulated Context

### Decisions (carried for next milestone)

- MCP write surfaces (MCP-02, MCP-03) and remote OAuth are the natural next expansion now that the internal governed-action contract is proven.
- `ToolExecutionWorker` is the sole `run/3` caller — any new action type should follow this pattern.
- Integration harness (`MIX_ENV=test mix test.integration`) is available for DB-backed proof lanes — prefer it for Oban worker + LiveView + repo round-trips.
- Telemetry must use enum-only labels; no actor_id/conversation_id/payload in metric event names.
- All approval-surface prose must read from snapshotted columns on `cairnloop_tool_proposals` — never call live `Preview.render` from approval or execution context.

### Hygiene Gate — Before vM012 Execution (⚠️ June 2, 2026 deadline for Node.js item)

Before the first `/gsd:execute-phase` of vM012, complete all of the following in order:
1. Run `mix format` — commit any diffs as `chore: fix formatting violations`
2. Update `.github/workflows/ci.yml` — pin `actions/checkout` and `actions/cache` to Node.js 24-compatible versions or add `env: ACTIONS_RUNNER_NODE_VERSION: '24'` (**hard deadline: June 2, 2026** — GitHub forces Node.js 24 default then)
3. `git push origin main` — push all local commits (currently 57 ahead as of 2026-05-25)
4. Verify CI green on `origin/main` (both `integration` and `phase-12-shift-left` jobs pass)
5. Optional: archive legacy `.planning/phases/` dirs (`1`, `2`, `3`, `10-citation-backed-draft-suggestions`, `12-in-thread-quick-fix-ops-closure`) into `.planning/milestones/`

Only proceed to vM012 phase execution once CI is green on origin/main.

### Release Gate — vM012 Close

Before opening vM013 or declaring vM012 complete, run the following release gate:
1. `git push origin main` — confirm 0 commits ahead of origin
2. CI green on `origin/main` — both `integration` and `phase-12-shift-left` jobs pass
3. `CHANGELOG.md` exists and covers vM009–vM012 with dates and feature summaries
4. `v0.1.0` semver tag created and pushed (first public release tag; current milestone tags are planning markers only)
5. `mix hex.publish` dry-run succeeds (package name available, metadata complete, docs build)

If all 5 pass → proceed to first Hex.pm publish as a vM012 milestone-close artifact.
If any fail → add a release-prep phase to vM013 roadmap before execution begins.

Package status as of 2026-05-25: **unpublished** (hex.pm returns 404 for `cairnloop`).

### Pending Todos

- Centralize duplicated fail-closed search guards before more retrieval-adjacent surfaces appear.
- Root `SECURITY.md` carries 5 open threats (T-10-09..T-10-13) from vM010 — pre-existing debt.

### Blockers/Concerns

- None blocking next milestone start.
- `Cairnloop.Repo` is unavailable for the default headless suite; integration harness (`MIX_ENV=test mix test.integration`) covers DB-backed lanes against dockerized Postgres.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Verification | Repo-backed realism lanes unavailable in this workspace (default headless suite) | Partially resolved — integration harness added in Phase 15 | vM009 closeout |
| Planning | Phase 10 and Phase 12 closure artifacts still span milestone-local and legacy planning layouts | Open | vM010 closeout |
| Verification | Focused test runs still emit unrelated `Chimeway.Repo` missing-database boot noise | Open | vM010 closeout |
| Scope | Broad remote MCP server surface and high-risk write tools (MCP-02, MCP-03, ACT-02) | Deferred | vM011 planning — now candidates for next milestone |
| Tech Debt | Root SECURITY.md carries 5 pre-existing open threats (T-10-09..T-10-13) from vM010 | Open | vM011 close |
| Tech Debt | AR-14-02: governed-actions rail lacks pagination (acceptable at current volume) | Open | vM011 Phase 14 |

## Session Continuity

Last session: 2026-05-25
Stopped at: vM011 milestone closed
Next step: `/gsd:new-milestone` to define vM012
