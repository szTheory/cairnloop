# M011 Architecture Research: AI Tool Governance & MCP Integration

**Date:** 2026-05-23
**Milestone:** vM011 AI Tool Governance & MCP Integration

## Recommended Architecture

### Core Workflow

`AutomationRun -> ToolCall Proposal -> Policy Decision -> ToolApproval -> Resume Job -> Tool Execution -> Action Event Timeline`

### Domain Boundaries

| Boundary | Responsibility |
|----------|----------------|
| `Cairnloop.Automation` | Orchestrate AI- and operator-driven action runs |
| `Cairnloop.Tools` | Registry, metadata contract, and structured execution outcomes |
| `Cairnloop.Policy` | Host-owned risk and approval decisions |
| `Cairnloop.Approvals` | Durable approval lifecycle and event history |
| `Cairnloop.Telemetry` | Stable bounded event emission |
| `Cairnloop.MCP` | Optional edge adapter for exposing or consuming governed tools |

## Existing Seams To Reuse

- `ReviewTask` proves the repo prefers durable review workflow truth.
- `Retrieval` already separates canonical and assistive evidence and fail-closes weak grounding.
- `ConversationLive` already has the operator-side rail where governed actions should appear.
- `AutomationPolicy` and `Auditor` already establish host-owned decision and audit seams.

## Alternatives Considered

### Synchronous LiveView execution
- **Pros:** smallest initial patch
- **Cons:** no durable approval, timeout risk, no resume story, weak auditability
- **Verdict:** reject

### MCP-first internal model
- **Pros:** protocol purity and easier future interoperability story
- **Cons:** transport concerns leak into core workflow, weak fit for Ecto/Oban truth, auth ergonomics vary by client
- **Verdict:** defer to edge adapter

### Scoria-owned governance runtime
- **Pros:** faster if centralizing AI governance becomes the primary goal
- **Cons:** too much inversion of Cairnloop's host-owned support workflow
- **Verdict:** optional companion only

## Package Classification

| Surface | Classification | Notes |
|---------|----------------|-------|
| Governed-tool behaviour, policy seam, records, and workers | core | Primary milestone value |
| In-thread operator timeline and approval UX | core | Required for low-surprise operator flow |
| Bounded telemetry and audit integration | core | Required for durable proof and SLOs |
| Optional Scoria evidence lane | companion | Useful but not required for milestone closure |
| Optional read-only MCP adapter | companion | Edge interoperability only |
| Broad remote MCP write surface | defer | Too much blast radius for first pass |
