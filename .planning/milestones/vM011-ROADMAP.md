# Milestone vM011: AI Tool Governance & MCP Integration

**Status:** ✅ SHIPPED 2026-05-25
**Phases:** 13–17
**Total Plans:** 17

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

- [x] M011-S01-01: Extend the tool contract with risk tier, approval mode, idempotency, preview, and structured result metadata.
- [x] M011-S01-02: Add durable proposal, action-event, and run records plus the public governed-action facade.
- [x] M011-S01-03: Replace direct `execute_tool` entrypoints with proposal-first, fail-closed action creation and scope validation.

**Details:**

- Establish one native governed-tool contract that remains host-owned and Elixir-first.
- Persist proposal truth in Ecto records and append-only events instead of LiveView state.
- Fail closed on missing input, invalid scope, unsupported tools, or denied policy before any execution path starts.

**Delivered:**
- Compile-time-validating `use Cairnloop.Tool` macro with risk tiers, approval modes, deny-by-default `authorize/2`, pure `%Cairnloop.Tool.Spec{}` data struct.
- `ToolProposal` + append-only `ToolActionEvent` Ecto records with Stripe-style idempotency and snapshot-at-propose-time.
- Proposal-first `execute_tool` handler; boot-time `validate_configured_tools!()` via `ToolRegistry`.

### Phase 14: Operator Timeline & Preview Surface

**Goal**: Operators can inspect governed action proposals and outcomes inside the existing
conversation workflow with durable timeline and preview semantics.
**Depends on**: Phase 13
**Plans**: 4 plans

Plans:

- [x] 14-00-PLAN.md — Wave 0 test infrastructure.
- [x] 14-01-PLAN.md (M011-S02-01) — conversation_id linkage, `Governance.list_proposals_for_conversation/1`, `ToolProposalPresenter`, total `Preview.render/1`.
- [x] 14-02-PLAN.md (M011-S02-02) — `governed_action_card/1` read-only function component.
- [x] 14-03-PLAN.md (M011-S02-03) — wire into `ConversationLive`: thread conversation_id, governed actions rail, rename Execute→Propose.

**Details:**

- Keep the operator experience inside the current in-thread workflow.
- Render human-readable approval cards instead of raw JSON payloads.
- Hybrid preview: snapshotted trust facts + best-effort live interpretive prose behind a total fallback.
- Brand tokens, no raw Elixir terms, no color-alone state.

### Phase 15: Approval State Machine & Oban Resume

**Goal**: Risky governed actions move through durable approval, rejection, deferral, expiry, and
resume paths with append-only decision history.
**Depends on**: Phase 14
**Plans**: 5 plans

Plans:

- [x] 15-00-PLAN.md — Wave 0 test infrastructure.
- [x] 15-01-PLAN.md (M011-S03-01) — `ToolApproval` storage + one-active-lane partial unique index + `get_active_approval/1`; D15-14 prose snapshot; D15-15/WR-01 humanization.
- [x] 15-02-PLAN.md (M011-S03-03) — `ApprovalResumeWorker` + `ApprovalExpiryWorker` + `Policy.resolve/3` PDP seam.
- [x] 15-03-PLAN.md (M011-S03-02) — approve/reject/defer/expire transitions on the narrow facade (guarded on `:pending`, append-only co-commit, FLOW-03 reason-required).
- [x] 15-04-PLAN.md (M011-S03-04) — reflect outcomes into in-thread surface: presenter maps approval states, footer-slot Approve/Reject/Defer with brand tokens.

**Details:**

- Approval is durable workflow truth, not a blocked process or LiveView-only prompt.
- Resume always happens through a new Oban job after re-validation.
- DB-backed integration test harness added; 4 former Manual-Only items shifted left to automated proof.

### Phase 16: First Approved Write Path & Telemetry

**Goal**: Cairnloop proves one narrow low-blast-radius write action after approval while keeping
execution inspectable, grounded, and operationally bounded.
**Depends on**: Phase 15
**Plans**: 3 plans

Plans:

- [x] 16-01-PLAN.md (M011-S04-01) — `ToolExecutionWorker` (sole `run/3` caller), `Cairnloop.Tools.InternalNote`, `execute_approved/2` facade.
- [x] 16-02-PLAN.md (M011-S04-03 + OBS-01) — three-layer at-most-once hardening, bounded `Cairnloop.Governance.Telemetry` execution events, transient/terminal retry semantics.
- [x] 16-03-PLAN.md (M011-S04-02 + OBS-02) — operator-surface reflection: presenter `:executed`/`:execution_failed` chips, thin-PubSub plain-assign reload, OBS-02 attribution-reconstructable proof.

**Details:**

- Three-layer at-most-once: Oban unique + terminal guard + SHA-256 per-attempt run key.
- Bounded telemetry with enum-only labels; no high-cardinality payload data in metric labels.

### Phase 17: Optional Evidence Lane & Read-Only MCP Seam

**Goal**: The internal governed-action contract can project into optional evidence adapters and a
read-only MCP seam without changing core approval or execution truth.
**Depends on**: Phase 16
**Plans**: 2 plans

Plans:

- [x] M011-S05-01-PLAN.md — Evidence lane: `Cairnloop.Governance.Telemetry.Traces` OI-conformant trace module + 7 additive emit call sites.
- [x] M011-S05-02-PLAN.md — Read-only MCP seam: `ToolRegistry.list_all_tools/0` + `Cairnloop.Web.MCP.ToolProjector` + `Cairnloop.Web.MCP.Router` optional Plug.

**Details:**

- OI-conformant trace module with 12-atom event registry, span-kind routing, payload-content exclusion; zero Scoria dependency.
- MCP Router: `tools/list` + `initialize` only; `-32601` for all write/call methods; pure `Spec→MCP` transform.

---

## Milestone Summary

**Key Decisions:**

- Keep workflow truth in Phoenix, Ecto, and Oban; LiveView reflects durable state rather than owning action execution.
- Reuse retrieval and existing review/audit patterns so tool actions stay grounded and inspectable in-thread.
- Delay the first write workflow until contract, timeline, and approval-resume machinery already exist.
- Treat Scoria as an optional evidence lane and MCP as an optional edge adapter, not the milestone's center.
- D15-14: propose/3 snapshots prose at propose time; approval/execution surfaces read snapshotted columns (never live `Preview.render`).
- Three-layer at-most-once execution: Oban unique + terminal guard + SHA-256 per-attempt run key (D16-05).
- Telemetry emitted AFTER co-commit with pipeline, never inside clause list; no actor_id/conversation_id/reason in labels (OBS-01).

**Issues Addressed:**

- The former synchronous `execute_tool` path had no durable approval, resume, or structured policy model.
- Tool execution now has richer metadata, explicit risk tiers, and fail-closed structured outcomes.
- Operator review for actions lives in the same support workflow as the rest of Cairnloop's trust model.
- MCP has a clean integration seam without becoming the internal workflow architecture.

**Issues Deferred:**

- Broad remote MCP server/client surface.
- MCP write actions and third-party protocol-led expansion.
- High-risk financial or destructive mutations.
- Any design where tool output becomes canonical truth over retrieval-backed KB/support evidence.

**Technical Debt Incurred:**

- Root `SECURITY.md` is Phase 10's verification and still carries 5 open threats (T-10-09..T-10-13) — pre-existing vM010 debt.
- AR-14-02: governed-actions rail has no pagination; re-evaluate at next write-action milestone when proposal volume grows.
- `REPO-UNAVAILABLE`: DB round-trip proofs remain MockRepo/fixture-covered; integration harness available for live proof when needed.

---

_For current project status, see .planning/ROADMAP.md_
_Archived: 2026-05-25_
