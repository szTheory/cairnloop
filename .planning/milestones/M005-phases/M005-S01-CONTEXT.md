# Phase Context: M005 Phase 1 (Foundation - Durable Auditing)

## Phase Goal
Critical operator actions are immutably logged to ensure enterprise-grade compliance. Integrate with Threadline for immutable audit logging.

## Architectural Decisions & Constraints
- **Threadline Durability**: Adopt the `Cairnloop.Auditor` behavior injected via `Ecto.Multi`. This ensures compliance-grade auditing by committing audit records in the exact same database transaction as the operator action, guaranteeing durable evidence. Pure telemetry is rejected because it breaks transactional boundaries and is therefore lossy.

## User Constraints
- Do not build a standalone auditing solution; we are building an integration boundary (the `Cairnloop.Auditor` behaviour) that allows host applications to wire up Threadline within `Ecto.Multi` chains.
- Maintain Cairnloop's philosophy: Host-owned wiring, strict cardinality safety, and atomic evidence.

## Deferred/Out of Scope
- Exposing metrics/SLIs directly to Parapet (This is M005 Phase 2).
- Defining SLO targets and runbook distribution (This is M005 Phase 3).
