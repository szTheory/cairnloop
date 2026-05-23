# M011 Pitfalls Research: AI Tool Governance & MCP Integration

**Date:** 2026-05-23
**Milestone:** vM011 AI Tool Governance & MCP Integration

## Main Footguns

| Pitfall | Why it matters | Prevention |
|---------|----------------|------------|
| Blocking on approval inside LiveView or one worker | Lost state, timeouts, and fragile operator UX | Persist approval request, then resume via a new Oban job |
| Broad write-capable MCP surface first | Creates too much blast radius before trust model is proven | Keep MCP optional and read-only first |
| Approving raw JSON | High operator friction and low confidence in risky actions | Render tool-specific preview cards with consequence text |
| Tool output becomes a second truth source | Undermines retrieval, KB review, and support evidence model | Keep KB/reviewed evidence canonical; tool results are contextual inputs |
| Confidence-score-based mutation approval | Models can be confident and wrong | Use policy- and risk-based approval classes instead |
| Missing loop guards | Tool-triggered automations can self-retrigger or fan out | Add idempotency keys, causal dedupe, and bounded retries |
| Unscoped auth or AI-superuser identities | Breaks host-owned trust and actor attribution | Inherit host actor/account scope and re-check policy before execute |
| High-cardinality telemetry | Makes SRE metrics noisy and brittle | Put detail in durable evidence rows, not metric labels |

## Repo-Specific Risks

- `ConversationLive` still executes tools directly after `can_execute?/2`; that path has no durable approval or resume story.
- Current tool metadata is too thin for risk tier, preview rendering, or idempotency semantics.
- Retrieval scope validation exists, but governed actions will need stricter actor/account/context replay checks.
- The repo currently has stronger retrieval/review primitives than tool-runtime primitives; M011 should build on the former instead of bypassing them.
