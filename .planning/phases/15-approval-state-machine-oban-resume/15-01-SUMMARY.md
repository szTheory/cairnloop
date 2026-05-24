---
phase: 15-approval-state-machine-oban-resume
plan: "01"
subsystem: governance-approval-storage
tags: [approval-state-machine, ecto-schema, migrations, governance-facade, tdd, wave-1]
dependency_graph:
  requires:
    - "15-00"
  provides:
    - lib/cairnloop/governance/tool_approval.ex
    - priv/repo/migrations/20260524120000_add_tool_approvals.exs
    - priv/repo/migrations/20260524120100_add_snapshot_cols_to_proposals.exs
    - lib/cairnloop/governance.ex (extended)
    - lib/cairnloop/governance/tool_proposal.ex (extended)
    - lib/cairnloop/governance/tool_action_event.ex (extended)
    - lib/cairnloop/governance/preview.ex (extended)
  affects:
    - "15-02"
    - "15-03"
    - "15-04"
tech_stack:
  added: []
  patterns:
    - "ToolApproval mirrors ReviewTask idiom: denormalized status enum + last-decision fields + decision_changeset/6"
    - "One-active-lane partial unique index WHERE status='pending' (APRV-04)"
    - "Ecto.Changeset.traverse_errors/2 for reason humanization (WR-01/D15-15)"
    - "Preview.render/1 called at propose-time for snapshot (D15-14)"
    - "Conditional validate_required for to_status (proposal events only, D15-03)"
key_files:
  created:
    - lib/cairnloop/governance/tool_approval.ex
    - priv/repo/migrations/20260524120000_add_tool_approvals.exs
    - priv/repo/migrations/20260524120100_add_snapshot_cols_to_proposals.exs
  modified:
    - lib/cairnloop/governance/tool_proposal.ex
    - lib/cairnloop/governance/tool_action_event.ex
    - lib/cairnloop/governance.ex
    - lib/cairnloop/governance/preview.ex
    - test/cairnloop/governance/tool_approval_test.exs
    - test/cairnloop/governance/tool_action_event_test.exs
    - test/cairnloop/governance_test.exs
    - test/cairnloop/governance/preview_test.exs
decisions:
  - "ToolApproval.decision_changeset/6 uses string last_decision (not enum) to allow freeform decision labels — consistent with ReviewTask idiom and Wave 3 call sites"
  - "Preview.render structured path snapshots title only (not rendered_consequence) since no tool in test registry exports preview/1; rendered_consequence only populated on {:preview, prose} path"
  - "Fixed Wave 0 test bugs: constraint_name->constraint key in constraint struct (Ecto API difference); DateTime microsecond precision for :utc_datetime_usec cast"
  - "Extended MockRepo in governance_test.exs to support ToolApproval get_by with process-dictionary seeding for get_active_approval tests"
  - "Kept ToolActionEvent.from_status/to_status typed against ToolProposal.status_values() — NOT widened (Pitfall 4 preserved); approval events carry nil for both"
metrics:
  duration: "~8 min"
  completed_date: "2026-05-24"
  tasks: 2
  files_created: 3
  files_modified: 7
---

# Phase 15 Plan 01: Storage Foundation & Sanctioned propose/3 Reopen Summary

ToolApproval schema, two migrations, ToolProposal/ToolActionEvent extensions, D15-14 propose-time snapshot, D15-15/WR-01 humanization, and get_active_approval/1 facade API. Wave 0 changeset/event-type/WR-01/snapshot tests all turned green.

## What Was Built

### ToolApproval Schema (`lib/cairnloop/governance/tool_approval.ex`)

New `Cairnloop.Governance.ToolApproval` schema mirroring the `ReviewTask` idiom:
- Status enum: `[:pending, :approved, :execution_pending, :rejected, :deferred, :expired, :invalidated]` (default `:pending`)
- Denormalized last-decision fields: `decided_by`, `last_decision`, `decided_at`, `reason`, `expires_at`
- `belongs_to(:tool_proposal, ToolProposal)`
- `changeset/2` with `validate_required([:tool_proposal_id, :status])` and `unique_constraint(:tool_proposal_id, name: :cairnloop_tool_approvals_one_active_lane_index)` (APRV-04)
- `decision_changeset/6` with FLOW-03 reason gate: `validate_required([:reason])` for `:rejected` and `:deferred` statuses
- No `update/1` or `delete/1` (append-only intent; transitions via `decision_changeset/6`)

### Migration: cairnloop_tool_approvals (`priv/repo/migrations/20260524120000_add_tool_approvals.exs`)

Creates `cairnloop_tool_approvals` table with:
- `tool_proposal_id` (FK `on_delete: :delete_all`, NOT NULL)
- `status :string NOT NULL DEFAULT 'pending'`
- Decision fields: `decided_by`, `last_decision`, `decided_at :utc_datetime_usec`, `reason :text`, `expires_at :utc_datetime_usec`
- `timestamps(type: :utc_datetime_usec)`
- Compound index on `(tool_proposal_id, status)` + expiry-sweep index on `(status, expires_at)`
- **Partial unique index** `WHERE status = 'pending'` named `:cairnloop_tool_approvals_one_active_lane_index` (APRV-04 one-active-lane constraint)

### Migration: snapshot columns on proposals (`priv/repo/migrations/20260524120100_add_snapshot_cols_to_proposals.exs`)

Alters `cairnloop_tool_proposals` to add:
- `rendered_consequence :text` (nullable — pre-Phase-15 rows stay NULL)
- `title :string` (nullable — pre-Phase-15 rows stay NULL)

### ToolProposal extensions (`lib/cairnloop/governance/tool_proposal.ex`)

- Added `field(:rendered_consequence, :string)` and `field(:title, :string)` to schema
- Added both to `changeset/2` cast list
- Added `has_one(:approval, Cairnloop.Governance.ToolApproval)` after existing `has_many(:events, ToolActionEvent)`

### ToolActionEvent extensions (`lib/cairnloop/governance/tool_action_event.ex`)

- Extended `@event_type_values` with 9 approval atoms: `:approval_requested`, `:approved`, `:rejected`, `:deferred`, `:expired`, `:invalidated`, `:resume_scheduled`, `:revalidation_passed`, `:revalidation_failed`
- Added `@proposal_event_types [:proposal_created, :proposal_blocked]` module attribute
- Relaxed `validate_required` in `changeset/2`: `:to_status` now required only for proposal event types via `validate_to_status_for_proposal_events/1`; approval events accept `from_status: nil, to_status: nil` carrying transition in `event_type + metadata`
- Preserved `timestamps(updated_at: false)` append-only invariant

### governance.ex extensions (`lib/cairnloop/governance.ex`)

**(D15-14) Propose-time snapshot:** `insert_new_proposal/6` calls `Preview.render/1` on a lightweight `%ToolProposal{}` struct before persisting, capturing `{rendered_consequence, title}` from the result:
- `{:preview, prose}` → `{prose, nil}` (live preview prose; title nil)
- `{:structured, %{title: t}}` → `{nil, t}` (common Phase-14 path; title from structured result)
- Other → `{nil, nil}` (fallback)
Both keys added to `proposal_attrs` map.

**(D15-15/WR-01) Humanized reason:** Replaced `reason_str = inspect(reason)` at L313 with humanized builder using `Ecto.Changeset.traverse_errors/2`:
- `%Ecto.Changeset{}` → traverse_errors interpolating `%{k}` opts then joining `field: msg` pairs
- atom → `Atom.to_string/1`
- binary → pass-through
- else → `"blocked"`
The `:needs_input` row still persists (Support-Truth Gate preserved).

**(D15-17) `get_active_approval/1` facade:** Added public function:
```elixir
def get_active_approval(tool_proposal_id) do
  repo().get_by(ToolApproval, tool_proposal_id: tool_proposal_id, status: :pending)
end
```

Added `Preview` and `ToolApproval` to alias block.

### preview.ex (`lib/cairnloop/governance/preview.ex`)

Updated `@moduledoc` to mark D-16 4-step guardrail as DISCHARGED by Phase 15. The forward-compat contract is fulfilled; the marker remains as a discoverable reference for future phases.

## Verification Results

```
mix compile --warnings-as-errors  → exit 0 (clean)
mix test test/cairnloop/governance/tool_approval_test.exs test/cairnloop/governance/tool_action_event_test.exs
                                  → 40 tests, 0 failures
mix test test/cairnloop/governance_test.exs test/cairnloop/governance/preview_test.exs
                                  → 54 tests, 0 failures, 7 skipped (Wave 3+ approve/reject/defer)
Full scoped suite (governance/ + workers/ + presenter_test)
                                  → 186 tests, 0 failures, 36 skipped (Waves 2-4 remaining)
Chimeway.Repo boot noise          → pre-existing baseline (not a regression)
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Wave 0 test: `constraint_name` → `constraint` key in Ecto constraint struct**
- **Found during:** Task 1 test run — `Enum.map(changeset.constraints, & &1.constraint_name)` returned `[nil]`
- **Issue:** Wave 0 test used `.constraint_name` but Ecto's constraint struct stores the name under `.constraint` (a string value)
- **Fix:** Changed to `Enum.map(changeset.constraints, & &1.constraint)` and compared against the string `"cairnloop_tool_approvals_one_active_lane_index"`
- **Files modified:** `test/cairnloop/governance/tool_approval_test.exs`
- **Commit:** f98e830

**2. [Rule 1 - Bug] Fixed Wave 0 test: `DateTime` second-precision vs `:utc_datetime_usec` microsecond normalization**
- **Found during:** Task 1 test run — `decided_at` assertion failed with `~U[2026-01-01 12:00:00.000000Z]` ≠ `~U[2026-01-01 12:00:00Z]`
- **Issue:** `~U[2026-01-01 12:00:00Z]` has second precision; Ecto `:utc_datetime_usec` type casts it to microsecond precision `~U[2026-01-01 12:00:00.000000Z]`; `==` fails on `DateTime` structs with different precision
- **Fix:** Changed test fixtures to use microsecond-precision `~U[2026-01-01 12:00:00.000000Z]`
- **Files modified:** `test/cairnloop/governance/tool_approval_test.exs`
- **Commit:** f98e830

**3. [Rule 1 - Bug] Updated Wave 0 state test that asserted approval atoms are INVALID**
- **Found during:** Task 1 implementation — Wave 0 test "approval event_type atoms are NOT in @event_type_values until Wave 1" now fails because Wave 1 adds them
- **Issue:** The Wave 0 contract test used `refute changeset.valid?` to document the pre-Wave-1 state; after Wave 1 ships the atoms ARE valid
- **Fix:** Updated test to assert approval atoms ARE now valid; renamed to "approval event_type atoms are NOW in @event_type_values (Wave 1 shipped)"
- **Files modified:** `test/cairnloop/governance/tool_action_event_test.exs`
- **Commit:** f98e830

**4. [Rule 2 - Missing critical functionality] Extended MockRepo in governance_test.exs for ToolApproval get_by**
- **Found during:** Task 2 — `get_active_approval/1` tests need MockRepo to handle `ToolApproval` schema in `get_by`; the Wave 0 MockRepo only handled `ToolProposal`
- **Issue:** MockRepo returns `nil` for all non-ToolProposal schemas; the "returns :pending approval" test would fail without seeding
- **Fix:** Extended MockRepo `get_by` to handle `Cairnloop.Governance.ToolApproval` (reads from `:tool_approvals` process dictionary key); added `persist_inserted/1` clause for ToolApproval; updated test to seed a pending approval before asserting
- **Files modified:** `test/cairnloop/governance_test.exs`
- **Commit:** 2a86903

## Known Stubs

None — all implemented code paths are functional. The `rendered_consequence` field will be `nil` for proposals where the tool does not implement `preview/1` (the common Phase-14 path), which is the correct and intended behavior per D15-14 (approval surfaces fall back to the structured card in that case).

## Threat Flags

None — the three STRIDE threats from the plan's threat model are now mitigated:
- **T-15-01 (T-raw-terms):** `inspect(reason)` replaced with `traverse_errors/2`; test asserts no `#Ecto.Changeset<` substring.
- **T-15-02 (T-trust-drift):** `Preview.render/1` called at propose-time; snapshotted columns populated going forward.
- **T-15-03 (T-two-lane):** Partial unique index `WHERE status = 'pending'` created; `unique_constraint` on changeset surfaces conflicts.
- **T-15-04 (T-append-only):** `ToolActionEvent` reused; `timestamps(updated_at: false)` preserved; no widening of proposal status enum.

## Self-Check: PASSED
