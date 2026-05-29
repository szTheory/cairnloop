# Requirements: Cairnloop — Milestone vM015 Operator Polish + Maintenance Gates

**Defined:** 2026-05-29
**Core Value:** Close the operator-facing rough edges and remaining security debt from vM010 to bring the library to "done enough for stated scope".

**Milestone goal:** A comprehensive operator settings and audit surface is shipped alongside production-grade health endpoints, final domain-layer security closure, expanded guides, and the v0.2.0 package release.

## v1 Requirements

Requirements for the vM015 release. Each maps to exactly one roadmap phase.

### Security Domain Closure (T-10-10, T-10-12, T-10-13)

- [ ] **SEC-01**: Close T-10-10 - `Cairnloop.KnowledgeAutomation` strictly reuses only non-published authoring targets for new-article suggestions.
- [ ] **SEC-02**: Close T-10-12 - `Cairnloop.KnowledgeAutomation` builds gap-candidate grounding exclusively from hydrated candidate evidence, completely removing caller-supplied grounding bypasses on that path.
- [ ] **SEC-03**: Close T-10-13 - `Cairnloop.KnowledgeAutomation` loads stale-gate inputs strictly from repo-backed `GapEvent` rows plus fresh canonical grounding inside the domain, rejecting externally spoofed inputs.

### Operator Settings Surface

- [ ] **SET-01**: `SettingsLive` provides a real interface for managing MCP tokens (CRUD, masking, validation), replacing placeholder/SLA-only settings.
- [ ] **SET-02**: `SettingsLive` visually surfaces the current health/reachability of configured Notifiers.
- [ ] **SET-03**: `SettingsLive` visually surfaces the health/status of the retrieval system (e.g., pgvector index status).
- [ ] **SET-04**: `SettingsLive` provides a dark mode toggle that persists the operator's theme preference and updates the UI instantly.

### Audit & Operations Support

- [ ] **AUDIT-01**: A new `AuditLogLive` view provides operators with a searchable, filterable timeline of `Cairnloop.Auditor` events.
- [ ] **OPS-01**: The application exposes a standard `/health` HTTP endpoint for adopter infrastructure monitoring (liveness/readiness probes).
- [ ] **OPS-02**: The application exposes a standard `/metrics` HTTP endpoint (e.g., Telemetry/Prometheus format) for system observability.
- [ ] **TECH-01**: The governed-actions rail (sidebar) implements pagination (AR-14-02 closure) to gracefully handle high action/outbound volume without unbounded DOM growth.

### Documentation & v0.2.0 Release

- [ ] **DOC-01**: ExDoc `guides/05-mcp-clients.md` is authored, explaining how to connect and use MCP clients.
- [ ] **DOC-02**: ExDoc `guides/06-extending.md` is authored, covering custom adapters and extensions.
- [ ] **DOC-03**: Root `CONTRIBUTING.md` is added to guide external maintainers/adopters.
- [ ] **DOC-04**: `docs/architecture.md` is authored for adopters needing deeper internals.
- [ ] **REL-01**: `CHANGELOG.md` is updated with a summary of the vM015 surface area (settings, audit, security closure, metrics).
- [ ] **REL-02**: The v0.2.0 tag is cut and pushed, triggering the release workflow.

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SEC-01 | Phase 33 | Pending |
| SEC-02 | Phase 33 | Pending |
| SEC-03 | Phase 33 | Pending |
| SET-01 | Phase 34 | Pending |
| SET-02 | Phase 34 | Pending |
| SET-03 | Phase 34 | Pending |
| SET-04 | Phase 34 | Pending |
| AUDIT-01 | Phase 35 | Pending |
| OPS-01 | Phase 35 | Pending |
| OPS-02 | Phase 35 | Pending |
| TECH-01 | Phase 35 | Pending |
| DOC-01 | Phase 36 | Pending |
| DOC-02 | Phase 36 | Pending |
| DOC-03 | Phase 36 | Pending |
| DOC-04 | Phase 36 | Pending |
| REL-01 | Phase 36 | Pending |
| REL-02 | Phase 36 | Pending |

**Coverage:**
- v1 requirements: 17 total
- Mapped to phases: 17
- Unmapped: 0 ✓
