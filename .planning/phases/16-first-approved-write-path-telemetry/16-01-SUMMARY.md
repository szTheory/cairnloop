---
phase: 16-first-approved-write-path-telemetry
plan: "01"
subsystem: governance-execution
tags: [execution-worker, governed-tools, oban, idempotency, telemetry, tdd]
dependency_graph:
  requires: [15-approval-state-machine-oban-resume]
  provides: [tool-execution-worker, internal-note-tool, execution-outcome-schema, facade-execute-api]
  affects: [governance, tool-registry, workers, message-schema]
tech_stack:
  added: [Cairnloop.Workers.ToolExecutionWorker, Cairnloop.Tools.InternalNote]
  patterns: [oban-worker-at-most-once, sequential-with-co-commit, run-level-idempotency, tdd-red-green]
key_files:
  created:
    - lib/cairnloop/workers/tool_execution_worker.ex
    - lib/cairnloop/tools/internal_note.ex
    - priv/repo/migrations/20260525000000_add_execution_outcome_index.exs
    - priv/test_host/migrations/20260525000001_add_run_key_to_messages.exs
    - test/integration/tool_execution_worker_test.exs
    - test/cairnloop/workers/tool_execution_worker_test.exs
  modified:
    - lib/cairnloop/governance/tool_approval.ex
    - lib/cairnloop/governance/tool_action_event.ex
    - lib/cairnloop/governance/telemetry.ex
    - lib/cairnloop/governance.ex
    - lib/cairnloop/workers/approval_resume_worker.ex
    - lib/cairnloop/message.ex
    - lib/cairnloop/tool_registry.ex
    - config/config.exs
    - test/support/fixtures.ex
decisions:
  - "ToolExecutionWorker uses :default queue (zero host config change, consistent with other workers)"
  - "max_attempts: 3 (fail-closed bounded default; transient -> {:error}, permanent -> {:cancel})"
  - "safe_enqueue/1 removed from ToolExecutionWorker (unused — worker consumes, doesn't enqueue)"
  - "run_idempotency_key = proposal.idempotency_key for Plan 01 (per-attempt derivation hardened in plan 02)"
  - "Code.ensure_loaded!/1 added to ToolRegistry.validate_configured_tools!/0 (Rule 1 fix: function_exported?/3 returns false for unloaded modules)"
  - "Message.changeset: conversation_id removed from validate_required (InternalNote appends without requiring conv context at changeset level; DB FK is nullable)"
metrics:
  duration_minutes: 24
  completed_date: "2026-05-25"
  tasks_completed: 3
  files_changed: 14
---

# Phase 16 Plan 01: First Approved Write Path — Execution Worker & Example Tool Summary

**One-liner:** `ToolExecutionWorker` (sole `run/3` caller) + `InternalNote` governed-write tool + execution outcome schema extensions + facade `execute_approved/2` + additive resume worker enqueue, all warnings-clean with TDD RED/GREEN gate compliance.

## What Was Built

### Task 1: Wave 0 Test Scaffold + run_key Migration + Fixtures

**Wave 0 integration test scaffold** (`test/integration/tool_execution_worker_test.exs`):
- Mirrors `approval_flow_test.exs` exactly: `use Cairnloop.DataCase, async: false`, inline `NoteWriteTool` via `use Cairnloop.Tool`, injectable `enqueue_fn` capture idiom, direct `ToolExecutionWorker.perform/1` invocation
- Happy-path test drives proposal+approval fixture through `:execution_pending` then asserts exactly one `cairnloop_messages` row AND `approval.status == :executed`
- Idempotency replay test: second `perform/1` call is a no-op — still 1 message row
- Terminal guard tests: non-`:execution_pending` and deleted approvals are silent `:ok` no-ops
- TODO stubs mark remaining VALIDATION.md rows for plans 02/03

**Test-host migration** (`priv/test_host/migrations/20260525000001_add_run_key_to_messages.exs`):
- Adds `run_key :string` to `cairnloop_messages`
- Partial unique index `WHERE run_key IS NOT NULL` — O(1) idempotency existence check

**Message schema / fixtures**:
- Added `:run_key` field + `:internal_note` to role enum in `Cairnloop.Message`; cast `:run_key` in `changeset/2`; relaxed `conversation_id` from `validate_required` (nullable FK)
- Added `message_fixture/1` to `Cairnloop.Fixtures` (defaults: `role: :internal_note`, `run_key: nil`)

### Task 2: Contract Extensions + InternalNote Example Tool

**ToolApproval** — extended `@status_values` with `:executed` (success terminal) and `:execution_failed` (failure terminal); `decision_changeset/6` accepts both without requiring a reason (only `:rejected`/`:deferred` require reason, FLOW-03 unchanged)

**ToolActionEvent** — extended `@event_type_values` with four Phase 16 execution events:
- `:execution_started` — optional pre-`run/3` latency marker
- `:execution_succeeded` — `run/3` returned `{:ok, result}`, co-committed with `:executed`
- `:execution_attempt_failed` — transient failure; Oban retries
- `:execution_failed` — terminal failure; no further retry
All with `from_status`/`to_status` nil (Pitfall 7: typed against ToolProposal, NOT ToolApproval)

**`Cairnloop.Tools.InternalNote`** — reference governed-write tool:
- `use Cairnloop.Tool, risk_tier: :low_write` → derives `approval_mode: :requires_approval`
- `embedded_schema`: `conversation_id`, `content`
- `run/3`: indexed `run_key` existence check (`repo.get_by(Message, run_key: key)` — never JSONB `@>` containment); inserts `role: :internal_note` row with `run_key`/`metadata`; returns `{:ok, %{idempotent: true}}` on replay
- Registered in `config/config.exs` under `:cairnloop, :tools`

**Migration** (`priv/repo/migrations/20260525000000_add_execution_outcome_index.exs`):
- No DDL for status column (`:string` storage); only adds a filtered index on `:executed`/`:execution_failed` for outcome queries

### Task 3: ToolExecutionWorker + Facade Execute API + Additive Resume Enqueue

**`Cairnloop.Workers.ToolExecutionWorker`** — the ONLY place `run/3` is ever called:
- `use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: :infinity, keys: [:approval_id]]`
- LAYER-1: non-`:execution_pending` status → `:ok` no-op
- LAYER-2: `proposal.result_state == :succeeded` → `:ok` no-op (TOCTOU guard, T-16-01)
- Re-validates via `Governance.validate/3` before `run/3`; fail-closed on failure (T-16-02)
- Success: sequential `with` co-commit (approval `:executed` + proposal `result_state: :succeeded` + `:execution_succeeded` event + PubSub `{:tool_executed, id}` after commit)
- Transient `{:error}` with `attempt < max_attempts` → `{:error, reason}` for Oban retry + `:execution_attempt_failed` event
- Exhausted retries (`attempt >= max_attempts`) → `{:cancel, reason}` + `:execution_failed` + approval `:execution_failed`
- `humanize_reason/1` (never `inspect/1` on operator-visible text); `humanize_result/1` for `result_summary`

**`Cairnloop.Governance.execute_approved/2`** — injectable facade API:
- Mirrors `approve/3` record-before-enqueue ordering
- `enqueue_fn` opt defaults to `&safe_enqueue/1` for testability
- Returns `{:ok, approval}` on success; `{:error, :not_found | :not_execution_pending}` guards

**`ApprovalResumeWorker` additive change** (D16-04):
- One-line addition at the `:execution_pending` success branch: `safe_enqueue(ToolExecutionWorker.new(...))`
- Added `defp safe_enqueue/1` (mirrors `Governance.safe_enqueue/1` — with comment)
- Still NEVER calls `run/3` — sealed contract holds; existing tests pass

**`Governance.Telemetry` extensions** (D16-10):
- Added `:action_executed` and `:action_failed` to `@events`
- New `metadata/2` head for execution events: bounded `risk_tier`, `approval_mode`, `result_state`, `tool_ref` labels
- `normalize_result_state/1` and `normalize_tool_ref/1` (registry-validated cardinality bound)
- NEVER puts `actor_id`, `conversation_id`, `account_id`, or reason strings in labels

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed ToolRegistry.validate_configured_tools!/0 not loading modules**
- **Found during:** Task 2 verification (app start failed with ArgumentError)
- **Issue:** `function_exported?/3` returns `false` for unloaded modules even when the beam file exists. The existing code worked accidentally when no tools were configured globally, but failed as soon as `InternalNote` was added to `config/config.exs`.
- **Fix:** Added `Code.ensure_loaded!(tool_module)` before `function_exported?/3` in `validate_configured_tools!/0`
- **Files modified:** `lib/cairnloop/tool_registry.ex`
- **Commit:** dfda35e

**2. [Rule 2 - Missing] Message.changeset: conversation_id not required at schema level**
- **Found during:** Task 1 design — InternalNote writes notes via `run/3` but some contexts may not have a conversation ID available in the changeset flow
- **Decision:** Removed `conversation_id` from `validate_required` in `Message.changeset/2`. The DB FK is nullable (no `null: false`). InternalNote's own `changeset/2` validates `conversation_id` at proposal time; the write goes through `Message.changeset` which now only requires `content` and `role`.
- **Impact:** Does not regress any tests (DraftTest failure is pre-existing M005 drift, unrelated to Message)
- **Files modified:** `lib/cairnloop/message.ex`
- **Commit:** 28f2f1c

## TDD Gate Compliance

Both Task 2 and Task 3 were implemented with TDD (RED/GREEN pattern).

| Phase | Commit | Gate |
|-------|--------|------|
| RED (Task 2) | 249ec9e | `test(16-01): add failing RED tests for Phase 16 contract extensions` |
| GREEN (Task 2) | dfda35e | `feat(16-01): contract extensions + InternalNote example tool` |
| RED (Task 3) | 9119525 | `test(16-01): add failing RED tests for ToolExecutionWorker + facade` |
| GREEN (Task 3) | 3e6dde9 | `feat(16-01): ToolExecutionWorker + facade execute API + additive resume enqueue` |

## Known Stubs

- **`test/integration/tool_execution_worker_test.exs` TODO blocks:** Remaining VALIDATION.md rows (T-16-02 re-validation at execution, at-most-once under replay, per-attempt events, OBS-02 telemetry label bounds) are stubbed as TODO comments referencing specific VALIDATION.md rows. These are extended by plans 02/03 — they do not prevent the plan's ACT-01 goal.
- **`run_idempotency_key = proposal.idempotency_key`:** Plan 01 passes the proposal's own idempotency key as the run-level key. Plan 02 hardens this to a per-attempt derived key. The current approach is functional (the tool's existence check works) but not yet at the full per-attempt dedup granularity.

## Threat Surface Scan

No new trust boundaries beyond what the plan's `<threat_model>` covers:
- T-16-01 (Oban replay) → mitigated by LAYER-1 + LAYER-2 guards (implemented)
- T-16-02 (stale approval executes) → mitigated by re-validate before `run/3` (implemented)
- T-16-03 (wrong conversation) → mitigated by `input_snapshot` context (implemented)
- T-16-04 (raw error terms) → mitigated by `humanize_reason/1` (implemented, never `inspect/1`)
- T-16-05 (note content disclosure) → accepted; `role: :internal_note`, operator-only (AR-16-01)

## Self-Check: PASSED

Files created:
- `/Users/jon/projects/cairnloop/lib/cairnloop/workers/tool_execution_worker.ex` — FOUND
- `/Users/jon/projects/cairnloop/lib/cairnloop/tools/internal_note.ex` — FOUND
- `/Users/jon/projects/cairnloop/priv/repo/migrations/20260525000000_add_execution_outcome_index.exs` — FOUND
- `/Users/jon/projects/cairnloop/priv/test_host/migrations/20260525000001_add_run_key_to_messages.exs` — FOUND
- `/Users/jon/projects/cairnloop/test/integration/tool_execution_worker_test.exs` — FOUND
- `/Users/jon/projects/cairnloop/test/cairnloop/workers/tool_execution_worker_test.exs` — FOUND

Commits verified:
- 28f2f1c feat(16-01): Wave 0 test scaffold + run_key migration + message fixture
- 249ec9e test(16-01): add failing RED tests for Phase 16 contract extensions
- dfda35e feat(16-01): contract extensions + InternalNote example tool
- 9119525 test(16-01): add failing RED tests for ToolExecutionWorker + facade
- 3e6dde9 feat(16-01): ToolExecutionWorker + facade execute API + additive resume enqueue

Test results: 496 tests, 1 failure (pre-existing DraftTest baseline), 0 regressions.
`MIX_ENV=test mix compile --warnings-as-errors` exits 0.
