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

### M012 - Public Release & MCP Write Surface
**Status:** shipped
**Why now:** The governed-action contract, durable approval workflow, and MCP seam were proven in M011. Adopter-first assessment identified two critical gaps: no runnable example app, and the package was unpublished. M012 closed both and added the first MCP write surface.
**Scope center of gravity:** v0.1.0 Hex.pm release, Example Phoenix App demo, MCP OAuth seam, and MCP write tools (`tools/call` via Governance).
**Shipped:** 2026-05-26

## Recommended Next Milestones

### M013 - Support-Triggered Outbound Lifecycle
**Status:** active
**Priority:** high
**Why now:** Now that the package is public and the example app demonstrates the core loop, the next leverage point is closing the recovery loop — using support events to trigger proactive outbound actions (incident recovery, bug-fix notifications) through the proven governed-action and notification primitives.
**Scope center of gravity:** `Cairnloop.Outbound`, Chimeway-backed lifecycle templates, conversation-linked recovery messages, and bulk outbound affordances for resolved incidents.
**Scope guard:** keep it transactional and support-triggered; never let it turn into a generic marketing automation layer.

### M014 - Advanced Routing & Team Collaboration
**Status:** candidate
**Priority:** medium
**Why later:** As adoption grows, single-operator lanes become bottlenecks. Departmental routing and handoff primitives are needed for scale.
**Scope center of gravity:** Team/Queue schemas, manual/auto assignment logic, and cross-operator handoff cues.

## Deferred Bets
- Broad external MCP server surface for third-party clients.
- External vector/search infrastructure as the default operating mode.
- Omnichannel breadth beyond the embedded widget, email, and currently supported escalation surfaces.
