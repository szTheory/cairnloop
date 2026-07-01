---
phase: 41-conversation-rail-progressive-disclosure-d2
plan: "01"
subsystem: test-scaffold
tags: [tdd, red-scaffold, rail, disclosure, phase-41]
dependency_graph:
  requires: []
  provides: [phase-41-red-scaffold, rail-disclosure-test-spec]
  affects: [conversation_live_test, components_test]
tech_stack:
  added: []
  patterns: [runtime-dispatch-test, source-assertion-test, clause-head-allow-list]
key_files:
  created: []
  modified:
    - test/cairnloop/web/conversation_live_test.exs
    - test/cairnloop/web/components_test.exs
decisions:
  - "RAIL-01 test adds data-tier='2' presence assertion to make it RED (current markup lacks Tier-2 cl_disclosure groups)"
  - "D-08 negative test adds data-tier='2' presence assertion to make it RED (same reason)"
  - "D-09 test uses clause-head allow-list (Regex.scan over def handle_event clause heads) not DOTALL grep to avoid open_review_task/open_manual_draft false positives"
  - "Approval struct used: Cairnloop.Governance.ToolApproval (not a bare Approval alias)"
metrics:
  duration: "~10 minutes"
  completed: "2026-06-04"
  tasks_completed: 2
  files_modified: 2
---

# Phase 41 Plan 01: Wave 0 RED Test Scaffold Summary

Wave 0 RED scaffold: 7-test describe block for rail progressive disclosure + data-tier passthrough unit test, both failing RED by design against pre-Wave-1 markup.

## What Was Built

### Task 1: Phase 41 rail-disclosure describe block in conversation_live_test.exs

Added `describe "governed_action_card/1 — Phase 41 rail disclosure"` inside the existing `Cairnloop.Web.ConversationLiveTest` module (MockRepo wiring intact, no new defmodule). Seven tests covering:

1. **RAIL-01 Tier-1 isolation** (RED): Asserts `data-tier="2"` Tier-2 groups exist AND all `<details>` are closed before the `governed-action-footer` marker.
2. **RAIL-02 group structure** (RED): Asserts exactly 3 `data-tier="2"` occurrences, all three Tier-2 summaries ("Inputs & scope", "History", "Policy explanation"), Trace group present and NOT data-tier.
3. **RAIL-02 mechanism** (RED): Asserts `<details>` count == `phx-update="ignore"` count and count >= 4.
4. **D-08 positive** (RED): Asserts pending proposal opens the Inputs Tier-2 group; `policy_denied` opens both Inputs and Policy.
5. **D-08 negative** (RED): Asserts Tier-2 groups exist but none carry static `open` for non-pending/non-blocked proposals.
6. **D-09 render-purity** (GREEN — stays green): Clause-head allow-list mechanism; scans `def handle_event(...)` clause heads, allow-lists `open_review_task`/`open_manual_draft`; asserts no other disclosure-toggle event name exists. Companion: asserts no `open={@...}` bound to a non-static assign.
7. **RAIL-03 controls** (RED): Source assertion against `conversation_live.ex` for "Expand all", "Collapse all", `set_attribute({"open", ""}`, `remove_attribute("open"`, `to: "[data-tier='2']"`, `data-density="comfortable"`.

All tests use `Function.capture(Cairnloop.Web.ConversationLive, :governed_action_card, 1)` + `render_component/2` (DB-free) or `File.read!`. No `# REPO-UNAVAILABLE` markers. `Cairnloop.Governance.ToolApproval` struct used for the pending fixture override.

### Task 2: data-tier passthrough test in components_test.exs

Added one test to the existing `cl_disclosure` describe block asserting `data-tier="2"` reaches the rendered `<details>` element. Uses `rendered_to_string(~H"...")` idiom. RED now because `cl_disclosure/1` has no `attr(:rest, :global)` — the attribute is silently dropped. Turns GREEN when Wave 1 adds the `:global` passthrough. Existing open=true / open=false / token-pure tests unchanged and green.

## Test Results

```
mix compile --warnings-as-errors  →  exits 0 (runtime dispatch keeps build clean)

mix test test/cairnloop/web/conversation_live_test.exs test/cairnloop/web/components_test.exs
109 tests, 7 failures

Failures (all Phase-41 RED by design):
  - RAIL-01 Tier-1 isolation
  - RAIL-02 group structure
  - RAIL-02 mechanism
  - D-08 positive
  - D-08 negative
  - RAIL-03 controls
  - cl_disclosure data-tier passthrough

Green (correct):
  - D-09 render-purity (behavior 6) — GREEN now, stays GREEN
  - All 102 pre-existing tests — unchanged, green
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] RAIL-01 and D-08 negative accidentally passed against current codebase**

- **Found during:** Task 1 verification
- **Issue:** RAIL-01 footer-balance assertion passed trivially (current footer is already outside the current bespoke `<details>`). D-08 negative `refute data-tier="2"...\bopen\b` passed trivially (no `data-tier="2"` at all in current markup).
- **Fix:** Both tests now also assert `html =~ ~s(data-tier="2")` — the post-restructure requirement that Tier-2 cl_disclosure groups exist. This makes both RED until Wave 1 ships the groups.
- **Files modified:** `test/cairnloop/web/conversation_live_test.exs`
- **Commit:** 30f6161 (inline fix, same task commit)

## Known Stubs

None. This plan adds tests only; no runtime stubs introduced.

## Threat Flags

None. This plan adds tests only; no runtime trust boundary introduced or moved.

## Self-Check: PASSED

- `test/cairnloop/web/conversation_live_test.exs` — FOUND
- `test/cairnloop/web/components_test.exs` — FOUND (extended)
- Commit 30f6161 — FOUND (Task 1)
- Commit 5b09586 — FOUND (Task 2)
- `mix compile --warnings-as-errors` — exits 0
- D-09 render-purity test — GREEN
- 6 other Phase-41 tests — RED (failing assertions, not compile errors)
- Pre-existing tests — all green
