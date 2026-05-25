---
gsd_state_version: 1.0
milestone: vM011
milestone_name: AI Tool Governance & MCP Integration
status: verifying
stopped_at: Phase 17 context gathered
last_updated: "2026-05-25T13:09:29.201Z"
last_activity: 2026-05-25
progress:
  total_phases: 5
  completed_phases: 4
  total_plans: 15
  completed_plans: 15
  percent: 80
---

# Project State

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-05-23)

**Core value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.
**Current focus:** Phase 16 — first-approved-write-path-telemetry

## Current Position

Phase: 17
Plan: Not started
Status: Phase complete — ready for verification
Last activity: 2026-05-25

Progress: [----------] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 40
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
| 15 | 5 | - | - |
| 16 | 3 | - | - |

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
| Phase 15-approval-state-machine-oban-resume P01 | 8 | 2 tasks | 10 files |
| Phase 15 P02 | 4 | 2 tasks | 5 files |
| Phase 15 P04 | 8 | 2 tasks | 5 files |
| Phase 16 P01 | 24 | 3 tasks | 14 files |

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
- [Phase 14 SECURITY — verified 2026-05-24]: `threats_open: 0`. All 15 mitigate-disposition threats independently verified in code by gsd-security-auditor (register authored at plan time, verify-mitigations mode); 2 accepted risks logged (AR-14-01 no-installs; AR-14-02 bounded rail list, re-evaluate at Phase 16). Report: `.planning/phases/14-operator-timeline-preview-surface/14-SECURITY.md`. Note: the root `SECURITY.md` is Phase 10's verification and still carries **5 open threats (T-10-09..T-10-13)** — pre-existing debt, untouched by Phase 14.
- [Phase ?]: Phase 15 W1: D15-14 DISCHARGED - propose/3 snapshots prose at propose time
- [Phase ?]: Phase 15 W1: WR-01 FIXED - traverse_errors replaces inspect(reason) at governance.ex; D15-15
- [Phase ?]: Phase 15 W1: ToolApproval schema + one-active-lane partial unique index (APRV-04)
- [Phase ?]: Phase 15 W1: get_active_approval/1 narrow facade read API on Cairnloop.Governance
- [Phase ?]: Re-validate gate + lazy expiry guard for approval resume
- [Phase ?]: Policy PDP seam extended, no enforcement
- [Phase 15 → 2026-05-25, INTEGRATION HARNESS]: Added a DB-backed integration test host under `test/support` (test-only `Cairnloop.Repo` + `Cairnloop.Web.Endpoint`/router + `DataCase`/`ConnCase`/`Fixtures`, `elixirc_paths(:test)` only) + `priv/test_host/migrations` for host-owned tables (conversations/messages/drafts) + `docker-compose.yml` (pgvector) + a CI `integration` job. 12 tests in `test/integration/` shift-left all 4 former Manual-Only/UAT items → **0 human verification**. Run: `MIX_ENV=test mix test.integration`. Fast headless `mix test` stays DB-free (`:integration` excluded; gated in `test_helper.exs`).
- [Phase 15 → 2026-05-25, DEFECTS FOUND & FIXED by integration tests (masked by MockRepo)]: (1) `cairnloop_tool_action_events.to_status` was NOT NULL but approval events insert nil → additive migration `20260524120200_relax_action_event_to_status_null`; (2) `ApprovalResumeWorker.perform/1` matched `:pending` while `approve/3` sets `:approved` → real approve→resume handoff no-op'd; fixed to match `:approved` (owner-approved). Headless worker-test fixtures updated `:pending`→`:approved`.
- [Phase 15 CARRIED DECISION — Phase 16 must honor]: approval lane lifecycle is `:pending → :approved → :execution_pending`. `ApprovalResumeWorker` acts on `:approved` only (never `:pending` — re-validation must not bypass the approval gate). **Phase 16 execution resumes from `:execution_pending`.**
- [Phase ?]: Phase 16 P01: ToolExecutionWorker — sole run/3 caller, at-most-once via Oban unique + LAYER-1/LAYER-2 guards, max_attempts 3
- [Phase ?]: Phase 16 P01: Code.ensure_loaded!/1 added to ToolRegistry.validate_configured_tools!/0 — function_exported?/3 returns false for unloaded modules (Rule 1 fix)
- [Phase 16]: [Phase 16 P02]: derive_run_key: SHA-256(idempotency_key::attempt::N) — deterministic per (proposal, attempt), fresh per retry (D16-05 layer 3)
- [Phase 16]: [Phase 16 P02]: transient {error} with attempt < max_attempts -> {:error, reason} (Oban backoff); exhausted -> {:cancel, reason} terminal (D16-07)
- [Phase 16]: [Phase 16 P02]: telemetry emitted AFTER co-commit with pipeline, never inside clause list (D-29); no actor_id/conversation_id/reason in labels (OBS-01)
- [Phase 16]: [Phase 16 P02]: Oban unique opts asserted headless via __opts__/0; live queue-count leg marked REPO-UNAVAILABLE
- [Phase ?]: [Phase 16 P03]: presenter maps :executed/:execution_failed to :done
- [Phase ?]: [Phase 16 P03]: OBS-02 attribution proven reconstructable from durable records without any Scoria/evidence adapter (D16-09)

### Pending Todos

- Centralize duplicated fail-closed search guards before more retrieval-adjacent surfaces appear.
- Unblock repo-backed realism lanes so later milestone verification can include stronger live proof.
- Replace the synchronous `execute_tool` LiveView path with a durable approval-aware action workflow.

### Blockers/Concerns

- `Cairnloop.Repo` is unavailable for the *default* (headless) suite, but DB-backed realism is now available on demand via the integration harness (`MIX_ENV=test mix test.integration` against dockerized Postgres / CI service). Prefer adding `test/integration/*` (tag `:integration`) for any future leg that needs a real Postgres + Oban-worker + LiveView round-trip.
- The current tool path has no durable approval, resume, or structured policy model; M011 is the first production-shape tool runtime milestone.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Verification | Repo-backed realism lanes unavailable in this workspace | Open | vM009 closeout |
| Planning | Phase 10 and Phase 12 closure artifacts still span milestone-local and legacy planning layouts | Open | vM010 closeout |
| Verification | Focused test runs still emit unrelated `Chimeway.Repo` missing-database boot noise in this workspace | Open | vM010 closeout |
| Scope | Broad remote MCP server surface and high-risk write tools | Deferred | vM011 planning |

## Session Continuity

Last session: 2026-05-25T13:09:29.197Z
Stopped at: Phase 17 context gathered
Resume file: .planning/phases/17-optional-evidence-lane-read-only-mcp-seam/17-CONTEXT.md
