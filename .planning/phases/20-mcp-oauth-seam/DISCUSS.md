# Phase 20: MCP OAuth Seam — Architectural Decision Record

**Status:** Approved (One-Shot Consensus)
**Context:** GSD Discuss Phase (Automated)
**Date:** 2026-05-26

## Overview
Phase 20 introduces the OAuth 2.1 Bearer token validation seam for the Model Context Protocol (MCP) server. Cairnloop acts as the **resource server**, validating tokens to gate access to write-capable tools. It does not issue tokens over the network; token issuance is host-controlled via Ecto.

In alignment with Cairnloop's core design principles (host-owned over magic, explicit Ecto state, and behaviours over DSLs), the architecture is designed to be embedded seamlessly into a Phoenix host application.

---

## 1. Token Storage & Lifecycle (Ecto-Native)

**Decision:** Tokens are stored as SHA-256 hashes in Ecto. The raw token is returned only once upon generation.
**Rationale:** Follows industry best practices (e.g., GitHub/GitLab token storage) to mitigate database compromise. Keeps token management fully host-owned.

### Schema (`cairnloop_mcp_tokens`)
- `id` (binary_id, primary key)
- `name` (string, required) — For display in the host's operator UI.
- `token_hash` (binary, required) — The SHA-256 hash of the generated raw token.
- `expires_at` (utc_datetime_usec, optional)
- `revoked_at` (utc_datetime_usec, optional)
- `inserted_at` / `updated_at`

### Context API (`Cairnloop.MCP`)
- `issue_token(attrs)`: Generates a secure random 32-byte string (e.g. via `:crypto.strong_rand_bytes/1`), hashes it, inserts the record, and returns `{:ok, token_record, raw_token}`.
- `validate_token(raw_token)`: Hashes the provided string, looks up the active, unexpired, unrevoked record. Returns `{:ok, token_record}` or `{:error, :unauthorized}`.
- `revoke_token(token_record)`: Sets `revoked_at = now()`.

---

## 2. Authentication Plug (`Cairnloop.Web.MCP.AuthPlug`)

**Decision:** The AuthPlug strictly parses and validates the `Authorization: Bearer` header, but delegates the 401 enforcement to the MCP Router based on the JSON-RPC method.
**Rationale:** The MCP spec uses a single POST endpoint for all JSON-RPC methods. We must allow unauthenticated access to discovery (`initialize`, `tools/list`) while strictly enforcing 401 on write actions (`tools/call`).

### Implementation Flow
1. **The Plug:** `Cairnloop.Web.MCP.AuthPlug` runs *before* JSON parsing. It extracts the Bearer token and calls `Cairnloop.MCP.validate_token/1`. 
   - If valid, it assigns: `conn |> assign(:mcp_token, token_record)`.
   - If invalid or missing, it leaves `conn.assigns.mcp_token` as `nil`. It **does not halt**.
2. **The Router:** `Cairnloop.Web.MCP.Router.call/2` parses the JSON body.
   - For read-only methods (`initialize`, `tools/list`), it proceeds normally.
   - For write methods (like `tools/call`, coming in Phase 21), it checks `conn.assigns.mcp_token`. If `nil`, it short-circuits the JSON-RPC response and returns a strict HTTP 401 with the `WWW-Authenticate` header pointing to the RFC 9728 endpoint.

**Tradeoffs:** By not forcing 401 at the plug level, we avoid buffering or double-parsing the JSON body. This keeps the Plug modular and adheres to the principle of least surprise in Phoenix.

---

## 3. RFC 9728 Metadata Endpoint (`Cairnloop.Web.MCP.WellKnownPlug`)

**Decision:** Provide a dedicated Plug for `/.well-known/oauth-protected-resource` that the host app mounts.
**Rationale:** Cairnloop is mounted at a sub-path (e.g., `/mcp`), but RFC 9728 mandates this metadata must be served at the domain root. Cairnloop cannot magically insert routes into the host's root.

### Integration
- **Host App Action:** The host developer will add this line to their `router.ex` or `endpoint.ex`:
  ```elixir
  forward "/.well-known/oauth-protected-resource", Cairnloop.Web.MCP.WellKnownPlug
  ```
- **Configuration:** The `authorization_servers` array required by the RFC is configured explicitly via:
  ```elixir
  config :cairnloop, :mcp_authorization_servers, ["https://auth.example.com"]
  ```

This ensures complete developer ergonomics without sacrificing control.

---

## Next Steps
With the architecture finalized and fully aligned with the embedded, host-owned philosophy, we are ready to proceed to the Planning Phase.

**Ready for: `/gsd-plan-phase 20`**
