# Phase 12: In-Thread Quick Fix & Ops Closure - Context

**Gathered:** 2026-05-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Let operators start KB maintenance directly from live support work, while closing the loop on fail-closed behavior and bounded operational visibility. This phase covers the in-thread launch point, the evidence package used to seed KB maintenance, fallback behavior when grounding is insufficient, and the bounded telemetry plus operator-visible follow-through needed to make the lane feel complete. It does not add autonomous publishing, a second review workflow, or a broad standalone operations dashboard.

</domain>

<decisions>
## Implementation Decisions

### In-thread launch point and handoff
- **D-01:** The default quick-fix launch point should be a dedicated KB-maintenance card in the `ConversationLive` evidence rail, not the reply composer, page header, or generic host tool registry.
- **D-02:** The quick-fix action should create or reuse a host-owned suggestion plus review-task lane, then deep-link into the existing `/knowledge-base/suggestions` task detail flow instead of opening a separate Phase 12 review surface.
- **D-03:** The handoff path should preserve the Phase 11 rule that review is the first-class maintenance lane. The quick-fix entrypoint changes where work starts, not where review truth lives.
- **D-04:** Quick-fix creation and review-task creation should be idempotent and durable, using host-owned `Ecto` state plus `Oban` follow-through rather than transient LiveView state.

### Evidence packaging
- **D-05:** Quick-fix suggestion generation should use a layered evidence package, not raw thread text alone and not a canonical-only bundle.
- **D-06:** The layered package should contain three explicitly typed layers:
  - `thread_context` for the live conversation signal,
  - `canonical_retrieval` for citation-eligible published KB evidence,
  - `resolved_case_assists` for bounded non-canonical support context.
- **D-07:** Only the canonical retrieval layer is citation-eligible for generated KB claims. Thread context and resolved cases may inform drafting and operator context, but they must never be presented as canonical evidence.
- **D-08:** Evidence packaging must stay bounded and typed. Do not persist one opaque JSON blob that mixes trust levels, and do not silently widen evidence scope during retries.

### Fail-closed fallback
- **D-09:** Phase 12 should use a hybrid fallback model keyed by failure class rather than a single fallback for all failure modes.
- **D-10:** When evidence is partial but still supports a real maintenance work item, create a reviewable draft shell with the missing-grounding reason made explicit in the review lane.
- **D-11:** When a canonical evidence snapshot cannot be built, citation anchors are invalid, or guardrails fail, the quick fix should fail closed with an explicit operator-visible blocked/manual-required state instead of fabricating a suggestion.
- **D-12:** Manual authoring should remain available as an explicit operator choice from failed or shell states, but it should not become the default first handoff because that would fragment the maintenance lane and audit trail.

### Ops closure and visibility
- **D-13:** Phase 12 should add bounded telemetry and small embedded status surfaces, not telemetry alone and not a separate operations dashboard.
- **D-14:** Workflow truth must remain in durable host-owned state such as `ArticleSuggestion`, `ReviewTask`, and append-only review-task events. Telemetry is observability, not audit truth.
- **D-15:** Add bounded telemetry for quick-fix initiation, suggestion prepared/blocked outcomes, review decisions, publish attempts, and reindex completion or failure using low-cardinality enums and reason codes.
- **D-16:** Operator-visible follow-through should stay in the existing working surfaces: the conversation thread should expose the quick-fix outcome, and the shared review lane should continue to expose publish and reindex progress.
- **D-17:** Do not collapse `approved`, `published`, and `reindexed` into one generic done state. Operators need to see where work is in the lane.

### Architecture and delegation posture
- **D-18:** Keep the whole Phase 12 lane Cairnloop-owned inside Phoenix, Ecto, LiveView, Oban, and `:telemetry`; do not introduce a second workflow engine or force Scoria into the critical path.
- **D-19:** Reuse the existing review-aware editor handoff from Phase 11 for edit-before-publish recovery paths instead of creating a new quick-fix-specific authoring experience.
- **D-20:** Shift ordinary implementation choices left within GSD and downstream planning. Re-escalate only decisions that materially affect trust semantics, the canonical publish boundary, or milestone scope.

### the agent's Discretion
- Exact module and schema names for the typed quick-fix evidence package, as long as trust layers remain explicit and bounded.
- Exact route params, presenter copy, and UI polish for the evidence-rail quick-fix card, as long as the action clearly lands in the shared review lane.
- Exact fallback reason enum names and task copy, as long as operators can always tell why the system produced a shell, blocked, or routed them to manual authoring.
- Exact telemetry event names and metadata field naming, as long as they stay low-cardinality, Parapet-friendly, and separate from durable workflow truth.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone boundary and active requirements
- `.planning/ROADMAP.md` — Phase 12 goal, success criteria, and placement after the review-gated workflow.
- `.planning/REQUIREMENTS.md` — `OPS-01`, `OPS-03`, proof posture, packaging ledger, support-truth gate, and out-of-scope constraints.
- `.planning/PROJECT.md` — Current milestone posture and host-owned product philosophy.
- `.planning/STATE.md` — Current focus, carried-forward decisions, and environment caveats.
- `.planning/M010-KB-AI-MAINTENANCE-SPEC.md` — Product shape, in-thread quick-fix primary flow, suggested APIs, retrieval and authoring policy, and DX posture.

### Prior phase decisions that constrain Phase 12
- `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md` — Suggestion artifact shape, evidence snapshot rules, fallback-shell allowance, and the shared maintenance lane posture.
- `.planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md` — Review-task separation, shared review inbox, publish boundary, editor handoff, and reindex follow-through.
- `.planning/milestones/M010-phases/M010-S03/M010-S03-04-SUMMARY.md` — Publish/reindex reflection work that Phase 12 should extend, not bypass.
- `.planning/milestones/M009-phases/M009-S03/M009-S03-CONTEXT.md` — Grounded drafting contract, visible evidence, and weak-grounding escalation posture.
- `.planning/milestones/M009-phases/M009-S02/M009-S02-CONTEXT.md` — Source/trust labeling and preview-before-action operator UX.
- `.planning/milestones/M008-phases/M008-S02-CONTEXT.md` — Markdown-native KB draft/publish posture.

### Product and research posture
- `docs/cairnloop-jtbd-and-user-flows.md` — Embedded support cockpit framing and the support-to-knowledge loop this phase closes.
- `prompts/cairnloop_brand_book.md` — “Show your sources,” “support that leaves a trail,” operator cockpit posture, and calm fail-closed UX language.
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — Host-owned Phoenix support architecture, evidence-vs-telemetry guidance, knowledge-first support lessons, and operator-grade health signal posture.
- `prompts/parapet overview for integration ideas.txt` — Evidence-versus-telemetry separation, strict telemetry contract posture, and host-owned operational philosophy.
- `prompts/scoria overview for integration ideas.txt` — Optional evidence/governance lane guidance and operator-first observability posture.

### Existing code seams
- `lib/cairnloop/web/conversation_live.ex` — Current in-thread evidence rail and natural quick-fix launch surface.
- `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` — Shared task-centric review lane that remains the authoritative maintenance workflow.
- `lib/cairnloop/web/knowledge_base_live/editor.ex` — Existing review-aware editor handoff and return-path behavior.
- `lib/cairnloop/knowledge_automation.ex` — Suggestion/review commands, fail-closed suggestion preparation, and publish/reindex follow-through.
- `lib/cairnloop/knowledge_automation/article_suggestion.ex` — Suggestion artifact schema and grounding/evidence metadata seam.
- `lib/cairnloop/knowledge_base/workers/chunk_revision.ex` — Existing reindex follow-through seam.
- `lib/cairnloop/retrieval/telemetry.ex` — Bounded telemetry normalization pattern to mirror for Phase 12 maintenance events.
- `lib/cairnloop/telemetry.ex` — Central telemetry wrapper used across Cairnloop.
- `lib/cairnloop/tool_registry.ex` and `lib/cairnloop/tool.ex` — Generic host tool seams that should remain separate from the Cairnloop-owned quick-fix workflow.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ConversationLive` evidence rail — already presents “proposal beside evidence” and is the most natural place to launch KB quick-fix work.
- `Cairnloop.KnowledgeAutomation` — already owns suggestion and review-task commands, making it the correct home for quick-fix orchestration.
- `ArticleSuggestion` and `ReviewTask` — already separate proposal truth from review/publish truth, which should remain intact for thread-launched work.
- `KnowledgeBaseLive.SuggestionReview` — already provides the shared maintenance lane that thread-launched work should enter.
- `KnowledgeBaseLive.Editor` — already has review-aware return-path behavior for edit-before-publish flows.
- `Cairnloop.Retrieval.Telemetry` — already demonstrates the bounded telemetry normalization style Phase 12 should mirror.

### Established Patterns
- Host-owned Ecto state over opaque AI workflow state.
- Oban-backed async work for generation and follow-through instead of blocking request or UI paths.
- Explicit trust labeling between canonical KB evidence and assistive resolved-case evidence.
- Calm operator UX with review-first and fail-closed semantics rather than silent automation.
- Publish and reindex as explicit post-review transitions rather than implicit consequences of approval.

### Integration Points
- Add a quick-fix command path from `ConversationLive.handle_event/3` into `KnowledgeAutomation`, with durable create-or-reuse semantics for suggestions and review tasks.
- Build a typed evidence-package or evidence-snapshot builder that can package thread context with retrieval evidence without weakening citation rules.
- Extend suggestion/review outcome state to represent shell, blocked, and manual-required fallback modes.
- Add a narrow KB-maintenance telemetry helper that emits bounded quick-fix and ops-closure events.
- Expand the thread and shared review lane presenters to expose quick-fix follow-through without creating a second dashboard.

</code_context>

<specifics>
## Specific Ideas

- Prefer the Zendesk/Intercom-style in-context launch lesson: start from the thread-side knowledge/evidence area, not from a generic action menu.
- Keep the GitHub-style lesson from Phase 11: approval is not publish; for Phase 12, quick-fix creation is also not publish.
- Keep the Sanity-style lesson for follow-through visibility: lightweight status in the work lane beats a second operational control plane.
- Treat the quick fix as a new entrypoint into the same maintenance lane, not as a mini-product or a shortcut around review.
- Shift low-impact detail decisions left into downstream research/planning unless they change trust, publish safety, or scope.

</specifics>

<deferred>
## Deferred Ideas

- Broader trend dashboards, queue analytics, or LiveDashboard/Parapet surfaces beyond the embedded operator-visible statuses — future ops/reporting phase.
- One-click “approve and publish now” or any shortcut that compresses review and publish into one action — future consideration only if the publish boundary remains explicit.
- Rich multi-reviewer assignment, governed-tool workflow expansion, or required Scoria evidence persistence in the critical path — later phase.
- A generalized command palette or thread action bar for all support workflows — separate UX phase if it becomes a broader product need.

</deferred>

---

*Phase: 12-in-thread-quick-fix-ops-closure*
*Context gathered: 2026-05-22*
