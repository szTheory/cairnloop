# M009-S01 Context: Hybrid Retrieval Corpus & APIs

**Gathered:** 2026-05-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the host-owned retrieval layer over published Knowledge Base content and resolved support evidence. This phase covers corpus shape, indexing jobs, retrieval APIs, ranking behavior, and recovery primitives. It does not cover operator-facing search UI, answer rendering, or telemetry dashboards beyond the contracts needed to support them.

</domain>

<decisions>
## Implementation Decisions

### Decision-making posture
- **D-01:** Downstream agents should default to decisive, idiomatic choices that fit Cairnloop's existing architecture and milestone goals. Re-escalate to the user only for decisions that materially change product posture, trust semantics, or scope.
- **D-02:** Principle of least surprise beats novelty. Prefer boring, inspectable retrieval behavior and a small public surface over clever ranking or broad configuration.

### Resolved support evidence shape
- **D-03:** Do not index full conversation transcripts as first-class retrieval documents.
- **D-04:** Model resolved conversations as a structured, assistive evidence record created at resolution time and stored separately from canonical Knowledge Base content.
- **D-05:** The structured evidence record should include, at minimum: `conversation_id`, `subject`, `issue_summary`, `resolution_note`, `actions_taken`, `outcome`, `resolved_at`, bounded intent/product metadata, and citation backreferences to the underlying messages or spans.
- **D-06:** Keep transcript/history available as source material for citations, audit, and regeneration, but not as the primary retrieval document.
- **D-07:** Resolved evidence must be clearly labeled as assistive evidence rather than canonical policy truth.

### Retrieval API boundary
- **D-08:** Expose one internal retrieval context as the paved-road API for Cairnloop callers. Recommended shape: `Cairnloop.Retrieval`.
- **D-09:** Implement the public retrieval context as a facade over specialized provider modules rather than a single monolith or multiple public low-level APIs.
- **D-10:** Use separate provider internals for canonical Knowledge Base retrieval and resolved-case retrieval so trust semantics, indexing strategies, and filters remain explicit.
- **D-11:** Normalize result structs across providers with fields such as `source_type`, `trust_level`, `visibility`, `citation_target`, `match_reasons`, and `can_ground_reply?`.
- **D-12:** LiveViews, workers, and future AI flows should call the retrieval context instead of reaching directly to remote search services.

### Hybrid ranking behavior
- **D-13:** Use deterministic hybrid retrieval as the Phase 1 default: run PostgreSQL full-text search and pgvector similarity retrieval in parallel, then fuse the candidate sets with deterministic reranking.
- **D-14:** Prefer rank-based fusion and explicit source-aware boosts over raw score blending or learned weighting in Phase 1.
- **D-15:** Canonical Knowledge Base hits should rank above similar resolved-case evidence when the evidence quality is otherwise comparable.
- **D-16:** Ranking must be explainable. Return stable ordering plus match reasons that can support operator trust, citation rails, and later Scoria traces.
- **D-17:** Do not ship hidden vector-first or keyword-first fallback magic as the default retrieval model for Phase 1.
- **D-18:** Defer learned weighting, query-class routing, and opaque confidence models until retrieval telemetry and evaluation loops exist in later phases.

### Index lifecycle and recovery
- **D-19:** Indexing should be event-driven by default and durably tied to the source-of-truth write path.
- **D-20:** Knowledge Base publish and resolved-conversation indexing should enqueue durable Oban work from transactional application boundaries, not from best-effort side paths.
- **D-21:** Retrieval indexing workers must be idempotent and keyed by stable natural identifiers such as `source_kind + source_id + source_version + chunk_idx`.
- **D-22:** Phase 1 must include explicit developer recovery primitives for replay and rebuild, such as `reindex_revision/1`, `reindex_conversation/1`, `replay_failed/1`, `rebuild_corpus/1`, and matching Mix tasks.
- **D-23:** Do not build a heavy operator control plane for retrieval lifecycle management in this phase.
- **D-24:** Oban uniqueness may help reduce duplicate inserts, but it is not the primary correctness guarantee. Idempotent writes and replayability are the real durability model.

### Safety, visibility, and trust
- **D-25:** Apply tenant, audience, and visibility filtering before ranking, not after.
- **D-26:** Keep canonical KB content and assistive resolved-case evidence separated in storage, ranking, and UI labels, even if both are returned through one retrieval facade.
- **D-27:** Retrieval misses and weak-evidence outcomes should produce an explicit "no trustworthy grounding" result rather than forcing a low-trust answer path.

### the agent's Discretion
- Exact schema names and module breakdown under the retrieval context
- Specific deterministic fusion formula, so long as it is transparent, bounded, and easy to test
- Exact mix task names and worker naming
- Internal query/window sizing and cutoff tuning

</decisions>

<specifics>
## Specific Ideas

- Favor a retrieval result shape that works equally well for operator search, AI drafting, and future evidence rails rather than separate ad hoc payloads per surface.
- Make the source distinction obvious everywhere: "Knowledge Base" vs "Similar resolved case" should be visible, not inferred.
- Retrieval should feel host-owned and inspectable, not like a hidden black box. Operators should be able to see what supported an answer; developers should be able to replay and repair indexes without bespoke SQL.
- Carry forward Cairnloop's product posture from the local research docs: embedded, host-owned, knowledge-centered, safe-by-default, and explicitly not a generic helpdesk clone.
- Shift the gray-area burden left inside GSD for this project: downstream agents should make strong defaults unless a decision changes trust, scope, or the product's core posture.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone requirements and posture
- `.planning/M009-ROADMAP.md` — Phase 1 goal, requirements, success criteria, and milestone boundary
- `.planning/PROJECT.md` — Active project posture and current milestone framing
- `.planning/REQUIREMENTS.md` — M009 requirement mapping and explicit out-of-scope constraints
- `.planning/STATE.md` — Current milestone state and accumulated architectural decisions

### Product and ecosystem direction
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — Product wedge, ecosystem lessons, and what to emulate vs avoid
- `prompts/scoria overview for integration ideas.txt` — AI-quality, trace, and governance posture relevant to retrieval spans and eval readiness
- `prompts/parapet overview for integration ideas.txt` — Reliability and telemetry contract guidance relevant to retrieval lifecycle and safe metrics
- `prompts/cairnloop_brand_book.md` — Brand and product posture: host-owned, sourced, calm, explicit handoff, operator-grade trust

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/cairnloop/knowledge_base.ex` — Existing publish path, latest revision queries, and current vector-only chunk search entry point
- `lib/cairnloop/knowledge_base/workers/chunk_revision.ex` — Existing Oban-backed chunking/indexing worker with delete-and-reinsert idempotent shape
- `lib/cairnloop/embedder.ex` and `lib/cairnloop/embedder/external_api.ex` — Existing embedding abstraction and default external adapter
- `lib/cairnloop/automation/workers/draft_worker.ex` — Existing draft pipeline that will later consume the retrieval boundary

### Established Patterns
- Ecto-backed durable state and explicit contexts instead of hidden service layers
- Oban for asynchronous processing and background index preparation
- Telemetry/OpenInference spans already exist in worker flows and should extend naturally to retriever and reranker spans
- Revision-based immutable KB content already exists and should remain the canonical retrieval source

### Integration Points
- Replace direct remote search calls in `lib/cairnloop/web/search_modal_component.ex` with the internal retrieval facade in later phases
- Replace direct external lookup behavior in `lib/cairnloop/automation/scoria_engine.ex` with retrieval-context calls when grounded drafting is implemented
- Conversation resolution flow needs a durable indexing hook equivalent in rigor to the existing KB publish path

</code_context>

<deferred>
## Deferred Ideas

- Learned rank weighting, LTR-style reranking, or query-class routing after retrieval telemetry/evals exist
- A dedicated retrieval operations UI or control plane
- Full transcript retrieval as a first-class search corpus
- Broader search UX decisions for `cmd+k` and result presentation, which belong to M009 Phase 2
- Citation rendering and weak-grounding fallback UX in AI draft review, which belong to M009 Phase 3

</deferred>

---

*Phase: M009-S01*
*Context gathered: 2026-05-17*
