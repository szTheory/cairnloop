# Cairnloop Milestone Arc

## Purpose
This document records the current strategic milestone ordering so future milestone starts do not need to rediscover the same tradeoffs.

**Last updated:** 2026-05-23

## Decision Principles
- Move trust and answer quality left before expanding AI agency.
- Prefer host-owned Phoenix/Ecto/Oban paths over new external infrastructure unless the local path proves insufficient.
- Build the support-to-knowledge loop before broader outbound or cross-system automation.
- Avoid omnichannel sprawl, generic CRM surface area, and protocol-first work that does not improve the operator workflow.

## Research Summary
- **Plain** validates API-first support infrastructure, embedded knowledge, and AI-assisted operator workflows.
- **Pylon** validates knowledge-gap discovery, similar-case workflows, and product-signal extraction from support.
- **Help Scout** and **Zendesk** reinforce that AI support quality depends on grounded knowledge retrieval and explicit fallback paths.
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

## Recommended Next Milestones

### M011 - AI Tool Governance & MCP Integration
**Status:** candidate
**Priority:** high
**Why after M010:** retrieval is now trustworthy and KB maintenance is operator-reviewed, so the
next leverage point is policy-gated action with explicit approval boundaries and governed
integration seams.
**Shift-left exception:** pull ahead of M010 only for materially important enterprise or platform-integration demand.

### M012 - Support-Triggered Outbound Lifecycle
**Status:** candidate
**Priority:** medium
**Why later:** transactional outbound is valuable, but it benefits from better retrieval, intent, and governance primitives before it becomes a core adoption story.
**Scope guard:** keep it transactional and support-triggered; never let it turn into a generic marketing automation layer.

## Deferred Bets
- Broad external MCP server surface for third-party clients.
- External vector/search infrastructure as the default operating mode.
- Omnichannel breadth beyond the embedded widget, email, and currently supported escalation surfaces.
