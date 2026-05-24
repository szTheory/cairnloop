# Cairnloop Project

## What This Is
An embedded, Phoenix-native customer support automation layer that turns support conversations into answers, product signals, knowledge-base improvements, and safe governed actions inside the host app.

## Core Value
Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.

## Current State

**Latest shipped milestone:** `vM010 KB AI Maintenance` on 2026-05-23.

**What is now true:**
- Cairnloop has a host-owned hybrid retrieval layer over published Knowledge Base content and resolved support evidence.
- Operators have a retrieval-backed `cmd+k` search flow with explicit source, recency, trust, and citation cues.
- Durable gap signals now project into a ranked KB maintenance queue with inspectable evidence and stable candidate identity.
- AI-prepared article and revision suggestions are citation-backed, inspectable, and fail closed when evidence or grounding is insufficient.
- KB review now runs through durable review tasks with explicit approve, reject, defer, publish, and reindex follow-through states.
- Operators can launch maintenance directly from conversation context without creating a second workflow surface outside the shared review lane.
- Maintenance telemetry is bounded and emitted from durable workflow seams rather than transient UI state.

**Current milestone:** `vM011 AI Tool Governance & MCP Integration`

**Why now:** Retrieval is now trustworthy and KB maintenance is operator-reviewed. The next leverage point is to let Cairnloop propose and govern support actions without weakening host-owned trust, approval, or audit boundaries.

**Target features:**
- Introduce a durable governed-action workflow for typed host-owned tools, starting with internal read-only and low-blast-radius support actions.
- Add policy-gated approval and resume mechanics using Ecto and Oban instead of synchronous LiveView execution.
- Reuse retrieval, review, telemetry, and audit primitives so tool actions stay grounded, fail closed, and inspectable in-thread.
- Define MCP as an optional edge adapter over the governed-tool contract, with read-only/user-scoped integration first and broad remote write surfaces deferred.

**Milestone progress:**
- ✓ Phase 13 (Governed Tool Contract & Proposal Records) complete on 2026-05-24 — the single native governed-tool contract (compile-time-validated `Tool.Spec` + behaviour), durable `ToolProposal` + append-only `ToolActionEvent` records, and the fail-closed `Cairnloop.Governance` propose/validate facade (with a `Policy.resolve/3` approval seam) now exist; Cairnloop creates proposals without executing tools inline.

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
- [x] Define the governed-tool contract, policy seam, and durable execution records for host-owned support actions. — validated in Phase 13 (vM011)
- [ ] Replace synchronous in-LiveView tool execution with fail-closed proposal, approval, and Oban resume flow.
- [ ] Keep tool actions grounded, reviewable, and visible in the existing operator workflow rather than introducing a parallel truth source.
- [ ] Expose MCP compatibility only through the governed-tool seam, starting with optional read-only and user-scoped integration.

## Validated Requirements

- vM010 validated `GAP-01` through `GAP-03`: retrieval and manual-handling evidence now converge into ranked, inspectable KB gap candidates.
- vM010 validated `DRAFT-01` through `DRAFT-03`: article and revision suggestions are citation-backed and fail closed when grounding is weak.
- vM010 validated `REVIEW-01` through `REVIEW-03`: review tasks now own decision, publish, and follow-through workflow state.
- vM010 validated `OPS-01` through `OPS-03`: operators can launch quick fixes from threads and maintenance telemetry remains bounded across publish and reindex follow-through.
- vM011 Phase 13 validated `M011-S01-01` through `M011-S01-03`: one native governed-tool contract, durable proposal + append-only action-event records, and the fail-closed `Cairnloop.Governance` facade — proposals are created and fail closed on unsupported tools, missing input, invalid scope, or denied policy, with no inline execution.

### Out of Scope
- Broad external MCP server surface for third-party clients before the internal governed-tool contract is proven.
- High-risk financial or destructive mutations as the first governed-action path.
- Autonomous customer-visible replies or side effects based only on retrieval confidence.
- Treating raw tool output as canonical truth over reviewed Knowledge Base and support evidence.
- Replacing host-owned Phoenix/Ecto/Oban workflow truth with an MCP- or Scoria-owned runtime.

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
*Last updated: 2026-05-24 after completing Phase 13 (vM011)*
