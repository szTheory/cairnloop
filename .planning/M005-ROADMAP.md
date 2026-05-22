# ROADMAP: M005 Durable Auditing & SRE Observability

## Phases

- [ ] **Phase 1: Foundation (Durable Auditing)** - Integrate with Threadline for immutable audit logging of critical operator actions.
- [ ] **Phase 2: SRE Observability (SLIs)** - Integrate with Parapet to consume Cairnloop's SLIs (e.g., Time to First Response).
- [ ] **Phase 3: Alerting & Runbooks** - Define SLO alerts and diagnostic runbooks for enterprise compliance.

## Phase Details

### Phase 1: Foundation (Durable Auditing)
**Goal**: Critical operator actions are immutably logged to ensure enterprise-grade compliance.
**Depends on**: Nothing
**Requirements**: M005-REQ-01, M005-REQ-02
**Success Criteria** (what must be TRUE):
  1. Integration with Threadline is established via a `Cairnloop.Auditor` behavior or similar.
  2. Actions such as "Agent manually approved AI draft" or "Agent redacted PII" generate durable evidence bundles via Threadline.
**Plans**:
- [ ] M005-S01-01

### Phase 2: SRE Observability (SLIs)
**Goal**: Support operation metrics are cleanly surfaced as quantitative indicators for reliability tracking.
**Depends on**: Phase 1
**Requirements**: M005-REQ-03, M005-REQ-04
**Success Criteria** (what must be TRUE):
  1. Cairnloop defines specific SLIs (Service Level Indicators) like "Time to First Response" and "Time to Resolution".
  2. Parapet integration correctly consumes these metrics via Telemetry without cardinality explosions.
**Plans**: TBD

### Phase 3: Alerting & Runbooks
**Goal**: Organizations can trigger alerts based on defined objectives and diagnose problems quickly.
**Depends on**: Phase 2
**Requirements**: M005-REQ-05, M005-REQ-06
**Success Criteria** (what must be TRUE):
  1. Adopters can define SLOs using Parapet's DSL based on the SLIs surfaced in Phase 2.
  2. Scaffolded runbook definitions and diagnostic commands (e.g. `mix parapet.doctor`) are available for support operation health.
**Plans**:
- [ ] M005-S03-01-PLAN.md — Scaffolding SLOs and runbooks via Igniter task

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation (Durable Auditing) | 0/1 | Planned | - |
| 2. SRE Observability (SLIs) | 0/0 | Not started | - |
| 3. Alerting & Runbooks | 0/1 | Planned | - |
