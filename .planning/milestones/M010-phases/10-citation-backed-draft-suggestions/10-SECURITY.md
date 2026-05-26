---
phase: 10
slug: citation-backed-draft-suggestions
status: verified
threats_open: 0
asvs_level: 1
created: 2026-05-23
updated: 2026-05-24
---

# Phase 10 — Security

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| operator entrypoints -> suggestion artifact | Untrusted operator-triggered suggestion requests become durable KB-maintenance records. | candidate ids, article ids, scoped attrs, proposed content metadata |
| retrieval evidence snapshot -> stored citation anchors | Only bounded, inspectable citation maps should become durable operator-facing evidence. | citation targets, destination metadata, trust/source fields |
| suggestion domain -> KB revision lineage | Revision suggestions must anchor to the currently published KB revision. | `article_id`, `base_revision_id`, revision lineage |
| suggestion/review surface -> authoring editor | Suggestion content may enter authoring only after explicit operator handoff. | `suggestion_id`, draft article target, proposed markdown |
| domain prep -> generation / stale gate | Candidate hydration and stale gating must use repo-backed evidence, not caller-supplied or generic fallback input. | `GapEvent` rows, grounding bundles, evidence digest, stale-signal metadata |

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-10-01 | T | `ArticleSuggestion` persistence | mitigate | Durable host-owned table with full markdown storage and no direct `Draft`/published revision mutation. | closed |
| T-10-02 | I | embedded evidence snapshot | mitigate | Bounded `citation_target` and `metadata.destination` validation in `ArticleSuggestionEvidence`. | closed |
| T-10-03 | S | revision entrypoint anchor | mitigate | `suggest_revision/2` resolves `base_revision_id` from `KnowledgeBase.get_latest_active_revision/1`. | closed |
| T-10-04 | D | `GenerateArticleSuggestion` queueing | mitigate | Oban uniqueness keyed by entrypoint identity plus `evidence_digest`. | closed |
| T-10-05 | T | stale-article revision gate | mitigate | `build_revision_gate/3` requires recent eligible article-linked failures and fresh canonical grounding. | closed |
| T-10-06 | S | generation grounding boundary | mitigate | Missing/weak canonical grounding fails closed and persists explicit failed status. | closed |
| T-10-07 | S | `SuggestionReview` action set | mitigate | Review UI exposes only inspect/regenerate/dismiss/manual-edit actions for this phase. | closed |
| T-10-08 | T | suggestion diff / trust presentation | mitigate | Revision diffs derive from `base_revision_id` content and trust/citation copy is presenter-owned. | closed |
| T-10-09 | E | editor handoff | mitigate | Editor suggestion preload requires explicit handoff navigation plus signed token validation and review-task binding. | closed |
| T-10-10 | T | authoring target seam | mitigate | New-article suggestions only reuse non-published authoring targets or create a fresh draft article target. | closed |
| T-10-11 | S | editor preload | mitigate | `suggestion_id` preload is gated by signed handoff verification and remains non-persistent until save/publish actions. | closed |
| T-10-12 | T | `suggest_article/2` gap-candidate prep | mitigate | Gap-driven requests hydrate candidate evidence in-domain and pass an internal grounding bundle, bypassing caller-supplied fallback input. | closed |
| T-10-13 | S | `suggest_revision/2` stale gate inputs | mitigate | Revision requests load article-linked `GapEvent` rows and fresh canonical grounding in-domain before stale-gate evaluation. | closed |
| T-10-14 | I | review-lane suggestion metadata | mitigate | Suggestion metadata persists query/digest/evidence counts/stale-signal fields for operator auditability. | closed |

## Accepted Risks Log

No accepted risks.

## Unregistered Flags

None. No `## Threat Flags` sections were present in `10-01-SUMMARY.md` through `10-05-SUMMARY.md`.

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-23 | 14 | 14 | 0 | Codex + `gsd-security-auditor` |
| 2026-05-24 | 14 | 14 | 0 | Claude (re-verification, short-circuit) |

**2026-05-24 re-verification note:** Plan-time threat register confirmed complete —
all 5 plans (`10-01`…`10-05`) carry `<threat_model>` blocks whose threat IDs union to
exactly T-10-01…T-10-14 (T-10-09 spans plans 03/04). `register_authored_at_plan_time: true`
and `threats_open: 0`, so the secure-phase short-circuit applies (no new-threat scan). All
13 cited evidence files were confirmed present on disk. No SUMMARY `## Threat Flags` exist;
no accepted risks required. Status unchanged: **SECURED**.

## Audit Evidence

| Threat Ref | Evidence |
|------------|----------|
| T-10-01 | [20260521020000_add_article_suggestions.exs](/Users/jon/projects/cairnloop/priv/repo/migrations/20260521020000_add_article_suggestions.exs:5), [article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/article_suggestion.ex:23) |
| T-10-02 | [article_suggestion_evidence.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/article_suggestion_evidence.ex:47) |
| T-10-03 | [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:472), [knowledge_base.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_base.ex:9) |
| T-10-04 | [generate_article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex:2), [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1066) |
| T-10-05 | [stale_article_signal.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/stale_article_signal.ex:10), [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:490) |
| T-10-06 | [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:583), [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:649), [generate_article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex:14) |
| T-10-07 | [suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:188), [suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:278) |
| T-10-08 | [suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:260), [article_suggestion_presenter.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/article_suggestion_presenter.ex:46), [article_suggestion_presenter.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/article_suggestion_presenter.ex:57) |
| T-10-09 | [suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:83), [editor_handoff.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor_handoff.ex:17), [editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:91) |
| T-10-10 | [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:546), [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:558), [knowledge_base.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_base.ex:65) |
| T-10-11 | [editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:85), [editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:91), [editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:40) |
| T-10-12 | [gaps.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/gaps.ex:30), [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:416), [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:817), [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1359) |
| T-10-13 | [index.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/index.ex:15), [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:472), [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1458), [stale_article_signal.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/stale_article_signal.ex:15) |
| T-10-14 | [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1123), [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1140), [knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1154) |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified
