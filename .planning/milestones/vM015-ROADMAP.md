# Milestone vM015: Operator Polish + Maintenance Gates

**Status:** ✅ SHIPPED 2026-05-30
**Phases:** 33–36
**Total Plans:** 6
**Released as:** `cairnloop` v0.2.0 → v0.2.1 → v0.2.2 on Hex.pm (release-please pipeline)

## Overview

Closed the operator-facing rough edges and the remaining domain-layer security debt carried
from vM010, bringing the library to "done enough for stated scope." Delivered a real operator
settings cockpit (MCP token CRUD, integration health, dark mode), an audit-log surface and
governed-actions pagination, adopter-facing `/health` + `/metrics` HTTP endpoints, final
KnowledgeAutomation security closure (T-10-10/12/13), expanded ExDoc guides + architecture docs,
and the v0.2.x package release. The milestone also migrated the repo onto the canonical szTheory
**release-please** pipeline and gated releases on a now-green DB-backed integration suite.

> **Note on the release arc.** v0.2.0 shipped first but a same-day milestone audit
> (`vM015-MILESTONE-AUDIT.md`) found three broken/partial Phase-35 features (AUDIT-01 no-op stub,
> OPS-01/02 plugs mounted in no router) and a falsely-claimed CHANGELOG entry (REL-01). All four
> were remediated and republished as **v0.2.1**. The DB-backed integration CI suite — red since
> before v0.2.0 — was then fixed and gated in `release_gate`, shipping as **v0.2.2**. The
> requirements below reflect the post-remediation (v0.2.2) reality.

## Phases

### Phase 33: Security Domain Closure
**Goal**: System enforces domain-layer security invariants for knowledge automation
unconditionally, rejecting spoofed or invalid inputs.
**Depends on**: Phase 32.1
**Requirements**: SEC-01, SEC-02, SEC-03
**Plans**: 1 plan

Plans:
- [x] 33-01: Enforce immutable evidence and state for knowledge automation (closes T-10-10, T-10-12, T-10-13)

**Details:**
Verified and pinned (with explicit tests) that `Cairnloop.KnowledgeAutomation` already enforced
the three threats at the domain layer: new-article suggestions reuse only non-published authoring
targets, gap-candidate grounding derives exclusively from hydrated evidence (caller-supplied
`grounding_bundle`/evidence overwritten via `Keyword.put` + stripped from attrs), and stale-gate
inputs load only from repo-backed `GapEvent` rows plus fresh canonical grounding. No production
logic changes required — the gap was missing regression tests, now added.

### Phase 34: Operator Settings Surface
**Goal**: Operators can configure integrations, monitor connection health, and customize their
interface securely.
**Depends on**: Phase 33
**Requirements**: SET-01, SET-02, SET-03, SET-04
**Plans**: 2 plans

Plans:
- [x] 34-01: SettingsLive MCP token management + health surfacing
- [x] 34-02: Retrieval health + dark-mode toggle

**Details:**
`SettingsLive` became a real cockpit: MCP token CRUD with masking/validation (raw token shown
once at creation only), Notifier reachability indicators, retrieval-system health (pgvector index
status + Oban failed-queue jobs surfaced via `Cairnloop.Retrieval`), and an inline persisted
dark-mode toggle with no JS hook. Replaced the prior placeholder/SLA-only settings.

### Phase 35: Audit & Operations Support
**Goal**: Adopters and operators have clear visibility into system health, performance metrics,
and historical actions.
**Depends on**: Phase 34
**Requirements**: AUDIT-01, OPS-01, OPS-02, TECH-01
**Plans**: 2 plans

Plans:
- [x] 35-01: Health/metrics plugs + Auditor behaviour `list_events/1`
- [x] 35-02: Audit Log UI + governed-actions rail pagination

**Details:**
`Cairnloop.Web.HealthPlug` (`/health`) and `Cairnloop.Web.MetricsPlug` (`/metrics`, Prometheus
via optional `telemetry_metrics_prometheus_core`); `Cairnloop.Auditor` behaviour extended with
`list_events/1`. `Cairnloop.Web.AuditLogLive` mounted at `/audit-log`; `Governance
.list_proposals_for_conversation/2` gained `:limit` with `load_more_actions` plain-assign
pagination in `ConversationLive` (TECH-01 / AR-14-02 closure).
**v0.2.1 remediation:** at v0.2.0 the audit log was a no-op stub (empty, no search/filter, raw
`inspect` copy) and the health/metrics plugs were mounted in no router. Remediated to surface
governance events through the facade, humanize copy, and ship a `cairnloop_operations/1`
mount helper. **v0.2.2** humanized the audit-log action-filter options (no raw atom leak).

### Phase 36: Documentation & v0.2.0 Release
**Goal**: Adopters have comprehensive architectural guidance and can pull the milestone release.
**Depends on**: Phase 35
**Requirements**: DOC-01, DOC-02, DOC-03, DOC-04, REL-01, REL-02
**Plans**: 1 plan

Plans:
- [x] 36-01: ExDoc guides 05/06, CONTRIBUTING.md, docs/architecture.md, release

**Details:**
`guides/05-mcp-clients.md` (MCP router integration, Bearer token via SettingsLive, Cursor/Claude
client config), `guides/06-extending.md` (all `@callback` extension points), root `CONTRIBUTING.md`,
and `docs/architecture.md`. Release cut and pushed.
**v0.2.1 remediation:** the `## [0.2.0]` CHANGELOG section was missing at v0.2.0 release (REL-01
falsely claimed done in 36-01-SUMMARY); written in v0.2.1 along with adoption of the release-please
pipeline.

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 33. Security Domain Closure | 1/1 | Complete | 2026-05-29 |
| 34. Operator Settings Surface | 2/2 | Complete | 2026-05-29 |
| 35. Audit & Operations Support | 2/2 | Complete | 2026-05-29 |
| 36. Documentation & v0.2.0 Release | 1/1 | Complete | 2026-05-29 |

---

## Milestone Summary

**Key Decisions:**
- Adopt the canonical szTheory **release-please** pipeline (`release-please-config.json`,
  `.github/workflows/release-please.yml`, `release_gate` in `ci.yml`) — future releases are a
  `fix:`/`feat:` commit on `main` → bot PR → auto-tag + `publish-hex`, zero manual steps.
- Snapshot/facade invariants held: AuditLogLive (post-remediation) surfaces durable
  `ToolActionEvent` rows through the narrow `Cairnloop.Governance` facade rather than a parallel
  audit truth.
- Security closure done as test-only pinning where the domain already enforced the invariant —
  no churn to sealed `KnowledgeAutomation` paths.

**Issues Resolved:**
- AUDIT-01: audit log repaired from no-op stub to a functional, humanized, facade-backed timeline (v0.2.1).
- OPS-01/OPS-02: `/health` + `/metrics` made reachable via a documented `cairnloop_operations/1` mount (v0.2.1).
- REL-01: real `## [0.2.0]` CHANGELOG section written; `36-01-SUMMARY` claim corrected (v0.2.1).
- Integration CI suite (red since before v0.2.0, 3 clusters) fixed and added to `release_gate` (v0.2.2).
- governance: approver preserved as `decided_by` through the execute co-commit (v0.2.2).

**Issues Deferred / Tech Debt:**
- **Verification debt:** phases 33/34/35 shipped without a `VERIFICATION.md`; Nyquist
  `*-VALIDATION.md` exists only for phase 36. Code is green in CI through v0.2.2 but GSD
  verification artifacts were never produced. Backfill via `/gsd-verify-work` if required.
- Centralize duplicated fail-closed search guards (carried from vM009).
- Epics 12/13/14 (Advanced Routing, Privacy-First Local AI, Mobile SDK) remain out of scope —
  vM016+ is adoption + maintenance, not features (diminishing-returns line reached at vM015 close).

---

_For current project status, see .planning/ROADMAP.md_
