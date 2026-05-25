# Phase 15: Approval State Machine & Oban Resume - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-24
**Phase:** 15-approval-state-machine-oban-resume
**Mode:** Shift-left auto-decide (repo CLAUDE.md decision policy + GSD discuss-phase note:
"surface at most the single genuinely VERY-impactful call, if any; auto-decide the rest with
recorded rationale"). The orchestrator researched the phase deeply (PROJECT/REQUIREMENTS/STATE/
ROADMAP, Phase 13 & 14 CONTEXT, `governance.ex`/`policy.ex`/`tool_proposal.ex`/`tool_action_event.ex`/
`preview.ex`, `review_task.ex` + transitions, `sla_countdown_worker.ex`, `application.ex`), found
the phase **exceptionally well-seamed by Phases 13–14** with **no genuinely VERY-impactful open
call**, auto-decided all gray areas, and presented them for a single ratify-or-veto gate.

**Areas analyzed:** State model & records, Approval triggering/decisions/attribution, Resume &
re-validation, Expiry, Carried guardrails (D-16 prose snapshot + WR-01 changeset humanization), UI
reflection.

**User decision:** Ratified the full decision set (D15-01..18, including all 3 flagged calls) and
authorized writing CONTEXT.md.

---

## State model & durable records

| Option | Description | Selected |
|--------|-------------|----------|
| ToolApproval mirrors ReviewTask (own lifecycle status + denormalized last-decision + reuse ToolActionEvent timeline) | Honors P13 D-23 (lifecycle on ToolApproval, not ToolProposal columns); one audit timeline; in-repo idiom | ✓ |
| Approval lifecycle as new ToolProposal.status values | Single status surface, but contradicts P13 D-23 and fuses creation-outcome with approval axis | |
| Separate ToolApprovalEvent table | Strict ReviewTask 1:1 parity, but forks a second timeline the Phase 14 card doesn't render | |

**Decision:** D15-01..04 — `ToolApproval` mirrors `ReviewTask`; reuse the single `ToolActionEvent`
table (extend event types); one-active-lane via partial unique index on `tool_proposal_id WHERE
status = :pending`.
**Notes:** Phase 14's `history_line/1` catch-all was added specifically so Phase 15/16 event types
render in the one timeline — strong signal toward reuse. `ToolProposal.status` stays unchanged.

---

## Resume worker scope (FLAGGED)

| Option | Description | Selected |
|--------|-------------|----------|
| Re-validate, stop at execution-pending seam (no run/3) | Phase-15 deliverable is the re-validate-before-execute gate; execution = Phase 16's worker success branch | ✓ |
| Wire a no-op/dry-run execution path in Phase 15 | Blurs the milestone's deliberate phasing; risks premature execution surface | |

**Decision:** D15-10 — resume worker re-calls `validate/3` + `Policy.resolve/3`; does NOT call
`run/3`. Flagged as a scope boundary; ratified.
**Notes:** Consistent with propose→display→approve/resume→execute phasing. Mirrors Terraform
"stale plan" (re-check only at apply) / CloudFormation change-set OBSOLETE-at-execute.

---

## Carried guardrails — reopening propose/3 (FLAGGED)

| Option | Description | Selected |
|--------|-------------|----------|
| Honor D-16 + fix WR-01 in one additive propose/3 reopen | Both prior phases anticipated this reopen; snapshot prose columns + humanize blocked reason; add divergence + no-`#Ecto.Changeset<` tests | ✓ |
| Defer WR-01 / live-render prose on approval card | Violates the ratified P14 D-16 guardrail and leaks raw changeset terms to operators | |

**Decision:** D15-14/15 — add nullable `rendered_consequence`/`title`, populate in `propose/3`,
approval surfaces read snapshotted columns (never live `Preview.render`); replace `inspect(reason)`
with `Ecto.Changeset.traverse_errors`. Flagged (touches sealed Phase-13 code) but mandated.
**Notes:** The D-16 guardrail is written into `Governance.Preview`'s `@moduledoc` as the
discoverable marker — confirms intent. Sanctioned additive work, not churn.

---

## Approval attribution / four-eyes (FLAGGED)

| Option | Description | Selected |
|--------|-------------|----------|
| No enforcement; offer approver≠proposer as a host policy hook | Cairnloop has no identity/role model (host owns identity); enforcing would be infeasible scope creep | ✓ |
| Enforce four-eyes in Phase 15 | Requires an actor/role model that doesn't exist; not in requirements | |

**Decision:** D15-08 — capture `decided_by`/`decided_at`; segregation-of-duties is a host policy
hook via `Policy.resolve/3` / `authorize/2`, not enforced. Flagged; ratified.

---

## Expiry mechanics

| Option | Description | Selected |
|--------|-------------|----------|
| `expires_at` + scheduled Oban flip + lazy `expires_at < now` guard (defense-in-depth) | Fail-closed even if the sweep never runs; SlaCountdownWorker flip idiom | ✓ |
| Scheduled Oban flip only | A missed/un-run sweep could let a stale approval execute | |
| Lazy guard only | No durable "expired" event/state without a read | |

**Decision:** D15-12/13 — both mechanisms; TTL host-configurable with a fail-closed bounded
default (exact value = planner). Re-validation at resume is the real safety; TTL is the bound.

---

## Claude's Discretion

- All names, enum spellings, the partial-unique-index predicate, the TTL default value, event-type
  names, `from_status`/`to_status` handling, `Ecto.Multi` structure, copy wording.
- Whether `:invalidated` and `:expired` are one status or two (must stay operator-legible).
- Whether approval APIs live on `Cairnloop.Governance` directly or a thin `Governance.Approval`
  submodule (one narrow facade either way).

## Deferred Ideas

- Execution (`run/3`) + first approved write path + run-level idempotency + execution telemetry → Phase 16.
- OBS-02 full attribution lineage → Phase 16/17.
- Four-eyes/segregation-of-duties enforcement → host policy hook (not Cairnloop).
- `Phoenix.LiveView.stream/3` for the timeline → re-evaluate Phase 16.
- Pending-too-long notifications/escalation; richer snooze/re-request UX → future enhancements.
- MCP seam / optional Scoria evidence lane → Phase 17.
