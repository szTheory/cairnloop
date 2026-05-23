# M011 Research Summary: AI Tool Governance & MCP Integration

**Date:** 2026-05-23
**Milestone:** vM011 AI Tool Governance & MCP Integration

## Recommendation

Build **a governed internal action framework first** and treat **MCP as an optional edge adapter**, not Cairnloop's core runtime.

## Why This Is The Right Shape

- It matches Cairnloop's existing Phoenix/Ecto/Oban architecture and operator-first workflow.
- It reuses the strongest repo primitives already proven in M009-M010: retrieval grounding, durable review tasks, bounded telemetry, and in-thread operator surfaces.
- It preserves host-owned trust boundaries by keeping policy, actor scope, and approval state inside the app.
- It allows future MCP interoperability without forcing transport concerns into internal workflow truth.

## Coherent Recommendation Set

1. Define one native governed-tool contract with typed inputs, structured outcomes, risk tier, preview rendering, idempotency, and redaction metadata.
2. Persist proposal, approval, and execution truth in Ecto records and append-only events.
3. Use Oban pause/resume workers for approval-gated actions; never block inside LiveView.
4. Keep governed actions visible inside `ConversationLive` as approval cards and timeline events.
5. Start with read-only and low-blast-radius support actions; defer high-risk financial or destructive tools.
6. Add optional Scoria and MCP companion seams after the core governed-action lane exists.

## Scope Corrections

### Ship in vM011
- Governed-tool contract
- In-thread action timeline
- Durable approval state machine
- One narrow write workflow
- Optional read-only MCP seam only if the internal contract is already proven

### Defer
- Broad remote MCP server surface
- High-risk write actions such as refunds or destructive account changes
- Protocol-first internal architecture
- Generic multi-step autonomous agent workflows
