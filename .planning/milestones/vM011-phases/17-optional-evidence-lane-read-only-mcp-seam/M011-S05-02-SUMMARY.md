---
phase: 17-optional-evidence-lane-read-only-mcp-seam
plan: M011-S05-02
subsystem: mcp-seam
tags: [mcp, json-rpc, plug, tool-registry, tool-projector, headless]
dependency_graph:
  requires: []
  provides:
    - Cairnloop.Web.MCP.Router — optional JSON-RPC 2.0 Plug for tools/list and initialize
    - Cairnloop.Web.MCP.ToolProjector — pure Spec->MCP tool definition transform
    - Cairnloop.ToolRegistry.list_all_tools/0 — unfiltered tool listing for MCP
  affects:
    - lib/cairnloop/tool_registry.ex (additive)
tech_stack:
  added: []
  patterns:
    - "@behaviour Plug with Plug.Conn.read_body + Jason.decode (email_webhook_plug.ex pattern)"
    - "Ecto reflection via changeset/2 empty attrs for inputSchema derivation"
    - "Pure total function over %Cairnloop.Tool.Spec{} struct fields"
    - "TDD RED/GREEN — test stubs before implementation"
key_files:
  created:
    - lib/cairnloop/web/mcp/router.ex
    - lib/cairnloop/web/mcp/tool_projector.ex
    - test/cairnloop/web/mcp/router_test.exs
    - test/cairnloop/web/mcp/tool_projector_test.exs
  modified:
    - lib/cairnloop/tool_registry.ex (additive: list_all_tools/0)
decisions:
  - "TDD workflow: wrote test stubs first (RED commit cbd2d4c), then implemented modules (GREEN commits 62d023c, aed23bc)"
  - "moduledoc security note for atom exhaustion prohibition uses plain English (not function ref) to keep grep-c assertion clean"
  - "x-cairnloop extension keys use kebab-case per HTTP header convention (RESEARCH.md open question resolution)"
metrics:
  duration: "~20 minutes"
  completed: "2026-05-25T14:21:23Z"
  tasks: 3
  files: 5
---

# Phase 17 Plan M011-S05-02: Optional Read-Only MCP Seam — Summary

Read-only MCP seam over the Cairnloop governed-tool registry: pure `Spec -> MCP tool definition` transform + JSON-RPC 2.0 Plug for `tools/list` and `initialize`, with Ecto-reflection `inputSchema` derivation, no execution path, and zero new dependencies.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Test stubs for ToolProjector and Router (RED) | cbd2d4c | test/cairnloop/web/mcp/tool_projector_test.exs, test/cairnloop/web/mcp/router_test.exs |
| 2 | ToolRegistry.list_all_tools/0 + ToolProjector (GREEN projector) | 62d023c | lib/cairnloop/tool_registry.ex, lib/cairnloop/web/mcp/tool_projector.ex |
| 3 | Cairnloop.Web.MCP.Router Plug (GREEN router) | aed23bc | lib/cairnloop/web/mcp/router.ex |

## What Was Built

**`Cairnloop.ToolRegistry.list_all_tools/0`** (additive to existing module)

Returns all configured tools as `{module, %Cairnloop.Tool.Spec{}}` tuples without any actor scope or authorization filtering. Uses the same `Application.get_env(:cairnloop, :tools, []) || []` pattern as `get_available_tools/2` but skips the advisory `scope/authorize` filter. Called by the MCP Router for `tools/list`.

**`Cairnloop.Web.MCP.ToolProjector`**

Pure total function `spec_to_mcp/1` transforms `{tool_module, %Spec{}}` tuples to MCP tool definition maps with string keys. `inputSchema` is derived via Ecto reflection: calling `tool_module.changeset(struct(tool_module), %{})` with empty attrs yields `cs.required` and `cs.types`. The `:id` field is excluded (Pitfall 2 — embedded_schema auto-generates it). A minimal Ecto-type-to-JSON-Schema mapping table handles the common types; safe fallback to `"string"` for unknowns.

**`Cairnloop.Web.MCP.Router`**

Optional `@behaviour Plug` following the `email_webhook_plug.ex` pattern. Handles JSON-RPC 2.0 POST requests:
- `initialize` — returns `protocolVersion: "2025-03-26"`, `capabilities.tools: {}`, `serverInfo`
- `tools/list` — returns `{jsonrpc, id, result: {tools: [...]}}` via `list_all_tools/0` + `spec_to_mcp/1`
- all other methods — returns JSON-RPC `-32601 Method not found` (HTTP 200)
- malformed JSON / missing envelope fields — returns JSON-RPC `-32600 Invalid Request` (HTTP 200)

No `String.to_atom/1` on untrusted method fields (T-17-02-01). No execution path reachable (D17-06). Auth is host middleware concern (D17-09).

## Test Results

All 7 tests in `test/cairnloop/web/mcp/` pass:
- `tool_projector_test.exs`: 2 tests — InternalNote `spec_to_mcp/1` round-trip, `x-cairnloop-*` string values
- `router_test.exs`: 5 tests — `tools/list` envelope, `initialize` protocolVersion, `tools/call` -32601, unknown method -32601, malformed JSON -32600

Full headless suite: 533 tests, 1 failure (pre-existing `Cairnloop.Automation.DraftTest` M005 drift baseline — not a regression).

`mix compile --warnings-as-errors`: exits 0.

## Verification Checks

```
grep -c "String.to_atom|to_existing_atom" lib/cairnloop/web/mcp/router.ex  → 0  ✓
grep -c "def list_all_tools" lib/cairnloop/tool_registry.ex                 → 1  ✓
grep -c "def get_available_tools" lib/cairnloop/tool_registry.ex            → 1  ✓ (unchanged)
```

## Deviations from Plan

None — plan executed exactly as written. The only minor adjustment was rephrasing the Router `@moduledoc` security note to avoid mentioning `String.to_atom/1` as a function call reference, which would have caused the plan's grep acceptance check to report false positives.

## TDD Gate Compliance

- RED gate: `test(17-M011-S05-02): add failing tests for ToolProjector and Router (RED)` — commit cbd2d4c
- GREEN gate (Task 2): `feat(17-M011-S05-02): implement list_all_tools/0 and ToolProjector` — commit 62d023c
- GREEN gate (Task 3): `feat(17-M011-S05-02): implement Cairnloop.Web.MCP.Router Plug` — commit aed23bc

Both RED and GREEN commits exist in order.

## Known Stubs

None — all data paths are wired. `tools/list` returns real tool definitions via `list_all_tools/0` + `spec_to_mcp/1`.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| lib/cairnloop/web/mcp/router.ex | FOUND |
| lib/cairnloop/web/mcp/tool_projector.ex | FOUND |
| lib/cairnloop/tool_registry.ex | FOUND |
| test/cairnloop/web/mcp/router_test.exs | FOUND |
| test/cairnloop/web/mcp/tool_projector_test.exs | FOUND |
| .planning/phases/17-.../M011-S05-02-SUMMARY.md | FOUND |
| Commit cbd2d4c (Task 1 RED) | FOUND |
| Commit 62d023c (Task 2 GREEN) | FOUND |
| Commit aed23bc (Task 3 GREEN) | FOUND |
