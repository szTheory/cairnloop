---
phase: 16-first-approved-write-path-telemetry
verified: 2026-05-25T09:30:00Z
status: human_needed
score: 11/11 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run mix test.integration (requires docker-compose up -d postgres) and confirm all 5 tests in test/integration/tool_execution_worker_test.exs pass: happy path, at-most-once replay, terminal-guard no-op, attempt increment, InternalNote idempotency."
    expected: "All integration tests green; exactly one cairnloop_messages row after two perform/1 calls; ToolApproval.status == :executed."
    why_human: "Integration tests require dockerized pgvector Postgres — unrunnable in this workspace (Homebrew postgresql@14 lacks vector extension). Tests exist and assert the right things (verified by reading); runtime proof requires the CI/docker environment."
  - test: "Run mix test.integration and confirm all 5 tests in test/integration/tool_execution_outcome_live_test.exs pass: OBS-02 attribution, event trail completeness, rendered success chip, rendered failure chip, chip-names-state."
    expected: "ToolApproval.decided_by == operator_42, ToolProposal.policy_snapshot != %{}, ToolActionEvent trail carries approver attribution and attempt metadata; LiveView HTML contains 'Action completed' text and 'var(--cl-primary, #A94F30)' brand token."
    why_human: "Same Postgres requirement as above. LiveView render assertions (html =~ ...) also require a running Phoenix endpoint with DB backing."
---

# Phase 16: First Approved Write Path + Telemetry — Verification Report

**Phase Goal:** "Cairnloop proves one narrow low-blast-radius write action after approval while keeping execution inspectable, grounded, and operationally bounded."
**Verified:** 2026-05-25T09:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | An approved lane at :execution_pending is executed ONLY by ToolExecutionWorker (sole run/3 caller); ApprovalResumeWorker enqueues it and never calls run/3 | VERIFIED | `grep ".run(" lib/cairnloop/workers/*.ex` returns exactly one match: `tool_execution_worker.ex:149`. ApprovalResumeWorker calls `safe_enqueue(ToolExecutionWorker.new(...))` at L89 and explicitly documents "Still NEVER calls run/3". |
| 2 | Success → :executed + result_state :succeeded + humanized result_summary; re-validation failure fails closed to :invalidated/:execution_failed writing nothing | VERIFIED | `record_success/6` (L166-231) co-commits approval `:executed` + proposal `result_state: :succeeded` + `result_summary: humanize_result(outcome)` in a transaction. `revalidate_and_execute/4` (L101-121) calls `record_terminal_failure/4` which returns `{:cancel, humanized}` without any host write. `humanize_result/1` (L421-444) and `humanize_reason/1` (L484-505) never call `inspect/1`. |
| 3 | InternalNote (use Cairnloop.Tool, risk_tier: :low_write) appends an operator-only row to host cairnloop_messages via indexed run_key existence check (never JSONB @>) | VERIFIED | `lib/cairnloop/tools/internal_note.ex` L50-53: `use Cairnloop.Tool, risk_tier: :low_write`. L97: `repo.get_by(Cairnloop.Message, run_key: run_key)` — indexed column check. Comment at L94-96 explicitly documents the JSONB anti-pattern. Role is `:internal_note` (L107). Repo indirection via `Application.fetch_env!(:cairnloop, :repo)` (L90). |
| 4 | Three-layer at-most-once: Oban unique [period: :infinity, keys: [:approval_id]] + terminal/result_state guard + deterministic per-attempt SHA-256 run key into run/3 via context | VERIFIED | Worker L38-41: `unique: [period: :infinity, fields: [:worker, :args], keys: [:approval_id]]`. L79: LAYER-2 guard `if proposal.result_state == :succeeded do :ok`. L474-477: `derive_run_key/1` = SHA-256 of `"#{idempotency_key}::attempt::#{proposal.attempt}"`. L146: placed into `run_context[:run_idempotency_key]` before `run/3`. |
| 5 | Transient-vs-terminal retry: {:error, reason} when attempt < max_attempts; {:cancel, reason} when attempt >= max_attempts; per-attempt :execution_attempt_failed event | VERIFIED | `handle_transient_failure/6` (L237-333): `if attempt >= max_attempts` at L241 routes to terminal cancel path; else transient path inserts `:execution_attempt_failed` event and returns `{:error, humanized}` for Oban retry. Both paths wrapped in `repo().transaction/1` (WR-03 fix confirmed). |
| 6 | Execution telemetry via bounded Governance.Telemetry allow-list: enum-only labels (risk_tier, approval_mode, result_state, tool_ref), NO high-cardinality keys (actor_id/conversation_id), AFTER co-commit | VERIFIED | `lib/cairnloop/governance/telemetry.ex` L65-73: `metadata/2` head for `:action_executed`/`:action_failed` emits only `%{risk_tier:, approval_mode:, result_state:, tool_ref:}`. `normalize_tool_ref/1` (L111-116) registry-validates cardinality. Telemetry emit in worker at L213-218 is inside `case tx_result do {:ok, :ok} ->` — after committed transaction, never inside the `with` clause list. Labels: `risk_tier`, `approval_mode`, `result_state`, `tool_ref` only. |
| 7 | :executed renders in Done group with success chip (brand token, never color-alone) + humanized result_summary; :execution_failed renders failure chip + humanized reason | VERIFIED | `status_group(:executed)` → `:done` at L70 of presenter (before catch-all at L72). `approval_outlook_for_approval(%{status: :executed})` (L164-167) reads `Map.get(approval, :reason)` — CR-01 fix confirmed (reads :reason where worker stores result_summary via `decision_changeset/6`). `history_line` clauses at L371-383 render humanized strings with attempt from STRING key `"attempt"`. No hardcoded hex literals in new clauses (grep returns nothing). |
| 8 | Execution outcomes reflect into ConversationLive via existing thin-PubSub → reload_conversation_with_context plain-assign path (no streams) | VERIFIED | `conversation_live.ex` L33-38: `handle_info({:tool_executed, _}, socket)` and `handle_info({:tool_execution_failed, _}, socket)` both call `reload_conversation_with_context`. No `Phoenix.LiveView.stream` in code (3 occurrences all in comments/HEEx comments). |
| 9 | who-approved (decided_by / :approved event actor_id) + which-policy (policy_snapshot) reconstructable from durable records after execute | VERIFIED | `governance.ex` L524-530: `get_latest_approval/1` returns status-agnostic approval (CR-02 fix — formerly only `:pending`). `conversation_live.ex` L957: uses `Governance.get_latest_approval(proposal.id)` for not-preloaded branch. Integration test `tool_execution_outcome_live_test.exs` L112-167 asserts `decided_by == "operator_42"`, `policy_snapshot != %{}`, and `:approved` event `actor_id` from durable records. |
| 10 | per-proposal ToolActionEvent timeline carries each attempt with actor attribution (one timeline, no duplication) | VERIFIED | Worker inserts `:execution_succeeded` event with `metadata: %{attempt: new_attempt}` (L182-190), `:execution_attempt_failed` with attempt metadata (L302-310), `:execution_failed` with attempt metadata (L248-256). Integration test at L170-200 asserts full trail presence and attempt attribution. |
| 11 | Build warnings-clean; headless suite green except known DraftTest baseline | VERIFIED | `mix compile --warnings-as-errors` exits 0. `mix test` = 526 tests, 1 failure (Cairnloop.Automation.DraftTest — pre-existing M005 drift baseline, not a Phase 16 regression). |

**Score:** 11/11 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/cairnloop/workers/tool_execution_worker.ex` | Sole run/3 caller; consumes :execution_pending; re-validates; co-commits outcome (537 lines) | VERIFIED | Exists, substantive (537 lines), wired — called by ApprovalResumeWorker enqueue + Governance.execute_approved/2. |
| `lib/cairnloop/tools/internal_note.ex` | use Cairnloop.Tool, risk_tier: :low_write; run/3 writes to cairnloop_messages | VERIFIED | Exists (119 lines), contains `use Cairnloop.Tool`, `risk_tier: :low_write`, `repo.get_by(Message, run_key:)` idempotency check. Registered in config.exs. |
| `lib/cairnloop/governance/tool_approval.ex` | @status_values includes :executed and :execution_failed | VERIFIED | L43-47: both `:executed` and `:execution_failed` present before list closes. |
| `lib/cairnloop/governance/tool_action_event.ex` | @event_type_values includes :execution_succeeded, :execution_attempt_failed, :execution_failed | VERIFIED | L41-45: all three Phase 16 execution events present. `timestamps(updated_at: false)` at L60 unchanged. |
| `lib/cairnloop/governance.ex` | execute_approved/2 facade + get_latest_approval/1 (CR-02 fix) | VERIFIED | `execute_approved/2` at L829, `get_latest_approval/1` at L524. `get_active_approval/1` kept for footer affordance. |
| `lib/cairnloop/governance/telemetry.ex` | @events includes :action_executed/:action_failed; @allowed_result_states; normalize_result_state/1; normalize_tool_ref/1 | VERIFIED | L26-28: both events in `@events`. L41: `@allowed_result_states`. L106-116: both normalize functions. |
| `lib/cairnloop/web/tool_proposal_presenter.ex` | status_group, approval_outlook_for_approval, history_line clauses for :executed/:execution_failed + events | VERIFIED | L70-71: status_group clauses before catch-all. L164-173: approval_outlook_for_approval clauses reading :reason (CR-01 fix). L371-383: history_line execution event clauses. |
| `lib/cairnloop/web/conversation_live.ex` | handle_info/2 reload handlers for :tool_executed and :tool_execution_failed | VERIFIED | L33-38: both handlers call `reload_conversation_with_context`. `get_latest_approval/1` used at L957 (CR-02 fix). |
| `test/cairnloop/governance/telemetry_test.exs` | Headless proof: bounded labels, no high-cardinality leakage, normalize_tool_ref → :unknown | VERIFIED | Exists (270 lines). Tests: bounded keys, refute actor_id/conversation_id/account_id/reason/content, normalize_tool_ref with empty registry → :unknown, registered ref passes through. |
| `test/cairnloop/web/tool_proposal_presenter_test.exs` | Execution outcome clauses: status_group, approval_outlook, history_line for :executed/:execution_failed | VERIFIED | Tests at L606-746 cover all new presenter clauses including CR-01 fix (L646: ":executed outlook reads from :reason field"). |
| `test/cairnloop/workers/tool_execution_worker_test.exs` | Headless worker branch: nil approval no-op, wrong status no-op, re-validation fail, transient retry, exhausted cancel | VERIFIED | Exists with MockRepo fixture map covering all documented test cases. |
| `test/integration/tool_execution_worker_test.exs` | DB-backed proof: happy path, at-most-once, terminal guard, attempt increment, InternalNote idempotency | VERIFIED (structure) | Exists (16 REPO-UNAVAILABLE markers). Asserts `Repo.aggregate(Message, :count) == 1`, approval `:executed`, attempt increment, InternalNote idempotency. Runtime requires Postgres. |
| `test/integration/tool_execution_outcome_live_test.exs` | DB-backed OBS-02 attribution + rendered chip proof | VERIFIED (structure) | Exists (5 tests). Asserts `decided_by`, `policy_snapshot != %{}`, event trail attribution, "Action completed" HTML text, `var(--cl-primary, #A94F30)` brand token. Runtime requires Postgres. |
| `priv/test_host/migrations/20260525000001_add_run_key_to_messages.exs` | run_key column + partial unique index WHERE run_key IS NOT NULL | VERIFIED | Correct `alter table` + `unique_index where: "run_key IS NOT NULL"`. |
| `priv/repo/migrations/20260525000000_add_execution_outcome_index.exs` | Filtered index on execution terminal statuses | VERIFIED | Creates index on `[:status, :decided_at]` where `status IN ('executed', 'execution_failed')`. No spurious ALTER TABLE. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `approval_resume_worker.ex` | `tool_execution_worker.ex` | `safe_enqueue(ToolExecutionWorker.new(...))` at :execution_pending success branch | WIRED | L89 in ApprovalResumeWorker: `safe_enqueue(ToolExecutionWorker.new(%{"approval_id" => approval.id}))`. |
| `tool_execution_worker.ex` | `InternalNote` (tool module) | `tool_module.run(tool_struct, ...)` after re-validate | WIRED | L149: `result = tool_module.run(tool_struct, proposal.actor_id, run_context)`. Module resolved via `ToolRegistry.find_tool_module/1` at L126. |
| `tool_execution_worker.ex` | `governance/telemetry.ex` | `GovTelemetry.emit(:action_executed/:action_failed, ...)` AFTER co-commit with | WIRED | L213-218 (`action_executed`) and L280-285 (`action_failed`) — both inside `case tx_result do {:ok, :ok} ->`, confirming post-commit positioning. |
| `internal_note.ex` | `cairnloop_messages` | `Application.fetch_env!(:cairnloop, :repo)` + `repo.get_by(Message, run_key:)` + `repo.insert(Message.changeset(...))` | WIRED | L90, L97, L112 — no direct `Cairnloop.Repo` reference. |
| `conversation_live.ex` | `tool_proposal_presenter.ex` | `status_group/1` used via presenter for display grouping | WIRED | ConversationLive imports `ToolProposalPresenter` (L11 alias). Presenter `status_group(:executed)` → `:done` confirmed before catch-all. |
| `governance.ex` | `conversation_live.ex` (CR-02) | `get_latest_approval/1` for not-preloaded terminal approval resolution | WIRED | `governance.ex` L524-530 exports `get_latest_approval/1`. `conversation_live.ex` L957 calls it. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `tool_proposal_presenter.ex` approval_outlook_for_approval(:executed) | `approval.reason` | Worker `decision_changeset(approval, :executed, "executed", result_summary, ...)` stores humanized summary in `:reason` column | Yes — reads from durable ToolApproval.reason field populated by worker co-commit | FLOWING (CR-01 fix confirmed) |
| `conversation_live.ex` execution outcome reload | `socket.assigns.conversation` via `reload_conversation_with_context` | `list_proposals_for_conversation` preloads proposals + approvals from DB | Yes — DB query | FLOWING |
| `tool_execution_worker.ex` → `run/3` context | `context[:run_idempotency_key]` | `derive_run_key(proposal)` = SHA-256(idempotency_key::attempt::N) | Yes — deterministic, derived from durable proposal fields | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| run/3 only called in ToolExecutionWorker | `grep ".run(" lib/cairnloop/workers/*.ex` | Exactly 1 match: tool_execution_worker.ex:149 | PASS |
| ApprovalResumeWorker never calls run/3 | `grep "\.run(" lib/cairnloop/workers/approval_resume_worker.ex` | 0 matches | PASS |
| No Phoenix.LiveView.stream in ConversationLive code | `grep -n "stream" conversation_live.ex` — 3 results all in comments | Comments only | PASS |
| No hardcoded hex in new presenter clauses | `grep "#[0-9A-Fa-f]{6}" tool_proposal_presenter.ex` | 0 matches outside comments | PASS |
| Build clean | `MIX_ENV=test mix compile --warnings-as-errors; echo EXIT:$?` | EXIT:0 | PASS |
| Headless suite | `MIX_ENV=test mix test` | 526 tests, 1 failure (pre-existing DraftTest baseline) | PASS |
| No debt markers in phase lib files | `grep -rn "TBD\|FIXME\|XXX" lib/...` | 0 matches | PASS |

### Probe Execution

Not applicable — no `scripts/*/tests/probe-*.sh` probe files declared for this phase. Behavioral spot-checks above serve as the automated verification layer.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| ACT-01 | 16-01, 16-02 | System ships at least one narrow low-blast-radius write workflow after approval | SATISFIED | ToolExecutionWorker (sole run/3 caller) + InternalNote governed-write tool proven end-to-end. Worker executes only :execution_pending lanes, re-validates, co-commits outcome. |
| OBS-01 | 16-02 | Bounded telemetry for governed action execution without leaking high-cardinality payload | SATISFIED | Governance.Telemetry @events includes :action_executed/:action_failed; metadata/2 head emits only {risk_tier, approval_mode, result_state, tool_ref}; normalize_tool_ref/1 registry-bounds the string label; headless tests assert no actor_id/conversation_id/reason in emitted metadata. |
| OBS-02 | 16-03 | Optional audit/evidence integrations can attribute who approved and which policy snapshot applied | SATISFIED | get_latest_approval/1 (status-agnostic, CR-02 fix) returns terminal-lane approval for display. ToolApproval.decided_by + ToolProposal.policy_snapshot + ToolActionEvent trail (approver actor_id + per-attempt metadata) reconstructable from durable records. Integration test asserts all three. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| No blocker debt markers (TBD/FIXME/XXX) in any phase lib files | — | — | — | Clean |

### Human Verification Required

#### 1. Integration Test Suite: ACT-01 at-most-once + retry proof

**Test:** `docker-compose up -d postgres && MIX_ENV=test mix test.integration test/integration/tool_execution_worker_test.exs`
**Expected:** All tests green. Key assertions: `Repo.aggregate(Message, :count) == 1` after two identical `perform/1` calls; approval stays `:executed` on replayed `perform/1`; `proposal.attempt == 2` and `:execution_attempt_failed` event after transient failure; two `InternalNote.run/3` calls with the same run-key produce one row and second returns `{:ok, %{idempotent: true}}`.
**Why human:** Requires dockerized pgvector Postgres. This workspace uses Homebrew postgresql@14 without the `vector` extension, making the integration DB unavailable. Tests exist and assert the correct behavior (verified by file reading); only the runtime execution requires the CI/docker environment.

#### 2. Integration Test Suite: OBS-02 attribution + rendered chip proof

**Test:** `docker-compose up -d postgres && MIX_ENV=test mix test.integration test/integration/tool_execution_outcome_live_test.exs`
**Expected:** All 5 tests green. Key assertions: `ToolApproval.decided_by == "operator_42"`, `ToolProposal.policy_snapshot != %{}`, `:approved` event `actor_id == "operator_42"`, `:execution_succeeded` event with attempt metadata; LiveView HTML contains `"Action completed"` text and `"var(--cl-primary, #A94F30)"` brand token for `:executed` lane; failure lane shows no `"Action completed"`.
**Why human:** Same Postgres requirement. Also requires Phoenix endpoint for LiveView render assertions (`live/2` in ConnCase).

### Gaps Summary

No gaps — all 11 observable truths are VERIFIED in the live codebase. Code review BLOCKERs (CR-01 presenter reading wrong field, CR-02 get_active_approval filtered to :pending only) and warnings (WR-02 expiry guard, WR-03/04 co-commit transactionality, WR-05 humanize_result safety, IN-02 nil conversation_id broadcast guard) are all confirmed fixed in the live code. The two human verification items are environmental constraints (unrunnable integration DB), not code defects.

---

_Verified: 2026-05-25T09:30:00Z_
_Verifier: Claude (gsd-verifier)_
