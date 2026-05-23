# Cairnloop Milestone Arc

## Purpose
This document records the current strategic milestone ordering so future milestone starts do not need to rediscover the same tradeoffs.

**Last updated:** 2026-05-23

## Decision Principles
- Move trust and answer quality left before expanding AI agency.
- Prefer host-owned Phoenix/Ecto/Oban paths over new external infrastructure unless the local path proves insufficient.
- Build the support-to-knowledge loop before broader outbound or cross-system automation.
- Avoid omnichannel sprawl, generic CRM surface area, and protocol-first work that does not improve the operator workflow.
- Treat MCP as an interoperability seam, not the internal workflow truth model.

## Research Summary
- **Plain** validates API-first support infrastructure, embedded knowledge, and pragmatic MCP onboarding, but also reinforces user-scoped auth and workflow-first actions.
- **Pylon** validates runbook-shaped, human-guided actions over generic tool spam, plus durable investigation and knowledge-gap loops.
- **Help Scout** and **Zendesk** reinforce that AI support quality depends on grounded knowledge retrieval, explicit fallback paths, visible action logs, and operator-facing review surfaces.
- **Chatwoot**, **Zammad**, and **FreeScout** validate open-source support demand, but also warn against becoming a broad helpdesk clone.
- **Papercups** validates Phoenix as a strong support fit while also showing the limits of the "open-source Intercom clone" path.

## Latest Shipped Milestone

### M010 - KB AI Maintenance
**Status:** shipped
**Why now:** Retrieval telemetry and no-hit evidence from M009 needed to become a safe,
operator-reviewed Knowledge Base maintenance loop before broader AI agency could expand.
**Scope center of gravity:** ranked gap candidates, citation-backed article and revision
suggestions, durable review tasks, in-thread quick fixes, and bounded maintenance telemetry.
**Non-goals:** autonomous publishing, external search/vector infrastructure by default, required
Scoria runtime integration, raw live-thread canonical truth.
**Shipped:** 2026-05-23
**Closeout note:** Archived as an audit-complete `tech_debt` milestone. All 12 v1 requirements are
verified; deferred debt remains limited to split planning-layout traceability and unrelated
workspace boot noise during focused tests.

## Active Milestone

### M011 - AI Tool Governance & MCP Integration
**Status:** active
**Priority:** high
**Activated:** 2026-05-23
**Why after M010:** retrieval is now trustworthy and KB maintenance is operator-reviewed, so the
next leverage point is governed support action with explicit approval boundaries and host-owned
workflow truth.
**Scope center of gravity:** typed governed tools, policy evaluation, durable approvals, Oban
pause/resume execution, in-thread operator review, and optional read-only MCP seams over the same
contract.
**Scope guard:** build the internal governed-action framework first; broad remote MCP surfaces,
high-risk write tools, and protocol-led expansion stay deferred until the core path is proven.
**Non-goals:** broad third-party MCP server marketplace support, high-risk financial mutations as
the first shipped action lane, AI-superuser identities, confidence-score-based mutation approval,
and replacing KB/review truth with tool output.

## Recommended Next Milestones

### M012 - Support-Triggered Outbound Lifecycle
**Status:** candidate
**Priority:** medium
**Why later:** transactional outbound is valuable, but it benefits from better retrieval, governed
actions, and policy/audit primitives before it becomes a core adoption story.
**Scope guard:** keep it transactional and support-triggered; never let it turn into a generic
marketing automation layer.

## Deferred Bets
- Broad external MCP server surface for third-party clients.
- External vector/search infrastructure as the default operating mode.
- Omnichannel breadth beyond the embedded widget, email, and currently supported escalation surfaces.
