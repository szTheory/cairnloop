---
phase: 15-approval-state-machine-oban-resume
plan: "04"
subsystem: governance-approval-ui
tags: [approval-state-machine, presenter, liverview, tdd, wave-4, aprv-01, flow-03, d15-14, d15-16]
dependency_graph:
  requires:
    - "15-01"
    - "15-03"
  provides:
    - lib/cairnloop/web/tool_proposal_presenter.ex (approval state display)
    - lib/cairnloop/web/conversation_live.ex (footer affordances + handlers)
  affects: []
tech_stack:
  added: []
  patterns:
    - "status_group/1 extended with approval atoms → :awaiting/:active/:done (D15-16 zero relabeling)"
    - "approval_outlook_for_approval/1: present-tense copy for active approval records (D15-16)"
    - "history_line/1: 9 approval event clauses above D-24 catch-all (D15-17)"
    - "governed_action_card/1: reads snapshotted title/rendered_consequence (D15-14), never Preview.render"
    - "approve_action/reject_action/defer_action handlers: facade-call + reload (APRV-01 no inline exec)"
    - "Footer slot: Approve button + Reject/Defer forms with inline reason capture (FLOW-03)"
    - "Brand token var(--cl-primary) + text label (brand §7.5 never color-alone)"
key_files:
  created: []
  modified:
    - lib/cairnloop/web/tool_proposal_presenter.ex
    - lib/cairnloop/web/conversation_live.ex
    - lib/cairnloop/governance.ex
    - test/cairnloop/web/tool_proposal_presenter_test.exs
    - test/cairnloop/web/conversation_live_test.exs
decisions:
  - "Removed Preview alias and all Preview.render/1 calls from conversation_live; pre-Phase-15 NULL-snapshot rows fall back to humanized tool_ref display (P14 D-17 structured-summary card) — not live prose"
  - "list_proposals_for_conversation/1 extended to preload :approval association so card reads preloaded assoc without per-proposal facade call"
  - "Handler event names: approve_action/reject_action/defer_action (avoids conflict with existing approve_draft event)"
  - "All 17 @tag :skip tags removed from presenter tests; 9 new Phase 15 footer/handler tests added to conversation_live"
metrics:
  duration: "~8 min"
  completed_date: "2026-05-24"
  tasks: 2
  files_created: 0
  files_modified: 5
---

# Phase 15 Plan 04: Approval UI Surface & ConversationLive Footer Summary

Presenter extended with approval state mappings (zero relabeling, D15-16), present-tense approval copy, and 9 humanized history_line clauses. ConversationLive footer slot wired with Approve/Reject/Defer affordances; handlers persist via Governance facade (APRV-01, FLOW-03); card reads snapshotted prose (D15-14); all Phase-15 approval tests green.

## What Was Built

### ToolProposalPresenter extensions (`lib/cairnloop/web/tool_proposal_presenter.ex`)

**(D15-16) `status_group/1` approval atoms:** 6 new clauses ABOVE the `:blocked` catch-all:
- `:pending_approval` → `:awaiting`
- `:execution_pending` → `:active`
- `:rejected` / `:deferred` / `:expired` / `:invalidated` → `:done`

Zero relabeling: `status_group_label/1` unchanged (four fixed group names per D15-16).

**(D15-16) `approval_outlook_for_approval/1`:** New total function taking an approval struct/map:
- `:pending` → "Pending approval — an operator must approve, reject, or defer this action."
- `:approved` → "Approved — resuming with current policy check."
- `:execution_pending` → "Approved — ready to execute."
- `:rejected` / `:deferred` → reason-forward "Rejected: <reason>" / "Deferred: <reason>" (§5.6)
- `:expired` → "Approval request expired."
- `:invalidated` → "Approval invalidated — policy or scope changed since approval."
- `_` → `nil` (total)

Leaves existing `approval_outlook/1` (future-tense honesty seam) in place for proposals with no active approval.

**(D15-17) `history_line/1` approval event clauses:** 9 clauses ABOVE the D-24 catch-all:
`:approval_requested`, `:approved`, `:rejected`, `:deferred`, `:expired`, `:invalidated`,
`:revalidation_passed`, `:revalidation_failed`, `:resume_scheduled` — all show actor_id and reason where present; no raw Elixir terms (brand §5.3/§5.6).

D-24 catch-all `def history_line(%ToolActionEvent{}), do: "Workflow updated"` remains LAST.

### ConversationLive extensions (`lib/cairnloop/web/conversation_live.ex`)

**(D15-14 / D15-17) Card precompute:**
- Resolves active approval from preloaded `proposal.approval` (when loaded) or `Governance.get_active_approval/1` fallback — keeps read through the narrow facade
- `approval_outlook`: uses `approval_outlook_for_approval/1` (present-tense D15-16) when active approval exists; falls back to `approval_outlook/1` (approval_mode honesty seam) when none
- Headline from snapshotted `proposal.title` → `proposal.rendered_consequence` → humanized `tool_ref` display for pre-Phase-15 NULL-snapshot rows (P14 D-17 structured fallback)
- Preview alias and all `Preview.render/1` calls removed (D15-14)

**(APRV-01 / FLOW-03) Footer slot:** Renders when `active_approval.status == :pending`:
- **Approve** button: `phx-click="approve_action"` with `phx-value-approval-id`
- **Reject** form: `phx-submit="reject_action"` with inline `<textarea name="reason">` (reason-required per FLOW-03)
- **Defer** form: `phx-submit="defer_action"` with inline `<textarea name="reason">` (reason-required per FLOW-03)
- Status conveyed by text label AND color chip (brand §7.5)
- Brand token `var(--cl-primary, #A94F30)` for Approve button (§2.2/§7)
- Calm copy: "A reason is required for rejection or deferral." (§13.2)

**(APRV-01) handle_event handlers:**
- `approve_action`: calls `Cairnloop.Governance.approve/3` → on success `put_flash(:info, "Action approved.")` + `reload_conversation_with_context`; never calls `run/3`
- `reject_action`: calls `Cairnloop.Governance.reject/3` with `reason:` opt → FLOW-03 error flash on missing reason; success flash + reload
- `defer_action`: calls `Cairnloop.Governance.defer/3` with `reason:` opt → FLOW-03 error flash on missing reason; success flash + reload

All reflection via `reload_conversation_with_context/2` — plain-assign, no streams (P14 D-02).

### Governance facade extension (`lib/cairnloop/governance.ex`)

`list_proposals_for_conversation/1`: extended `preload/2` to include `approval: []` so each proposal arrives with the `:approval` association preloaded — card reads it directly, no per-proposal facade call needed.

### Tests (`test/cairnloop/web/tool_proposal_presenter_test.exs`)

Removed all 17 `@tag :skip` tags from Phase 15 approval describe blocks:
- `status_group/1 — approval states (D15-16, 15-04-a)`: 6 tests
- `approval_outlook for active :pending approval (D15-16, 15-04-b)`: 1 test
- `history_line/1 — approval events (D15-16, 15-04-b)`: 10 tests

### Tests (`test/cairnloop/web/conversation_live_test.exs`)

Added `describe "governed_action_card/1 — Phase 15 approval surface"` (5 tests) and `describe "handle_event approve_action/reject_action/defer_action"` (4 tests):
- Footer renders Approve/Reject/Defer when :pending approval preloaded
- Card reads snapshotted title (D15-14 source assertion)
- approval_outlook shows "Pending approval" (D15-16)
- Brand token var(--cl-primary) source assertion (§2.2/§7)
- No streams source assertion (P14 D-02)
- No Preview.render source assertion (D15-14)
- approve_action handler round-trip
- reject_action/defer_action FLOW-03 error-flash on empty reason

## Verification Results

```
mix compile --warnings-as-errors  → exit 0 (clean)
mix test test/cairnloop/web/tool_proposal_presenter_test.exs
                                  → 53 tests, 0 failures, 0 skipped
mix test test/cairnloop/web/conversation_live_test.exs
                                  → 55 tests, 0 failures
mix test test/cairnloop/governance/ test/cairnloop/workers/
      test/cairnloop/governance_test.exs
      test/cairnloop/web/tool_proposal_presenter_test.exs
      test/cairnloop/web/conversation_live_test.exs
                                  → 258 tests, 0 failures
No remaining @tag :skip in Phase-15 test files   → confirmed
No Preview.render calls in conversation_live.ex   → confirmed (0 occurrences)
No streams in conversation_live.ex                → confirmed (0 occurrences)
No .run( in approve_action handler                → confirmed (0 occurrences)
rendered_consequence in card precompute           → confirmed (3 occurrences)
Governance.approve/reject/defer in handlers       → confirmed (3 occurrences)
Chimeway.Repo boot noise                          → pre-existing baseline (not a regression)
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Preview.render/1 still called in Phase 14 pre-Phase-15-row fallback**
- **Found during:** Task 2 acceptance criterion check — `grep -c "Preview.render"` returned 2 (in comments) then 5 when the fallback code was included
- **Issue:** Plan acceptance criterion says `grep -c "Preview.render" returns 0`; keeping a live `Preview.render/1` call even in a fallback path violates D15-14
- **Fix:** Replaced the live `Preview.render/1` fallback with a pure static fallback using the humanized `tool_ref` display name (P14 D-17 structured-summary card intent); removed the `Preview` alias entirely
- **Files modified:** `lib/cairnloop/web/conversation_live.ex`
- **Commit:** 2fd731d

**2. [Rule 2 - Missing critical functionality] Handler event names: approve_action/reject_action/defer_action**
- **Found during:** Task 2 implementation — `approve` event name would conflict with the existing `approve_draft` handler match pattern
- **Fix:** Used `approve_action`/`reject_action`/`defer_action` event names to avoid ambiguity; footer template updated accordingly
- **Files modified:** `lib/cairnloop/web/conversation_live.ex`, `test/cairnloop/web/conversation_live_test.exs`
- **Commit:** 2fd731d

## Known Stubs

None — all approval display paths are functional. The footer slot only renders when `active_approval.status == :pending`; proposals without an active approval show the existing approval_outlook honesty seam or nil.

## Threat Flags

All STRIDE threats from this plan's threat model are mitigated:
- **T-15-15 (T-inline-exec):** `approve_action` handler calls `Governance.approve/3` (persist + enqueue) then reloads; zero `run/3` calls in any approval handler; source-asserted by test.
- **T-15-16 (T-trust-drift):** Card reads snapshotted `proposal.title` / `proposal.rendered_consequence`; no `Preview.render/1` calls remain in `conversation_live.ex`; source-asserted by test.
- **T-15-17 (T-raw-terms):** All approval copy runs through `approval_outlook_for_approval/1` and `history_line/1`; 0 raw Elixir terms; presenter test suite asserts no `#Ecto`/`%{`/colon-prefix in output.
- **T-15-18 (T-color-alone):** Status conveyed by text label AND color chip; brand token `var(--cl-primary)` used; source-asserted by test.
- **T-15-19 (T-reason-required):** `reject_action`/`defer_action` pass `reason:` to facade; facade enforces via `decision_changeset/6`; handlers surface calm "A reason is required" error; FLOW-03 asserted by test.
- **T-15-SC:** No package installs in Phase 15.

## Self-Check: PASSED
