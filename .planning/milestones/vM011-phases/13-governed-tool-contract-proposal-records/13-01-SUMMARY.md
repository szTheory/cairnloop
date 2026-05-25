---
phase: 13-governed-tool-contract-proposal-records
plan: "01"
subsystem: tool-contract
tags: [governed-tool, compile-time-validation, spec-struct, deny-by-default, fail-closed]
dependency_graph:
  requires: []
  provides:
    - Cairnloop.Tool.Spec — pure data struct, MCP-01 projection point
    - Cairnloop.Tool — governed-tool behaviour with compile-time enum validation
    - Cairnloop.ToolRegistry — updated registry with scope/authorize-based filtering
  affects:
    - All future governed tools via use Cairnloop.Tool
    - Phase 14 (preview/1 seam), Phase 15 (authorize/2 policy seam), Phase 16 (run/3 execution), Phase 17 (Spec MCP projection)
tech_stack:
  added: []
  patterns:
    - Oban.Worker declarative-opts __using__ macro pattern (compile-time data + behaviour callbacks + introspection accessor)
    - CompileError raised inside defmacro body before quote do (compile-time enum validation)
    - Plain defstruct as pure data carrier (no Ecto.Schema, no behaviour)
key_files:
  created:
    - lib/cairnloop/tool/spec.ex
  modified:
    - lib/cairnloop/tool.ex
    - lib/cairnloop/tool_registry.ex
    - test/cairnloop/tool_test.exs
    - test/cairnloop/tool_registry_test.exs
decisions:
  - "D-01: Evolved Cairnloop.Tool in place — one governed contract, no parallel GovernedTool"
  - "D-02: CompileError raised before quote do in __using__ for enum validation at build time"
  - "D-03: Cairnloop.Tool.Spec is plain defstruct — no Ecto.Schema, pure data for MCP-01 projection"
  - "D-04: changeset/2 kept as required host-owned callback; no default injected"
  - "D-05: execute/3 renamed run/3; NOT called in Phase 13"
  - "D-06: can_execute?/2 removed; scope/0 + authorize/2 replace it; preview/1 optional"
  - "D-09/D-10: @valid_risk_tiers [:read_only,:low_write,:high_write,:destructive], @valid_approval_modes [:auto,:requires_approval,:always_block]"
  - "D-11: derive_approval_mode/1 fail-closed: read_only->:auto, low_write|high_write->:requires_approval, destructive->:always_block, unknown->:always_block"
  - "D-16: authorize/2 default returns {:error, :no_policy_defined} — deny-by-default"
  - "D-19: ToolRegistry.find_tool_module/1 uses Atom.to_string comparison, never String.to_existing_atom"
  - "D-28: get_available_tools/2 updated to scope/0 + authorize/2 (advisory UX only)"
metrics:
  duration_minutes: 4
  completed_date: "2026-05-23"
  tasks_completed: 3
  files_changed: 5
---

# Phase 13 Plan 01: Governed Tool Contract (Spec + Behaviour + Tests) Summary

**One-liner:** Compile-time-validating `use Cairnloop.Tool, risk_tier: ...` macro with fail-closed enum validation, deny-by-default `authorize/2`, pure `%Cairnloop.Tool.Spec{}` data struct, and TOOL-01 contract test suite covering D-02/D-03/D-11/D-16.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Create pure Cairnloop.Tool.Spec data struct | f5fcb90 | lib/cairnloop/tool/spec.ex |
| 2 | Evolve Cairnloop.Tool behaviour + compile-time macro + ToolRegistry cutover | ae2efcb | lib/cairnloop/tool.ex, lib/cairnloop/tool_registry.ex |
| 3 | Write TOOL-01 contract tests | e95c536 | test/cairnloop/tool_test.exs, test/cairnloop/tool_registry_test.exs |

## What Was Built

### `lib/cairnloop/tool/spec.ex` (new)

Pure `defstruct` carrying compile-time governed-tool metadata. Six fields:
`risk_tier`, `approval_mode`, `idempotency`, `result_states`, `title`, `description`.
`@enforce_keys [:risk_tier, :approval_mode]`. No `use Ecto.Schema`, no behaviour, no DB.
Phase 17 projects this directly to an MCP `{name, title, description, inputSchema, outputSchema}` definition.

### `lib/cairnloop/tool.ex` (evolved in place)

- **Removed:** `@callback can_execute?/2` (D-06)
- **Renamed:** `@callback execute/3` → `@callback run/3` (D-05; NOT called in Phase 13)
- **Kept:** `@callback changeset/2` as required host-owned callback — no default injected (D-04)
- **Added:** `@callback scope/0`, `@callback authorize/2`, `@callback preview/1` (optional, Phase 14 seam)
- **Added:** `@optional_callbacks [preview: 1, custom_ui: 0]`
- **Added:** `@valid_risk_tiers` and `@valid_approval_modes` module attributes
- **Rewritten:** `defmacro __using__(opts)` — validates enums BEFORE `quote do`, derives fail-closed `approval_mode`, generates `__tool_spec__/0`, injects deny-by-default `authorize/2`
- **Added:** `def derive_approval_mode/1` — plain def callable at macro-expansion time (D-11 fail-closed)

### `lib/cairnloop/tool_registry.ex` (evolved in place)

- `get_available_tools/2`: replaced `can_execute?/2` filter with `scope/0` + `authorize/2` (D-28)
- `find_tool_module/1`: resolves string tool_ref via `Atom.to_string` comparison, no `String.to_existing_atom` (D-19)
- `validate_configured_tools!/0`: boot-time validation that each declared tool has `__tool_spec__/0` returning `%Cairnloop.Tool.Spec{}` (D-07)

### `test/cairnloop/tool_test.exs` (replaced)

19 tests covering all four TOOL-01 validation rows:
- **D-02:** `assert_raise CompileError` via `Code.compile_string/1` for bad `risk_tier` and bad `approval_mode`
- **D-03:** `__tool_spec__/0` returns `%Cairnloop.Tool.Spec{}` with frozen declared fields; Spec is not an Ecto schema
- **D-16:** default `authorize/2` returns `{:error, :no_policy_defined}`; overridden `authorize/2` can return `:ok`
- **D-11:** `derive_approval_mode/1` across all four tiers + unknown/nil fail-closed; spec.approval_mode derived correctly

### `test/cairnloop/tool_registry_test.exs` (updated)

Updated from old `can_execute?/2` model to `scope/0` + `authorize/2`. Added `find_tool_module/1` and `validate_configured_tools!/0` tests. 5 tests, all passing.

## Verification

- `mix compile` succeeds — no warnings beyond pre-existing Chimeway.Repo noise
- `mix test test/cairnloop/tool_test.exs` — 19 tests, 0 failures
- `mix test test/cairnloop/tool_registry_test.exs` — 5 tests, 0 failures
- Source assertions all pass (can_execute: 0, @callback run: 1, @callback changeset: 1, no_policy_defined: 4)
- Spec file: defstruct: 2 occurrences, use Ecto.Schema: 0

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated ToolRegistry to remove can_execute?/2 call**
- **Found during:** Task 2 (after removing callback from behaviour)
- **Issue:** `lib/cairnloop/tool_registry.ex` still called `tool_module.can_execute?(actor_id, context)` which was removed from the governed-tool contract.
- **Fix:** Updated `get_available_tools/2` to use `scope/0` + `authorize/2` per D-28; added `find_tool_module/1` (D-19) and `validate_configured_tools!/0` (D-07) per PATTERNS.md cutover shape.
- **Files modified:** `lib/cairnloop/tool_registry.ex`
- **Commit:** ae2efcb

**2. [Rule 1 - Bug] Updated tool_registry_test.exs to match evolved ToolRegistry**
- **Found during:** Task 3
- **Issue:** `test/cairnloop/tool_registry_test.exs` used removed `can_execute?/2` and `execute/3` callbacks in test tool modules, and tested the old `get_available_tools/2` can_execute? filtering.
- **Fix:** Rewrote test tools to implement `scope/0`, `run/3`, and (optionally) `authorize/2`. Updated tests to verify `scope/0` + `authorize/2` advisory filtering, `find_tool_module/1`, and `validate_configured_tools!/0`.
- **Files modified:** `test/cairnloop/tool_registry_test.exs`
- **Commit:** e95c536

## Known Stubs

None — all fields and functions are fully implemented. The `derive_approval_mode/1` catch-all clause (`_ -> :always_block`) is intentional fail-closed behavior per D-11, not a stub.

## Threat Flags

No new threat surface introduced. STRIDE threats T-13-01 through T-13-03 are mitigated:
- T-13-01: `CompileError` raised before `quote do` for invalid enum values (build-time gate)
- T-13-02: Default `authorize/2` returns `{:error, :no_policy_defined}` (deny-by-default)
- T-13-03: `derive_approval_mode/1` returns `:always_block` for unknown/nil tier (fail-closed)
- T-13-04: Accepted as-is — Spec is intentionally serializable for MCP-01

## Self-Check: PASSED

Files exist:
- lib/cairnloop/tool/spec.ex: FOUND
- lib/cairnloop/tool.ex: FOUND (evolved in place)
- lib/cairnloop/tool_registry.ex: FOUND (evolved in place)
- test/cairnloop/tool_test.exs: FOUND
- test/cairnloop/tool_registry_test.exs: FOUND

Commits exist:
- f5fcb90: Task 1 — Cairnloop.Tool.Spec struct
- ae2efcb: Task 2 — Evolved Cairnloop.Tool + ToolRegistry
- e95c536: Task 3 — TOOL-01 contract tests
