---
phase: 14
plan: "03"
subsystem: conversation-live-wiring
tags: [wave-3, governance, liveview, rail, conversation-id, presenter, brand-token, final-wave]
dependency_graph:
  requires:
    - 14-01 (list_proposals_for_conversation/1 + ToolProposalPresenter.reason_label/1)
    - 14-02 (governed_action_card/1 function component)
    - 14-00 (Wave-0 test contracts — rows 14-03-a/b/c)
  provides:
    - lib/cairnloop/web/conversation_live.ex (fully wired — conversation_id threading, governed_actions assign, rail section, Propose rename, reason_label)
  affects:
    - Phase 15: footer action slot in governed_action_card/1 receives approve/reject/defer buttons (D-05)
tech_stack:
  added: []
  patterns:
    - conversation_id threaded from server-trusted socket.assigns (D-07; NOT from request params)
    - ToolProposalPresenter.reason_label/1 replaces inspect(reason) in all three failure_reason_message/1 clauses (D-14)
    - Governance.list_proposals_for_conversation/1 via narrow facade, not direct schema query (D-09)
    - Plain-assign list-comprehension over @governed_actions — no Phoenix.LiveView.stream/3 (D-02)
    - Calm empty state ("No governed actions yet.") for empty governed_actions list
    - Map.put_new(:governed_actions, []) in render/1 for direct render_component tests (defensive default)
    - Brand token var(--cl-primary, #A94F30) replaces hardcoded #2563eb on submit button (D-04)
    - "Execute" → "Propose" rename on launcher button (D-04)
key_files:
  created: []
  modified:
    - lib/cairnloop/web/conversation_live.ex
    - test/cairnloop/web/conversation_live_test.exs
decisions:
  - D-07: conversation_id from socket.assigns.conversation.id (server-trusted), excluded from idempotency canonical map (D-08)
  - D-09: governed_actions loaded via Governance.list_proposals_for_conversation/1 in reload_conversation_with_context/2 (single reload seam)
  - D-14: All three inspect(reason) calls in failure_reason_message/1 replaced with ToolProposalPresenter.reason_label/1 — no raw Elixir terms to operator
  - D-02: Plain assign list-comprehension — bounded per-conversation list, full-reload PubSub pattern, no streams
  - D-01: Governed actions section in right evidence rail, not center message-timeline
  - D-04: Submit button text Execute → Propose; background #2563eb → var(--cl-primary, #A94F30)
  - Wave-3 D-14 source-assertion test inverted (refute inspect(reason) instead of assert)
metrics:
  duration: "~4 min"
  completed: "2026-05-24T12:26:00Z"
  tasks_completed: 2
  files_created: 0
  files_modified: 2
---

# Phase 14 Plan 03: ConversationLive Wire-up (Wave 3) Summary

conversation_id threaded into propose context via server-trusted socket assigns; governed_actions loaded + assigned via the narrow Governance facade; "Governed actions" right-rail section renders the per-conversation timeline via plain-assign list-comprehension of governed_action_card/1 with calm empty state; Execute → Propose rename + brand token applied; inspect(reason) eliminated from failure_reason_message/1 via ToolProposalPresenter.reason_label/1. FLOW-01 observable end to end.

## What Was Built

### Task 1: Thread conversation_id, humanize reasons, assign governed_actions, Propose rename

**`lib/cairnloop/web/conversation_live.ex`** (four touch points):

- **handle_event("execute_tool")**: added `context = Map.put(context, :conversation_id, socket.assigns.conversation.id)` before the `Governance.propose/3` call (D-07). Server-trusted — NOT sourced from request params.
- **failure_reason_message/1**: replaced all three `inspect(reason)` calls with `ToolProposalPresenter.reason_label(reason)` — `:scope_invalid` (L192), `:policy_denied` (L195), catch-all (L198). Zero `inspect(` remains in the function body (D-14 gate).
- **reload_conversation_with_context/2**: added `governed_actions = Cairnloop.Governance.list_proposals_for_conversation(conversation_id)` and `governed_actions: governed_actions` to the `assign/2` call. This is the single reload seam (mount + all handle_info/handle_event reloads).
- **tool_renderer/1**: submit button text `Execute` → `Propose`; `background: #2563eb` → `background: var(--cl-primary, #A94F30)` (D-04). Zero-field button unchanged (its label is the humanized tool name — no "Execute" text).
- **render/1**: added `assigns = Map.put_new(assigns, :governed_actions, [])` before the `~H` block as a defensive default for direct `render_component/2` tests that bypass `mount`.

**`test/cairnloop/web/conversation_live_test.exs`**:

- Removed `@tag :skip` from all 4 Wave-3 tests:
  - `"MockRepo governed_actions load path"` (1 test): verifies `MockRepo.all/1` returns a list (safe default)
  - `"governed_action rail — blocked proposals visible"` (3 tests): invoked `governed_action_card/1` via `Function.capture` + `render_component/2`; asserts `:needs_input` → "Needs input", `:scope_invalid` → "Not available here", `:policy_denied` → "Blocked by policy"
- Inverted the D-14 source-assertion test: `assert region =~ "inspect(reason)"` → `refute region =~ "inspect(reason)"` + `assert region =~ "reason_label"` (D-14 positive + negative gate)

### Task 2: "Governed actions" rail section

**`lib/cairnloop/web/conversation_live.ex`** (rail section + CSS):

- Added `<section class="rail-card governed-actions-rail">` as a sibling to `quick_fix_card` and drafts sections in the `.evidence-rail` div (NOT in `.message-timeline` — D-01; brand §10.2)
- Renders via `for proposal <- @governed_actions do <.governed_action_card proposal={proposal} /> end` — plain assign, no streams (D-02)
- Empty state: `<p class="governed-actions-empty">No governed actions yet.</p>` rendered when `@governed_actions == []` — calm, honest, brand voice; no crash, no empty section
- Section header: `<span class="governed-actions-rail-eyebrow">Governed actions</span>` consistent with other rail eyebrows
- Added scoped CSS for `.governed-actions-rail`, `.governed-actions-rail-header`, `.governed-actions-rail-eyebrow`, `.governed-actions-empty` — brand tokens only (`var(--cl-primary, #A94F30)`), no new hardcoded hex

## Test Results

```
mix compile --warnings-as-errors: CLEAN (exit 0)
mix test test/cairnloop/web/conversation_live_test.exs: 43 tests, 0 failures, 0 skipped
mix test (full suite): 1 doctest, 366 tests, 1 failure (pre-existing DraftTest baseline), 0 skipped
```

Pre-existing baseline (UNCHANGED):
- 1 failure: `Cairnloop.Automation.DraftTest` (test/cairnloop/automation/draft_test.exs:6) — NOT introduced by this plan
- `Chimeway.Repo` Postgrex "missing the :database key" boot noise — expected (Repo unavailable)

Phase-14 skip status: **0 remaining Phase-14 skips** (all 4 Wave-3 tests are now green)

## Deviations from Plan

### Auto-fixed Issues

None — plan executed as written. Four touch points applied cleanly in the order specified. The only notable implementation choice was the `Map.put_new(:governed_actions, [])` defensive default in `render/1`, which is implied by the existing `normalize_quick_fix_card` assign pattern (D-02 consistency) and required to keep existing direct-render tests working without modifying their assigns.

## Known Stubs

None — all implemented paths return real data:
- `governed_actions` is loaded from `Governance.list_proposals_for_conversation/1` on every reload
- `failure_reason_message/1` now uses `ToolProposalPresenter.reason_label/1` (real humanization)
- Empty state copy ("No governed actions yet.") is a real empty-list branch, not a placeholder

## Threat Flags

All T-14-03-xx threats mitigated as designed:
- T-14-03-01 (T-pii): `inspect(reason)` count = 0 in `failure_reason_message/1`; `reason_label/1` is the ONLY path for scope/policy reasons (D-14)
- T-14-03-02: `conversation_id` sourced from `socket.assigns.conversation.id` (server-trusted), NOT from request params; excluded from idempotency canonical map (D-08)
- T-14-03-03 (T-pii): Rail renders exclusively through `governed_action_card/1` component (Wave-2 masking choke point via `input_rows/1`); blocked proposals visible per Support-Truth Gate
- T-14-03-04: Bounded list (indexed `[conversation_id, inserted_at]`); no streams (D-02); plain assign reload path
- T-14-SC: No package installs

## Self-Check: PASSED

- `lib/cairnloop/web/conversation_live.ex` modified: YES
- `test/cairnloop/web/conversation_live_test.exs` modified: YES
- Commits:
  - d03c219: feat(14-03): thread conversation_id, humanize reason, assign governed_actions, Propose rename
  - 1d5bcd6: feat(14-03): add 'Governed actions' rail section with plain-assign list-comprehension
- `grep -c "conversation_id" lib/cairnloop/web/conversation_live.ex` = 7 (≥ 1): YES
- `awk '/defp failure_reason_message/,/^  defp [a-z]/' ... | grep -c "inspect("` = 0: YES
- `grep -c "governed_actions" lib/cairnloop/web/conversation_live.ex` = 5 (≥ 1): YES
- `grep -c "list_proposals_for_conversation" lib/cairnloop/web/conversation_live.ex` = 1 (≥ 1): YES
- `grep -c "Propose" lib/cairnloop/web/conversation_live.ex` = 2 (≥ 1): YES
- `grep -c "#2563eb" lib/cairnloop/web/conversation_live.ex` = 0: YES
- `grep -c "var(--cl-primary" lib/cairnloop/web/conversation_live.ex` = 2 (≥ 1): YES
- `grep -c "governed_action_card" lib/cairnloop/web/conversation_live.ex` = 2 (≥ 2: definition + render): YES
- `grep -c "stream(" lib/cairnloop/web/conversation_live.ex` = 0: YES
- `grep -c 'phx-update="stream"' lib/cairnloop/web/conversation_live.ex` = 0: YES
- `mix compile --warnings-as-errors`: CLEAN (exit 0)
- `mix test` full suite: 1 failure (pre-existing baseline only), 0 skipped
