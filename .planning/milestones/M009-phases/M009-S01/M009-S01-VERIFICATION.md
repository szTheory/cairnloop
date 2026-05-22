# Phase M009-S01 Verification

## Scope

This Phase 6 closure artifact backfills the verification evidence that the original Phase 1
retrieval-corpus delivery never received. It records fresh automated evidence from 2026-05-21,
ties the shipped implementation back to `M009-REQ-01`, `M009-REQ-02`, and `M009-REQ-03`, and
states explicitly where proof remains implementation-backed rather than DB-backed in this
workspace.

## Requirement Coverage Summary

| Requirement | Closure state | Primary fresh evidence | Notes |
|-------------|---------------|------------------------|-------|
| `M009-REQ-01` | Closed with residual verification risk | Focused Phase 1 suite rerun on 2026-05-21 (`29 tests, 0 failures`) | Real provider query lane blocked before `Cairnloop.Repo` could execute |
| `M009-REQ-02` | Closed with residual verification risk | Focused Phase 1 suite rerun on 2026-05-21 (`29 tests, 0 failures`) | Assistive/canonical trust split is proven by code and tests; DB-backed provider query remains blocked |
| `M009-REQ-03` | Closed with residual verification risk | Focused Phase 1 suite rerun on 2026-05-21 (`29 tests, 0 failures`) | Transactional enqueueing and replay/rebuild primitives are proven by the current test surface |

## M009-REQ-01

System indexes published Knowledge Base revisions into a hybrid retrieval corpus that supports both
semantic similarity and keyword search.

### Implementation evidence

- `priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs`
  adds retrieval-corpus schema support for canonical Knowledge Base chunks.
- `lib/cairnloop/knowledge_base/workers/chunk_revision.ex`
  persists deterministic `chunk_index`, optional `heading`, and retrieval-facing chunk metadata for
  published revisions.
- `lib/cairnloop/retrieval.ex`
  exposes the retrieval facade plus `rebuild_corpus/1` and `replay_failed/1` recovery entry points.
- `lib/cairnloop/retrieval/providers/knowledge_base.ex`
  implements both keyword (`websearch_to_tsquery`) and semantic (`pgvector`) candidate paths for
  published KB content, then merges them into normalized retrieval results.
- `.planning/milestones/M009-phases/M009-S01/M009-S01-01-SUMMARY.md`
  records the storage/indexing delivery for deterministic chunk metadata.
- `.planning/milestones/M009-phases/M009-S01/M009-S01-02-SUMMARY.md`
  records the retrieval facade, provider, ranker, and recovery-path delivery.

### Automated evidence

- Command run on `2026-05-21`:
  `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs test/cairnloop/chat_test.exs test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs test/cairnloop/retrieval_test.exs test/cairnloop/tasks/retrieval_tasks_test.exs`
- Observed outcome on `2026-05-21`: `29 tests, 0 failures`.
- This reproduces the already-known `29 tests, 0 failures` result from `2026-05-20`.
- Repeated startup caveat preserved per closure guidance:
  `Postgrex.Protocol ... failed to connect: ** (ArgumentError) missing the :database key in options for Chimeway.Repo`
- `test/cairnloop/knowledge_base_test.exs` and
  `test/cairnloop/knowledge_base/workers/chunk_revision_test.exs`
  cover published-revision indexing, deterministic chunk persistence, and retrieval-corpus writes.
- `test/cairnloop/retrieval_test.exs`
  covers the retrieval facade, provider wiring, and ranker behavior with the existing mock-driven
  harness.

### Manual checks

- Review `lib/cairnloop/retrieval/providers/knowledge_base.ex` and confirm the keyword path ranks
  by PostgreSQL FTS score and the semantic path orders by `pgvector` distance without bypassing the
  published-only filter.
- Review one retrieval result contract in `lib/cairnloop/retrieval/providers/knowledge_base.ex`
  and confirm citations preserve `article_id`, `revision_id`, and `chunk_index`.
- Inspect the two Phase 1 summary files and confirm the closure artifact does not claim broader
  DB-backed proof than the workspace currently provides.

### Residual risk

The focused suite proves the shipped retrieval facade and chunk-indexing paths still behave as
expected, but the real provider query path did not execute in this workspace. FTS ranking,
`pgvector` ordering, and filter-before-rank semantics therefore remain partly unproven here and are
closed on implementation review plus mock-driven coverage rather than a live `Cairnloop.Repo`
query.

## M009-REQ-02

System indexes resolved conversation summaries separately from Knowledge Base content and marks them
as assistive evidence rather than canonical policy.

### Implementation evidence

- `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex`
  persists resolved-case evidence through its own indexing worker and corpus path.
- `lib/cairnloop/retrieval/resolved_case_evidence.ex` and
  `lib/cairnloop/retrieval/resolved_case_chunk.ex`
  model resolved conversations separately from Knowledge Base truth.
- `lib/cairnloop/retrieval/providers/resolved_cases.ex`
  returns `source_type: :resolved_case`, `trust_level: :assistive`, and host-scoped citations for
  assistive-only retrieval evidence.
- `lib/cairnloop/retrieval.ex`
  keeps Knowledge Base and resolved-case retrieval as separate provider calls before rank fusion.
- `.planning/milestones/M009-phases/M009-S01/M009-S01-01-SUMMARY.md`
  records the separate resolved-case evidence storage and enqueue path.
- `.planning/milestones/M009-phases/M009-S01/M009-S01-02-SUMMARY.md`
  records explicit source labeling and normalized retrieval results for assistive evidence.

### Automated evidence

- Command run on `2026-05-21`:
  `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs test/cairnloop/chat_test.exs test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs test/cairnloop/retrieval_test.exs test/cairnloop/tasks/retrieval_tasks_test.exs`
- Observed outcome on `2026-05-21`: `29 tests, 0 failures`.
- This reproduces the already-known `29 tests, 0 failures` result from `2026-05-20`.
- Repeated startup caveat preserved per closure guidance:
  `Postgrex.Protocol ... failed to connect: ** (ArgumentError) missing the :database key in options for Chimeway.Repo`
- `test/cairnloop/chat_test.exs` and
  `test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs`
  cover resolved-conversation indexing and separate evidence persistence.
- `test/cairnloop/retrieval_test.exs`
  covers the assistive-versus-canonical result contract and provider composition under the current
  mock-driven retrieval harness.

### Manual checks

- Review `lib/cairnloop/retrieval/providers/resolved_cases.ex` and confirm assistive evidence stays
  tenant-scoped through `host_user_id` filtering before merge.
- Confirm the provider result payload uses `trust_level: :assistive` and `source_type: :resolved_case`
  rather than reusing Knowledge Base truth semantics.
- Review `M009-S01-01-SUMMARY.md` and `M009-S01-02-SUMMARY.md` together and confirm the closure
  story still distinguishes separate storage from separate presentation/trust semantics.

### Residual risk

The current proof surface is strong for separate storage and trust semantics, but the blocked real
provider lane means this workspace still lacks a DB-backed execution of the resolved-case query
path. Host filtering, FTS ranking, and semantic ordering are therefore closed with residual
verification risk rather than full live-query proof.

## M009-REQ-03

System updates retrieval indexes asynchronously via Oban when Knowledge Base revisions publish and
when conversations resolve.

### Implementation evidence

- `lib/cairnloop/retrieval.ex`
  exposes `reindex_revision/2`, `reindex_conversation/2`, `rebuild_corpus/1`, and `replay_failed/1`
  as the retrieval recovery boundary.
- `lib/cairnloop/knowledge_base/workers/chunk_revision.ex`
  owns asynchronous KB chunk indexing for published revisions.
- `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex`
  owns asynchronous resolved-conversation indexing.
- `lib/cairnloop/chat.ex`
  wires conversation resolution to the resolved-case indexing path.
- `lib/mix/tasks/cairnloop.retrieval.rebuild.ex` and
  `lib/mix/tasks/cairnloop.retrieval.replay_failed.ex`
  provide the developer recovery primitives for corpus rebuild and failed-job replay.
- The two Phase 1 summary files record transactional enqueueing and the recovery command surface as
  shipped behavior.

### Automated evidence

- Command run on `2026-05-21`:
  `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs test/cairnloop/chat_test.exs test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs test/cairnloop/retrieval_test.exs test/cairnloop/tasks/retrieval_tasks_test.exs`
- Observed outcome on `2026-05-21`: `29 tests, 0 failures`.
- This reproduces the already-known `29 tests, 0 failures` result from `2026-05-20`.
- Repeated startup caveat preserved per closure guidance:
  `Postgrex.Protocol ... failed to connect: ** (ArgumentError) missing the :database key in options for Chimeway.Repo`
- `test/cairnloop/knowledge_base_test.exs`,
  `test/cairnloop/chat_test.exs`, and
  `test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs`
  cover publish/resolve enqueue behavior.
- `test/cairnloop/tasks/retrieval_tasks_test.exs`
  covers the rebuild and replay developer primitives.

### Manual checks

- Review `lib/mix/tasks/cairnloop.retrieval.rebuild.ex` and
  `lib/mix/tasks/cairnloop.retrieval.replay_failed.ex` and confirm the commands stay routed
  through the retrieval context rather than raw SQL shortcuts.
- Inspect the enqueue calls in `lib/cairnloop/retrieval.ex`, `lib/cairnloop/chat.ex`, and
  `lib/cairnloop/knowledge_base/workers/chunk_revision.ex` to confirm async indexing remains the
  designed boundary instead of synchronous inline mutation.
- Confirm the closure artifact treats replay/rebuild as proven by the current command/test surface,
  not by the blocked provider query lane.

### Residual risk

This requirement has the strongest current evidence because the focused suite covers enqueue and
recovery behavior directly. Residual risk remains mostly indirect: the blocked live provider query
means the workspace still does not prove that asynchronously indexed records are queryable through a
real repo-backed retrieval path after enqueue completion.

## Realistic Proof Lane

### Attempted command

`MIX_ENV=test mix run -e 'Application.put_env(:cairnloop, :repo, Cairnloop.Repo); IO.inspect(Cairnloop.Retrieval.Providers.KnowledgeBase.keyword_candidates("phase-6-proof", 1), label: "kb_keyword"); IO.inspect(Cairnloop.Retrieval.Providers.ResolvedCases.keyword_candidates("phase-6-proof", 1, host_user_id: "phase-6-proof"), label: "resolved_keyword")'`

### Observed outcome

- The command was attempted on `2026-05-21`.
- It did not reach a real provider query against `Cairnloop.Repo`.
- First blocking application error line:
  `** (UndefinedFunctionError) function Cairnloop.Repo.all/1 is undefined (module Cairnloop.Repo is not available)`
- The run also repeated the existing environment noise:
  `Postgrex.Protocol ... failed to connect: ** (ArgumentError) missing the :database key in options for Chimeway.Repo`
- Missing prerequisite: this workspace does not expose an in-tree `Cairnloop.Repo` module or a
  configured DB-backed test harness for the exact plan command.

### Residual risk impact

This is an explicit blocked-proof lane rather than a retrieval-contract failure. The closure status
therefore remains `closed with residual verification risk`, but the residual risk must stay visible:
FTS ranking, `pgvector` ordering, and filter-before-rank semantics remain partly unproven in this
workspace because the real provider query path never executed.

## Backfill Summary

This is a Phase 6 closure artifact for already-shipped Phase 1 work. Fresh execution on
`2026-05-21` proves the focused retrieval corpus suite still passes with `29 tests, 0 failures`,
while implementation review and prior Phase 1 summaries explain how the retrieval corpus, assistive
evidence split, and async recovery paths are wired. The real provider proof lane is blocked by the
workspace's missing `Cairnloop.Repo` test harness, so the correct closure posture is `closed with
residual verification risk` rather than unconditional DB-backed proof.
