# Phase M009-S04: Retrieval Telemetry & Gap Signals - Research

**Researched:** 2026-05-20 [VERIFIED: local system date]  
**Domain:** Retrieval telemetry contracts, append-only gap evidence, and trust-state propagation across retrieval, search, and drafting [VERIFIED: .planning/M009-ROADMAP.md] [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md]  
**Confidence:** HIGH [VERIFIED: repo code review] [CITED: https://hexdocs.pm/telemetry/telemetry.html] [CITED: https://hexdocs.pm/oban/Oban.html] [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)
- Dedicated retrieval debugger or control-plane UI
- Rich historical dashboards and query forensics surfaces
- Fully normalized retrieval-attempt lineage schema
- Learned weighting, adaptive routing, or opaque confidence modeling
- M010 clustering, topic naming, and operator-facing gap dashboard workflows
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| M009-REQ-08 | System emits retrieval telemetry for latency, hit/miss, ranking outcomes, and grounding decisions using Scoria- and Parapet-safe contracts. [VERIFIED: .planning/REQUIREMENTS.md] | Use `Cairnloop.Telemetry` as the stable public seam, emit bounded root events at retrieval/search/draft boundaries, and keep OpenInference/OpenTelemetry as adapters only. [VERIFIED: lib/cairnloop/telemetry.ex] [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex] [CITED: https://hexdocs.pm/telemetry/telemetry.html] |
| M009-REQ-09 | System records failed searches and no-hit retrieval events so future knowledge-gap workflows can prioritize missing content from real evidence. [VERIFIED: .planning/REQUIREMENTS.md] | Add one append-only retrieval gap event table with typed envelope fields plus embedded snapshots, write from the search/draft application boundary, and preserve sanitized query seed text plus canonical/assistive counts. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md] [VERIFIED: lib/cairnloop/automation/draft.ex] [CITED: https://hexdocs.pm/ecto/embedded-schemas.html] [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html] |
</phase_requirements>

## Summary

Phase 4 should not introduce a parallel retrieval subsystem. The repo already has the right paved-road seams: `Cairnloop.Retrieval` centralizes search and draft grounding, `Cairnloop.Retrieval.Result` normalizes source/trust/citation data, `Cairnloop.Telemetry` exists as the library-owned wrapper, and `DraftWorker` plus the LiveView search surfaces are the existing application boundaries where outcome state is decided and shown. [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/retrieval/result.ex] [VERIFIED: lib/cairnloop/telemetry.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex] [VERIFIED: lib/cairnloop/web/search_modal_component.ex]

The implementation-ready recommendation is to add two narrow pieces only: a stable `[:cairnloop, :retrieval, ...]` contract emitted through `Cairnloop.Telemetry`, and an append-only `RetrievalGapEvent` store written from search and draft boundaries with typed enums plus embedded snapshots. This fits the existing host-owned observability posture from M005, matches the Phase 4 locked decisions, and avoids the anti-pattern of using telemetry handlers as durable storage. [VERIFIED: .planning/M005-RESEARCH.md] [VERIFIED: .planning/milestones/M005-phases/M005-S02/M005-S02-RESEARCH.md] [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md] [CITED: https://hexdocs.pm/telemetry/telemetry.html] [CITED: https://hexdocs.pm/oban/Oban.html]

Two repo risks need to be handled as part of this phase. `SearchModalComponent` currently calls `Cairnloop.Retrieval.search(query, [])` without passing the already-available `host_user_id`, and `DraftWorker` calls `ground_for_draft/1` without propagating host scope or other retrieval opts, so telemetry and gap evidence can be incomplete or misleading if Phase 4 simply records current calls as-is. `Retrieval.ground_for_draft/2` also rescues all errors into a generic `:retrieval_error` bundle, which is safe for user flow but too lossy for diagnostic telemetry unless the error class is captured before the rescue boundary. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex] [VERIFIED: lib/cairnloop/retrieval.ex]

**Primary recommendation:** Keep `Cairnloop.Retrieval` as the single public seam, add a repo-backed `RetrievalGapEvent` with bounded enums plus embedded evidence snapshots, and emit one bounded telemetry contract per retrieval/search/grounding attempt before projecting anything to OpenInference or Parapet. [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/telemetry.ex] [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Retrieval telemetry emission | API / Backend | — | Retrieval and grounding decisions are made in `Cairnloop.Retrieval` and `DraftWorker`, so the library backend owns the authoritative event contract. [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex] |
| Gap-event persistence | API / Backend | Database / Storage | Durable evidence must be written from application boundaries with Ecto/Oban rather than from telemetry handlers. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md] [CITED: https://hexdocs.pm/oban/Oban.html] |
| Operator trust cues | Frontend Server (LiveView) | Browser / Client | Search and draft rails are rendered by LiveView components and already consume normalized retrieval result structs. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/web/conversation_live.ex] |
| Host metrics projection | API / Backend (Host App) | — | M005 already established a host-owned Parapet instrumenter generated into the adopter app instead of hidden runtime wiring. [VERIFIED: lib/mix/tasks/cairnloop/install.parapet.ex] [VERIFIED: .planning/milestones/M005-phases/M005-S02/M005-S02-RESEARCH.md] |
| Future gap clustering inputs | Database / Storage | API / Backend | M010 needs sanitized, append-only historical evidence, not just transient telemetry. [VERIFIED: .planning/research/EPIC_IDEAS_INTENT_GAPS.md] [VERIFIED: .planning/MILESTONE-ARC.md] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Cairnloop.Telemetry` + `:telemetry` | repo wrapper + `telemetry 1.4.1` [VERIFIED: lib/cairnloop/telemetry.ex] [VERIFIED: mix.lock] | Stable public event seam for start/stop/exception and point events. [VERIFIED: lib/cairnloop/telemetry.ex] | `:telemetry.span/3` already models start/stop/exception and the repo already uses the wrapper for stable library events. [VERIFIED: lib/cairnloop/telemetry.ex] [VERIFIED: lib/cairnloop/chat.ex] [CITED: https://hexdocs.pm/telemetry/telemetry.html] |
| Ecto schema + embeds + `Ecto.Enum` | `ecto 3.13.6` / `ecto_sql 3.13.5` [VERIFIED: mix.lock] | Typed gap-event envelope with embedded snapshots and bounded enums. [CITED: https://hexdocs.pm/ecto/embedded-schemas.html] [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html] | The repo already uses `Ecto.Enum` for bounded state on drafts, revisions, SLAs, and messages, and embedded/map payloads fit the “one table with typed envelope plus JSONB payloads” decision. [VERIFIED: lib/cairnloop/automation/draft.ex] [VERIFIED: lib/cairnloop/conversation.ex] [VERIFIED: lib/cairnloop/knowledge_base/revision.ex] |
| Oban | `2.22.1` [VERIFIED: mix.lock] | Async durability, replay, and pruning paths for gap-event writes that should not block operator UX. [VERIFIED: mix.lock] | Oban is already the repo’s durability primitive for indexing and drafting work, and official docs recommend Oban’s own `insert` helpers inside `Ecto.Multi` for job features such as uniqueness. [VERIFIED: lib/cairnloop/retrieval/workers/index_resolved_conversation.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex] [CITED: https://hexdocs.pm/oban/Oban.html] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix LiveView | `1.1.30` [VERIFIED: mix.lock] | Existing search and draft rails for calm trust cues. [VERIFIED: mix.lock] | Extend current components for no-hit, weak-grounding, and source-aware copy instead of adding a new console. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/web/conversation_live.ex] |
| `pgvector` | `0.3.1` [VERIFIED: mix.lock] | Existing retrieval corpus backing and future M010 clustering substrate. [VERIFIED: mix.lock] | Keep gap events relational now; do not add embeddings to the Phase 4 event table yet. Use existing retrieval corpus and defer vectorized clustering to M010. [VERIFIED: .planning/research/EPIC_IDEAS_INTENT_GAPS.md] [VERIFIED: priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs] |
| Generated Parapet instrumenter | repo task + host-owned module [VERIFIED: lib/mix/tasks/cairnloop/install.parapet.ex] [VERIFIED: test/cairnloop/tasks/install.parapet_test.exs] | Safe metric projection from bounded retrieval events to host SRE tooling. [VERIFIED: lib/mix/tasks/cairnloop/install.parapet.ex] | Use when Phase 4 adds new low-cardinality retrieval metrics; keep projection explicit in host code. [VERIFIED: .planning/milestones/M005-phases/M005-S02/M005-S02-RESEARCH.md] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| One append-only gap event table | Fully normalized attempt/evidence lineage tables | Better provenance at query time, but too much schema surface for M009 and directly contradicts the locked Phase 4 decision to prefer one focused table now. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md] |
| Boundary-owned durable writes | Telemetry handlers that persist no-hit events | Handler-side persistence breaks the evidence-vs-telemetry separation and risks hidden write failures in an observability path. [VERIFIED: .planning/M005-RESEARCH.md] [CITED: https://hexdocs.pm/telemetry/telemetry.html] |
| Bounded enums + typed reason atoms | Freeform strings for outcomes/reasons | Freeform labels drift, inflate metric cardinality, and make testing harder. `Ecto.Enum` is already an established repo pattern. [VERIFIED: lib/cairnloop/automation/draft.ex] [VERIFIED: lib/cairnloop/conversations/sla.ex] [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html] |

**Installation:** No new dependency is required for the recommended Phase 4 shape because the repo already pins Ecto, Oban, Phoenix LiveView, `pgvector`, and `:telemetry`. [VERIFIED: mix.exs] [VERIFIED: mix.lock]

**Version verification:** The versions above are the repo-pinned versions currently resolved in `mix.lock`, not speculative training-data versions. [VERIFIED: mix.lock]

## Architecture Patterns

### System Architecture Diagram

```text
Operator search input / DraftWorker query
        |
        v
  Cairnloop.Retrieval.search/2 or ground_for_draft/2
        |
        +--> KB provider ------------+
        |                            |
        +--> Resolved-case provider -+--> Ranker --> normalized Result[]
        |                            |
        |                            +--> root retrieval telemetry event
        |
        +--> grounding assessment (strong | clarification | escalation)
        |              |
        |              +--> draft proposal / search UI trust cues
        |
        +--> gap recorder decision
                       |
                       +--> append-only RetrievalGapEvent row
                       |
                       +--> optional Oban durability/prune job
                       |
                       +--> host-owned Parapet projection from stable telemetry
```

The data-flow inflection point should stay at the retrieval/search/draft application boundary because that is where the repo already knows surface, query intent, trust mix, and operator-facing outcome. [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex] [VERIFIED: lib/cairnloop/web/search_modal_component.ex]

### Recommended Project Structure
```text
lib/cairnloop/retrieval.ex                         # Continue as the public retrieval seam
lib/cairnloop/retrieval/telemetry.ex               # Event-name builders and bounded metadata helpers
lib/cairnloop/retrieval/gap_event.ex               # Ecto schema with typed envelope fields
lib/cairnloop/retrieval/gap_event_snapshot.ex      # Embedded attempted-source/evidence snapshot structs
lib/cairnloop/retrieval/gap_recorder.ex            # Boundary-owned persistence API
priv/repo/migrations/*_add_retrieval_gap_events.exs # Append-only table + indexes
test/cairnloop/retrieval/telemetry_test.exs        # Contract tests for event names and metadata shape
test/cairnloop/retrieval/gap_event_test.exs        # Persistence, dedupe, redaction tests
```

This structure preserves one public retrieval boundary while keeping telemetry and durable evidence explicit and testable. [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/automation/draft.ex]

### Pattern 1: Boundary-Owned Retrieval Span + Outcome Event
**What:** Wrap each retrieval/search/grounding attempt in a stable Cairnloop event and return bounded metadata plus high-cardinality evidence separately. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md]  
**When to use:** `search/2`, `ground_for_draft/2`, and any future retrieval-backed surfaces. [VERIFIED: lib/cairnloop/retrieval.ex]  
**Example:**
```elixir
# Source: lib/cairnloop/telemetry.ex, lib/cairnloop/chat.ex, https://hexdocs.pm/telemetry/telemetry.html
Cairnloop.Telemetry.span([:retrieval, :search], %{surface: :search_modal}, fn ->
  results = do_search(query, opts)
  summary = %{
    result_bucket: result_bucket(results),
    source_mix: source_mix(results),
    canonical_hits: count(results, :knowledge_base),
    assistive_hits: count(results, :resolved_case)
  }

  {results, %{latency_ms: elapsed_ms()}, summary}
end)
```

### Pattern 2: Append-Only Gap Event with Typed Envelope + Embedded Snapshots
**What:** Persist a single row per durable gap signal with bounded enums in top-level columns and JSON/embedded snapshots for attempted evidence. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/embedded-schemas.html]  
**When to use:** No-hit search, retrieval errors, assistive-only grounding, clarification-limit escalation, and canonical-insufficient-detail outcomes. [VERIFIED: lib/cairnloop/retrieval.ex]  
**Example:**
```elixir
# Source: lib/cairnloop/automation/draft.ex, https://hexdocs.pm/ecto/Ecto.Enum.html, https://hexdocs.pm/ecto/embedded-schemas.html
schema "cairnloop_retrieval_gap_events" do
  field :surface, Ecto.Enum, values: [:search_modal, :draft_generation]
  field :outcome, Ecto.Enum, values: [:empty_recall, :retrieval_error, :weak_grounding, :policy_limit]
  field :reason, Ecto.Enum,
    values: [:no_canonical_results, :assistive_only_results, :canonical_insufficient_detail,
             :clarification_limit_reached, :provider_timeout, :index_unavailable]
  field :query_fingerprint, :string
  field :sanitized_query_excerpt, :string
  field :canonical_hit_count, :integer, default: 0
  field :assistive_hit_count, :integer, default: 0
  field :clarification_attempts, :integer, default: 0
  field :payload, :map, default: %{}
  timestamps(updated_at: false)
end
```

### Pattern 3: Oban Only for Async Durability Paths, Not for Product Semantics
**What:** Use synchronous writes when the user-facing branch depends on the row existing now, and Oban when evidence can be queued without changing the operator outcome. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md] [CITED: https://hexdocs.pm/oban/Oban.html]  
**When to use:** Queue prune, replay, or best-effort shadow persistence, but keep product outcome classification in retrieval metadata. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md]  
**Example:**
```elixir
# Source: https://hexdocs.pm/oban/Oban.html
Ecto.Multi.new()
|> Ecto.Multi.insert(:gap_event, RetrievalGapEvent.changeset(%RetrievalGapEvent{}, attrs))
|> Oban.insert(:followup, MyApp.PruneGapEventsWorker.new(%{}))
|> Repo.transaction()
```

### Anti-Patterns to Avoid
- **Persisting gap evidence from telemetry handlers:** Telemetry is lossy observability, and handlers execute in the emitter process rather than as a durable storage contract. [CITED: https://hexdocs.pm/telemetry/telemetry.html] [VERIFIED: .planning/M005-RESEARCH.md]
- **Flattening canonical and assistive evidence into one hit count:** Phase 1 and Phase 3 explicitly preserve canonical-vs-assistive trust semantics, so Phase 4 must record both separately. [VERIFIED: .planning/milestones/M009-phases/M009-S01-CONTEXT.md] [VERIFIED: .planning/milestones/M009-phases/M009-S03/M009-S03-CONTEXT.md]
- **Using freeform query text or result IDs as metric labels:** M005 and the Phase 4 context both reject high-cardinality labels in Parapet-facing metrics. [VERIFIED: .planning/M005-RESEARCH.md] [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md]
- **Treating `:failed` and `:no_hit` as the only diagnostic buckets:** The current `ground_for_draft/2` branch reasons already distinguish `:assistive_only_results`, `:clarification_limit_reached`, and `:retrieval_error`; the persisted taxonomy should keep that structure. [VERIFIED: lib/cairnloop/retrieval.ex]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Start/stop/exception instrumentation | Raw ad hoc event triplets per caller | `Cairnloop.Telemetry.span/3` over `:telemetry.span/3` | The wrapper already exists and the official API already provides the correct event lifecycle. [VERIFIED: lib/cairnloop/telemetry.ex] [CITED: https://hexdocs.pm/telemetry/telemetry.html] |
| Gap-state enums | Stringly typed status/reason columns | `Ecto.Enum` | Repo conventions already use enums for durable state and the docs support bounded values cleanly. [VERIFIED: lib/cairnloop/automation/draft.ex] [VERIFIED: lib/cairnloop/conversation.ex] [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html] |
| Rich gap payload normalization | Three to five linked tables for attempts, sources, and snapshots | One envelope table plus embeds/JSON | The locked context explicitly prefers one focused table now, and Ecto embeds are designed for schema-owned embedded data. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/embedded-schemas.html] |
| Oban job inserts in multis | `Ecto.Multi.insert(job_changeset)` for new gap workers | `Oban.insert/4` inside the multi | Official Oban docs recommend the Oban helper inside `Ecto.Multi` because it preserves job features such as uniqueness. [CITED: https://hexdocs.pm/oban/Oban.html] |

**Key insight:** Cairnloop already has one normalized retrieval contract and one host-owned observability posture; Phase 4 should extend those seams, not branch away from them. [VERIFIED: lib/cairnloop/retrieval/result.ex] [VERIFIED: .planning/milestones/M005-phases/M005-S02/M005-S02-RESEARCH.md]

## Common Pitfalls

### Pitfall 1: Missing Tenant/Host Scope at the Call Site
**What goes wrong:** Search and draft telemetry look correct structurally but represent unscoped or mis-scoped retrieval attempts. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex]  
**Why it happens:** `SearchModalComponent` ignores its `host_user_id` assign when calling retrieval, and `DraftWorker` does not propagate host scope into `ground_for_draft/1`. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex]  
**How to avoid:** Thread `surface`, `host_user_id`, and any future tenant scope through retrieval opts before adding telemetry or gap persistence. [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex]  
**Warning signs:** Retrieved resolved cases do not narrow by host user even though provider code supports `host_user_id`. [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex]

### Pitfall 2: Losing Diagnostic Detail Behind the `rescue` in `ground_for_draft/2`
**What goes wrong:** Everything becomes `:retrieval_error`, which is safe for product fallback but too coarse for quality analysis. [VERIFIED: lib/cairnloop/retrieval.ex]  
**Why it happens:** The function rescues all exceptions and returns the same escalation bundle. [VERIFIED: lib/cairnloop/retrieval.ex]  
**How to avoid:** Capture a bounded `error_class` before rescue return or instrument provider/ranker spans separately and summarize them into the root event. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md]  
**Warning signs:** Telemetry shows flat `retrieval_error` counts with no difference between timeout, bad query, unavailable index, or provider crash. [VERIFIED: lib/cairnloop/retrieval.ex]

### Pitfall 3: Duplicating Evidence Payload Shapes
**What goes wrong:** Search rows, draft evidence, telemetry evidence, and gap-event evidence drift into incompatible map shapes. [VERIFIED: lib/cairnloop/retrieval/result.ex] [VERIFIED: lib/cairnloop/automation/draft.ex]  
**Why it happens:** Each surface serializes its own view-model instead of reusing `Retrieval.Result` semantics. [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/web/search_result_presenter.ex]  
**How to avoid:** Keep `Retrieval.Result` as the canonical in-memory evidence contract and derive presenter or snapshot structs from it. [VERIFIED: lib/cairnloop/retrieval/result.ex]  
**Warning signs:** Search copy shows source/trust labels that do not match draft rails or persisted gap snapshots. [VERIFIED: lib/cairnloop/web/search_result_presenter.ex] [VERIFIED: lib/cairnloop/web/conversation_live.ex]

### Pitfall 4: Treating Unique Jobs as the Deduplication Strategy
**What goes wrong:** Retry storms or repeated no-hit searches create duplicate gap rows even if job uniqueness reduces some queue pressure. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md]  
**Why it happens:** Oban uniqueness controls job insertion windows, not semantic deduplication of evidence rows. [CITED: https://hexdocs.pm/oban/Oban.html]  
**How to avoid:** Deduplicate at the gap-event boundary with a bounded fingerprint such as `surface + query_fingerprint + outcome + host_scope + time_bucket`. [ASSUMED]  
**Warning signs:** Many near-identical rows appear for the same failed search within minutes. [ASSUMED]

## Code Examples

Verified patterns from repo code and official docs:

### Root Retrieval Event with Bounded Metadata
```elixir
# Source: lib/cairnloop/telemetry.ex, https://hexdocs.pm/telemetry/telemetry.html
Cairnloop.Telemetry.execute(
  [:retrieval, :search, :result],
  %{latency_ms: latency_ms},
  %{
    surface: :search_modal,
    source_mix: :kb_only,
    result_bucket: :hits,
    canonical_hit_count: 3,
    assistive_hit_count: 0,
    grounding_status: :strong
  }
)
```

### Host-Owned Gap Persistence in the Application Boundary
```elixir
# Source: lib/cairnloop/automation/draft.ex, https://hexdocs.pm/ecto/Ecto.Multi.html
Ecto.Multi.new()
|> Ecto.Multi.insert(
  :gap_event,
  Cairnloop.Retrieval.GapEvent.changeset(%Cairnloop.Retrieval.GapEvent{}, attrs)
)
|> Repo.transaction()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Direct `[:openinference, :span, ...]` emission in workers | Stable `[:cairnloop, :retrieval, ...]` contract first, OpenInference as adapter second | Recommended for Phase 4 because the repo already has `Cairnloop.Telemetry` and M005 locked host-owned metrics. [VERIFIED: lib/cairnloop/telemetry.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex] | Host apps and generated Parapet instrumenters get a semver-stable contract instead of coupling to trace internals. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md] |
| Generic no-hit/error buckets | Coarse operator disposition plus structured diagnostic taxonomy | Recommended for Phase 4 because `ground_for_draft/2` already distinguishes multiple reasons. [VERIFIED: lib/cairnloop/retrieval.ex] | Better product analysis and fewer misleading “retrieval failed” aggregates. [VERIFIED: lib/cairnloop/retrieval.ex] |
| Draft-only evidence blobs | Shared retrieval result semantics reused across search, draft, telemetry, and gap persistence | Already emerging in M009-S01 to M009-S03. [VERIFIED: .planning/milestones/M009-phases/M009-S01-CONTEXT.md] [VERIFIED: .planning/milestones/M009-phases/M009-S03/M009-S03-CONTEXT.md] | Reduces payload drift and makes trust copy consistent. [VERIFIED: lib/cairnloop/retrieval/result.ex] [VERIFIED: lib/cairnloop/web/search_result_presenter.ex] |
| No durable retrieval-gap evidence | Append-only retrieval gap events with typed envelope and embedded snapshots | Required by M009-REQ-09 in Phase 4. [VERIFIED: .planning/REQUIREMENTS.md] | Gives M010 a real evidence trail instead of deriving gaps from lossy telemetry only. [VERIFIED: .planning/research/EPIC_IDEAS_INTENT_GAPS.md] |

**Deprecated/outdated:**
- Treating raw query text, IDs, or citation payloads as metric labels is explicitly out of bounds for Cairnloop’s Parapet posture. [VERIFIED: .planning/M005-RESEARCH.md] [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md]
- Using telemetry handlers as the only place to persist business-critical evidence is out of bounds for this repo’s durable-evidence model. [VERIFIED: .planning/M005-RESEARCH.md] [CITED: https://hexdocs.pm/telemetry/telemetry.html]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A bounded dedupe key should include `surface + query_fingerprint + outcome + host_scope + time_bucket`. [ASSUMED] | Common Pitfalls | Low to medium. The exact fingerprint recipe may change, but the need for semantic dedupe does not. |

## Resolved Planning Decisions

1. **Retention window for gap events**
   - Decision: Keep retrieval gap events for **90 days by default**. [RESOLVED]
   - Why: This preserves enough history for the planned M010 clustering seed data without turning Phase 4 into indefinite analytics storage, and it satisfies D-15's requirement for explicit retention discipline. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md] [VERIFIED: .planning/research/EPIC_IDEAS_INTENT_GAPS.md]
   - Implementation shape: Store rows append-only with indexed occurrence time, then prune old rows through an explicit Oban maintenance worker or equivalent host-owned maintenance path. [CITED: https://hexdocs.pm/oban/Oban.html]

2. **Persistence path for no-hit and failed-search evidence**
   - Decision: Persist the primary gap-event row **synchronously at the retrieval/search/draft application boundary** using `Ecto.Multi`, and reserve Oban for explicit follow-up work such as retention pruning or replay maintenance. [RESOLVED]
   - Why: D-12 and D-20 require durable evidence to be written from the application boundary where product trust semantics are known, while keeping worker retry semantics separate from the meaning of the retrieval outcome. Synchronous persistence also keeps the evidence immediately inspectable after the user-facing branch completes. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md] [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex]
   - Implementation shape: Search and draft boundaries call a synchronous recorder API directly; Oban must not be the primary path for inserting the evidence row itself. [CITED: https://hexdocs.pm/oban/Oban.html]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | schema, retrieval, tests, LiveView, Mix tasks | ✓ [VERIFIED: local command] | `1.19.5` [VERIFIED: local command] | — |
| PostgreSQL | retrieval corpus, new gap-event table, local tests | ✓ [VERIFIED: local command] | `14.17` and local server accepting connections on `/tmp:5432` [VERIFIED: local command] | — |
| Mix | migrations and test execution | ✓ [VERIFIED: local command] | `1.19.5` [VERIFIED: local command] | — |

**Missing dependencies with no fallback:** None found during local environment audit. [VERIFIED: local command]

**Missing dependencies with fallback:** None needed for this phase. [VERIFIED: local command]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix LiveViewTest on repo-pinned Phoenix LiveView `1.1.30`. [VERIFIED: test/test_helper.exs] [VERIFIED: test/cairnloop/web/conversation_live_test.exs] [VERIFIED: mix.lock] |
| Config file | `test/test_helper.exs`. [VERIFIED: test/test_helper.exs] |
| Quick run command | `mix test test/cairnloop/retrieval_test.exs test/cairnloop/automation/scoria_engine_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/conversation_live_test.exs`. [VERIFIED: test file inventory] |
| Full suite command | `mix test`. [VERIFIED: repo test layout] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| M009-REQ-08 | Retrieval/search/draft flows emit bounded `[:cairnloop, :retrieval, ...]` events with low-cardinality metadata and correct outcome taxonomy. [VERIFIED: .planning/REQUIREMENTS.md] | unit + integration | `mix test test/cairnloop/retrieval_test.exs test/cairnloop/automation/workers/draft_worker_test.exs test/cairnloop/retrieval/telemetry_test.exs` | `retrieval_test.exs` and `draft_worker_test.exs` exist; `retrieval/telemetry_test.exs` is ❌ Wave 0. [VERIFIED: test file inventory] |
| M009-REQ-08 | Search and draft trust cues reflect the same source/trust/outcome semantics the telemetry sees. [VERIFIED: .planning/REQUIREMENTS.md] | LiveView | `mix test test/cairnloop/web/search_modal_component_test.exs test/cairnloop/web/conversation_live_test.exs` | Both files exist. [VERIFIED: test file inventory] |
| M009-REQ-09 | No-hit, assistive-only, clarification-limit, and retrieval-error cases persist append-only gap rows with sanitized payloads. [VERIFIED: .planning/REQUIREMENTS.md] | unit + integration | `mix test test/cairnloop/retrieval/gap_event_test.exs test/cairnloop/automation/workers/draft_worker_test.exs` | `gap_event_test.exs` is ❌ Wave 0; draft worker tests exist. [VERIFIED: test file inventory] |
| M009-REQ-09 | Search misses record the correct surface, scope, and result counts without unsafe labels. [VERIFIED: .planning/REQUIREMENTS.md] | LiveView + integration | `mix test test/cairnloop/web/search_modal_component_test.exs test/cairnloop/retrieval/gap_event_test.exs` | Search modal test exists; gap-event test is ❌ Wave 0. [VERIFIED: test file inventory] |

### Sampling Rate
- **Per task commit:** Run the phase-focused quick suite above. [VERIFIED: repo test layout]
- **Per wave merge:** Run `mix test`. [VERIFIED: repo test layout]
- **Phase gate:** Full suite green before `/gsd-verify-work`. [VERIFIED: workflow instructions]

### Wave 0 Gaps
- [ ] `test/cairnloop/retrieval/telemetry_test.exs` — event names, metadata partition, error taxonomy, and Parapet-safe label assertions. [VERIFIED: test file inventory]
- [ ] `test/cairnloop/retrieval/gap_event_test.exs` — append-only persistence, redaction, dedupe, and canonical/assistive count assertions. [VERIFIED: test file inventory]
- [ ] Extend `test/cairnloop/web/search_modal_component_test.exs` to assert scope propagation and no-hit trust copy. [VERIFIED: test/cairnloop/web/search_modal_component_test.exs]
- [ ] Extend `test/cairnloop/automation/workers/draft_worker_test.exs` to assert retrieval events and persisted weak-grounding evidence on `:assistive_only_results`, `:clarification_limit_reached`, and `:retrieval_error`. [VERIFIED: test/cairnloop/automation/workers/draft_worker_test.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 4 does not add authentication flows directly. [VERIFIED: phase scope] |
| V3 Session Management | no | Phase 4 works inside existing LiveView/operator sessions and does not change session primitives. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/web/conversation_live.ex] |
| V4 Access Control | yes | Preserve `host_user_id` and visibility scope through retrieval, telemetry, and gap persistence so assistive evidence never crosses tenant boundaries. [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] [VERIFIED: lib/cairnloop/web/search_modal_component.ex] |
| V5 Input Validation | yes | Validate bounded enums, truncate/sanitize query excerpts, and limit embedded payload size. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md] [VERIFIED: lib/cairnloop/retrieval/resolved_case_evidence.ex] |
| V6 Cryptography | no | Phase 4 does not add cryptographic requirements directly. [VERIFIED: phase scope] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Query text or IDs leaking into labels | Information Disclosure / DoS | Keep raw query text in sanitized evidence storage only and expose only bounded enums/counts in metrics metadata. [VERIFIED: .planning/M005-RESEARCH.md] [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md] |
| Cross-tenant assistive evidence attribution | Information Disclosure | Propagate `host_user_id` into retrieval and persist scope fields in gap events for later auditability. [VERIFIED: lib/cairnloop/retrieval/providers/resolved_cases.ex] [VERIFIED: lib/cairnloop/web/search_modal_component.ex] |
| Unbounded JSON payload growth | Denial of Service | Limit payload keys and snapshot depth just as `ResolvedCaseEvidence` already constrains metadata size. [VERIFIED: lib/cairnloop/retrieval/resolved_case_evidence.ex] |
| Hidden durable write failure in observability path | Repudiation | Write evidence through Ecto/Oban application boundaries, not inside telemetry handlers. [VERIFIED: .planning/M005-RESEARCH.md] [CITED: https://hexdocs.pm/telemetry/telemetry.html] |

## Sources

### Primary (HIGH confidence)
- `.planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md` - Locked Phase 4 decisions, scope, and deferred work. [VERIFIED: .planning/milestones/M009-phases/M009-S04/M009-S04-CONTEXT.md]
- `.planning/M009-ROADMAP.md` and `.planning/REQUIREMENTS.md` - Requirement mapping and success criteria. [VERIFIED: .planning/M009-ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md]
- `lib/cairnloop/retrieval.ex` - Current retrieval seam, grounding assessment, and rescue behavior. [VERIFIED: lib/cairnloop/retrieval.ex]
- `lib/cairnloop/retrieval/result.ex` and `lib/cairnloop/retrieval/ranker.ex` - Normalized result contract and ranking semantics. [VERIFIED: lib/cairnloop/retrieval/result.ex] [VERIFIED: lib/cairnloop/retrieval/ranker.ex]
- `lib/cairnloop/telemetry.ex` and `lib/cairnloop/chat.ex` - Existing stable telemetry wrapper and span usage pattern. [VERIFIED: lib/cairnloop/telemetry.ex] [VERIFIED: lib/cairnloop/chat.ex]
- `lib/cairnloop/automation/workers/draft_worker.ex` and `lib/cairnloop/automation/scoria_engine.ex` - Grounded drafting seam and proposal taxonomy. [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex] [VERIFIED: lib/cairnloop/automation/scoria_engine.ex]
- `lib/cairnloop/web/search_modal_component.ex`, `lib/cairnloop/web/search_result_presenter.ex`, and `lib/cairnloop/web/conversation_live.ex` - Current operator-facing trust surfaces and scope-propagation gap. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/web/search_result_presenter.ex] [VERIFIED: lib/cairnloop/web/conversation_live.ex]
- `https://hexdocs.pm/telemetry/telemetry.html` - Official span and execute semantics for the public event contract. [CITED: https://hexdocs.pm/telemetry/telemetry.html]
- `https://hexdocs.pm/ecto/Ecto.Enum.html` and `https://hexdocs.pm/ecto/embedded-schemas.html` - Official guidance for bounded enums and embedded schema payloads. [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html] [CITED: https://hexdocs.pm/ecto/embedded-schemas.html]
- `https://hexdocs.pm/oban/Oban.html` - Official guidance for using Oban inserts and `Ecto.Multi` integration. [CITED: https://hexdocs.pm/oban/Oban.html]

### Secondary (MEDIUM confidence)
- `.planning/M005-RESEARCH.md` and `.planning/milestones/M005-phases/M005-S02/M005-S02-RESEARCH.md` - Repo-specific host-owned telemetry posture and Parapet-safe cardinality guidance. [VERIFIED: .planning/M005-RESEARCH.md] [VERIFIED: .planning/milestones/M005-phases/M005-S02/M005-S02-RESEARCH.md]
- `.planning/research/EPIC_IDEAS_INTENT_GAPS.md` - Future M010 use of durable no-hit evidence. [VERIFIED: .planning/research/EPIC_IDEAS_INTENT_GAPS.md]

### Tertiary (LOW confidence)
- None. [VERIFIED: research session]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all recommended building blocks are already in the repo or documented in primary official docs. [VERIFIED: mix.lock] [CITED: https://hexdocs.pm/telemetry/telemetry.html] [CITED: https://hexdocs.pm/oban/Oban.html]
- Architecture: HIGH - the proposal extends existing retrieval, draft, and telemetry seams rather than inventing a new subsystem. [VERIFIED: lib/cairnloop/retrieval.ex] [VERIFIED: lib/cairnloop/telemetry.ex]
- Pitfalls: HIGH - the biggest risks are visible in current code paths and directly affect telemetry correctness. [VERIFIED: lib/cairnloop/web/search_modal_component.ex] [VERIFIED: lib/cairnloop/automation/workers/draft_worker.ex] [VERIFIED: lib/cairnloop/retrieval.ex]

**Research date:** 2026-05-20 [VERIFIED: local system date]  
**Valid until:** 2026-06-19 for repo-shape guidance unless M009 implementation changes the retrieval seam first. [ASSUMED]
