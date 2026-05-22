# Phase 11: Review-Gated KB Updates - Context

**Gathered:** 2026-05-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Route AI-prepared KB article and revision suggestions through a visible operator review workflow that preserves the existing canonical publish boundary. This phase covers the review-task domain, review inbox behavior, decision tracking, draft handoff, publish gating, and reindex follow-through. It does not add autonomous publishing, broad workflow/governance expansion, or in-thread initiation from live conversation context.

</domain>

<decisions>
## Implementation Decisions

### Review domain model
- **D-01:** Keep `ArticleSuggestion` as the durable AI proposal artifact. Do not overload it with Phase 11 review and publish state.
- **D-02:** Introduce a separate host-owned `ReviewTask` domain object that wraps one `ArticleSuggestion` and owns operator workflow, decision metadata, publish handoff, and reindex follow-through.
- **D-03:** Start with one active review task per suggestion. Keep the relationship narrow and simple rather than designing a multi-review workflow up front.
- **D-04:** `ReviewTask` must preserve the distinction between three facts: what the AI proposed, what the operator decided, and what canonical KB revision was ultimately published.

### Review queue shape
- **D-05:** Phase 11 should center on one dedicated KB maintenance review inbox, not fragmented review controls embedded across gap and article screens.
- **D-06:** Gap candidates and article views remain suggestion launch points, but once a suggestion exists the operator should review it in the shared review inbox.
- **D-07:** The Phase 10 `SuggestionReview` surface is the correct foundation for this inbox. Evolve it into a task-centric list/detail review lane rather than replacing it with multiple mini-flows.
- **D-08:** The review inbox should make pending, approved-ready-to-publish, rejected, deferred, and published outcomes visible as queue states so operators do not lose follow-through work.

### Approval and publish semantics
- **D-09:** `Approve` must not publish by default.
- **D-10:** Approval should stage or update a normal KB draft revision, record the review decision, and move the task into an explicit `approved_ready_to_publish` state.
- **D-11:** Publish remains a separate explicit action that reuses the normal `KnowledgeBase.publish_revision/1` path and its existing chunk/reindex follow-through.
- **D-12:** Revision-based review tasks must re-check base-revision freshness before publish so a stale reviewed draft cannot silently overwrite newer canonical work.
- **D-13:** If later convenience is desired, add a separately labeled secondary action such as `Approve and publish now`; do not redefine plain `Approve`.

### Edit-before-publish flow
- **D-14:** Edit-before-publish should hand off into the existing KB editor rather than introducing inline editing on the review surface.
- **D-15:** The review surface remains evidence-first and decision-first; the editor remains the canonical authoring surface.
- **D-16:** The editor handoff should preload the suggestion-backed markdown and preserve a clear return path back to the review task.
- **D-17:** Keep evidence visible during authoring via lightweight context such as a sidebar, summary, or return link, but do not turn the review screen into a second markdown editor.
- **D-18:** If an approved draft is materially edited afterward, the review task should return to a review-needed state rather than pretending prior approval still applies unchanged.

### Decision tracking and audit posture
- **D-19:** Do not rely on freeform notes as the primary review record.
- **D-20:** Review decisions must be structured and queryable: decision type, bounded reason, actor, timestamp, and optional notes.
- **D-21:** Use a small bounded reason taxonomy for reject/defer/rework states. Freeform notes remain optional context, not audit truth.
- **D-22:** Persist durable review-task state transitions and decision metadata in relational host-owned state. Do not bury workflow truth only in JSON blobs or comments.
- **D-23:** Add an append-only review event/history seam so later ops and governance work can answer who did what, when, and why without rewriting state archaeology.

### Reindex and follow-through
- **D-24:** Reindex follow-through belongs to publish completion, not approve completion.
- **D-25:** Publish and reindex outcomes should be reflected back onto the review task so operators can see completion, failure, or retry-needed state from the same review lane.
- **D-26:** Follow-up jobs should use normal Oban/Ecto boundaries with explicit durable references rather than ad hoc side effects.

### Architecture and product posture
- **D-27:** Keep the whole lane Cairnloop-owned inside Phoenix, Ecto, and Oban. Do not introduce an external workflow engine or make Scoria required for the critical path.
- **D-28:** Preserve the product posture from the prompts and earlier phases: show sources, make safety explicit, keep the host app in control, and never let AI-prepared work become canonical without an explicit operator-controlled publish step.
- **D-29:** Prefer one clear workflow per surface: suggestion generation, review, authoring, and publish should stay conceptually distinct even when they hand off cleanly to each other.

### Decision delegation posture
- **D-30:** Shift ordinary implementation choices left within GSD and downstream planning. Re-escalate only decisions that materially change trust semantics, canonical publish boundaries, or milestone scope.
- **D-31:** For low-impact details such as exact route names, button copy, reason-enum naming, presenter structure, and telemetry field names, downstream agents should choose the most idiomatic host-owned approach without asking again.

### the agent's Discretion
- Exact schema/module names for `ReviewTask`, event history, and publish follow-through records, as long as proposal state, review state, and canonical revision state remain separated.
- Exact queue filters, sort order, and LiveView composition, as long as pending review and approved-ready-to-publish work remain visible and calm.
- Exact reason taxonomy labels, as long as they stay small, bounded, and queryable.
- Exact editor evidence-context affordance, as long as authors can recover the linked review context without re-reading raw source data manually.

</decisions>

<specifics>
## Specific Ideas

- Treat this like mature review/publish systems in adjacent products: proposal artifact, review task, and live publication are separate layers.
- GitHub/GitLab-style lesson: approval is not merge; keep judgment and release as separate actions.
- Zendesk/Sanity/Contentful-style lesson: draft and live content should stay distinct until explicit promotion.
- Keep the UX calm and operator-grade: one shared inbox, explicit states, visible evidence, obvious next action.
- “Support that leaves a trail” applies here directly: every review outcome should leave a durable, queryable trail instead of a vague comment.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone boundary and active requirements
- `.planning/ROADMAP.md` — Phase 11 goal, success criteria, and milestone boundary.
- `.planning/REQUIREMENTS.md` — `REVIEW-01`, `REVIEW-02`, `REVIEW-03`, `OPS-02`, proof posture, and publish-boundary constraints.
- `.planning/PROJECT.md` — Host-owned, safe-by-default product posture for Cairnloop.
- `.planning/STATE.md` — Current milestone decisions and carried-forward constraints.
- `.planning/M010-KB-AI-MAINTENANCE-SPEC.md` — Suggested review-task APIs, operator UX direction, and KB maintenance boundaries.

### Prior phase decisions that constrain Phase 11
- `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md` — Suggestion artifact shape, suggestion review surface, and the decision that publish semantics were deferred to Phase 11.
- `.planning/milestones/M010-phases/M010-S02/M010-S02-RESEARCH.md` — Evidence-first review posture and reasons the editor was not the default Phase 10 surface.
- `.planning/milestones/M009-phases/M009-S03/M009-S03-CONTEXT.md` — Keep evidence visible by default and do not hide grounding behind UI indirection.
- `.planning/milestones/M009-phases/M009-S02/M009-S02-CONTEXT.md` — Source/trust labeling posture and preview-before-action operator UX.
- `.planning/milestones/M008-phases/M008-S02-CONTEXT.md` — Markdown-native KB authoring and revision lifecycle posture.

### Product and ecosystem posture
- `prompts/cairnloop_brand_book.md` — “Support that leaves a trail,” show-your-sources posture, explicit safety, and host-owned control.
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — Product wedge, operator workflow lessons, and the importance of the knowledge-first support loop.
- `prompts/scoria overview for integration ideas.txt` — Evidence, durable operator workflows, and optional governance/quality layering.
- `prompts/parapet overview for integration ideas.txt` — Bounded telemetry, evidence-vs-telemetry separation, and host-owned operator diagnostics posture.

### Existing code seams
- `lib/cairnloop/knowledge_automation/article_suggestion.ex` — Existing proposal artifact and Phase 10 state machine that must not become the review-state dumping ground.
- `lib/cairnloop/knowledge_automation.ex` — Existing suggestion query/command facade and the natural home or neighbor for review-task commands.
- `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` — Existing Phase 10 review foundation that should evolve into the dedicated review inbox/detail lane.
- `lib/cairnloop/web/knowledge_base_live/editor.ex` — Existing authoring surface and current publish semantics that Phase 11 must preserve explicitly.
- `lib/cairnloop/knowledge_base.ex` — Canonical draft and publish lifecycle, including publish-triggered chunk/reindex follow-through.
- `lib/cairnloop/web/knowledge_base_live/gaps.ex` — Primary gap-driven launch point that should deep-link into the shared review lane.
- `lib/cairnloop/web/knowledge_base_live/index.ex` — Article-driven revision launch point that should also deep-link into the shared review lane.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Cairnloop.KnowledgeAutomation` — already owns suggestion lifecycle seams and should own or neighbor the new review-task API.
- `ArticleSuggestion` — already preserves proposal body, evidence snapshot, grounding metadata, and generation status; keep it proposal-only.
- `KnowledgeBaseLive.SuggestionReview` — already provides the list/detail review scaffold and should become task-centric rather than be discarded.
- `KnowledgeBaseLive.Editor` plus `KnowledgeBase` — already own markdown authoring, draft persistence, and publish/reindex semantics; reuse them rather than cloning them.
- `Oban`-backed publish/reindex seams — already exist and should remain the follow-through boundary after explicit publish.

### Established Patterns
- Host-owned Ecto state over opaque external workflow systems.
- Clear Phoenix context boundaries rather than one giant mutable workflow record.
- Evidence-first operator UX with visible trust and source labeling.
- Explicit safe boundaries between draft/proposal state and canonical published state.

### Integration Points
- Add `ReviewTask` query/command APIs under `Cairnloop.KnowledgeAutomation` or a tight adjacent context.
- Link `ReviewTask` to `ArticleSuggestion`, staged draft revision ids, publish outcome, and reindex outcome.
- Evolve `/knowledge-base/suggestions` into a dedicated task inbox/detail lane while preserving deep links from gaps and article views.
- Add explicit approve, reject, defer, open-for-edit, publish, and retry-follow-through commands with durable decision history.

</code_context>

<deferred>
## Deferred Ideas

- One-click `Approve and publish now` convenience action — possible later, but not the default meaning of `Approve`.
- Inline micro-editing inside the review surface — keep out of Phase 11 unless planning finds a tiny, clearly bounded affordance that does not duplicate the editor.
- Rich assignment, multi-reviewer, SLA, or governed-tool workflow expansion — later phase or backlog, not needed for core milestone closure.
- Broad Scoria-backed governance workflows or MCP participation for review tasks — optional later expansion after the core review lane is proven.
- In-thread quick-fix initiation from live conversation context — Phase 12.

</deferred>

---

*Phase: M010-S03*
*Context gathered: 2026-05-22*
