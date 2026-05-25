# Architecture Research

**Domain:** Elixir hex.pm library release + example app + MCP OAuth + MCP write tools
**Researched:** 2026-05-25
**Confidence:** HIGH (hex.pm/ExDoc: HIGH via official docs; MCP OAuth: HIGH via official spec; example app placement: HIGH via ecosystem patterns; MCP tools/call integration: MEDIUM via Elixir ecosystem search)

---

## Standard Architecture

### System Overview (vM012 additions in context)

```
┌────────────────────────────────────────────────────────────────────┐
│                    Host Phoenix Application                         │
│  ┌──────────────┐  ┌──────────────────┐  ┌───────────────────────┐ │
│  │  cairnloop_  │  │  cairnloop       │  │  cairnloop_example/   │ │
│  │  dashboard   │  │  router.ex       │  │  (separate Mix app,   │ │
│  │  LiveView    │  │  (macro mount)   │  │   examples/ subdir)   │ │
│  └──────────────┘  └──────────────────┘  └───────────────────────┘ │
└───────────────────────────────────┬────────────────────────────────┘
                                    │ forward "/mcp"
┌───────────────────────────────────▼────────────────────────────────┐
│               Cairnloop Library (hex: cairnloop)                    │
│                                                                     │
│  Phase 18: Hex.pm Release                                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  mix.exs: package/docs metadata  CI: release job on v* tag  │   │
│  │  CHANGELOG.md  ExDoc  hexdocs.pm publish                    │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  Phase 20: MCP OAuth Seam (new Plug layer)                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Cairnloop.Web.MCP.Auth (new Plug)                           │  │
│  │    - 401 + WWW-Authenticate on missing/invalid Bearer token  │  │
│  │    - /.well-known/oauth-protected-resource metadata endpoint │  │
│  │    - MCP token lookup → Cairnloop.MCP.Token (new Ecto schema)│  │
│  │    - Scope claim extracted into conn.private                 │  │
│  └──────────────────────┬───────────────────────────────────────┘  │
│                          │ passes validated conn                    │
│  Phase 17 (existing): MCP Router (now gated by OAuth plug)          │
│  ┌──────────────────────▼───────────────────────────────────────┐  │
│  │  Cairnloop.Web.MCP.Router                                    │  │
│  │    initialize  tools/list  (Phase 21: +tools/call)           │  │
│  └──────────────────────┬───────────────────────────────────────┘  │
│                          │ tools/call dispatch                      │
│  Phase 21: MCP Write Tools (new handler)                            │
│  ┌──────────────────────▼───────────────────────────────────────┐  │
│  │  Cairnloop.Web.MCP.ToolCallHandler (new module)              │  │
│  │    - extract tool_ref + params from JSON-RPC                 │  │
│  │    - build context from conn.private (actor_id, scopes)      │  │
│  │    - delegate to Cairnloop.Governance.propose/3              │  │
│  │    - return proposal ID + status in JSON-RPC result          │  │
│  └──────────────────────┬───────────────────────────────────────┘  │
│                          │                                          │
│  Existing (vM011): Governance + Oban Pipeline                       │
│  ┌──────────────────────▼───────────────────────────────────────┐  │
│  │  Cairnloop.Governance.propose/3                              │  │
│  │    → ToolProposal (Ecto)                                     │  │
│  │    → ToolApproval state machine                              │  │
│  │    → ApprovalResumeWorker → ToolExecutionWorker              │  │
│  │    → Tool.run/3 (sole execution site)                        │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | New or Existing |
|-----------|----------------|-----------------|
| `mix.exs` package block | hex.pm publish metadata, ExDoc config, licenses | Modified (Phase 18) |
| `CHANGELOG.md` | Release history vM009–vM012 | New (Phase 18) |
| CI release job | Triggered on `v*` tag push; runs `mix hex.publish --yes` | New (Phase 18) |
| `examples/cairnloop_example/` | Standalone Phoenix app demonstrating draft/approval/KB flow | New (Phase 19) |
| `Cairnloop.Web.MCP.Auth` | Bearer token extraction, 401 on failure, scope into conn.private | New (Phase 20) |
| `Cairnloop.MCP.Token` (Ecto schema) | Durable token records (token_hash, scopes, actor_id, revoked_at) | New (Phase 20) |
| MCP OAuth metadata endpoint | `/.well-known/oauth-protected-resource` served by the Auth Plug | New (Phase 20) |
| `Cairnloop.Web.MCP.Router` (modified) | Adds `tools/call` dispatch for Phase 21 | Modified (Phase 21) |
| `Cairnloop.Web.MCP.ToolCallHandler` | Converts MCP JSON-RPC call → `Governance.propose/3` context | New (Phase 21) |
| `Cairnloop.Governance` | Unchanged; `propose/3` is the single entry point for all tool invocations | Unchanged |
| `ToolExecutionWorker` | Unchanged; sole `run/3` caller | Unchanged |

---

## Phase 18: Hex.pm Release

### mix.exs Changes

Two new top-level blocks in the `project/0` function:

```elixir
def project do
  [
    app: :cairnloop,
    version: "0.1.0",
    elixir: "~> 1.19",
    # ... existing ...
    name: "Cairnloop",
    description: "Host-owned customer support automation library for Phoenix.",
    source_url: "https://github.com/szTheory/cairnloop",
    homepage_url: "https://hexdocs.pm/cairnloop",
    docs: [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      source_ref: "v#{@version}",
      source_url_pattern: "https://github.com/szTheory/cairnloop/blob/v#{@version}/%{path}#L%{line}"
    ],
    package: package(),
    deps: deps()
  ]
end

defp package do
  [
    licenses: ["MIT"],               # required by hex.pm
    links: %{
      "GitHub" => "https://github.com/szTheory/cairnloop",
      "HexDocs" => "https://hexdocs.pm/cairnloop"
    },
    files: ~w(lib priv mix.exs README.md CHANGELOG.md LICENSE)
  ]
end
```

ExDoc added as dev-only dep:
```elixir
{:ex_doc, "~> 0.34", only: :dev, runtime: false}
```

### CI Release Job

A second GitHub Actions job (separate from the existing CI matrix) triggered by `v*` tag pushes:

```yaml
# .github/workflows/release.yml (new file)
on:
  push:
    tags:
      - "v*"
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.19.0"
          otp-version: "27.2"
      - run: mix deps.get
      - run: mix hex.publish --yes
        env:
          HEX_API_KEY: ${{ secrets.HEX_API_KEY }}
```

The `HEX_API_KEY` secret is a write-scoped Hex API key created with `mix hex.user key generate --key-name publish-ci --permission api:write` and stored in the GitHub repository secrets.

**Files modified:** `mix.exs`, `.github/workflows/ci.yml` (add job), new `.github/workflows/release.yml`
**Files new:** `CHANGELOG.md`, `LICENSE` (if not present), `README.md` (update with hex badge + install instructions)

---

## Phase 19: Example App

### Placement Decision: `examples/cairnloop_example/` (subdirectory, not umbrella, not separate repo)

Rationale:
- The example app is tightly coupled to the library for development (path dep); shipping a separate repo adds sync overhead.
- Umbrella adds structural complexity that isn't warranted for a demo that will never be published to hex.
- `examples/` subdirectory is the idiomatic Elixir pattern used by Phoenix, Ecto, Oban, and other major libraries.
- Excluded from the published hex package via `files:` list in `package/0` — the library consumer never receives the example app.
- The example app references the library via `{:cairnloop, path: "../.."}` during development; DEMO-04 switches this to `{:cairnloop, "~> 0.1"}` after publish.

### Example App Structure

```
examples/
└── cairnloop_example/
    ├── mix.exs              # {:cairnloop, "~> 0.1"} dep
    ├── README.md            # setup + config docs (DEMO-03)
    ├── config/
    │   └── config.exs       # :cairnloop config with example tool
    ├── lib/
    │   ├── cairnloop_example/
    │   │   ├── application.ex
    │   │   ├── repo.ex
    │   │   └── tools/
    │   │       └── example_tool.ex   # use Cairnloop.Tool (demo)
    │   └── cairnloop_example_web/
    │       ├── router.ex             # cairnloop_dashboard + MCP forward
    │       └── endpoint.ex
    ├── priv/
    │   ├── repo/migrations/           # host tables (conversations, messages)
    │   └── seeds.exs                  # seed data for demo flow
    └── test/
```

The example app's `router.ex` shows the two integration points a host performs:

```elixir
# In the host router — the only two lines a host needs:
use Cairnloop.Router
cairnloop_dashboard "/support"
forward "/mcp", Cairnloop.Web.MCP.Router  # after OAuth middleware
```

**Files modified:** `mix.exs` package `files:` list (exclude `examples/`)
**Files new:** entire `examples/cairnloop_example/` tree

---

## Phase 20: MCP OAuth Seam

### Architecture Decision: Plug middleware, not embedded OAuth AS

The MCP spec (2025-11-25) separates the resource server (the MCP endpoint) from the authorization server. Cairnloop owns the resource server role only. The host is responsible for the authorization server (token issuance and the `/.well-known/oauth-authorization-server` discovery document). Cairnloop provides:

1. **Token validation middleware** (`Cairnloop.Web.MCP.Auth` Plug) — validates Bearer tokens against durable `MCP.Token` records; returns 401/403 on failure; populates `conn.private` with `mcp_actor_id` and `mcp_scopes`.
2. **Protected resource metadata endpoint** — `/.well-known/oauth-protected-resource` served by the Auth Plug to satisfy MCP spec RFC9728 requirement; points `authorization_servers` at the host's configured AS URL.

This is the correct split: the host controls token issuance (they own the user identity and OAuth consent); Cairnloop controls token validation and scope enforcement.

### New Ecto Schema: `Cairnloop.MCP.Token`

```
mcp_tokens table:
  id             uuid PK
  token_hash     text UNIQUE NOT NULL    # sha256(raw_token), never store raw
  actor_id       text NOT NULL
  scopes         text[] NOT NULL         # granted scopes
  expires_at     utc_datetime
  revoked_at     utc_datetime NULL       # nil = active
  issued_by      text                    # AS URL / system identifier
  inserted_at    utc_datetime
  updated_at     utc_datetime
```

Token records are Ecto-backed (durable, auditable, revocable). The raw token is never stored — only the SHA-256 hash. Revocation is a single `UPDATE revoked_at = now()`.

### New Module: `Cairnloop.Web.MCP.Auth`

```elixir
defmodule Cairnloop.Web.MCP.Auth do
  @behaviour Plug
  # 1. Intercepts /.well-known/oauth-protected-resource → returns RFC9728 metadata JSON
  # 2. For all other paths: extracts Bearer token from Authorization header
  # 3. hash(token) → lookup MCP.Token; check not expired, not revoked
  # 4. On failure: 401 + WWW-Authenticate: Bearer resource_metadata="..."
  # 5. On scope-gated call with wrong scope: 403 + WWW-Authenticate: Bearer error="insufficient_scope"
  # 6. On success: put_private(conn, :mcp_actor_id, ...) + put_private(conn, :mcp_scopes, ...)
end
```

### Integration in Host Router

```elixir
# Host adds auth before the existing MCP forward:
pipeline :mcp_auth do
  plug Cairnloop.Web.MCP.Auth
end

scope "/mcp" do
  pipe_through :mcp_auth
  forward "/", Cairnloop.Web.MCP.Router
end
```

The existing `Cairnloop.Web.MCP.Router` is unchanged — it receives a conn already validated by the Auth Plug.

### OAuth Protected Resource Metadata Response

```json
{
  "resource": "https://host.example.com/mcp",
  "authorization_servers": ["https://auth.example.com"],
  "bearer_methods_supported": ["header"],
  "scopes_supported": ["tools:read", "tools:write"]
}
```

The `authorization_servers` URL is host-configured via `Application.get_env(:cairnloop, :mcp_auth_server_url)`.

**New files:** `lib/cairnloop/web/mcp/auth.ex`, `lib/cairnloop/mcp/token.ex`, `lib/cairnloop/mcp.ex`, migration `add_mcp_tokens`
**Modified files:** `config/config.exs` (add `:mcp_auth_server_url` key documentation)

---

## Phase 21: MCP Write Tools

### Data Flow: MCP tools/call → ToolProposal pipeline

```
MCP Client
  │  POST /mcp
  │  Authorization: Bearer <token>
  │  {"jsonrpc":"2.0","id":1,"method":"tools/call",
  │   "params":{"name":"Elixir.MyTool","arguments":{...}}}
  │
  ▼
Cairnloop.Web.MCP.Auth (Plug)
  │  Validates token → conn.private[:mcp_actor_id], conn.private[:mcp_scopes]
  │
  ▼
Cairnloop.Web.MCP.Router
  │  Dispatches "tools/call" → ToolCallHandler
  │
  ▼
Cairnloop.Web.MCP.ToolCallHandler (new)
  │  1. Extract tool_ref = params["name"], tool_params = params["arguments"]
  │  2. Build Governance context:
  │       context = %{
  │         scopes:   conn.private[:mcp_scopes],
  │         tool_params: tool_params,
  │         account_id: nil,
  │         conversation_id: nil,
  │         idempotency_token: params["_idempotency_token"]  # optional
  │       }
  │  3. actor_id = conn.private[:mcp_actor_id]
  │  4. Call Cairnloop.Governance.propose(tool_ref, actor_id, context)
  │  5. Map result to JSON-RPC result content
  │
  ▼
JSON-RPC response to MCP client:
  {
    "jsonrpc": "2.0",
    "id": 1,
    "result": {
      "content": [{
        "type": "text",
        "text": "Tool invocation queued (proposal: abc123, status: proposed, approval: requires_approval)"
      }],
      "proposal_id": "abc123",
      "status": "proposed",
      "approval_mode": "requires_approval"
    }
  }
```

### Key design constraint: MCP tools/call is async by nature for requires_approval tools

The MCP spec's `tools/call` expects a synchronous result. For `:auto` approval tools (risk tier `:read_only`), Cairnloop can propose + immediately check status and return result. For `:requires_approval` tools, the correct return is "proposal created, pending operator approval" — the MCP client must poll or be notified via a separate channel. This is the honest, safe behavior: never pretend synchronous execution happened.

Always return the proposal ID and status synchronously; let polling/WebSocket notification handle result delivery. This avoids coupling Oban job execution timing to HTTP response windows and keeps the ToolCallHandler stateless.

### Router Modification

The only change to the existing MCP Router is adding one new dispatch clause:

```elixir
# In Cairnloop.Web.MCP.Router — add tools/call clause:
defp handle_method(conn, id, "tools/call", params) do
  Cairnloop.Web.MCP.ToolCallHandler.handle(conn, id, params)
end
```

The existing `-32601 Method not found` catch-all continues to handle any other methods. The string-only dispatch pattern (D-19, T-17-02-01) is preserved — `"tools/call"` stays a string.

**New files:** `lib/cairnloop/web/mcp/tool_call_handler.ex`
**Modified files:** `lib/cairnloop/web/mcp/router.ex` (add single tools/call clause only)

---

## Recommended Build Order

The milestone has four phases with a specific dependency graph:

```
Phase 18 (Release)
  │  Must be first — establishes the published package that Phase 19 depends on
  │  No code dependencies on other vM012 phases
  ▼
Phase 19 (Example App)
  │  Depends on Phase 18 being published (DEMO-04 requires hex dep, not path dep)
  │  Can develop with path dep, switch to hex dep at phase end
  │  No code dependencies on Phases 20/21
  ▼
Phase 20 (MCP OAuth)
  │  Adds Auth Plug + Token schema; MCP Router unchanged
  │  Must precede Phase 21 (ToolCallHandler needs actor_id/scopes from conn.private)
  ▼
Phase 21 (MCP Write Tools)
     Depends on Phase 20 (conn.private auth context)
     Depends on existing vM011 Governance pipeline (already shipped)
```

**Rationale for ordering:**

1. **Phase 18 first** — Hard June 2, 2026 CI deadline per PROJECT.md. Publish infrastructure (release job, package metadata, CHANGELOG) is a prerequisite for DEMO-04. Zero risk of destabilizing existing code.

2. **Phase 19 second** — Example app is the most impactful adopter-gap closer. Building it immediately after publish confirms the published package is actually installable and integrated correctly end-to-end. No blocking dependencies on OAuth or write tools.

3. **Phase 20 before 21** — The `conn.private` actor/scopes context set by the Auth Plug is what `ToolCallHandler` reads. Phase 21 without Phase 20 would produce unauthenticated tool invocations.

4. **Phase 21 last** — Build on proven OAuth seam; extends the existing MCP router minimally; depends entirely on the vM011 Governance pipeline which is sealed.

---

## New vs Modified Modules Summary

### Phase 18 — Release

| File | Change |
|------|--------|
| `mix.exs` | Modified — add `name`, `description`, `source_url`, `docs`, `package` |
| `CHANGELOG.md` | New |
| `README.md` | Modified — add hex badge, `mix.exs` install snippet |
| `LICENSE` | New (if absent) |
| `.github/workflows/release.yml` | New — `v*` tag trigger + `mix hex.publish --yes` |
| `.github/workflows/ci.yml` | Unchanged — existing CI jobs unaffected |

### Phase 19 — Example App

| File | Change |
|------|--------|
| `examples/cairnloop_example/` | New — entire standalone Phoenix app tree |
| `mix.exs` package `files:` | Modified — whitelist excludes `examples/` |

### Phase 20 — MCP OAuth

| File | Change |
|------|--------|
| `lib/cairnloop/web/mcp/auth.ex` | New — Plug: token validation + resource metadata endpoint |
| `lib/cairnloop/mcp/token.ex` | New — Ecto schema: MCP token records |
| `lib/cairnloop/mcp.ex` | New — facade: `issue_token/2`, `revoke_token/1`, `lookup_by_raw/1` |
| `priv/repo/migrations/YYYYMMDD_add_mcp_tokens.exs` | New |
| `config/config.exs` | Modified — document `:mcp_auth_server_url` config key |

### Phase 21 — MCP Write Tools

| File | Change |
|------|--------|
| `lib/cairnloop/web/mcp/tool_call_handler.ex` | New — JSON-RPC → Governance.propose/3 bridge |
| `lib/cairnloop/web/mcp/router.ex` | Modified — add `tools/call` dispatch clause only |

**Sealed and unchanged across all phases:** `Cairnloop.Governance`, `ToolExecutionWorker`, `ApprovalResumeWorker`, `ToolProposal`, `ToolApproval`, `ToolActionEvent` — zero modifications.

---

## Architectural Patterns

### Pattern 1: OAuth as Plug Middleware, Not Embedded AS

**What:** MCP OAuth validation is a pure Plug that validates tokens and populates `conn.private`. It does not issue tokens (that is the host's authorization server). The resource metadata document points clients to the host's AS.

**When to use:** When the library must support OAuth but cannot own the user identity model (it doesn't — the host does).

**Trade-offs:** Simpler library; requires host configuration of AS URL. This is the correct split per MCP spec which explicitly allows AS and resource server to be separate entities.

### Pattern 2: Governance.propose/3 as the Single MCP Entry Point

**What:** `ToolCallHandler` does not call `run/3` directly. It calls `Governance.propose/3`, which performs all validation gates (scope, policy, input) and creates a durable `ToolProposal`. Execution is async via Oban.

**When to use:** Always — this is the core architectural invariant from vM011. The MCP surface is just another caller of the same governance facade, identical in behavior to LiveView-triggered proposals.

**Trade-offs:** MCP clients receive proposal status rather than execution result for `requires_approval` tools. This is honest and safe.

### Pattern 3: Token Hash Storage

**What:** MCP tokens are stored as `sha256(raw_token)` only. The raw token is returned once at issuance and never stored. Validation hashes the incoming Bearer token and compares against the stored hash.

**When to use:** Any time tokens need to be durable and revocable without risk of token leakage from the database.

**Trade-offs:** Tokens cannot be recovered if lost (by design). Issuance must be handled carefully.

### Pattern 4: Example App as Subdirectory (Not Umbrella, Not Separate Repo)

**What:** `examples/cairnloop_example/` is a standalone Mix project nested inside the library repo but excluded from the published package via `files:` whitelist.

**When to use:** When the example is tightly coupled in development (path dep) but must demonstrate the published package (hex dep).

**Trade-offs:** Repo is slightly larger; CI must not run example app tests in the library's CI suite (they are separate Mix projects with separate `mix.exs` files).

---

## Anti-Patterns

### Anti-Pattern 1: Embedding an Authorization Server in the Library

**What people do:** Implement token issuance, consent flows, and user identity inside the library.

**Why it's wrong:** Cairnloop is a library, not an application. It cannot own user identity. The MCP spec explicitly allows the AS to be a separate entity. Adding an AS would massively expand scope and create the exact out-of-scope concern listed in PROJECT.md.

**Do this instead:** Document that the host must configure an AS URL. The library's Auth Plug validates tokens; the host's AS issues them. For simple setups, the `Cairnloop.MCP` facade's `issue_token/2` can act as a manual/admin token issuer without a full OAuth AS.

### Anti-Pattern 2: Calling run/3 from ToolCallHandler

**What people do:** Short-circuit the governance pipeline by calling `tool_module.run/3` directly from the MCP handler for "fast" execution.

**Why it's wrong:** Violates the core vM011 invariant. Bypasses idempotency, approval state machine, telemetry, and all three idempotency layers. Would require reopening sealed vM011 code.

**Do this instead:** Route through `Governance.propose/3` always. Return proposal ID + status to the MCP client.

### Anti-Pattern 3: Storing Raw Bearer Tokens

**What people do:** Store the raw MCP bearer token in the `mcp_tokens` table for easy lookup.

**Why it's wrong:** Database breach = all token secrets exposed. Tokens are credentials.

**Do this instead:** Store `sha256(raw_token)` only; return the raw token once at issuance.

### Anti-Pattern 4: Converting MCP method strings to atoms

**What people do:** `String.to_existing_atom(method)` for pattern matching dispatch.

**Why it's wrong:** Established security constraint from D-19 (T-17-02-01). The vM011 MCP router already uses string case matching; this must continue in Phase 21.

**Do this instead:** String case matching only. `"tools/call"` stays a string throughout.

---

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| hex.pm | `mix hex.publish --yes` in CI on `v*` tag | `HEX_API_KEY` GitHub secret required |
| hexdocs.pm | Auto-published by `mix hex.publish` when ExDoc dep present | Requires `docs:` config in mix.exs |
| Host Authorization Server | URL configured via `:mcp_auth_server_url` app env | Library does not call the AS; just advertises it in resource metadata |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `MCP.Auth` → `MCP.Token` | Direct Ecto query via repo indirection | Same `Application.fetch_env!(:cairnloop, :repo)` pattern as existing code |
| `MCP.ToolCallHandler` → `Cairnloop.Governance` | `Governance.propose/3` public API | No new facade entry points needed |
| `MCP.Auth` → Host Router | `conn.private[:mcp_actor_id]`, `conn.private[:mcp_scopes]` | `conn.private` not `conn.assigns` to avoid collision with host assigns |
| Example App → Library | `{:cairnloop, "~> 0.1"}` hex dep (post-publish) | Path dep `{:cairnloop, path: "../.."}` for development |

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-100 MCP clients | Single table lookup per request in `mcp_tokens`; no caching needed |
| 100-10K MCP clients | Index on `token_hash` (included in migration); consider ETS cache for token validation to reduce DB round-trips |
| 10K+ MCP clients | Token validation hot path may benefit from short-lived ETS cache with TTL; revocation propagation latency becomes a concern |

Token validation is the only new hot path. The existing governance pipeline scales with Oban queue concurrency and Postgres; no changes needed for Phase 21.

---

## Sources

- [hex.pm publish documentation](https://hex.pm/docs/publish) — official hex.pm publish guide (HIGH confidence)
- [MCP Authorization Specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization) — official MCP OAuth spec (HIGH confidence)
- [mix hex.publish task docs](https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html) — CI publish flags (HIGH confidence)
- [ExDoc mix docs](https://hexdocs.pm/ex_doc/Mix.Tasks.Docs.html) — ExDoc configuration reference (HIGH confidence)
- [Building MCP Server in Elixir - Hashrocket](https://hashrocket.com/blog/posts/building-a-mcp-server-in-elixir) — Elixir MCP implementation patterns (MEDIUM confidence)
- [wesleimp/action-publish-hex GitHub Action](https://github.com/wesleimp/action-publish-hex) — CI publish action patterns (MEDIUM confidence)
- [Boruta OAuth library on hex.pm](https://hex.pm/packages/boruta) — surveyed as AS alternative; decided against embedding (HIGH confidence on decision)

---
*Architecture research for: Cairnloop vM012 Public Release & MCP Write Surface*
*Researched: 2026-05-25*
