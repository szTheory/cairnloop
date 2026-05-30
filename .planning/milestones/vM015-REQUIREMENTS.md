# Requirements: Cairnloop — Milestone vM015 Operator Polish + Maintenance Gates (ARCHIVED)

**Defined:** 2026-05-29 · **Shipped:** 2026-05-30 · **Status:** ✅ COMPLETE (archived at milestone close)
**Core Value:** Close the operator-facing rough edges and remaining security debt from vM010 to bring the library to "done enough for stated scope".

**Milestone goal:** A comprehensive operator settings and audit surface is shipped alongside production-grade health endpoints, final domain-layer security closure, expanded guides, and the v0.2.0 package release.

**Outcome:** All 17 v1 requirements satisfied. Released as `cairnloop` v0.2.0, then remediated to
v0.2.1 (AUDIT-01, OPS-01/02, REL-01) and v0.2.2 (integration-suite green + governance fix) on
Hex.pm via the new release-please pipeline.

## v1 Requirements

### Security Domain Closure (T-10-10, T-10-12, T-10-13)

- [x] **SEC-01**: Close T-10-10 - `Cairnloop.KnowledgeAutomation` strictly reuses only non-published authoring targets for new-article suggestions.
- [x] **SEC-02**: Close T-10-12 - `Cairnloop.KnowledgeAutomation` builds gap-candidate grounding exclusively from hydrated candidate evidence, removing caller-supplied grounding bypasses on that path.
- [x] **SEC-03**: Close T-10-13 - `Cairnloop.KnowledgeAutomation` loads stale-gate inputs strictly from repo-backed `GapEvent` rows plus fresh canonical grounding inside the domain, rejecting externally spoofed inputs.

### Operator Settings Surface

- [x] **SET-01**: `SettingsLive` provides a real interface for managing MCP tokens (CRUD, masking, validation), replacing placeholder/SLA-only settings.
- [x] **SET-02**: `SettingsLive` visually surfaces the current health/reachability of configured Notifiers.
- [x] **SET-03**: `SettingsLive` visually surfaces the health/status of the retrieval system (pgvector index status + Oban failed-queue jobs).
- [x] **SET-04**: `SettingsLive` provides a dark mode toggle that persists the operator's theme preference and updates the UI instantly.

### Audit & Operations Support

- [x] **AUDIT-01**: A new `AuditLogLive` view provides operators with a searchable, filterable timeline of `Cairnloop.Auditor` events. *(Shipped as no-op stub at v0.2.0; repaired to a functional, humanized, facade-backed timeline in v0.2.1; action-filter options humanized in v0.2.2.)*
- [x] **OPS-01**: The application exposes a standard `/health` HTTP endpoint for adopter infrastructure monitoring. *(Plug existed but was unrouted at v0.2.0; mountable via `cairnloop_operations/1` as of v0.2.1.)*
- [x] **OPS-02**: The application exposes a standard `/metrics` HTTP endpoint (Telemetry/Prometheus format). *(Same remediation as OPS-01 in v0.2.1.)*
- [x] **TECH-01**: The governed-actions rail (sidebar) implements pagination (AR-14-02 closure) to gracefully handle high action/outbound volume without unbounded DOM growth.

### Documentation & v0.2.0 Release

- [x] **DOC-01**: ExDoc `guides/05-mcp-clients.md` authored (connecting/using MCP clients).
- [x] **DOC-02**: ExDoc `guides/06-extending.md` authored (custom adapters and extension `@callback`s).
- [x] **DOC-03**: Root `CONTRIBUTING.md` added.
- [x] **DOC-04**: `docs/architecture.md` authored for adopters needing deeper internals.
- [x] **REL-01**: `CHANGELOG.md` updated for the milestone surface area. *(`## [0.2.0]` section was missing at v0.2.0 release despite the summary claiming otherwise; written in v0.2.1.)*
- [x] **REL-02**: The release tag is cut and pushed, triggering the release workflow. *(v0.2.0 → v0.2.1 → v0.2.2 published to Hex.pm via release-please.)*

## Traceability

| Requirement | Phase | Status | Outcome |
|-------------|-------|--------|---------|
| SEC-01 | 33 | ✅ Complete | Validated — domain already enforced; regression tests added |
| SEC-02 | 33 | ✅ Complete | Validated — caller grounding overwritten + stripped |
| SEC-03 | 33 | ✅ Complete | Validated — repo-backed GapEvent + canonical grounding only |
| SET-01 | 34 | ✅ Complete | MCP token CRUD, masking, validation |
| SET-02 | 34 | ✅ Complete | Notifier reachability surfaced |
| SET-03 | 34 | ✅ Complete | pgvector + Oban failed-queue health |
| SET-04 | 34 | ✅ Complete | Persisted dark-mode toggle, no JS hook |
| AUDIT-01 | 35 | ✅ Complete | Repaired in v0.2.1 (was no-op stub at v0.2.0); humanized in v0.2.2 |
| OPS-01 | 35 | ✅ Complete | Mountable via `cairnloop_operations/1` (v0.2.1) |
| OPS-02 | 35 | ✅ Complete | Mountable via `cairnloop_operations/1` (v0.2.1) |
| TECH-01 | 35 | ✅ Complete | `:limit` + `load_more_actions` pagination |
| DOC-01 | 36 | ✅ Complete | guides/05-mcp-clients.md |
| DOC-02 | 36 | ✅ Complete | guides/06-extending.md |
| DOC-03 | 36 | ✅ Complete | CONTRIBUTING.md |
| DOC-04 | 36 | ✅ Complete | docs/architecture.md |
| REL-01 | 36 | ✅ Complete | CHANGELOG `[0.2.0]` written in v0.2.1 |
| REL-02 | 36 | ✅ Complete | v0.2.0/0.2.1/0.2.2 published via release-please |

**Coverage:**
- v1 requirements: 17 total
- Mapped to phases: 17
- Satisfied: 17 ✓ (4 via post-v0.2.0 remediation)
- Unmapped: 0 ✓
