# Milestones

## vM010 - KB AI Maintenance
**Shipped:** 2026-05-23

**Key accomplishments:**
- Turned retrieval no-hits, weak grounding, and repeated manual handling into a ranked, inspectable
  KB gap queue.
- Shipped citation-backed draft article and revision suggestions that fail closed when evidence or
  grounding is insufficient.
- Added a durable review-task workflow with explicit approve, reject, defer, and publish
  boundaries separate from suggestion truth.
- Unified KB maintenance inside `/knowledge-base/suggestions`, including visible history and
  publish or reindex follow-through.
- Let operators launch KB maintenance directly from conversation context while preserving
  shell/manual fallback inside the shared review lane.
- Added bounded maintenance telemetry for gap creation, suggestion outcomes, review decisions,
  publish, and reindex events.

**Stats:**
- Phases: 4
- Plans: 15
- Tasks: 16
- Timeline: 2026-05-21 -> 2026-05-23
- Git range: `1c8b2ca` -> `42613c8`
- Code delta at close: 253 files changed, 37599 insertions, 316 deletions
- Known deferred items at close: 2 technical debt items (split Phase 10/12 closure artifacts
  across planning layouts; unrelated `Chimeway.Repo` boot noise during focused tests)

## vM009 - Retrieval-First Support Answers & Search Ops
**Shipped:** 2026-05-21

**Key accomplishments:**
- Built a host-owned hybrid retrieval corpus over published Knowledge Base content and resolved
  support evidence.
- Shipped a retrieval-backed `cmd+k` operator search flow with source, trust, recency, and
  citation cues.
- Grounded AI drafts in explicit retrieval evidence with visible clarification and escalation
  states.
- Added bounded retrieval telemetry and durable gap-event storage so future KB maintenance work can
  start from real miss signals.
- Closed the remaining operator-search scope blocker and backfilled milestone verification so all
  nine requirements are traced as verified.

**Stats:**
- Phases: 8
- Plans: 14
- Timeline: 2026-05-17 -> 2026-05-21
- Git range: `2adb75d` -> working tree closeout
- Code delta at close: 30 files changed, 3230 insertions, 181 deletions
- Known deferred items at close: 2 technical debt items (repo-backed realism lanes blocked in this
  workspace; duplicated search-surface guard lists)

## vM006 - Omnichannel SLA Escalation (Chimeway)
**Shipped:** 2026-05-15

**Key accomplishments:**
- Implemented SLA Countdown Engine via Oban for durably tracking conversation SLA timers.
- Defined `Cairnloop.Notifier` behaviour for omnichannel notification delivery.
- Integrated Chimeway to dispatch actionable SLA breach notifications securely and safely without hardcoding external integrations.
- Exposed configuration for host applications to route SLA breach messages to Slack, PagerDuty, or Email.

**Stats:**
- Phases: 2
- Plans: 2

## vM005 - Durable Auditing & SRE Observability
**Shipped:** 2026-05-13

**Key accomplishments:**
- Integrated `Cairnloop.Auditor` behavior for immutable audit logging of critical operator actions.
- Integrated with Parapet to surface Service Level Indicators (SLIs) via Telemetry without cardinality explosions.
- Scaffolded SLO alerts and diagnostic runbooks via Igniter for enterprise compliance.

**Stats:**
- Phases: 3
- Plans: 2

## vM004 - Customer Voice Activation
**Shipped:** 2026-05-12

**Key accomplishments:**
- Implemented core telemetry pipeline for conversation resolution (`[:cairnloop, :conversation, :resolved]`).
- Added robust host extensibility and documentation for reacting to resolution events.
- Created durable Customer Satisfaction (CSAT) data models and storage.
- Integrated frictionless CSAT rating capture into the widget channel with related telemetry emission.

**Stats:**
- Phases: 2
- Plans: 2

## vM003 - Deep Context Enrichment
**Shipped:** 2024-05-11

**Key accomplishments:**
- Implemented robust `Cairnloop.ContextProvider` behaviour for zero API sync.
- Built a dynamic evidence rail and context pane UI in `ConversationLive`.
- Created Extensibility Components & Actions (`Cairnloop.Tool`) for custom action injection.

**Stats:**
- Phases: 3
- Plans: 3
- Lines of code: 1037 insertions, 123 deletions
