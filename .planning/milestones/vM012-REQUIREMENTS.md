# Requirements Archive: Cairnloop vM012 Public Release & MCP Write Surface

**Status:** ✅ ARCHIVED — shipped 2026-05-26 (backfilled 2026-05-27)
**Defined:** 2026-05-25
**All v1 requirements:** COMPLETE

---

## v1 Requirements (All Satisfied)

### Release Engineering (REL)

- [x] **REL-01**: CI passes on `main` (compile, tests, credo/dialyzer where applicable).
  _→ Validated Phase 18: existing CI workflow green; release workflow added without breaking main pipeline._
- [x] **REL-02**: `CHANGELOG.md` follows Keep-a-Changelog and covers the v0.1.0 release.
  _→ Validated Phase 18: v0.1.0 entry added at release time._
- [x] **REL-03**: v0.1.0 semver tag pushed and surfaced in git history.
  _→ Validated Phase 18: `v0.1.0` annotated tag exists (`docs(18): complete plans 02 and 03`, 2026-05-25)._
- [x] **REL-04**: `mix.exs` package metadata complete (description, licenses, links, files).
  _→ Validated Phase 18: package metadata configured for Hex.pm publish._
- [x] **REL-05**: Package published to Hex.pm via automated CI on `v*` tag push.
  _→ Validated Phase 18: `.github/workflows/release.yml` automates publish; v0.1.0 live on hex.pm._
- [x] **REL-06**: ExDoc configured with semantic module groups and docs published alongside the package.
  _→ Validated Phase 18: ExDoc groups configured; docs pushed by release workflow._

### Demo / Example Host (DEMO)

- [x] **DEMO-01**: Example Phoenix app boots with `mix setup` and exercises the core support loop.
  _→ Validated Phase 19: `examples/cairnloop_example` boots; pgvector extension + host + library migrations run; seeds insert demo conversation + message + article + revision._
- [x] **DEMO-02**: Example app demonstrates the dashboard mount and a mock customer chat surface.
  _→ Validated Phase 19: dashboard at `/support`, `ChatLive` at `/chat`._
- [x] **DEMO-03**: Example app documentation is complete (setup, configuration, integration, routing).
  _→ Validated Phase 19: README rewritten; documents setup + Oban + cairnloop integration + dashboard macro caveat._
- [x] **DEMO-04**: Example app references the published Hex dependency (not a path dep) once v0.1.0 is live.
  _→ Validated Phase 19: example app consumes published `cairnloop` package._

### MCP OAuth Seam (MCP)

- [x] **MCP-02**: MCP server validates OAuth Bearer tokens on `tools/call` and serves RFC 9728 resource-metadata at the well-known endpoint.
  _→ Validated Phase 20: `AuthPlug` + Router 401 guard on `tools/call`; `WellKnownPlug` serves RFC 9728 metadata from application env._
- [x] **MCP-03**: Ecto-backed OAuth token lifecycle with SHA-256 hashing (issue / validate / revoke).
  _→ Validated Phase 20: `cairnloop_mcp_tokens` table; `Cairnloop.MCP` context with `issue_token/1`, `validate_token/1`, `revoke_token/1`; tokens stored as hashes, never plaintext._

### MCP Write Tools (ACT)

- [x] **ACT-02**: MCP clients can invoke write-capable tools — every invocation goes through `Governance.propose/3`, never inline execution.
  _→ Validated Phase 21: `handle_method(_, "tools/call", _, _)` calls `Cairnloop.Governance.propose/3` with `origin: :mcp` context._
- [x] **ACT-03**: MCP write responses include `proposal_id` and support idempotency keys end-to-end.
  _→ Validated Phase 21: response carries `proposal.id` + status; idempotency-key reuse returns the same proposal; integration tests pin behavior against real pgvector._

---

## Traceability Table

| Requirement | Phase | Status |
|-------------|-------|--------|
| REL-01 | Phase 18 | ✅ Complete |
| REL-02 | Phase 18 | ✅ Complete |
| REL-03 | Phase 18 | ✅ Complete |
| REL-04 | Phase 18 | ✅ Complete |
| REL-05 | Phase 18 | ✅ Complete |
| REL-06 | Phase 18 | ✅ Complete |
| DEMO-01 | Phase 19 | ✅ Complete |
| DEMO-02 | Phase 19 | ✅ Complete |
| DEMO-03 | Phase 19 | ✅ Complete |
| DEMO-04 | Phase 19 | ✅ Complete |
| MCP-02 | Phase 20 | ✅ Complete |
| MCP-03 | Phase 20 | ✅ Complete |
| ACT-02 | Phase 21 | ✅ Complete |
| ACT-03 | Phase 21 | ✅ Complete |

**Coverage: 14/14 v1 requirements satisfied.**

---

## Out of Scope (vM012)

- Broad external MCP server surface open to untrusted third-party public clients.
- High-risk financial or destructive mutations as the first governed-action path.
- Library-side `cairnloop_dashboard` macro `live/3` import fix (host expansion works for 0.1.0).
- Marketing/Newsletter drip campaigns (carried forward — out of scope project-wide).

---

_Requirements defined: 2026-05-25_
_Archived (backfilled): 2026-05-27 — all 14 v1 requirements satisfied across Phases 18–21_
