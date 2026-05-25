---
phase: 17
slug: optional-evidence-lane-read-only-mcp-seam
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-25
---

# Phase 17 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in Elixir) |
| **Config file** | `test/test_helper.exs` (excludes `:integration` by default) |
| **Quick run command** | `mix test test/cairnloop/governance/telemetry/ test/cairnloop/web/mcp/ --warnings-as-errors` |
| **Full suite command** | `mix test --warnings-as-errors` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/cairnloop/governance/telemetry/ test/cairnloop/web/mcp/ --warnings-as-errors`
- **After every plan wave:** Run `mix test --warnings-as-errors`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 17-01-01 | S05-01 | 1 | D17-02 | — | Trace events carry OI span kind, tool_proposal_id, actor_id; NO payload content | unit | `mix test test/cairnloop/governance/telemetry/traces_test.exs --warnings-as-errors` | ❌ Wave 0 | ⬜ pending |
| 17-01-02 | S05-01 | 1 | D17-04 | — | Trace events emitted after successful ToolActionEvent co-commit, not inside with clause | unit | `mix test test/cairnloop/governance/telemetry/traces_test.exs --warnings-as-errors` | ❌ Wave 0 | ⬜ pending |
| 17-02-01 | S05-02 | 1 | MCP-01 | — | InternalNote Spec projects to correct MCP tool definition shape (inputSchema, x-cairnloop-* fields) | unit | `mix test test/cairnloop/web/mcp/tool_projector_test.exs --warnings-as-errors` | ❌ Wave 0 | ⬜ pending |
| 17-02-02 | S05-02 | 1 | MCP-01 | — | tools/list JSON-RPC returns correct envelope {jsonrpc, id, result: {tools: [...]}} | unit | `mix test test/cairnloop/web/mcp/router_test.exs --warnings-as-errors` | ❌ Wave 0 | ⬜ pending |
| 17-02-03 | S05-02 | 1 | MCP-01 | — | initialize returns protocolVersion 2025-03-26 with capabilities: {tools: {}} | unit | `mix test test/cairnloop/web/mcp/router_test.exs --warnings-as-errors` | ❌ Wave 0 | ⬜ pending |
| 17-02-04 | S05-02 | 1 | MCP-01 | — | Unsupported methods return JSON-RPC -32601 error | unit | `mix test test/cairnloop/web/mcp/router_test.exs --warnings-as-errors` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/cairnloop/governance/telemetry/traces_test.exs` — stub tests for D17-02 trace emission assertions
- [ ] `test/cairnloop/web/mcp/tool_projector_test.exs` — stub tests for MCP-01 Spec→MCP projection
- [ ] `test/cairnloop/web/mcp/router_test.exs` — stub tests for MCP-01 JSON-RPC routing

*Existing ExUnit infrastructure covers all phase requirements — no new test framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Scoria :telemetry.attach_many/0 auto-attach pattern | D17-03 | Integration with external Scoria library | In docs/guides, verify sample code `Scoria.attach_cairnloop_governance_traces/0` is coherent |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
