# M011 Feature Research: AI Tool Governance & MCP Integration

**Date:** 2026-05-23
**Milestone:** vM011 AI Tool Governance & MCP Integration

## Table Stakes

### Governed Tool Contract
- Typed tool inputs and structured outcomes
- Explicit risk tier and approval mode
- Host-actor and account-aware authorization
- Missing-input and fail-closed states

### Operator Review
- In-thread action timeline
- Approval cards with human-readable previews
- Approve, reject, and defer actions
- Visible policy reason, blast radius, and reversibility cues

### Durable Execution
- Proposal and approval records
- Oban pause/resume flow for gated actions
- Append-only action events
- Expiry/invalidation when context or policy changes

### Observability
- Bounded telemetry for proposal, approval, execution, and failure
- Durable audit evidence for actor, action, and policy snapshot
- Optional OpenInference/Scoria spans

## Differentiators

### Retrieval-Grounded Actions
- Tool proposals carry the same canonical vs assistive evidence discipline used for grounded drafts
- Action lanes do not create a second truth system outside KB and reviewed support evidence

### Human-Guided Mode
- AI can propose next actions while operators remain the explicit driver for risky flows
- Reject/defer reasons feed back into future drafts and tooling guidance

### Embedded Host-Native DX
- One native Elixir behaviour for tools with optional MCP exposure later
- Examples and doctor/tester ergonomics for host developers instead of transport-first complexity

## MCP Scope Recommendation

### In Scope
- Core tool metadata and execution contract that can later map cleanly to MCP
- Optional read-only MCP adapter or bridge as a late milestone phase
- User-scoped auth and explicit consent if a remote MCP seam is enabled

### Out of Scope For This Milestone
- Broad third-party MCP marketplace/server surface
- High-risk remote write operations
- Generic multi-tool autonomous agent workflows
- AI-superuser identities or static privileged service credentials
