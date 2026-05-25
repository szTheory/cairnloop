# Stack Research — vM012: Public Release & MCP Write Surface

**Domain:** Elixir/Phoenix library — hex.pm publish, example app, MCP OAuth seam, MCP write tools
**Researched:** 2026-05-25
**Confidence:** HIGH (all claims verified against official docs or hex.pm current releases)

---

## Scope

This file covers NEW stack additions for vM012 only. The existing stack
(Elixir 1.19, Phoenix LiveView 1.0, Ecto/PostgreSQL, pgvector 0.3.1, Oban 2.17,
Jason 1.2, Req 0.5, Hackney, Igniter, Earmark) is carried forward unchanged.

---

## Area 1 — Hex.pm First Publish (REL-01 through REL-06)

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `ex_doc` | `~> 0.34` (current: 0.40.3) | API docs generation + hexdocs.pm publish | Standard Elixir doc tool; `mix hex.publish` calls `mix docs` automatically; integrates with hexdocs.pm zero-config |
| `mix hex.publish` (built-in) | ships with Hex 2.2.1 | Publishes package + docs to hex.pm and hexdocs.pm | Authoritative publish path; publishes both package and docs in one step; `mix hex.publish docs` re-publishes docs only |

### Required mix.exs additions

`ex_doc` is a dev-only, no-runtime dependency:

```elixir
{:ex_doc, "~> 0.34", only: :dev, runtime: false}
```

`project/0` must add `source_url`, `homepage_url`, and a `docs/0` function:

```elixir
def project do
  [
    # existing fields ...
    source_url: "https://github.com/YOUR_ORG/cairnloop",
    homepage_url: "https://hexdocs.pm/cairnloop",
    docs: docs()
  ]
end

defp docs do
  [
    main: "readme",
    extras: ["README.md", "CHANGELOG.md"],
    source_ref: "v#{@version}"
  ]
end
```

`package/0` in `project/0` must include:

```elixir
package: [
  description: "Host-owned customer support automation library for Phoenix/Ecto apps.",
  licenses: ["Apache-2.0"],           # only REQUIRED field
  links: %{
    "GitHub" => "https://github.com/YOUR_ORG/cairnloop",
    "Changelog" => "https://github.com/YOUR_ORG/cairnloop/blob/main/CHANGELOG.md"
  }
]
```

Note: `:maintainers` is no longer required or recommended as of Hex 2.x.

### CHANGELOG tooling

**Decision: Hand-authored CHANGELOG.md following Keep a Changelog format.**

Rationale: Cairnloop's milestone-level release cadence (one hex.pm release per milestone, not per commit) is too coarse for automated tools like git-cliff or Release Please, which are optimized for conventional-commits-driven continuous delivery. The manual "Unreleased then move to version" section pattern from Keep a Changelog matches Cairnloop's workflow exactly and requires zero new dependencies.

git-cliff is the correct choice if the project moves to conventional-commits CI automation in a future milestone. Not needed for vM012.

### CI publish gate

Add a `HEX_API_KEY` secret to GitHub Actions. The release workflow should:
1. Require integration + standard CI jobs to pass (REL-01)
2. Trigger on `v*` semver tag push
3. Run `mix hex.publish --yes`

---

## Area 2 — Example Phoenix App (DEMO-01 through DEMO-04)

### Placement decision

**Decision: `example/` subdirectory within the cairnloop repo, NOT a separate repo, NOT an umbrella.**

Rationale:
- Sibling-separate-repo adds overhead (two repos to keep in sync, two CI configs, delayed updates when the library API changes).
- Umbrella adds structural complexity for no benefit on a 1-library project (confirmed by lotech.org Phoenix package dev guide: "I do not recommend this option. Umbrellas just make things extra complex for little to no gain.").
- `example/` subdirectory is the dominant pattern in the Elixir ecosystem for library demo apps. The directory is excluded from the published hex package via `files:` in `package/0`.

### Example app stack

The example app is a standalone Phoenix 1.8 application. Its `mix.exs` references the
library via a local path dependency during development, and via the published hex package
on main (DEMO-04):

```elixir
# example/mix.exs — during local development
{:cairnloop, path: ".."}

# example/mix.exs — after first hex.pm publish (main branch)
{:cairnloop, "~> 0.1"}
```

No extra libraries are needed beyond what a standard `mix phx.new` generates plus the
Cairnloop library itself.

### Exclude from hex package

Add to `mix.exs` `package`:

```elixir
files: ~w(lib priv mix.exs mix.lock README.md CHANGELOG.md LICENSE)
```

This explicitly excludes `example/`, `test/`, and CI config from the published tarball.

---

## Area 3 — MCP OAuth 2.0 Seam (MCP-02, MCP-03)

### What the spec requires

Per MCP spec 2025-11-25 (current spec as of research date, verified at modelcontextprotocol.io):

- The MCP server acts as an **OAuth 2.1 resource server only** — it validates tokens, it does NOT issue them.
- The authorization server (AS) is a separate concern — it may be the host app's existing Phoenix auth layer or a dedicated service.
- The MCP server MUST implement `/.well-known/oauth-protected-resource` (RFC 9728) OR include `WWW-Authenticate: Bearer resource_metadata="..."` on 401 responses.
- Token validation: verify Bearer token on every request, return 401 for missing/invalid, 403 for insufficient scope.
- PKCE (S256) is mandatory for the authorization code flow on the AS side.
- Tokens MUST be audience-bound to the MCP server URI (RFC 8707).

### OAuth library decision

**Decision: Roll the resource-server side using Joken + Plug, backed by an Ecto `McpToken` schema. Do NOT add Boruta, ExOauth2Provider, or Guardian.**

Rationale by option:

| Option | Assessment | Verdict |
|--------|-----------|---------|
| **boruta_auth** | Full OAuth AS + RS. Massive dependency: includes its own Ecto schemas, migrations, and LiveView admin surface. Overkill — Cairnloop needs only the RS half, and the host app owns the AS. | Reject — exceeds scope |
| **ex_oauth2_provider** | Full OAuth AS library (authorization code, client_credentials, refresh). Last release August 2023; maintenance uncertain. Requires AS role Cairnloop should not own. | Reject — stale + wrong role |
| **assent** | Multi-provider OAuth client framework for consuming OAuth services, not for being a resource server. | Reject — wrong role |
| **guardian** | JWT-based auth for Phoenix apps. Brings its own token store and refresh logic; would conflict with the host app's own auth layer. | Reject — too opinionated |
| **Joken ~> 2.6 + custom Plug** | Joken verifies JWT Bearer tokens (HS256/RS256). A thin `Cairnloop.Web.MCP.Auth` Plug validates the token and assigns claims; the host configures the signing key. Ecto-backed `McpToken` table stores issued/revoked state for revocation checks. Fits the "host-controlled token delegation" requirement in MCP-02. Zero new library dependencies beyond Joken. | **Accept** |

### New dependency

```elixir
{:joken, "~> 2.6"}
```

Joken current version: 2.6.2 (verified on hex.pm). Pulls `erlang-jose` transitively; no conflict with existing deps.

### What to build (not buy)

1. `Cairnloop.Web.MCP.Auth` — Plug that extracts `Authorization: Bearer <token>`, validates via `Joken.verify_and_validate/3`, returns 401/403 on failure, assigns `:mcp_claims` on success.
2. `Cairnloop.MCP.Token` — Ecto schema (`cairnloop_mcp_tokens`) with columns: `jti`, `subject`, `scopes`, `issued_at`, `expires_at`, `revoked_at`. Used for revocation lookup and durable audit (MCP-03).
3. `Cairnloop.Web.MCP.ProtectedResource` — Plug or controller action serving `/.well-known/oauth-protected-resource` JSON (RFC 9728 discovery endpoint).
4. Host-configured signing key: the library reads `config :cairnloop, :mcp_jwt_secret` — the host app provides the key. This is the "host-controlled token delegation" model.

### Protocol version note

The existing `Cairnloop.Web.MCP.Router` implements `"2025-03-26"`. The current MCP OAuth spec is versioned `"2025-11-25"`. The router's `@protocol_version` will need updating when the write surface and OAuth seam are added, as the newer protocol version introduces the resource server metadata requirements and formalizes the `tools/call` capability.

---

## Area 4 — MCP Write Tools / tools/call (ACT-02)

### What to build

The existing `Cairnloop.Web.MCP.Router` returns `-32601 Method not found` for `tools/call` (decision D17-06). vM012 lifts that restriction by adding a `tools/call` handler that routes through the governed-action approval pipeline.

**No new library is needed.** The implementation is additive to the existing Plug router:

1. Add `defp handle_method(conn, id, "tools/call", params)` to `Cairnloop.Web.MCP.Router`.
2. The handler calls `Cairnloop.Governance.propose/3` (already exists) using the tool name and arguments from the MCP params.
3. Returns a JSON-RPC result containing the `ToolProposal` ID and approval status — NOT the execution result (write tools remain governed; approval is async).
4. The `capabilities` response in `initialize` should declare `"tools" => %{"listChanged" => false}`. For write tools, no new capability flag is required — `tools/call` is part of the base MCP spec.

### hermes_mcp consideration

hermes_mcp (cloudwalk, v0.14.1) provides a complete MCP client+server SDK for Elixir. It is NOT recommended for Cairnloop because:
- Cairnloop's MCP Router is a thin Plug with explicit governed-tool dispatch — a direct architectural match to the library's security posture.
- hermes_mcp's dispatcher uses async Tasks for tool handlers, which would bypass the Oban-backed governed-action pipeline and the three-layer idempotency guarantee.
- Adding hermes_mcp would import ~10 transitive dependencies and an opinionated supervision tree on top of the existing library.
- The existing Plug-based router is ~80 LOC and proven in vM011; extending it is lower-risk than replacing it.

hermes_mcp is appropriate for projects that need a general-purpose MCP SDK from scratch. Cairnloop already has a custom, security-hardened implementation that must not be replaced.

---

## Recommended New Dependencies (mix.exs delta for vM012)

```elixir
# vM012 additions only
{:ex_doc, "~> 0.34", only: :dev, runtime: false},  # hex.pm docs publishing
{:joken, "~> 2.6"}                                  # MCP Bearer token validation (RS role)
```

Everything else is either built on existing deps (Plug, Ecto, Jason, Phoenix) or
hand-authored (CHANGELOG.md, example app, MCP router extension).

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| Joken + custom Plug for RS token validation | boruta_auth | Full AS+RS framework; massive dependency surface; Cairnloop is RS only |
| Joken + custom Plug for RS token validation | ex_oauth2_provider | Stale (last release Aug 2023); full AS role; wrong fit |
| Joken + custom Plug for RS token validation | guardian | Opinionated JWT auth for Phoenix apps; conflicts with host app's auth layer |
| `example/` subdirectory monorepo | Separate repo | Two-repo maintenance burden; delayed updates when library API changes |
| `example/` subdirectory monorepo | Umbrella project | Structural complexity, no benefit for 1-library case |
| Extend existing MCP Router Plug | hermes_mcp | Async task dispatch bypasses governed-action pipeline; adds ~10 transitive deps; existing 80-LOC router is proven |
| Manual Keep a Changelog CHANGELOG.md | git-cliff / Release Please | Optimized for conventional-commits CI cadence; overkill for milestone-level releases |

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `boruta_auth` | Full OAuth AS+RS server; Cairnloop is resource server only | Joken + custom `MCP.Auth` Plug |
| `ex_oauth2_provider` | Stale since Aug 2023; full AS scope; wrong role | Joken + thin Ecto token schema |
| `assent` | OAuth client framework (consuming OAuth), not resource server | N/A for this role |
| `guardian` | Phoenix app JWT auth; conflicts with host app's existing session model | Joken |
| `hermes_mcp` | Replaces proven Plug router; async dispatch bypasses governance pipeline | Extend existing `Cairnloop.Web.MCP.Router` |
| `phoenix_oauth2_provider` | Phoenix wrapper for ex_oauth2_provider; same staleness problem | N/A |

---

## Version Compatibility

| Package | Version | Elixir Constraint | Notes |
|---------|---------|------------------|-------|
| ex_doc | ~> 0.34 (0.40.3 current) | >= 1.15 | Cairnloop requires ~> 1.19; fully compatible |
| joken | ~> 2.6 (2.6.2 current) | >= 1.12 | Pulls erlang-jose; no conflict with existing deps |
| MCP spec | 2025-11-25 | N/A | Current spec; router `@protocol_version` needs update from "2025-03-26" |

---

## Sources

- https://hex.pm/docs/publish — Required/optional package metadata fields (HIGH)
- https://hexdocs.pm/ex_doc/readme.html — ExDoc 0.40.3 installation and config (HIGH)
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html — mix hex.publish workflow (HIGH)
- https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization — MCP OAuth spec, resource server requirements, RFC 9728, PKCE, token validation (HIGH)
- https://hexdocs.pm/joken/Joken.html — Joken 2.6.2 (HIGH)
- https://hexdocs.pm/hermes_mcp/readme.html — hermes_mcp 0.14.1; confirmed async Task dispatch model (HIGH)
- https://blog.lotech.org/configuring-a-dev-environment-for-phoenix-package-development.html — Example app placement; umbrella discouraged (MEDIUM)
- https://github.com/danschultzer/ex_oauth2_provider — ExOauth2Provider 0.5.7, last release Aug 2023 (HIGH)
- https://hex.pm/packages/joken — Joken version confirmation (HIGH)

---

*Stack research for: Cairnloop vM012 — Public Release & MCP Write Surface*
*Researched: 2026-05-25*
