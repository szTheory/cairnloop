---
phase: 13-governed-tool-contract-proposal-records
plan: "03"
subsystem: entrypoint-cutover
tags: [governance, entrypoint, proposal-first, fail-closed, boot-validation, D-19, D-27, D-28, TOOL-02]
dependency_graph:
  requires:
    - Cairnloop.Tool governed contract (13-01)
    - Cairnloop.ToolRegistry.find_tool_module/1 (13-01)
    - Cairnloop.Governance.propose/3 + validate/3 (13-02)
  provides:
    - Cairnloop.Application: boot-time validate_configured_tools!() call (D-07 fail-fast)
    - Cairnloop.Governance.validate/3 gate 0 delegates to ToolRegistry.find_tool_module/1 (D-19 single source of truth)
    - ConversationLive.handle_event("execute_tool"): proposal-first via Governance.propose/3 (D-27, TOOL-02)
    - failure_reason_message/2: bounded per-outcome flash messages (D-27)
    - conversation_live_test.exs: governed-contract fixture tools + proposal-first handler tests (TOOL-02)
  affects:
    - Phase 14 (proposal id in flash is the timeline card seam)
    - Phase 15 (validate/3 re-call contract unchanged; gate-0 delegation transparent)
tech_stack:
  added: []
  patterns:
    - Gate-0 delegation: governance.ex resolve_tool/1 -> ToolRegistry.find_tool_module/1 (single source of truth D-19)
    - Fail-fast boot validation: application.ex calls validate_configured_tools!() before Supervisor.start_link
    - Proposal-first handler: case Governance.propose/3 -> :info flash with id / :error flash with bounded reason
    - failure_reason_message/2: ordered clauses per outcome atom, operator-legible
    - MockRepo insert/1 + get_by/2: extended for Governance.propose/3 in-test flow
key_files:
  created: []
  modified:
    - lib/cairnloop/application.ex
    - lib/cairnloop/governance.ex
    - lib/cairnloop/web/conversation_live.ex
    - test/cairnloop/web/conversation_live_test.exs
decisions:
  - "D-07: validate_configured_tools!() called at application boot before Supervisor.start_link"
  - "D-19: Governance.validate/3 gate 0 now delegates to ToolRegistry.find_tool_module/1 — single source of truth, no duplicate Atom.to_string logic"
  - "D-27: execute_tool handler fully replaced with Governance.propose/3; no try/rescue, no run/3/execute/3, no can_execute?, no String.to_existing_atom"
  - "D-28: get_available_tools/2 call and template event 'execute_tool' left unchanged — advisory UX only"
  - "TOOL-02: failure_reason_message/2 provides bounded, distinct, operator-legible reasons per outcome atom"
metrics:
  duration_minutes: 11
  completed_date: "2026-05-23"
  tasks_completed: 3
  files_changed: 4
---

# Phase 13 Plan 03: Entrypoint Cutover (ConversationLive + Boot Wiring) Summary

**One-liner:** Proposal-first `execute_tool` handler via `Governance.propose/3` with per-outcome `failure_reason_message/2`, boot-time `validate_configured_tools!()` wiring in Application, and gate-0 delegation from `Governance.validate/3` to `ToolRegistry.find_tool_module/1` as single source of truth.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Wire boot validation + centralize gate-0 to ToolRegistry | aeddb41 | lib/cairnloop/application.ex, lib/cairnloop/governance.ex |
| 2 | Replace execute_tool handler + update test fixtures | ca491ed | lib/cairnloop/web/conversation_live.ex, test/cairnloop/web/conversation_live_test.exs |
| 3 | Full-suite green gate (compile + test verification) | (no new files — gate only) | — |

## What Was Built

### `lib/cairnloop/application.ex` (modified)

Added `Cairnloop.ToolRegistry.validate_configured_tools!()` call in `start/2` BEFORE `Supervisor.start_link/2` (D-07). A misconfigured/non-conforming tool now raises `ArgumentError` at boot, not at first user interaction. This is a one-line call that hooks into the boot-time fail-fast posture.

### `lib/cairnloop/governance.ex` (modified)

Replaced the private `resolve_tool/1` body (which duplicated the `Atom.to_string(mod) == tool_ref` logic from ToolRegistry) with a single delegation to `Cairnloop.ToolRegistry.find_tool_module/1`:

```elixir
defp resolve_tool(tool_ref) when is_binary(tool_ref) do
  Cairnloop.ToolRegistry.find_tool_module(tool_ref)
end
```

This makes `ToolRegistry.find_tool_module/1` the single source of truth for resolution (D-19). All 23 governance tests continue to pass unchanged — the `validate/3` pipeline is transparent to this refactor.

### `lib/cairnloop/web/conversation_live.ex` (modified)

**Replaced** the synchronous `execute_tool` handler entirely (D-27, TOOL-02):

- **Removed:** `String.to_existing_atom/1` tool resolution (D-19)
- **Removed:** `can_execute?/2` authorization branch (D-06)
- **Removed:** `try/rescue`-around-`execute/3` block (D-27, D-05)
- **Added:** `case Cairnloop.Governance.propose(tool_ref, actor_id, context)` as the sole entrypoint
- **Added:** `:info` flash `"Proposed — pending review. (##{proposal.id})"` on success — proposal id is the Phase 14 seam
- **Added:** `:error` flash via `failure_reason_message/2` on `{:blocked, outcome, reason}`
- **Added:** `failure_reason_message/2` with 5 clauses (`:unsupported`, `:needs_input`, `:scope_invalid`, `:policy_denied`, catch-all) — bounded, operator-legible reasons
- **Unchanged:** `get_available_tools/2` call and `"execute_tool"` template event name (D-28 advisory-only advisory UX; module-string identity holds per Pitfall 8)

### `test/cairnloop/web/conversation_live_test.exs` (modified)

- **Updated tool fixtures** to the governed contract: `SimpleTool`, `InputTool`, `CustomUiTool` now implement `scope/0`, `authorize/2`, `run/3` (not `can_execute?/2`, `execute/3`)
- **Extended MockRepo** with `get/2`, `get_by/2`, `insert/1` to support the full `Governance.propose/3` flow in tests
- **Replaced 4 old inline-execution handler tests** with 5 proposal-first tests (TOOL-02):
  - Success: `:info` flash containing "Proposed" and "#<id>"
  - Unknown tool: `:error` flash containing "Unknown tool"
  - Missing required input: `:error` flash containing "Invalid tool parameters"
  - Phase 14 seam: flash contains "#" prefix before proposal id
  - Source-level: handler region free of `String.to_existing_atom`, `can_execute?`, `.execute(`, `try do`; contains `Governance.propose` and `failure_reason_message`

## Verification

- `mix compile --warnings-as-errors` — clean (0 warnings from this plan's changes)
- `mix test test/cairnloop/web/conversation_live_test.exs` — 29 tests, 0 failures
- `mix test test/cairnloop/tool_registry_test.exs test/cairnloop/governance_test.exs` — 23 tests, 0 failures
- `mix test` full suite — 1 doctest + 299 tests, 1 failure (pre-existing `DraftTest` only)
- `grep -rn "def can_execute?" lib/` — 0 results (no tool still defines the removed callback)
- `.execute(` in lib/ — only `Telemetry.execute` calls; no governed-tool execution callsites
- `grep -c "ToolRegistry.find_tool_module" lib/cairnloop/governance.ex` — 1 (gate-0 delegation)
- `grep -c "validate_configured_tools" lib/cairnloop/application.ex` — 1 (boot wiring)
- `grep -c "Cairnloop.Governance.propose" lib/cairnloop/web/conversation_live.ex` — 1

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Notes

- Task 1 was treated as a combined implementation task (not TDD RED/GREEN split) because the changes to `governance.ex` and `application.ex` are pure refactors/delegation — no new behavior to test-drive; the existing governance_test.exs and tool_registry_test.exs already cover these paths.
- Task 2 followed TDD: wrote the updated test file (with new proposal-first assertions) first, confirmed 5 failures (RED), then implemented the handler replacement (GREEN), confirming 0 failures.
- The source-level assertion test for the handler uses `Path.dirname/1` traversal from `__ENV__.file` to locate `conversation_live.ex` — more robust than `app_dir/2` which resolves to the build directory.

## Known Stubs

None — all functions are fully implemented. The `failure_reason_message/2` catch-all clause is intentional fail-closed behavior, not a stub.

## Threat Flags

All STRIDE threats T-13-11 through T-13-15 from 13-03-PLAN.md are mitigated:

- **T-13-11 (Tampering/DoS — execute_tool tool_ref):** Handler passes raw string to `Governance.propose/3`; resolution via `ToolRegistry.find_tool_module/1` (module-list match, never `String.to_existing_atom/1`) — verified by source-level test assertion.
- **T-13-12 (EoP — visibility filter as gate):** `get_available_tools/2` advisory-only; `Governance.validate/3` re-checks scope + authorize authoritatively at propose time — unchanged from 13-01 implementation.
- **T-13-13 (Tampering/DoS — misconfigured tool at boot):** `validate_configured_tools!()` called before `Supervisor.start_link/2` in `Application.start/2` — boot-time fail-fast.
- **T-13-14 (Repudiation/Tampering — inline execution removal):** Handler has no try/rescue, no run/3/execute/3, no optimistic UI — verified by source-level assertion and `mix compile --warnings-as-errors`.
- **T-13-15 (Information Disclosure — blocked-reason flash):** `failure_reason_message/2` returns bounded outcome-atom-based strings, not raw internal payloads.

## Self-Check: PASSED

Files modified:
- lib/cairnloop/application.ex: FOUND (validate_configured_tools! call present)
- lib/cairnloop/governance.ex: FOUND (ToolRegistry.find_tool_module delegation present)
- lib/cairnloop/web/conversation_live.ex: FOUND (Governance.propose present, old inline execution absent)
- test/cairnloop/web/conversation_live_test.exs: FOUND (29 tests, 0 failures)

Commits exist:
- aeddb41: Task 1 — boot validation + gate-0 delegation
- ca491ed: Task 2 — handler replacement + test fixture update
