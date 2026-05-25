# Phase 16: First Approved Write Path & Telemetry - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-25
**Phase:** 16-first-approved-write-path-telemetry
**Areas discussed:** First write action (the one escalated, owner-confirmed call)

**Calibration:** owner profile `opinionated` → advisor tier `minimal_decisive`;
`technical_background: true` → `NON_TECHNICAL_OWNER = false`. Repo CLAUDE.md shift-left policy +
the discuss-phase note ("surface at most the single genuinely VERY-impactful call; auto-decide the
rest with recorded rationale") governed the interaction: I deep-researched all gray areas, decided
all but one, and surfaced only the marquee scope-shaping deliverable for confirmation.

---

## First write action (ACT-01)

| Option | Description | Selected |
|--------|-------------|----------|
| Internal note | Append an internal, operator-only note to the conversation after approval. Lowest blast radius, append-only, trivially idempotent via the run-level key, no host identity/routing model needed, never customer-visible. Ships as a copyable example governed-write tool; proven via the Phase 15 DB integration harness. | ✓ |
| Thread assignment | Set the conversation's assignee (`host_user_id`) after approval. Mutates routing state, last-write-wins (less append-only / harder to make cleanly idempotent), leans on a host user model Cairnloop doesn't own. Higher blast radius. | |
| Follow-up task | Create a follow-up task after approval. No host task table exists — requires new storage + schema; pulls scope toward infra the milestone defers. | |

**User's choice:** Internal note (the recommended default).
**Notes:** Confirmed without redirection. Locks D16-01/D16-02 (example `Cairnloop.Tools.InternalNote`
governed-write tool, `:low_write` → `:requires_approval`, writing an internal-note row to the host
`cairnloop_messages` store via the configured repo, idempotent on the run-level key).

---

## Claude's Discretion

Auto-decided per shift-left policy (recorded in CONTEXT.md `<decisions>` D16-03..D16-14, owner can
veto cheaply):

- **Execution architecture (D16-03/04):** new dedicated `ToolExecutionWorker`; resume worker
  enqueues it at `:execution_pending`; resume never calls `run/3` (sealed contract intact).
- **Idempotency / safety (D16-05/06):** at-most-once — Oban job uniqueness + `result_state`
  pre-execution guard + run-level key passed to `run/3`; re-validate `validate/3` + lazy expiry
  before each attempt.
- **Failure / retry (D16-07):** transient `{:error,_}` → Oban backoff retry (host-configurable
  bounded `max_attempts`); permanent → terminal `:execution_failed`, no retry.
- **Outcome states / durable truth (D16-08):** extend `ToolApproval` with `:executed` /
  `:execution_failed`; populate reserved `ToolProposal` columns; per-attempt `ToolActionEvent`s; no
  separate `ToolRun` table.
- **OBS-02 (D16-09):** attribution reconstructable from durable records; no evidence adapter
  (Phase 17).
- **Telemetry (D16-10):** extend bounded `Governance.Telemetry`; `:action_executed`/`:action_failed`;
  enum-bounded labels only; no high-cardinality payload in labels.
- **Operator surface (D16-11):** new states into existing four groups, zero relabeling, failure chip
  color+text; snapshot-read; existing reload path.
- **Streams (D16-12):** P14 D-02 trigger evaluated → keep plain-assign reload, no
  `Phoenix.LiveView.stream/3` this phase.
- **Proof (D16-14):** merge-blocking write/idempotency/retry proof via the Phase 15 integration
  harness (`mix test.integration`); headless `mix test` stays DB-free.

## Deferred Ideas

- Auto (`:auto` / read-only) execution — build worker forward-compatibly, keep phase on approved-write proof.
- Scoria/evidence adapter + read-only MCP seam — Phase 17.
- `Phoenix.LiveView.stream/3` — re-evaluate only under real-host volume pressure.
- `:destructive` / high-risk / financial writes, rollback, multi-step runbooks (FLOW-04) — past vM011.
- Four-eyes / segregation-of-duties enforcement — host policy hook only.
- A second governed write tool / broad catalog — future work once the lane is proven.
