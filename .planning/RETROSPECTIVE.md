# Cairnloop Retrospective

## Cross-Milestone Trends

| Milestone | Date | Phases | Plans |
|-----------|------|--------|-------|
| M005      | 2026-05-13 | 3      | 2     |
| M004      | 2026-05-12 | 2      | 2     |
| M001      | -    | -      | -     |
| M002      | -    | -      | -     |
| M003      | 2024-05-11 | 3      | 3     |

## Milestone: M005 — Durable Auditing & SRE Observability

**Shipped:** 2026-05-13
**Phases:** 3 | **Plans:** 2

### What Was Built
- Integrated `Cairnloop.Auditor` behavior for immutable audit logging of critical operator actions.
- Integrated with Parapet to surface Service Level Indicators (SLIs) via Telemetry without cardinality explosions.
- Scaffolded SLO alerts and diagnostic runbooks via Igniter for enterprise compliance.

### What Worked
- TDD with Igniter generation provided safe, reproducible scaffolding.
- Decoupling auditing through behaviours maintained the 'SaaS in a box' philosophy.

### What Was Inefficient
- Minimal blockers encountered; however, managing parallel metrics outputs requires careful testing of telemetry payloads.

### Patterns Established
- Test-driven generation for complex setup tasks using `Igniter`.

### Key Lessons
- Providing explicit `.md` runbook generation as a default builds significant trust for enterprise adopters and positions Cairnloop as a true platform.

## Milestone: M004 — Customer Voice Activation

**Shipped:** 2026-05-12
**Phases:** 2 | **Plans:** 2

### What Was Built
- Core telemetry pipeline for conversation resolution events.
- Customer Satisfaction (CSAT) durable storage and UI integration in the widget.

### What Worked
- Firing high-signal events (`[:cairnloop, :conversation, :resolved]`) kept the package decoupled from host actions.

### Key Lessons
- Keeping UI interactions frictionless (rating dismisses prompt instantly) is crucial for support flows.

## Milestone: M003 — Deep Context Enrichment

**Shipped:** 2024-05-11
**Phases:** 3 | **Plans:** 3

### What Was Built
- Implemented robust `Cairnloop.ContextProvider` behaviour for zero API sync.
- Built a dynamic evidence rail and context pane UI in `ConversationLive`.
- Created Extensibility Components & Actions (`Cairnloop.Tool`) for custom action injection.

### What Worked
- Clear boundary definitions via behaviours enabled test-driven development.
- Splitting the work into logical slices (behaviour, UI, extensibility) kept scope contained.

### What Was Inefficient
- N/A

### Patterns Established
- Dependency injection via application env for contexts.
- Tagged tuples for resilient error handling in UI bounds.

### Key Lessons
- Deep integration requires defensive UI rendering to prevent host application data issues from crashing the embedded support dashboard.
