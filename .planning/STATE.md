---
gsd_state_version: 1.0
milestone: vM011
milestone_name: AI Tool Governance & MCP Integration
status: executing
stopped_at: Phase 14 complete (verified PASS 8/8)
last_updated: "2026-05-24T13:00:23.673Z"
last_activity: 2026-05-24
progress:
  total_phases: 5
  completed_phases: 2
  total_plans: 7
  completed_plans: 7
  percent: 40
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-05-23)

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** Phase 15 — approval-state-machine-&-oban-resume

## Current Position

Phase: 15
Plan: Not started
Status: Phase 14 verified (PASS 8/8) — Phase 15 not started
Last activity: 2026-05-24 -- Phase 14 executed, reviewed, fixed, and verified

Progress: [----------] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 32
- Average duration: -
- Total execution time: -

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 9. Gap Candidate Discovery | 3 | - | - |
| 11. Review-Gated KB Updates | 4 | 7 min | 7 min |
| 12 | 4 | - | - |
| 13 | 3 | - | - |
| 14 | 4 | - | - |

**Recent Trend:**

- Last 5 plans: M010-S01-03, M010-S03-01, M010-S03-02, M010-S03-03, M010-S03-04
- Trend: Increasing

| Phase 11 P04 | 9 min | 2 tasks | 6 files |
| Phase 10 P01 | 8min | 2 tasks | 2 files |
| Phase 10 P02 | 2min | 2 tasks | 1 files |
| Phase 10 P03 | 6min | 2 tasks | 3 files |
| Phase 10 P04 | 2min | 2 tasks | 1 files |
| Phase 13-governed-tool-contract-proposal-records P01 | 4 | 3 tasks | 5 files |
| Phase 14 P01 | 8 | 2 tasks | 9 files |
| Phase 14 P02 | 3 | 1 tasks | 2 files |

## Accumulated Context

### Decisions

- vM010 stays inside Cairnloop-owned Phoenix, Ecto, and Oban paths; Scoria remains optional.
- Sequence the milestone as `Governed contract -> timeline -> approvals -> narrow write path -> optional MCP seam`.
- Preserve the canonical publish boundary: AI can prepare KB work, never publish it directly.
- Governed action truth should live in durable records and events, not telemetry or LiveView process state.
- MCP is an adapter seam over governed tools, not the primary internal execution model.
- [Phase ?]: Cairnloop.Tool evolved in place (D-01..D-06): can_execute?/2 removed, execute/3->run/3, scope/0+authorize/2+preview/1 added
- [Phase ?]: Cairnloop.Tool.Spec plain defstruct @enforce_keys [:risk_tier, :approval_mode] — pure data, MCP-01 Phase 17 projection point (D-03)
- [Phase ?]: derive_approval_mode/1 fail-closed: unknown/nil tier -> :always_block; CompileError before quote do for invalid enums (D-11, D-02)
- [Phase ?]: authorize/2 deny-by-default {:error, :no_policy_defined}; ToolRegistry uses Atom.to_string, not String.to_existing_atom (D-16, D-19)
- [Phase 14]: D-15 RATIFIED Hybrid — preview trust fields render from propose-time snapshot; interpretive prose (consequence via `preview/1`, title via live `Spec`) is best-effort LIVE behind a total `Preview.render/1` fallback, labelled "current description". Phase 13 `propose/3` is NOT reopened; no prose migration in Phase 14. (3-agent deep research, unanimous; see 14-CONTEXT.md ratification note.)
- [Phase 15 GUARDRAIL — carry forward]: when prose first becomes load-bearing (approval), Phase 15 MUST add nullable `rendered_consequence` + `title` columns to `cairnloop_tool_proposals`, populate in `propose/3` going forward, and have the approval/execution surfaces read the snapshotted columns — NEVER call live `Preview.render`. Add a test asserting snapshotted-vs-live divergence. (D-16 additive promotion.)
- [Phase 14 → carry forward, WR-01]: the `:needs_input` blocked path persists `inspect(changeset)` (a raw `#Ecto.Changeset<...>`) into the durable `policy_snapshot` column + `ToolActionEvent.reason` via the SEALED Phase-13 `insert_blocked_proposal/10` chain (`governance.ex:313`). NOT churned in Phase 14 (seal-completed-phases). When Phase 15 reopens propose/approval persistence, decide whether `:needs_input` should persist at all; if it must, humanize via `Ecto.Changeset.traverse_errors` (NOT `inspect/1`) and add a test asserting `policy_snapshot` contains no `#Ecto.Changeset<` substring. (Code review 14-REVIEW.md WR-01/IN-01.)

### Pending Todos

- Centralize duplicated fail-closed search guards before more retrieval-adjacent surfaces appear.
- Unblock repo-backed realism lanes so later milestone verification can include stronger live proof.
- Replace the synchronous `execute_tool` LiveView path with a durable approval-aware action workflow.

### Blockers/Concerns

- `Cairnloop.Repo` remains unavailable in this workspace, so some DB-backed realism proof may stay environment-blocked.
- The current tool path has no durable approval, resume, or structured policy model; M011 is the first production-shape tool runtime milestone.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Verification | Repo-backed realism lanes unavailable in this workspace | Open | vM009 closeout |
| Planning | Phase 10 and Phase 12 closure artifacts still span milestone-local and legacy planning layouts | Open | vM010 closeout |
| Verification | Focused test runs still emit unrelated `Chimeway.Repo` missing-database boot noise in this workspace | Open | vM010 closeout |
| Scope | Broad remote MCP server surface and high-risk write tools | Deferred | vM011 planning |

## Session Continuity

Last session: 2026-05-24T12:28:22.638Z
Stopped at: Phase 14 context gathered
Resume file: None
