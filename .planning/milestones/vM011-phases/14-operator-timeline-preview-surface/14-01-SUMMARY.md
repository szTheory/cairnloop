---
phase: 14
plan: "01"
subsystem: governance-presenter-preview
tags: [wave-1, governance, presenter, preview, conversation-id, tdd, data-layer]
dependency_graph:
  requires:
    - 14-00 (Wave-0 test contracts)
  provides:
    - priv/repo/migrations/20260524120000_add_conversation_id_to_tool_proposals.exs
    - lib/cairnloop/governance/tool_proposal.ex (conversation_id FK + belongs_to)
    - lib/cairnloop/conversation.ex (has_many :tool_proposals)
    - lib/cairnloop/governance.ex (list_proposals_for_conversation/1 + conversation_id write paths)
    - lib/cairnloop/web/tool_proposal_presenter.ex
    - lib/cairnloop/governance/preview.ex
  affects:
    - Wave 2 (14-02): governed_action_card/1 component renders against ToolProposalPresenter
    - Wave 3 (14-03): conversation timeline rail uses list_proposals_for_conversation/1
    - Phase 15: must add rendered_consequence + title columns per guardrail in Preview @moduledoc
tech_stack:
  added: []
  patterns:
    - Nullable FK with nilify_all (pre-Phase-14 rows stay NULL — D-06)
    - Dual-key metadata_value/2 lookup (atom + string) for JSONB round-trip survival
    - String.to_existing_atom/1 + rescue ArgumentError for JSONB key atomization (never String.to_atom — T-14-01)
    - Code.ensure_loaded? + function_exported? + try/rescue D-19 guard stack
    - struct/2 rehydration (never the cast/validate pipeline — RESEARCH anti-pattern)
    - "Unsupported value" posture for masking nested/sensitive input_snapshot values (D-22)
key_files:
  created:
    - priv/repo/migrations/20260524120000_add_conversation_id_to_tool_proposals.exs
    - lib/cairnloop/web/tool_proposal_presenter.ex
    - lib/cairnloop/governance/preview.ex
  modified:
    - lib/cairnloop/governance/tool_proposal.ex
    - lib/cairnloop/conversation.ex
    - lib/cairnloop/governance.ex
    - test/cairnloop/governance_test.exs
    - test/cairnloop/governance/preview_test.exs
    - test/cairnloop/web/tool_proposal_presenter_test.exs
decisions:
  - D-06: Nullable conversation_id FK with nilify_all; pre-Phase-14 rows stay NULL (no backfill)
  - D-07: conversation_id written on BOTH valid and blocked proposal paths (both appear in rail)
  - D-08: conversation_id excluded from idempotency canonical map; identical actions in different conversations deduplicate
  - D-17: {:structured, _} is the common Phase-14 path (no tool exports preview/1 yet)
  - D-19: String.to_existing_atom/1 + rescue for JSONB key atomization; NEVER String.to_atom/1
  - D-22: input_rows/1 is the masking choke point; "Unsupported value" posture for nested/sensitive values
  - MockRepo extended with all/1 to handle Ecto.Query structs for list_proposals_for_conversation/1 tests
metrics:
  duration: "~8 min"
  completed: "2026-05-24T12:11:00Z"
  tasks_completed: 2
  files_created: 3
  files_modified: 6
---

# Phase 14 Plan 01: Wave 1 Data + Presenter + Preview Layer Summary

Conversation_id data linkage (migration, schema, facade write paths, list helper), pure
`ToolProposalPresenter` (total functions, D-22 masking, D-14 humanization), and total
`Preview.render/1` (D-19 guard stack, Phase-15 @moduledoc guardrail). Wave-0 FLOW-01 and
FLOW-02 tests turned green; `mix compile --warnings-as-errors` clean; 1 baseline failure
unchanged.

## What Was Built

### Task 1: conversation_id linkage

**Migration** `priv/repo/migrations/20260524120000_add_conversation_id_to_tool_proposals.exs`:
- Nullable `conversation_id` FK on `cairnloop_tool_proposals` (`references(:cairnloop_conversations, on_delete: :nilify_all)`)
- Composite index on `[:conversation_id, :inserted_at]`
- No data backfill (D-06 — pre-Phase-14 rows correctly stay NULL)

**`lib/cairnloop/governance/tool_proposal.ex`**:
- `belongs_to(:conversation, Cairnloop.Conversation)` added
- `:conversation_id` added to `cast/3` list (not validate_required — nullable by design)

**`lib/cairnloop/conversation.ex`**:
- `has_many(:tool_proposals, Cairnloop.Governance.ToolProposal)` added (parallel to `has_many(:drafts)`)

**`lib/cairnloop/governance.ex`**:
- `conversation_id: Map.get(context, :conversation_id)` threaded into `insert_new_proposal/6` (D-07)
- `conversation_id: Map.get(context, :conversation_id)` threaded into `insert_blocked_proposal/10` (D-07)
- D-08 exclusion comment added to `derive_idempotency_key/4` canonical map
- `list_proposals_for_conversation/1` added: filters by conversation_id, orders desc:inserted_at, preloads events asc:inserted_at

**`test/cairnloop/governance_test.exs`**:
- `MockRepo.all/1` added to handle `Ecto.Query` structs (parse where clause, filter, order, populate events)
- `MockRepo.maybe_put_inserted_at/1` added to fix `put_new` not overwriting nil timestamps
- 5 Wave-1 tests un-skipped and green: list_proposals (3 tests) + conversation_id write paths (2 tests)

### Task 2: ToolProposalPresenter + Preview.render/1

**`lib/cairnloop/web/tool_proposal_presenter.ex`** (pure, total, no markup, no live config re-read):
- `status_label/1` — D-11 locked copy: "Proposed" / "Needs input" / "Not available here" / "Blocked by policy"
- `status_meaning/1` — calm one-sentence explanation per status
- `status_group/1` + `status_group_label/1` — D-10 four groups (:awaiting/:blocked/:active/:done)
- `risk_tier_label/1` + `risk_tier_tone/1` — tone returns atom (:info/:warning/:danger) only (brand §7.5)
- `approval_mode_label/1` + `approval_outlook/1` — D-12 honesty seam (nil for :auto)
- `reason_label/1` — handles nil/tuple/{:missing_scopes,_}/atom/string without inspect output (D-14)
- `input_rows/1` — masking choke point (D-22): allowlisted scalar fields, "Unsupported value" for nested
- `scope_summary/1`, `policy_explanation/1` — dual-key lookup for JSONB string-key survival
- `block_reason_copy/1`, `history_line/1` — D-24 catch-all → "Workflow updated"
- `event_timestamp_label/1` — mirrors SearchResultPresenter.relative_time/1
- `trace_metadata/1` — humanized trace fields (no raw module atom strings)

**`lib/cairnloop/governance/preview.ex`** (total function, D-17/D-18/D-19):
- `render/1` — returns `{:preview, String.t()}` or `{:structured, map()}` (TOTAL, never crashes)
- D-19 guard stack: find_tool_module → Code.ensure_loaded? → function_exported? → rehydrate → try/rescue
- JSONB key atomization via `String.to_existing_atom/1` + rescue ArgumentError (NEVER `String.to_atom`)
- `struct/2` rehydration (never the cast/validate pipeline)
- Structured fallback built from snapshot only (D-17 — common path in Phase 14)
- Phase-15 forward-compat guardrail in `@moduledoc` (D-16 additive promotion)

**Tests un-skipped and green**:
- All 36 `tool_proposal_presenter_test.exs` tests (all Wave-1 FLOW-02)
- 8 `preview_test.exs` tests (all un-skipped, including inline test-only tool modules for raise/non-string coverage)

## Test Results

```
mix compile --warnings-as-errors: CLEAN (exit 0)
mix test (three Wave-1 files): 71 tests, 0 failures, 0 skipped
mix test (full suite): 1 doctest, 366 tests, 1 failure (pre-existing DraftTest baseline), 10 skipped (Wave-2/Wave-3 card/rail tests)
```

Pre-existing baseline (UNCHANGED):
- 1 failure: `Cairnloop.Automation.DraftTest` — NOT introduced by this plan
- `Chimeway.Repo` Postgrex "missing the :database key" boot noise — expected (Repo unavailable)
- `@impl` warnings in test tool modules in `governance_test.exs` — pre-existing from Wave-0

Remaining 10 skipped (Wave-2/Wave-3 only):
- `conversation_live_test.exs`: governed_action_card renders (6 tests) + blocked proposals in rail (3 tests) + MockRepo governed_actions load (1 test)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] MockRepo.insert did not set inserted_at when nil**
- **Found during:** Task 1 — list_proposals test sorting failed with nil DateTime
- **Issue:** `Map.put_new(:inserted_at, ...)` only sets if key is absent; ToolProposal struct initializes `inserted_at: nil`, so `put_new` left it nil
- **Fix:** Added `maybe_put_inserted_at/1` that explicitly replaces `nil` with `DateTime.utc_now()`
- **Files modified:** `test/cairnloop/governance_test.exs`
- **Commit:** b1cf7c4

**2. [Rule 1 - Bug] scope_summary/1 operator precedence**
- **Found during:** Task 2 presenter tests
- **Issue:** `"Required scopes: " <> Enum.map(...) |> Enum.join(", ")` — `<>` binds tighter than `|>`, trying to concatenate a list
- **Fix:** Added parentheses: `"Required scopes: " <> (Enum.map(...) |> Enum.join(", "))`
- **Files modified:** `lib/cairnloop/web/tool_proposal_presenter.ex`
- **Commit:** 4bf3931

**3. [Rule 2 - Missing Critical Functionality] Preview test live-leg coverage**
- **Found during:** Task 2 — placeholder tests for "raises" and "non-string return" were just `:ok`
- **Issue:** Plan required inline test-only tool modules exercising the live leg; placeholder tests had no assertions
- **Fix:** Added inline `defmodule RaisingPreviewTool` and `NonStringPreviewTool` to preview_test.exs with actual `preview/1` implementations and assertions
- **Files modified:** `test/cairnloop/governance/preview_test.exs`
- **Commit:** 4bf3931

## Known Stubs

None — all implemented functions return real values from snapshot data. No hardcoded empty values flowing to UI.

## Threat Flags

All T-14-xx threats mitigated as designed:
- T-14-01: `String.to_atom(` count == 0 in preview.ex (grep verified)
- T-14-02: try/rescue guard around preview/1 in live leg
- T-14-03: unknown tool → structured fallback; title chain never emits raw module atom
- T-14-04: conversation_id absent from canonical map (D-08 comment + grep verified)
- T-14-05: input_rows/1 allowlist + "Unsupported value" posture (D-22)
- T-14-06: reason_label/1 humanizes all shapes; policy_explanation/1 returns calm sentence

## Self-Check: PASSED

- `priv/repo/migrations/20260524120000_add_conversation_id_to_tool_proposals.exs` exists: YES
- `lib/cairnloop/web/tool_proposal_presenter.ex` exists: YES
- `lib/cairnloop/governance/preview.ex` exists: YES
- Commits exist:
  - b1cf7c4: feat(14-01): conversation_id linkage
  - 4bf3931: feat(14-01): ToolProposalPresenter + Preview.render/1
- `mix compile --warnings-as-errors`: CLEAN (exit 0)
- `mix test` full suite: 1 failure (pre-existing baseline only), 10 skipped (Wave-2/Wave-3)
