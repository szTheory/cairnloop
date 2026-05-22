# M010-S02-02 Summary

## Outcome

Implemented the shared article-suggestion generation pipeline: stale-revision gating, async Oban worker execution, and fail-closed citation-backed proposal generation.

## Completed Work

- Added `Cairnloop.KnowledgeAutomation.StaleArticleSignal` to require repeated article-linked failures plus a fresh canonical revision anchor before revision suggestions can queue.
- Extended `Cairnloop.KnowledgeAutomation` to normalize explicit evidence attrs into one generation bundle contract, persist pending or failed suggestions safely, and enqueue `GenerateArticleSuggestion` jobs with entrypoint-plus-digest identity.
- Added `Cairnloop.KnowledgeAutomation.Workers.GenerateArticleSuggestion` as the shared async generation worker for article and revision suggestions.
- Extended `Cairnloop.Automation.ScoriaEngine` with a dedicated article-suggestion proposal seam that returns full markdown plus citation metadata.
- Added focused tests for stale gating, fail-closed behavior, job argument identity, and worker ready/failed execution paths.

## Verification

- `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/knowledge_automation/workers/generate_article_suggestion_test.exs`
  - Passed with `14 tests, 0 failures`
  - Workspace still emits unrelated `Chimeway.Repo` database configuration warnings during boot.

## Deviations from Plan

- Stored the reusable new-article authoring target marker later via `grounding_metadata.authoring_article_id` rather than the suggestion row's `article_id`, because gap-driven article suggestions intentionally reject revision-style anchors.
