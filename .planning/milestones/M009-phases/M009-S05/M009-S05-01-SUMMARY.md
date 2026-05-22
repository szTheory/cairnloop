# M009-S05-01 Summary

## What Was Built

- Inbox and Settings now read `session["host_user_id"]` and pass it into the shared
  `SearchModalComponent`, while conversation search remains the reference scoped path.
- `cairnloop_dashboard` now documents the host-app session contract for scoped operator search on
  non-conversation surfaces.
- `SearchModalComponent` now fails closed with a dedicated `:scoped_unavailable` state when a
  surface requires tenant scope but `host_user_id` is missing, while preserving distinct no-hit
  and retrieval-error behavior.
- `Cairnloop.Retrieval.search/2` now blocks unsafe unscoped dashboard searches before
  `Ranker.merge/3`, `ResolvedCases` returns no candidates without `host_user_id`, and
  `KnowledgeBase` keeps only the real published-visibility gate instead of a misleading no-op host
  filter seam.
- The targeted test slice now proves explicit scope semantics, fail-closed behavior, and that
  unsafe unscoped searches do not reach ranking.

## Verification Run

- `mix format lib/cairnloop/router.ex lib/cairnloop/web/inbox_live.ex lib/cairnloop/web/settings_live.ex lib/cairnloop/web/search_modal_component.ex lib/cairnloop/retrieval.ex lib/cairnloop/retrieval/providers/knowledge_base.ex lib/cairnloop/retrieval/providers/resolved_cases.ex test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/settings_live_test.exs test/cairnloop/web/search_modal_component_test.exs test/cairnloop/retrieval_test.exs`
- `mix test test/cairnloop/web/inbox_live_test.exs test/cairnloop/web/settings_live_test.exs test/cairnloop/web/conversation_live_test.exs test/cairnloop/web/search_modal_component_test.exs test/cairnloop/retrieval_test.exs`

## Deviations

- Commit granularity was not split per task because the workspace already contained broad in-flight
  edits outside this plan’s ownership. The S05-owned file set was updated in place instead.
- Test boot still logs existing `Chimeway.Repo` database configuration noise in this workspace,
  but the targeted S05 suite completed with `37 tests, 0 failures`.
