---
phase: M009-S01
plan: "01"
subsystem: retrieval-corpus
tags:
  - retrieval
  - knowledge-base
  - resolved-cases
key-files:
  - priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs
  - lib/cairnloop/knowledge_base/workers/chunk_revision.ex
  - lib/cairnloop/retrieval/workers/index_resolved_conversation.ex
metrics:
  tests: 19
  failures: 0
---

# M009-S01-01 Summary

## What Changed

- Added retrieval corpus schema support for canonical KB chunks and separate resolved-case evidence storage.
- Extended KB chunk indexing with deterministic `chunk_index`, optional `heading`, and full-text search support.
- Added `Cairnloop.Retrieval.Workers.IndexResolvedConversation` plus transactional enqueueing from `Cairnloop.Chat.resolve_conversation/2`.
- Preserved the delete-and-reinsert indexing pattern for idempotent retries in both corpora.

## Commits

| Task | Commit | Notes |
|------|--------|-------|
| Task 1 | uncommitted | Added retrieval migration, KB chunk schema fields, and resolved-case schemas |
| Task 2 | uncommitted | Refactored KB indexing worker to persist deterministic retrieval metadata |
| Task 3 | uncommitted | Added resolved-conversation indexing worker, enqueue hook, and tests |

## Verification

- `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs test/cairnloop/chat_test.exs test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs`

## Deviations

- Manual execute-phase fallback was used because the local `gsd-sdk` in this workspace does not expose the workflow `query` interface expected by the GSD docs.

## Self-Check: PASSED

- Published KB revisions enqueue durable indexing jobs and persist deterministic chunk metadata.
- Resolved conversations enqueue a dedicated retrieval indexing job and store assistive evidence separately from canonical KB facts.
