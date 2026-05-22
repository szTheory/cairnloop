# M009-S03 Context: Grounded Drafting & Citations

**Gathered:** 2026-05-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Improve AI draft quality by grounding draft generation in retrieved evidence before the operator reviews the proposal. This phase covers the retrieval-to-draft contract, weak-grounding policy, draft payload shape, and operator-facing citation/evidence presentation inside the conversation workflow. It does not cover operator search UX beyond reuse of its result semantics, autonomous customer-visible sending, or retrieval telemetry dashboards beyond the contracts needed to support later phases.

</domain>

<decisions>
## Implementation Decisions

### Decision-making posture
- **D-01:** Shift decision burden left inside GSD for Cairnloop. Downstream agents should make strong defaults aligned with Cairnloop's trust posture, architecture, and operator UX instead of re-escalating normal implementation choices.
- **D-02:** Re-escalate only for decisions that materially change trust semantics, milestone scope, or the product's embedded host-owned posture.
- **D-03:** Principle of least surprise beats maximal automation. Draft quality, source clarity, and explicit fallback matter more than squeezing out the highest draft rate.

### Retrieval bundle for draft generation
- **D-04:** Use a two-stage, canonical-first evidence bundle for draft generation.
- **D-05:** Stage 1 must retrieve and assess canonical Knowledge Base evidence first.
- **D-06:** Stage 2 may add labeled resolved-case evidence only when canonical coverage is weak and only as assistive troubleshooting context, never as policy truth.
- **D-07:** Do not flatten Knowledge Base and resolved-case evidence into one undifferentiated prompt bundle.
- **D-08:** The draft input contract must preserve explicit source semantics, stable source identifiers, citation targets, and match reasons so evidence can be traced end to end.
- **D-09:** Visibility and tenant filtering must already be enforced before any evidence enters the draft bundle.

### Draft payload shape
- **D-10:** Replace the current single-blob draft posture with a structured tri-part proposal shape.
- **D-11:** The proposal must contain, at minimum: `operator_summary`, `customer_reply`, and `evidence[]`.
- **D-12:** `operator_summary` is internal-only and should stay short, explicit, and action-oriented: what supports the reply, what cautions remain, and whether escalation or clarification is needed.
- **D-13:** `customer_reply` is the editable proposed outbound text and must stay distinct from internal reasoning and raw evidence excerpts.
- **D-14:** `evidence[]` must preserve source type, trust level, snippet/excerpt, citation target, match reasons, and whether the evidence can directly ground a customer-facing reply.
- **D-15:** Keep one shared grounding snapshot behind summary, reply, citations, and trace data rather than generating separate ad hoc payloads per surface.

### Weak-grounding and fallback policy
- **D-16:** Do not create a normal customer-facing draft when retrieval is empty, conflicting, retrieval errored, or only assistive evidence is available.
- **D-17:** The default weak-grounding fallback is a structured escalation recommendation for the operator, not a “draft anyway with warning” pattern.
- **D-18:** A clarification-question draft is allowed only for weak-but-recoverable cases where canonical grounding is plausible but missing one bounded piece of customer context.
- **D-19:** Clarification-question fallback must be tightly bounded: ask one focused question, do not imply unsupported conclusions, and force escalation after one failed clarification turn rather than looping.
- **D-20:** Warning badges alone are not a safety mechanism. Safety must be encoded in the draft state machine and visible proposal type.

### Citation and evidence presentation
- **D-21:** Show supporting evidence in a dedicated, always-visible evidence section/card adjacent to the draft card inside the existing `ConversationLive` evidence rail.
- **D-22:** Keep the customer reply body clean; do not default to inline citation chips or heavy source-echoing inside the editable draft text.
- **D-23:** Evidence presentation should reuse the retrieval result semantics established in M009-S01 and M009-S02: explicit source label, explicit trust label, concise excerpt, recency, and direct open/citation target.
- **D-24:** Source label and trust label must appear together on each evidence item. Do not rely on color alone or hide the distinction between canonical Knowledge Base truth and assistive resolved cases.
- **D-25:** Keep evidence visible by default for operator review. Do not hide grounding behind collapsible-only affordances in the default experience.

### Architecture and ergonomics
- **D-26:** Introduce a durable, host-owned grounding contract between retrieval and drafting rather than letting `ScoriaEngine` perform opaque remote lookups on its own.
- **D-27:** The drafting flow should remain idiomatic for Elixir/Phoenix/Ecto/Oban: explicit structs/maps, durable state, observable branching, and small composable boundaries rather than hidden agent magic.
- **D-28:** Persist enough structured grounding data that Scoria traces and later Parapet-safe telemetry can explain why a draft was produced, downgraded to clarification, or escalated.
- **D-29:** Reuse normalized retrieval contracts and presenters where possible instead of inventing draft-only evidence payloads.

### the agent's Discretion
- Exact module names and schema names for the grounding snapshot / proposal artifact
- Exact thresholds or rule shape used to classify canonical coverage as strong vs weak
- Exact wording of operator-summary cautions and escalation labels
- Exact rail layout and compact/mobile fallback details, so long as evidence remains visible by default
- Exact prompt wording that enforces “never promote resolved case evidence to policy truth”

</decisions>

<specifics>
## Specific Ideas

- The winning direction is a coherent package, not four separate choices:
  - canonical-first retrieval bundle
  - structured tri-part proposal payload
  - adjacent evidence card in the current rail
  - explicit escalation recommendation as the default low-trust branch
- Treat grounded drafting as an operator-grade review artifact, not a chat-style message blob.
- Keep the `Knowledge Base` vs `Similar resolved case` distinction obvious everywhere. Resolved cases may help with troubleshooting or phrasing, but they do not become policy.
- Clarification is a narrow recovery lane, not a generic “AI asks follow-up forever” mode.
- Emphasize great DX for host developers and future maintainers: one paved-road contract from retrieval to draft to UI to traces.
- Ecosystem lessons carried into the recommendations:
  - successful tools get more value from good knowledge quality and visible sources than from aggressive autonomy
  - too many sources and flattened source semantics degrade accuracy and operator trust
  - hidden or optional source review is a repeat footgun
  - strong products preserve a clear handoff path instead of bluffing when grounding is weak

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone requirements and product posture
- `.planning/M009-ROADMAP.md` — Phase 3 goal, requirements, success criteria, and milestone boundary
- `.planning/PROJECT.md` — Current milestone framing and host-owned support-automation posture
- `.planning/REQUIREMENTS.md` — M009 requirement mapping and out-of-scope constraints
- `.planning/STATE.md` — Current milestone state and accumulated architectural decisions
- `.planning/MILESTONE-ARC.md` — Retrieval-first strategic ordering and non-goals
- `.planning/PROJECT_EPICS.md` — Durable product and architectural direction for grounded support workflows

### Prior phase decisions
- `.planning/milestones/M009-phases/M009-S01-CONTEXT.md` — Locked retrieval semantics, source hierarchy, trust boundary, and weak-grounding posture from Phase 1
- `.planning/milestones/M009-phases/M009-S02-CONTEXT.md` — Locked operator-search result semantics, preview behavior, and evidence-first presentation posture from Phase 2

### Product research and project vision
- `prompts/cairnloop_brand_book.md` — Brand and UX posture: show your sources, never trap the customer, make safety explicit
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — Ecosystem lessons, support-product tradeoffs, and retrieval/knowledge guidance
- `prompts/scoria overview for integration ideas.txt` — Traceability, evaluation, and operator-grade AI quality-layer guidance
- `prompts/parapet overview for integration ideas.txt` — Telemetry-contract and reliability guidance relevant to grounding outcomes

### Existing code seams
- `lib/cairnloop/retrieval.ex` — Current retrieval facade that should become the paved-road drafting dependency
- `lib/cairnloop/retrieval/result.ex` — Normalized retrieval result contract with source/trust/citation fields
- `lib/cairnloop/automation/scoria_engine.ex` — Current draft-generation seam that must stop acting like an opaque remote lookup boundary
- `lib/cairnloop/automation/workers/draft_worker.ex` — Current draft pipeline and policy junction
- `lib/cairnloop/web/conversation_live.ex` — Current draft review surface and evidence rail
- `lib/cairnloop/web/search_modal_component.ex` — Existing evidence-first preview semantics that Phase 3 should echo rather than contradict

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/cairnloop/retrieval.ex` — Single retrieval boundary already exists and should feed drafting directly
- `lib/cairnloop/retrieval/result.ex` — Source, trust, match-reason, and citation fields already model most of the evidence contract Phase 3 needs
- `lib/cairnloop/web/conversation_live.ex` — Existing evidence rail and draft review shell provide the natural mounting point for structured grounded proposals
- `lib/cairnloop/web/search_modal_component.ex` — Source-aware result presentation and preview behavior from Phase 2 can be reused conceptually for draft evidence display

### Established Patterns
- Host-owned Ecto state over opaque remote workflows
- Explicit context boundaries and normalized structs rather than UI-specific transport payloads
- Calm operator UX that favors inspectability over flashy AI affordances
- Oban-backed asynchronous work with clear policy branching points

### Integration Points
- `DraftWorker` should request retrieval context before generating a draft and branch on grounding status rather than always producing one generic proposal
- `ScoriaEngine` should receive a structured grounding bundle and return a structured grounded proposal instead of a single `content` string
- `ConversationLive` should render proposal summary, proposed reply, and supporting evidence as separate but linked review surfaces
- Future Scoria traces and Phase 4 telemetry should consume the same grounding-status and evidence snapshot used by the operator UI

</code_context>

<deferred>
## Deferred Ideas

- Inline per-sentence citation chips inside editable draft text
- Full split-workbench draft/evidence layout that rewrites the conversation shell
- Letting resolved-case evidence independently justify customer-facing policy answers
- “Draft anyway with warning badge” as a default fallback pattern
- Broader autonomous send behavior based on retrieval confidence alone
- Rich retrieval-quality dashboards and no-hit analytics surfaces, which belong to M009-S04

</deferred>

---

*Phase: M009-S03*
*Context gathered: 2026-05-17*
