---
phase: M010-S01
plan: "02"
subsystem: gap-candidate-refresh-pipeline
tags: [knowledge-automation, clustering, oban, manual-handling]
key-files:
  created:
    [
      lib/cairnloop/knowledge_automation/candidate_builder.ex,
      lib/cairnloop/knowledge_automation/manual_handling_signal.ex,
      lib/cairnloop/knowledge_automation/workers/refresh_gap_candidates.ex,
      lib/cairnloop/knowledge_automation/workers/backfill_gap_candidates.ex,
      test/cairnloop/knowledge_automation/candidate_builder_test.exs,
      test/cairnloop/knowledge_automation/workers/refresh_gap_candidates_test.exs
    ]
  modified:
    [
      lib/cairnloop/retrieval/gap_recorder.ex,
      lib/cairnloop/retrieval/workers/index_resolved_conversation.ex
    ]
requirements-completed: [GAP-01, GAP-02]
completed: 2026-05-21
---

# M010-S01-02 Summary

Implemented the deterministic clustering and refresh path that keeps the Phase 9 queue current.

## Built

- Added lexical-first candidate bucketing with durable `stable_key` generation and persisted score
  components.
- Added repeated manual-handling projection from durable draft and resolved-case evidence.
- Added refresh and backfill worker seams, and wired best-effort refresh scheduling from
  retrieval-gap writes and resolved-case indexing.

## Verification

- `mix test test/cairnloop/knowledge_automation/candidate_builder_test.exs` ✅
- `mix test test/cairnloop/knowledge_automation/workers/refresh_gap_candidates_test.exs` ✅

## Deviations

- The refresh path is verified through focused hermetic tests in this workspace; repo-backed
  end-to-end realism remains environment-blocked by the missing `Cairnloop.Repo` runtime wiring.
