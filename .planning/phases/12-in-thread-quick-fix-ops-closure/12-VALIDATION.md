---
phase: 12
slug: in-thread-quick-fix-ops-closure
status: ready_for_execution
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-22
---

# Phase 12 - Validation Strategy

> Planning-state validation artifact for Phase 12. This phase is ready for execution, but it has not been verified yet.

## Execution Readiness

| Property | Value |
|----------|-------|
| Planned status | `ready_for_execution` |
| Plan count | `4` |
| Wave structure | `01 -> 02 -> 03 -> 04` |
| Quick run command | `mix test test/cairnloop/web/conversation_live_test.exs test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs test/cairnloop/retrieval/telemetry_test.exs` |
| Full suite command | `mix test` |
| Estimated runtime | `~20-60 seconds once new focused tests exist` |

## Source Coverage Audit

### GOAL

| Source Item | Covered By | Notes |
|-------------|------------|-------|
| Start KB maintenance from conversation context | Plan 01, Plan 03 | Conversation-scoped quick-fix command plus evidence-rail card |
| Fail closed with explicit shell or blocked/manual-required behavior | Plan 02, Plan 03 | Command-layer fallback state plus thread/review-lane copy |
| Add bounded operational visibility without a second dashboard | Plan 03, Plan 04 | Thread status rail plus bounded telemetry helper and presenter updates |

### REQ

| Requirement | Covered By | Notes |
|-------------|------------|-------|
| `OPS-01` | Plan 01, Plan 02, Plan 03 | Durable create-or-reuse quick fix, fail-closed fallback, thread launch UI |
| `OPS-03` | Plan 04 | Gap, suggestion, review, publish, and reindex telemetry normalization |

### RESEARCH

| Research Constraint / Risk | Covered By | Notes |
|----------------------------|------------|-------|
| Keep `evidence_snapshot` canonical-only | Plan 01 | Typed quick-fix package added separately from citation evidence |
| Add conversation-scoped idempotency | Plan 01 | Conversation entrypoint and create-or-reuse quick-fix seam |
| Preserve shared review lane as workflow truth | Plan 02, Plan 03 | Review task reuse and shared-lane links remain authoritative |
| Thread UI currently lacks maintenance state | Plan 03 | New evidence-rail card and thread status rendering |
| Knowledge-maintenance telemetry is missing | Plan 04 | New bounded telemetry helper and focused tests |

### CONTEXT

| Decision Range | Covered By | Notes |
|----------------|------------|-------|
| D-01 to D-04 | Plan 01, Plan 03 | Evidence-rail launch, shared review lane, durable create-or-reuse semantics |
| D-05 to D-08 | Plan 01 | Typed package layers and explicit citation-only canonical evidence |
| D-09 to D-12 | Plan 02 | Shell vs blocked/manual-required fallback and manual-authoring path |
| D-13 to D-17 | Plan 03, Plan 04 | Embedded status surfaces, bounded telemetry, and publish/reindex distinction |
| D-18 to D-20 | Plan 01, Plan 02, Plan 04 | Cairnloop-owned implementation, review-aware reuse, and decision posture |

## Locked-Decision Fidelity Check

- [x] Launch remains in `ConversationLive` evidence rail
- [x] Review lane remains the maintenance truth
- [x] Quick-fix create or reuse is durable and idempotent
- [x] Typed layers remain explicit and bounded
- [x] Only canonical retrieval is citation-eligible
- [x] Shell and blocked/manual-required fallback are both represented
- [x] Telemetry remains bounded and separate from audit truth
- [x] Thread and review-lane surfaces show follow-through without a second dashboard
- [x] `approved`, `published`, and `reindexed` remain distinct states

## Deferred / Out-of-Scope Audit

- Standalone ops dashboard
- One-click publish shortcuts
- Required Scoria or MCP critical-path integration
- Generalized conversation action palette

## Why Four Plans

Four plans keep this phase execution-ready without mixing trust-sensitive packaging, fallback state, UI composition, and telemetry closure into one broad slice:

1. conversation-scoped backend identity and typed evidence package,
2. shell/blocked fallback and review-lane semantics,
3. in-thread quick-fix card and status UX,
4. bounded telemetry plus remaining follow-through copy and visibility.

## Sampling Rate

- After Plan 01: run `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/knowledge_automation/review_task_test.exs`
- After Plan 02: run `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs`
- After Plan 03: run `mix test test/cairnloop/web/conversation_live_test.exs test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs`
- After Plan 04: run `mix test test/cairnloop/retrieval/telemetry_test.exs test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/web/conversation_live_test.exs`
- Before phase verification: run the full quick run command above, then `mix test` if focused suites are green

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| 12-01-01 | 01 | 1 | OPS-01 | T-12-01, T-12-02 | Conversation quick fix reuses one durable suggestion/review lane and keeps thread context separate from canonical citations | unit | `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/knowledge_automation/review_task_test.exs` | planned |
| 12-01-02 | 01 | 1 | OPS-01 | T-12-01 | Conversation-scoped quick-fix lookup is queryable for thread rendering and deep-link reuse | unit | `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs` | planned |
| 12-02-01 | 02 | 2 | OPS-01 | T-12-03, T-12-04 | Shell vs blocked fallback is explicit and task-safe; manual authoring stays available without bypassing review truth | unit | `mix test test/cairnloop/knowledge_automation/article_suggestion_test.exs test/cairnloop/knowledge_automation/review_task_test.exs` | planned |
| 12-02-02 | 02 | 2 | OPS-01 | T-12-03 | Review lane exposes quick-fix reasons and launch context without inventing a second workflow | liveview/unit | `mix test test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` | planned |
| 12-03-01 | 03 | 3 | OPS-01 | T-12-05 | Thread card renders launch, status, typed layer summary, and calm fallback copy in the evidence rail | liveview | `mix test test/cairnloop/web/conversation_live_test.exs` | planned |
| 12-03-02 | 03 | 3 | OPS-01 | T-12-05 | Quick-fix action stays idempotent and lands operators in the shared review lane or manual authoring path | liveview | `mix test test/cairnloop/web/conversation_live_test.exs test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` | planned |
| 12-04-01 | 04 | 4 | OPS-03 | T-12-06 | Bounded maintenance telemetry omits raw query text, thread text, and citation payloads while preserving coarse status and reason codes | unit | `mix test test/cairnloop/retrieval/telemetry_test.exs` | planned |
| 12-04-02 | 04 | 4 | OPS-03 | T-12-06, T-12-07 | Review decisions, publish, and reindex follow-through emit bounded events and keep thread/review-lane state distinct | unit/liveview | `mix test test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/web/conversation_live_test.exs` | planned |

## Wave 0 Requirements

- [x] Every planned task has automated verification
- [x] Typed evidence packaging and bounded telemetry risks are assigned to concrete tasks
- [x] `OPS-01` and `OPS-03` both map to at least one plan and one focused suite
- [x] Deferred ideas remain out of scope

## Manual-Only Checks To Reserve For Verification

| Behavior | Requirement | Why Manual | Verification Instructions |
|----------|-------------|------------|---------------------------|
| Confirm the quick-fix card feels evidence-adjacent rather than like a generic tool button | OPS-01 | UI hierarchy is experiential | Open a conversation with evidence, confirm the card sits in the rail and the launch action reads like maintenance, not reply composition |
| Confirm blocked/shell copy is calm and explicit | OPS-01 | Copy quality is experiential | Exercise weak-grounding and missing-citation cases and verify the next safe action is obvious |
| Confirm thread and review-lane follow-through stays understandable | OPS-03 | Multi-surface state comprehension is experiential | Publish a quick-fix item and verify thread/review-lane states progress from ready -> published -> reindexed or failure without collapsing states |

## Validation Sign-Off

- [x] Four execution-ready plans were created
- [x] Every locked decision in `12-CONTEXT.md` is covered
- [x] Quick-fix stays inside the existing maintenance lane
- [x] Typed evidence and bounded telemetry are explicit
- [x] Phase status is `ready_for_execution`, not verified
