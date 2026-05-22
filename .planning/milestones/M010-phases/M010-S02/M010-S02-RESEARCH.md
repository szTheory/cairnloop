# Phase M010-S02: Citation-Backed Draft Suggestions - Research

**Researched:** 2026-05-21 [VERIFIED: local system date]  
**Domain:** Host-owned KB maintenance suggestion generation over existing retrieval, KB revision, and LiveView seams. [VERIFIED: `.planning/ROADMAP.md`] [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`] [VERIFIED: `lib/cairnloop/knowledge_automation.ex`] [VERIFIED: `lib/cairnloop/retrieval.ex`]  
**Confidence:** HIGH. The phase boundary, retrieval contract, draft-worker pattern, and Phase 9 queue seams are all already present in-repo; the remaining work is mostly additive inside existing Phoenix/Ecto/Oban idioms. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `.planning/milestones/M010-phases/M010-S01/M010-S01-RESEARCH.md`] [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] [VERIFIED: `mix.lock`]  

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Phase 10 supports both suggestion entrypoints required by the milestone: generate a new article from a gap candidate and generate a revision suggestion from an existing published article. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- **D-02:** These entrypoints must converge into one shared KB-maintenance suggestion domain, not two separate pipelines. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- **D-03:** The gap dashboard remains the primary operator home for suggestion generation because it is already the ranked maintenance queue established in Phase 9. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/web/knowledge_base_live/gaps.ex`]
- **D-04:** The stale-article entrypoint should be a thinner secondary affordance that opens the same suggestion pipeline and artifact type used by gap-driven generation. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- **D-05:** Suggestion generation must stay off the request path and run through a durable host-owned Oban job boundary with uniqueness keyed by entrypoint identity plus evidence digest. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [CITED: https://hexdocs.pm/oban/unique_jobs.html]
- **D-06:** “Stale or incomplete” does not mean “old by timestamp.” Age alone is not enough to create a revision suggestion. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `.planning/REQUIREMENTS.md`]
- **D-07:** The default stale-article trigger is a composite evidence gate: repeated recent article-linked failure signals within a bounded recency window plus a fresh citation-backed grounding snapshot. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- **D-08:** Valid article-linked failure signals include recurring weak-grounding outcomes, repeated manual clarification or escalation after the article was retrieved, or repeated support evidence showing the article did not resolve the issue cleanly. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- **D-09:** No revision suggestion may be created unless the system can anchor the suggestion to a current published KB revision and valid citation targets from canonical evidence. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/knowledge_base.ex`] [VERIFIED: `lib/cairnloop/retrieval/providers/knowledge_base.ex`]
- **D-10:** Rare one-off article failures may remain visible as evidence, but they do not auto-promote into a revision suggestion by default in Phase 10. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- **D-11:** The canonical persisted suggestion artifact is a full proposed markdown body, not an outline-only shell and not an AI-authored patch. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- **D-12:** New-article suggestions produce a full markdown article draft. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- **D-13:** Revision suggestions produce a full proposed markdown revision body anchored to a specific `base_revision_id`. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/knowledge_base/revision.ex`]
- **D-14:** Both suggestion types also persist small structured metadata: at minimum `operator_summary`, title or change summary, `evidence_snapshot`, `grounding_metadata`, and entrypoint identity. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- **D-15:** For revision suggestions, the app computes the visible diff from `base_revision_id` plus proposed markdown body. The diff is a derived review aid, not the canonical stored truth. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- **D-16:** Outline or draft-shell output is acceptable only as a fail-closed fallback when grounding is insufficient for a normal suggestion success path. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `.planning/REQUIREMENTS.md`]
- **D-17:** Citations and evidence stay adjacent to the editable body in the review surface; they should not be inlined into markdown by default. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/web/conversation_live.ex`]
- **D-18:** Phase 10 should introduce a small dedicated suggestion review surface instead of overloading either the gap dashboard or the current KB editor. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/web/knowledge_base_live/gaps.ex`] [VERIFIED: `lib/cairnloop/web/knowledge_base_live/editor.ex`]
- **D-19:** This review surface must work for both gap-driven create suggestions and stale-article revision suggestions. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- **D-20:** The review surface should foreground provenance and trust state: evidence, citation anchors, grounding status, and proposed body or diff before any editing or publish-shaped action. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/web/conversation_live.ex`]
- **D-21:** Phase 10 actions stop at suggestion-safe boundaries such as generate, inspect, regenerate, dismiss, and open into the manual editing path. Publish and approval decisions remain Phase 11 work. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `.planning/ROADMAP.md`]
- **D-22:** The existing KB editor is not the default first stop for AI-generated suggestions in Phase 10 because it currently implies direct authoring or publish flow rather than review of a proposal artifact. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/web/knowledge_base_live/editor.ex`]
- **D-23:** Add one host-owned KB-maintenance suggestion artifact and state machine under `Cairnloop.KnowledgeAutomation` or an adjacent Cairnloop-owned context, rather than reusing conversation `Draft` records directly. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/knowledge_automation.ex`] [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`]
- **D-24:** The shared suggestion pipeline should reuse one evidence snapshot contract, one grounding-judge policy, and one citation-validation boundary for both new-article and revision suggestions. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/retrieval.ex`] [VERIFIED: `lib/cairnloop/retrieval/result.ex`]
- **D-25:** Phase 10 should preserve Phoenix/Ecto/Oban idioms: durable Ecto state, explicit structs and changesets, Oban-backed generation work, and LiveView-owned operator inspection. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/knowledge_automation.ex`] [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] [VERIFIED: `lib/cairnloop/web/knowledge_base_live/gaps.ex`]
- **D-26:** Telemetry for generation outcomes, citation-validity failures, and stale-detection reasons should follow bounded Parapet-friendly metadata and remain durable enough for later review and operations phases. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/retrieval/telemetry.ex`]

### Claude's Discretion
- Exact schema and module names for the suggestion artifact, so long as the domain stays host-owned and separate from publish state. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- Exact thresholds for the composite stale-article gate, so long as they are deterministic, inspectable, and seeded-testable. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- Exact review-surface layout and copy, so long as evidence and trust signals remain visible by default. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- Exact prompt wording and regeneration controls, so long as canonical-first citation rules remain enforced. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]

### Deferred Ideas (OUT OF SCOPE)
- Time-based article reverification or stale sweeps as a standalone maintenance chore. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- Publish approval, reject/approve decision tracking, and reindex follow-through. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `.planning/ROADMAP.md`]
- In-thread quick-fix initiation from live conversation context. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `.planning/ROADMAP.md`]
- Centralizing duplicated fail-closed search guards beyond what Phase 10 directly needs. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- Repo-backed realism verification lanes for DB-heavy proof. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `.planning/STATE.md`]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DRAFT-01 | Operator can generate a draft article suggestion from a selected gap candidate using citation-backed evidence only. [VERIFIED: `.planning/REQUIREMENTS.md`] | Shared `suggest_article/2` suggestion domain, canonical-only citation validation, Oban generation boundary, and suggestion review surface. [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`] [VERIFIED: `lib/cairnloop/knowledge_automation.ex`] [VERIFIED: `lib/cairnloop/retrieval/providers/knowledge_base.ex`] |
| DRAFT-02 | Operator can generate a suggested revision for an existing KB article when retrieval evidence shows the published article is stale or incomplete. [VERIFIED: `.planning/REQUIREMENTS.md`] | Deterministic stale-article trigger, `base_revision_id`-anchored revision suggestion artifact, and diff-as-derived-view posture. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/knowledge_base.ex`] |
| DRAFT-03 | System blocks draft or revision recommendations that lack valid citations or exceed grounding confidence thresholds. [VERIFIED: `.planning/REQUIREMENTS.md`] | Reuse retrieval grounding diagnostics, require canonical citation anchors, fail closed when evidence snapshots are incomplete, and keep weak/assistive evidence advisory only. [VERIFIED: `lib/cairnloop/retrieval.ex`] [VERIFIED: `lib/cairnloop/retrieval/result.ex`] [VERIFIED: `lib/cairnloop/retrieval/telemetry.ex`] |
</phase_requirements>

## Summary

Phase 10 should be implemented as a Cairnloop-owned suggestion layer adjacent to the Phase 9 gap queue, not as an extension of conversation drafts and not as a shortcut into KB publishing. The repo already has the needed primitives: a ranked maintenance queue in `Cairnloop.KnowledgeAutomation`, a citation-bearing retrieval bundle that distinguishes canonical KB evidence from assistive resolved cases, an Oban-backed generation pattern in `DraftWorker`, and a KB revision model that preserves draft-vs-published boundaries. [VERIFIED: `lib/cairnloop/knowledge_automation.ex`] [VERIFIED: `lib/cairnloop/retrieval.ex`] [VERIFIED: `lib/cairnloop/retrieval/providers/knowledge_base.ex`] [VERIFIED: `lib/cairnloop/retrieval/providers/resolved_cases.ex`] [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] [VERIFIED: `lib/cairnloop/knowledge_base.ex`] [VERIFIED: `lib/cairnloop/knowledge_base/revision.ex`]

The key planning constraint is that Phase 10 must treat suggestion generation as a review artifact factory with a hard citation gate. Retrieval evidence already exposes `citation_target`, `trust_level`, grounding diagnostics, and bounded telemetry. The phase should reuse those contracts to build and validate an `evidence_snapshot`, refuse success when canonical anchors are missing, and persist a full proposed markdown body plus metadata for later review. Assistive evidence may explain why an article is stale or why a gap matters, but it must not be enough by itself to pass the generation gate. [VERIFIED: `lib/cairnloop/retrieval/result.ex`] [VERIFIED: `lib/cairnloop/retrieval.ex`] [VERIFIED: `lib/cairnloop/retrieval/telemetry.ex`] [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`]

**Primary recommendation:** Add one `KnowledgeAutomation` suggestion artifact and worker pipeline that serves both `suggest_article/2` and `suggest_revision/2`, validates a canonical-only evidence snapshot before persistence, derives revision diffs from `base_revision_id`, and stops the operator flow at inspect/regenerate/dismiss/open-for-manual-edit. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `.planning/ROADMAP.md`] [VERIFIED: `lib/cairnloop/web/knowledge_base_live/editor.ex`] [CITED: https://hexdocs.pm/oban/unique_jobs.html]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Suggestion generation orchestration | API / Backend | Database / Storage | The generation gate depends on retrieval diagnostics, job dispatch, and durable state, all of which already live in Cairnloop contexts and Oban workers rather than LiveView request handling. [VERIFIED: `lib/cairnloop/knowledge_automation.ex`] [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] |
| Evidence snapshot construction and citation validation | API / Backend | Database / Storage | Retrieval normalizes evidence, trust, and citation targets in backend structs before UI rendering. [VERIFIED: `lib/cairnloop/retrieval.ex`] [VERIFIED: `lib/cairnloop/retrieval/result.ex`] |
| Suggestion artifact persistence | Database / Storage | API / Backend | Phase 10 requires durable artifacts, base revision anchoring, and later review handoff. [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`] [VERIFIED: `lib/cairnloop/knowledge_base/revision.ex`] |
| Operator suggestion inspection surface | Frontend Server (SSR) | API / Backend | The repo’s operator flows are LiveView-owned, with server-rendered evidence panes and state transitions. [VERIFIED: `lib/cairnloop/web/knowledge_base_live/gaps.ex`] [VERIFIED: `lib/cairnloop/web/conversation_live.ex`] |
| Diff derivation for revision proposals | API / Backend | Frontend Server (SSR) | The canonical truth is markdown plus `base_revision_id`; the UI only consumes the derived diff. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] |
| Telemetry and stale-detection reasons | API / Backend | Database / Storage | Bounded metadata and deterministic reason codes follow the existing retrieval telemetry posture and later ops needs. [VERIFIED: `lib/cairnloop/retrieval/telemetry.ex`] [VERIFIED: `.planning/REQUIREMENTS.md`] |

## Recommended Phase 10 Shape

### Shared Domain

Keep Phase 10 inside `Cairnloop.KnowledgeAutomation` and add shared public entrypoints for `suggest_article/2` and `suggest_revision/2` there rather than creating a second maintenance context or reusing conversation `Draft` rows. `KnowledgeAutomation` already owns the maintenance queue and scheduled refresh seams, while conversation drafts are customer-reply artifacts with approval-oriented policy semantics that do not map to KB suggestion review. [VERIFIED: `lib/cairnloop/knowledge_automation.ex`] [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`]  

Recommended module split: `Suggestion`, `SuggestionEvidence`, `SuggestionGenerator`, `CitationValidator`, `StaleArticleDetector`, and one Oban worker under `lib/cairnloop/knowledge_automation/workers/`. Those names are flexible, but the split itself keeps generation, stale gating, evidence validation, and persistence testable without leaking publish semantics into the artifact. [ASSUMED]

### Concrete File and Module Recommendations

| Area | Recommendation | Why |
|------|----------------|-----|
| Context facade | Extend [`lib/cairnloop/knowledge_automation.ex`](/Users/jon/projects/cairnloop/lib/cairnloop/knowledge_automation.ex) with `suggest_article/2`, `suggest_revision/2`, `get_suggestion!/2`, `list_suggestions/1`, and best-effort schedule helpers. [ASSUMED] | Phase 9 already made this context the operator-visible maintenance facade. [VERIFIED: `lib/cairnloop/knowledge_automation.ex`] |
| Persistence | Add a first-class suggestion schema under `lib/cairnloop/knowledge_automation/`. [ASSUMED] | KB suggestion state must remain separate from `cairnloop_revisions` until Phase 11 review/publish handoff. [VERIFIED: `.planning/ROADMAP.md`] [VERIFIED: `lib/cairnloop/knowledge_base.ex`] |
| Worker | Add one generation worker separate from `DraftWorker`. [ASSUMED] | Conversation draft generation already embeds reply-policy logic that Phase 10 must not inherit. [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] |
| Review surface | Add a dedicated LiveView under `lib/cairnloop/web/knowledge_base_live/` for suggestion inspection. [ASSUMED] | The current KB editor exposes direct `save_draft` and `publish` actions, which are explicitly out of scope for Phase 10. [VERIFIED: `lib/cairnloop/web/knowledge_base_live/editor.ex`] [VERIFIED: `.planning/ROADMAP.md`] |
| Presenter | Add a presenter/helper seam for evidence, trust labels, stale reasons, and diff summaries. [ASSUMED] | Existing operator surfaces already keep phrasing and labels out of raw templates. [VERIFIED: `lib/cairnloop/web/gap_candidate_presenter.ex`] [VERIFIED: `lib/cairnloop/web/search_result_presenter.ex`] |

### Evidence Snapshot Contract

The accepted evidence snapshot should be derived from `Retrieval.ground_for_draft/2` style output and store only bounded, render-ready fields already normalized by retrieval: source type, trust level, title, content excerpt, `citation_target`, match reasons, score, and destination metadata. That preserves one evidence vocabulary across search, conversation drafting, and KB maintenance. [VERIFIED: `lib/cairnloop/retrieval.ex`] [VERIFIED: `lib/cairnloop/retrieval/result.ex`] [VERIFIED: `lib/cairnloop/retrieval/providers/knowledge_base.ex`] [VERIFIED: `lib/cairnloop/retrieval/providers/resolved_cases.ex`]

Validation rules should be strict:
- The snapshot must contain at least one canonical KB evidence row with a non-empty `citation_target.article_id`, `citation_target.revision_id`, and `citation_target.chunk_index`. [VERIFIED: `lib/cairnloop/retrieval/providers/knowledge_base.ex`]
- Every citation surfaced as grounding support for the generated markdown body must come from canonical KB evidence, not resolved cases. Resolved cases remain advisory evidence only. [VERIFIED: `.planning/M010-KB-AI-MAINTENANCE-SPEC.md`] [VERIFIED: `lib/cairnloop/retrieval/providers/resolved_cases.ex`]
- `grounding_assessment.status` must be `:strong` for a normal success path; `:clarification` and `:escalation` should fail closed into a blocked or shell state rather than persisting a ready suggestion. [VERIFIED: `lib/cairnloop/retrieval.ex`] [VERIFIED: `.planning/REQUIREMENTS.md`]
- Missing or malformed citation targets must block persistence of a success artifact and emit a bounded failure reason. [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `lib/cairnloop/retrieval/telemetry.ex`]

### Stale-Article Trigger

The stale trigger should be deterministic and article-linked, not time-based. The repo already records weak-grounding and no-canonical-results evidence durably through `GapRecorder`, and `KnowledgeBase` can resolve the current published revision for an article. Phase 10 should combine those seams instead of inventing a separate freshness subsystem. [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`] [VERIFIED: `lib/cairnloop/knowledge_base.ex`] [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]

Resolved default for planning: open the stale-revision path only when the same published article accumulates at least `2` recent article-linked failure signals inside a `30` day window and the generation attempt can also build a fresh canonical evidence snapshot against the current published revision. The exact `2 / 30 days` threshold is discretionary, but it is the smallest deterministic default that honors the “repeated recent evidence” requirement and avoids one-off auto-promotion. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [ASSUMED]

Qualifying failure signals should include:
- repeated weak-grounding outcomes where the published article was retrieved but could not ground the answer safely, [VERIFIED: `lib/cairnloop/retrieval.ex`] [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- repeated clarification-limit or escalation outcomes after article retrieval in the existing draft-generation lane, [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- repeated manual-handling evidence tied back to the same topic/article cluster from Phase 9. [VERIFIED: `.planning/milestones/M010-phases/M010-S01/M010-S01-RESEARCH.md`] [VERIFIED: `lib/cairnloop/knowledge_automation.ex`]

### Oban Boundary, Idempotency, and Fail-Closed Behavior

Suggestion generation should use a dedicated Oban worker and never run inline from LiveView events. The repo already uses Oban workers for asynchronous generation and rebuild work, and the phase context explicitly requires a host-owned durable job boundary. [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] [VERIFIED: `lib/cairnloop/knowledge_automation.ex`] [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]

Use Oban uniqueness keyed by entrypoint identity plus evidence digest, with argument keys restricted to the entrypoint discriminator and digest fields rather than the entire payload. Oban’s unique-job docs explicitly support period, states, and key-scoped uniqueness within args/meta. [CITED: https://hexdocs.pm/oban/unique_jobs.html]

Planning defaults for uniqueness and failure:
- Use a debounce-style unique window for scheduled/available/retryable work so repeated clicks or repeated refreshes collapse to one generation attempt per entrypoint identity plus evidence digest. [CITED: https://hexdocs.pm/oban/unique_jobs.html] [ASSUMED]
- Treat a generation conflict as success-from-operator perspective by returning or loading the existing suggestion instead of enqueueing duplicate work. [ASSUMED]
- Fail closed when evidence snapshot validation fails before or after model generation; persist a blocked artifact or explicit failure metadata, but do not create a success suggestion without canonical citations. [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `lib/cairnloop/retrieval.ex`]
- Do not allow worker retries to mutate the meaning of a suggestion identity; the identity must stay tied to the same entrypoint and evidence digest, with regeneration producing a new digest when evidence actually changes. [ASSUMED]

### Suggestion Artifact Shape

The artifact should persist the full proposed markdown body as canonical suggestion truth, plus bounded metadata that explains where it came from and whether it is safe to inspect. That matches the context decision that diffs are derived and that suggestions are review artifacts rather than direct KB mutations. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]

Minimum persisted fields:
- `suggestion_type` as `:article` or `:revision`. [ASSUMED]
- `status` as a suggestion-only state such as `:pending_generation | :ready | :blocked | :dismissed`. [ASSUMED]
- `gap_candidate_id` for gap-driven article suggestions when applicable. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- `article_id` and `base_revision_id` for revision suggestions. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/knowledge_base.ex`]
- `proposed_title` and `proposed_markdown`. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- `operator_summary`, `change_summary`, `evidence_snapshot`, `grounding_metadata`, `entrypoint_identity`, `evidence_digest`, and `stale_detection_reason`. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/retrieval/telemetry.ex`]

For revision suggestions, compute the visible diff at read time from `base_revision_id.content` versus `proposed_markdown`. The repo has no existing diff-library dependency in `mix.exs` or `mix.lock`, so planners should keep the first implementation simple and server-side rather than pulling Phase 10 into a dependency spike. [VERIFIED: `mix.exs`] [VERIFIED: `mix.lock`] [ASSUMED]

### Review Surface Shape

Phase 10 needs a dedicated suggestion review LiveView, not a redirect into the current editor. `KnowledgeBaseLive.Editor` currently renders a live markdown editor with `save_draft` and `publish` actions, which conflicts with the phase boundary that stops before approval/publish semantics. [VERIFIED: `lib/cairnloop/web/knowledge_base_live/editor.ex`] [VERIFIED: `.planning/ROADMAP.md`]

The LiveView should:
- be reachable from the gap dashboard for gap-driven suggestions, [VERIFIED: `lib/cairnloop/web/knowledge_base_live/gaps.ex`]
- accept a direct article-scoped stale entrypoint that lands on the same suggestion artifact, [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- show evidence and trust labels beside the proposed body, following the evidence-rail posture from `ConversationLive`, [VERIFIED: `lib/cairnloop/web/conversation_live.ex`]
- show derived diff for revision suggestions and full markdown preview for article suggestions, [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]
- expose only `generate`, `regenerate`, `dismiss`, and `open in manual editor` actions in this phase. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `.planning/ROADMAP.md`]

### Telemetry

Phase 10 telemetry should mirror the bounded posture already enforced in retrieval telemetry: low-cardinality status, reason, and counts only; no raw markdown, query text, or citation payloads in event metadata. [VERIFIED: `lib/cairnloop/retrieval/telemetry.ex`]

Emit at least:
- `suggestion_generation` success or blocked outcome with `suggestion_type`, `entrypoint_type`, `grounding_status`, and `citation_validation_result`. [ASSUMED]
- `stale_detection` with bounded reason codes such as `:insufficient_failures`, `:missing_published_revision`, `:missing_canonical_citations`, or `:ready_for_revision`. [ASSUMED]
- `regeneration` attempts and duplicates collapsed by uniqueness. [ASSUMED]

Persist the human-inspectable reason in the suggestion artifact as well, because later phases need operator review and ops closure over the same lane. Telemetry alone is not enough for the product requirement. [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `.planning/ROADMAP.md`]

## Common Pitfalls

- **Reusing conversation drafts for KB suggestions:** `DraftWorker` and the conversation draft model are customer-reply artifacts with policy approval semantics, not KB-maintenance review artifacts. Reusing them would blur trust boundaries and leak Phase 11 concerns into Phase 10. [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] [VERIFIED: `test/cairnloop/automation/workers/draft_worker_test.exs`]  
- **Treating resolved-case evidence as sufficient grounding:** resolved cases are explicitly assistive in retrieval results and should never satisfy the citation gate alone. [VERIFIED: `lib/cairnloop/retrieval/providers/resolved_cases.ex`] [VERIFIED: `lib/cairnloop/retrieval.ex`]  
- **Making staleness time-based:** the context explicitly rejects timestamp-only freshness rules; article age without repeated failure evidence is out of scope. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]  
- **Persisting diffs instead of markdown bodies:** the context requires full proposed markdown as the canonical suggestion truth, with diff as a derived review aid only. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]  
- **Sending publish-shaped actions into the Phase 10 UI:** the current editor already exposes publish; adding the same affordance to the suggestion surface would violate the roadmap boundary. [VERIFIED: `lib/cairnloop/web/knowledge_base_live/editor.ex`] [VERIFIED: `.planning/ROADMAP.md`]  
- **Putting suggestion generation on the request path:** Phase 10 requires a durable Oban boundary and the existing generation patterns are already asynchronous. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`] [CITED: https://hexdocs.pm/oban/unique_jobs.html]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Duplicate job suppression | custom dedupe table or ad hoc mutex | Oban unique jobs with keyed args | The stack already ships Oban `2.22.1`, and the docs support period/state/key-based uniqueness directly. [VERIFIED: `mix.lock`] [CITED: https://hexdocs.pm/oban/unique_jobs.html] |
| Citation normalization | new evidence shape unrelated to retrieval | existing `Retrieval.Result`-style snapshot fields | Retrieval already standardizes trust labels, citation targets, and bounded metadata. [VERIFIED: `lib/cairnloop/retrieval/result.ex`] [VERIFIED: `lib/cairnloop/retrieval.ex`] |
| Publish workflow | direct writes into `publish_revision/1` from suggestions | suggestion artifact + later handoff to normal KB draft flow | The roadmap reserves approval/publish gating for Phase 11. [VERIFIED: `.planning/ROADMAP.md`] [VERIFIED: `lib/cairnloop/knowledge_base.ex`] |
| Review UI | overloading the existing KB editor | dedicated suggestion review LiveView | The editor currently implies direct authoring and publish actions. [VERIFIED: `lib/cairnloop/web/knowledge_base_live/editor.ex`] |

## Validation Architecture

Phase 10 can be proven hermetically in this repo because the retrieval, worker, and LiveView seams are already covered by focused ExUnit patterns with mocks and in-memory repos. The environment risk remains the same as Phase 9: repo-backed realism is unavailable here, so validation must prioritize deterministic unit and LiveView tests. [VERIFIED: `test/cairnloop/retrieval_test.exs`] [VERIFIED: `test/cairnloop/automation/workers/draft_worker_test.exs`] [VERIFIED: `test/cairnloop/web/knowledge_base_live/gaps_test.exs`] [VERIFIED: `.planning/STATE.md`]

Recommended new test files:
- `test/cairnloop/knowledge_automation/suggestion_test.exs` for changesets, state, and scoped reads. [ASSUMED]
- `test/cairnloop/knowledge_automation/citation_validator_test.exs` for canonical-anchor acceptance and malformed-citation rejection. [ASSUMED]
- `test/cairnloop/knowledge_automation/stale_article_detector_test.exs` for repeated-failure thresholds and current-revision anchoring. [ASSUMED]
- `test/cairnloop/knowledge_automation/workers/generate_suggestion_test.exs` for uniqueness, idempotency, blocked-vs-ready outcomes, and fail-closed persistence. [ASSUMED]
- `test/cairnloop/web/knowledge_base_live/suggestions_test.exs` for inspect/regenerate/dismiss/manual-open behaviors and evidence rendering. [ASSUMED]

Phase-to-test map:

| Requirement | Proof Focus | Test Type | Command |
|-------------|-------------|-----------|---------|
| DRAFT-01 | gap candidate to article suggestion success requires canonical citations and persists full markdown plus metadata | unit + worker | `mix test test/cairnloop/knowledge_automation/suggestion_test.exs test/cairnloop/knowledge_automation/workers/generate_suggestion_test.exs` [ASSUMED] |
| DRAFT-02 | stale-article trigger requires repeated article-linked failures plus fresh grounding snapshot and `base_revision_id` | unit + worker | `mix test test/cairnloop/knowledge_automation/stale_article_detector_test.exs test/cairnloop/knowledge_automation/workers/generate_suggestion_test.exs` [ASSUMED] |
| DRAFT-03 | missing/malformed citations, assistive-only evidence, or weak grounding block success artifacts and emit bounded reasons | unit + telemetry | `mix test test/cairnloop/knowledge_automation/citation_validator_test.exs test/cairnloop/knowledge_automation/workers/generate_suggestion_test.exs` [ASSUMED] |

Recommended quick run command:

```bash
mix test \
  test/cairnloop/knowledge_automation/suggestion_test.exs \
  test/cairnloop/knowledge_automation/citation_validator_test.exs \
  test/cairnloop/knowledge_automation/stale_article_detector_test.exs \
  test/cairnloop/knowledge_automation/workers/generate_suggestion_test.exs \
  test/cairnloop/web/knowledge_base_live/suggestions_test.exs
```

Step 2.6 environment audit: skipped for new dependencies. Phase 10 stays inside already-present Phoenix LiveView, Ecto, Earmark, and Oban dependencies; no external service or runtime beyond the existing app stack is required. [VERIFIED: `mix.exs`] [VERIFIED: `mix.lock`]

## Resolved Planning Defaults

1. **Canonical citation gate:** success suggestions require `grounding_assessment.status == :strong` plus at least one canonical KB citation anchor; assistive-only evidence can explain stale pressure but cannot ground suggestion content. [VERIFIED: `lib/cairnloop/retrieval.ex`] [VERIFIED: `lib/cairnloop/retrieval/providers/knowledge_base.ex`] [VERIFIED: `lib/cairnloop/retrieval/providers/resolved_cases.ex`]
2. **Stale trigger threshold:** require at least two article-linked failure signals in the last 30 days before Phase 10 opens the revision suggestion path by default. That is the recommended deterministic minimum unless planning finds a better seeded threshold from existing fixtures. [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`] [ASSUMED]
3. **Review surface boundary:** Phase 10 ends at inspect/regenerate/dismiss/open-for-manual-edit. No approve, reject, publish, or reindex actions belong in this phase. [VERIFIED: `.planning/ROADMAP.md`] [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Recommended module names such as `Suggestion`, `CitationValidator`, and `StaleArticleDetector` are the right split. | Recommended Phase 10 Shape | Low. Names can change without affecting the architecture. |
| A2 | The stale trigger should default to `2` failures within `30` days. | Stale-Article Trigger | Medium. Product may prefer a stricter or looser threshold. |
| A3 | Suggestion state values such as `:pending_generation | :ready | :blocked | :dismissed` are sufficient for Phase 10. | Suggestion Artifact Shape | Low. Enum names can change without changing the phase boundary. |
| A4 | The first revision-diff implementation should stay server-side and simple rather than adding a new dependency in Phase 10. | Suggestion Artifact Shape | Low. A small diff dependency could still be justified later. |
| A5 | New test files should be split into `suggestion`, `citation_validator`, `stale_article_detector`, worker, and LiveView suites. | Validation Architecture | Low. The coverage shape matters more than the exact filenames. |

## Open Questions (RESOLVED)

1. **How should article-linked failure evidence be attached to a specific KB article?**  
What we know: retrieval results already carry `article_id`, `revision_id`, and `chunk_index` in canonical citation targets, and gap events already persist bounded attempted-evidence snapshots. [VERIFIED: `lib/cairnloop/retrieval/providers/knowledge_base.ex`] [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`]  
Resolution: Phase 10 will derive article linkage from durable `attempted_evidence_snapshots` on retrieval gap evidence, using canonical `citation_target.article_id`, `citation_target.revision_id`, and `chunk_index` fields as the only article-linking contract for stale-revision pressure. This matches the chosen plan behavior in Plan 02 and avoids introducing a new stale-membership table or title-based inference in this phase. [VERIFIED: `lib/cairnloop/retrieval/providers/knowledge_base.ex`] [VERIFIED: `lib/cairnloop/retrieval/gap_recorder.ex`] [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-02-PLAN.md`]

2. **Should blocked suggestions be persisted or returned as transient errors?**  
What we know: the milestone requires operator-visible fail-closed behavior, and telemetry alone is not enough for later review/ops work. [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `.planning/ROADMAP.md`]  
Resolution: operator-invoked generation attempts that fail citation or grounding gates will persist durable blocked or failed suggestion artifacts with bounded failure metadata instead of surfacing only transient LiveView errors. This aligns with the selected Plan 01 and Plan 02 storage and worker behavior, preserves inspectability, and keeps regenerate/dismiss flows possible without weakening the fail-closed posture. [VERIFIED: `.planning/REQUIREMENTS.md`] [VERIFIED: `.planning/ROADMAP.md`] [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-01-PLAN.md`] [VERIFIED: `.planning/milestones/M010-phases/M010-S02/M010-S02-02-PLAN.md`]

## Sources

### Primary
- `.planning/ROADMAP.md` - Phase 10 boundary and out-of-scope lines. [VERIFIED: local file]
- `.planning/REQUIREMENTS.md` - `DRAFT-01` to `DRAFT-03`, proof posture, and fail-closed rules. [VERIFIED: local file]
- `.planning/M010-KB-AI-MAINTENANCE-SPEC.md` - shared domain, evidence posture, and review boundary. [VERIFIED: local file]
- `.planning/milestones/M010-phases/M010-S02/M010-S02-CONTEXT.md` - locked phase decisions and discretionary defaults. [VERIFIED: local file]
- `.planning/milestones/M010-phases/M010-S01/M010-S01-RESEARCH.md` - delivered Phase 9 queue shape and anti-patterns. [VERIFIED: local file]
- `lib/cairnloop/knowledge_automation.ex` - existing maintenance facade and Oban refresh seam. [VERIFIED: local file]
- `lib/cairnloop/retrieval.ex` and `lib/cairnloop/retrieval/result.ex` - grounding, diagnostics, and evidence shape. [VERIFIED: local file]
- `lib/cairnloop/retrieval/gap_recorder.ex` - durable failure evidence recording. [VERIFIED: local file]
- `lib/cairnloop/automation/workers/draft_worker.ex` - existing async generation and fail-closed pattern. [VERIFIED: local file]
- `lib/cairnloop/web/knowledge_base_live/gaps.ex`, `editor.ex`, and `conversation_live.ex` - operator surface boundaries. [VERIFIED: local file]
- `test/cairnloop/retrieval_test.exs`, `test/cairnloop/automation/workers/draft_worker_test.exs`, `test/cairnloop/web/knowledge_base_live/gaps_test.exs` - hermetic validation style. [VERIFIED: local file]

### External
- `https://hexdocs.pm/oban/unique_jobs.html` - unique-job period, state, field, and key semantics for the dedicated suggestion worker. [CITED: official Oban docs]

## RESEARCH COMPLETE
