<user_constraints>
## User Constraints (from DISCUSS.md)

### Locked Decisions
- Tokens are stored as SHA-256 hashes in Ecto. The raw token is returned only once upon generation.
- The AuthPlug strictly parses and validates the `Authorization: Bearer` header, but delegates the 401 enforcement to the MCP Router based on the JSON-RPC method.
- Provide a dedicated Plug for `/.well-known/oauth-protected-resource` that the host app mounts.

### the agent's Discretion
- Implementation details around how the token generation, hashing, and database schema are technically constructed in Elixir and Ecto.

### Deferred Ideas (OUT OF SCOPE)
- N/A
</user_constraints>

# Phase 20: MCP OAuth Seam - Research

**Researched:** 2024-05-26 (Date of research)
**Domain:** Elixir/Phoenix Backend Authentication & OAuth Resource Server Metadata
**Confidence:** HIGH

## Summary

This phase focuses on implementing the backend authentication layer for Cairnloop to act as an OAuth 2.1 resource server for the Model Context Protocol (MCP). The strategy relies on stateless-to-the-network token validation where Cairnloop (via Ecto) owns token records securely hashed with SHA-256. 

The primary recommendation is to use Erlang's native `:crypto` module for generating secure tokens and hashing them before storage. The `AuthPlug` will parse the `Authorization: Bearer` header and assign the token context without halting, allowing the router to conditionally enforce 401 Unauthorized errors only on write-heavy JSON-RPC actions. The `WellKnownPlug` is a standard Elixir Plug serving RFC 9728 compliant JSON, ready to be forwarded from a host Phoenix router.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Token Storage & Lifecycle | Database / Storage | API / Backend | Token state must be persistent, host-owned, and hashed securely at rest using Ecto. |
| Token Validation | API / Backend | Database / Storage | `AuthPlug` extracts the token; a context API function hashes and checks the DB for valid tokens. |
| Conditional Auth Enforcement | API / Backend | — | The router handles the 401 logic, as the plug itself must allow discovery endpoints to remain unauthenticated. |
| RFC 9728 Metadata Endpoint | API / Backend | — | The `WellKnownPlug` handles the domain root path `/.well-known/oauth-protected-resource` via host mounting. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `:crypto` | (Erlang OTP) | Secure random bytes & hashing | Native Erlang module, standard for high-performance and secure cryptographic functions without external dependencies. |
| `Ecto.Migration` | ~> 3.10 | Database schema definitions | Project standard for data persistence. |
| `Plug.Conn` | ~> 1.15 | HTTP request processing | Native Phoenix/Elixir way to handle HTTP middleware safely. |
| `Jason` | ~> 1.4 | JSON encoding | Standard JSON library in Elixir/Phoenix ecosystems. |

## Architecture Patterns

### System Architecture Diagram

```
[External MCP Client]
       │
       │ (HTTP POST /mcp or GET /.well-known/oauth-protected-resource)
       ▼
[Host Phoenix Endpoint]
       │
       ├─► (if /.well-known/...) ─► Cairnloop.Web.MCP.WellKnownPlug ─► [JSON Response]
       │
       ▼
[Cairnloop MCP Route]
       │
       ▼
[Cairnloop.Web.MCP.AuthPlug]
       │
       │──► 1. Extract `Authorization: Bearer <token>`
       │──► 2. Call `Cairnloop.MCP.validate_token(<token>)`
       │       └───► Hash token, check `cairnloop_mcp_tokens` via Ecto
       │──► 3. Assign `mcp_token` to `conn` (or leave nil, do not halt)
       ▼
[Cairnloop.Web.MCP.Router]
       │
       ├──► (Method: `initialize` or `tools/list`) ─► [Process normally]
       │
       └──► (Method: `tools/call`) ─► Check `conn.assigns.mcp_token`
                                       ├──► (nil) ─► Return HTTP 401 with `WWW-Authenticate`
                                       └──► (valid) ─► [Process tool call]
```

### Pattern 1: Secure Token Generation and Hashing
**What:** Generating a cryptographically secure token and immediately hashing it before storing it.
**When to use:** Whenever issuing tokens that provide access to protected resources.
**Example:**
```elixir
# Generate 32 bytes of secure random data and base64 encode it for transmission
raw_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

# Hash the token with SHA-256 for database storage
hashed_token = :crypto.hash(:sha256, raw_token)
```

### Pattern 2: Non-Halting Authentication Plug
**What:** A Plug that extracts information and assigns it to the connection, but defers authorization decisions (like returning a 401 error and halting) to a later stage (the router).
**When to use:** When different routes or request body contents (e.g., JSON-RPC methods) have different authentication requirements on the same endpoint.
**Example:**
```elixir
def call(conn, _opts) do
  with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
       {:ok, token_record} <- Cairnloop.MCP.validate_token(token) do
    assign(conn, :mcp_token, token_record)
  else
    _ -> conn # Do not halt; leave assigns empty
  end
end
```

### Anti-Patterns to Avoid
- **Halting in the Auth Plug:** Do not `halt(conn)` and return a 401 in `AuthPlug` because the MCP spec requires the same `/mcp` POST endpoint to serve both unauthenticated `initialize` and authenticated `tools/call` requests.
- **Storing Raw Tokens:** Do not store the raw `Base64` token string in the database. Always use the SHA-256 hash. If the database is compromised, the attacker cannot use the tokens.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Token generation | Custom PRNGs | `:crypto.strong_rand_bytes/1` | Native OTP is cryptographically secure and auditable. |
| HTTP header extraction | Regex parsing | `Plug.Conn.get_req_header/2` | Robust and standard way to access headers case-insensitively in Plug. |

## Common Pitfalls

### Pitfall 1: Double Body Parsing in Router
**What goes wrong:** Attempting to parse the JSON body in the Plug to enforce the 401, causing `Plug.Parsers` or the router to crash when it attempts to read the body a second time.
**Why it happens:** Plug consumes the socket stream. Once read, the body is gone unless explicitly cached, which impacts memory and performance.
**How to avoid:** Defer all method-based authorization checks to the Router layer *after* standard JSON parsing occurs.

### Pitfall 2: Timing Attacks on Token Validation
**What goes wrong:** Attackers could measure the time it takes to validate a token, inferring partial matches.
**Why it happens:** Database lookups or string comparisons might fail fast.
**How to avoid:** Rely on standard Ecto queries which look up by hash. Since the token is hashed via SHA-256 *before* the DB query, a timing attack only reveals information about the hash, not the plaintext token, mitigating the risk.

## Code Examples

### Ecto Migration Pattern
```elixir
defmodule Cairnloop.Repo.Migrations.CreateCairnloopMcpTokens do
  use Ecto.Migration

  def change do
    create table(:cairnloop_mcp_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :token_hash, :binary, null: false
      add :expires_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end
    
    # Fast lookups and uniqueness constraint
    create unique_index(:cairnloop_mcp_tokens, [:token_hash])
  end
end
```

### WellKnownPlug Implementation
```elixir
defmodule Cairnloop.Web.MCP.WellKnownPlug do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    servers = Application.get_env(:cairnloop, :mcp_authorization_servers, [])
    body = Jason.encode!(%{authorization_servers: servers})
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
    |> halt()
  end
end
```

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Base.url_encode64/2` with `padding: false` is desired for the token string representation. | Patterns | [ASSUMED] The client might require standard Base64 or padding. (Low risk, standard practice). |
| A2 | The host app configuration uses `:mcp_authorization_servers`. | Constraints | [ASSUMED] The host might configure this differently, breaking RFC 9728. (Medium risk). |

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified beyond the existing Ecto/PostgreSQL setup).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `test/test_helper.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-01 | Issue token creates valid secure hash and DB record | unit | `mix test test/cairnloop/mcp_test.exs` | ❌ |
| REQ-02 | AuthPlug correctly extracts and validates token | unit | `mix test test/cairnloop/web/mcp/auth_plug_test.exs` | ❌ |
| REQ-03 | WellKnownPlug returns valid RFC 9728 JSON | unit | `mix test test/cairnloop/web/mcp/well_known_plug_test.exs` | ❌ |

### Sampling Rate
- **Per task commit:** `mix test <specific_test_file>`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/cairnloop/mcp_test.exs`
- [ ] `test/cairnloop/web/mcp/auth_plug_test.exs`
- [ ] `test/cairnloop/web/mcp/well_known_plug_test.exs`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | `:crypto.strong_rand_bytes/1` and token validation via Ecto |
| V3 Session Management | yes | Bearer tokens stored as SHA-256 hashes |
| V4 Access Control | yes | Router conditionally checks `conn.assigns.mcp_token` |
| V5 Input Validation | yes | Ecto Changeset for `cairnloop_mcp_tokens` |
| V6 Cryptography | yes | `:crypto.hash(:sha256, value)` — standard Erlang OTP |

### Known Threat Patterns for Elixir/Phoenix

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Database Compromise Exposing Tokens | Information Disclosure | Only store one-way SHA-256 hashes of the tokens in the database. |
| Timing Attacks on Validation | Information Disclosure | Perform database lookups by the hash instead of the raw string. |

## Sources

### Primary (HIGH confidence)
- [Erlang `:crypto` docs] - Verified standard functions for cryptographic operations.
- [Plug.Conn docs] - Verified `get_req_header/2` and `send_resp/3` functions for Plug implementation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - `crypto`, `Plug`, and `Ecto` are industry standard in Elixir.
- Architecture: HIGH - Follows standard non-halting plug pattern for decoupled authorization.
- Pitfalls: HIGH - Avoiding double-parsing body is a well-known Plug consideration.

**Research date:** 2024-05-26
**Valid until:** 30 days
