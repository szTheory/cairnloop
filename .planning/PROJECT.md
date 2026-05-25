# Cairnloop Project

## What This Is
An embedded, Phoenix-native customer support automation layer that turns support conversations into answers, product signals, knowledge-base improvements, and safe governed actions inside the host app.

## Core Value
Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.

## Current Milestone: vM012 Public Release & MCP Write Surface

**Goal:** Ship Cairnloop's first public Hex.pm release, close the adopter demo gap with a runnable example app, then extend the proven governed-tool contract with MCP write surfaces and OAuth.

**Target features:**
- Release gate + Hex.pm publish — CI-clean v0.1.0 tag, CHANGELOG, and first hex.pm publish (⚠️ hard June 2, 2026 CI deadline)
- Example Phoenix app — Runnable `mix setup` → seed → draft/approval/KB flow demo (biggest adopter gap)
- MCP OAuth seam (MCP-02) — Remote OAuth over MCP, host-controlled token delegation
- MCP write tools (MCP-03 / ACT-02) — Write-capable MCP tools with full governed-action approval flow

## Current State

**Latest shipped milestone:** `vM011 AI Tool Governance & MCP Integration` on 2026-05-25.

**What is now true:**
- Cairnloop has a host-owned hybrid retrieval layer over published Knowledge Base content and resolved support evidence.
- Operators have a retrieval-backed `cmd+k` search flow with explicit source, recency, trust, and citation cues.
- Durable gap signals now project into a ranked KB maintenance queue with inspectable evidence and stable candidate identity.
- AI-prepared article and revision suggestions are citation-backed, inspectable, and fail closed when evidence or grounding is insufficient.
- KB review now runs through durable review tasks with explicit approve, reject, defer, publish, and reindex follow-through states.
- Operators can launch maintenance directly from conversation context without creating a second workflow surface outside the shared review lane.
- Cairnloop has a host-owned governed-tool contract (`use Cairnloop.Tool`) with compile-time validation, risk tiers, approval modes, and durable `ToolProposal` + append-only `ToolActionEvent` records.
- Governed action proposals are fail-closed on unsupported tools, missing input, invalid scope, or denied policy — never execute inline.
- Operators see humanized in-thread governed action cards with snapshotted trust facts, risk/approval-mode chips, and a hybrid preview surface; raw Elixir terms and color-alone state are kept off the operator surface.
- Risky actions move through a durable `ToolApproval` state machine (approve / reject / defer / expiry / resume) with one-active-lane invariant and append-only decision history; resume re-validates via Oban before execution.
- First narrow approved write path is proven: `ToolExecutionWorker` (sole `run/3` caller) with three-layer at-most-once idempotency and bounded `[:cairnloop, :governance, ...]` telemetry.
- An optional OpenInference-conformant evidence lane and read-only MCP seam (`tools/list` + `initialize`) exist as additive adapters; core approval and execution truth is unchanged.

**Current milestone:** vM012 — "Public Release & MCP Write Surface" — started 2026-05-25.

**Why now:** The governed-action contract, durable approval workflow, and MCP seam are all proven. Adopter-first assessment (2026-05-25) identified two critical gaps: no runnable example app, and the package is unpublished (hex.pm 404). vM012 closes both, then adds MCP write surfaces (the one meaningful new feature wedge). After that: diminishing returns — assess real adoption signals before expanding further.

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
- ✓ Governed tool contract with risk tiers, approval modes, idempotency, and fail-closed proposal pipeline — vM011 (TOOL-01 through TOOL-04)
- ✓ Durable in-thread operator action timeline with humanized preview cards and snapshotted trust facts — vM011 (FLOW-01, FLOW-02)
- ✓ Approval state machine (approve/reject/defer/expiry/resume) with append-only decision history and Oban re-validate-before-execute resume — vM011 (FLOW-03, APRV-01 through APRV-04)
- ✓ First narrow approved write path with three-layer at-most-once idempotency and bounded telemetry — vM011 (ACT-01, OBS-01, OBS-02)
- ✓ Optional read-only MCP seam over governed-tool contract — vM011 (MCP-01)

### Active (vM012)
- [ ] **REL-01** — CI green on main (integration + standard jobs)
- [ ] **REL-02** — CHANGELOG.md covers vM009–vM012 with dates and feature summaries
- [ ] **REL-03** — v0.1.0 semver tag created and pushed
- [ ] **REL-04** — Package metadata complete (description, links, licenses, maintainers)
- [ ] **REL-05** — Package published to hex.pm (cairnloop available at hex.pm/packages/cairnloop)
- [ ] **REL-06** — ExDoc API docs generated and published to hexdocs.pm
- [ ] **DEMO-01** — Runnable example Phoenix app with `mix setup` + seed script
- [ ] **DEMO-02** — Example app demonstrates draft/approval/KB flow end-to-end
- [ ] **DEMO-03** — Example app README documents configuration and integration
- [ ] **DEMO-04** — Example app references library via published hex dependency
- [ ] **MCP-02** — MCP server supports OAuth 2.0 authorization code flow, host-controlled token delegation
- [ ] **MCP-03** — OAuth token lifecycle (issue, validate, revoke) durable and Ecto-backed; unauthorized requests return 401/403
- [ ] **ACT-02** — MCP clients can invoke write-capable governed tools via MCP; invocations flow through full governed-action approval pipeline

### Out of Scope
- Broad external MCP server surface for third-party clients before the internal governed-tool contract is proven. _(MCP-02 now a candidate for next milestone — internal contract is proven.)_
- High-risk financial or destructive mutations as the first governed-action path.
- Autonomous customer-visible replies or side effects based only on retrieval confidence.
- Treating raw tool output as canonical truth over reviewed Knowledge Base and support evidence.
- Replacing host-owned Phoenix/Ecto/Oban workflow truth with an MCP- or Scoria-owned runtime.

## Key Decisions

| Decision | Milestone | Outcome |
|----------|-----------|---------|
| Workflow truth in Phoenix/Ecto/Oban; LiveView reflects state, never owns execution | vM011 | ✓ Good — consistently delivered across 5 phases |
| Sequence: contract → timeline → approvals → narrow write → optional MCP seam | vM011 | ✓ Good — late phases were additive without reopening earlier work |
| Hybrid preview: snapshot trust facts at propose time; interpretive prose best-effort live behind total fallback | vM011 | ✓ Good — D15-14 discharged cleanly in Phase 15 |
| Three-layer at-most-once execution: Oban unique + terminal guard + SHA-256 per-attempt run key | vM011 | ✓ Good — DB-backed proof added to integration harness |
| DB-backed integration test harness added (docker-compose + pgvector + DataCase/ConnCase) | vM011 | ✓ Good — shifted 4 former Manual-Only items to automated proof |
| MCP as read-only edge adapter, not internal execution model | vM011 | ✓ Good — additive, zero core truth changes |
| Keep MCP write surfaces and remote OAuth for next milestone | vM011 | — Pending — next milestone decision |

## Context

**Codebase at vM011:** ~15,389 LOC Elixir / Phoenix / LiveView / Ecto / Oban.
**Tech stack:** Elixir, Phoenix LiveView, Ecto (PostgreSQL + pgvector), Oban, OpenInference telemetry.
**Integration test harness:** `MIX_ENV=test mix test.integration` against dockerized Postgres; fast headless `mix test` remains DB-free.

**Known tech debt:**
- Root `SECURITY.md` carries 5 open threats (T-10-09..T-10-13) from vM010 — pre-existing, untouched by vM011.
- AR-14-02: governed-actions rail has no pagination — re-evaluate when write-action volume grows.
- Centralize duplicated fail-closed search guards (pre-existing from vM009).

## Previous Milestone Brief

<details>
<summary>Archived vM011 brief</summary>

### vM011 AI Tool Governance & MCP Integration

**Goal:** Extend the M009-M010 trust model with a host-owned governed-action lane.

**Target features:**
- Introduce a durable governed-action workflow for typed host-owned tools.
- Add policy-gated approval and resume mechanics using Ecto and Oban instead of synchronous LiveView execution.
- Reuse retrieval, review, telemetry, and audit primitives so tool actions stay grounded and fail closed.
- Define MCP as an optional edge adapter with read-only/user-scoped integration first.

**Shipped 2026-05-25 — all 15 v1 requirements satisfied across Phases 13–17.**

</details>

<details>
<summary>Archived vM010 brief</summary>

### vM010 KB AI Maintenance

**Goal:** Turn retrieval misses, weak grounding, and repeated manual handling into a safe
Knowledge Base maintenance workflow.

**Shipped 2026-05-23.**

</details>

<details>
<summary>Archived vM009 brief</summary>

### vM009 Retrieval-First Support Answers & Search Ops

**Goal:** Turn the Knowledge Base substrate into visible operator and AI value through grounded
retrieval, trustworthy search, and measurable answer quality.

**Shipped 2026-05-21.**

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
*Last updated: 2026-05-25 — vM012 milestone started*
