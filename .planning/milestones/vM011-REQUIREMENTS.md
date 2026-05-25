# Requirements Archive: Cairnloop vM011 AI Tool Governance & MCP Integration

**Status:** ✅ ARCHIVED — shipped 2026-05-25
**Defined:** 2026-05-23
**All v1 requirements:** COMPLETE

---

## v1 Requirements (All Satisfied)

### Governed Tool Contract

- [x] **TOOL-01**: Host developer can define a governed support tool with typed input validation, declared risk tier, approval mode, idempotency metadata, and structured result states.
  _→ Validated Phase 13: compile-time-validating `use Cairnloop.Tool` macro with `%Cairnloop.Tool.Spec{}`._
- [x] **TOOL-02**: System can propose a governed tool call from scoped conversation and account context without executing it inline.
  _→ Validated Phase 13: proposal-first `Governance.propose/3`; `execute_tool` never calls `run/3`._
- [x] **TOOL-03**: Governed tool proposal fails closed with explicit `needs_input`, `scope_invalid`, `policy_denied`, or `unsupported` outcomes instead of guessing or widening scope.
  _→ Validated Phase 13: ordered `with` validate/3 pipeline; `ToolRegistry.find_tool_module/1` gate-0._
- [x] **TOOL-04**: Governed tool execution stores durable proposal and execution records plus append-only action events separate from transient UI state.
  _→ Validated Phase 13: `ToolProposal` + `ToolActionEvent` with Stripe-style idempotency and snapshot-at-propose-time._

### Operator Timeline & Review

- [x] **FLOW-01**: Operator can inspect governed action proposals and outcomes inside the existing conversation workflow as a durable timeline.
  _→ Validated Phase 14: "Governed actions" right-rail section via narrow `Governance.list_proposals_for_conversation/1` facade._
- [x] **FLOW-02**: Operator sees a human-readable preview card for each risky action, including risk label, actor scope, target, consequence summary, and evidence links.
  _→ Validated Phase 14: `governed_action_card/1` + `ToolProposalPresenter` + hybrid `Preview.render/1`; no raw Elixir terms._
- [x] **FLOW-03**: Operator can reject or defer a proposed action with a persisted reason that remains visible in the action timeline.
  _→ Validated Phase 15: `reject/3` + `defer/3` require a persisted reason (FLOW-03); visible in approval history timeline._

### Approval & Resume

- [x] **APRV-01**: High-risk or sensitive governed actions create a durable approval record and never execute inside LiveView or a blocked worker process.
  _→ Validated Phase 15: `ToolApproval` record created; `approve/3` enqueues `ApprovalResumeWorker` after persistence — never inline `run/3`._
- [x] **APRV-02**: Approved governed actions resume through a new Oban job that re-validates scope and policy before execution.
  _→ Validated Phase 15: `ApprovalResumeWorker` re-validates via `Governance.validate/3` + lazy `expires_at` guard before enqueuing `ToolExecutionWorker`._
- [x] **APRV-03**: Approval requests can expire or become invalid when policy, actor scope, or action context changes, and the timeline shows that state explicitly.
  _→ Validated Phase 15: `ApprovalExpiryWorker` scheduled `:pending→:expired` flip; lazy expiry guard in resume worker._
- [x] **APRV-04**: System allows only one active approval lane per governed action proposal and records all approval decisions as append-only events.
  _→ Validated Phase 15: partial unique index on `cairnloop_tool_approvals`; all transitions co-commit append-only `ToolActionEvent`._

### First Action Path & Observability

- [x] **ACT-01**: System ships at least one narrow low-blast-radius write workflow after approval, such as adding an internal note, assigning a thread, or creating a follow-up task.
  _→ Validated Phase 16: `Cairnloop.Tools.InternalNote` governed-write tool; `ToolExecutionWorker` is sole `run/3` caller._
- [x] **OBS-01**: System emits bounded telemetry for governed action proposal, approval, execution, and failure outcomes without leaking high-cardinality payload data into metric labels.
  _→ Validated Phase 16: `Cairnloop.Governance.Telemetry` with enum-only event names; emitted after co-commit; no actor_id/payload in labels._
- [x] **OBS-02**: Optional audit/evidence integrations can attribute who approved or denied a governed action and which policy snapshot applied.
  _→ Validated Phase 16: `decided_by`, `policy_snapshot`, per-attempt `ToolActionEvent` trail proven reconstructable from durable records._
- [x] **MCP-01**: Core governed-tool metadata can map cleanly to an optional read-only MCP seam without changing the internal approval and execution model.
  _→ Validated Phase 17: `Cairnloop.Web.MCP.Router` (tools/list + initialize only; -32601 for call) + pure `ToolProjector` (Spec→MCP transform); core truth unchanged._

---

## Traceability Table

| Requirement | Phase | Status |
|-------------|-------|--------|
| TOOL-01 | Phase 13 | ✅ Complete |
| TOOL-02 | Phase 13 | ✅ Complete |
| TOOL-03 | Phase 13 | ✅ Complete |
| TOOL-04 | Phase 13 | ✅ Complete |
| FLOW-01 | Phase 14 | ✅ Complete |
| FLOW-02 | Phase 14 | ✅ Complete |
| FLOW-03 | Phase 15 | ✅ Complete |
| APRV-01 | Phase 15 | ✅ Complete |
| APRV-02 | Phase 15 | ✅ Complete |
| APRV-03 | Phase 15 | ✅ Complete |
| APRV-04 | Phase 15 | ✅ Complete |
| ACT-01 | Phase 16 | ✅ Complete |
| OBS-01 | Phase 16 | ✅ Complete |
| OBS-02 | Phase 16 | ✅ Complete |
| MCP-01 | Phase 17 | ✅ Complete |

**Coverage: 15/15 v1 requirements satisfied.**

---

## v2 Requirements (Deferred to Next Milestone)

- **MCP-02**: Optional remote MCP adapter with user-scoped OAuth and explicit consent flows.
- **MCP-03**: Optional remote MCP write tools participating in approval-gated execution.
- **ACT-02**: Higher-risk financial or destructive mutations after stronger proof, rollback, and coverage exist.
- **FLOW-04**: AI orchestration of multi-step runbooks across several governed tools.

---

_Requirements defined: 2026-05-23_
_Archived: 2026-05-25 — all 15 v1 requirements satisfied across Phases 13–17_
