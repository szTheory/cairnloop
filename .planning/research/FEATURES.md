# Feature Research: vM012 Public Release & MCP Write Surface

**Domain:** Elixir library first public release + example Phoenix app + MCP OAuth + MCP write tools
**Researched:** 2026-05-25
**Confidence:** HIGH (hex.pm/MCP official spec), MEDIUM (example app patterns, OAuth implementation), HIGH (MCP tools protocol)

---

## 1. Hex.pm First Publish (REL-01 through REL-06)

### What the Publish Workflow Looks Like

The standard v0.1.0 publish workflow (HIGH confidence — official hex.pm docs):

1. `mix hex.user register` (or `mix hex.user auth` if already registered) — one-time credential setup
2. Confirm email from Hex.pm (required before first publish)
3. Add `:description` and `:package` key to `mix.exs` (currently missing — see current mix.exs)
4. Add `ex_doc` as a dev dependency; add `:source_url` and `:homepage_url` to the project function
5. Run `mix hex.publish --dry-run` to validate locally (8MB compressed / 64MB uncompressed size limits)
6. Run `mix docs` locally to confirm ExDoc output is sane
7. Run `mix hex.publish` — publishes package + docs together; confirm prompt
8. New version can be reverted within 1 hour; initial publish is revocable within 24 hours

**Current mix.exs gap analysis:** The current `mix.exs` has no `:description`, no `:package` key, no `:source_url`, no `:homepage_url`, and no `ex_doc` dev dependency. All of these must be added.

### Required mix.exs Fields for hex.pm (HIGH confidence)

**Mandatory:**
- `:version` — already present (`"0.1.0"`)
- `:description` — one or two sentence package summary (currently absent)
- `:package` → `:licenses` — SPDX identifier list, e.g. `["MIT"]` (required; currently absent)

**Strongly recommended (functionally required for good listing):**
- `:package` → `:links` — map of named URLs (GitHub, Docs, etc.)
- `:package` → `:files` — defaults are sensible but should be verified; explicitly exclude test fixtures, planning/, prompts/ docs
- `:source_url` — GitHub URL (used by ExDoc for source links)
- `:homepage_url` — same or hex.pm URL

**ExDoc configuration (for hexdocs.pm auto-publish):**
- Add `{:ex_doc, "~> 0.34", only: :dev, runtime: false}` to deps
- Add `docs: [main: "Cairnloop", extras: ["README.md"]]` to project/0
- Docs auto-publish to hexdocs.pm when `mix hex.publish` runs; no separate step needed

### What a Good CHANGELOG.md Contains (MEDIUM confidence — Oban/hex examples)

Standard Elixir CHANGELOG format (keep-a-changelog style, widely adopted):

```
## [Unreleased]

## [0.1.0] — 2026-05-XX

### Milestone vM012 — Public Release & MCP Write Surface
- First public hex.pm release
- Runnable example Phoenix app (`examples/cairnloop_demo`)
- MCP OAuth 2.1 authorization code flow with host-controlled token delegation
- MCP write tools: governed tool invocations via MCP with full approval pipeline

### Milestone vM011 — AI Tool Governance & MCP Integration
...
```

Key conventions from major Elixir libraries (Oban, hex itself):
- Header format: `## vX.Y.Z — YYYY-MM-DD` (Oban style) or `## [X.Y.Z] — YYYY-MM-DD` (keep-a-changelog)
- Categories: `### Enhancements`, `### Bug Fixes`, `### Breaking Changes`
- Oban uses component tags like `[Repo]` or `[Worker]` prefix per entry
- CHANGELOG.md must exist at package root — hex.pm includes it in default `:files` glob (`CHANGELOG*`)
- ExDoc can render CHANGELOG.md as a page if added to `extras:` in docs config

---

## 2. Example Phoenix App (DEMO-01 through DEMO-04)

### What Popular Elixir Libraries Do (MEDIUM confidence — observed from live_svelte, Oban training, community patterns)

| Pattern | Library | Notes |
|---------|---------|-------|
| `example_project/` subdirectory in main repo | live_svelte | Full Phoenix app; `cd example_project && mix setup && mix phx.server` |
| Separate training repo (Livebook) | Oban | Not a Phoenix app; interactive notebooks for learning |
| Inline code snippets only | Most small libs | No runnable app; biggest adopter friction |
| `examples/` flat directory | Ecto, some others | Individual scripts, not full apps |

**Recommendation for Cairnloop: `examples/cairnloop_demo/` inside the main repo.** Rationale:
- Keeps demo co-located with the library code it demonstrates (version-locked)
- `cd examples/cairnloop_demo && mix setup && mix phx.server` is the industry-standard UX
- Separate repos require dual maintenance and can drift from library version
- Umbrella app is overkill for a demo — single Phoenix app with library as hex dep is the right abstraction

### What Makes a Good Library Example App

**Table stakes for a runnable demo:**

| Element | Why Expected | Notes |
|---------|--------------|-------|
| `mix setup` alias that does deps + DB create + migrate + seed | Adopters expect one command | Defined in mix.exs `aliases: ["setup": ["deps.get", "ecto.setup", "cmd npm install --prefix assets"]]` or similar |
| Seed script (`priv/repo/seeds.exs`) | Can't demo approval flows without data | Must seed at least: conversations, drafts, a pending ToolProposal, KB articles |
| README with config + integration steps | First thing adopters read | Must cover: library dep, config keys, required migrations, `mix setup`, `mix phx.server` |
| Reference library via published hex dep | Proves the package works from hex | `{:cairnloop, "~> 0.1"}` in demo mix.exs — not a path dep |
| End-to-end flow demo | Draft → approval → KB publish | The "aha moment" flow from conversation thread |

**Dependency pattern:** DEMO-04 requires REL-05 (published hex.pm) — the example app must reference `{:cairnloop, "~> 0.1"}` not `{:cairnloop, path: "../../"}`. This creates a hard phase ordering dependency: Phase 18 (publish) must complete before Phase 19 (example app) can finalize.

**What to seed:**
- 2–3 sample conversations with messages
- AI-drafted reply suggestions (pending/approved)
- 1 pending ToolProposal (InternalNote tool, awaiting operator approval)
- 2–3 KB articles (published)
- 1 KB gap signal with maintenance task

---

## 3. MCP OAuth 2.0/2.1 Seam (MCP-02, MCP-03)

### What the MCP Spec Specifies (HIGH confidence — official MCP specification)

The MCP spec (current draft as of 2026-05-25) specifies:

**Roles:**
- MCP server = OAuth 2.1 **resource server** (accepts/validates access tokens)
- MCP client = OAuth 2.1 **client** (obtains tokens on behalf of resource owner)
- Authorization server = separate entity or co-hosted (issues tokens); Cairnloop/Phoenix acts as both resource server AND authorization server in the host-owned model

**Hard requirements from spec:**
- MCP server MUST implement OAuth 2.0 Protected Resource Metadata (RFC9728)
- MCP server MUST return 401 with `WWW-Authenticate: Bearer resource_metadata="..."` header
- Authorization server MUST implement OAuth 2.1 (draft-ietf-oauth-v2-1-13)
- PKCE (Proof Key for Code Exchange) is MANDATORY — clients MUST verify PKCE support before proceeding
- Resource Indicators (RFC 8707) MUST be included in both authorization and token requests
- Authorization server MUST provide discovery via RFC8414 or OpenID Connect Discovery 1.0

**Discovery flow (standard MCP client → Cairnloop server):**
1. Client sends unauthenticated MCP request
2. Server returns `401 Unauthorized` + `WWW-Authenticate: Bearer resource_metadata="https://host/.well-known/oauth-protected-resource"`
3. Client fetches protected resource metadata → gets `authorization_servers` URL
4. Client fetches authorization server metadata at `/.well-known/oauth-authorization-server`
5. OAuth 2.1 authorization code + PKCE flow begins
6. Client gets access token; subsequent MCP requests carry `Authorization: Bearer <token>`

**Client registration options (priority order):**
1. Pre-registration (hardcoded client_id) — simplest for controlled deployments
2. Client ID Metadata Documents (CIMD) — preferred for unknown clients; client_id is an HTTPS URL pointing to a JSON metadata doc
3. Dynamic Client Registration (RFC7591) — backwards-compatible fallback

### Host-Controlled Token Delegation Pattern (MEDIUM confidence)

For Cairnloop's "host-owned" model, the authorization server is the Phoenix host app itself. This means:

- Phoenix app hosts both `/.well-known/oauth-protected-resource` and `/.well-known/oauth-authorization-server` endpoints
- Token issuance delegates to Phoenix session/user context — the MCP token is scoped to a specific operator/account identity already authenticated in Phoenix
- Token lifecycle (issue, validate, revoke) is backed by Ecto records (requirement MCP-03) — not in-memory JWT-only
- Unauthorized MCP requests return 401 (unauthenticated) or 403 (authenticated but not authorized)

**Elixir ecosystem options for OAuth provider (MEDIUM confidence):**
- `boruta_auth` — OpenID Connect certified, PKCE, authorization code flow; most complete but complex
- `ex_oauth2_provider` + `phoenix_oauth2_provider` — simpler, Ecto-backed, good Phoenix integration; PKCE may need manual extension
- Custom minimal implementation — viable because Cairnloop controls both client and server; scope is narrow (internal operator clients only, not open federation)

**Recommendation:** For vM012 scope (internal operator clients, single-tenant per host), a minimal custom implementation of the OAuth 2.1 authorization code + PKCE flow is appropriate. `ex_oauth2_provider` as a base is acceptable if full certification isn't required. Defer `boruta_auth` (full OIDC) unless external federation is needed.

### Token Lifecycle — Ecto-Backed (MCP-03)

Required Ecto records:
- `cairnloop_mcp_tokens` — issued access tokens (hashed), expiry, scope, operator_id, revoked_at
- `cairnloop_mcp_auth_codes` — short-lived authorization codes (cleared after exchange)
- Token validation: middleware plug on MCP router plug (not LiveView routes)
- Revocation: set `revoked_at`, check on every request

---

## 4. MCP Write Tools (MCP-03, ACT-02)

### How Write Tools Differ from Read Tools (HIGH confidence — official MCP spec)

At the protocol level, MCP does NOT distinguish read vs. write tools — all tools use `tools/call`. The difference is entirely in what the tool does and how the server handles it:

| Dimension | Read Tool | Write Tool |
|-----------|-----------|------------|
| Protocol method | `tools/call` | `tools/call` (identical) |
| Response shape | Immediate result in `content` | May be immediate OR deferred (pending approval) |
| `isError` field | false (success) or true (failure) | false even for "pending" states; error means protocol failure |
| Side effects | None (or idempotent) | Mutates state; requires idempotency guarantees |
| Approval required | Never | Depends on risk tier |
| MCP spec guidance | No confirmation needed | "SHOULD present confirmation prompts to user for operations" |

**Critical insight:** MCP itself has no approval primitive. The approval loop is entirely server-side — Cairnloop's governed-action contract handles it. From the MCP client's perspective, a write tool call either:
- Returns immediately with `isError: false` + result content (auto-approved or low-risk)
- Returns immediately with `isError: false` + a pending/queued acknowledgment payload (approval gating)
- Returns `isError: true` if the tool call is rejected, invalid, or unauthorized

### Well-Designed Write Tool Invocation-to-Approval Flow

The proven Cairnloop pattern (from vM011) maps onto MCP write calls as follows:

```
MCP Client  →  tools/call {name: "cairnloop_internal_note", arguments: {...}}
                         ↓
              Cairnloop.MCP.ToolsHandler
                         ↓
              Route to governed tool via Cairnloop.Tool registry
                         ↓
              Cairnloop.Governance.propose/3
              (creates ToolProposal, validates risk tier, checks approval_mode)
                         ↓
              If :auto_approve → ToolExecutionWorker → return result
              If :operator_approval_required → return "pending" acknowledgment
                         ↓ (async)
              Operator approves in LiveView UI (existing approval surface)
                         ↓
              ToolApproval state machine → resume → ToolExecutionWorker
                         ↓
              Result stored on ToolActionEvent (append-only)
```

**MCP response for pending-approval scenario:**
```json
{
  "jsonrpc": "2.0",
  "id": 42,
  "result": {
    "content": [{"type": "text", "text": "Action queued for operator approval. Proposal ID: proposal_abc123"}],
    "isError": false
  }
}
```

**Key design decisions for ACT-02:**
- The governed-tool contract (vM011) is unchanged — MCP is a translation layer, not a new execution path
- `ToolExecutionWorker` remains the sole `run/3` caller (carried decision from vM011)
- Write tool calls over MCP MUST carry a valid OAuth token; the token identity becomes the `actor_id` on the proposal
- Tools exposed via MCP should be a curated subset of governed tools — not all internal tools need MCP exposure
- `isError: true` is returned for: unknown tool name, invalid arguments, insufficient OAuth scope, policy rejection, missing approval mode

---

## Feature Landscape

### Table Stakes (Users/Adopters Expect These)

| Feature | Why Expected | Complexity | Dependency |
|---------|--------------|------------|------------|
| hex.pm package published (cairnloop) | Library is unusable if `mix deps.get` 404s | LOW | CI green (REL-01) |
| Semver tag + CHANGELOG.md | Standard library release hygiene | LOW | — |
| ExDoc docs on hexdocs.pm | Adopters look here first | LOW | ex_doc dep + mix.exs metadata |
| `mix hex.publish` dry-run passing | Proves release gate is closeable | LOW | `:package` key in mix.exs |
| Example app: `mix setup` + seed | One-command demo is the industry standard | MEDIUM | hex.pm publish (DEMO-04 needs REL-05) |
| Example app: end-to-end flow | Draft → approval → KB publish flow visible | MEDIUM | Seed data quality |
| Example app README | First adopter touchpoint | LOW | — |
| MCP OAuth: 401 + resource metadata | MCP spec compliance; clients expect this | MEDIUM | Ecto token records |
| MCP OAuth: token validation on write calls | Security table stakes | MEDIUM | Token lifecycle records |
| MCP write tools: `tools/call` → proposal pipeline | Core vM012 feature; builds on proven vM011 contract | HIGH | MCP-02 OAuth seam |

### Differentiators (Competitive Advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Host-controlled OAuth (no external IDP required) | Operators use their existing Phoenix auth; zero new service dependency | MEDIUM | Cairnloop authorizes within the host app's identity model |
| Write tool proposal returns stable Proposal ID | MCP clients can reference the pending action; enables async polling patterns | LOW | Emergent from existing proposal identity (carries forward from vM011) |
| Write tool result carries snapshotted trust facts | Audit trail shows who authorized what at what risk tier via MCP | LOW | Already on ToolProposal record; just surface in MCP response payload |
| Example app references published hex dep | Proves the real adoption path end-to-end | LOW | Requirement DEMO-04 — powerful signal to evaluators |

### Anti-Features (Do Not Build)

| Anti-Feature | Why Requested | Why Problematic | Alternative |
|--------------|---------------|-----------------|-------------|
| MCP async polling endpoint for pending approvals | "Clients need to know when approval completes" | Adds stateful long-poll/webhook surface; out of scope for vM012; Cairnloop's truth is in Ecto + LiveView | Return proposal ID in MCP response; polling/webhook is a vM013+ concern |
| OIDC full stack (ID tokens, userinfo endpoint) | "OAuth should be OIDC" | boruta_auth adds significant complexity; Cairnloop's MCP clients are internal operators, not external federation partners | OAuth 2.1 bearer tokens sufficient; defer OIDC to when external clients appear |
| Dynamic Client Registration (RFC7591) open to public | "Any MCP client should be able to register" | Security risk for a host-owned library; Cairnloop's MCP surface is operator-controlled | Pre-registration or CIMD with host-controlled allow-list |
| MCP tools for all governed actions | "Expose everything via MCP" | MCP surface expands blast radius; curated subset is safer | Expose only approved tool subset; hosts opt-in per tool |
| Example app as separate GitHub repo | "Easier to find" | Version drift; dual maintenance; adopters can't verify it matches the library version they're evaluating | `examples/cairnloop_demo/` in main repo, version-locked |
| Real-time MCP streaming for approval status | Seems like good UX | SSE/streaming add transport complexity; approval is async on operator timeline | Return pending acknowledgment; let LiveView UI drive approval; polling is acceptable for v1 |

---

## Feature Dependencies

```
REL-01 (CI green)
    └──required-by──> REL-03 (semver tag)
                          └──required-by──> REL-05 (hex.pm publish)
                                                └──required-by──> DEMO-04 (example app hex dep)
                                                                      └──required-by──> DEMO-02 (end-to-end flow)

REL-02 (CHANGELOG) ──required-for──> REL-05 (hex.pm publish)
REL-04 (package metadata in mix.exs) ──required-for──> REL-05

MCP-02 (OAuth seam: 401 + discovery + token issue)
    └──required-by──> MCP-03 (token lifecycle: Ecto records, validate, revoke)
                          └──required-by──> ACT-02 (MCP write tools: token identity → actor_id on proposal)

vM011 (ToolProposal + ToolApproval + ToolExecutionWorker) ──already-exists──> ACT-02 (MCP invokes existing pipeline)
```

### Dependency Notes

- **DEMO-04 requires REL-05:** Example app must `{:cairnloop, "~> 0.1"}` from hex.pm — path dep defeats the purpose. Phase 19 (example app) cannot finalize until Phase 18 (hex publish) completes.
- **ACT-02 requires MCP-02/MCP-03:** Write tool calls must carry valid OAuth tokens; token identity becomes actor on ToolProposal. Cannot implement write surface without auth enforcement.
- **ACT-02 does NOT require changes to vM011 contracts:** `ToolExecutionWorker`, `propose/3`, approval state machine are sealed. ACT-02 is a translation layer (MCP → governance facade), not a rewrite.
- **MCP-03 (token lifecycle) requires MCP-02 (OAuth endpoints):** Token table and validation logic emerge together in one phase.

---

## MVP Definition for vM012

### Launch With (v1 — all 4 phase groups)

- [x] REL: CI green, CHANGELOG, v0.1.0 tag, package metadata, hex.pm publish, hexdocs
- [x] DEMO: Runnable example app in `examples/cairnloop_demo/`, mix setup + seed + README, hex dep
- [x] MCP-02/03: OAuth 2.1 authorization code + PKCE, 401/403 enforcement, Ecto-backed token lifecycle
- [x] ACT-02: MCP `tools/call` → governed proposal pipeline (InternalNote as reference write tool)

### Add After Validation (v1.x — vM013+)

- MCP async polling / webhook for approval completion (when real adoption signals demand it)
- Additional governed tools exposed via MCP (beyond InternalNote)
- OIDC layer on top of OAuth 2.1 (only if external client federation is needed)
- Example app: multi-tenant / multi-operator demo

### Future Consideration (v2+)

- Dynamic Client Registration open to external clients (requires security review and federation policy)
- MCP streaming transport (SSE for real-time tool status)
- Batch write tool invocations via MCP

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| hex.pm publish (REL-05) | HIGH — adopters can't use unpublished lib | LOW — metadata + CI work | P1 |
| CHANGELOG.md (REL-02) | HIGH — release hygiene expectation | LOW — documentation work | P1 |
| Example app (DEMO-01..04) | HIGH — biggest current adopter gap | MEDIUM — Phoenix app + seed | P1 |
| MCP OAuth seam (MCP-02) | MEDIUM — enables write tools | HIGH — spec compliance, PKCE, discovery | P1 |
| Token lifecycle Ecto records (MCP-03) | MEDIUM — security requirement | MEDIUM — migrations + plug | P1 |
| MCP write tools (ACT-02) | MEDIUM — extends proven contract to MCP | MEDIUM — translation layer only | P1 |
| ExDoc/hexdocs (REL-06) | HIGH — standard adopter resource | LOW — ex_doc dep + config | P1 |
| MCP async polling for approval | LOW (v1 adopters can poll manually) | HIGH — new surface | P3 |
| Additional governed tools via MCP | LOW (InternalNote proves the pattern) | MEDIUM | P3 |

---

## Sources

- [Hex.pm publish documentation](https://hex.pm/docs/publish) — HIGH confidence
- [mix hex.publish task documentation](https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html) — HIGH confidence
- [MCP Authorization specification (draft)](https://modelcontextprotocol.io/specification/draft/basic/authorization) — HIGH confidence
- [MCP Tools specification](https://modelcontextprotocol.io/docs/concepts/tools) — HIGH confidence
- [live_svelte example_project pattern](https://github.com/woutdp/live_svelte) — MEDIUM confidence (observed pattern)
- [Oban training repo (Livebook pattern)](https://github.com/oban-bg/oban_training/) — MEDIUM confidence
- [ExMCP OAuth 2.1 implementation](https://github.com/azmaveth/ex_mcp) — MEDIUM confidence
- [ex_oauth2_provider](https://github.com/danschultzer/ex_oauth2_provider) — MEDIUM confidence
- [Token delegation and MCP orchestration](https://dev.to/stacklok/token-delegation-and-mcp-server-orchestration-for-multi-user-ai-systems-3gbi) — MEDIUM confidence
- [Boruta OAuth/OIDC for Elixir](https://hexdocs.pm/boruta/provider_integration.html) — MEDIUM confidence

---

*Feature research for: vM012 Public Release & MCP Write Surface*
*Researched: 2026-05-25*
