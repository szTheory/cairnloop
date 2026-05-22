# Phase 10: Citation-Backed Draft Suggestions - Context

**Gathered:** 2026-05-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Let operators turn either a durable KB gap candidate or a clearly stale published article into a grounded KB draft suggestion. This phase covers suggestion entrypoints, stale-signal standards, suggestion artifact shape, and the initial operator inspection surface. It does not cover publish approval, review-task decisions, or in-thread quick-fix initiation.

</domain>

<decisions>
## Implementation Decisions

### Suggestion domain and entrypoints
- **D-01:** Phase 10 supports both suggestion entrypoints required by the milestone: generate a new article from a gap candidate and generate a revision suggestion from an existing published article.
- **D-02:** These entrypoints must converge into one shared KB-maintenance suggestion domain, not two separate pipelines.
- **D-03:** The gap dashboard remains the primary operator home for suggestion generation because it is already the ranked maintenance queue established in Phase 9.
- **D-04:** The stale-article entrypoint should be a thinner secondary affordance that opens the same suggestion pipeline and artifact type used by gap-driven generation.
- **D-05:** Suggestion generation must stay off the request path and run through a durable host-owned Oban job boundary with uniqueness keyed by entrypoint identity plus evidence digest.

### Stale article detection
- **D-06:** “Stale or incomplete” does not mean “old by timestamp.” Age alone is not enough to create a revision suggestion.
- **D-07:** The default stale-article trigger is a composite evidence gate: repeated recent article-linked failure signals within a bounded recency window plus a fresh citation-backed grounding snapshot.
- **D-08:** Valid article-linked failure signals include recurring weak-grounding outcomes, repeated manual clarification or escalation after the article was retrieved, or repeated support evidence showing the article did not resolve the issue cleanly.
- **D-09:** No revision suggestion may be created unless the system can anchor the suggestion to a current published KB revision and valid citation targets from canonical evidence.
- **D-10:** Rare one-off article failures may remain visible as evidence, but they do not auto-promote into a revision suggestion by default in Phase 10.

### Suggestion artifact shape
- **D-11:** The canonical persisted suggestion artifact is a full proposed markdown body, not an outline-only shell and not an AI-authored patch.
- **D-12:** New-article suggestions produce a full markdown article draft.
- **D-13:** Revision suggestions produce a full proposed markdown revision body anchored to a specific `base_revision_id`.
- **D-14:** Both suggestion types also persist small structured metadata: at minimum `operator_summary`, title or change summary, `evidence_snapshot`, `grounding_metadata`, and entrypoint identity.
- **D-15:** For revision suggestions, the app computes the visible diff from `base_revision_id` plus proposed markdown body. The diff is a derived review aid, not the canonical stored truth.
- **D-16:** Outline or draft-shell output is acceptable only as a fail-closed fallback when grounding is insufficient for a normal suggestion success path.
- **D-17:** Citations and evidence stay adjacent to the editable body in the review surface; they should not be inlined into markdown by default.

### Operator handoff surface
- **D-18:** Phase 10 should introduce a small dedicated suggestion review surface instead of overloading either the gap dashboard or the current KB editor.
- **D-19:** This review surface must work for both gap-driven create suggestions and stale-article revision suggestions.
- **D-20:** The review surface should foreground provenance and trust state: evidence, citation anchors, grounding status, and proposed body or diff before any editing or publish-shaped action.
- **D-21:** Phase 10 actions stop at suggestion-safe boundaries such as generate, inspect, regenerate, dismiss, and open into the manual editing path. Publish and approval decisions remain Phase 11 work.
- **D-22:** The existing KB editor is not the default first stop for AI-generated suggestions in Phase 10 because it currently implies direct authoring or publish flow rather than review of a proposal artifact.

### Architecture and ergonomics
- **D-23:** Add one host-owned KB-maintenance suggestion artifact and state machine under `Cairnloop.KnowledgeAutomation` or an adjacent Cairnloop-owned context, rather than reusing conversation `Draft` records directly.
- **D-24:** The shared suggestion pipeline should reuse one evidence snapshot contract, one grounding-judge policy, and one citation-validation boundary for both new-article and revision suggestions.
- **D-25:** Phase 10 should preserve Phoenix/Ecto/Oban idioms: durable Ecto state, explicit structs and changesets, Oban-backed generation work, and LiveView-owned operator inspection.
- **D-26:** Telemetry for generation outcomes, citation-validity failures, and stale-detection reasons should follow bounded Parapet-friendly metadata and remain durable enough for later review and operations phases.

### the agent's Discretion
- Exact schema and module names for the suggestion artifact, so long as the domain stays host-owned and separate from publish state.
- Exact thresholds for the composite stale-article gate, so long as they are deterministic, inspectable, and seeded-testable.
- Exact review-surface layout and copy, so long as evidence and trust signals remain visible by default.
- Exact prompt wording and regeneration controls, so long as canonical-first citation rules remain enforced.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone boundary and active requirements
- `.planning/ROADMAP.md` — Phase 10 goal, success criteria, and explicit boundary relative to Phases 11 and 12.
- `.planning/REQUIREMENTS.md` — `DRAFT-01`, `DRAFT-02`, `DRAFT-03`, proof posture, packaging ledger, and out-of-scope rules.
- `.planning/PROJECT.md` — Current milestone posture: embedded, host-owned, safe-by-default KB maintenance.
- `.planning/STATE.md` — Current focus, carried-forward milestone decisions, and pending todo context.
- `.planning/M010-KB-AI-MAINTENANCE-SPEC.md` — Primary flows, suggested API/domain shape, operator UX direction, and Scoria/KB maintenance boundaries.

### Prior phase decisions that constrain Phase 10
- `.planning/milestones/M008-phases/M008-S02-CONTEXT.md` — Markdown-native KB authoring posture and draft revision model.
- `.planning/milestones/M009-phases/M009-S01-CONTEXT.md` — Retrieval facade, canonical-vs-assistive trust semantics, and deterministic retrieval posture.
- `.planning/milestones/M009-phases/M009-S02-CONTEXT.md` — Evidence-first operator UX, source/trust labeling, and preview-before-action posture.
- `.planning/milestones/M009-phases/M009-S03/M009-S03-CONTEXT.md` — Grounded drafting contract, adjacent evidence rail posture, weak-grounding fallback rules, and “do not hide sources” decisions.

### Existing Phase 9 groundwork
- `.planning/milestones/M010-phases/M010-S01/M010-S01-RESEARCH.md` — Gap-candidate architecture and anti-patterns that Phase 10 should build on, not bypass.
- `.planning/milestones/M010-phases/M010-S01/M010-S01-VALIDATION.md` — Verified queue, builder, and dashboard boundaries from Phase 9.
- `.planning/milestones/M010-phases/M010-S01/M010-S01-VERIFICATION.md` — Confirmed delivered outcomes and residual risk from Phase 9.

### Product and ecosystem posture
- `prompts/cairnloop_brand_book.md` — “Support that leaves a trail,” show-your-sources posture, explicit safety, and host-owned control.
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — Product wedge, adjacent product lessons, operator workflow priorities, and knowledge-first support automation posture.
- `prompts/scoria overview for integration ideas.txt` — Evidence, traceability, evaluation, and operator-grade AI quality layer guidance.
- `prompts/parapet overview for integration ideas.txt` — Bounded telemetry, evidence-vs-telemetry separation, and operator-grade operational contract guidance.

### Existing code seams
- `lib/cairnloop/knowledge_automation.ex` — Current Phase 9 gap-candidate facade and likely home or neighbor for Phase 10 suggestion APIs.
- `lib/cairnloop/web/knowledge_base_live/gaps.ex` — Current maintenance queue surface and primary gap-driven suggestion launch point.
- `lib/cairnloop/web/knowledge_base_live/editor.ex` — Existing markdown editor whose current semantics should not become the default Phase 10 review surface.
- `lib/cairnloop/knowledge_base.ex` — Draft and publish revision lifecycle that suggestion artifacts must hand off into without bypassing.
- `lib/cairnloop/retrieval.ex` — Grounding bundle production and retrieval diagnostics used to support citation-backed suggestion gating.
- `lib/cairnloop/retrieval/result.ex` — Normalized evidence contract with source, trust, and citation fields.
- `lib/cairnloop/retrieval/gap_recorder.ex` — Durable retrieval-failure recording seam relevant to stale-article evidence gating.
- `lib/cairnloop/automation/scoria_engine.ex` — Existing structured proposal seam that demonstrates grounded artifact shaping but is conversation-oriented.
- `lib/cairnloop/automation/workers/draft_worker.ex` — Existing Oban-backed generation pattern and fail-closed grounding branch behavior.
- `lib/cairnloop/web/conversation_live.ex` — Existing adjacent-evidence review pattern that should inform the suggestion surface.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Cairnloop.KnowledgeAutomation` — already owns the durable Phase 9 maintenance queue and is the natural place for shared suggestion APIs and read-model access.
- `Cairnloop.Retrieval` and `Cairnloop.Retrieval.Result` — already provide citation-aware evidence bundles and canonical-vs-assistive trust semantics.
- `Cairnloop.KnowledgeBase` plus `KnowledgeBaseLive.Editor` — already own markdown draft and revision persistence, which suggestion artifacts should eventually feed without bypassing review.
- `ConversationLive` draft evidence rail — already demonstrates the preferred “proposal beside evidence” review posture.

### Established Patterns
- Host-owned Ecto state over opaque vendor-managed workflows.
- Oban-backed asynchronous generation and refresh boundaries.
- Explicit trust labels and source distinctions that remain visible to operators.
- Calm operator UX that favors inspectability and fail-closed states over aggressive automation.

### Integration Points
- Add shared `suggest_article/2` and `suggest_revision/2` APIs under the KB-maintenance context.
- Add a durable suggestion artifact with `base_revision_id` support for revision proposals and evidence-snapshot persistence for both suggestion types.
- Extend stale-signal projection from retrieval and support evidence into an article-linked maintenance trigger, but keep it deterministic and bounded.
- Add a dedicated suggestion review LiveView that sits between queue/editor concerns and becomes the Phase 11 review foundation.

</code_context>

<specifics>
## Specific Ideas

- Treat Phase 10 output as a review artifact, not as an implicit mutation of an article.
- Keep one coherent maintenance lane with multiple launch points, not two mini-products.
- Compute revision diffs in-app from canonical markdown bodies instead of persisting model-authored patches.
- Preserve the “Knowledge Base vs similar resolved case” trust distinction on every suggestion surface.
- Shift ordinary implementation choices left within GSD and downstream planning; only re-escalate future decisions that materially alter trust semantics, milestone scope, or the canonical publish boundary.

</specifics>

<deferred>
## Deferred Ideas

- Time-based article reverification or stale sweeps as a standalone maintenance chore — useful later, but not the default Phase 10 suggestion trigger.
- Publish approval, reject/approve decision tracking, and reindex follow-through — Phase 11.
- In-thread quick-fix initiation from live conversation context — Phase 12.
- Centralizing duplicated fail-closed search guards beyond what Phase 10 directly needs — keep as separate follow-on work unless planning finds a low-risk seam.
- Repo-backed realism verification lanes for DB-heavy proof — environment concern remains open outside this discussion scope.

</deferred>

---

*Phase: M010-S02*
*Context gathered: 2026-05-21*
