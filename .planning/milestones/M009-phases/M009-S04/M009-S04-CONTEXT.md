# M009-S04 Context: Retrieval Telemetry & Gap Signals

**Gathered:** 2026-05-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Make retrieval quality inspectable and preserve no-hit evidence for the next knowledge-gap milestone. This phase covers retrieval telemetry contracts, durable gap-signal persistence, failure/outcome classification, and lightweight trust cues that surface retrieval quality inside existing operator flows. It does not cover a dedicated retrieval control plane, rich historical analytics dashboards, learned ranking, or full M010 clustering/product-gap workflows.

</domain>

<decisions>
## Implementation Decisions

### Decision-making posture
- **D-01:** Shift preference left inside GSD for this project. Downstream agents should make strong, coherent defaults that fit Cairnloop's host-owned, retrieval-first, least-surprise posture instead of re-escalating normal design choices.
- **D-02:** Re-escalate only for decisions that materially change trust semantics, public contract stability, storage/retention posture, or milestone scope.
- **D-03:** Principle of least surprise beats maximal telemetry cleverness. The system should be easy for host developers to reason about, safe for operators to trust, and boring to maintain.

### Retrieval telemetry contract
- **D-04:** Use a layered Cairnloop-native telemetry contract as the public seam for this phase.
- **D-05:** Keep `Cairnloop.Telemetry` and stable `[:cairnloop, ...]` events as the semver-stable public contract for host apps and generated Parapet instrumenters.
- **D-06:** Use OpenInference/OpenTelemetry as an adapter layer for traces, not as the primary public contract of the library.
- **D-07:** Emit a root retrieval/search contract with bounded dimensions such as surface, source mix, result bucket, and grounding status, plus nested provider/retriever/reranker spans where useful.
- **D-08:** Keep low-cardinality labels for metrics separate from high-cardinality evidence. Raw query text, record IDs, citation payloads, and verbose error strings must never become metric labels.
- **D-09:** Treat telemetry as lossy observability and durable gap evidence as a separate storage concern. Do not overload metrics/traces as the only source of truth for future clustering.

### Durable gap evidence
- **D-10:** Persist no-hit, failed-search, and weak-grounding evidence in a dedicated append-only retrieval gap event store.
- **D-11:** Prefer one focused event table with typed envelope fields plus embedded/JSONB payloads over a heavily normalized multi-table lineage model in this phase.
- **D-12:** Write durable gap evidence from the retrieval/search/draft application boundary, or enqueue it through Oban from that boundary, not from telemetry handlers.
- **D-13:** Gap-event records must preserve enough sanitized customer-language seed text and retrieval context to feed future M010 clustering without flattening canonical-vs-assistive source semantics.
- **D-14:** Include stable typed fields for occurrence time, surface, outcome, reason, tenant scope, query fingerprint, canonical/assistive hit counts, and clarification attempts, plus embedded attempted-source/evidence snapshots.
- **D-15:** Add explicit redaction, retention, and deduplication discipline to gap events. Avoid raw PII hoarding, retry storms, and unbounded JSON growth.

### Failure and outcome classification
- **D-16:** Keep the existing coarse operator-facing grounding state machine (`strong`, `clarification`, `escalation`) as the primary disposition model.
- **D-17:** Add a structured diagnostic taxonomy beneath that disposition instead of exploding the top-level state machine.
- **D-18:** Use orthogonal diagnostic classes such as retrieval error, empty recall, weak grounding, and policy limit, each with stable reason atoms such as provider timeout, index unavailable, no canonical results, assistive-only results, canonical insufficient detail, and clarification limit reached.
- **D-19:** Do not collapse infra failures, recall misses, and weak-grounding cases into one generic `failed` or `no_hit` bucket.
- **D-20:** Keep execution retry semantics in Oban and product/trust semantics in retrieval outcome metadata. Do not blur worker lifecycle state with operator-facing grounding state.

### Inspectable surface
- **D-21:** Use a layered inspectability posture: lightweight operator-facing trust cues in existing surfaces now, developer-grade telemetry underneath, and defer a dedicated retrieval debugger/control-plane UI.
- **D-22:** Reuse existing search and drafting evidence surfaces rather than introducing a new routed admin console in this phase.
- **D-23:** Operator-facing cues should stay calm and evidence-first: source type, trust label, recency, citation/open target, weak-grounding state, and clear no-hit/escalation copy.
- **D-24:** Do not expose raw scores, fake precision, or debug-density retrieval internals to operators in normal flows.
- **D-25:** Defer richer historical quality dashboards, query forensics, and answer-debugger workflows until later work proves enough volume and value.

### Architecture and DX posture
- **D-26:** Preserve host ownership: Parapet-safe metric projection remains explicit and visible in generated host instrumentation rather than hidden inside a black-box runtime DSL.
- **D-27:** Keep retrieval quality seams consistent across operator search, grounded drafting, telemetry, and future clustering. One normalized result/evidence contract should remain the paved road.
- **D-28:** Prefer small explicit structs/schemas, `Ecto.Enum` for bounded outcome fields, `Ecto.Multi` for atomic persistence, and Oban for asynchronous durability/replay paths.
- **D-29:** Preserve the canonical Knowledge Base vs assistive resolved-case distinction everywhere, including telemetry labels, durable evidence snapshots, and UI copy.
- **D-30:** Planning and implementation should treat product trust and developer ergonomics as co-equal requirements. The next maintainer should be able to inspect contracts, replay failures, and understand why a retrieval outcome happened without reading hidden magic.

### the agent's Discretion
- Exact event names beneath the `[:cairnloop, :retrieval, ...]` namespace
- Exact schema/module names for the gap-event store and any embedded payload structs
- Exact low-cardinality label vocabulary, so long as it remains bounded and Parapet-safe
- Exact trace nesting and attribute naming, so long as OpenInference remains an adapter rather than the primary public contract
- Exact UI wording for weak-grounding and no-hit states, so long as it stays calm, explicit, and source-aware

</decisions>

<specifics>
## Specific Ideas

- Retrieval quality should feel like a trust layer, not like hidden backend plumbing.
- The recommended package is intentionally coherent:
  - stable Cairnloop-native telemetry contract
  - separate durable append-only gap evidence
  - coarse operator outcome plus structured diagnostic cause taxonomy
  - lightweight in-flow trust cues instead of a new debugger console
- Preserve the M009 rule everywhere: canonical Knowledge Base truth first, resolved cases second as assistive evidence only.
- Optimize for host-developer comprehension. A Phoenix team should be able to read the event contract, inspect the persisted evidence, and tune metrics without reverse-engineering black-box adapters.
- Keep future M010 clustering in mind, but do not prematurely over-normalize the storage model or ship a broad analytics subsystem in this phase.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone requirements and posture
- `.planning/M009-ROADMAP.md` — Phase 4 goal, requirements, success criteria, and milestone boundary
- `.planning/PROJECT.md` — Current product posture and retrieval-first framing
- `.planning/REQUIREMENTS.md` — M009 requirement mapping and out-of-scope constraints
- `.planning/STATE.md` — Current milestone state and accumulated architectural decisions
- `.planning/MILESTONE-ARC.md` — Strategic ordering and explicit retrieval-first priorities
- `.planning/PROJECT_EPICS.md` — Product and architecture direction for retrieval, grounded drafting, telemetry, and future gap workflows

### Prior M009 decisions
- `.planning/milestones/M009-phases/M009-S01-CONTEXT.md` — Retrieval boundary, ranking, trust hierarchy, and durability model
- `.planning/milestones/M009-phases/M009-S02-CONTEXT.md` — Operator search trust signals, evidence-first presentation, and retrieval-backed UI posture
- `.planning/milestones/M009-phases/M009-S03/M009-S03-CONTEXT.md` — Grounded drafting state machine, weak-grounding policy, and evidence presentation rules

### Observability and host-ownership posture
- `.planning/M005-RESEARCH.md` — Evidence vs telemetry posture, host-owned instrumentation, and Parapet-safe cardinality principles
- `.planning/milestones/M005-phases/M005-S02/M005-S02-RESEARCH.md` — Generated instrumenter approach and low-cardinality metrics discipline

### Product research and project vision
- `prompts/cairnloop_brand_book.md` — Brand/product posture: show sources, make safety explicit, keep host in control
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — Ecosystem lessons on grounded support, knowledge loops, and support-quality signals
- `prompts/scoria overview for integration ideas.txt` — Traceability and AI-quality interoperability guidance
- `prompts/parapet overview for integration ideas.txt` — Reliability and metrics-contract guidance
- `.planning/research/EPIC_IDEAS_INTENT_GAPS.md` — Future M010 gap-clustering direction and why durable no-hit evidence matters

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/cairnloop/retrieval.ex` — Current retrieval facade and grounding assessment seam; natural home for Phase 4 contract emission
- `lib/cairnloop/retrieval/result.ex` — Normalized source/trust/result payload that should stay the paved-road evidence contract
- `lib/cairnloop/retrieval/ranker.ex` — Deterministic ranking seam whose outcomes and match reasons should feed retrieval-quality signaling
- `lib/cairnloop/telemetry.ex` — Existing library-owned telemetry wrapper for stable `[:cairnloop, ...]` events
- `lib/cairnloop/automation/workers/draft_worker.ex` — Current grounded-draft execution seam where retrieval outcomes already branch into reply/clarification/escalation
- `lib/cairnloop/automation/scoria_engine.ex` — Existing proposal-generation seam that already carries grounding metadata and should emit/propagate structured outcome causes
- `lib/cairnloop/web/search_modal_component.ex` and `lib/cairnloop/web/search_result_presenter.ex` — Existing search trust cues and preview surfaces that can absorb lightweight inspectability
- `lib/cairnloop/web/conversation_live.ex` — Existing operator review surface where weak-grounding and evidence-state cues can stay visible

### Established Patterns
- Host-owned observability contracts over hidden runtime magic
- Ecto-backed durable state and explicit application boundaries instead of telemetry-driven side effects
- Oban for asynchronous replay/rebuild/durable work
- One normalized retrieval/result contract reused across search, drafting, and later telemetry/evidence work
- Calm operator-facing evidence presentation instead of raw debugging chrome

### Integration Points
- Add retrieval/search/grounding telemetry at the retrieval facade and ranker seams
- Add structured diagnostic cause propagation from retrieval into the draft pipeline and proposal metadata
- Add durable gap-event persistence at the application boundary for operator search misses and grounded-draft weak-evidence cases
- Reuse existing search and draft evidence surfaces for lightweight trust cues rather than creating a new Phase 4 console
- Keep generated host instrumentation aligned with the stable Cairnloop telemetry contract

</code_context>

<deferred>
## Deferred Ideas

- Dedicated retrieval debugger or control-plane UI
- Rich historical dashboards and query forensics surfaces
- Fully normalized retrieval-attempt lineage schema
- Learned weighting, adaptive routing, or opaque confidence modeling
- M010 clustering, topic naming, and operator-facing gap dashboard workflows

</deferred>

---

*Phase: M009-S04*
*Context gathered: 2026-05-20*
