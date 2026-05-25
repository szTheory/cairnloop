# Requirements: Cairnloop vM011 AI Tool Governance & MCP Integration

**Defined:** 2026-05-23
**Core Value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.

## Milestone Gates

### Capability Selection Rubric

| Capability Family | Route Owner | Bridge Frequency | Permission / Policy Sensitivity | Support-Matrix Impact | Proof Required | Package Classification |
|-------------------|-------------|------------------|---------------------------------|-----------------------|----------------|------------------------|
| Governed internal tool contract and read-only actions | Cairnloop core | Low-frequency semantic | High | High | Hermetic contract, policy, and replay proof | core |
| Operator action timeline and approval UX | Cairnloop core | Native screen | High | High | LiveView interaction proof and fail-closed preview proof | core |
| Durable approval and resume state machine | Cairnloop core | Low-frequency semantic | High | High | Oban resume, expiry, and double-check policy proof | core |
| Optional Scoria/OpenInference evidence lane | Optional adapter | Low-frequency semantic | Medium | Low | Advisory integration proof only | companion |
| Optional read-only MCP bridge | Optional adapter | Low-frequency semantic | High | Medium | Advisory auth and mapping proof only | companion |
| Broad remote MCP write surfaces | Deferred | Defer | High | High | Not in this milestone | defer |

### Packaging Ledger

| Surface | Classification | Notes |
|---------|----------------|-------|
| Governed-tool metadata and execution contract | core | Primary host-developer integration seam |
| Durable proposal, approval, and action-event records | core | Workflow truth for risky actions |
| In-thread governed-action timeline and approval cards | core | Primary operator entrypoint |
| One narrow low-blast-radius write workflow | core | Proof lane for action execution after approval |
| Scoria evidence/eval adapter | companion | Optional tracing and eval persistence |
| Read-only MCP adapter | companion | Optional edge interoperability |
| Broad third-party MCP server support | defer | Outside first-governed-action scope |

### Proof Posture Gate

| Support Claim | Merge-Blocking Proof | Advisory Proof | Doctor / Operational Coverage |
|---------------|----------------------|----------------|-------------------------------|
| Governed tools fail closed when scope, input, or policy is insufficient | Tests for policy denial, missing-input, missing-scope, and invalid-context outcomes | Manual operator walkthrough for blocked states | Doctor check for policy and queue wiring |
| Approval-gated actions never execute inline and always resume through durable workflow state | Tests for approval request persistence, resume job scheduling, expiry, and re-check before execution | Manual approval UX smoke test | Queue/runbook note for stuck approvals |
| Operators can inspect what is about to happen before approving risky actions | Tests for preview rendering and action metadata exposure | Manual review of preview-card readability | Rough-edge docs for preview limitations |
| Telemetry remains bounded while full action truth is still reconstructable | Tests for event names and bounded metadata; durable event history tests | Advisory SRE/dashboard walkthrough | Telemetry contract doc plus support note |

### Support Truth Gate

| Surface | Denial / Fallback Behavior | Missing Prerequisite Behavior | Native Rebuild Required | Rough-Edge Docs |
|---------|----------------------------|-------------------------------|-------------------------|-----------------|
| Governed read-only action | Return `policy_denied`, `needs_input`, or `scope_invalid` with visible operator reason | Refuse execution and preserve proposal record | No | Tool contract and result-state guide |
| Approval-gated write action | Persist approval request or deny; never execute inline | Keep request pending or expired with clear reason | No | Approval lifecycle and expiry notes |
| In-thread action timeline | Show durable blocked/pending/error states instead of optimistic UI | If action cannot render preview, fall back to structured summary card | No | Operator review card guide |
| Optional MCP adapter | Disable surface entirely when auth or capability wiring is absent | Show read-only unavailable state; never silently widen scope | No | MCP enablement and auth notes |

## v1 Requirements

### Governed Tool Contract

- [x] **TOOL-01**: Host developer can define a governed support tool with typed input validation, declared risk tier, approval mode, idempotency metadata, and structured result states.
- [x] **TOOL-02**: System can propose a governed tool call from scoped conversation and account context without executing it inline.
- [x] **TOOL-03**: Governed tool proposal fails closed with explicit `needs_input`, `scope_invalid`, `policy_denied`, or `unsupported` outcomes instead of guessing or widening scope.
- [x] **TOOL-04**: Governed tool execution stores durable proposal and execution records plus append-only action events separate from transient UI state.

### Operator Timeline & Review

- [x] **FLOW-01**: Operator can inspect governed action proposals and outcomes inside the existing conversation workflow as a durable timeline.
- [x] **FLOW-02**: Operator sees a human-readable preview card for each risky action, including risk label, actor scope, target, consequence summary, and evidence links.
- [x] **FLOW-03**: Operator can reject or defer a proposed action with a persisted reason that remains visible in the action timeline.

### Approval & Resume

- [x] **APRV-01**: High-risk or sensitive governed actions create a durable approval record and never execute inside LiveView or a blocked worker process.
- [x] **APRV-02**: Approved governed actions resume through a new Oban job that re-validates scope and policy before execution.
- [x] **APRV-03**: Approval requests can expire or become invalid when policy, actor scope, or action context changes, and the timeline shows that state explicitly.
- [x] **APRV-04**: System allows only one active approval lane per governed action proposal and records all approval decisions as append-only events.

### First Action Path & Observability

- [x] **ACT-01**: System ships at least one narrow low-blast-radius write workflow after approval, such as adding an internal note, assigning a thread, or creating a follow-up task.
- [x] **OBS-01**: System emits bounded telemetry for governed action proposal, approval, execution, and failure outcomes without leaking high-cardinality payload data into metric labels.
- [x] **OBS-02**: Optional audit/evidence integrations can attribute who approved or denied a governed action and which policy snapshot applied.
- [ ] **MCP-01**: Core governed-tool metadata can map cleanly to an optional read-only MCP seam without changing the internal approval and execution model.

## v2 Requirements

### Deferred Expansion

- **MCP-02**: Optional remote MCP adapter can expose governed tools to third-party clients with user-scoped OAuth and explicit consent flows.
- **MCP-03**: Optional remote MCP write tools can participate in approval-gated execution after the internal governed-action lane is proven.
- **ACT-02**: System can support higher-risk financial or destructive mutations only after stronger proof, rollback, and support-truth coverage exist.
- **FLOW-04**: AI can orchestrate multi-step runbooks across several governed tools after single-action governance is proven stable.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Broad third-party MCP server marketplace support | Too much scope and blast radius for the first governed-action milestone |
| High-risk financial mutations as the first action path | Violates the shift-left proof posture for support safety |
| Confidence-score-only approval of mutations | Approval must remain policy- and risk-based |
| Blocking human approval inside LiveView or one long-running worker | Non-idiomatic for Phoenix and fragile under failure |
| Treating tool output as canonical truth over KB/reviewed support evidence | Undermines the retrieval and review trust model already established |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TOOL-01 | Phase 13 | Complete |
| TOOL-02 | Phase 13 | Complete |
| TOOL-03 | Phase 13 | Complete |
| TOOL-04 | Phase 13 | Complete |
| FLOW-01 | Phase 14 | Complete |
| FLOW-02 | Phase 14 | Complete |
| FLOW-03 | Phase 15 | Complete |
| APRV-01 | Phase 15 | Complete |
| APRV-02 | Phase 15 | Complete |
| APRV-03 | Phase 15 | Complete |
| APRV-04 | Phase 15 | Complete |
| ACT-01 | Phase 16 | Complete |
| OBS-01 | Phase 16 | Complete |
| OBS-02 | Phase 16 | Complete |
| MCP-01 | Phase 17 | Pending |

**Coverage:**

- v1 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0

---
*Requirements defined: 2026-05-23*
*Last updated: 2026-05-23 after initial milestone definition*
