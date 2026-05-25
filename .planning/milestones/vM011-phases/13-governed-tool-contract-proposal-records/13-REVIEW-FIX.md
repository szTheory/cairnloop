---
phase: 13-governed-tool-contract-proposal-records
fixed_at: 2026-05-23T23:28:00Z
review_path: .planning/phases/13-governed-tool-contract-proposal-records/13-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 13: Code Review Fix Report

**Fixed at:** 2026-05-23T23:28:00Z
**Source review:** .planning/phases/13-governed-tool-contract-proposal-records/13-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 8 (CR-01, CR-02, WR-01, WR-02, WR-03, WR-04, WR-06, IN-01)
- Fixed: 8
- Skipped: 0

Out of scope (per objective): WR-05, IN-04, IN-02 (addressed implicitly by CR-02), IN-03 (low-risk, no separate work needed).

## Fixed Issues

### CR-01: `failure_reason_message/2` crashes on scope_invalid / policy_denied

**Files modified:** `lib/cairnloop/web/conversation_live.ex`
**Commit:** `2f47406`
**Applied fix:** Changed `"#{reason}"` interpolation in `:scope_invalid` and `:policy_denied` clauses to `"#{inspect(reason)}"`. `inspect/1` never raises regardless of the value's type, so the `{:missing_scopes, [...]}` tuple returned by `check_scope/2` no longer triggers `Protocol.UndefinedError`.

---

### CR-02 + WR-06: Blocked-proposal persistence silently swallows insert failures; missing pre-check

**Files modified:** `lib/cairnloop/governance.ex`
**Commit:** `9acf92f`
**Applied fix:**
- Extracted `insert_blocked_proposal/10` from `propose_blocked/5` to hold the `with/else` pipeline.
- Added `else` clause to the `with` pipeline with unique-constraint recovery (mirroring `insert_new_proposal/5`).
- Added `get_by(ToolProposal, idempotency_key: key)` pre-check before insert in `propose_blocked/5` (mirrors `propose_valid/4` defense-in-depth).
- Updated `propose/3` to thread `propose_blocked/5`'s return — `{:error, cs}` is now surfaced instead of discarded.
- Telemetry is emitted on the duplicate path (`:proposal_duplicate`) in both the pre-check and the constraint recovery.

---

### WR-01: Idempotency key input derivation differs between valid and blocked paths

**Files modified:** `lib/cairnloop/governance.ex`
**Commit:** `9acf92f`
**Applied fix:** In `propose_blocked/5`, replaced raw `Map.get(context, :tool_params, %{})` with a full changeset run (`tool_module.changeset(struct(...), raw_params) |> Ecto.Changeset.apply_changes() |> Map.from_struct()`). This normalizes atom/string key shapes identically to the `propose_valid/4` path, so the same logical call produces the same idempotency key regardless of which code path is taken.

---

### WR-02: `derive_idempotency_key/4` only sorts top-level keys

**Files modified:** `lib/cairnloop/governance.ex`
**Commit:** `9acf92f`
**Applied fix:** Added `deep_sort_map/1` private helper that recursively sorts map keys at every nesting level using `to_string/1` for consistent comparison. Replaced the inline `Map.to_list() |> Enum.sort() |> Map.new()` with `deep_sort_map(input_snapshot)` so nested maps hash deterministically.

---

### WR-03: `propose_blocked/5` re-implements tool resolution inline

**Files modified:** `lib/cairnloop/governance.ex`
**Commit:** `9acf92f`
**Applied fix:** Replaced the inline `Enum.find(fn mod -> Atom.to_string(mod) == tool_ref end)` with `Cairnloop.ToolRegistry.find_tool_module(tool_ref)` — the single source of truth. Pattern-matched `{:ok, tool_module}` directly; gate 0 guarantees resolution succeeds before `propose_blocked/5` is reached.

---

### WR-04: Dead `{:unknown, :always_block}` branch produces invalid enum value

**Files modified:** `lib/cairnloop/governance.ex`
**Commit:** `9acf92f`
**Applied fix:** Removed the dead `if tool_module do … else {:unknown, :always_block} end` branch entirely. The WR-03 fix (registry call with pattern-matched `{:ok, tool_module}`) makes the else branch unreachable and having it fabricate `:unknown` (not in `@risk_tier_values`) was a latent data-integrity bug.

---

### IN-01: No coverage for `:scope_invalid` / `:policy_denied` LiveView flash paths + blocked dedupe

**Files modified:** `test/cairnloop/web/conversation_live_test.exs`, `test/cairnloop/governance_test.exs`
**Commit:** `c89dac9`
**Applied fix:**

*conversation_live_test.exs:*
- Added `ScopeTool` fixture (requires `:admin_scope`, `authorize/2` returns `:ok`).
- Added `PolicyTool` fixture (`authorize/2` returns `{:error, {:policy_violation, :high_risk_denied}}` — a tuple).
- Added test: `handle_event execute_tool shows scope_invalid flash without crashing` — asserts flash contains "Tool not available in this context" and does not crash.
- Added test: `handle_event execute_tool shows policy_denied flash without crashing` — asserts flash contains "Tool call not permitted" and does not crash.

*governance_test.exs:*
- Added test: `repeated blocked submission dedupes via idempotency key` — calls `propose/3` twice with identical scope-failing context, asserts only 1 proposal row is inserted (CR-02/WR-06 regression guard).
- Added test: `deep-canonicalized input hashes identically regardless of nested map key order` — submits atom-key and string-key versions of the same params, asserts both proposals share the same id after deduplication (WR-01/WR-02 regression guard).

## Skipped Issues

None.

---

## Verification

- `mix compile --warnings-as-errors`: clean (no new warnings).
- `mix test`: 1 doctest, 303 tests, **1 failure** — the pre-existing `Cairnloop.Automation.DraftTest: changeset/2 requires content, status, and conversation_id` (test/cairnloop/automation/draft_test.exs:6). All new and existing tests pass.

---

_Fixed: 2026-05-23T23:28:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
