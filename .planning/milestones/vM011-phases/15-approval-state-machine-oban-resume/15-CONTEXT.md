# Phase 15: Approval State Machine & Oban Resume - Context

**Gathered:** 2026-05-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Give risky governed actions a **durable approval lane**: an action whose resolved
`approval_mode` is `:requires_approval` opens an approval record that an operator can
**approve, reject, or defer (with a persisted reason)**, that **expires** when it sits too
long or when policy/scope/context changes, and that — once approved — **resumes through a new
Oban job which re-validates scope and policy immediately before execution**. Every decision is
captured as append-only history and reflected back into the in-thread operator timeline.

This phase covers requirements **FLOW-03, APRV-01, APRV-02, APRV-03, APRV-04** and the plans
**M011-S03-01..04** (ToolApproval storage + one-active-lane + approval APIs; approve/reject/
defer/expire transitions with append-only events; Oban resume worker with re-validation;
timeline reflection of approval/expiry/resume outcomes).

It does **NOT** build:
- **Actual execution** — `run/3` is never called; the resume worker re-validates and stops at an
  execution-pending seam. The first approved write path + run-level idempotency + execution
  telemetry land in **Phase 16**.
- **Bounded execution telemetry alignment / OBS-02 attribution lineage** — Phase 16.
- **The MCP seam / optional evidence lane** — Phase 17.
- **Four-eyes / RBAC** — Cairnloop has no identity/role model (host owns identity); offered only
  as a host policy hook, not enforced (D15-08).
- **`Phoenix.LiveView.stream/3`** — still plain-assign reload; re-evaluate at Phase 16 (P14 D-02).

This phase is **exceptionally well-seamed** by Phases 13–14: the pure re-callable
`Governance.validate/3` pipeline (P13 D-15), the `Policy.resolve/3` PDP seam (P13 D-12), the
ReviewTask append-only transition idiom (P13 D-20), the reserved `:pending_approval` posture on
a *separate* `ToolApproval` record (P13 D-23), the Awaiting/Blocked/Active/Done display groups +
`approval_outlook/1` honesty seam + footer action slot (P14 D-10/D-12/D-05), and the two carried
guardrails below all exist for exactly this work. Decisions were auto-decided per the repo's
shift-left policy; no genuinely VERY-impactful open call surfaced. Exact names, enum spellings,
index predicates, the TTL default value, `event_type` names, `from_status`/`to_status` handling,
and `Ecto.Multi` structure are the planner's discretion as long as the shapes and trust
boundaries below hold (P13 D-31 / P14 D-27).

</domain>

<decisions>
## Implementation Decisions

### State model & durable records (APRV-04, M011-S03-01/02)

- **D15-01:** Add a new durable `ToolApproval` record that **mirrors the `ReviewTask` idiom
  exactly** — its own denormalized lifecycle `status` enum, denormalized last-decision fields
  (`decided_by`/`last_decision`/`decided_at`/`reason`, cf. ReviewTask `last_actor_id`/
  `last_decision`/`last_decided_at`/`notes`), and transitions co-committed with an append-only
  event in one `Ecto.Multi`. The approval lifecycle lives **on `ToolApproval`**, **not** as new
  values on `ToolProposal.status` (honors P13 **D-23**). `belongs_to(:tool_proposal)`;
  `has_one(:approval)` (or `has_many` + active-lane query) on `ToolProposal`.
- **D15-02:** Approval status axis ≈ `[:pending, :approved, :rejected, :deferred, :expired,
  :invalidated]` (planner may refine names). **Keep states distinct — never collapse into a
  generic "done"** (P13 D-23 / P12 D-17). `ToolProposal.status` is **unchanged** (stays the
  creation-outcome enum `[:proposed, :needs_input, :scope_invalid, :policy_denied]`).
  `:invalidated` vs `:expired` may merge if the planner finds the distinction noise — but the
  operator must be able to tell "timed out" from "policy/scope changed under it."
- **D15-03:** **Reuse the single `ToolActionEvent` append-only table** for approval transitions
  (extend `@event_type_values` with e.g. `:approval_requested`, `:approved`, `:rejected`,
  `:deferred`, `:expired`, `:invalidated`, `:resume_scheduled`, `:revalidation_failed`). This
  keeps **one** operator timeline per proposal — exactly what the Phase 14 card renders via
  `list_events/1`, and why P14 D-24 already added the `history_line/1` catch-all. **Do NOT fork a
  second approval-events table.** Planner decides how to record the approval-status transition in
  the event (widen `from_status`/`to_status` to a proposal+approval union enum, **or** leave them
  nil and carry the transition in `event_type` + `metadata`) — as long as every transition stays
  reconstructable from the durable trail.
- **D15-04:** One-active-lane (APRV-04): enforce via a **partial unique index** on
  `tool_proposal_id WHERE status = :pending` (at most one active approval per proposal). A
  terminal decision (rejected/deferred/expired/invalidated) may open a fresh lane later, but only
  one is ever active. All decisions are append-only events; the active lane is the only mutable
  surface.

### Approval triggering, decisions & attribution (FLOW-03, APRV-01)

- **D15-05:** An approval lane opens **iff** the resolved `approval_mode == :requires_approval`
  (P13 D-10). `:auto` opens no lane (proceeds toward execution in Phase 16, still durably
  recorded). `:always_block` never opens a lane (terminal `:policy_denied`). Locked upstream.
- **D15-06:** Approve / Reject / Defer are **durable decisions** written from the LiveView
  footer-slot affordances. Approve writes the decision record + event **and enqueues the Oban
  resume job**; it **never executes inline** (APRV-01 — no blocking LiveView, no blocked worker
  process). The handler returns/persists state so the rail reflects it via the existing reload
  path.
- **D15-07:** **Reject and Defer REQUIRE a persisted, operator-visible reason** (FLOW-03) that
  remains visible in the action timeline. Capture `decided_by` (host-supplied actor) + `decided_at`
  on every decision (ReviewTask `last_*` denormalization idiom). Approve may carry an optional note.
- **D15-08:** **[FLAGGED — ratified]** No four-eyes / segregation-of-duties enforcement in Phase
  15. Cairnloop has no identity/role model (the host supplies `actor_id`/approver identity), so
  "approver ≠ proposer" is **offered as a host policy hook** via the existing `Policy.resolve/3` /
  per-tool `authorize/2` deny-by-default seam — not enforced by Cairnloop. Deferred as a host
  policy concern.

### Resume & re-validation (APRV-02, M011-S03-03)

- **D15-09:** Resume is a **new Oban worker** that mirrors the in-repo worker idiom
  (`SlaCountdownWorker`: `use Oban.Worker, queue: :default`, `perform/1` on `%Oban.Job{args: ...}`,
  `Application.fetch_env!(:cairnloop, :repo)` indirection). **Cairnloop is a host-owned library —
  the host runs the Oban runtime**; the library only `Oban.insert/1`s jobs (cf. `application.ex`,
  which supervises no Oban and wraps `Oban.insert` in `try/rescue`). Plan for: job uniqueness
  keyed on the approval/proposal, and tolerance for the host not having Oban configured in this
  workspace (Repo-unavailable caveat).
- **D15-10:** **[FLAGGED — ratified]** The Phase 15 resume worker **re-calls the pure
  `Governance.validate/3` pipeline + `Policy.resolve/3` against CURRENT context** (re-validation is
  free by construction — P13 D-15) and, on pass, transitions to an **execution-pending seam state**
  + emits an event. It **does NOT call `run/3`** — actual execution is the explicit **Phase 16**
  seam (the worker's success branch). The valuable, testable Phase-15 deliverable is the
  re-validate-before-execute gate (the rubric's "double-check policy proof"), consistent with the
  milestone's deliberate phasing (propose→display→approve/resume→execute).
- **D15-11:** On re-validation failure (policy/actor-scope/action-context changed since approval) →
  transition to `:invalidated` (or `:expired`) with an **operator-visible reason**, emit an event,
  and **never execute** (APRV-03, fail-closed). The timeline shows this explicitly.

### Expiry (APRV-03)

- **D15-12:** Add `ToolApproval.expires_at` (durable). Expiry is **defense-in-depth, fail-closed**:
  (1) a **scheduled Oban job** (`scheduled_at`/`schedule_in` ≈ `expires_at`) flips `:pending →
  :expired` + emits an event (SlaCountdownWorker flip idiom), **and** (2) a **lazy guard** treats
  `expires_at < now` as expired at resume/read time so a missed/un-run sweep can never let a stale
  approval execute. The timeline shows the expired state explicitly.
- **D15-13:** Expiry TTL is **host-configurable** (per-tier and/or per-tool via config / the
  `Policy` seam) with a **fail-closed bounded default** (exact default value = planner discretion;
  must be finite, not "never"). Re-validation-at-resume (D15-10/11) is the real safety; the TTL is
  the bound that guarantees a pending lane cannot live forever.

### Carried guardrails — one sanctioned `propose/3` reopen

> Both prior phases explicitly anticipated Phase 15 reopening `propose/3`; this is **sanctioned
> additive work, not churn** of sealed code. Do both fixes in the same pass.

- **D15-14:** **[FLAGGED — mandated by ratified P14 D-16]** Honor the prose-snapshot guardrail (it
  is written into `Cairnloop.Governance.Preview`'s `@moduledoc` as the discoverable marker):
  1. Add **nullable `rendered_consequence` + `title` columns** to `cairnloop_tool_proposals`.
  2. **Populate both in `propose/3` from Phase 15 forward** (call `Preview.render/1` at propose
     time and snapshot the result).
  3. The approval (and Phase 16 execution) surfaces **READ the snapshotted columns** — **NEVER**
     call live `Preview.render` on an approval/execution screen. Pre-Phase-15 rows have NULL
     snapshot → fall back to the **structured-summary card** built from the snapshot (P14 D-17),
     **not** live prose.
  4. Add a test asserting the approval card shows the **snapshotted** consequence when it diverges
     from the live registry description.
- **D15-15:** **[FLAGGED — carried WR-01]** In the same reopen, replace `reason_str =
  inspect(reason)` in `Governance.insert_blocked_proposal/10` (`governance.ex:313`) with a
  **humanized reason builder** — changesets via `Ecto.Changeset.traverse_errors/2`, never
  `inspect/1` (which persists a raw `#Ecto.Changeset<...>` into `policy_snapshot` + the
  `ToolActionEvent.reason`). `:needs_input` **still persists** (Support-Truth Gate wants blocked
  proposals visible) but with humanized text. Add a test asserting `policy_snapshot` and the event
  reason contain **no `#Ecto.Changeset<` substring**.

### UI reflection (FLOW-03, M011-S03-04)

- **D15-16:** Drop **Approve / Reject / Defer** affordances into the **Phase 14 footer action
  slot** (P14 D-05). The presenter's `approval_outlook/1` (the named honesty seam, P14 D-12)
  becomes the real **"Pending approval"** status when an active `:pending` approval exists, with
  real actions. New states map into the **existing four groups with zero relabeling** (P14 D-10):
  Awaiting = `:pending`; Active = `:approved`/execution-pending; Done = `:rejected`/`:deferred`/
  `:expired`/`:invalidated`; Blocked unchanged. Reflect approval/expiry/resume outcomes back into
  the rail timeline via the existing thin-notification → `reload_conversation_with_context` path —
  **still plain-assign, no streams** (P14 D-02).

### Architecture & posture

- **D15-17:** Telemetry stays **observability-only**, emitted **alongside** (never instead of)
  `ToolActionEvent` inserts (P13 D-29). All reads go through the **narrow `Cairnloop.Governance`
  facade** (P13 D-30) — add approval read/transition APIs there (e.g. `request_approval/_`,
  `approve/_`, `reject/_`, `defer/_`, `expire/_`, `get_active_approval/1`), keep pipeline
  internals private. Copy is **calm, fail-closed, reason-forward, humanized** — never raw Elixir
  terms/JSON to operators (raw only behind an explicit expander), never state-by-color-alone
  (brand §7.5), brand tokens over hex.
- **D15-18:** Shift ordinary implementation choices left to research/planning: exact module/table
  names (recommended `Cairnloop.Governance.ToolApproval`; table `cairnloop_tool_approvals`),
  enum value spellings, the partial-unique-index predicate, the TTL default number, `event_type`
  names, `from_status`/`to_status` handling, and `Ecto.Multi` composition — all discretion **as
  long as the shapes and trust boundaries in D15-01..D15-17 hold**.

### Claude's Discretion

- All names, enum spellings, index predicates, the TTL default value, event-type names,
  Multi/transaction structure, copy wording within the calm brand voice, and exactly where in the
  footer slot the affordances sit — planner/executor discretion.
- Whether `:invalidated` and `:expired` are one status or two (must remain operator-legible).
- Whether the approval read API lives in `Cairnloop.Governance` directly or a thin
  `Governance.Approval` submodule, as long as there is one narrow public facade.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone boundary & active requirements
- `.planning/ROADMAP.md` — Phase 15 goal + plans **M011-S03-01..04**; Phases 16–17 (what Phase 15
  must stay forward-compatible with: execution/first write path + run-level idempotency; MCP seam).
- `.planning/REQUIREMENTS.md` — **FLOW-03, APRV-01..04** (the requirements this phase delivers);
  Proof Posture Gate ("approval request persistence, resume job scheduling, expiry, and re-check
  before execution"; capability rubric "Oban resume, expiry, and **double-check policy** proof");
  Support-Truth Gate ("Persist approval request or deny; **never execute inline**"; "Keep request
  pending or expired with clear reason"); out-of-scope (confidence-score-only approval; blocking
  human approval inside LiveView or one long-running worker).
- `.planning/PROJECT.md` — vM011 posture: extend the M009/M010 trust model; host-owned
  governed-action lane; durable records as truth; **policy-gated approval + resume via Ecto and
  Oban instead of synchronous LiveView execution**.
- `.planning/STATE.md` — carried decisions, incl. the **D-16 prose-snapshot guardrail** and the
  **WR-01** `inspect(changeset)` carry-forward (both honored by D15-14/D15-15); pending todo
  "Replace the synchronous `execute_tool` LiveView path with a durable approval-aware action
  workflow" (this phase's essence); environment caveat (**`Cairnloop.Repo` may be unavailable** in
  this workspace — DB-round-trip + Oban tests may be environment-blocked; mark `# REPO-UNAVAILABLE`).

### Prior-phase decisions that constrain Phase 15
- `.planning/phases/14-operator-timeline-preview-surface/14-CONTEXT.md` — **the direct upstream.**
  **D-16** (the prose-snapshot promotion guardrail Phase 15 MUST execute → D15-14); D-15 (Hybrid
  preview, snapshot vs live); **D-10** (four display groups, zero relabeling → D15-16); **D-12**
  (`approval_outlook/1` honesty seam repurposed to real "Pending approval" → D15-16); **D-05**
  (footer action slot → D15-16); **D-02** (no streams → D15-16); D-24 (`history_line/1` catch-all →
  D15-03); D-13 (status ⊥ risk ⊥ approval axes); D-25 (`ToolProposalPresenter` to extend).
- `.planning/phases/13-governed-tool-contract-proposal-records/13-CONTEXT.md` — **D-15** (pure
  re-callable `validate/3` pipeline the resume worker re-calls → D15-10); **D-12** (`Policy.resolve/3`
  is the Phase-15 PDP seam — extend ONLY this → D15-09/10); **D-23** (approval-transition states
  live on a new `ToolApproval` record, not `ToolProposal` columns → D15-01/02; reserve
  `:pending_approval`); **D-20/D-21** (mirror `ReviewTask`/`ReviewTaskEvent` append-only +
  denormalized-status + transactional co-commit → D15-01/03); **D-24** (propose-time snapshots are
  exactly what resume re-validates current scope/policy against → D15-10); **D-26** (Oban enters in
  Phase 15 resume worker → D15-09); D-10 (`approval_mode` values → D15-05); D-30 (narrow facade).
- `.planning/phases/12-in-thread-quick-fix-ops-closure/12-CONTEXT.md` — D-08 (no opaque
  trust-mixing blob), D-17 (don't collapse distinct states → D15-02).

### Existing code seams (read before implementing)
- `lib/cairnloop/governance.ex` — the facade. `validate/3` (~L154, **re-call from the resume
  worker** — pure, no side effects, D-15); `propose/3` + `insert_new_proposal` (~L180/218, **add
  D-16 `rendered_consequence`/`title` snapshotting** going forward); `insert_blocked_proposal`
  (~L309, **`reason_str = inspect(reason)` at L313 → humanize, WR-01/D15-15**); `get_proposal/1`,
  `list_events/1`, `list_proposals_for_conversation/1` — add the approval read/transition APIs here.
- `lib/cairnloop/governance/policy.ex` — `resolve/3` (the **PDP seam** — extend in place to factor
  actor scope + runtime context; signature stays fixed, D-12).
- `lib/cairnloop/governance/tool_proposal.ex` — add nullable `rendered_consequence`/`title`
  columns + `has_one(:approval)`; `status_values/0` is referenced cross-schema by the event table.
- `lib/cairnloop/governance/tool_action_event.ex` — **extend `@event_type_values`** for approval
  transitions (D15-03); decide `from_status`/`to_status` enum handling; append-only invariant
  (insert-only, `updated_at: false`) must hold.
- `lib/cairnloop/governance/preview.ex` — `Preview.render/1`; the `@moduledoc` already documents the
  **D-16 guardrail** (snapshot at propose, NEVER live on approval surfaces) — D15-14.
- `lib/cairnloop/governance/telemetry.ex` — bounded low-cardinality telemetry to emit approval
  lifecycle events through (observability only, D15-17).
- `lib/cairnloop/knowledge_automation/review_task.ex` + `review_task_event.ex` +
  `lib/cairnloop/knowledge_automation.ex` (`approve_review_task/2`, `reject_review_task/2`,
  `defer_review_task/2`, `publish_review_task/2`) — **THE transition idiom to mirror for
  `ToolApproval`**: denormalized lifecycle `status` + `last_decision`/`last_actor_id`/
  `last_decided_at`/`notes`, `Ecto.Multi` co-commit of record-update + append-only event (D15-01).
- `lib/cairnloop/workers/sla_countdown_worker.ex` — **the Oban worker + scheduled-status-flip
  idiom** for the resume worker and the expiry sweep (D15-09/12); `Application.fetch_env!(:cairnloop,
  :repo)` indirection.
- `lib/cairnloop/application.ex` — **host-owned Oban posture**: the library supervises no Oban and
  wraps `Oban.insert` in `try/rescue` (the host runs the runtime) — plan resume/expiry enqueues
  accordingly (D15-09).
- `lib/cairnloop/web/conversation_live.ex` — footer-slot affordances + Approve/Reject/Defer
  `handle_event` handlers (**durable decision + enqueue, never inline execution**, D15-06); the thin
  PubSub → `reload_conversation_with_context` reload path that reflects new states (D15-16).
- `lib/cairnloop/web/tool_proposal_presenter.ex` — extend: `approval_outlook/1` → real "Pending
  approval"; status-group mapping for the new states; reason/`decided_by` display; humanized labels
  (D15-16).
- `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs` (+ the Phase 13/14 governance
  migrations) — migration style (enum, partial/unique index, append-only event table) for the
  `cairnloop_tool_approvals` migration + the `rendered_consequence`/`title` columns (D15-01/14).

### Product & brand posture
- `prompts/cairnloop_brand_book.md` — §13.2 ("Approval required" / "Blocked by policy" register),
  §5.3/§5.6 (name the state; reason-forward; no raw terms — D15-07/15/17), §7.5 (never
  state-by-color-alone — D15-16), §10.2 (rail layout — D15-16), §2.2/§7 (brand tokens over hex).
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — host-owned Phoenix/Ecto/Oban
  architecture; evidence-vs-telemetry separation; DX posture for host-supplied runtimes.
- `docs/cairnloop-jtbd-and-user-flows.md` — embedded support-cockpit, the in-thread workflow the
  approval surface plugs into.

### External references (orientation, not requirements — most already mined by P13/P14 research)
- GitHub Environments deployment **protection rules / required reviewers** + "Waiting" state;
  Stripe `requires_action` / `requires_confirmation` lifecycle; Terraform `plan -out` → "stale
  plan" only at *apply* (the re-validate-before-execute invariant — D15-10); AWS CloudFormation
  change-set OBSOLETE-at-execute; Temporal/Oban durable-job resume + uniqueness (D15-09).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ReviewTask` + `ReviewTaskEvent` + `KnowledgeAutomation.{approve,reject,defer,publish}_review_task`
  — the proven approve/reject/defer lifecycle: denormalized status + `last_*` decision fields +
  `Ecto.Multi` co-commit of record-update + append-only event. Direct template for `ToolApproval`.
- `Governance.validate/3` — pure, side-effect-free, re-callable gate pipeline; the resume worker
  calls it verbatim against current context (re-validation is free).
- `Governance.Policy.resolve/3` — the single PDP seam to extend (signature fixed); no call-site change.
- `Governance.Preview.render/1` — propose-time snapshot renderer; `@moduledoc` carries the D-16
  guardrail Phase 15 executes.
- `SlaCountdownWorker` — Oban worker + scheduled status-flip; template for the resume worker and the
  expiry sweep.
- `ToolProposalPresenter` (+ `approval_outlook/1`, `history_line/1` catch-all) — extend for new states.
- `ToolActionEvent` — the single append-only timeline to extend with approval event types.

### Established Patterns
- Denormalized authoritative `status` column **plus** a separate append-only events table,
  co-committed in one transaction (`ReviewTask`/`ToolProposal`).
- Pure re-callable validation pipeline; persistence is a thin wrapper around it.
- `Ecto.Enum` value-lists as module attributes paired with derivation/fallback helpers.
- Oban introduced only where async/resume/scheduling is needed; the **host owns the Oban runtime**
  (library only `Oban.insert`s; supervises none).
- Snapshot-at-decision-time as the render source of trust facts; telemetry strictly observability.
- Plain-assign list-comprehension rendering + thin-notification PubSub → full reload (no streams,
  no optimistic UI).
- Calm, fail-closed, reason-forward operator copy; humanize, never raw terms/JSON; never color-alone.

### Integration Points
- New `cairnloop_tool_approvals` table (lifecycle status + denormalized decision fields + `expires_at`
  + FK to proposal + partial unique index on active lane) and `belongs_to`/`has_one` linkage.
- New `rendered_consequence` + `title` columns on `cairnloop_tool_proposals` (nullable), populated in
  `propose/3` going forward (D-16).
- Extended `ToolActionEvent.@event_type_values` for approval transitions (one timeline).
- New approval APIs on the `Cairnloop.Governance` facade (request/approve/reject/defer/expire +
  active-lane read).
- New Oban resume worker (re-validates via `validate/3`, stops at the Phase-16 execution seam) and an
  expiry mechanism (scheduled flip + lazy guard).
- `ConversationLive` footer-slot Approve/Reject/Defer handlers (durable + enqueue, never inline) +
  presenter extensions reflecting new states into the existing four groups.

</code_context>

<specifics>
## Specific Ideas

- `ToolApproval` is "ReviewTask for actions" — the operator's approve/reject/defer muscle memory and
  the durable-decision-with-reason trail map 1:1.
- The re-validate-before-execute gate is **the** Phase-15 deliverable (the rubric's "double-check
  policy proof"): an approval that was valid yesterday must be re-checked against *current* scope and
  policy at resume — borrowed from Terraform's "stale plan" / CloudFormation change-set OBSOLETE
  semantics, which only bite at *apply*, never at proposal time.
- Expiry is fail-closed by construction: even if the scheduled sweep never runs, the lazy
  `expires_at < now` guard at resume guarantees a stale approval can never execute.
- `approval_outlook/1` was deliberately named in Phase 14 as the honesty seam to repurpose here:
  future-tense "Will require approval" copy becomes the real "Pending approval" status with actions,
  with no relabeling of the four display groups.
- Phase 15 reopening `propose/3` is sanctioned (both D-16 and WR-01 were written *expecting* it) —
  do the prose-snapshot columns and the changeset-humanization fix in the same additive pass.

</specifics>

<deferred>
## Deferred Ideas

- **Actual execution (`run/3`), the first narrow approved write path, run-level idempotency, retry/
  backoff, execution telemetry alignment** — Phase 16 (the resume worker's success branch is the
  seam; Phase 15 stops at execution-pending).
- **OBS-02 full attribution lineage** (which policy version/rule fired, attributable evidence
  chains) — Phase 16/17; Phase 15 captures `decided_by` + the `policy_snapshot` only.
- **Four-eyes / segregation-of-duties enforcement** — host policy hook via `Policy.resolve/3` /
  `authorize/2`; not enforced by Cairnloop (no identity/role model).
- **`Phoenix.LiveView.stream/3` for the timeline** — re-evaluate at Phase 16 when real execution
  events flow (P14 D-02 trigger).
- **Pending-too-long notifications / escalation** (nudge an approver before expiry) — future
  enhancement; out of scope.
- **Richer snooze / re-request UX** beyond defer + open-a-new-lane — future enhancement.
- **MCP seam / optional Scoria evidence lane** — Phase 17.

### Reviewed Todos (not folded)
- STATE.md "Replace the synchronous `execute_tool` LiveView path with a durable approval-aware
  action workflow" — **not deferred; it IS this phase's essence** (D15-06/16), so it is satisfied
  here rather than carried.

</deferred>

---

*Phase: 15-approval-state-machine-oban-resume*
*Context gathered: 2026-05-24*
