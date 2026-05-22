---
phase: M009-S06
slug: retrieval-corpus-verification-closure
status: verified_with_residual_risk
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-21
---

# Phase M009-S06 — Validation Strategy

> Phase-local validation contract for the retrieval-corpus closure backfill.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Quick run command** | `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs test/cairnloop/chat_test.exs test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs test/cairnloop/retrieval_test.exs test/cairnloop/tasks/retrieval_tasks_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~20-45 seconds |

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|--------|
| M009-S06-01-01 | 01 | 1 | M009-REQ-01 | Retrieval corpus closure artifact exists with concrete implementation and test evidence | docs + unit | `rg -n '^# Phase M009-S01 Verification$|M009-REQ-01|M009-REQ-02|M009-REQ-03' .planning/milestones/M009-phases/M009-S01/M009-S01-VERIFICATION.md && mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs test/cairnloop/retrieval_test.exs` | ✅ passed on 2026-05-21 |
| M009-S06-01-02 | 01 | 1 | M009-REQ-02 | Resolved-case evidence remains separate from canonical Knowledge Base storage and trust semantics | unit | `mix test test/cairnloop/chat_test.exs test/cairnloop/retrieval/workers/index_resolved_conversation_test.exs test/cairnloop/retrieval_test.exs` | ✅ passed on 2026-05-21 |
| M009-S06-01-03 | 01 | 1 | M009-REQ-03 | Publish/resolve transitions and recovery primitives remain asynchronous and durable | unit | `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/chat_test.exs test/cairnloop/tasks/retrieval_tasks_test.exs` | ✅ passed on 2026-05-21 |

## Closure Notes

- `.planning/milestones/M009-phases/M009-S06/M009-S06-01-SUMMARY.md`
  now carries `requirements-completed` frontmatter for the audit matrix.
- The realism lane remained blocked because `Cairnloop.Repo` is unavailable in this shell.
- Closure therefore lands in `verified_with_residual_risk`, matching the underlying S01 closure
  artifact.

## Validation Sign-Off

- [x] Phase-local summary includes explicit completed requirements
- [x] Phase-local verification artifact exists
- [x] Focused proof suite is documented and green
- [x] Residual-risk posture is explicit and justified
- [x] `nyquist_compliant: true` set before completion

**Approval:** verified_with_residual_risk
