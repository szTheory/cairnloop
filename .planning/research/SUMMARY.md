# Research Summary — vM012: Public Release & MCP Write Surface

**Project:** Cairnloop
**Domain:** Elixir hex.pm library first publish + example app + MCP OAuth 2.1 + MCP write tools
**Researched:** 2026-05-25
**Confidence:** HIGH

---

## Executive Summary

vM012 has four distinct workstreams that must execute in strict dependency order. The release gate (hex.pm publish) is both the simplest workstream and the hardest constraint: a June 2, 2026 CI deadline means Phase 18 must ship first, before the example app or any MCP work begins. The work itself is low-complexity — primarily `mix.exs` metadata, ExDoc configuration, a CHANGELOG, and a CI release job — but the pre-publish checklist is long and any miss is expensive to undo after the 60-minute revert window closes.

The example app (Phase 19) is the highest-value adopter-facing deliverable: the current package is unpublished and there is no runnable demo. The architecture decision is settled — `examples/cairnloop_example/` subdirectory in the main repo, excluded from the published tarball via `files:` whitelist, referencing the library via a published hex dep (not a path dep). This requirement creates a hard ordering dependency: Phase 19 cannot finalize until Phase 18's hex.pm publish completes.

The MCP phases (20 and 21) are additive extensions to the proven vM011 foundation. Cairnloop's role is OAuth **resource server only** — it validates tokens, it does not issue them. Two new dependencies suffice for the entire milestone: `ex_doc ~> 0.34` (dev-only) and `joken ~> 2.6` for JWT validation. The core architectural invariant from vM011 is inviolable across vM012: all write-tool execution routes through `Cairnloop.Governance.propose/3` and `ToolExecutionWorker` — MCP is a translation layer, never a shortcut. The three sealed components (`Governance`, `ToolExecutionWorker`, `ToolActionEvent`) are not touched.

---

## Key Findings

### Recommended Stack

The existing stack (Elixir 1.19, Phoenix LiveView 1.0, Ecto/PostgreSQL, pgvector, Oban 2.17, Jason, Req, Igniter, Earmark) carries forward unchanged. vM012 adds exactly two dependencies:

**Core technologies (new for vM012):**
- `ex_doc ~> 0.34` (dev, no runtime): hex.pm docs — auto-publishes to hexdocs.pm when `mix hex.publish` runs; required for quality package listing
- `joken ~> 2.6`: JWT Bearer token validation — MCP OAuth resource-server role; pulls `erlang-jose` transitively with no conflicts

**Explicitly rejected:**
- `boruta_auth` — Full OAuth AS+RS; Cairnloop is RS only; massive scope expansion
- `ex_oauth2_provider` — Stale (Aug 2023); wrong role (AS not RS)
- `guardian` — Phoenix-app JWT auth; conflicts with host app identity model
- `hermes_mcp` — Replaces proven 80-LOC Plug router; async task dispatch bypasses governed-action pipeline
- `git-cliff` / Release Please — Overkill for milestone-level release cadence; manual CHANGELOG.md is correct

**Critical version note:** MCP protocol version must be bumped from `"2025-03-26"` to `"2025-11-25"` in `Cairnloop.Web.MCP.Router` when the OAuth seam is added (Phase 20). All production deps must use `"~> x.y"` (two-part) form, never `"~> x.y.z"` — this is a known first-publish landmine.

### Expected Features

**Must have (table stakes):**
- hex.pm package published as `cairnloop` — library is unusable otherwise
- `v0.1.0` semver tag + CHANGELOG.md — standard release hygiene; adopters expect it
- ExDoc API docs on hexdocs.pm — first place adopters look
- `mix hex.build` dry-run passing before publish
- Example app: `mix setup` + seed in one command — industry-standard UX
- Example app: end-to-end draft/approval/KB flow demo — the "aha moment"
- Example app README documenting config and integration steps
- Example app references `{:cairnloop, "~> 0.1"}` (hex dep, not path dep) — proves the real adoption path
- MCP OAuth: 401 + `WWW-Authenticate` + `/.well-known/oauth-protected-resource` — spec compliance
- MCP OAuth: Ecto-backed token lifecycle (issue, validate, revoke)
- MCP write tools: `tools/call` -> governed-proposal pipeline

**Should have (differentiators):**
- Host-controlled OAuth (no external IDP required) — operators use existing Phoenix auth identity
- MCP write tool response includes stable `proposal_id` — enables async polling and audit reference
- MCP write tool response includes snapshotted trust facts — audit trail of MCP-originated actions

**Defer (vM013+):**
- MCP async polling / webhook for approval completion
- Additional governed tools exposed via MCP (InternalNote proves the pattern)
- OIDC layer on OAuth 2.1 (only if external federation is needed)
- Dynamic Client Registration open to public (security review required)

### Architecture Approach

The milestone adds four groups of components in a linear dependency chain. Sealed vM011 components (`Cairnloop.Governance`, `ToolExecutionWorker`, `ApprovalResumeWorker`, `ToolProposal`, `ToolApproval`, `ToolActionEvent`) are not modified. New code wraps and extends; it does not rewrite.

**Major components:**
1. `mix.exs` package block + `CHANGELOG.md` + CI release job — hex.pm publish infrastructure (Phase 18)
2. `examples/cairnloop_example/` — standalone Phoenix app, subdirectory in repo, excluded from published tarball (Phase 19)
3. `Cairnloop.Web.MCP.Auth` (Plug) + `Cairnloop.MCP.Token` (Ecto schema) + `Cairnloop.MCP` (facade) + migration — OAuth resource-server token validation; stores `sha256(token)` only; returns 401/403; serves resource metadata endpoint (Phase 20)
4. `Cairnloop.Web.MCP.ToolCallHandler` — converts MCP JSON-RPC `tools/call` to `Governance.propose/3`; returns `proposal_id` + `status`; single added dispatch clause in the existing router (Phase 21)

**Key patterns locked in:**
- OAuth as Plug middleware only (Cairnloop is RS, not AS); host configures `:mcp_auth_server_url`
- Token hash storage: `sha256(raw_token)` in DB only; raw token returned once at issuance, never stored
- MCP string dispatch: `"tools/call"` stays a string — no `String.to_existing_atom` (carried constraint from D-19)
- `conn.private` (not `conn.assigns`) for MCP actor/scopes to avoid collision with host assigns
- MCP write handler returns `proposal_id` + `status: "proposed"` synchronously; execution is async via Oban

### Critical Pitfalls

1. **MCP write bypasses governance pipeline** — Wiring `tools/call` directly to `Tool.run/3` instead of `Governance.propose/3`. Bypasses idempotency, approval state machine, policy checks, and audit trail. Prevention: first line of Phase 21 CONTEXT.md must state this as a hard constraint; integration test must assert every MCP write call produces a `ToolProposal` row.

2. **Hex publish with git deps or three-part version constraints** — `mix hex.publish` hard-fails on git deps; three-part `"~> x.y.z"` constraints trigger adopter dependency conflicts within days. Prevention: run `mix hex.build` first; audit all deps before the release tag is pushed.

3. **One-hour publish revert window** — v0.1.0 mistakes cannot be quietly retracted after 60 minutes. Prevention: mandatory `mix hex.build` dry-run, tarball inspection, and smoke-test in a scratch Phoenix app before announcing.

4. **MCP write double-approval on retry** — Without an explicit `proposal_id` in the response, MCP clients retry and create duplicate proposals. Prevention: include `proposal_id` + `"pending_approval"` status in every response; extend one-active-lane invariant to include an MCP request idempotency key.

5. **OAuth scope bleeding** — A valid MCP token authorizes actions the underlying host actor cannot perform in the Phoenix UI. Prevention: thread host actor identity from the delegation token into `Governance.propose/3`; the governance pipeline's existing policy check at propose time closes the gap.

---

## Implications for Roadmap

Four phases in strict dependency order: 18 -> 19 -> 20 -> 21.

### Phase 18: Hex.pm Release

**Rationale:** Hard June 2, 2026 CI deadline; no code dependencies on other vM012 phases; must ship before the example app can reference a published hex dep; lowest risk (pure config and documentation).

**Delivers:** CI-clean `v0.1.0` tagged and published to hex.pm; ExDoc docs on hexdocs.pm; `mix hex.build` dry-run passing; CHANGELOG.md covering vM009-vM012; README updated with hex badge and install snippet; GitHub Actions release job on `v*` tag push.

**Addresses:** REL-01, REL-02, REL-03, REL-04, REL-05, REL-06

**Avoids:**
- Git deps or three-part version constraints in `mix.exs` (Pitfalls 1, 3)
- Missing `:description`, `:licenses`, `:links` metadata (Pitfall 5)
- Publishing `examples/`, `test/`, `.planning/`, `prompts/` in the tarball (Pitfall 6)
- Skipping `@moduledoc false` audit (Pitfall 2)
- Skipping the dry-run + tarball inspection step before `mix hex.publish` (Pitfall 6)

**Research flag:** Standard patterns — no additional research needed.

---

### Phase 19: Example Phoenix App

**Rationale:** Highest-value adopter-gap closer after hex publish; no dependency on MCP phases; builds immediately after publish to verify the published package installs and integrates correctly end-to-end.

**Delivers:** `examples/cairnloop_example/` with `mix setup` alias, seed script (2-3 conversations, pending ToolProposal, KB articles), end-to-end draft/approval/KB flow demo, README documenting config and integration steps, references `{:cairnloop, "~> 0.1"}` (not path dep).

**Addresses:** DEMO-01, DEMO-02, DEMO-03, DEMO-04

**Avoids:**
- Path dep in final merged example app — `mix deps.tree` must show hex dep (Pitfall 7)
- Scope creep: define `SCOPE.md` before writing code (Pitfall 8)
- Referencing `Cairnloop.*` internal modules from example app code — run PrivCheck (Pitfall 2)

**Research flag:** Standard patterns — example app structure and `mix setup` alias pattern are well-documented.

---

### Phase 20: MCP OAuth Seam

**Rationale:** OAuth token validation (`conn.private[:mcp_actor_id]`, `conn.private[:mcp_scopes]`) is a code dependency of Phase 21's `ToolCallHandler`. Must precede write tools. No dependency on Phase 19.

**Delivers:** `Cairnloop.Web.MCP.Auth` Plug; `Cairnloop.MCP.Token` Ecto schema (`token_hash` sha256, `actor_id`, `scopes`, `expires_at`, `revoked_at`); `Cairnloop.MCP` facade; migration for `cairnloop_mcp_tokens`; MCP protocol version bumped to `"2025-11-25"` in router.

**Addresses:** MCP-02, MCP-03

**Avoids:**
- Token accepted from query parameter — `Authorization: Bearer` header only (Pitfall 9)
- Raw token storage — store only `sha256(raw_token)` (Architecture anti-pattern 3)
- JWT validation without leeway — clock skew causes spurious 401s in containers (Pitfall 12)
- JWT validation without `aud` and `iss` claim checks — RFC 8707 requirement (Pitfall 11)
- PKCE with `plain` transform — `S256` only; in-flight state needs TTL and must be deleted on first use (Pitfall 10)
- Generic `tools:write` scope — use tool-scoped `cairnloop:tool:{name}:invoke` from day one (Pitfall 11)
- Refresh tokens without rotation and family revocation (Pitfall 16)

**Research flag:** Needs careful pre-read of STACK.md Area 3 and PITFALLS.md Pitfalls 9-12 and 16 before writing the implementation plan. MCP spec 2025-11-25 authorization has multiple non-obvious requirements. Recommend `--research-phase` flag during planning.

---

### Phase 21: MCP Write Tools

**Rationale:** Builds on Phase 20's `conn.private` auth context; extends the existing MCP Router with a single new dispatch clause; delegates entirely to the proven vM011 Governance pipeline. Smallest code surface of the four phases.

**Delivers:** `Cairnloop.Web.MCP.ToolCallHandler`; single `tools/call` dispatch clause added to `Cairnloop.Web.MCP.Router`; `InternalNote` as reference write tool exposed via MCP; capabilities response updated to declare `"tools" => %{"listChanged" => false}`.

**Addresses:** ACT-02

**Avoids:**
- Calling `Tool.run/3` or `ToolExecutionWorker` directly — must route through `Governance.propose/3` always (Pitfall 13, Architecture anti-pattern 2)
- Returning `isError: true` for "pending approval" — `isError` is for protocol failures, not async states
- Missing idempotency key on MCP-originated proposals — duplicate MCP calls must return the existing proposal (Pitfall 14)
- Synthetic or nil actor in `propose/3` — must use host actor from delegation token (Pitfall 15)
- Converting MCP method strings to atoms — string dispatch is a carried security constraint

**Research flag:** Standard patterns — thin translation layer over sealed vM011 code. Main planning focus is idempotency key design and integration test coverage.

---

### Phase Ordering Rationale

- Phase 18 first: June 2 CI deadline is hard; DEMO-04 hex-dep requirement is a code dependency
- Phase 19 second: no dependency on MCP phases; proves the published package immediately; closes the biggest adopter gap
- Phase 20 before 21: `ToolCallHandler` reads `conn.private` set by `MCP.Auth` — code dependency
- Phases 19 and 20 are independent of each other; linear order avoids context-switching cost
- Phase 21 last: smallest surface area; builds on everything else; sealed vM011 contracts guarantee no regressions

### Research Flags

**Needs `--research-phase` during planning:**
- **Phase 20 (MCP OAuth):** MCP spec 2025-11-25 authorization has multiple non-obvious requirements (RFC 9728 resource metadata, RFC 8707 audience binding, PKCE S256 mandate, refresh token rotation). High-consequence security decisions should be double-checked before the implementation plan is written.

**Standard patterns (skip research-phase):**
- **Phase 18 (Hex Release):** Official hex.pm docs are complete and authoritative. All decisions documented in STACK.md and ARCHITECTURE.md.
- **Phase 19 (Example App):** Example app subdirectory pattern is ecosystem-standard. Seed data design is implementation detail.
- **Phase 21 (MCP Write Tools):** Thin translation layer over sealed vM011 code. No new protocol surface; all patterns established by Phase 20.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All claims verified against official hex.pm docs, MCP spec 2025-11-25, and hex.pm package pages. Dependency rejections backed by primary source evidence. |
| Features | HIGH | hex.pm requirements from official docs; MCP spec requirements from official spec. Example app patterns from live ecosystem observation. Feature prioritization consistent across all four research files. |
| Architecture | HIGH | Canonical build order matches dependency graph. Component boundaries derived from MCP spec RS/AS split and vM011's sealed contracts. Example app placement is ecosystem-standard. |
| Pitfalls | HIGH | Critical pitfalls verified against primary sources. OAuth/JWT pitfalls cross-checked against MCP spec, RFC 8707, and multiple secondary sources. |

**Overall confidence:** HIGH

### Gaps to Address

- **Refresh token rotation schema design:** Phase 20 planner must decide whether to include `oauth_states` and `refresh_tokens` tables in the initial migration or scope them to a follow-on. Recommendation: include them in Phase 20 to avoid a schema migration mid-v1.x.

- **MCP request idempotency key convention:** Deduplication of MCP-originated `ToolProposal` records uses `params["_idempotency_token"]` — a custom convention, not in the MCP spec. Phase 21 planner should decide whether to document this as required client behavior or derive the key from MCP request `id` + actor hash instead.

- **`mix hex.search cairnloop` pre-publish check:** Must be run before Phase 18 execution begins to verify the package name is unclaimed. One-time manual step; record the result in Phase 18 CONTEXT.md before writing code.

---

## Sources

### Primary (HIGH confidence)

- https://hex.pm/docs/publish — hex.pm publish requirements, metadata fields, revert window
- https://hexdocs.pm/ex_doc/readme.html — ExDoc 0.40.3 configuration
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html — `mix hex.publish` flags and CI workflow
- https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization — MCP OAuth spec: RS requirements, RFC 9728, PKCE, token validation
- https://hexdocs.pm/joken/Joken.html — Joken 2.6.2 API
- https://hexdocs.pm/elixir/library-guidelines.html — dep version constraint form
- https://www.rfc-editor.org/rfc/rfc8707.html — RFC 8707 audience binding requirement
- https://hexdocs.pm/elixir/writing-documentation.html — `@moduledoc false` semantics

### Secondary (MEDIUM confidence)

- https://github.com/woutdp/live_svelte — example app subdirectory pattern
- https://blog.lotech.org/configuring-a-dev-environment-for-phoenix-package-development.html — umbrella project discouraged for library demos
- https://www.practical-devsecops.com/mcp-oauth-2-1-implementation/ — PKCE verifier storage pitfalls, scope design
- https://www.descope.com/blog/post/mcp-vulnerabilities — scope bleeding, write surface risks
- https://docs.gostoa.dev/blog/oauth-pkce-mcp-gateway — clock skew, refresh token family revocation
- https://hexdocs.pm/hermes_mcp/readme.html — hermes_mcp async task dispatch model (confirmed not suitable)
- https://hexdocs.pm/priv_check/readme.html — catching internal module usage in consumers
- https://github.com/danschultzer/ex_oauth2_provider — confirmed stale (Aug 2023 last release)

---

*Research completed: 2026-05-25*
*Ready for roadmap: yes*
