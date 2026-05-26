# Phase 21: MCP Write Tools - Wave 1 Summary

Implemented the MCP `tools/call` JSON-RPC handler to route write-capable tool invocations through Cairnloop's governance proposal pipeline.

## Implementation Details

- **MCP Router (`lib/cairnloop/web/mcp/router.ex`):**
    - Implemented `handle_method/4` for `"tools/call"`.
    - Authenticated requests are routed to `Cairnloop.Governance.propose/3`.
    - Context is explicitly prepared with `origin: :mcp`, `mcp_token_id`, and `tool_params`.
    - Outcomes from `Governance.propose/3` are mapped to standard JSON-RPC 2.0 responses:
        - `{:ok, proposal}` -> Success result with `proposal.id` and status.
        - `{:blocked, :unsupported, _}` -> `-32601 Method not found`.
        - `{:blocked, :needs_input, changeset}` -> `-32602 Invalid params` with serialized errors.
        - `{:blocked, outcome, _}` -> Success result with `isError: true` and block reason.
        - `{:error, _}` -> `-32603 Internal error`.
    - Added `unauthorized/1` helper for consistent 401 responses.
    - Updated module documentation to reflect write support.

- **Integration Tests (`test/cairnloop/web/mcp/router_test.exs`):**
    - Updated to use `Cairnloop.ConnCase` for database access.
    - Added comprehensive test suite for `tools/call`:
        - Valid token and tool name (verifies `proposal_id` and success format).
        - Idempotency (duplicate calls return the same result).
        - Authentication guard (401 for missing token).
        - Argument validation (402 for missing required fields).
        - Tool resolution (401 for unknown tools).
    - Verified against a real `pgvector` database (running in Docker).

## Verification Results

- `mix test --include integration test/cairnloop/web/mcp/router_test.exs` passes 100% (9 tests).
- All JSON-RPC 2.0 semantics preserved (HTTP 200 for errors, except 401 for auth).
- No synchronous tool execution; all actions go through the async Governance pipeline.

## Trust Boundaries & Security

- Relies on `AuthPlug` for token validation.
- `actor_id` is strictly prefixed with `mcp_token:` to ensure audit traceability.
- No atoms are dynamically generated from user input.
