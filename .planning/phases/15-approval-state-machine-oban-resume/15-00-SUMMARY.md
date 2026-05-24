---
phase: 15-approval-state-machine-oban-resume
plan: "00"
subsystem: governance-approval-tests
tags: [test-infrastructure, wave-0, tdd, approval-state-machine, oban-resume]
dependency_graph:
  requires: []
  provides:
    - test/cairnloop/governance/tool_approval_test.exs
    - test/cairnloop/workers/approval_resume_worker_test.exs
    - test/cairnloop/workers/approval_expiry_worker_test.exs
    - test/cairnloop/governance_test.exs (extended)
    - test/cairnloop/governance/tool_action_event_test.exs (extended)
    - test/cairnloop/governance/preview_test.exs (extended)
    - test/cairnloop/web/tool_proposal_presenter_test.exs (extended)
  affects: []
tech_stack:
  added: []
  patterns:
    - "@tag :skip on undefined-module refs for Wave 0 compile-safety"
    - "MockRepo via Application.put_env(:cairnloop, :repo, MockRepo) for headless worker tests"
    - "Map.put instead of struct syntax for fields that don't exist yet"
    - "Source-assertion tests that run now and verify Wave N invariants"
key_files:
  created:
    - test/cairnloop/governance/tool_approval_test.exs
    - test/cairnloop/workers/approval_resume_worker_test.exs
    - test/cairnloop/workers/approval_expiry_worker_test.exs
  modified:
    - test/cairnloop/governance_test.exs
    - test/cairnloop/governance/tool_action_event_test.exs
    - test/cairnloop/governance/preview_test.exs
    - test/cairnloop/web/tool_proposal_presenter_test.exs
decisions:
  - "Use Map.put (not struct syntax) for fields not yet on ToolProposal — avoids compile-time unknown-key errors"
  - "MockRepo functions use module-name equality guards with compile-safe atom comparison (not require guards)"
  - "Source-assertion tests (no @tag :skip) run in Wave 0 and verify file invariants; they pass trivially when files don't exist and meaningfully once Wave N creates them"
  - "Tool_action_event_test Wave 0 state test explicitly asserts approval atoms ARE invalid now — documents the contract for Wave 1 to turn green"
metrics:
  duration: "~10 min"
  completed_date: "2026-05-24"
  tasks: 2
  files_created: 3
  files_modified: 4
---

# Phase 15 Plan 00: Wave 0 Approval Test Infrastructure Summary

Wave 0 test infrastructure for the Phase 15 approval state machine and Oban resume surface. Three new headless test files and four extended test files establish the per-task `<automated>` verification gates that Waves 1-4 will turn green.

## What Was Built

**3 new headless test files (Wave 0 scaffolds, all @tag :skip pending implementation):**

- `test/cairnloop/governance/tool_approval_test.exs` — ToolApproval changeset validity, `decision_changeset/6` FLOW-03 reason-required (reject/defer require reason, approve does not), one-active-lane `unique_constraint` declaration, denormalized last-decision fields (mirrors ReviewTask idiom), append-only invariant (`refute function_exported?`). The append-only tests run NOW.

- `test/cairnloop/workers/approval_resume_worker_test.exs` — MockRepo with 4 approval fixtures (id 1: pending/no-expiry, id 2: already-approved, id 3: nil/deleted, id 4: pending/expired TTL). Describe blocks for validate-pass→`:execution_pending`, lazy `expires_at` guard→`:expired`, already-transitioned no-ops, and the validate-fail→`:invalidated` path. Source-assertion test (runs now) verifies `approval_resume_worker.ex` will never contain `.run(`.

- `test/cairnloop/workers/approval_expiry_worker_test.exs` — MockRepo mirroring the SlaCountdownWorker pattern. Describe block for the scheduled `:pending→:expired` flip + event (SlaCountdownWorker flip idiom), and already-resolved/deleted no-ops.

**4 extended existing test files:**

- `test/cairnloop/governance_test.exs` — New Phase 15 describe blocks: `get_active_approval/1` facade contract; `approve/3` enqueues-never-executes (APRV-01, `enqueue_fn` injection pattern); record-before-enqueue ordering; append-only multi-decision trail (≥2 events for request→approve); transition guarded on `:pending` (force-resolved approvals refused); D15-15/WR-01 humanization (`:needs_input` still persists + no `#Ecto.Changeset<` in policy_snapshot or event reason). Non-skip "`:needs_input` persists" test passes now (Phase 13 behavior intact).

- `test/cairnloop/governance/tool_action_event_test.exs` — New describe block for 9 approval `@event_type_values` atoms: `:approval_requested`, `:approved`, `:rejected`, `:deferred`, `:expired`, `:invalidated`, `:resume_scheduled`, `:revalidation_passed`, `:revalidation_failed`. Wave 0 state test explicitly asserts they are INVALID now (documents Wave 1 extension contract). Existing append-only invariant tests unchanged.

- `test/cairnloop/governance/preview_test.exs` — New "snapshotted prose vs live divergence (D15-14)" describe block. Uses `Map.put` instead of struct syntax (fields not on ToolProposal yet). Tests the snapshot-reads-not-live-Preview invariant, NULL-snapshot fallback to structured card (P14 D-17), and the proposal struct compatibility assertion (runs now).

- `test/cairnloop/web/tool_proposal_presenter_test.exs` — New describe blocks for: `status_group/1` approval states (`:pending_approval`→`:awaiting`, `:execution_pending`→`:active`, `:rejected`/`:deferred`/`:expired`/`:invalidated`→`:done`; zero relabeling D15-16); `approval_outlook_for_approval/1` real "Pending approval" copy (not future-tense); `history_line/1` for all 9 approval event_types with actor_id/reason visibility and no raw Elixir terms.

## Verification Results

```
mix compile --warnings-as-errors  → exit 0 (clean)
mix test {all 7 files}            → 160 tests, 0 failures, 67 skipped
Scoped suite (governance/ + workers/ + presenter_test) → 144 tests, 0 failures, 55 skipped
Chimeway.Repo boot noise          → pre-existing baseline (not a regression)
```

## Deviations from Plan

**1. [Rule 1 - Bug] Used Map.put instead of struct syntax in preview_test.exs**
- **Found during:** Task 2 execution — first compile attempt
- **Issue:** `%Cairnloop.Governance.ToolProposal{rendered_consequence: ..., title: ...}` is a compile-time struct literal; the fields don't exist on ToolProposal until Wave 1, causing "unknown key" compile errors
- **Fix:** Replaced struct literal syntax with `base_proposal() |> Map.put(:rendered_consequence, ...) |> Map.put(:title, ...)` for the divergence fixture tests
- **Files modified:** `test/cairnloop/governance/preview_test.exs`
- **Commit:** 07405b4

**2. [Rule 1 - Bug] Used plain map instead of ToolApproval struct in presenter_test.exs**
- **Found during:** Task 2 — same class of issue
- **Issue:** `%Cairnloop.Governance.ToolApproval{status: :pending}` would cause a compile error since ToolApproval doesn't exist until Wave 1
- **Fix:** Changed to `%{status: :pending}` (plain map) for the approval_outlook fixture
- **Files modified:** `test/cairnloop/web/tool_proposal_presenter_test.exs`
- **Commit:** 07405b4

**3. [Rule 1] Removed unused module attributes in worker tests**
- **Found during:** Task 1 — `mix test` showed warnings for `@tool_approval_module` and `@tool_proposal_module` defined but never used at the module level (MockRepo uses inline module names for pattern guards)
- **Fix:** Removed the two unused module attributes from `approval_resume_worker_test.exs` and `approval_expiry_worker_test.exs`
- **Files modified:** Both worker test files
- **Commit:** cd9a47d

## Known Stubs

None — this plan creates test-only files. The `@tag :skip` annotations are intentional Wave 0 scaffolding, not stubs that block the plan's goal.

## Threat Flags

None — Wave 0 is test-infrastructure-only. No new production code or network surfaces introduced.

## Self-Check: PASSED
