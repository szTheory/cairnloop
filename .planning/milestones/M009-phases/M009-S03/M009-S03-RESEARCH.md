# Phase M009-S03: Grounded Drafting & Citations - Research

**Researched:** 2026-05-18
**Domain:** Elixir/Phoenix grounded drafting over host-owned retrieval with durable operator evidence review
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md) [VERIFIED: `.planning/milestones/M009-phases/M009-S03/M009-S03-CONTEXT.md`]

### Locked Decisions
- **D-04 to D-09:** Draft generation must consume a canonical-first grounding bundle. Knowledge Base evidence remains policy truth; resolved cases are assistive only.
- **D-10 to D-15:** The draft output contract must be structured, not a single content blob. Minimum shape: `operator_summary`, `customer_reply`, and `evidence[]`.
- **D-16 to D-20:** Weak grounding is a workflow state, not a warning badge. Empty, conflicting, errored, or assistive-only retrieval should default to escalation, with only a narrow clarification lane for recoverable cases.
- **D-21 to D-25:** Supporting evidence stays visible by default in the `ConversationLive` evidence rail. Do not hide source/trust semantics or move citations into the editable reply body by default.
- **D-26 to D-29:** The retrieval-to-draft boundary must stay host-owned, explicit, and reusable. Persist enough grounding state that later Scoria traces and M009-S04 telemetry can explain why a draft was produced, downgraded, or escalated.

### Important Discretion Areas
- Exact module names for the grounding bundle and proposal artifact helpers.
- Exact schema layout for structured proposal and evidence storage inside `cairnloop_drafts`.
- Exact rule thresholds used to classify canonical coverage as strong, weak-but-recoverable, or escalation-only.
</user_constraints>

<phase_requirements>
## Phase Requirements [VERIFIED: `.planning/REQUIREMENTS.md` + `.planning/M009-ROADMAP.md`]

| ID | Description | Planning Implication |
|----|-------------|----------------------|
| M009-REQ-06 | AI drafting can request grounded retrieval context before proposing a response. | `DraftWorker` must fetch retrieval context through `Cairnloop.Retrieval` before calling `ScoriaEngine`, and the engine contract must accept a structured grounding bundle rather than performing its own remote lookup. |
| M009-REQ-07 | Drafts display supporting citations or retrieved evidence and fall back to escalation when retrieval confidence is weak or no trustworthy sources exist. | Draft persistence and `ConversationLive` rendering must preserve evidence rows, source/trust labels, citation targets, and explicit proposal states for normal draft vs clarification vs escalation. |
</phase_requirements>

## Summary

The current drafting path is still pre-retrieval scaffolding. `Cairnloop.Automation.ScoriaEngine.generate_draft/1` performs a remote `Req.get`, returns a map with a single `content` string, and keeps the retrieved context only in an opaque `context_used` payload. `Cairnloop.Automation.Workers.DraftWorker` then persists only `proposal.content`, which means the operator UI cannot inspect evidence, the policy layer cannot reason about weak grounding, and later telemetry cannot explain why a draft existed. [VERIFIED: `lib/cairnloop/automation/scoria_engine.ex` + `lib/cairnloop/automation/workers/draft_worker.ex`]

The repo already has the right substrate to fix this without inventing a second retrieval stack. `Cairnloop.Retrieval` is the host-owned search boundary, `Cairnloop.Retrieval.Result` already carries `source_type`, `trust_level`, `citation_target`, `match_reasons`, and `can_ground_reply?`, and `Cairnloop.Web.SearchResultPresenter` already formats the source/trust semantics that the Phase 3 evidence rail should reuse. The planning focus should therefore be the contract between retrieval and drafting, not a new search implementation. [VERIFIED: `lib/cairnloop/retrieval.ex` + `lib/cairnloop/retrieval/result.ex` + `lib/cairnloop/web/search_result_presenter.ex`]

The persistence seam is also favorable. `Cairnloop.Automation.Draft` is the durable artifact already shown in `ConversationLive`, and `Cairnloop.Automation.create_draft/2` uses a clean `Ecto.Multi` transaction with post-success telemetry. The phase should evolve this artifact into a structured grounded proposal instead of introducing transient in-memory evidence payloads that the rail renders ad hoc. [VERIFIED: `lib/cairnloop/automation/draft.ex` + `lib/cairnloop/automation.ex` + `lib/cairnloop/web/conversation_live.ex`]

**Primary recommendation:** Split execution into two plans. Plan 01 should establish the retrieval-to-draft grounding contract, structured proposal persistence, and explicit worker branching for strong grounding vs clarification vs escalation. Plan 02 should render the structured proposal and supporting evidence in `ConversationLive`, reusing Phase 2 source/trust/citation semantics and adding tests that keep weak-grounding behavior visible and safe.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Retrieval before drafting | API / Backend | Database / Storage | `Cairnloop.Retrieval` already owns source/trust filtering and should remain the only search boundary. |
| Grounding bundle classification | API / Backend | Worker policy branch | Strong vs weak vs escalation is a durable product rule, not a UI-only concern. |
| Proposal generation | Automation engine | Retrieval bundle input | `ScoriaEngine` should consume grounded input and return structured output, not perform remote lookups itself. |
| Structured draft persistence | Automation context | Database / Storage | `Cairnloop.Automation` already owns draft writes and lifecycle telemetry. |
| Evidence rail rendering | LiveView UI | Presenter helpers | `ConversationLive` is the right mount point, but labels/citation copy should reuse server-owned result semantics. |
| Weak-grounding fallback | Worker + UI | Policy module | Worker decides proposal type; UI makes that state explicit to the operator. |

## Existing Code Realities

### What can be reused
- `Cairnloop.Retrieval` already merges canonical and assistive evidence through one host-owned facade. [VERIFIED: `lib/cairnloop/retrieval.ex`]
- `Cairnloop.Retrieval.Result` already exposes most of the source, trust, citation, and preview fields the draft evidence rail needs. [VERIFIED: `lib/cairnloop/retrieval/result.ex`]
- `Cairnloop.Web.SearchResultPresenter` already encodes the source/trust labels and open-path behavior that Phase 3 should echo. [VERIFIED: `lib/cairnloop/web/search_result_presenter.ex`]
- `ConversationLive` already has an evidence rail and a draft review shell, so the grounded review surface can extend an existing operator workflow rather than replacing it. [VERIFIED: `lib/cairnloop/web/conversation_live.ex`]

### What is missing
- No retrieval-to-draft function or grounding bundle exists yet under `Cairnloop.Retrieval`. [VERIFIED: `lib/cairnloop/retrieval.ex`]
- `ScoriaEngine` still performs its own remote HTTP lookup and returns only `proposal.content`. [VERIFIED: `lib/cairnloop/automation/scoria_engine.ex`]
- `DraftWorker` cannot distinguish strong grounding from clarification or escalation-only states because it branches only on the automation policy result. [VERIFIED: `lib/cairnloop/automation/workers/draft_worker.ex`]
- `Cairnloop.Automation.Draft` stores only `content` and `status`, so citations, operator summary, evidence snapshot, and proposal type are not durable today. [VERIFIED: `lib/cairnloop/automation/draft.ex`]
- `ConversationLive` renders raw draft text and status only; there is no dedicated evidence card or citation/open-target surface. [VERIFIED: `lib/cairnloop/web/conversation_live.ex` + `test/cairnloop/web/conversation_live_test.exs`]

## Recommended Structure

```text
lib/cairnloop/
├── retrieval.ex
├── retrieval/
│   └── result.ex
├── automation.ex
├── automation/
│   ├── draft.ex
│   ├── scoria_engine.ex
│   └── workers/draft_worker.ex
└── web/
    ├── conversation_live.ex
    └── search_result_presenter.ex

test/cairnloop/
├── automation_test.exs
├── automation/scoria_engine_test.exs
├── automation/workers/draft_worker_test.exs
└── web/conversation_live_test.exs
```

This phase does not need a new retrieval provider or a second presentation system. It needs one paved road from retrieval results to structured proposal to visible operator evidence review.

## Patterns To Follow

### Pattern 1: Host-owned retrieval boundary first
Keep retrieval in `Cairnloop.Retrieval`, then pass a grounding bundle into drafting. Do not reintroduce a draft-local `Req` lookup path.

### Pattern 2: Structured durable proposal artifact
Evolve `Cairnloop.Automation.Draft` to store proposal type, operator summary, customer reply, and evidence snapshot durably so worker, policy, UI, and telemetry share one source of truth.

### Pattern 3: Explicit worker state machine
Keep the draft worker branch visible and testable: strong canonical grounding -> normal pending/approved draft; weak-but-recoverable -> clarification proposal; empty/conflicting/assistive-only/errored -> escalation recommendation.

### Pattern 4: Shared source/trust presentation semantics
Reuse the source/trust/citation/open-target semantics from Phase 2 instead of inventing a new label system for grounded drafts.

## Risks And Pitfalls

- **Trust collapse:** If the plan lets resolved-case evidence generate a normal customer reply without strong canonical support, it violates the milestone posture immediately.
- **Blob persistence regression:** If grounding data stays only in memory or in `context_used`, the operator rail and Phase 4 telemetry will both be underpowered.
- **UI-only weak-grounding safeguards:** Warning copy in the rail is not enough. Proposal type and worker branching must enforce escalation/clarification behavior before rendering.
- **Presentation drift from Phase 2:** If draft evidence uses different source/trust labels or open actions than operator search, operator trust will fragment across two adjacent workflows.

## Validation Architecture

The phase should verify three layers:

1. Grounding contract:
   - retrieval results are transformed into a canonical-first draft bundle with explicit source/trust/citation semantics.
2. Worker and persistence contract:
   - strong, clarification, and escalation states produce distinct durable proposal records and deterministic worker outcomes.
3. Operator review contract:
   - `ConversationLive` shows operator summary plus visible supporting evidence, and weak-grounding branches render as escalation or clarification rather than a normal reply blob.

Fast feedback should come from focused ExUnit tests around `ScoriaEngine`, `DraftWorker`, `Automation`, and `ConversationLive`, with manual inspection reserved for the final evidence-rail readability check.
