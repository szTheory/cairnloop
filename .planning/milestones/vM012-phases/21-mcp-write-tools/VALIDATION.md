# Phase 21: MCP Write Tools - Validation Strategy

## Goal-Backward Verification

This document outlines the validation criteria required to prove Phase 21 is successfully implemented, following the Nyquist rule that every step must have automated verification.

### 1. tools/call Mapping to Governance
**Goal:** `tools/call` must map correctly to `Governance.propose/3` without executing tools synchronously.
**Verification:**
- **Automated:** `mix test test/cairnloop/web/mcp/router_test.exs`
- The tests must assert that a valid `tools/call` request returns a `200 OK` JSON-RPC success response containing a `proposal_id` and `pending_approval` status string, proving the proposal was created.
- The code must not contain any direct calls to `Tool.run/3`.

### 2. Idempotency/Duplicate Proposals
**Goal:** Duplicate `tools/call` payloads must safely return the same successful response without error.
**Verification:**
- **Automated:** `mix test test/cairnloop/web/mcp/router_test.exs`
- The tests must assert that repeating the exact same `tools/call` request immediately after the first returns the identical success JSON-RPC response, leveraging `Governance.propose/3`'s native idempotency.

### 3. Authentication Constraints
**Goal:** `tools/call` must reject unauthenticated requests before proposing any tool.
**Verification:**
- **Automated:** `mix test test/cairnloop/web/mcp/router_test.exs`
- The tests must assert that calling `tools/call` without a valid `Authorization: Bearer <token>` header returns a `401 Unauthorized` HTTP status.

### 4. Error Handling & Validation
**Goal:** Missing or invalid tool arguments, and unsupported tools, must be correctly translated into standard JSON-RPC errors.
**Verification:**
- **Automated:** `mix test test/cairnloop/web/mcp/router_test.exs`
- The tests must assert that invalid arguments (e.g., failing the Ecto changeset) return a `-32602` error code, and calling an unsupported tool name returns a `-32601` error code. All error responses must use HTTP 200 with the JSON-RPC `error` key populated.