---
phase: M009-S01
plan: "02"
subsystem: retrieval-api
tags:
  - retrieval
  - ranking
  - mix-tasks
key-files:
  - lib/cairnloop/retrieval.ex
  - lib/cairnloop/retrieval/ranker.ex
  - lib/cairnloop/retrieval/providers/knowledge_base.ex
  - lib/cairnloop/retrieval/providers/resolved_cases.ex
metrics:
  tests: 23
  failures: 0
---

# M009-S01-02 Summary

## What Changed

- Added `Cairnloop.Retrieval` as the internal retrieval facade for future callers.
- Added normalized `Cairnloop.Retrieval.Result` structs and deterministic rank-based fusion in `Cairnloop.Retrieval.Ranker`.
- Added provider modules for knowledge-base and resolved-case retrieval with explicit full-text and vector candidate paths.
- Added `mix cairnloop.retrieval.rebuild` and `mix cairnloop.retrieval.replay_failed` as developer recovery primitives routed through the retrieval context.

## Commits

| Task | Commit | Notes |
|------|--------|-------|
| Task 1 | uncommitted | Added retrieval facade and normalized result contract |
| Task 2 | uncommitted | Added provider-local hybrid candidate generation and deterministic ranking |
| Task 3 | uncommitted | Added rebuild and replay Mix task entry points plus task tests |

## Verification

- `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs test/cairnloop/chat_test.exs test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs test/cairnloop/retrieval_test.exs test/cairnloop/tasks/retrieval_tasks_test.exs`
- `mix help cairnloop.retrieval.rebuild`
- `mix help cairnloop.retrieval.replay_failed`

## Deviations

- The real provider query paths compile, but the retrieval facade and Mix tasks are verified via injected test doubles because this workspace does not have a configured Postgres test database.

## Self-Check: PASSED

- Retrieval now exposes one internal API with explicit source labeling and deterministic ranking.
- Recovery primitives exist under the `cairnloop.retrieval.*` namespace and route through the retrieval context instead of bespoke SQL.
