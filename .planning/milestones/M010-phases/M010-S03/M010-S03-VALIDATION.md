---
phase: M010-S03
slug: review-gated-kb-updates
status: ready_for_execution
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-22
---

# Phase M010-S03 — Validation Strategy

> Planning-state validation artifact for Phase 11. This phase is ready for execution, but it has
> not been verified yet.

## Execution Readiness

| Property | Value |
|----------|-------|
| **Planned status** | `ready_for_execution` |
| **Plan count** | `4` |
| **Wave structure** | `01 -> 02 -> 03 -> 04` |
| **Quick run command** | `mix test test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/knowledge_base_test.exs test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs test/cairnloop/web/knowledge_base_live_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | `~25-60 seconds once the new focused tests exist` |

## Source Coverage Audit

### GOAL

| Source Item | Covered By | Notes |
|-------------|------------|-------|
| AI-prepared KB drafts and revisions move through an inspectable review task | Plan 01, Plan 03 | Separate `ReviewTask` storage plus task-centric inbox and detail surface |
| Operator can review evidence, citation anchors, and proposal body or diff | Plan 01, Plan 03 | Task read model preloads suggestions; inbox detail keeps evidence and proposal content visible |
| Operator can approve, reject, edit-before-publish, and publish without weakening canonical boundary | Plan 02, Plan 03, Plan 04 | Separate command semantics, task actions, review-aware editor handoff, and publish-bypass closure |
| Approved updates use normal publish and reindex flow with visible follow-through | Plan 02, Plan 04 | `publish_review_task/2` reuses `KnowledgeBase.publish_revision/1`; `ChunkRevision` reflects completion/failure |

### REQ

| Requirement | Covered By | Notes |
|-------------|------------|-------|
| `REVIEW-01` | Plan 01, Plan 03 | Durable task read model plus shared inbox/detail with evidence, citation anchors, and proposal content |
| `REVIEW-02` | Plan 02, Plan 03, Plan 04 | Approve/reject/defer/publish semantics, task actions, editor handoff, and publish-bypass closure |
| `REVIEW-03` | Plan 01, Plan 02, Plan 03, Plan 04 | Structured state, decision metadata, append-only history, and publish/reindex follow-through updates |
| `OPS-02` | Plan 02, Plan 04 | Explicit reuse of `KnowledgeBase.publish_revision/1` plus chunk or reindex outcome reflection |

### RESEARCH

| Research Constraint / Risk | Covered By | Notes |
|----------------------------|------------|-------|
| Keep `ArticleSuggestion` proposal-only | Plan 01 | New `ReviewTask` + `ReviewTaskEvent`; no review-state columns added to suggestion schema |
| Shared inbox over existing `SuggestionReview` foundation | Plan 03 | Converts `/knowledge-base/suggestions` into the task-centric review lane |
| Risk 1: `save_draft/2` can overwrite unrelated drafts | Plan 02 | Approval checks `staged_revision_id` ownership and fails closed on foreign draft collisions |
| Risk 2: review-origin editor publish can bypass audit | Plan 04 | Editor becomes review-aware and suppresses or reroutes direct publish when `review_task_id` is present |
| Publish must reuse canonical KB path | Plan 02, Plan 04 | `publish_review_task/2` calls `KnowledgeBase.publish_revision/1`; follow-through attaches to `ChunkRevision` |
| Re-review after material edits | Plan 04 | Editor-origin changes mark task `review_needed` and append history |

### CONTEXT

| Decision Range | Covered By | Notes |
|----------------|------------|-------|
| D-01 to D-04 | Plan 01 | Separate proposal, workflow, and canonical truth with one active task per suggestion |
| D-05 to D-08 | Plan 01, Plan 03 | Dedicated inbox, shared review lane, queue-state visibility |
| D-09 to D-13 | Plan 02 | Approve is draft-only, publish is separate, freshness checked, no convenience approve-and-publish |
| D-14 to D-18 | Plan 03, Plan 04 | Editor handoff, review-context return path, lightweight evidence context, re-review after edits |
| D-19 to D-23 | Plan 01, Plan 02, Plan 03, Plan 04 | Structured decisions, bounded reasons, relational state, append-only history |
| D-24 to D-26 | Plan 02, Plan 04 | Publish and reindex follow-through are reflected only after canonical publish via normal Oban/Ecto seams |
| D-27 to D-31 | Plan 01, Plan 02, Plan 03, Plan 04 | Host-owned Phoenix/Ecto/Oban lane; no external workflow engine, Scoria dependency, or unnecessary re-escalation |

## Locked-Decision Fidelity Check

- [x] D-01 implemented: `ArticleSuggestion` remains proposal-only
- [x] D-02 implemented: separate `ReviewTask` domain object
- [x] D-03 implemented: one active task per suggestion
- [x] D-04 implemented: proposal / decision / canonical publish facts remain separate
- [x] D-05 implemented: one dedicated KB maintenance review inbox
- [x] D-06 implemented: launch points deep-link into shared review lane
- [x] D-07 implemented: Phase 10 `SuggestionReview` evolves instead of being replaced
- [x] D-08 implemented: pending, approved-ready-to-publish, rejected, deferred, published visible in queue
- [x] D-09 implemented: approve never publishes by default
- [x] D-10 implemented: approve stages draft and moves task to `approved_ready_to_publish`
- [x] D-11 implemented: `KnowledgeBase.publish_revision/1` remains the only canonical publish path
- [x] D-12 implemented: revision publish freshness re-check
- [x] D-13 implemented: no approve-and-publish convenience action in this phase
- [x] D-14 implemented: edit-before-publish routes into existing editor
- [x] D-15 implemented: review remains evidence-first, editor remains authoring surface
- [x] D-16 implemented: editor handoff preserves return path
- [x] D-17 implemented: lightweight review context stays visible during authoring
- [x] D-18 implemented: material edits trigger re-review
- [x] D-19 implemented: notes are optional, not audit truth
- [x] D-20 implemented: decision metadata is structured and queryable
- [x] D-21 implemented: bounded reason taxonomy
- [x] D-22 implemented: relational host-owned workflow state
- [x] D-23 implemented: append-only review history seam
- [x] D-24 implemented: reindex belongs to publish completion
- [x] D-25 implemented: publish/reindex outcome reflected on task
- [x] D-26 implemented: follow-through uses Oban/Ecto boundaries
- [x] D-27 implemented: host-owned Phoenix/Ecto/Oban only
- [x] D-28 implemented: explicit operator-controlled publish boundary remains intact
- [x] D-29 implemented: distinct surfaces for suggestion generation, review, authoring, and publish
- [x] D-30 implemented: ordinary implementation naming left to executor where safe
- [x] D-31 implemented: route/button/reason naming left discretionary where trust semantics stay fixed

## Deferred / Out-of-Scope Audit

- Explicitly excluded from this phase:
  - one-click `Approve and publish now`
  - inline markdown editing on the review surface
  - assignment, multi-reviewer, SLA, or broader governance workflow features
  - required Scoria or MCP participation
  - Phase 12 in-thread quick-fix initiation
  - broader ops or telemetry closure beyond review-task publish/reindex follow-through

## Why Four Plans

Four plans are the right split for this phase because the work separates cleanly into:

1. durable review-task storage and query APIs,
2. stateful command semantics with the draft-collision and freshness guardrails,
3. task-centric shared review UI,
4. review-aware editor and publish-follow-through reflection.

Collapsing these would mix storage, command, UI, and post-publish behavior into larger cross-surface plans and make the two explicit research risks harder to isolate and verify.

## Sampling Rate

- After Plan 01 schema/context work: run `mix test test/cairnloop/knowledge_automation/review_task_test.exs`
- After Plan 02 command work: run `mix test test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/knowledge_base_test.exs`
- After Plan 03 inbox/detail work: run `mix test test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs`
- After Plan 04 editor/follow-through work: run `mix test test/cairnloop/web/knowledge_base_live_test.exs test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs`
- Before phase verification: run the full quick run command above, then `mix test` if the focused suite is green

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| M010-S03-01-01 | 01 | 1 | REVIEW-01, REVIEW-03 | T-M010-S03-01, T-M010-S03-02, T-M010-S03-03 | Durable task and event storage preserve proposal/workflow separation and active-task uniqueness | unit | `mix test test/cairnloop/knowledge_automation/review_task_test.exs` | planned |
| M010-S03-01-02 | 01 | 1 | REVIEW-01, REVIEW-03 | T-M010-S03-01, T-M010-S03-03 | Scoped task queries and idempotent task creation expose one inbox-ready read model without mutating suggestions | unit | `mix test test/cairnloop/knowledge_automation/review_task_test.exs` | planned |
| M010-S03-02-01 | 02 | 2 | REVIEW-02, REVIEW-03 | T-M010-S03-04, T-M010-S03-05 | Approval stages only task-owned drafts, blocks unrelated draft collisions, and reject/defer persist structured history | unit | `mix test test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/knowledge_base_test.exs` | planned |
| M010-S03-02-02 | 02 | 2 | REVIEW-02, OPS-02 | T-M010-S03-05, T-M010-S03-06 | Publish remains explicit, freshness-checked, and canonical through `publish_revision/1` | unit | `mix test test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/knowledge_base_test.exs` | planned |
| M010-S03-03-01 | 03 | 3 | REVIEW-01, REVIEW-03 | T-M010-S03-07, T-M010-S03-08, T-M010-S03-09 | Shared inbox shows queue states, evidence, diff/body, and audit history from one task lane | liveview | `mix test test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` | planned |
| M010-S03-03-02 | 03 | 3 | REVIEW-02 | T-M010-S03-07, T-M010-S03-09 | Task actions and launch-point deep links converge on one auditable review lane | liveview | `mix test test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` | planned |
| M010-S03-04-01 | 04 | 4 | REVIEW-02, REVIEW-03 | T-M010-S03-10, T-M010-S03-11 | Review-origin editor sessions cannot bypass audit and force re-review after material edits | liveview/unit | `mix test test/cairnloop/web/knowledge_base_live_test.exs test/cairnloop/knowledge_automation/review_task_test.exs` | planned |
| M010-S03-04-02 | 04 | 4 | REVIEW-03, OPS-02 | T-M010-S03-12 | Chunk/reindex outcomes update review-task status through durable revision links without creating a second publish path | unit | `mix test test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/knowledge_base/workers/chunk_revision_test.exs` | planned |

## Wave 0 Requirements

- [x] Every planned task has an automated verification command
- [x] The two explicit research risks are assigned to concrete tasks and threat entries
- [x] Requirement coverage spans `REVIEW-01`, `REVIEW-02`, `REVIEW-03`, and `OPS-02`
- [x] Deferred ideas and Phase 12 quick-fix/governance work stay out of scope
- [x] The quick-run command spans every planned surface

## Manual-Only Checks To Reserve For Verification

| Behavior | Requirement | Why Manual | Verification Instructions |
|----------|-------------|------------|---------------------------|
| Confirm the inbox reads as one calm review lane rather than a pile of fragmented states | REVIEW-01, REVIEW-02 | Queue clarity and action hierarchy are experiential | Open `/knowledge-base/suggestions`, filter through pending, approved-ready-to-publish, deferred, and published states, and confirm the next step is obvious in each |
| Confirm review-origin editor context stays lightweight but recoverable | REVIEW-02 | Sidebar/summary quality is UX-sensitive | Open a task for edit, verify review context remains visible, save a material change, and confirm the UI routes cleanly back to the task with `review_needed` state |
| Confirm publish follow-through remains visible after chunking succeeds or fails | REVIEW-03, OPS-02 | Status comprehension and retry cues are partly visual | Publish an approved task, then inspect the same task after chunk work completes or fails and verify the inbox shows the resulting state without losing the canonical revision link |

## Validation Sign-Off

- [x] Four execution-ready plans were created and are the preferred split for this phase
- [x] Every locked decision in `M010-S03-CONTEXT.md` is covered
- [x] `ArticleSuggestion` remains proposal-only in the plan set
- [x] Append-only history, separate workflow state, and canonical publish-path reuse are explicit
- [x] Draft-collision and editor-publish-bypass risks are surfaced and assigned to concrete tasks
- [x] Phase status is `ready_for_execution`, not verified

Execution should produce the later verification artifact after these commands have actually run.
