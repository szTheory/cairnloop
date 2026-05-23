# Security Verification: Phase 10 Citation-Backed Draft Suggestions

- Phase: `10` - `citation-backed-draft-suggestions`
- ASVS Level: `1`
- block_on: `threats_open`
- threats_total: `14`
- threats_open: `5`

## Threat Verification

| Threat ID | Category | Component | Disposition | Status | Evidence |
| --- | --- | --- | --- | --- | --- |
| T-10-01 | T | `ArticleSuggestion` persistence | mitigate | CLOSED | Separate host-owned `cairnloop_article_suggestions` table with `proposed_markdown` in [priv/repo/migrations/20260521020000_add_article_suggestions.exs](/Users/jon/projects/cairnloop/priv/repo/migrations/20260521020000_add_article_suggestions.exs:5); schema persists full markdown in [lib/cairnloop/knowledge_automation/article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/article_suggestion.ex:23). |
| T-10-02 | I | embedded evidence snapshot | mitigate | CLOSED | Bounded `citation_target` and `metadata.destination` validation in [lib/cairnloop/knowledge_automation/article_suggestion_evidence.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/article_suggestion_evidence.ex:47). |
| T-10-03 | S | revision entrypoint anchor | mitigate | CLOSED | `suggest_revision/2` resolves the published anchor through `get_latest_active_revision/1` and rejects missing anchors in [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:472) and [lib/cairnloop/knowledge_base.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_base.ex:9). |
| T-10-04 | D | `GenerateArticleSuggestion` queueing | mitigate | CLOSED | Oban uniqueness keys include `entrypoint_type`, `entrypoint_id`, `base_revision_id`, and `evidence_digest` in [lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex:2); job args include the same fields in [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1063). |
| T-10-05 | T | stale-article revision gate | mitigate | CLOSED | Stale gate enforces `@window_days 30`, `@minimum_signals 2`, published `base_revision_id`, and article/revision linkage from canonical citation anchors in [lib/cairnloop/knowledge_automation/stale_article_signal.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/stale_article_signal.ex:10) and [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:472). |
| T-10-06 | S | generation grounding boundary | mitigate | CLOSED | Weak or anchorless bundles fail closed before success and persist durable failed suggestions via [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:580), [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:646), and worker checks in [lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex:14). |
| T-10-07 | S | `SuggestionReview` action set | mitigate | CLOSED | The review surface renders only regenerate, dismiss, and open-for-manual-edit actions in [lib/cairnloop/web/knowledge_base_live/suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:274); no approval or publish events are handled there. |
| T-10-08 | T | suggestion diff / trust presentation | mitigate | CLOSED | Revision diffs derive from `base_revision_id` plus `proposed_markdown` in [lib/cairnloop/web/knowledge_base_live/suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:256) and [lib/cairnloop/web/article_suggestion_presenter.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/article_suggestion_presenter.ex:55); trust/citation wording is presenter-driven in [lib/cairnloop/web/article_suggestion_presenter.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/article_suggestion_presenter.ex:6). |
| T-10-09 | E | editor handoff | mitigate | OPEN | `SuggestionReview` provides `open_for_manual_edit`, but the editor accepts any matching `suggestion_id` directly and does not verify a prior handoff marker or `manual_edit_opened_at` gate in [lib/cairnloop/web/knowledge_base_live/suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:82) and [lib/cairnloop/web/knowledge_base_live/editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:90). |
| T-10-10 | T | authoring target seam | mitigate | OPEN | New-article creation starts with `status: :draft`, but reuse of `authoring_article_id` does not verify the target is still non-published in [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:544). |
| T-10-11 | S | editor preload | mitigate | OPEN | The editor preloads `proposed_markdown` whenever `suggestion_id` is present, without requiring deliberate handoff state beyond URL parameters in [lib/cairnloop/web/knowledge_base_live/editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:16) and [lib/cairnloop/web/knowledge_base_live/editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:84). |
| T-10-12 | T | `suggest_article/2` gap-candidate prep | mitigate | OPEN | The shipped path hydrates candidate evidence, but callers can still bypass it by supplying query/evidence/grounding fields because `hydrate_gap_candidate_request/2` short-circuits on `gap_candidate_grounding_supplied?/1`; generic fallback logic also remains in the shared bundle builder at [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1366) and [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:824). |
| T-10-13 | S | `suggest_revision/2` stale gate inputs | mitigate | OPEN | The domain loads durable `GapEvent` rows and fresh grounding by default, but `gap_events` and `grounding_bundle` can still be injected through opts, so queueing is not limited to repo-backed stale evidence in [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:490) and [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1470). |
| T-10-14 | I | review-lane suggestion metadata | mitigate | CLOSED | Query, digest, canonical evidence counts, and stale-signal metadata persist in grounding metadata via [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1120), [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1137), and [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1151). |

## Open Threats

| Threat ID | Expected Mitigation | Files Searched |
| --- | --- | --- |
| T-10-09 | Require a verifiable `open_for_manual_edit` handoff before the editor accepts suggestion content. | [lib/cairnloop/web/knowledge_base_live/suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:82), [lib/cairnloop/web/knowledge_base_live/editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:90), [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:544) |
| T-10-10 | Reuse only non-published authoring targets for new-article suggestions. | [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:544), [lib/cairnloop/knowledge_base.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_base.ex:24) |
| T-10-11 | Preload reviewed suggestion markdown only after deliberate handoff, not from a bare `suggestion_id` URL. | [lib/cairnloop/web/knowledge_base_live/editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:11), [lib/cairnloop/web/knowledge_base_live/suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:82) |
| T-10-12 | Build gap-candidate grounding only from hydrated candidate evidence and remove caller-supplied bypasses on that path. | [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:416), [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1366), [lib/cairnloop/web/knowledge_base_live/gaps.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/gaps.ex:30) |
| T-10-13 | Load stale-gate inputs only from repo-backed `GapEvent` rows plus fresh canonical grounding inside the domain. | [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:472), [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1470), [lib/cairnloop/knowledge_automation/stale_article_signal.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/stale_article_signal.ex:15) |

## Accepted Risks Log

None.

## Transfer Log

None.

## Unregistered Flags

None. The required summary files do not contain a `## Threat Flags` section.
