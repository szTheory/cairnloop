---
phase: 14
plan: "02"
subsystem: governance-card-component
tags: [wave-2, governance, component, liveview, presenter, preview, read-only-card]
dependency_graph:
  requires:
    - 14-01 (ToolProposalPresenter + Preview.render/1)
    - 14-00 (Wave-0 test contracts — row 14-02-a)
  provides:
    - lib/cairnloop/web/conversation_live.ex (governed_action_card/1 function component)
  affects:
    - Wave 3 (14-03): rail-wiring wires governed_action_card/1 into the evidence rail section
    - Phase 15: footer action slot receives approve/reject/defer buttons (D-05)
tech_stack:
  added: []
  patterns:
    - Function component (not LiveComponent) — stateless render of immutable snapshot data (D-03)
    - Precompute presenter values into assigns before ~H block (in-repo pattern)
    - Ecto.assoc_loaded? guard for event trail (D-24 — empty/not-loaded → calm "No history yet")
    - HEEx <%!-- --%> comments (<%# is deprecated/warns in --warnings-as-errors)
    - Risk tone atom (:info/:warning/:danger) → CSS class modifier in LiveView (brand §7.5)
    - Raw snapshot maps behind <details> expanders (D-22 — inline humanized, raw opt-in)
    - Brand tokens (var(--cl-primary, #A94F30)) — no new hardcoded SaaS hex
key_files:
  created: []
  modified:
    - lib/cairnloop/web/conversation_live.ex
    - test/cairnloop/web/conversation_live_test.exs
decisions:
  - D-03: Function component (not LiveComponent); parent LiveView owns all events
  - D-05: Footer action slot structurally present but empty in Phase 14 (read-only)
  - D-13: Risk tier / approval mode / status are separate display axes — never fused
  - D-15: Headline from Preview.render/1 — {:preview, str} labelled "current description"; {:structured, %{title:}} shows title
  - D-22: input_rows/1 is masking choke point; raw snapshot maps only behind explicit <details> expanders
  - D-24: Ecto.assoc_loaded? guard — empty or not-loaded events → "No history yet"
metrics:
  duration: "~3 min"
  completed: "2026-05-24T12:19:00Z"
  tasks_completed: 1
  files_created: 0
  files_modified: 2
---

# Phase 14 Plan 02: governed_action_card/1 Function Component Summary

Read-only `governed_action_card/1` function component rendering any of the four Phase-13 ToolProposal statuses via the Wave-1 ToolProposalPresenter + Preview.render/1, with separate risk/approval/status axes, humanized inline content, raw maps behind expanders, guarded event mini-timeline, and an empty Phase-15 footer slot.

## What Was Built

### Task 1: governed_action_card/1 function component

**`lib/cairnloop/web/conversation_live.ex`** (function component + CSS):

- Added `alias Cairnloop.Web.ToolProposalPresenter` and `alias Cairnloop.Governance.Preview`
- `governed_action_card/1` function component (declared with `attr :proposal, :map, required: true`):
  - Precomputes all presenter values into assigns before the `~H` block (in-repo pattern)
  - **Headline**: from `Preview.render/1` — `{:preview, str}` labelled "current description" (D-15); `{:structured, %{title:}}` shows title; never a raw module atom
  - **Status chip**: `ToolProposalPresenter.status_label/1` text + CSS class derived from `risk_tier_tone/1` atom (`:info`/`:warning`/`:danger`) — chip always contains text label, never color-alone (brand §7.5)
  - **Meta line**: `risk_tier_label/1` + `approval_mode_label/1` as SEPARATE axes from status chip (D-13)
  - **Approval outlook sub-line**: rendered only when non-nil; future-tense (D-12)
  - **Block reason copy**: rendered for `:scope_invalid` / `:policy_denied` via `block_reason_copy/1`
  - **Input snapshot**: rendered via `input_rows/1` masking choke point + `context_field/1` humanizer; raw `input_snapshot` ONLY behind `<details>` expander (D-22)
  - **Event mini-timeline**: `Ecto.assoc_loaded?/1` guard → "No history yet" when empty/not-loaded (D-24); loaded events use `history_line/1` + `event_timestamp_label/1`; per-event reason/metadata behind `<details>` expander
  - **Scope snapshot**: `scope_summary/1` calm sentence
  - **Policy snapshot**: `policy_explanation/1` calm sentence; raw policy map behind `<details>` expander (D-22)
  - **Trace metadata**: `trace_metadata/1` (proposal id, tool_ref, tool_version, idempotency key) in mono `<dl>`
  - **Footer action slot**: `<div class="governed-action-footer">` structurally present, empty (D-05 — Phase-15 affordance point)
- Added scoped CSS for `.governed-action-*` classes using brand tokens (`var(--cl-primary, #A94F30)`); no new hardcoded SaaS hex

**`test/cairnloop/web/conversation_live_test.exs`**:
- Removed `@tag :skip` from all 6 Wave-2 card-render tests in `describe "governed_action_card/1 — renders all four statuses without crashing (row 14-02-a)"`:
  - `:proposed` status renders "Proposed" chip text
  - `:needs_input` status renders "Needs input"
  - `:scope_invalid` status renders "Not available here"
  - `:policy_denied` status renders "Blocked by policy"
  - Empty events list renders "No history yet" (D-24)
  - `%Ecto.Association.NotLoaded{}` events renders "No history yet" (D-24 assoc_loaded? guard)
- Wave-3 rail-wiring tests remain `@tag :skip` (14-03-a/b/c)

## Test Results

```
mix compile --warnings-as-errors: CLEAN (exit 0)
mix test test/cairnloop/web/conversation_live_test.exs: 43 tests, 0 failures, 4 skipped
mix test (full suite): 1 doctest, 366 tests, 1 failure (pre-existing DraftTest baseline), 4 skipped (Wave-3 rail tests)
```

Pre-existing baseline (UNCHANGED):
- 1 failure: `Cairnloop.Automation.DraftTest` — NOT introduced by this plan
- `Chimeway.Repo` Postgrex "missing the :database key" boot noise — expected (Repo unavailable)

Remaining 4 skipped (Wave-3 only):
- `conversation_live_test.exs`: blocked proposals in rail (3 tests) + MockRepo governed_actions load (1 test)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Deprecated <%# HEEx comment syntax**
- **Found during:** Task 1 — `mix compile --warnings-as-errors` failed on first compile
- **Issue:** `<%# comment %>` is deprecated in Phoenix HEEx; causes warnings-as-errors failure
- **Fix:** Replaced all `<%# ... %>` comments in the new component with `<%!-- ... --%>` (modern Phoenix HEEx comment syntax)
- **Files modified:** `lib/cairnloop/web/conversation_live.ex`
- **Commit:** 86d2ab0 (fixed inline before final commit)

## Known Stubs

None — all implemented functions return real values from Wave-1 presenter and snapshot data.

## Threat Flags

All T-14-02-xx threats mitigated as designed:
- T-14-02-01 (T-pii): `input_rows/1` is the ONLY inline render path for `input_snapshot`; raw snapshot behind `<details>` expander only (D-22)
- T-14-02-02: Headline from `Preview` fallback chain (never raw module atom); `reason_label/1` + `policy_explanation/1` humanize all shapes
- T-14-02-03: Footer slot is empty; no `phx-click` approve/reject/defer buttons rendered (D-05)
- T-14-02-04 (XSS): All prose rendered via standard HEEx interpolation (`<%= ... %>` — auto-HTML-escaped); no `raw/1` on host-supplied strings

## Self-Check: PASSED

- `lib/cairnloop/web/conversation_live.ex` modified: YES
- `test/cairnloop/web/conversation_live_test.exs` modified: YES
- `grep -c "def governed_action_card" lib/cairnloop/web/conversation_live.ex` = 1: YES
- `grep -c "ToolProposalPresenter\." lib/cairnloop/web/conversation_live.ex` = 14 (≥ 1): YES
- `grep -c "Preview.render" lib/cairnloop/web/conversation_live.ex` = 3 (≥ 1): YES
- `grep -c "use Phoenix.LiveComponent" lib/cairnloop/web/conversation_live.ex` = 0: YES
- No new `#2563eb` introduced (1 existing Execute-button instance from before Wave 2): YES
- Commit 86d2ab0 exists: YES
- `mix compile --warnings-as-errors`: CLEAN (exit 0)
- `mix test` full suite: 1 failure (pre-existing baseline only), 4 skipped (Wave-3)
