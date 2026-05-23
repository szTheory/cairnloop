# Roadmap: Cairnloop

## Milestones

- ✅ **vM010 KB AI Maintenance** - Phases 9-12 (shipped 2026-05-23)
- ✅ **vM009 Retrieval-First Support Answers & Search Ops** - Phases 1-8 (shipped 2026-05-21)
- 🚧 **vM011 AI Tool Governance & MCP Integration** - Phases 13-17 (planned 2026-05-23)

## Active Milestone

### vM011: AI Tool Governance & MCP Integration

**Status:** Planned
**Phases:** 13-17
**Total Plans:** 15

## Overview

vM011 extends the M009-M010 trust model instead of bypassing it. The milestone centers on a
host-owned governed-action lane inside Phoenix, Ecto, and Oban with LiveView as the operator
surface, retrieval as the grounding layer, durable approval state as workflow truth, one narrow
post-approval write path, and MCP only as a late optional read-only seam.

## Phases

### Phase 13: Governed Tool Contract & Proposal Records

**Goal**: Host developers can define governed support tools and Cairnloop can create fail-closed
proposals without executing them inline.
**Depends on**: Phase 12
**Plans**: 3 plans

Plans:

- [ ] M011-S01-01: Extend the tool contract with risk tier, approval mode, idempotency, preview, and structured result metadata.
- [ ] M011-S01-02: Add durable proposal, action-event, and run records plus the public governed-action facade.
- [ ] M011-S01-03: Replace direct `execute_tool` entrypoints with proposal-first, fail-closed action creation and scope validation.

**Details:**

- Establish one native governed-tool contract that remains host-owned and Elixir-first.
- Persist proposal truth in Ecto records and append-only events instead of LiveView state.
- Fail closed on missing input, invalid scope, unsupported tools, or denied policy before any execution path starts.

### Phase 14: Operator Timeline & Preview Surface

**Goal**: Operators can inspect governed action proposals and outcomes inside the existing
conversation workflow with durable timeline and preview semantics.
**Depends on**: Phase 13
**Plans**: 3 plans

Plans:

- [ ] M011-S02-01: Add conversation-scoped governed-action timeline queries and presenter helpers.
- [ ] M011-S02-02: Build preview-card rendering with risk labels, actor scope, consequence text, and evidence links.
- [ ] M011-S02-03: Replace synchronous tool buttons with governed-action timeline cards and proposal-driven affordances in `ConversationLive`.

**Details:**

- Keep the operator experience inside the current in-thread workflow rather than inventing a second tool console.
- Render human-readable approval cards instead of raw JSON payloads.
- Make pending, blocked, denied, and completed states durable and visible.

### Phase 15: Approval State Machine & Oban Resume

**Goal**: Risky governed actions move through durable approval, rejection, deferral, expiry, and
resume paths with append-only decision history.
**Depends on**: Phase 14
**Plans**: 4 plans

Plans:

- [ ] M011-S03-01: Add `ToolApproval` storage, one-active-approval semantics, and public approval APIs.
- [ ] M011-S03-02: Implement approve, reject, defer, and expire transitions with append-only decision events.
- [ ] M011-S03-03: Add Oban resume workers that re-check scope and policy immediately before execution.
- [ ] M011-S03-04: Reflect approval, expiry, and resume outcomes back into the conversation timeline and operator workflow.

**Details:**

- Approval is durable workflow truth, not a blocked process or LiveView-only prompt.
- Resume always happens through a new Oban job after re-validation.
- Actor attribution, reason capture, and expiry semantics remain explicit and reconstructable.

### Phase 16: First Approved Write Path & Telemetry

**Goal**: Cairnloop proves one narrow low-blast-radius write action after approval while keeping
execution inspectable, grounded, and operationally bounded.
**Depends on**: Phase 15
**Plans**: 3 plans

Plans:

- [ ] M011-S04-01: Ship one narrow approved write workflow such as internal note, thread assignment, or follow-up task creation.
- [ ] M011-S04-02: Add bounded governed-action telemetry and align durable action events with audit/evidence seams.
- [ ] M011-S04-03: Add failure, retry, and idempotency protections so the first write path remains low-surprise under replay or worker retries.

**Details:**

- Delay write execution until the contract, timeline, and approval machinery are already proven.
- Keep telemetry low-cardinality and push detailed action truth into durable records.
- Treat this phase as the proof lane for safe side effects, not as the start of broad tool sprawl.

### Phase 17: Optional Evidence Lane & Read-Only MCP Seam

**Goal**: The internal governed-action contract can project into optional evidence adapters and a
read-only MCP seam without changing core approval or execution truth.
**Depends on**: Phase 16
**Plans**: 2 plans

Plans:

- [ ] M011-S05-01: Add optional Scoria/evidence hooks for governed-action traces, policy snapshots, and approval attribution.
- [ ] M011-S05-02: Expose a read-only MCP seam over the governed-tool contract without widening auth or bypassing host-owned workflow truth.

**Details:**

- Keep MCP at the edge and read-only first.
- Preserve the same policy, actor scope, and durable records regardless of whether the seam is used internally or through an optional adapter.

---

## Milestone Summary

**Decimal Phases:**

- None

**Key Decisions:**

- Keep workflow truth in Phoenix, Ecto, and Oban; LiveView reflects durable state rather than owning action execution.
- Reuse retrieval and existing review/audit patterns so tool actions stay grounded and inspectable in-thread.
- Delay the first write workflow until contract, timeline, and approval-resume machinery already exist.
- Treat Scoria as an optional evidence lane and MCP as an optional edge adapter, not the milestone’s center.

**Issues Addressed:**

- The current synchronous `execute_tool` path has no durable approval, resume, or structured policy model.
- Tool execution needs richer metadata, explicit risk tiers, and fail-closed structured outcomes.
- Operator review for actions should live in the same support workflow as the rest of Cairnloop’s trust model.
- MCP needs a clean integration seam without becoming the internal workflow architecture.

**Issues Deferred:**

- Broad remote MCP server/client surface.
- MCP write actions and third-party protocol-led expansion.
- High-risk financial or destructive mutations.
- Any design where tool output becomes canonical truth over retrieval-backed KB/support evidence.

---

_For current project status, see `.planning/STATE.md`_
