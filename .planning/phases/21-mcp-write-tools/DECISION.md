# Phase 21: MCP Write Tools — Architectural Decision Record

**Status:** Approved (One-Shot Consensus)
**Context:** GSD Discuss Phase (Automated)
**Date:** 2026-05-26

## Overview
Phase 21 (ACT-02, ACT-03) extends the governed-action approval flow to the Model Context Protocol (MCP) server. Authenticated MCP clients will be able to invoke write-capable tools via the `tools/call` JSON-RPC method.

Following Cairnloop's strict architectural constraints, **write-capable tools are NEVER executed synchronously via the MCP handler.** Every `tools/call` invocation must create a `ToolProposal` via the `Cairnloop.Governance.propose/3` pipeline. The MCP client receives a `proposal_id` and a `"pending_approval"` status, leaving the actual execution to the host's asynchronous approval and worker mechanics (vM011).

## 1. Actor Identity Mapping (ACT-02)

**Decision:** The `actor_id` passed to `Governance.propose/3` will be derived from the validated `Cairnloop.MCP.Token` record, formatted as `"mcp_token:#{token.id}"`.
**Rationale:** MCP clients authenticate via Bearer tokens (Phase 20). The token is the highest-fidelity identity we have for the remote actor. By namespacing it with `mcp_token:`, we prevent collisions with host `user_id`s and explicitly document the origin of the proposal in the database.
**Context Mapping:** The `conn.assigns.mcp_token` (set by `AuthPlug`) will be extracted in the router. The `context` map passed to `Governance` will include `%{origin: :mcp, mcp_token_id: token.id, mcp_token_name: token.name}` to provide full visibility to the operator during approval review.

## 2. Idempotency & Duplicate Handling (ACT-03)

**Decision:** Leverage `Governance.propose/3`'s existing idempotency mechanics. MCP `tools/call` does not require a custom deduplication layer.
**Rationale:** `Governance.propose/3` natively derives an idempotency key from `tool_ref, actor_id, context, input_snapshot` (D-25). If an MCP client retries a `tools/call` with the same arguments within the approval window, `Governance.propose/3` will trap the unique constraint violation and return the existing `ToolProposal`.
**MCP Integration:** The router will pattern-match on `{:ok, proposal}` (new proposal) and `{:error, :already_exists, proposal}` (or the equivalent existing return from `propose/3`) and format both as a successful `tools/call` response containing the `proposal_id` and `pending_approval` status.

## 3. The `tools/call` JSON-RPC Response

**Decision:** The `tools/call` response will conform to the MCP specification by returning a `content` array containing a single `text` item. The text will clearly state the proposal's ID and pending status.
**Rationale:** MCP expects tool results to be human-readable or LLM-readable text/content blocks.
**Format:**
```json
{
  "content": [
    {
      "type": "text",
      "text": "Proposal created successfully. Proposal ID: <uuid>. Status: pending_approval. The action will be executed asynchronously once approved by a host operator."
    }
  ],
  "isError": false
}
```
**Tradeoffs:** While returning structured JSON inside the `text` field was considered, human-readable prose provides better UX for LLM clients natively interpreting the MCP tool response. The unique `proposal_id` is included so the LLM can reference it in subsequent interactions if a status-check tool is added later.

## 4. Router Integration

**Decision:** Remove the 404 stub for `tools/call` in `Cairnloop.Web.MCP.Router`. Replace it with a handler that extracts the requested tool, invokes `Governance.propose/3`, and maps the result.
**Rationale:** The router already protects `tools/call` with an HTTP 401 guard via `conn.assigns.mcp_token` (Phase 20). The handler only needs to focus on mapping the JSON-RPC arguments to the `Governance` API.
**Error Handling:**
- `{:blocked, :unsupported, :unknown_tool}` -> Returns MCP standard error `-32601` (Method not found).
- `{:blocked, :needs_input, changeset}` -> Returns MCP standard error `-32602` (Invalid params) with the changeset errors serialized.
- `{:blocked, outcome, reason}` -> Returns a successful MCP response with `isError: true` containing the outcome (e.g., `policy_denied`) in the text block, as the tool exists but the proposal was immediately rejected.

## Next Steps
This architecture satisfies all constraints of ACT-02 and ACT-03 without altering the core governance engine. 

**Ready for: `/gsd-plan-phase 21`**
