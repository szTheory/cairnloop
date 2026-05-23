# Cairnloop Project

## What This Is
An embedded, Phoenix-native customer support automation layer that turns support conversations into answers, product signals, knowledge-base improvements, and safe automated actions.

## Core Value
Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.

## Current State

**Latest shipped milestone:** `vM010 KB AI Maintenance` on 2026-05-23.

**What is now true:**
- Cairnloop has a host-owned hybrid retrieval layer over published Knowledge Base content and
  resolved support evidence.
- Operators have a retrieval-backed `cmd+k` search flow with explicit source, recency, trust, and
  citation cues.
- Durable gap signals now project into a ranked KB maintenance queue with inspectable evidence and
  stable candidate identity.
- AI-prepared article and revision suggestions are citation-backed, inspectable, and fail closed
  when evidence or grounding is insufficient.
- KB review now runs through durable review tasks with explicit approve, reject, defer, publish,
  and reindex follow-through states.
- Operators can launch maintenance directly from conversation context without creating a second
  workflow surface outside the shared review lane.
- Maintenance telemetry is bounded and emitted from durable workflow seams rather than transient UI state.

**Closeout posture:** `vM010` is shipped and archived as a `tech_debt` milestone. All 12 v1
requirements are verified; the remaining debt is explicit, traceable, and non-blocking.

## Next Milestone Goals

**Next candidate:** `M011 AI Tool Governance & MCP Integration`

**Why next:** Retrieval is now trustworthy and KB maintenance is operator-reviewed. The next
highest-leverage step is to broaden from grounded answer and maintenance primitives into
policy-gated actions and governed integrations.

**Initial goals:**
- Add explicit policy and approval boundaries for higher-agency tool use.
- Define MCP or governed-tool integration seams without weakening the host-owned trust layer.
- Reuse the existing retrieval, review, and telemetry primitives instead of creating parallel truth sources.

## Requirements

### Validated
- ✓ Multi-Channel Ingress Engine — vM001
- ✓ AI Triage, Drafting, & Governance — vM002
- ✓ Deep Context Enrichment — vM003
- ✓ Customer Voice Activation — vM004
- ✓ Durable Auditing & SRE Observability — vM005
- ✓ Omnichannel SLA Escalation — vM006
- ✓ Semantic Search UI Foundations — vM007
- ✓ Knowledge Base Engine — vM008
- ✓ Retrieval-First Support Answers & Search Ops — vM009
- ✓ KB AI Maintenance — vM010

### Active
- [ ] Define the policy and approval model for governed AI tool execution.
- [ ] Establish MCP or governed-tool seams that preserve host-owned trust and auditability.
- [ ] Keep new action lanes fail-closed, reviewable, and observable from durable workflow state.

## Validated Requirements

- vM010 validated `GAP-01` through `GAP-03`: retrieval and manual-handling evidence now converge
  into ranked, inspectable KB gap candidates.
- vM010 validated `DRAFT-01` through `DRAFT-03`: article and revision suggestions are
  citation-backed and fail closed when grounding is weak.
- vM010 validated `REVIEW-01` through `REVIEW-03`: review tasks now own decision, publish, and
  follow-through workflow state.
- vM010 validated `OPS-01` through `OPS-03`: operators can launch quick fixes from threads and
  maintenance telemetry remains bounded across publish and reindex follow-through.

### Out of Scope
- External vector/search infrastructure as the default path.
- Autonomous customer-visible replies based only on retrieval confidence.
- Treating raw live conversations as canonical policy truth.
- Autonomous publishing of substantive KB content.
- Broad MCP or governed-tool expansion before the KB maintenance loop is operational.

## Previous Milestone Brief

<details>
<summary>Archived vM010 brief</summary>

### vM010 KB AI Maintenance

**Goal:** Turn retrieval misses, weak grounding, and repeated manual handling into a safe
Knowledge Base maintenance workflow.

**Target features:**
- Gap detection and clustering from retrieval no-hits, weak grounding, and repeated support
  handling.
- AI-assisted draft article creation and suggested revisions for existing KB content.
- Operator review workflow with evidence, citations, diff/review actions, and publish gated by
  the existing KB review path.
- In-thread quick-fix flow so operators can start a KB draft directly from conversation evidence.

**Why now:** `vM009` already emits retrieval telemetry and durable gap signals. The
highest-leverage next step was to turn those signals into operator-reviewed KB improvements before
expanding AI agency or external integration surface area.

</details>

<details>
<summary>Archived vM009 brief</summary>

### vM009 Retrieval-First Support Answers & Search Ops

**Goal:** Turn the Knowledge Base substrate into visible operator and AI value through grounded
retrieval, trustworthy search, and measurable answer quality.

**Target features:**
- Hybrid retrieval over published Knowledge Base revisions and resolved conversation summaries
  using `pgvector` plus PostgreSQL full-text search.
- Operator `cmd+k` search and similar-case assist inside the LiveView dashboard.
- Grounded AI draft flow with citations, retrieval telemetry, and policy-aware escalation when
  retrieval confidence is weak.
- Failed-search and no-hit analytics that feed the future knowledge-gap workflow.

**Why now:** M008 shipped the durable RAG substrate on 2026-05-17. The highest-leverage next step
is to make retrieval the trust layer before expanding into broader tool autonomy or outbound
workflows.

</details>

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-23 after shipping vM010*
