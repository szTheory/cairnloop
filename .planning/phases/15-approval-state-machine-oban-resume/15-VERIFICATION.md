---
phase: 15-approval-state-machine-oban-resume
verified: 2026-05-24T19:32:00Z
status: human_needed
score: 10/10 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Visually inspect the footer slot in a running app: navigate to a conversation with a :requires_approval governed action proposal and verify the Approve/Reject/Defer affordances render with status chip showing both color AND text label, not color alone."
    expected: "Approve button (brand token color), Reject and Defer buttons with reason textarea; status chip labels are visible as text strings alongside color. Per brand §7.5."
    why_human: "Color+text pairing is a visual/accessibility property; grep cannot verify that color and text both render to the operator's viewport."
  - test: "Visually confirm that an approval card displays the snapshotted title and rendered_consequence (not fresh Preview.render prose) when the tool's consequence would differ from the propose-time snapshot."
    expected: "Card shows the prose that was captured at propose-time, not a freshly rendered value. A proposal created before Phase 15 (NULL snapshot) shows the structured-summary card fallback."
    why_human: "D15-14 trust-drift guard: snapshot correctness requires a live environment where propose-time and current-time prose can diverge."
  - test: "Exercise the approval flow end-to-end in a running environment: call request_approval, then approve, wait for the Oban job to execute, and confirm the approval status transitions to :execution_pending with a :revalidation_passed ToolActionEvent in the timeline."
    expected: "Status is :execution_pending; two events exist in the timeline (approval_requested, approved, then revalidation_passed from the async worker); NO run/3 was called synchronously."
    why_human: "Requires a live Oban queue; the worker's async re-validation path cannot be exercised headlessly."
  - test: "Attempt to reject or defer an action without supplying a reason from the UI footer (leave the reason textarea blank) and confirm the UI surfaces a calm error message without persisting any record."
    expected: "The handler returns {:error, changeset} from the facade, which renders 'A reason is required.' flash. No new ToolApproval or ToolActionEvent rows are written."
    why_human: "Form submission behavior with blank fields requires browser interaction; the server-side guard is code-verified but the UX path needs a live session."
---

# Phase 15: Approval State Machine & Oban Resume — Verification Report

**Phase Goal:** Risky governed actions move through durable approval, rejection, deferral, expiry,
and resume paths with append-only decision history.
**Verified:** 2026-05-24T19:32:00Z
**Status:** human_needed (all automated checks pass; 4 items require live environment)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ToolApproval schema with decision_changeset requiring reason for reject/defer (FLOW-03) | VERIFIED | `lib/cairnloop/governance/tool_approval.ex` exists, 117 lines; `validate_reason_present/2` enforces reason for `:rejected`/`:deferred`, not `:approved`; `unique_constraint` on `:tool_proposal_id` with `name: :cairnloop_tool_approvals_one_active_lane_index` |
| 2 | Migration creates cairnloop_tool_approvals with partial unique index WHERE status = 'pending' (APRV-04) | VERIFIED | `priv/repo/migrations/20260524120000_add_tool_approvals.exs` contains `where: "status = 'pending'"` and `name: :cairnloop_tool_approvals_one_active_lane_index` |
| 3 | ToolProposal gains rendered_consequence + title columns and has_one(:approval); propose/3 snapshots prose at propose time (D15-14) | VERIFIED | `tool_proposal.ex`: `field(:rendered_consequence, :string)`, `field(:title, :string)`, `has_one(:approval, ...)` confirmed; `governance.ex` L292-322 calls `Preview.render/1` inside `insert_new_proposal/6` before repo insert |
| 4 | ToolActionEvent accepts 9 new approval event types with from_status/to_status nil (D15-03) | VERIFIED | `tool_action_event.ex` L28-36 lists all 9: `:approval_requested`, `:approved`, `:rejected`, `:deferred`, `:expired`, `:invalidated`, `:resume_scheduled`, `:revalidation_passed`, `:revalidation_failed`; updated_at: false preserved |
| 5 | inspect(reason) removed; blocked-proposal reasons humanized via traverse_errors (D15-15/WR-01) | VERIFIED | `grep -c "inspect(reason)"` returns 0; `traverse_errors` present at `governance.ex:410`; the only `inspect()` call is on an exception struct in `safe_enqueue` rescue log (sanctioned) |
| 6 | get_active_approval/1 on the narrow Governance facade | VERIFIED | `governance.ex` L505: `def get_active_approval(tool_proposal_id)` using `repo().get_by(ToolApproval, ... status: :pending)` |
| 7 | ApprovalResumeWorker re-validates via pure Governance.validate/3; transitions to :execution_pending on pass (never run/3); :invalidated fail-closed on fail; lazy expires_at guard fires before re-validate (APRV-02/03, D15-12) | VERIFIED | `approval_resume_worker.ex`: `Cairnloop.Governance.validate/3` called at L73; `:execution_pending` transition on pass; `:invalidated` on fail with `humanize_reason/1`; lazy guard at L49 using `DateTime.before?`; no `.run(` calls; `unique: [keys: [:approval_id]]` for double-enqueue safety |
| 8 | ApprovalExpiryWorker flips :pending → :expired; idempotent no-op otherwise (APRV-03) | VERIFIED | `approval_expiry_worker.ex`: pattern matches `%ToolApproval{status: :pending}` → expire; nil and `_` → `:ok`; sequential `with` co-commit with `:expired` ToolActionEvent |
| 9 | approve/reject/defer/expire transitions guarded on :pending; approve persists+enqueues ApprovalResumeWorker via injectable enqueue_fn (never inline run/3); reject/defer require reason (FLOW-03); request_approval fail-closed on non-:requires_approval proposals (CR-01 fix); append-only trail (APRV-01/04) | VERIFIED | `governance.ex`: `def request_approval(%{approval_mode: mode}, _opts) when mode != :requires_approval` returns `{:error, :not_requires_approval}` (CR-01 confirmed); `approve/3` L611 guards `%ToolApproval{status: :pending}`, returns `{:error, :not_pending}` otherwise; `ApprovalResumeWorker.new/1` enqueued AFTER update (record-before-enqueue); `decision_changeset` used for reject/defer (FLOW-03); no `.run(`, no `Ecto.Multi` |
| 10 | Presenter maps approval states into existing four groups (zero relabeling, CR-02 fix); approval_outlook_for_approval covers all statuses; history_line humanizes all 9 event types; conversation_live handles approve/reject/defer via facade, reads snapshotted prose, no streams (D15-16/14/17) | VERIFIED | `tool_proposal_presenter.ex`: `:pending` → `:awaiting`, `:approved`/`:execution_pending` → `:active`, `:rejected`/`:deferred`/`:expired`/`:invalidated` → `:done` (CR-02 confirmed, no phantom `:pending_approval`); `approval_outlook_for_approval/1` covers all 7 statuses; all 9 `history_line` clauses present above catch-all; `conversation_live.ex`: 3 `handle_event` handlers call `Cairnloop.Governance.approve/reject/defer`; `rendered_consequence` read from snapshot; `Preview.render` count = 0; `LiveView.stream` count = 0; `var(--cl-primary, #A94F30)` in footer |

**Score:** 10/10 truths verified

---

### Code Review Blocker Resolution

| Blocker | Fix | Evidence in Code |
|---------|-----|-----------------|
| CR-01: request_approval/2 opened lanes for :auto/:always_block (fail-open governance defect) | RESOLVED (commit 5489017) | `governance.ex` L533-538: `when mode != :requires_approval` guard returns `{:error, :not_requires_approval}` |
| CR-02: status_group/1 mapped phantom :pending_approval; real :pending fell through to :blocked | RESOLVED (commit f30175d) | `tool_proposal_presenter.ex` L62: `def status_group(:pending), do: :awaiting`; `:approved` → `:active` also present |

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/cairnloop/governance/tool_approval.ex` | ToolApproval schema + decision_changeset (FLOW-03) | VERIFIED | 117 lines; `defmodule Cairnloop.Governance.ToolApproval`; no `update/1` or `delete/1` |
| `priv/repo/migrations/20260524120000_add_tool_approvals.exs` | cairnloop_tool_approvals table + partial unique index | VERIFIED | Contains `cairnloop_tool_approvals_one_active_lane_index` with `where: "status = 'pending'"` |
| `priv/repo/migrations/20260524120100_add_snapshot_cols_to_proposals.exs` | rendered_consequence + title nullable columns | VERIFIED | Contains `add(:rendered_consequence, :text)` and `add(:title, :string)` |
| `lib/cairnloop/workers/approval_resume_worker.ex` | Re-validate gate + lazy expiry + :execution_pending seam | VERIFIED | 196 lines; `unique: [keys: [:approval_id]]`; no `run/3`; `Governance.validate/3` called |
| `lib/cairnloop/workers/approval_expiry_worker.ex` | Scheduled :pending → :expired flip | VERIFIED | 90 lines; handles `nil`, `:pending`, and `_` branches idempotently |
| `lib/cairnloop/governance.ex` | approve/reject/defer/expire/request_approval transitions + enqueue | VERIFIED | All 5 public functions + `update_approval_with_event`, `safe_enqueue`, `get_active_approval` present; `inspect(reason)` = 0; `Ecto.Multi` = 0 |
| `lib/cairnloop/governance/policy.ex` | Policy.resolve/3 extended in place with apply_context_factors pass-through | VERIFIED | L26: `def resolve(tool_module, actor_id, context)` with `apply_context_factors/4` at L37 and L55 |
| `lib/cairnloop/web/tool_proposal_presenter.ex` | Approval status_group/approval_outlook_for_approval/history_line | VERIFIED | All 7 status_group clauses, 8 approval_outlook_for_approval clauses, 9 history_line event clauses; catch-all still last |
| `lib/cairnloop/web/conversation_live.ex` | approve/reject/defer handlers + snapshot card + no streams | VERIFIED | 3 handlers; `rendered_consequence` read; `Preview.render` = 0; `LiveView.stream` = 0 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `governance.ex` | `Preview.render/1` | propose-time snapshot into rendered_consequence | VERIFIED | L292-322 calls `Preview.render/1` inside `insert_new_proposal/6` before repo insert |
| `governance.ex` | `Cairnloop.Workers.ApprovalResumeWorker` | approve enqueues after persist | VERIFIED | L631-633: `enqueue_fn.(ApprovalResumeWorker.new(%{"approval_id" => updated.id}))` after `with` success |
| `governance.ex` | `ToolApproval.decision_changeset/6` | reject/defer reason gate (FLOW-03) | VERIFIED | L666 (reject), L717 (defer), L766 (expire) all call `decision_changeset` |
| `governance.ex` | `ToolActionEvent` | append-only event co-committed with each transition | VERIFIED | `update_approval_with_event/3` inserts event in sequential `with`; `updated_at: false` in schema |
| `approval_resume_worker.ex` | `Cairnloop.Governance.validate/3` | pure re-validation against current context | VERIFIED | L73: `case Cairnloop.Governance.validate(proposal.tool_ref, proposal.actor_id, context)` |
| `conversation_live.ex` | `Cairnloop.Governance.approve/reject/defer` | footer-slot handlers | VERIFIED | L207, L228, L250: `Cairnloop.Governance.approve/reject/defer` called |
| `conversation_live.ex` | `proposal.rendered_consequence` | card reads snapshot, never live Preview.render | VERIFIED | L996-997 reads `proposal.rendered_consequence`; `Preview.render` absent from file |
| `tool_proposal.ex` | `Cairnloop.Governance.ToolApproval` | `has_one(:approval)` association | VERIFIED | L58: `has_one(:approval, Cairnloop.Governance.ToolApproval)` |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| `conversation_live.ex` approval card | `proposal.rendered_consequence` | Snapshotted at propose-time by `insert_new_proposal/6` → `Preview.render/1` | Yes (populated at DB write; read from column) | FLOWING |
| `conversation_live.ex` approval_outlook | `approval_outlook_for_approval(active_approval)` | `proposal.approval` loaded via `has_one` preload | Yes (reads from DB struct field) | FLOWING |
| `tool_proposal_presenter.ex` `history_line` | `%ToolActionEvent{}` event structs | DB `tool_action_events` table; append-only inserts co-committed with each transition | Yes (real DB writes via `repo().insert`) | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| mix compile --warnings-as-errors exits 0 | `mix compile --warnings-as-errors; echo "EXIT: $?"` | EXIT: 0 (no output, clean compile) | PASS |
| Scoped Phase 15 test suite: 260 tests, 0 failures | `mix test test/cairnloop/governance/ test/cairnloop/workers/ test/cairnloop/governance_test.exs test/cairnloop/web/tool_proposal_presenter_test.exs test/cairnloop/web/conversation_live_test.exs` | 260 tests, 0 failures (Chimeway.Repo boot noise is baseline per CLAUDE.md) | PASS |
| Full suite baseline: exactly 1 pre-existing failure in DraftTest, not Phase 15 | `mix test` | 472 tests, 1 failure: `Cairnloop.Automation.DraftTest` "changeset/2 requires content..." (M005-era drift); `git log dd1ef5e..HEAD -- lib/cairnloop/automation/` is empty (Phase 15 never touched it) | PASS (baseline confirmed) |
| No inline run/3 in approve path (APRV-01) | `grep -cE "\.run\(|run/3|Governance\.execute" governance.ex` | 0 (all "run/3" references are in comments only) | PASS |
| No Ecto.Multi (sequential `with` idiom) | `grep -c "Ecto.Multi" governance.ex` | 0 | PASS |
| CR-01 fix: request_approval guards against non-:requires_approval | `grep -n "when mode != :requires_approval"` | L534 confirmed | PASS |
| CR-02 fix: status_group(:pending) → :awaiting (not :blocked) | `grep -n "def status_group(:pending)"` | L62 confirmed | PASS |

---

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| FLOW-03 | 15-00, 15-01, 15-03, 15-04 | Operator can reject/defer with a persisted reason visible in action timeline | SATISFIED | `decision_changeset/6` enforces `validate_required([:reason])` for `:rejected`/`:deferred`; reason field persisted to `cairnloop_tool_approvals`; `history_line/1` renders reason in timeline |
| APRV-01 | 15-00, 15-03, 15-04 | Durable approval record; never execute inside LiveView or blocked worker | SATISFIED | `approve/3` persists record then enqueues `ApprovalResumeWorker`; no `run/3`/inline execution in `governance.ex` or `conversation_live.ex`; conversation_live handlers call facade then reload only |
| APRV-02 | 15-00, 15-02 | Approved actions resume through Oban job that re-validates before execution | SATISFIED | `ApprovalResumeWorker` calls `Governance.validate/3` against current context; transitions to `:execution_pending` on pass (Phase 16 seam); `:invalidated` on fail |
| APRV-03 | 15-00, 15-02, 15-04 | Approval requests expire or become invalid when policy/scope changes | SATISFIED | `ApprovalExpiryWorker` scheduled at `expires_at`; lazy guard in `ApprovalResumeWorker` checks `expires_at < now` before re-validate; `:invalidated` on re-validation failure; timeline shows state |
| APRV-04 | 15-01, 15-03 | One active approval lane per proposal; append-only event decisions | SATISFIED | Partial unique index `WHERE status = 'pending'` enforces one lane at DB level; `unique_constraint` surfaced in changeset; all transitions co-commit an append-only `ToolActionEvent` (`updated_at: false`) |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `governance.ex` | 103, 138 (workers also) | Sequential `with` co-commit without `Repo.transaction` wrapper (WR-01 from 15-REVIEW.md) | Warning | If status update succeeds and event insert fails, audit trail loses the corresponding event. Mirrors the sanctioned `update_task_with_event/4` pattern; docstrings were corrected per REVIEW.md to say "sequential non-transactional co-commit" |
| `approval_resume_worker.ex` | 94-128 | `rebuild_context_from_snapshot` drops `account_id`/`conversation_id` (WR-02 from 15-REVIEW.md) | Warning | Re-validation may spuriously invalidate correct approvals if tool's `authorize/2` gates on `account_id`; fail-closed direction is safe but may over-invalidate |
| `governance.ex` | 562-573 | `request_approval/2` has no `else` branch for unique constraint race (WR-03/WR-07 from 15-REVIEW.md) | Warning | Concurrent second `request_approval` returns raw changeset with no telemetry; tolerable but inconsistent with other constraint paths |
| `governance.ex` | Multiple | Atom-valued event `metadata` won't round-trip JSONB (WR-04 from 15-REVIEW.md) | Warning | `%{approval_status: :pending}` becomes `%{"approval_status" => "pending"}` after DB round-trip; existing `metadata_value/2` dual-key accessor partially mitigates |

**Debt marker gate:** No `TBD`, `FIXME`, or `XXX` markers found in any Phase 15 implementation files. Gate passes.

All four anti-patterns above are **open warnings from 15-REVIEW.md** acknowledged as non-blocking during execute-phase. None prevent the phase goal from being achieved.

---

### Human Verification Required

### 1. Footer slot color+text pairing (brand §7.5 accessibility)

**Test:** In a running Phoenix LiveView session, navigate to a conversation with a `:requires_approval` governed action proposal that has an active `:pending` approval lane. Inspect the footer slot.
**Expected:** Approve button uses `var(--cl-primary, #A94F30)` background with visible text label "Approve". Reject and Defer buttons have matching text. Status chip displays both color AND a text string (not color alone). Reason textarea is present for Reject/Defer.
**Why human:** Color+text pairing is a visual/accessibility property; grep confirms the brand token is present in the template but cannot verify the rendered visual composite.

### 2. Snapshot-vs-live divergence correctness (D15-14 trust-drift)

**Test:** Create a governed action proposal (which snapshots `rendered_consequence`/`title`), then modify the tool's consequence descriptor in the tool module, and reload the approval card.
**Expected:** The card displays the prose captured at propose-time (the snapshot), not the freshly-rendered current value. A pre-Phase-15 proposal (NULL snapshot columns) shows the structured-summary fallback card, not live prose.
**Why human:** Requires a live environment where propose-time and current-time prose diverge; the code path is verified correct (reads `proposal.rendered_consequence`, no `Preview.render` call) but the behavioral correctness requires observable output.

### 3. End-to-end approval flow with async Oban job

**Test:** In a running environment with Oban configured: call `request_approval/2` to open a lane, call `approve/3`, wait for the `ApprovalResumeWorker` Oban job to execute (queue drain), then inspect the approval record and event trail.
**Expected:** Approval status = `:execution_pending`; ToolActionEvent trail shows `:approval_requested`, `:approved`, `:revalidation_passed` in order; NO synchronous `run/3` was called.
**Why human:** Requires a live Oban queue; the async re-validation path uses MockRepo in tests and cannot demonstrate real end-to-end Oban job execution headlessly.

### 4. FLOW-03 reason-required enforced at UI layer (reject/defer with blank reason)

**Test:** In the ConversationLive footer, submit a "reject" or "defer" action with the reason textarea left blank.
**Expected:** The facade returns `{:error, changeset}` (reason validation fails); the handler surfaces a calm "A reason is required." flash; no ToolApproval row and no ToolActionEvent are written to the database.
**Why human:** Form submission with intentionally blank fields requires browser interaction; the server-side guard is confirmed in code but the UX error-display path needs a live session.

---

### Gaps Summary

No blocking gaps found. All 10 must-have truths are verified in the codebase.

The 4 human verification items are UI/behavioral/async checks that cannot be assessed programmatically. The underlying code is correct and wired for all four scenarios — human checks confirm the observable operator experience.

**Open warnings from 15-REVIEW.md (WR-01 through WR-07)** remain as acknowledged non-blocking items for `/gsd:code-review 15 --fix`. They do not block the phase goal.

---

_Verified: 2026-05-24T19:32:00Z_
_Verifier: Claude (gsd-verifier)_
