# Phase 20: MCP OAuth Seam - Validation Strategy

## Goal-Backward Verification

This document outlines the validation criteria required to prove Phase 20 is successfully implemented.

### 1. Token Issue & Storage
**Goal:** Tokens must be issued securely and stored as hashes, never plain text.
**Verification:** 
- ExUnit tests (`mcp_test.exs`) must assert that `Cairnloop.MCP.issue_token/1` returns a raw token string that, when hashed with `:crypto.hash(:sha256, raw_token)`, strictly matches the `token_hash` field persisted in the Ecto record.
- Ecto migration ensures `token_hash` is a binary string with a unique index.

### 2. Stateless Validation
**Goal:** Authentication plugs should validate tokens without halting the connection prematurely, allowing downstream routing to decide whether auth is strictly required based on the RPC method.
**Verification:**
- Plug unit tests (`auth_plug_test.exs`) must assert that `AuthPlug` parses the `Authorization: Bearer <token>` header correctly.
- If a valid token is provided, `conn.assigns.mcp_token` must be populated.
- If an invalid, expired, revoked, or missing token is provided, `conn.assigns.mcp_token` remains unpopulated, but `halt(conn)` is **not** called.

### 3. Metadata Standard
**Goal:** The application must expose an OAuth authorization server metadata endpoint compliant with RFC 9728.
**Verification:**
- `well_known_plug_test.exs` must ensure the JSON payload served at the correct endpoint matches the expected RFC 9728 schema (`{"authorization_servers": [...]}`).

### 4. Conditional Enforcement
**Goal:** The application must enforce Bearer authentication *only* for write methods to allow read-only operations without tokens.
**Verification:**
- Integration tests on the MCP router must assert that read methods (e.g., `initialize`, `tools/list`) succeed normally without any authorization header.
- Integration tests must assert that write methods (e.g., `tools/call`) automatically return a `401 Unauthorized` HTTP response (and set the `WWW-Authenticate` header) whenever `conn.assigns.mcp_token` is missing or invalid.
