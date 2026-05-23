---
phase: 10-citation-backed-draft-suggestions
verified: 2026-05-23T11:41:21Z
status: human_needed
score: 10/10 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 8/10
  gaps_closed:
    - "Operator can generate a proposed new KB article from a selected gap candidate using citation-backed evidence only."
    - "Operator can generate a suggested revision when published KB content appears stale or incomplete against retrieval evidence."
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Run the gap-candidate and stale-article flows in a real host app session"
    expected: "Selecting a gap candidate or article creates a scoped suggestion, redirects to /knowledge-base/suggestions, and shows candidate/article-specific evidence instead of mock-only data."
    why_human: "The automated suites prove the code paths with mocks, but not a live Phoenix session against the host app's configured repo/retrieval stack."
  - test: "Open a suggestion for manual edit from the review surface in the browser"
    expected: "The editor preloads proposed markdown, shows review context, preserves the return path, and suppresses direct publish for review-origin sessions."
    why_human: "This is a browser interaction and UX-flow check; the verifier did not run a real LiveView session."
---

# Phase 10: Citation-Backed Draft Suggestions Verification Report

**Phase Goal:** Operators can safely turn a gap candidate or stale article signal into a grounded KB draft suggestion.
**Verified:** 2026-05-23T11:41:21Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Operator can generate a proposed new KB article from a selected gap candidate using citation-backed evidence only. | ✓ VERIFIED | [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1366) now hydrates the selected candidate in-domain, derives the query from durable gap evidence, and injects a grounded bundle before queueing; [test/cairnloop/knowledge_automation/article_suggestion_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/knowledge_automation/article_suggestion_test.exs:489) and [test/cairnloop/web/knowledge_base_live/gaps_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/web/knowledge_base_live/gaps_test.exs:330) verify the shipped path uses candidate-scoped evidence rather than the generic fallback query. |
| 2 | Operator can generate a suggested revision when published KB content appears stale or incomplete against retrieval evidence. | ✓ VERIFIED | [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:1470) now loads repo-backed article-linked gap events and a fresh canonical grounding bundle before evaluating staleness; [lib/cairnloop/knowledge_automation/stale_article_signal.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/stale_article_signal.ex:15) enforces the repeated-signal plus fresh-snapshot gate; [test/cairnloop/knowledge_automation/article_suggestion_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/knowledge_automation/article_suggestion_test.exs:649) and [test/cairnloop/web/knowledge_base_live/gaps_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/web/knowledge_base_live/gaps_test.exs:443) cover the real UI-to-domain path. |
| 3 | The system refuses to create or advance suggestions when citation anchors are missing or grounding is below the milestone threshold. | ✓ VERIFIED | [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:696) marks weak/no-citation bundles invalid and persists failed suggestions; [lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex:14) fail-closes invalid prepared bundles; tests cover blocked gap and worker failure paths. |
| 4 | Gap-driven and stale-driven suggestions share one durable suggestion artifact. | ✓ VERIFIED | [lib/cairnloop/knowledge_automation/article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/article_suggestion.ex:23) stores both `:article` and `:revision` suggestion types in one schema with shared lifecycle fields. |
| 5 | Suggestions persist full proposed markdown, evidence snapshot, and grounding metadata as the canonical stored truth. | ✓ VERIFIED | [lib/cairnloop/knowledge_automation/article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/article_suggestion.ex:33) stores `proposed_markdown`, embedded `evidence_snapshot`, and `grounding_metadata`; [priv/repo/migrations/20260521020000_add_article_suggestions.exs](/Users/jon/projects/cairnloop/priv/repo/migrations/20260521020000_add_article_suggestions.exs:5) persists the same fields durably. |
| 6 | Revision suggestions anchor to the current published `base_revision_id`. | ✓ VERIFIED | [lib/cairnloop/knowledge_base.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_base.ex:9) resolves the latest published revision and [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:474) overwrites the request with that `base_revision_id` before queueing. |
| 7 | Suggestion rows can be listed, scoped, and fetched with evidence. | ✓ VERIFIED | [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:64) and [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:72) implement scoped list/get seams; [test/cairnloop/knowledge_automation/article_suggestion_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/knowledge_automation/article_suggestion_test.exs:340) covers ordering, scope, and hydrated evidence. |
| 8 | Both suggestion types queue one shared async generation worker with uniqueness keyed by entrypoint identity and evidence digest. | ✓ VERIFIED | [lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex:1) uses one Oban worker with uniqueness keys `entrypoint_type`, `entrypoint_id`, `base_revision_id`, and `evidence_digest`; [test/cairnloop/knowledge_automation/workers/generate_article_suggestion_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/knowledge_automation/workers/generate_article_suggestion_test.exs:49) verifies the queued args. |
| 9 | Operators can inspect suggestions on a dedicated review surface with provenance, grounding, citation anchors, and proposal content or diff. | ✓ VERIFIED | [lib/cairnloop/router.ex](/Users/jon/projects/cairnloop/lib/cairnloop/router.ex:11) wires the route; [lib/cairnloop/web/knowledge_base_live/suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:112) renders grounding, stale pressure, evidence, citation anchors, and draft/diff content; [lib/cairnloop/web/article_suggestion_presenter.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/article_suggestion_presenter.ex:11) provides the trust/citation labels. |
| 10 | Manual edit handoff is explicit and preloads reviewed suggestion content without saving or publishing as a side effect. | ✓ VERIFIED | [lib/cairnloop/web/knowledge_base_live/suggestion_review.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:82) requires explicit `open_for_manual_edit`; [lib/cairnloop/knowledge_automation.ex](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex:544) creates or reuses the authoring target only when needed; [lib/cairnloop/web/knowledge_base_live/editor.ex](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:81) preloads `suggestion_id` content without saving or publishing. |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `priv/repo/migrations/20260521020000_add_article_suggestions.exs` | Durable suggestion storage/indexes | ✓ VERIFIED | Suggestion table plus indexes for `stable_key`, `status`, entrypoint identity, `evidence_digest`, and `base_revision_id`. |
| `lib/cairnloop/knowledge_automation/article_suggestion.ex` | Shared durable suggestion schema | ✓ VERIFIED | Substantive schema for article/revision suggestions, evidence embeds, lifecycle fields, and validation. |
| `lib/cairnloop/knowledge_automation/article_suggestion_evidence.ex` | Bounded citation-backed evidence rows | ✓ VERIFIED | Embedded evidence schema validates citation targets and bounded destination metadata. |
| `lib/cairnloop/knowledge_automation.ex` | Public suggestion/query/queue facade | ✓ VERIFIED | Scoped list/get, article/revision suggestion seams, gap hydration, stale gate input loading, fail-closed persistence, and manual-edit authoring seam are all present and wired. |
| `lib/cairnloop/knowledge_automation/stale_article_signal.ex` | Deterministic stale gate | ✓ VERIFIED | Filters recent article-linked failures and requires a fresh canonical snapshot. |
| `lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex` | Shared unique generation worker | ✓ VERIFIED | One shared worker executes generation and persists ready/failed outcomes. |
| `lib/cairnloop/web/knowledge_base_live/gaps.ex` | Gap queue generation entrypoint | ✓ VERIFIED | Thin UI entrypoint passes identity/scope, while the domain now hydrates candidate evidence internally. |
| `lib/cairnloop/web/knowledge_base_live/index.ex` | Stale-article revision entrypoint | ✓ VERIFIED | Thin UI entrypoint passes article identity/scope, while the domain now loads stale evidence and grounding internally. |
| `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` | Dedicated suggestion review surface | ✓ VERIFIED | Review lane renders evidence and supports explicit regenerate/dismiss/manual-edit actions. |
| `lib/cairnloop/web/article_suggestion_presenter.ex` | Suggestion presenter seam | ✓ VERIFIED | Presenter formats status, grounding, stale pressure, citations, diff summaries, and quick-fix labels. |
| `lib/cairnloop/web/knowledge_base_live/editor.ex` | Suggestion-aware manual-edit handoff | ✓ VERIFIED | Editor preloads suggestion markdown and preserves review-origin publish restrictions. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `gaps.ex` | `KnowledgeAutomation.suggest_article/2` | Selected candidate id plus scope | ✓ WIRED | UI passes candidate identity; domain hydration loads the selected candidate and builds the grounding bundle internally. |
| `index.ex` | `KnowledgeAutomation.suggest_revision/2` | Article id plus scope | ✓ WIRED | UI passes article identity; domain loads repo-backed stale signals and fresh grounding before the stale gate runs. |
| `KnowledgeAutomation` | `StaleArticleSignal.build_revision_gate/3` | Repo-backed gap events and fresh grounding bundle | ✓ WIRED | `build_revision_gate_inputs/3` now supplies both inputs on the shipped path. |
| `KnowledgeAutomation` | `GenerateArticleSuggestion` | Suggest/regenerate queueing | ✓ WIRED | `enqueue_generation_job/2` builds shared worker args from suggestion identity and digest. |
| `GenerateArticleSuggestion` | `ScoriaEngine` | Shared generation seam | ✓ WIRED | Worker calls `generate_article_suggestion/2` and persists ready/failed outcomes. |
| `SuggestionReview` | `ArticleSuggestionPresenter` | Suggestion-first review rendering | ✓ WIRED | Presenter labels and diff helpers are used throughout the review surface. |
| `SuggestionReview` | `Editor` | Explicit manual-edit handoff | ✓ WIRED | `open_for_manual_edit` navigates with `suggestion_id`, `review_task_id`, and return path. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `lib/cairnloop/knowledge_automation.ex` | Gap article grounding bundle | `get_gap_candidate!/2` + `gap_candidate_query/1` + `ground_for_draft/2` | Candidate-specific retrieval query and manual-handling evidence are loaded before suggestion persistence. | ✓ FLOWING |
| `lib/cairnloop/web/knowledge_base_live/gaps.ex` | `suggest_article` request attrs | Selected candidate id + scope | Thin UI request is sufficient because the domain now hydrates the selected candidate itself. | ✓ FLOWING |
| `lib/cairnloop/knowledge_automation.ex` | Revision stale gate inputs | `article_linked_gap_events/3` + `fresh_revision_grounding_bundle/4` | Domain loads durable article-linked failure signals and a fresh canonical snapshot before queueing. | ✓ FLOWING |
| `lib/cairnloop/web/knowledge_base_live/index.ex` | `suggest_revision` request attrs | Article id + scope | Thin UI request is sufficient because the domain now resolves revision anchor, stale evidence, and grounding internally. | ✓ FLOWING |
| `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` | Selected review task and evidence | `list_review_tasks/1` + `get_review_task!/2` | Review surface renders persisted suggestion data, evidence, and history. | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused Phase 10 suites | `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/knowledge_automation/workers/generate_article_suggestion_test.exs test/cairnloop/web/knowledge_base_live/gaps_test.exs test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs test/cairnloop/web/knowledge_base_live_test.exs` | `39 tests, 0 failures` in 0.3s; run emitted unrelated `Chimeway.Repo` missing `:database` boot logs | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `DRAFT-01` | `10-01`, `10-02`, `10-03`, `10-04`, `10-05` | Operator can generate a draft article suggestion from a selected gap candidate using citation-backed evidence only. | ✓ SATISFIED | Domain-side candidate hydration is implemented and covered by [article_suggestion_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/knowledge_automation/article_suggestion_test.exs:489) and [gaps_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/web/knowledge_base_live/gaps_test.exs:330). |
| `DRAFT-02` | `10-01`, `10-02`, `10-03`, `10-04`, `10-05` | Operator can generate a suggested revision for an existing KB article when retrieval evidence shows the published article is stale or incomplete. | ✓ SATISFIED | Repo-backed stale evidence and fresh canonical grounding are loaded in the default revision path and covered by [article_suggestion_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/knowledge_automation/article_suggestion_test.exs:649) and [gaps_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/web/knowledge_base_live/gaps_test.exs:443). |
| `DRAFT-03` | `10-01`, `10-02`, `10-03`, `10-05` | System blocks draft or revision recommendations that lack valid citations or exceed grounding confidence thresholds. | ✓ SATISFIED | Fail-closed validation remains in the request-preparation and worker paths; blocked gap and invalid bundle tests still pass. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/cairnloop/knowledge_automation/article_suggestion_test.exs` | 99 | Same-name `def all/1` clauses are split instead of grouped, producing a compiler warning during `mix test` | ⚠️ Warning | No functional failure, but it adds avoidable warning noise to the verification suite. |

### Human Verification Required

### 1. Real Entry-Point Smoke Test

**Test:** In a configured host app session, open `/knowledge-base/gaps`, select a real candidate, generate a suggestion, then repeat from `/knowledge-base` for a stale article.
**Expected:** Each action creates a scoped suggestion, redirects to `/knowledge-base/suggestions?task=...`, and shows evidence tied to the selected candidate/article rather than placeholder data.
**Why human:** The automated suites use mocks for repo and retrieval modules; they do not validate the real host integration or rendered browser flow.

### 2. Manual-Edit Handoff Smoke Test

**Test:** From `/knowledge-base/suggestions`, open a ready suggestion for manual edit.
**Expected:** The editor preloads the proposed markdown, shows review-origin context, preserves the return path, and does not expose direct publish in review-origin mode.
**Why human:** This is a browser interaction and UX check that the verifier did not execute live.

### Gaps Summary

The two prior functional blockers are closed. Gap-driven suggestions now hydrate the selected candidate's durable evidence in-domain, and stale-article revision suggestions now load repo-backed article-linked failure signals plus a fresh canonical grounding bundle before the stale gate runs. Automated must-haves are satisfied across storage, queueing, review, and manual-edit handoff. Remaining work is human confirmation of the live browser flow against a configured host app.

---

_Verified: 2026-05-23T11:41:21Z_
_Verifier: Claude (gsd-verifier)_
