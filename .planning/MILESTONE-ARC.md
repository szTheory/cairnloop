# Cairnloop Milestone Arc

## Purpose
This document records the current strategic milestone ordering so future milestone starts do not need to rediscover the same tradeoffs.

**Last updated:** 2026-05-27 — vM013 shipped; arc revised post-adoption-proof assessment (see `.planning/threads/vM014-adoption-proof-assessment.md`). The earlier "M014 = Advanced Routing & Team Collaboration" call is **superseded** — repo-local audit + brand/domain research both point to Adoption Proof as the next wedge; routing/teams is opt-in only when an adopter pulls.

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
**Status:** shipped 2026-05-27
**Priority:** high (was)
**Outcome:** `Cairnloop.Outbound.trigger/2` + `bulk_trigger/2` + `BulkEnvelope` + `OutboundWorker`; `system_outbound` messages on the conversation timeline; multi-select bulk recovery in `InboxLive`; OpenInference traces on `[:cairnloop, :outbound, :trace, …]`; narrow Governance audit READ facade.

### M014 - Adoption Proof (Realistic Demo, JTBD E2E, Brand) — active candidate
**Status:** active candidate (decided 2026-05-27)
**Priority:** high
**Why now:** Repo-local audit shows ~85% feature-done but adopter surface is genuinely thin (lonely demo seed, brand book unapplied, no JTBD smoke test, README leads with wrong install path, 5 vM010 SECURITY threats open). Brand book + domain research both prioritize "support becomes knowledge" + visible operator-grade flow over multi-operator scaling. Maintainer hasn't even looked at the UI yet — that's a strong signal.
**Scope center of gravity:** realistic seeded fixtures across the full JTBD lifecycle, customer `/chat` wired to real `WidgetChannel` ingress, D-10 brand-token CSS extraction, KB editorial-loop polish + T-10-09/T-10-11 closure, golden-path `Phoenix.LiveViewTest` smoke in CI, README + ExDoc `guides/`.
**Scope guard:** additive only; zero churn to sealed primitives (`Governance.propose/3`, `Outbound.trigger/2`, three-layer at-most-once, BulkEnvelope boundary, approval state machine).
**Detail:** `.planning/threads/vM014-adoption-proof-assessment.md` + `/Users/jon/.claude/plans/can-u-decide-this-greedy-balloon.md`.

### M015 - Operator Polish + Maintenance Gates
**Status:** candidate
**Priority:** medium-high
**Why next:** Close the operator-facing rough edges + remaining vM010 security debt; brings the library to "done enough for stated scope."
**Scope center of gravity:** real `SettingsLive` (MCP tokens, Notifier health, retrieval health), audit-log viewer LiveView, `/health` + `/metrics` endpoints, T-10-10/T-10-12/T-10-13 closure, AR-14-02 pagination, ExDoc guides expansion, contributor docs, v0.2.0 release.

### M016+ - Strategic Optionality (opt-in only when adopter pulls)
**Status:** deferred — do NOT pre-build
**Priority:** low (build only on real adopter signal)
- **Epic 13 Privacy-First Local AI (Nx/Bumblebee):** highest leverage of the three; pluggable `Cairnloop.Intent` adapter.
- **Epic 12 Advanced Routing & Team Collaboration:** medium leverage; only when multi-operator adoption shows up. Papercups taught "team routing didn't save us."
- **Epic 14 Mobile SDK Surface:** lowest leverage; defer indefinitely.

**Diminishing-returns line:** end of vM015. Post-done = adoption + maintenance. Cut v1.0.0 once at least one non-maintainer host runs cairnloop in production.

## Deferred Bets
- Broad external MCP server surface for third-party clients.
- External vector/search infrastructure as the default operating mode.
- Omnichannel breadth beyond the embedded widget, email, and currently supported escalation surfaces.
