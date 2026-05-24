---
phase: 14-operator-timeline-preview-surface
fixed_at: 2026-05-24T14:45:00Z
review_path: .planning/phases/14-operator-timeline-preview-surface/14-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 14: Code Review Fix Report

**Fixed at:** 2026-05-24T14:45:00Z
**Source review:** .planning/phases/14-operator-timeline-preview-surface/14-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6 (CR-01, WR-02, WR-03, WR-04, WR-05, WR-06)
- Fixed: 6
- Skipped: 0

**Out of scope (per instructions):** WR-01, IN-01, IN-02, IN-03, IN-04 — not touched.

**Build verification:** `MIX_ENV=test mix compile --warnings-as-errors` exits 0 (clean).
**Test verification:** `mix test` — 1 doctest + 367 tests, **1 failure** (pre-existing baseline `Cairnloop.Automation.DraftTest` only; no new failures introduced).

## Fixed Issues

### CR-01: `execute_tool` handler has no clause for `{:error, changeset}` — crashes LiveView on insert failure

**Files modified:** `lib/cairnloop/web/conversation_live.ex`, `test/cairnloop/web/conversation_live_test.exs`
**Commit:** `678457c`
**Applied fix:**
Added `{:error, _changeset}` clause to the `case Cairnloop.Governance.propose(...)` expression in `execute_tool/3`. The clause fails closed with a calm, reason-forward flash message: "This action could not be recorded right now. Please try again." — no raw changeset, no inspect output, no CaseClauseError.

Also added regression test `"handle_event execute_tool emits calm error flash on {:error, changeset} without crashing (CR-01 regression)"` in the "tools rendering and execution" describe block. The test uses a `Process.put(:force_insert_error, true)` hook added to `MockRepo.insert/1` to force `{:error, changeset}` return for that test. Asserts the flash message contains "could not be recorded" and does NOT contain "Ecto.Changeset" or "#Ecto".

---

### WR-02: Test-suite compilation emits `@impl` warnings — violates mandatory warnings-clean build

**Files modified:** `test/cairnloop/governance_test.exs`
**Commit:** `7355c36`
**Applied fix:**
Added `@impl Cairnloop.Tool` before each behaviour callback (`changeset/2`, `run/3`, `scope/0`, and `authorize/2`) in all four test tool fixtures: `ValidTool`, `ScopeFailingTool`, `PolicyDenyingTool`, `InvalidInputTool`. This mirrors the `conversation_live_test.exs` fixture pattern. All four tools already had `@impl` on `authorize/2`; the remaining three callbacks were missing annotations.

---

### WR-03: Unused default argument warning on `tool_proposal_fixture/1`

**Files modified:** `test/cairnloop/web/conversation_live_test.exs`
**Commit:** `588f16e`
**Applied fix:**
Changed `defp tool_proposal_fixture(overrides \\ %{}) do` to `defp tool_proposal_fixture(overrides) do`. Every existing caller already passes an explicit map argument, so the default was dead code producing a compile warning.

---

### WR-04: `event.metadata` truthiness always opens the per-event "Details" expander

**Files modified:** `lib/cairnloop/web/conversation_live.ex`
**Commit:** `3fb9a1d`
**Applied fix:**
Changed the outer guard from `if event.reason || event.metadata` to `if event.reason || (is_map(event.metadata) and map_size(event.metadata) > 0)`. Changed the inner metadata `<pre>` block guard from `if event.metadata` to `if is_map(event.metadata) and map_size(event.metadata) > 0`. An empty `%{}` is now correctly treated as "no detail to show" — the Details expander is suppressed and the empty `inspect(%{})` output never renders.

---

### WR-05: `metadata_value/2` uses `||` and will treat a stored `false` value as missing

**Files modified:** `lib/cairnloop/web/tool_proposal_presenter.ex`
**Commit:** `a96fe06`
**Applied fix:**
Replaced `Map.get(map, key) || Map.get(map, Atom.to_string(key))` with an explicit `Map.fetch/2` presence check:
```elixir
case Map.fetch(map, key) do
  {:ok, value} -> value
  :error -> Map.get(map, Atom.to_string(key))
end
```
A stored `false` atom-key value is now correctly returned instead of being discarded as falsy.

---

### WR-06: `humanize_label/1` can emit an empty headline/title for a trailing-dot or empty tool_ref segment

**Files modified:** `lib/cairnloop/governance/preview.ex`
**Commit:** `bf44f62`
**Applied fix:**
Added `defp humanize_label(""), do: "Unknown tool"` clause between the existing `nil` clause and the general clause. A malformed `tool_ref` ending in `"."` now resolves to `"Unknown tool"` rather than an empty headline string.

---

## Skipped Issues

None.

---

_Fixed: 2026-05-24T14:45:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
