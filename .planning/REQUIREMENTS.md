# Requirements — vM012 Public Release & MCP Write Surface

**Milestone:** vM012
**Status:** Active
**Created:** 2026-05-25

## v1 Requirements

### Release (REL)

- [ ] **REL-01** — CI passes on main branch (both integration and standard jobs green before tagging)
- [ ] **REL-02** — CHANGELOG.md covers vM009–vM012 with dates and feature summaries
- [ ] **REL-03** — v0.1.0 semver tag created and pushed to origin
- [ ] **REL-04** — mix.exs package metadata complete: `:description`, `:package` block with `:licenses`, `:links`, `:maintainers`; `:source_url`; `:homepage_url`; `:docs` block pointing at ExDoc
- [ ] **REL-05** — Package published to hex.pm and available at hex.pm/packages/cairnloop
- [ ] **REL-06** — ExDoc configured; API docs published to hexdocs.pm alongside the hex release

### Example App (DEMO)

- [ ] **DEMO-01** — Example Phoenix app at `examples/cairnloop_example/` boots with a single `mix setup` + seed command
- [ ] **DEMO-02** — Example app demonstrates draft/approval/KB flow end-to-end in the browser
- [ ] **DEMO-03** — Example app README documents how to add cairnloop to a host app and configure it
- [ ] **DEMO-04** — Example app references `{:cairnloop, "~> 0.1"}` published hex dependency (not path dep); verified by CI `mix deps.tree`

### MCP OAuth Seam (MCP)

- [ ] **MCP-02** — MCP server validates OAuth 2.1 Bearer tokens; unauthenticated write requests return 401 + `WWW-Authenticate` header with RFC 9728 resource-metadata pointer
- [ ] **MCP-03** — OAuth token lifecycle (issue, validate, revoke) is Ecto-backed (SHA-256 hash stored, never raw); `/.well-known/oauth-protected-resource` endpoint served per RFC 9728

### MCP Write Tools (ACT)

- [ ] **ACT-02** — MCP clients invoke write-capable governed tools via `tools/call`; every call creates a `ToolProposal` via `Governance.propose/3` (never calls `Tool.run/3` directly)
- [ ] **ACT-03** — MCP write responses include `proposal_id` + `"pending_approval"` status; duplicate calls within the approval window return the existing proposal (one-active-lane idempotency extended to MCP origination)

## Future Requirements

*(Deferred to vM013 or later, pending adoption signals)*

- Broad external MCP server surface for third-party public clients (Dynamic Client Registration open to untrusted clients)
- MCP async polling / webhook callbacks for long-running approval workflows
- OIDC full-stack or external IDP federation for MCP OAuth
- Additional governed-tool types beyond `InternalNote` (FLOW-04; deferred until vM012 adoption signals)
- Pagination for the governed-actions rail (AR-14-02; re-evaluate at scale)

## Out of Scope

| Excluded | Reason |
|---------|--------|
| Calling `Tool.run/3` directly from MCP handlers | Violates governed-action contract; bypasses idempotency, approval state machine, policy, and audit trail |
| MCP server acting as OAuth authorization server | Cairnloop is resource server only; host app or external IDP issues tokens |
| High-risk financial or destructive mutations via MCP write | Trust is not yet established with external MCP clients |
| Autonomous customer-visible replies from MCP write | Operator approval required for all write actions |
| Replacing Phoenix/Ecto/Oban workflow truth with MCP-owned runtime | Core execution model is sealed and unchanging |
| Example app in a separate repo | Increases sync burden; `examples/` subdirectory is the idiomatic pattern |

## Traceability

| Req ID | Phase | Status |
|--------|-------|--------|
| REL-01 | Phase 18 | Pending |
| REL-02 | Phase 18 | Pending |
| REL-03 | Phase 18 | Pending |
| REL-04 | Phase 18 | Pending |
| REL-05 | Phase 18 | Pending |
| REL-06 | Phase 18 | Pending |
| DEMO-01 | Phase 19 | Pending |
| DEMO-02 | Phase 19 | Pending |
| DEMO-03 | Phase 19 | Pending |
| DEMO-04 | Phase 19 | Pending |
| MCP-02 | Phase 20 | Pending |
| MCP-03 | Phase 20 | Pending |
| ACT-02 | Phase 21 | Pending |
| ACT-03 | Phase 21 | Pending |

---
*Last updated: 2026-05-25 — vM012 roadmap created; traceability table updated with phase assignments and Pending status*
