---
phase: M009-S01
slug: hybrid-retrieval-corpus-and-apis
status: verified_with_residual_risk
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-17
---

# Phase M009-S01 — Validation Strategy

> Backfilled validation state for the shipped Phase 1 retrieval corpus after Phase 6 closure work.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | `mix.exs` |
| **Primary proof command** | `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs test/cairnloop/chat_test.exs test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs test/cairnloop/retrieval_test.exs test/cairnloop/tasks/retrieval_tasks_test.exs` |
| **Focused rerun date** | `2026-05-21` |
| **Observed result** | `29 tests, 0 failures` |
| **Environment caveat** | Repeated `Chimeway.Repo` missing-`:database` startup noise still appears during test boot |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~20-40 seconds for the focused proof suite |

---

## Proof State

- Focused Phase 1 proof was rerun on `2026-05-21` with the command listed above.
- The rerun reproduced the prior `2026-05-20` outcome: `29 tests, 0 failures`.
- The realistic provider proof lane remained blocked because the plan command could not execute a
  live `Cairnloop.Repo` query in this workspace.
- Authoritative closure artifact:
  `.planning/milestones/M009-phases/M009-S01/M009-S01-VERIFICATION.md`

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| M009-S01-01-01 | 01 | 1 | M009-REQ-01 | T-M009-S01-01 | KB corpus stores searchable chunks with deterministic keys | unit | `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs` | ✅ yes | ✅ verified in focused rerun |
| M009-S01-01-02 | 01 | 1 | M009-REQ-02 | T-M009-S01-02 | Resolved evidence is stored separately from canonical KB truth | unit | `mix test test/cairnloop/chat_test.exs test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs` | ✅ yes | ✅ verified in focused rerun |
| M009-S01-01-03 | 01 | 1 | M009-REQ-03 | T-M009-S01-03 | Publish/resolve transitions enqueue durable indexing jobs | unit | `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/chat_test.exs` | ✅ yes | ✅ verified in focused rerun |
| M009-S01-02-01 | 02 | 2 | M009-REQ-01 | T-M009-S01-04 | Retrieval combines FTS and vector candidates without bypassing filters | integration | `mix test test/cairnloop/retrieval_test.exs` | ✅ yes | ⚠ verified with residual risk |
| M009-S01-02-02 | 02 | 2 | M009-REQ-02 | T-M009-S01-05 | Returned results label assistive evidence distinctly from KB content | unit | `mix test test/cairnloop/retrieval_test.exs` | ✅ yes | ⚠ verified with residual risk |
| M009-S01-02-03 | 02 | 2 | M009-REQ-03 | T-M009-S01-06 | Recovery primitives rebuild/replay corpus without unsafe shortcuts | integration | `mix test test/cairnloop/retrieval_test.exs test/cairnloop/tasks/retrieval_tasks_test.exs` | ✅ yes | ✅ verified in focused rerun |

*Status: ✅ verified in focused rerun · ⚠ verified with residual risk from blocked DB-backed proof lane*

---

## Realistic Proof Lane

- Attempted command:
  `MIX_ENV=test mix run -e 'Application.put_env(:cairnloop, :repo, Cairnloop.Repo); IO.inspect(Cairnloop.Retrieval.Providers.KnowledgeBase.keyword_candidates("phase-6-proof", 1), label: "kb_keyword"); IO.inspect(Cairnloop.Retrieval.Providers.ResolvedCases.keyword_candidates("phase-6-proof", 1, host_user_id: "phase-6-proof"), label: "resolved_keyword")'`
- Observed blocker:
  `** (UndefinedFunctionError) function Cairnloop.Repo.all/1 is undefined (module Cairnloop.Repo is not available)`
- Residual-risk consequence:
  FTS ranking, `pgvector` ordering, and filter-before-rank semantics remain partly unproven in this
  workspace because the provider command never reached a real repo-backed query.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Inspect that result labels and match reasons are understandable to future UI consumers | M009-REQ-01, M009-REQ-02 | This is a contract-quality review, not just compile correctness | Review `lib/cairnloop/retrieval/providers/knowledge_base.ex`, `lib/cairnloop/retrieval/providers/resolved_cases.ex`, and the verification artifact to confirm canonical and assistive outputs remain distinct |
| Verify rebuild/replay commands are safe to run in a developer workflow | M009-REQ-03 | Requires judgment around command ergonomics and destructive scope | Review `lib/mix/tasks/cairnloop.retrieval.rebuild.ex` and `lib/mix/tasks/cairnloop.retrieval.replay_failed.ex` and confirm both route through retrieval context helpers rather than raw SQL |

---

## Validation Sign-Off

- [x] All tasks have current automated proof coverage or explicit residual-risk notes
- [x] Sampling continuity: the focused proof suite covers the full Phase 1 surface
- [x] Wave 0 placeholder gaps have been replaced by current verification state
- [ ] No watch-mode flags
- [x] Feedback latency remains within the targeted focused-suite budget
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** closed with residual verification risk
