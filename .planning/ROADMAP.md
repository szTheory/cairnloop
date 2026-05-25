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
**Plans**: 4 plans

Plans:

**Wave 1**

- [x] 14-00-PLAN.md — Wave 0 test infrastructure: 2 new headless test files (`preview_test.exs`, `tool_proposal_presenter_test.exs`) + 2 extensions (`governance_test.exs`, `conversation_live_test.exs`).
- [x] 14-01-PLAN.md (M011-S02-01) — conversation_id linkage (migration/schema/both write paths/idempotency exclusion), `Governance.list_proposals_for_conversation/1`, `ToolProposalPresenter`, total `Preview.render/1` + Phase-15 guardrail.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 14-02-PLAN.md (M011-S02-02) — `governed_action_card/1` read-only function component (status chip color+text, separate risk/approval/status axes, humanized rows, event mini-timeline, empty Phase-15 footer slot).

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 14-03-PLAN.md (M011-S02-03) — wire into `ConversationLive`: thread conversation_id, assign `governed_actions`, render the "Governed actions" rail section (no streams), rename Execute→Propose + brand token, replace `inspect(reason)` with `reason_label/1`.

**Details:**

- Keep the operator experience inside the current in-thread workflow rather than inventing a second tool console.
- Render human-readable approval cards instead of raw JSON payloads.
- Make pending, blocked, denied, and completed states durable and visible.

### Phase 15: Approval State Machine & Oban Resume

**Goal**: Risky governed actions move through durable approval, rejection, deferral, expiry, and
resume paths with append-only decision history.
**Depends on**: Phase 14
**Plans**: 5 plans

Plans:

**Wave 0**

- [x] 15-00-PLAN.md — Wave 0 test infrastructure: 3 new headless test files (`tool_approval_test.exs`, `approval_resume_worker_test.exs`, `approval_expiry_worker_test.exs`) + 4 extensions (`governance_test.exs`, `tool_action_event_test.exs`, `preview_test.exs`, `tool_proposal_presenter_test.exs`).

**Wave 1** *(blocked on Wave 0 completion)*

- [x] 15-01-PLAN.md (M011-S03-01) — `ToolApproval` storage + one-active-lane partial unique index + `get_active_approval/1`; `ToolActionEvent`/`ToolProposal` extensions; the sanctioned `propose/3` reopen (D15-14 prose snapshot + D15-15/WR-01 humanization).

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 15-02-PLAN.md (M011-S03-03) — Oban `ApprovalResumeWorker` (re-validate-before-execute gate → `:execution_pending` seam, never `run/3`; lazy expiry guard; idempotent/double-enqueue-safe) + `ApprovalExpiryWorker` scheduled flip + `Policy.resolve/3` PDP seam.

**Wave 3** *(blocked on Waves 1-2 completion)*

- [x] 15-03-PLAN.md (M011-S03-02) — approve/reject/defer/expire transitions on the narrow facade (guarded on `:pending`, append-only co-commit, FLOW-03 reason-required, approve enqueues resume — never inline execute) + `request_approval` lane open with host-configurable TTL.

**Wave 4** *(blocked on Waves 1, 3 completion)*

- [x] 15-04-PLAN.md (M011-S03-04) — reflect outcomes into the in-thread surface: presenter maps approval states into the existing four groups (zero relabeling), `approval_outlook` → real "Pending approval", footer-slot Approve/Reject/Defer (color+text, brand tokens), snapshot-read card (never live `Preview.render`), plain-assign reload (no streams).

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

**Wave 1**

- [ ] 16-01-PLAN.md (M011-S04-01, ACT-01) — first approved write path: `ToolExecutionWorker` (only place `run/3` is called), example `Cairnloop.Tools.InternalNote` low-write tool, terminal statuses `:executed`/`:execution_failed` + execution event types + reserved-column population, `Governance.execute_approved/2` facade transition, additive resume-worker enqueue, Wave 0 integration scaffold.

**Wave 2** *(blocked on Wave 1 completion; 16-02 and 16-03 run in parallel — disjoint files)*

- [ ] 16-02-PLAN.md (M011-S04-03 + OBS-01, ACT-01/OBS-01) — three-layer at-most-once hardening (Oban unique + terminal guard + deterministic run-level idempotency key), transient/terminal retry semantics with per-attempt events, bounded `Cairnloop.Governance.Telemetry` execution events (enum-only labels), DB-backed at-most-once/retry/idempotency proof + headless telemetry-bounding proof.
- [ ] 16-03-PLAN.md (M011-S04-02 + OBS-02) — operator-surface reflection: presenter `:executed`/`:execution_failed` chips (humanized, brand-token, never color-alone) into the existing four groups, ConversationLive thin-PubSub plain-assign reload (no streams), DB-backed OBS-02 attribution-reconstructable-from-durable-records proof + automated rendered-outcome (chip) proof.

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
