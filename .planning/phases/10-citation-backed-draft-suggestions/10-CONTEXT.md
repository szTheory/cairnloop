# Phase 10: Citation-Backed Draft Suggestions - Context

**Gathered:** 2026-05-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Let operators turn either a durable KB gap candidate or a stale published article signal into a grounded KB draft suggestion. This phase covers the suggestion domain, stale-signal gate, suggestion artifact shape, generation and fallback policy, and the operator review surface for inspecting evidence-backed draft proposals. It does not cover publish approval, publish execution, or broad in-thread quick-fix initiation.

</domain>

<decisions>
## Implementation Decisions

### Shared suggestion lane and domain ownership
- **D-01:** Keep one shared `Cairnloop.KnowledgeAutomation` suggestion domain for all KB-maintenance suggestions rather than separate workflows per entrypoint.
- **D-02:** Gap-driven article creation, stale-article revision suggestions, and later conversation quick fixes must converge on one suggestion artifact shape, one evidence contract, one review-task lane, and one publish handoff posture.
- **D-03:** Keep entrypoint-specific logic at the orchestration edge only: gap dashboard launches `suggest_article/2`, stale-article affordances launch `suggest_revision/2`, and later thread quick fix should still land in the same review lane.
- **D-04:** Narrow the public API to a paved-road Phoenix context surface: suggestion creation, review-task operations, and authoring handoff helpers. Keep policy plumbing, evidence builders, and entrypoint-specific preparation internal.

### Stale article trigger strictness
- **D-05:** Use a strict composite gate as the default stale-article trigger for revision suggestions.
- **D-06:** A revision suggestion requires repeated recent article-linked failure signals within a bounded recency window plus a fresh canonical grounding snapshot tied to the current published revision.
- **D-07:** Timestamp age alone is not enough to create a revision suggestion. Age may be used later for hygiene sweeps or secondary sorting, but not as the main actionable trigger in Phase 10.
- **D-08:** Looser heuristics may be considered later only if Cairnloop introduces a separate watchlist or advisory stale queue distinct from actionable revision suggestions.

### Suggestion artifact shape and review truth
- **D-09:** Persist full proposed markdown as the canonical suggestion artifact for both new articles and revisions.
- **D-10:** Revision suggestions must remain anchored to `base_revision_id`, with visible diff computed from the persisted markdown body plus the base revision content.
- **D-11:** Diff is a derived review aid, not stored truth. Do not persist model-authored patches as the primary artifact.
- **D-12:** Outline-only or shell-like artifacts are acceptable only as fail-closed fallback output, not the normal success path for Phase 10 suggestion generation.

### Grounding and fallback policy
- **D-13:** Use strict block-by-default behavior for KB draft and revision suggestions when canonical citation grounding is missing or below threshold.
- **D-14:** Assistive or resolved-case evidence may inform suggestion preparation, but canonical evidence is the only citation-eligible basis for generated KB claims.
- **D-15:** Do not generate a full best-effort suggestion with warning badges when citation grounding is insufficient. That weakens trust and muddies audit semantics.
- **D-16:** Shell fallback is not a general Phase 10 behavior. It is a narrow allowance for later conversation quick-fix seeding when the operator explicitly starts from a thread and the system must preserve a real maintenance lead without pretending the suggestion is grounded.
- **D-17:** Phase 10 operator-visible states should stay explicit and bounded: suggestion ready for review, suggestion blocked, and later quick-fix shell/manual-required states where applicable.

### Operator review surface
- **D-18:** Keep a dedicated suggestion review lane as the default first stop for AI-generated KB suggestions.
- **D-19:** The review lane must foreground provenance and trust state before editing: evidence rows, citation anchors, grounding status, stale-pressure context for revisions, and proposed markdown or derived diff.
- **D-20:** The existing KB editor is not the default first stop for generated suggestions. It should remain an explicit handoff via “Open for manual edit” after the operator has inspected the proposal.
- **D-21:** Keep review truth separate from authoring truth, following the same general posture as PR review or suggestion review workflows: proposal first, manual edit second, publish later.

### Architecture, ergonomics, and shift-left defaults
- **D-22:** Preserve host-owned Phoenix/Ecto/Oban architecture: durable Ecto state, explicit schemas, deterministic gates, Oban-backed generation, and LiveView-owned operator review.
- **D-23:** Treat stale-signal readiness, grounding status, citation validation outcome, and failure reason as durable Ecto facts, not copy-only UI annotations.
- **D-24:** Telemetry must stay bounded and Parapet-friendly. Durable workflow truth belongs in suggestion rows and later review-task rows, not in telemetry streams.
- **D-25:** Shift ordinary implementation choices left within GSD and downstream planning. Re-escalate only decisions that materially alter trust semantics, the canonical publish boundary, or the milestone scope.

### the agent's Discretion
- Exact stale-signal thresholds and recency-window tuning, as long as the gate remains deterministic, inspectable, and composite rather than age-driven.
- Exact schema and module names for internal evidence builders and preparation helpers, as long as they stay inside the host-owned `KnowledgeAutomation` lane.
- Exact review-lane layout, copy, and interaction polish, as long as provenance and trust are visible before editing.
- Exact telemetry event field naming, as long as metadata stays low-cardinality and distinct from durable evidence and decision truth.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone boundary and active requirements
- `.planning/ROADMAP.md` — Phase 10 goal, success criteria, and boundaries relative to Phases 11 and 12.
- `.planning/REQUIREMENTS.md` — `DRAFT-01`, `DRAFT-02`, `DRAFT-03`, proof posture, packaging ledger, and support-truth gate.
- `.planning/PROJECT.md` — Current milestone posture and host-owned product philosophy.
- `.planning/STATE.md` — Current carried-forward decisions and environment caveats.
- `.planning/M010-KB-AI-MAINTENANCE-SPEC.md` — KB maintenance product shape, primary flows, and domain/API direction.

### Prior phase decisions that constrain Phase 10
- `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md` — Previous Phase 10 context with the core suggestion-lane and review-surface posture that remains valid.
- `.planning/milestones/M009-phases/M009-S01-CONTEXT.md` — Retrieval facade and canonical-vs-assistive trust semantics.
- `.planning/milestones/M009-phases/M009-S02-CONTEXT.md` — Evidence-first operator UX and source/trust labeling posture.
- `.planning/milestones/M009-phases/M009-S03/M009-S03-CONTEXT.md` — Grounded drafting contract, weak-grounding fallback posture, and “show your sources” review expectations.
- `.planning/milestones/M008-phases/M008-S02-CONTEXT.md` — Markdown-native KB authoring and revision posture.

### Product and ecosystem posture
- `prompts/cairnloop_brand_book.md` — “Support that leaves a trail,” “show your sources,” and safe operator-first product posture.
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — Product wedge, embedded support-to-knowledge loop, and ecosystem lessons.
- `prompts/parapet overview for integration ideas.txt` — Bounded telemetry, evidence-vs-telemetry separation, and operator-grade diagnostics posture.
- `prompts/scoria overview for integration ideas.txt` — Durable evidence, AI observability, and operator-first audit/governance posture.

### Existing code seams
- `lib/cairnloop/knowledge_automation.ex` — Suggestion APIs, review-task handoff, and current generation/fallback flow.
- `lib/cairnloop/knowledge_automation/article_suggestion.ex` — Canonical suggestion artifact schema and grounding metadata contract.
- `lib/cairnloop/knowledge_automation/article_suggestion_evidence.ex` — Embedded evidence snapshot contract and citation-target validation seam.
- `lib/cairnloop/knowledge_automation/stale_article_signal.ex` — Composite stale-signal gate for revision suggestions.
- `lib/cairnloop/web/knowledge_base_live/gaps.ex` — Primary gap-driven suggestion launch point.
- `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` — Dedicated review lane and manual-edit handoff seam.
- `lib/cairnloop/web/article_suggestion_presenter.ex` — Trust labeling, stale-pressure presentation, diff derivation, and outcome copy.
- `lib/cairnloop/knowledge_base.ex` — KB draft and publish lifecycle that suggestions must hand off into.
- `lib/cairnloop/knowledge_base/revision.ex` — Immutable revision model backing diff derivation and authoring handoff.
- `lib/cairnloop/retrieval.ex` — Grounding bundle production and fail-closed retrieval semantics.
- `lib/cairnloop/retrieval/gap_recorder.ex` — Durable retrieval-failure recording seam relevant to stale-article evidence.
- `lib/cairnloop/automation/scoria_engine.ex` — Grounded suggestion shaping seam and missing-citation failure behavior.
- `lib/cairnloop/knowledge_automation/telemetry.ex` — Low-cardinality maintenance telemetry contract.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Cairnloop.KnowledgeAutomation` — already owns the durable maintenance lane and is the correct home for shared suggestion APIs and gating rules.
- `ArticleSuggestion` plus `ArticleSuggestionEvidence` — already provide the right host-owned artifact shape for markdown, evidence snapshots, and grounding metadata.
- `StaleArticleSignal` — already encodes the strict composite gate pattern that should remain the default stale-article trigger.
- `SuggestionReview` — already provides the dedicated review lane needed for proposal-first inspection.
- `KnowledgeBase` and `Revision` — already define a full-body draft/revision lifecycle that favors persisted markdown over patch-first storage.
- `ArticleSuggestionPresenter` — already encodes diff-as-derived-view and explicit trust/outcome presentation.

### Established Patterns
- Host-owned Ecto state over opaque workflow state.
- Oban-backed async generation and projection boundaries.
- Canonical-vs-assistive trust separation that stays visible to operators.
- Review-first, fail-closed UX instead of permissive best-effort automation.
- Bounded telemetry as an operational API, separate from durable evidence and workflow truth.

### Integration Points
- Keep `suggest_article/2` and `suggest_revision/2` as the main public creation APIs, with entrypoint-specific prep hidden behind them.
- Extend stale-signal projection and evidence digesting without creating a parallel stale-maintenance subsystem.
- Keep review-lane navigation as the shared operator destination from all suggestion entrypoints.
- Reuse the existing manual-edit handoff into `KnowledgeBase` instead of introducing a second authoring path.

</code_context>

<specifics>
## Specific Ideas

- Treat Phase 10 suggestions like proposal artifacts in a review workflow, not as implicit mutations of canonical KB content.
- Use the GitHub PR review analogy for architecture shape: canonical body is stored truth, diff is review aid, and review state stays separate from authoring state.
- Use the Google Docs “suggest then accept” lesson for operator UX: make review explicit before mutation, but avoid patch-first persistence.
- Learn from Help Scout, Intercom, and Zendesk that source quality and reviewable provenance matter more than maximizing AI suggestion throughput.
- Keep the product posture calm and explicit: if evidence is weak, say so and block or defer rather than bluffing.
- Shift ordinary implementation choices left into GSD and planning by default; only re-escalate trust-boundary decisions.

</specifics>

<deferred>
## Deferred Ideas

- Age-driven or scheduled stale-content sweeps as a separate hygiene workflow — useful later, but not the default actionable trigger in Phase 10.
- A broader watchlist or advisory queue for looser stale heuristics — separate future phase if operators need “possible issue” surfacing distinct from actionable revision suggestions.
- Patch-first or AI-authored diff persistence — out of scope for this phase and misaligned with the current KB revision lifecycle.
- Making the editor the first stop for AI-generated suggestions — defer unless the product deliberately shifts away from provenance-first review.
- General shell fallback for all suggestion types — keep deferred; Phase 10 should block by default outside later quick-fix seeding.

</deferred>

---

*Phase: 10-citation-backed-draft-suggestions*
*Context gathered: 2026-05-23*
