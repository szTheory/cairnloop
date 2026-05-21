# Cairnloop Milestone Arc

## Purpose
This document records the current strategic milestone ordering so future milestone starts do not need to rediscover the same tradeoffs.

**Last updated:** 2026-05-21

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

### M009 - Retrieval-First Support Answers & Search Ops
**Status:** shipped
**Why now:** M008 shipped the durable Knowledge Base substrate on 2026-05-17. Retrieval is the highest-leverage way to convert that substrate into visible product value.
**Scope center of gravity:** host-owned hybrid retrieval over KB content first, resolved support evidence second, with grounded drafts, citations, operator search, and retrieval telemetry.
**Non-goals:** external Scrypath dependency by default, autonomous replies, full MCP exposure, raw live-thread RAG.
**Shipped:** 2026-05-21
**Closeout note:** Archived as an audit-complete `tech_debt` milestone. All nine requirements are
verified; deferred debt remains limited to environment-blocked realism lanes and duplicated
search-surface scope guards.

## Recommended Next Milestones

### M010 - KB AI Maintenance
**Status:** active
**Priority:** high
**Why after M009:** retrieval telemetry and no-hit evidence should feed a ranked gap loop instead of asking AI to invent product insights from thin signals.
**Shift-left rule:** keep this immediately after M009 unless enterprise adoption pressure strongly favors governed tools first.
**Implementation bias:** treat M010 as the start of a KB maintenance lane, not just analytics. The main operator action should be `Gap -> Draft article / Suggest revision -> Review -> Publish -> Reindex`, with Scoria as an optional governance/evidence layer rather than a hard dependency.
**Activated:** 2026-05-21

### M011 - AI Tool Governance & MCP Integration
**Status:** candidate
**Priority:** high
**Why after M010:** once retrieval is trustworthy and support intents/gaps are inspectable, broaden from grounded answers into policy-gated actions.
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
