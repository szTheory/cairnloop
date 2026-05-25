---
phase: 16-first-approved-write-path-telemetry
plan: "03"
subsystem: governance-presentation
tags: [elixir, phoenix-liveview, presenter, obs-02, tdd, integration-testing]
dependency_graph:
  requires:
    - 16-01: ToolExecutionWorker, execution terminal statuses (:executed/:execution_failed), PubSub broadcast
    - 16-02: bounded telemetry, derive_run_key, transient/terminal retry semantics
  provides:
    - execution-outcome-presenter-clauses
    - conversation-live-execution-handlers
    - obs-02-attribution-proof
    - done-group-chip-render-proof
  affects: [governance, presenter, liveview, integration-tests, validation]
tech_stack:
  added: []
  patterns:
    - "TDD RED/GREEN: failing tests committed before implementation (Pitfall 6 guard)"
    - "Dual-key JSONB lookup in presenter: atom then string key (Map.fetch + Map.get fallback)"
    - "Plain-assign reload pattern: handle_info mirrors {:draft_created, _} exactly (D16-12)"
    - "ConnCase LiveView render assertion: live/2 + html =~ for chip text + brand token presence"
    - "PubSub broadcast for both success and failure terminals (D16-11)"
key_files:
  created:
    - test/integration/tool_execution_outcome_live_test.exs
  modified:
    - lib/cairnloop/web/tool_proposal_presenter.ex
    - lib/cairnloop/web/conversation_live.ex
    - lib/cairnloop/workers/tool_execution_worker.ex
    - test/cairnloop/web/tool_proposal_presenter_test.exs
    - .planning/phases/16-first-approved-write-path-telemetry/16-VALIDATION.md
decisions:
  - "Phase 16 P03: :executed and :execution_failed both map to :done in status_group/1 (per D16-11; distinct :failed group considered but :done is correct — operator sees a completed lane)"
  - "Phase 16 P03: approval_outlook_for_approval reads result_summary/reason via dual-key (atom+string) for JSONB survival; never surfaces raw nil (falls back to 'Done.'/'An error occurred.')"
  - "Phase 16 P03: history_line reads attempt from STRING key 'attempt' (JSONB round-trip: atom keys become strings after Postgres SELECT)"
  - "Phase 16 P03: broadcast_execution_failed/2 added to ToolExecutionWorker (Rule 2 — missing critical functionality: terminal failure must also broadcast so ConversationLive reflects :execution_failed)"
  - "Phase 16 P03: integration tests use ConnCase (not DataCase) for LiveView render assertions; OBS-02 attribution tests use DataCase pattern for worker-only assertions"
metrics:
  duration_minutes: 18
  completed_date: "2026-05-25"
  tasks_completed: 3
  files_changed: 5
---

# Phase 16 Plan 03: Execution Outcome Reflection + OBS-02 Attribution Proof Summary

**One-liner:** Execution outcomes reflected into ConversationLive via existing thin-PubSub → plain-assign reload; presenter humanizes `:executed`/`:execution_failed` into Done-group chips with brand tokens (never color-alone); OBS-02 attribution (`decided_by`, `policy_snapshot`, per-attempt event trail) proven reconstructable from durable records without any adapter, and the former Manual-Only rendered-chip verification shifted left to automated rendered-HTML assertions.

## What Was Built

### Task 1: Presenter clauses for :executed / :execution_failed + execution events (TDD)

**RED phase** (`test/cairnloop/web/tool_proposal_presenter_test.exs`):
- 15 new failing tests for `status_group/1`, `approval_outlook_for_approval/1`, and `history_line/1` execution-terminal clauses
- Tests assert: JSONB string-key survival for attempt number, no raw Elixir terms (T-16-10), state named in text not color-alone

**GREEN phase** (`lib/cairnloop/web/tool_proposal_presenter.ex`):
- `status_group(:executed)` → `:done` (BEFORE catch-all — Pitfall 6 prevention)
- `status_group(:execution_failed)` → `:done` (BEFORE catch-all)
- `approval_outlook_for_approval(%{status: :executed})` → `"Action completed: #{result_summary || "Done."}"` with dual-key JSONB lookup
- `approval_outlook_for_approval(%{status: :execution_failed})` → `"Action failed: #{reason || "An error occurred."}"` with dual-key JSONB lookup
- `history_line(:execution_succeeded)` → `"Action completed (attempt N)."` (reads STRING key `"attempt"`)
- `history_line(:execution_attempt_failed)` → `"Attempt N failed: <reason>"` (reads STRING key `"attempt"`)
- `history_line(:execution_failed)` → `"Action failed permanently: <reason>"`
- No hardcoded hex; all brand token references via existing CSS class system

### Task 2: ConversationLive execution-outcome reflection

**`lib/cairnloop/web/conversation_live.ex`**:
- `handle_info({:tool_executed, _approval_id}, socket)` — mirrors `{:draft_created, _}` exactly: `{:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}`
- `handle_info({:tool_execution_failed, _approval_id}, socket)` — same plain-assign reload
- PubSub topic: `"conversation:#{id}"` (broadcast by ToolExecutionWorker after co-commit)
- No `Phoenix.LiveView.stream` introduced (D16-12); no manual retry control (D16-07)

### Task 3: DB-backed OBS-02 attribution + rendered-outcome proof

**`test/integration/tool_execution_outcome_live_test.exs`** (5 tests):
1. **OBS-02 attribution**: drives full lane → asserts `ToolApproval.decided_by == "operator_42"`, `ToolProposal.policy_snapshot != %{}`, `:approved` event `actor_id == "operator_42"`, `:execution_succeeded` event with attempt metadata present — all from durable records, no adapter needed (D16-09)
2. **Full event trail completeness**: asserts all 4 trail events present for success lane (`approval_requested`, `approved`, `revalidation_passed`, `execution_succeeded`); no failure events on happy path
3. **Rendered success chip**: LiveView render asserts `"Action completed"` text + `var(--cl-primary, #A94F30)` brand token in HTML
4. **Rendered failure chip**: forces re-validation failure (unregisters tool at execution time); asserts no `"Action completed"` in HTML; brand token present
5. **Chip text names state**: asserts both `"Action completed"` text AND brand token present together (not color-alone — brand §7.5 / T-16-12)

**`lib/cairnloop/workers/tool_execution_worker.ex`** (Rule 2 fix):
- Added `broadcast_execution_failed/2` — broadcasts `{:tool_execution_failed, approval_id}` on terminal exhausted-retry path so ConversationLive can reflect `:execution_failed` outcomes

**`.planning/phases/16-first-approved-write-path-telemetry/16-VALIDATION.md`**:
- OBS-02 rows marked ✅ green (16-03)
- Manual-Only row updated: shifted left to automated rendered-HTML assertion in `tool_execution_outcome_live_test.exs`

## Task Commits

| Task | Commit | Type |
|------|--------|------|
| Task 1 RED | bd66740 | test(16-03) |
| Task 1 GREEN | 9bef45b | feat(16-03) |
| Task 2 | fa380e4 | feat(16-03) |
| Task 3 | 81a3e2f | feat(16-03) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing] broadcast_execution_failed/2 added to ToolExecutionWorker**
- **Found during:** Task 3 — writing the LiveView test for :execution_failed, observed that the worker only broadcasts `{:tool_executed, _}` on success but never `{:tool_execution_failed, _}` on terminal failure
- **Issue:** Without the failure broadcast, ConversationLive cannot reflect `:execution_failed` via the thin-PubSub path described in PATTERNS.md and D16-11
- **Fix:** Added `broadcast_execution_failed/2` helper (mirrors `broadcast_executed/2`) and called it in the exhausted-retries branch of `handle_transient_failure/6`
- **Files modified:** `lib/cairnloop/workers/tool_execution_worker.ex`
- **Commit:** 81a3e2f

## TDD Gate Compliance

| Phase | Commit | Gate |
|-------|--------|------|
| RED (Task 1) | bd66740 | `test(16-03): add failing RED tests for execution outcome presenter clauses` |
| GREEN (Task 1) | 9bef45b | `feat(16-03): extend ToolProposalPresenter with execution outcome clauses` |

## Known Stubs

None — all OBS-02 attribution assertions are real DB-backed checks (marked `# REPO-UNAVAILABLE` where Postgres is required), and the LiveView render assertions use the real ConnCase/LiveView integration harness.

## Threat Surface Scan

No new trust boundaries beyond the plan's `<threat_model>`:
- T-16-10 (raw terms / JSON in outcome card) → mitigated: presenter returns humanized strings only; tests assert no `#Ecto.` / `%{` in output (Task 1)
- T-16-11 (who-approved / which-policy not reconstructable) → mitigated: OBS-02 test proves `decided_by`, `policy_snapshot`, `:approved` event `actor_id`, and per-attempt metadata all present in durable records after execute (Task 3)
- T-16-12 (state by color alone) → mitigated: chips carry text (`"Action completed"`) + brand token; rendered-HTML assertions verify both are present (Task 3)

## Self-Check: PASSED

Files created:
- `/Users/jon/projects/cairnloop/test/integration/tool_execution_outcome_live_test.exs` — FOUND

Files modified:
- `/Users/jon/projects/cairnloop/lib/cairnloop/web/tool_proposal_presenter.ex` — FOUND
- `/Users/jon/projects/cairnloop/lib/cairnloop/web/conversation_live.ex` — FOUND
- `/Users/jon/projects/cairnloop/lib/cairnloop/workers/tool_execution_worker.ex` — FOUND
- `/Users/jon/projects/cairnloop/test/cairnloop/web/tool_proposal_presenter_test.exs` — FOUND

Commits verified:
- bd66740 test(16-03): add failing RED tests for execution outcome presenter clauses
- 9bef45b feat(16-03): extend ToolProposalPresenter with execution outcome clauses
- fa380e4 feat(16-03): add execution-outcome handle_info handlers to ConversationLive
- 81a3e2f feat(16-03): DB-backed OBS-02 attribution proof + rendered outcome integration tests

Test results: 525 tests, 1 failure (pre-existing DraftTest baseline), 0 regressions.
`MIX_ENV=test mix compile --warnings-as-errors` exits 0.
Integration tests tagged `:integration` (require `docker-compose up -d postgres`).
