# Cairnloop vM015 Roadmap

## Phases

- [ ] **Phase 33: Security Domain Closure** - Enforce immutable evidence and state for knowledge automation.
- [ ] **Phase 34: Operator Settings Surface** - Real settings interface for MCP tokens, health, and theming.
- [ ] **Phase 35: Audit & Operations Support** - HTTP health/metrics endpoints, UI audit log, and rail pagination.
- [ ] **Phase 36: Documentation & v0.2.0 Release** - Architecture docs, guides, and package release.

## Phase Details

### Phase 33: Security Domain Closure
**Goal**: System enforces domain-layer security invariants for knowledge automation unconditionally, rejecting spoofed or invalid inputs.
**Depends on**: Phase 32.1
**Requirements**: SEC-01, SEC-02, SEC-03
**Success Criteria**:
  1. System rejects creating new suggestions targeting already published articles.
  2. Gap-candidate suggestions strictly derive from immutable system evidence, ignoring external caller payloads.
  3. Stale revision checks rely solely on database events and canonical grounding, rejecting spoofed inputs.
**Plans**: 1/1 plans complete
  - [ ] 33-01-PLAN.md — Enforce immutable evidence and state for knowledge automation (closes T-10-10, T-10-12, T-10-13)

### Phase 34: Operator Settings Surface
**Goal**: Operators can configure integrations, monitor connection health, and customize their interface securely.
**Depends on**: Phase 33
**Requirements**: SET-01, SET-02, SET-03, SET-04
**Success Criteria**:
  1. Operator can add, edit, and validate MCP tokens securely from the Settings UI.
  2. Operator can visually confirm whether Notifiers and retrieval systems are healthy.
  3. Operator can toggle dark mode and see the application theme update immediately.
**Plans**: TBD
**UI hint**: yes

### Phase 35: Audit & Operations Support
**Goal**: Adopters and operators have clear visibility into system health, performance metrics, and historical actions.
**Depends on**: Phase 34
**Requirements**: AUDIT-01, OPS-01, OPS-02, TECH-01
**Success Criteria**:
  1. Operator can view, search, and filter a timeline of system actions in the new Audit Log UI.
  2. Operator can page through long lists of governed actions in the conversation sidebar without layout breakage.
  3. Adopter infrastructure can poll `/health` to verify application liveness.
  4. Adopter infrastructure can scrape `/metrics` to gather telemetry data.
**Plans**: TBD
**UI hint**: yes

### Phase 36: Documentation & v0.2.0 Release
**Goal**: Adopters have comprehensive architectural guidance and can pull the v0.2.0 milestone release.
**Depends on**: Phase 35
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04, REL-01, REL-02
**Success Criteria**:
  1. Adopter can read ExDoc guides covering MCP clients and extending Cairnloop on HexDocs.
  2. Contributor can find clear contribution guidelines in `CONTRIBUTING.md`.
  3. Adopter can understand system design via `docs/architecture.md`.
  4. Release v0.2.0 is published and documented in `CHANGELOG.md`.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 33. Security Domain Closure | 0/1 | Planned | - |
| 34. Operator Settings Surface | 0/0 | Not started | - |
| 35. Audit & Operations Support | 0/0 | Not started | - |
| 36. Documentation & v0.2.0 Release | 0/0 | Not started | - |
