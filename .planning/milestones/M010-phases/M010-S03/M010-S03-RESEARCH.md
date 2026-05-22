# Phase 11: Review-Gated KB Updates - Research

**Researched:** 2026-05-22 [VERIFIED: current session date]
**Domain:** Host-owned KB review-task workflow over AI suggestions, editor handoff, and canonical publish or reindex follow-through. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
**Confidence:** HIGH for repo seams and phase boundaries; MEDIUM for new schema defaults because they are prescriptive recommendations layered onto existing code. [VERIFIED: lib/cairnloop/knowledge_automation.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/suggestion_review.ex] [ASSUMED]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Keep `ArticleSuggestion` as the durable AI proposal artifact. Do not overload it with Phase 11 review and publish state. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-02:** Introduce a separate host-owned `ReviewTask` domain object that wraps one `ArticleSuggestion` and owns operator workflow, decision metadata, publish handoff, and reindex follow-through. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-03:** Start with one active review task per suggestion. Keep the relationship narrow and simple rather than designing a multi-review workflow up front. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-04:** `ReviewTask` must preserve the distinction between three facts: what the AI proposed, what the operator decided, and what canonical KB revision was ultimately published. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-05:** Phase 11 should center on one dedicated KB maintenance review inbox, not fragmented review controls embedded across gap and article screens. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-06:** Gap candidates and article views remain suggestion launch points, but once a suggestion exists the operator should review it in the shared review inbox. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-07:** The Phase 10 `SuggestionReview` surface is the correct foundation for this inbox. Evolve it into a task-centric list/detail review lane rather than replacing it with multiple mini-flows. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-08:** The review inbox should make pending, approved-ready-to-publish, rejected, deferred, and published outcomes visible as queue states so operators do not lose follow-through work. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-09:** `Approve` must not publish by default. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-10:** Approval should stage or update a normal KB draft revision, record the review decision, and move the task into an explicit `approved_ready_to_publish` state. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-11:** Publish remains a separate explicit action that reuses the normal `KnowledgeBase.publish_revision/1` path and its existing chunk/reindex follow-through. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [VERIFIED: lib/cairnloop/knowledge_base.ex]
- **D-12:** Revision-based review tasks must re-check base-revision freshness before publish so a stale reviewed draft cannot silently overwrite newer canonical work. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-13:** If later convenience is desired, add a separately labeled secondary action such as `Approve and publish now`; do not redefine plain `Approve`. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-14:** Edit-before-publish should hand off into the existing KB editor rather than introducing inline editing on the review surface. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-15:** The review surface remains evidence-first and decision-first; the editor remains the canonical authoring surface. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-16:** The editor handoff should preload the suggestion-backed markdown and preserve a clear return path back to the review task. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-17:** Keep evidence visible during authoring via lightweight context such as a sidebar, summary, or return link, but do not turn the review screen into a second markdown editor. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-18:** If an approved draft is materially edited afterward, the review task should return to a review-needed state rather than pretending prior approval still applies unchanged. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-19:** Do not rely on freeform notes as the primary review record. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-20:** Review decisions must be structured and queryable: decision type, bounded reason, actor, timestamp, and optional notes. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-21:** Use a small bounded reason taxonomy for reject/defer/rework states. Freeform notes remain optional context, not audit truth. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-22:** Persist durable review-task state transitions and decision metadata in relational host-owned state. Do not bury workflow truth only in JSON blobs or comments. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-23:** Add an append-only review event/history seam so later ops and governance work can answer who did what, when, and why without rewriting state archaeology. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-24:** Reindex follow-through belongs to publish completion, not approve completion. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-25:** Publish and reindex outcomes should be reflected back onto the review task so operators can see completion, failure, or retry-needed state from the same review lane. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-26:** Follow-up jobs should use normal Oban/Ecto boundaries with explicit durable references rather than ad hoc side effects. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-27:** Keep the whole lane Cairnloop-owned inside Phoenix, Ecto, and Oban. Do not introduce an external workflow engine or make Scoria required for the critical path. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- **D-28:** Preserve the product posture from the prompts and earlier phases: show sources, make safety explicit, keep the host app in control, and never let AI-prepared work become canonical without an explicit operator-controlled publish step. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [VERIFIED: .planning/PROJECT.md]
- **D-29:** Prefer one clear workflow per surface: suggestion generation, review, authoring, and publish should stay conceptually distinct even when they hand off cleanly to each other. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]

### Claude's Discretion
- Exact schema/module names for `ReviewTask`, event history, and publish follow-through records, as long as proposal state, review state, and canonical revision state remain separated. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- Exact queue filters, sort order, and LiveView composition, as long as pending review and approved-ready-to-publish work remain visible and calm. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- Exact reason taxonomy labels, as long as they stay small, bounded, and queryable. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- Exact editor evidence-context affordance, as long as authors can recover the linked review context without re-reading raw source data manually. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)
- One-click `Approve and publish now` convenience action. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- Inline micro-editing inside the review surface. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- Rich assignment, multi-reviewer, SLA, or governed-tool workflow expansion. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- Broad Scoria-backed governance workflows or MCP participation for review tasks. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- In-thread quick-fix initiation from live conversation context. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REVIEW-01 | Operator can review a suggested article or revision with visible evidence, citation anchors, and a proposed content diff or draft body. [VERIFIED: .planning/REQUIREMENTS.md] | Evolve `KnowledgeBaseLive.SuggestionReview` into a task inbox/detail lane, keep `ArticleSuggestion` as the proposal truth, reuse `ArticleSuggestionPresenter` evidence labels, and derive revision diff from `base_revision_id` plus `proposed_markdown`. [VERIFIED: lib/cairnloop/web/knowledge_base_live/suggestion_review.ex] [VERIFIED: lib/cairnloop/web/article_suggestion_presenter.ex] [VERIFIED: lib/cairnloop/knowledge_automation/article_suggestion.ex] |
| REVIEW-02 | Operator can approve, reject, or edit-before-publish a review task without bypassing the existing KB publish flow. [VERIFIED: .planning/REQUIREMENTS.md] | Add a separate `ReviewTask` command layer; `approve` stages a KB draft via `KnowledgeBase.save_draft/2`, `reject` and `defer` write structured decisions, `edit-before-publish` routes into `KnowledgeBaseLive.Editor`, and publish stays a separate review-task action that reuses `KnowledgeBase.publish_revision/1`. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] |
| REVIEW-03 | System records review-task state transitions, decision metadata, and reindex follow-up work for approved KB updates. [VERIFIED: .planning/REQUIREMENTS.md] | Persist relational `ReviewTask` state plus append-only event history, record actor and bounded reason metadata, and reflect publish or reindex completion back onto the task because `publish_revision/1` already enqueues `ChunkRevision` transactionally. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: lib/cairnloop/knowledge_base/workers/chunk_revision.ex] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] |
| OPS-02 | Approved KB updates trigger the normal revision publish and reindex path so retrieval reflects the new canonical content. [VERIFIED: .planning/REQUIREMENTS.md] | Reuse `KnowledgeBase.publish_revision/1` unchanged as the only publish boundary and track its `ChunkRevision` job outcome on the review task instead of creating a second publish pipeline. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: test/cairnloop/knowledge_base_test.exs] |
</phase_requirements>

## Summary

Phase 11 should add a narrow review-task layer on top of the existing suggestion, editor, and publish seams rather than reworking those seams. `ArticleSuggestion` already stores the AI proposal body, evidence snapshot, grounding metadata, and generation status; it should remain proposal-only. The new workflow state belongs in a separate `ReviewTask` plus append-only event history so approval, rejection, publish, and reindex follow-through stay explicit and queryable. [VERIFIED: lib/cairnloop/knowledge_automation/article_suggestion.ex] [VERIFIED: lib/cairnloop/knowledge_automation.ex] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]

The current `/knowledge-base/suggestions` LiveView is already the right inbox foundation because it renders proposal detail, evidence, and diff-style review. Phase 11 should evolve that screen from suggestion-centric actions into task-centric actions while keeping evidence visible and routing edits into the existing editor. The important boundary is that approval stages a KB draft and records a decision, but publish remains a separate action that calls `KnowledgeBase.publish_revision/1` and lets the existing chunk or reindex job remain authoritative. [VERIFIED: lib/cairnloop/web/knowledge_base_live/suggestion_review.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [VERIFIED: lib/cairnloop/knowledge_base.ex]

**Primary recommendation:** Add `ReviewTask` and `ReviewTaskEvent` under `Cairnloop.KnowledgeAutomation`, convert `/knowledge-base/suggestions` into a task inbox, route editor handoff back into that inbox, and treat `KnowledgeBase.publish_revision/1` as the only canonical publish path. [VERIFIED: lib/cairnloop/knowledge_automation.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/suggestion_review.ex] [VERIFIED: lib/cairnloop/knowledge_base.ex] [ASSUMED]

## Locked Decisions

- Keep proposal truth, review truth, and canonical KB truth in separate records. `ArticleSuggestion` already carries proposal fields such as `proposed_markdown`, `grounding_metadata`, and `evidence_snapshot`, so adding review or publish state to that schema would collapse the distinctions Phase 11 explicitly requires. [VERIFIED: lib/cairnloop/knowledge_automation/article_suggestion.ex] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- Reuse the current suggestion review route as the shared review inbox. Both gap-driven article suggestions and article-driven revision suggestions already navigate to `/knowledge-base/suggestions?suggestion=:id`, so Phase 11 can centralize review work there without adding another inbox surface. [VERIFIED: lib/cairnloop/web/knowledge_base_live/gaps.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/index.ex] [VERIFIED: lib/cairnloop/router.ex]
- Keep publish separate from approve. The existing editor directly exposes `publish`, but the context locks in `approve != publish`; planning must therefore gate review-task publishing from the inbox and avoid letting editor handoff silently satisfy the publish step. [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Review-task persistence and state machine | API / Backend | Database / Storage | `KnowledgeAutomation` already owns suggestion lifecycle commands and Ecto state; review-task truth belongs beside it. [VERIFIED: lib/cairnloop/knowledge_automation.ex] [ASSUMED] |
| Review inbox and detail rendering | Frontend Server (SSR) | API / Backend | `KnowledgeBaseLive.SuggestionReview` already renders list/detail review data and should stay the operator surface. [VERIFIED: lib/cairnloop/web/knowledge_base_live/suggestion_review.ex] |
| Draft staging on approve | API / Backend | Database / Storage | `KnowledgeBase.save_draft/2` owns draft creation or update semantics and must stay the staging seam. [VERIFIED: lib/cairnloop/knowledge_base.ex] |
| Manual authoring after handoff | Frontend Server (SSR) | API / Backend | `KnowledgeBaseLive.Editor` is the canonical markdown authoring UI; review only routes into it. [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] |
| Canonical publish and chunk or reindex follow-through | API / Backend | Oban worker / Database / Storage | `KnowledgeBase.publish_revision/1` transitions the revision, updates the article, and enqueues `ChunkRevision` transactionally. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: test/cairnloop/knowledge_base_test.exs] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir | 1.19.5 | Application runtime and tests | The workspace runtime is already Elixir `1.19.5`, so the phase should stay inside current language and tooling conventions. [VERIFIED: `mix --version`] |
| Phoenix | 1.8.7 | LiveView host framework and routing | The repo already uses Phoenix `1.8.7` and routes the KB surfaces through `Cairnloop.Router`. [VERIFIED: mix.lock] [VERIFIED: lib/cairnloop/router.ex] |
| Phoenix LiveView | 1.1.30 | Review inbox and editor surfaces | Both existing KB surfaces are LiveViews and Phase 11 is explicitly a review UI phase. [VERIFIED: mix.lock] [VERIFIED: lib/cairnloop/web/knowledge_base_live/suggestion_review.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] |
| Ecto / Ecto SQL | 3.13.6 / 3.13.5 | Review-task persistence and transactional state transitions | Existing suggestion and KB lifecycles already rely on Ecto schema, changeset, and `Ecto.Multi` patterns. [VERIFIED: mix.lock] [VERIFIED: lib/cairnloop/knowledge_automation/article_suggestion.ex] [VERIFIED: lib/cairnloop/knowledge_base.ex] |
| Oban | 2.22.1 | Publish follow-through tracking and retry-safe background jobs | Existing suggestion generation and revision chunking already use Oban workers with durable args and uniqueness. [VERIFIED: mix.lock] [VERIFIED: lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex] [VERIFIED: lib/cairnloop/knowledge_base/workers/chunk_revision.ex] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Earmark | 1.4.48 | Markdown preview in the editor | Keep using the existing preview path; review remains evidence-first, not a second markdown renderer. [VERIFIED: mix.lock] [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] |
| Existing presenter modules | repo-local | Status, evidence, and diff copy | Extend presenter-style formatting rather than inlining decision labels into LiveView templates. [VERIFIED: lib/cairnloop/web/article_suggestion_presenter.ex] [VERIFIED: lib/cairnloop/web/gap_candidate_presenter.ex] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Separate `ReviewTask` state | Extend `ArticleSuggestion.status` | Rejected because it mixes proposal generation state with review and publish workflow truth. [VERIFIED: lib/cairnloop/knowledge_automation/article_suggestion.ex] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] |
| Shared review inbox route | New review route and duplicate LiveView | Rejected because `/knowledge-base/suggestions` already provides the list/detail foundation and both launch points already target it. [VERIFIED: lib/cairnloop/web/knowledge_base_live/suggestion_review.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/gaps.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/index.ex] |
| Existing publish path | New publish worker or direct review-task publication logic | Rejected because `KnowledgeBase.publish_revision/1` already updates canonical state and enqueues chunking in one transaction. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: test/cairnloop/knowledge_base_test.exs] |

**Installation:** No new Hex dependency is required for Phase 11 in the current recommendation. [VERIFIED: mix.exs] [ASSUMED]

## Recommended Architecture

### Recommended Project Structure

```text
lib/cairnloop/knowledge_automation/
├── review_task.ex                # review-task schema and current-state changeset
├── review_task_event.ex          # append-only structured history
├── review_task_policy.ex         # bounded decision and freshness guards
└── workers/
    └── sync_review_task_publish.ex # reflect publish/reindex outcomes onto the task

lib/cairnloop/web/
├── review_task_presenter.ex      # task labels, action availability, outcome copy
└── knowledge_base_live/
    ├── suggestion_review.ex      # evolve into task inbox/detail
    └── editor.ex                 # preload task context, save draft, return to review
```

The exact names are discretionary, but the new code should stay adjacent to `KnowledgeAutomation` and reuse the existing editor and publish modules rather than cloning them. [VERIFIED: lib/cairnloop/knowledge_automation.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [ASSUMED]

### System Architecture Diagram

```text
Gap dashboard / KB article index
        |
        v
ArticleSuggestion created or reused
        |
        v
/knowledge-base/suggestions  ->  load ReviewTask + ArticleSuggestion + evidence + diff
        |                               |
        | approve                       | reject / defer
        v                               v
KnowledgeBase.save_draft/2         ReviewTask event only
        |
        v
ReviewTask -> approved_ready_to_publish
        |
        | open_for_manual_edit
        v
KnowledgeBaseLive.Editor -> save_draft -> mark review_needed if content changed
        |
        | publish from review task only
        v
KnowledgeBase.publish_revision/1
        |
        v
ChunkRevision Oban job
        |
        v
ReviewTask publish or reindex outcome reflected back to inbox
```

This flow preserves the existing canonical publish boundary while making review and follow-through visible from one operator lane. [VERIFIED: lib/cairnloop/web/knowledge_base_live/gaps.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/index.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/suggestion_review.ex] [VERIFIED: lib/cairnloop/knowledge_base.ex] [ASSUMED]

### Pattern 1: ReviewTask Wraps ArticleSuggestion

**What:** Store current workflow state, staged revision linkage, and last decision metadata in `ReviewTask`, while `ArticleSuggestion` remains immutable proposal truth for evidence and AI output. [VERIFIED: lib/cairnloop/knowledge_automation/article_suggestion.ex] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED]

**When to use:** For every suggestion that enters operator review, including both gap-driven article suggestions and revision suggestions. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] [ASSUMED]

**Recommended fields:** `article_suggestion_id`, `status`, `staged_article_id`, `staged_revision_id`, `published_revision_id`, `base_revision_id_snapshot`, `last_decision`, `last_reason`, `last_actor_id`, `last_decided_at`, `publish_job_status`, `reindex_job_status`, and `needs_re_review`. [ASSUMED]

### Pattern 2: Append-Only ReviewTaskEvent History

**What:** Add a separate relational history seam that records state transition, decision type, bounded reason, actor, note, and task snapshot references. The existing automation layer already shows a lightweight actor-plus-metadata audit pattern through `auditor.audit/4`; Phase 11 should keep that level of explicitness while storing review events in first-class task history. [VERIFIED: lib/cairnloop/automation.ex] [VERIFIED: test/cairnloop/automation_test.exs] [ASSUMED]

**When to use:** On create, approve, reject, defer, open-for-edit, publish-started, publish-succeeded, publish-failed, and reindex follow-through updates. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED]

### Pattern 3: Approve Stages Draft, Publish Promotes Draft

**What:** Approval should call `KnowledgeBase.save_draft/2` with suggestion-backed markdown, persist the resulting `staged_revision_id` on the review task, and stop there. Publish should later load that staged revision and call `KnowledgeBase.publish_revision/1`. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED]

**When to use:** Always. Do not publish from the approval command. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]

### Pattern 4: Freshness Guard Before Publish

**What:** For revision suggestions, compare the task’s stored `base_revision_id_snapshot` against `KnowledgeBase.get_latest_active_revision(article_id)` before publish. If the published base changed, block publish and move the task to a review-needed state. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED]

**When to use:** Every revision-task publish attempt. [VERIFIED: .planning/REQUIREMENTS.md] [ASSUMED]

### Pattern 5: Editor Handoff Returns to Review

**What:** Keep `KnowledgeBaseLive.Editor` as the authoring surface, but when opened from a review task it should preload suggestion markdown, show lightweight evidence context, and return to the task instead of behaving like a free-floating publish surface. `preload_content/2` already supports `suggestion_id`; Phase 11 should extend that handoff with task context and suppress or reroute direct publish from review-origin sessions. [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [VERIFIED: test/cairnloop/web/knowledge_base_live_test.exs] [ASSUMED]

**When to use:** Only for `edit-before-publish` or post-approval edits. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]

### Anti-Patterns to Avoid

- **Review state inside `ArticleSuggestion.status`:** Phase 10 status values are generation-safe only: `:pending_generation`, `:ready`, `:failed`, and `:dismissed`. Extending those into review and publish truth will conflate workflow layers. [VERIFIED: lib/cairnloop/knowledge_automation/article_suggestion.ex] [VERIFIED: test/cairnloop/knowledge_automation/article_suggestion_test.exs]
- **Publishing from the editor handoff without returning to review:** The current editor exposes `publish` directly; leaving that behavior untouched for review-origin sessions creates a bypass around the new review-task audit trail. [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [ASSUMED]
- **Custom second publish path:** `KnowledgeBase.publish_revision/1` already updates article state and enqueues `ChunkRevision`; adding another publish mechanism would split canonical truth. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: test/cairnloop/knowledge_base_test.exs]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Publish or reindex orchestration | A new “review publish pipeline” separate from KB lifecycle | `KnowledgeBase.publish_revision/1` plus task outcome reflection | Canonical publish and chunking already happen transactionally there. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: test/cairnloop/knowledge_base_test.exs] |
| Review evidence formatting | Fresh evidence or trust-label logic inside the new LiveView | Existing `ArticleSuggestionPresenter` and search-result presenter patterns | The repo already has a vocabulary for evidence labels and revision diff copy. [VERIFIED: lib/cairnloop/web/article_suggestion_presenter.ex] |
| Async follow-through | Ad hoc `send` calls or implicit background side effects | Oban worker with durable task or revision identifiers | Existing suggestion generation and chunk indexing already use durable worker args. [VERIFIED: lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex] [VERIFIED: lib/cairnloop/knowledge_base/workers/chunk_revision.ex] |
| Audit history | JSON comment blobs on the review task | First-class `ReviewTaskEvent` rows or an equivalent relational event seam | Phase 11 explicitly requires structured, queryable decision history. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED] |

**Key insight:** Phase 11 is mostly an orchestration and state-separation problem, not a new AI or publishing problem. The repo already contains the durable proposal artifact, the editor, and the publish or reindex machinery. [VERIFIED: lib/cairnloop/knowledge_automation/article_suggestion.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [VERIFIED: lib/cairnloop/knowledge_base.ex]

## Common Pitfalls

### Pitfall 1: Draft Collision on Approve

**What goes wrong:** `KnowledgeBase.save_draft/2` updates the latest draft in place if one already exists for the article, so approving a review task can overwrite another in-progress draft for the same article. [VERIFIED: lib/cairnloop/knowledge_base.ex]

**Why it happens:** The current KB layer has no concept of “draft owned by review task X”; it only knows “latest revision for article Y.” [VERIFIED: lib/cairnloop/knowledge_base.ex] [ASSUMED]

**How to avoid:** Persist `staged_revision_id` on the task and fail closed when another unrelated draft is already active for the article, or make the task explicitly own the draft it created and only update that draft thereafter. [ASSUMED]

**Warning signs:** Approve on one task changes the content of a different draft or produces unexpected version reuse. [ASSUMED]

### Pitfall 2: Editor Handoff Bypasses Review Audit

**What goes wrong:** The operator opens the editor from review and can still click the editor’s existing `publish` button without the review task recording approval or publish follow-through. [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [ASSUMED]

**Why it happens:** The current editor has no review-task awareness beyond preloading `suggestion_id` markdown. [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [VERIFIED: test/cairnloop/web/knowledge_base_live_test.exs]

**How to avoid:** When `review_task_id` is present, suppress direct publish in the editor or route it through review-task publish command wiring. [ASSUMED]

**Warning signs:** Published revisions appear without matching review-task events or `approved_ready_to_publish` transitions. [ASSUMED]

### Pitfall 3: Approval Semantics Drift into Publish

**What goes wrong:** The inbox treats approve as “approve and publish,” which violates the explicit phase decision and weakens the canonical boundary. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]

**Why it happens:** The current product already has a direct publish button in the editor, so it is tempting to collapse actions for convenience. [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [ASSUMED]

**How to avoid:** Keep separate commands, labels, and task states: `pending_review`, `approved_ready_to_publish`, and `published`. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED]

**Warning signs:** Task history lacks an explicit approval event before publication. [ASSUMED]

### Pitfall 4: No Freshness Recheck for Revision Tasks

**What goes wrong:** A revision suggestion approved against base revision A is published after revision B becomes the new latest published version, so review silently blesses stale content. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED]

**Why it happens:** Phase 10 stores `base_revision_id`, but current publish code does not know about review freshness constraints. [VERIFIED: lib/cairnloop/knowledge_automation/article_suggestion.ex] [VERIFIED: lib/cairnloop/knowledge_base.ex]

**How to avoid:** Re-check the latest published revision during publish and move the task back to review-needed when the base no longer matches. [VERIFIED: lib/cairnloop/knowledge_base.ex] [ASSUMED]

**Warning signs:** Published revision version jumps even though the reviewed task still points at an older base. [ASSUMED]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with repo mocks and LiveView unit rendering. [VERIFIED: test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs] [VERIFIED: test/cairnloop/knowledge_base_test.exs] |
| Config file | none in repo root; use standard `mix test`. [VERIFIED: test/test_helper.exs] [VERIFIED: repo file listing] |
| Quick run command | `mix test test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/knowledge_automation/review_task_event_test.exs test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs test/cairnloop/web/knowledge_base_live_test.exs test/cairnloop/knowledge_base_test.exs` [ASSUMED] |
| Full suite command | `mix test` [VERIFIED: mix.exs] [ASSUMED] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REVIEW-01 | Inbox shows task states, evidence, citation anchors, and revision diff or draft body. [VERIFIED: .planning/REQUIREMENTS.md] | LiveView | `mix test test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` [VERIFIED: test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs] | ✅ |
| REVIEW-02 | Approve stages draft only, reject or defer record decisions, edit handoff preloads content and does not bypass review. [VERIFIED: .planning/REQUIREMENTS.md] | Context + LiveView | `mix test test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/web/knowledge_base_live_test.exs` [ASSUMED] | ❌ Wave 0 |
| REVIEW-03 | Task records current state plus append-only history for decisions and publish follow-through. [VERIFIED: .planning/REQUIREMENTS.md] | Context | `mix test test/cairnloop/knowledge_automation/review_task_test.exs test/cairnloop/knowledge_automation/review_task_event_test.exs` [ASSUMED] | ❌ Wave 0 |
| OPS-02 | Publish command reuses `KnowledgeBase.publish_revision/1` and reflects chunk or reindex outcome back to the task. [VERIFIED: .planning/REQUIREMENTS.md] | Context + worker | `mix test test/cairnloop/knowledge_base_test.exs test/cairnloop/knowledge_automation/sync_review_task_publish_test.exs` [ASSUMED] | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Run the task-specific file set for the touched review-task or LiveView surface. [ASSUMED]
- **Per wave merge:** Run all Phase 11 review-task and KB publish tests together. [ASSUMED]
- **Phase gate:** `mix test` must pass before `/gsd-verify-work`. [ASSUMED]

### Wave 0 Gaps

- [ ] `test/cairnloop/knowledge_automation/review_task_test.exs` for approve, reject, defer, publish, and freshness guards. [ASSUMED]
- [ ] `test/cairnloop/knowledge_automation/review_task_event_test.exs` for bounded reasons, actor capture, and append-only event persistence. [ASSUMED]
- [ ] `test/cairnloop/knowledge_automation/sync_review_task_publish_test.exs` for mapping publish or reindex completion and failure back to task state. [ASSUMED]
- [ ] Extend `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` with task-centric queue filters and publish gating cases. [VERIFIED: test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs] [ASSUMED]
- [ ] Extend `test/cairnloop/web/knowledge_base_live_test.exs` so editor behavior changes when opened from a review task. [VERIFIED: test/cairnloop/web/knowledge_base_live_test.exs] [ASSUMED]

The repo-backed realism blocker remains open, so the best proof posture here is still deterministic ExUnit and mocked context tests rather than live DB or worker integration proof. [VERIFIED: .planning/STATE.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Host app session handling is outside this phase’s repo scope. [VERIFIED: .planning/ROADMAP.md] [ASSUMED] |
| V3 Session Management | no | No new session primitive is introduced by the review-task lane. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED] |
| V4 Access Control | yes | Reuse tenant and host scoping patterns already present in suggestion and gap queries. [VERIFIED: lib/cairnloop/knowledge_automation.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/suggestion_review.ex] |
| V5 Input Validation | yes | Use Ecto changesets for review-task state, bounded reason enums, and note validation. [VERIFIED: lib/cairnloop/knowledge_automation/article_suggestion.ex] [ASSUMED] |
| V6 Cryptography | no | No new cryptographic primitive or secret-handling flow is required for this phase. [VERIFIED: .planning/ROADMAP.md] [ASSUMED] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Cross-tenant review-task access | Elevation of privilege | Apply the same `tenant_scope` and `host_user_id` filters used by suggestion reads. [VERIFIED: lib/cairnloop/knowledge_automation.ex] [VERIFIED: test/cairnloop/knowledge_automation/article_suggestion_test.exs] [ASSUMED] |
| Publish from stale reviewed base | Tampering | Re-check current published revision before publish and force re-review on mismatch. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED] |
| Missing review audit trail | Repudiation | Persist append-only task events with actor, reason, and timestamp. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED] |
| Review-origin editor publish bypass | Elevation of privilege | Make editor review-task-aware so review-origin sessions cannot skip the task publish command. [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [ASSUMED] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ReviewTask` plus `ReviewTaskEvent` is the minimal schema split needed; no third persistence object is necessary in Phase 11. [ASSUMED] | Recommended Architecture | Planner may under-scope data modeling if publish outcome detail needs a separate table. |
| A2 | Review-origin editor sessions should suppress direct editor publish and route back through review-task publish. [ASSUMED] | Recommended Architecture | If the product deliberately wants editor-origin publish, the implementation will need a different guard and audit path. |
| A3 | Task statuses should include `pending_review`, `approved_ready_to_publish`, `review_needed`, `rejected`, `deferred`, `published`, and `publish_failed`. [ASSUMED] | Resolved Defaults | Different naming or fewer states will change route filters, presenter logic, and tests. |
| A4 | If another unrelated draft already exists for the same article, approve should fail closed instead of overwriting it. [ASSUMED] | Common Pitfalls | If the intended behavior is merge or replace, planner tasks will need a different conflict policy. |

## Resolved Defaults

1. Use one active `ReviewTask` per `ArticleSuggestion`, enforced with a unique index on `article_suggestion_id` for non-terminal states. This matches the locked narrow relationship while keeping replacement or rerun behavior explicit. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED]
2. Keep the current suggestion route and evolve it into a task inbox rather than adding a second review route. Launch points from gaps and article index should deep-link by task once a review task exists. [VERIFIED: lib/cairnloop/web/knowledge_base_live/gaps.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/index.ex] [VERIFIED: lib/cairnloop/router.ex] [ASSUMED]
3. On approve, call `KnowledgeBase.save_draft/2`, store `staged_revision_id`, copy `base_revision_id` into task snapshot fields, emit a structured approve event, and move to `approved_ready_to_publish`. Do not call `publish_revision/1` here. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED]
4. On editor save after approval, compare the saved draft content against the original suggestion body. If it changed materially, set the task to `review_needed` and append an `edited_after_approval` event. [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED]
5. Publish should load the task’s `staged_revision_id`, re-check freshness for revision tasks, call `KnowledgeBase.publish_revision/1`, and then record both publish result and chunk or reindex follow-through result on the task. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: lib/cairnloop/knowledge_base/workers/chunk_revision.ex] [ASSUMED]
6. Use a small bounded reason taxonomy such as `:insufficient_quality`, `:needs_manual_rewrite`, `:superseded`, `:waiting_on_product_input`, and `:stale_base_revision`. Freeform notes stay optional. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md] [ASSUMED]

## Sources

### Primary (HIGH confidence)

- `.planning/ROADMAP.md` - Phase 11 goal, success criteria, and scope boundary. [VERIFIED: .planning/ROADMAP.md]
- `.planning/REQUIREMENTS.md` - `REVIEW-01`, `REVIEW-02`, `REVIEW-03`, and `OPS-02`. [VERIFIED: .planning/REQUIREMENTS.md]
- `.planning/PROJECT.md` - host-owned and no-autonomous-publish product posture. [VERIFIED: .planning/PROJECT.md]
- `.planning/STATE.md` - current proof posture and repo-backed realism blocker. [VERIFIED: .planning/STATE.md]
- `.planning/M010-KB-AI-MAINTENANCE-SPEC.md` - suggested public API and review/publish separation. [VERIFIED: .planning/M010-KB-AI-MAINTENANCE-SPEC.md]
- `.planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md` - locked decisions and deferred scope. [VERIFIED: .planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md]
- `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md` - carry-forward Phase 10 suggestion boundaries. [VERIFIED: .planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md]
- `.planning/milestones/M010-phases/M010-S02/M010-S02-RESEARCH.md` - validated evidence-first suggestion posture. [VERIFIED: .planning/milestones/M010-phases/M010-S02/M010-S02-RESEARCH.md]
- `.planning/milestones/M010-phases/M010-S02/M010-S02-PLAN-CHECK.md` - confirms Phase 10 intent and boundary cleanliness. [VERIFIED: .planning/milestones/M010-phases/M010-S02/M010-S02-PLAN-CHECK.md]
- `lib/cairnloop/knowledge_automation.ex` - suggestion lifecycle, reuse seams, and context ownership. [VERIFIED: lib/cairnloop/knowledge_automation.ex]
- `lib/cairnloop/knowledge_automation/article_suggestion.ex` - proposal schema and generation-only statuses. [VERIFIED: lib/cairnloop/knowledge_automation/article_suggestion.ex]
- `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` - current review inbox foundation. [VERIFIED: lib/cairnloop/web/knowledge_base_live/suggestion_review.ex]
- `lib/cairnloop/web/knowledge_base_live/editor.ex` - existing editor handoff and direct publish behavior. [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex]
- `lib/cairnloop/knowledge_base.ex` - draft and publish lifecycle. [VERIFIED: lib/cairnloop/knowledge_base.ex]
- `lib/cairnloop/router.ex` - route topology for gaps, suggestions, and editor. [VERIFIED: lib/cairnloop/router.ex]
- `lib/cairnloop/web/article_suggestion_presenter.ex` - evidence labels and diff presentation. [VERIFIED: lib/cairnloop/web/article_suggestion_presenter.ex]
- `lib/cairnloop/web/knowledge_base_live/gaps.ex` and `index.ex` - launch points into the shared review lane. [VERIFIED: lib/cairnloop/web/knowledge_base_live/gaps.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/index.ex]
- `lib/cairnloop/knowledge_base/workers/chunk_revision.ex` - existing reindex follow-through worker. [VERIFIED: lib/cairnloop/knowledge_base/workers/chunk_revision.ex]
- `test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs` - current LiveView proof shape. [VERIFIED: test/cairnloop/web/knowledge_base_live/suggestion_review_test.exs]
- `test/cairnloop/web/knowledge_base_live_test.exs` - editor preload and render behavior. [VERIFIED: test/cairnloop/web/knowledge_base_live_test.exs]
- `test/cairnloop/knowledge_base_test.exs` - publish enqueues chunk job transactionally. [VERIFIED: test/cairnloop/knowledge_base_test.exs]
- `test/cairnloop/knowledge_automation/article_suggestion_test.exs` - migration, scope, and status expectations. [VERIFIED: test/cairnloop/knowledge_automation/article_suggestion_test.exs]
- `priv/repo/migrations/20260521020000_add_article_suggestions.exs` - current suggestion table and indexes. [VERIFIED: priv/repo/migrations/20260521020000_add_article_suggestions.exs]
- `lib/cairnloop/automation.ex` and `test/cairnloop/automation_test.exs` - existing actor-plus-audit pattern to mirror. [VERIFIED: lib/cairnloop/automation.ex] [VERIFIED: test/cairnloop/automation_test.exs]
- `mix.exs`, `mix.lock`, and `mix --version` - current stack and runtime versions. [VERIFIED: mix.exs] [VERIFIED: mix.lock] [VERIFIED: `mix --version`]

### Secondary (MEDIUM confidence)

- None. No external documentation was required beyond repo and planning artifacts for this phase research. [VERIFIED: current session research scope]

### Tertiary (LOW confidence)

- None. [VERIFIED: current session research scope]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH, because all stack claims come from `mix.exs`, `mix.lock`, and local runtime. [VERIFIED: mix.exs] [VERIFIED: mix.lock] [VERIFIED: `mix --version`]
- Architecture: HIGH for boundary placement and reuse seams, MEDIUM for exact new schema defaults because they are prescriptive additions. [VERIFIED: lib/cairnloop/knowledge_automation.ex] [VERIFIED: lib/cairnloop/knowledge_base.ex] [ASSUMED]
- Pitfalls: HIGH for existing editor and draft-collision risks because those follow directly from current code paths. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex]

**Research date:** 2026-05-22 [VERIFIED: current session date]
**Valid until:** 2026-06-21 for repo-local architecture and 2026-05-29 for any workflow assumptions not yet implemented. [ASSUMED]

## RESEARCH COMPLETE

**Phase:** 11 - Review-Gated KB Updates [VERIFIED: .planning/ROADMAP.md]
**Confidence:** HIGH for implementation planning inside the current repo boundary; MEDIUM for the exact task schema defaults until planning locks names and states. [VERIFIED: lib/cairnloop/knowledge_automation.ex] [ASSUMED]

### Key Findings

- `ArticleSuggestion` already cleanly holds AI proposal truth and should not absorb review or publish workflow state. [VERIFIED: lib/cairnloop/knowledge_automation/article_suggestion.ex]
- `/knowledge-base/suggestions` is already the shared review entrypoint from both gaps and article revision flows, so Phase 11 should evolve it instead of creating another inbox. [VERIFIED: lib/cairnloop/web/knowledge_base_live/gaps.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/index.ex] [VERIFIED: lib/cairnloop/web/knowledge_base_live/suggestion_review.ex]
- `KnowledgeBase.publish_revision/1` already owns canonical publication and transactional chunk-job enqueue, so OPS-02 should be implemented by reusing that path and reflecting the outcome back to the task. [VERIFIED: lib/cairnloop/knowledge_base.ex] [VERIFIED: test/cairnloop/knowledge_base_test.exs]
- The biggest implementation risk is the existing editor’s direct publish button, because review-origin sessions can otherwise bypass the new review-task audit trail. [VERIFIED: lib/cairnloop/web/knowledge_base_live/editor.ex] [ASSUMED]
- The second major risk is draft collision, because `save_draft/2` updates the current draft in place and therefore needs task-aware conflict handling for article revisions. [VERIFIED: lib/cairnloop/knowledge_base.ex] [ASSUMED]

### File Created

`.planning/milestones/M010-phases/M010-S03/M010-S03-RESEARCH.md` [VERIFIED: this file]
