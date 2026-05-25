---
phase: 14
plan: "00"
subsystem: test-infrastructure
tags: [wave-0, nyquist, governance, preview, presenter, tdd, test-only]
dependency_graph:
  requires: []
  provides:
    - test/cairnloop/governance/preview_test.exs
    - test/cairnloop/web/tool_proposal_presenter_test.exs
    - test/cairnloop/governance_test.exs (extended)
    - test/cairnloop/web/conversation_live_test.exs (extended)
  affects:
    - Wave 1 (14-01): implements Cairnloop.Governance.Preview + ToolProposalPresenter + list_proposals_for_conversation/1
    - Wave 2 (14-02): implements governed_action_card/1 component
    - Wave 3 (14-03): implements conversation_id threading + failure_reason_message humanization
tech_stack:
  added: []
  patterns:
    - Wave-0 Nyquist test-first: all tests @tag :skip or live (for D-08 exclusion); modules referenced via runtime aliases / Function.capture
    - Inline fixture helpers (no shared factory — repo idiom)
    - Source-assertion pattern (existing conversation_live_test idiom)
key_files:
  created:
    - test/cairnloop/governance/preview_test.exs
    - test/cairnloop/web/tool_proposal_presenter_test.exs
  modified:
    - test/cairnloop/governance_test.exs
    - test/cairnloop/web/conversation_live_test.exs
decisions:
  - Wave 0 tests reference undefined modules via @preview_module / @presenter module attributes and Function.capture (runtime dispatch) — never compile-time macro expansion — so --warnings-as-errors stays clean (T-14-W0-01)
  - D-08 idempotency exclusion tests (conversation_id excluded from canonical map) run live NOW because derive_idempotency_key/4 already ignores unknown context keys; these are the only non-skipped new tests
  - failure_reason_message/1 source assertion documents current inspect(reason) state so Wave 3 can invert it when D-14 humanization lands
  - Function.capture used for governed_action_card/1 references in @tag :skip tests to avoid compile-time undefined-function warnings (T-14-W0-01 mitigation)
metrics:
  duration: "~6 min"
  completed: "2026-05-24T12:00:03Z"
  tasks_completed: 2
  files_created: 2
  files_modified: 2
---

# Phase 14 Plan 00: Wave 0 Nyquist Test Infrastructure Summary

Wave 0 test scaffold for the Phase 14 operator-timeline-preview surface: two new headless
test files and two extended test files, compiling warnings-clean with 59 tests skipped and 2
live D-08 idempotency-exclusion tests passing.

## What Was Built

### Task 1: New headless test files

**`test/cairnloop/governance/preview_test.exs`** — behavior contract for
`Cairnloop.Governance.Preview.render/1` (module does not exist until Wave 1). Covers:
- Common path: tool without `preview/1` returns `{:structured, _}` (D-17)
- Fallback when tool is unregistered (D-19 footgun 4)
- Fallback when `preview/1` raises (D-19 try/rescue)
- Fallback when `preview/1` returns non-string (D-19)
- String-keyed `input_snapshot` variant (`%{"order_id" => "123"}`) — partial JSONB
  round-trip simulation with `# REPO-UNAVAILABLE` comment (D-19 footgun 1)

All tests `@tag :skip`; module referenced via `@preview_module` runtime attribute.

**`test/cairnloop/web/tool_proposal_presenter_test.exs`** — behavior contract for
`Cairnloop.Web.ToolProposalPresenter` (module does not exist until Wave 1). One describe
block per D-25 total function: `status_label`, `status_group`, `status_group_label`,
`approval_outlook`, `risk_tier_label`, `risk_tier_tone`, `approval_mode_label`,
`reason_label`, `input_rows`, `scope_summary`, `policy_explanation`, `block_reason_copy`,
`history_line`, `event_timestamp_label`, `trace_metadata`, `status_meaning`.

Key assertions:
- `reason_label({:missing_scopes, [:admin_scope]})` produces NO raw `:missing_scopes` /
  `[:admin_scope]` output (D-14 / brand §5.6)
- `input_rows/1` with nested map/tuple returns humanized rows or "Unsupported value",
  never raw nested structure (D-22 masking choke point)
- `approval_outlook/1` returns future-tense sentence for `:requires_approval`, nil for
  `:auto`, "cannot be approved or run" sentence for `:always_block` (D-12)
- `history_line/1` catch-all returns a non-empty string (D-24 forward-compat)

All tests `@tag :skip`; module referenced via `@presenter` runtime attribute.

### Task 2: Extended existing test files

**`test/cairnloop/governance_test.exs`** — three new describe blocks appended:
1. `list_proposals_for_conversation/1` ordered+preloaded proposals (3 tests `@tag :skip`, Wave 1)
2. `conversation_id` written on valid AND blocked paths (2 tests `@tag :skip`, Wave 1)
3. `conversation_id` excluded from idempotency key (D-08) — **2 live tests that pass now**,
   verifying `derive_idempotency_key/4` canonical map already excludes `conversation_id`

**`test/cairnloop/web/conversation_live_test.exs`** — five additions:
1. `tool_proposal_fixture/1` inline helper for `%ToolProposal{}` structs
2. `governed_action_card/1` rendering describe block (6 tests `@tag :skip`, Wave 2) using
   `Function.capture/3` for runtime dispatch — avoids compile-time warnings (T-14-W0-01)
3. MockRepo governed_actions load path contract (1 test `@tag :skip`, Wave 1)
4. Blocked proposals visible in rail (3 tests `@tag :skip`, Wave 3, Support-Truth Gate)
5. Source assertion: `failure_reason_message/1` uses `inspect(reason)` in current source —
   documents D-14 pre-state; Wave 3 inverts this assertion when humanization lands

## Test Results

```
mix compile --warnings-as-errors: CLEAN (no warnings from new code)
mix test (four files): 114 tests, 0 failures, 59 skipped
mix test (full suite): 1 doctest, 366 tests, 1 failure (pre-existing DraftTest baseline), 59 skipped
```

Pre-existing baseline:
- 1 failure: `Cairnloop.Automation.DraftTest` "changeset/2 requires content, status, and conversation_id" — NOT introduced by this plan
- Pre-existing `@impl` warnings on inline test-tool modules in `governance_test.exs` — baseline, NOT introduced by this plan
- `Chimeway.Repo` Postgrex "missing the :database key" boot noise — expected (Repo unavailable)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Compile warnings from function helper default values**
- **Found during:** Task 1 verification
- **Issue:** `defp proposal(overrides \\ %{})` and `defp event(overrides \\ %{})` produced "default values for optional arguments are never used" warnings, breaking `--warnings-as-errors`
- **Fix:** Removed default values; all callers already pass explicit `%{}` or override maps
- **Files modified:** `test/cairnloop/web/tool_proposal_presenter_test.exs`
- **Commit:** d1a5fa1

**2. [Rule 1 - Bug] Compile warnings from `governed_action_card/1` function captures**
- **Found during:** Task 2 verification
- **Issue:** `&ConversationLive.governed_action_card/1` in `@tag :skip` tests still generated compile-time "undefined or private" warnings, breaking `--warnings-as-errors`; T-14-W0-01 explicitly prohibits compile-time references to undefined functions
- **Fix:** Replaced function captures with `Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)` — resolved at runtime, not compile time
- **Files modified:** `test/cairnloop/web/conversation_live_test.exs`
- **Commit:** 821cc8c

## Known Stubs

None — this plan creates test files only; no implementation stubs.

## Threat Flags

None — Wave 0 is test-only. No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `test/cairnloop/governance/preview_test.exs` exists: YES
- `test/cairnloop/web/tool_proposal_presenter_test.exs` exists: YES
- `test/cairnloop/governance_test.exs` contains `list_proposals_for_conversation`: YES (6 matches)
- `test/cairnloop/web/conversation_live_test.exs` contains `governed_action`: YES (15 matches)
- Commits exist:
  - d1a5fa1: test(14-00): add Wave 0 headless Preview.render/1 and ToolProposalPresenter test files
  - 821cc8c: test(14-00): extend governance_test and conversation_live_test with governed-action contracts
- `mix compile --warnings-as-errors`: CLEAN
- `mix test` full suite: 1 failure (pre-existing baseline only), 59 skipped
