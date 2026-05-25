# Phase 16: First Approved Write Path & Telemetry - Context

**Gathered:** 2026-05-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Prove **one narrow, low-blast-radius write action after approval**, end-to-end, while keeping
execution inspectable, grounded, fail-closed, and operationally bounded. This is the milestone's
**first real side effect** — every prior phase deliberately stopped short of calling `run/3`.

The execution lane is already seamed by Phases 13–15 and terminates at `:execution_pending`
(`ApprovalResumeWorker` re-validates against current policy/scope, then STOPS — it never calls
`run/3`; that contract is sealed). Phase 16 builds the success branch off `:execution_pending`:
the actual `run/3` call, run-level idempotency/retry protections, bounded execution telemetry, and
in-thread reflection of execution outcomes.

This phase covers requirements **ACT-01, OBS-01, OBS-02** and plans **M011-S04-01..03**:

- **M011-S04-01 (ACT-01):** ship one narrow approved write workflow — **an internal,
  operator-only note appended to the conversation** (owner-confirmed; see D16-01).
- **M011-S04-02 (OBS-01 + OBS-02):** bounded governed-action execution telemetry, and align
  durable action events so audit/evidence can attribute who approved and which policy applied.
- **M011-S04-03:** failure, retry, and idempotency protections so the first write path stays
  low-surprise under replay and worker retries.

It does **NOT** build:
- **Auto (`:auto` / read-only) execution** — deferred (D16-09); build the execution worker
  forward-compatibly but keep this phase on the approved-write proof.
- **The Scoria / optional evidence adapter or the read-only MCP seam** — Phase 17 (OBS-02 here
  only makes attribution *reconstructable from durable records*; it does not build an adapter).
- **`:destructive`-tier or high-risk/financial writes** — ACT-02, deferred past vM011.
- **A central host policy DSL / four-eyes enforcement** — host policy hook only (P15 D15-08).
- **`Phoenix.LiveView.stream/3`** — evaluated and rejected for this phase (D16-08).

Sealed upstream — do NOT churn: `propose/3`, the idempotency-key derivation, the
re-validate-before-execute gate, `ApprovalResumeWorker`'s "never call `run/3`" contract, the
approve/reject/defer/expire facade, and the Phase 13/14/15 schemas. Phase 16 is **additive**:
new worker, new terminal states, new telemetry events, reserved-column population, one example tool.

</domain>

<decisions>
## Implementation Decisions

> Calibration: owner profile is `opinionated` → `minimal_decisive`; repo CLAUDE.md is shift-left
> (decide-for-me, escalate only VERY-impactful). All decisions below were auto-decided with
> recorded rationale **except D16-01**, the one genuinely scope-shaping call, which the owner
> confirmed (internal note). Exact names, enum spellings, queue names, backoff numbers, event-type
> names, and Multi/transaction structure are planner/executor discretion as long as the shapes and
> trust boundaries below hold (continues P13 D-31 / P15 D15-18).

### First write action — the ACT-01 proof (M011-S04-01)

- **D16-01 [OWNER-CONFIRMED]:** The first approved write action is an **internal, operator-only
  note appended to the conversation**. Rationale: lowest blast radius, **append-only** (fits the
  durable-records-are-truth trust model), trivially idempotent via the run-level key, needs **no
  host identity/routing model**, and is **never customer-visible** (compliant with PROJECT.md
  out-of-scope "no autonomous customer-visible side effects" — it goes through approval, not
  confidence). Rejected: thread assignment (mutating/last-write-wins, leans on a host user model
  Cairnloop doesn't own) and follow-up task (no host task table — pulls in deferred infra).
- **D16-02:** Ship the note tool as a **documented, copyable example governed-write tool**
  (`use Cairnloop.Tool`, `risk_tier: :low_write` → derives `approval_mode: :requires_approval`),
  e.g. `Cairnloop.Tools.InternalNote` (name = planner discretion). It is the concrete reference a
  host developer copies AND the concrete tool Phase 17 projects to MCP. The write target is the
  **host-owned conversation message store** (`cairnloop_messages`, with a distinct
  `role`/`metadata` marking it internal) reached through the **configured repo indirection**
  (`Application.fetch_env!(:cairnloop, :repo)`) — the library declares the example but does not
  hardcode host-schema assumptions beyond the message-append shape the integration harness models.
  The note row **carries the run-level idempotency key** (in `metadata`) so the write itself is
  dedupable (D16-05).

### Execution architecture — the success branch off `:execution_pending` (M011-S04-01)

- **D16-03:** Add a **new dedicated `ToolExecutionWorker`** Oban worker (queue + name = planner
  discretion; mirror `SlaCountdownWorker`/`ApprovalResumeWorker` idiom:
  `Application.fetch_env!(:cairnloop, :repo)` indirection, host owns the Oban runtime, library only
  `Oban.insert`s via the existing `safe_enqueue/1` try/rescue). It is the **only** place `run/3` is
  ever called. Do **NOT** fold execution into `ApprovalResumeWorker` — its "never call `run/3`"
  contract is sealed (P15 D15-10); folding would couple the re-validation gate to side effects and
  break independent retryability.
- **D16-04:** **The resume worker enqueues execution.** On `:approved` + re-validation pass, the
  resume worker transitions `:execution_pending` **and then enqueues `ToolExecutionWorker`** (same
  record-before-enqueue ordering as `approve/3` → resume). The chain is a series of durable,
  independently-retryable Oban jobs:
  `approve → [enqueue] resume → re-validate → :execution_pending → [enqueue] execute → run/3`.
  (Re-confirm: this is additive to the resume worker's success branch, not a contract change — it
  still never calls `run/3`.)

### Idempotency, failure & retry — low-surprise under replay (M011-S04-03)

- **D16-05:** Target **at-most-once execution** (fail-closed: prefer NOT executing over
  double-writing). Three layers, all required:
  1. **Oban job uniqueness** on `ToolExecutionWorker` keyed on the proposal/approval id
     (`unique: [period: :infinity, ...]`, mirroring the resume worker) — no double-enqueue.
  2. **Pre-execution terminal guard** — if `ToolProposal.result_state == :succeeded` (or the lane
     is already in a terminal executed/failed state), the worker is a true no-op. A replayed/
     duplicate job never re-runs a completed write.
  3. **Run-level idempotency key** derived deterministically from the proposal's existing
     idempotency key (P13 D-25 reserved this) + attempt-stable component, **passed into `run/3`
     via context** so the tool dedupes its own host write (Stripe-style). The example note tool
     demonstrates the pattern (existence check on the key in `metadata` before insert).
- **D16-06:** **Re-validate immediately before each `run/3` attempt.** Re-call the pure
  `Governance.validate/3` + the lazy `expires_at` guard at execution time (cheap, no side effects —
  Terraform "stale-plan only bites at apply", extended from resume to execution). On failure →
  fail-closed to `:invalidated` with a humanized operator-visible reason, **never write** (APRV-03
  posture carried into execution).
- **D16-07:** **Failure/retry semantics.** Distinguish transient from permanent:
  - Transient `run/3` `{:error, reason}` (e.g. DB hiccup) → return `{:error, reason}` so **Oban's
    built-in backoff retries**, up to a **host-configurable `max_attempts` with a fail-closed
    bounded default** (finite; planner picks the number, e.g. 3–5). Increment `ToolProposal.attempt`
    and emit a per-attempt `ToolActionEvent` so attempt history is reconstructable.
  - Permanent failure (re-validation fail, invalid input, exhausted retries) → terminal
    `:execution_failed`, **no further retry** (`{:cancel, reason}` or recorded-`:ok`, planner's
    choice), with a durable humanized reason.

### Outcome states & durable truth (TOOL-04 continuation, OBS-02)

- **D16-08:** Extend `ToolApproval` status with terminal **`:executed`** (success) and
  **`:execution_failed`** (terminal after retries). Keep states distinct — never collapse into a
  generic "done" (P12 D-17 / P13 D-23). The canonical **execution outcome** lives in the already-
  reserved `ToolProposal` columns: `result_state` (`:succeeded`/`:failed`), `result_summary`
  (humanized, bounded — from `run/3`'s `{:ok, result}`), `attempt`, and `oban_job_id`. Each
  attempt/outcome is also an append-only `ToolActionEvent` (extend `@event_type_values` with e.g.
  `:execution_started`, `:execution_succeeded`, `:execution_failed`) carrying the attempt number —
  **one timeline per proposal** (P15 D15-03). **No separate `ToolRun` table** (P13 D-22 left it
  optional; reserved columns + per-attempt events make full history reconstructable for ONE narrow
  write — extracting `ToolRun` now would design against unproven multi-tool assumptions).
- **D16-09 (OBS-02 alignment):** Phase 16 makes attribution **reconstructable from durable
  records** — approver identity (`ToolApproval.decided_by` / the `:approved` event `actor_id`),
  which policy applied (`ToolProposal.policy_snapshot`, re-validated at resume + execute), and the
  execution outcome/attempt. It does **NOT** build a Scoria/evidence adapter or new attribution
  lineage schema (Phase 17). The deliverable is "the durable trail already carries everything an
  optional evidence integration would need."

### Telemetry (OBS-01)

- **D16-10:** Route execution telemetry through the **bounded `Cairnloop.Governance.Telemetry`
  allow-list module** (not ad-hoc `Cairnloop.Telemetry.execute`). Add events
  `[:cairnloop, :governance, :action_executed]` and `[:cairnloop, :governance, :action_failed]`
  (names = planner discretion; `:approval_decided` optional). Measurements: `count` + bounded
  numeric `duration_ms` (execution latency). **Labels are enum-bounded only:**
  `risk_tier`, `approval_mode`, `result_state` (all `Ecto.Enum`-bounded), and `tool_ref` **only
  when validated against the registry** (registry size is the cardinality bound; normalize unknown
  → `:unknown`, mirroring the module's existing `normalize_*` posture). **NEVER** put input
  payloads, `actor_id`, `conversation_id`/`account_id`, reason strings, or note content into labels
  — detailed truth lives in durable records (D-29, OBS-01 "no high-cardinality payload in labels").
  Telemetry is emitted **after** a successful `with`/transaction, never inside the clause list, and
  never instead of a `ToolActionEvent` (P13 D-29). *(Discretionary additive nicety: route the
  existing `ApprovalResumeWorker` `[:governance, :approval_transition]` emit through the bounded
  module too, for consistency — only if it stays a clean additive change.)*

### Operator surface (FLOW reflection)

- **D16-11:** New states map into the **existing four display groups with zero relabeling**
  (P14 D-10): `:execution_pending` → Active (already mapped); `:executed` → Done (success chip);
  `:execution_failed` → Done with a **failure chip (color + text, brand token — never
  color-alone**, brand §7.5). Show the humanized `result_summary` on success and the humanized
  failure reason + attempt count on failure (raw terms only behind an explicit expander). Read from
  **snapshotted** card fields (never live `Preview.render` — D-16 guardrail). Reflect outcomes via
  the existing thin-PubSub → `reload_conversation_with_context` path.
- **D16-12 [P14 D-02 trigger evaluated → resolved]:** **Keep plain-assign reload; do NOT introduce
  `Phoenix.LiveView.stream/3` in Phase 16.** Rationale: the governed-actions rail is a bounded
  per-conversation list (AR-14-02), execution adds only a couple of events per action, and the
  existing full-reload path already renders new states correctly. Streams add DOM-id/append
  complexity for no measurable benefit at this size, against the "seal completed phases / prefer
  additive" posture. Re-evaluate only if a real host shows volume pressure (deferred).

### Architecture & posture (carried)

- **D16-13:** Durable Ecto records + append-only events are workflow truth; `:telemetry` is
  observability only (P13 D-29). All reads/transitions go through the **narrow
  `Cairnloop.Governance` facade** (add execution transition/read APIs there; keep worker internals
  private). Copy is calm, fail-closed, reason-forward, humanized — never raw Elixir terms/JSON to
  operators except behind an explicit expander; brand tokens over hex (P15 D15-17).
- **D16-14:** **Use the Phase 15 DB-backed integration harness for the merge-blocking proof.**
  `MIX_ENV=test mix test.integration` (dockerized pgvector / CI `integration` job) is exactly the
  "real Postgres + Oban-worker + LiveView round-trip" leg STATE.md anticipated. The write +
  idempotency-under-replay + retry + at-most-once guarantees are proven in `test/integration/`;
  fast headless `mix test` stays DB-free and covers worker branch logic with the mock repo
  (mark genuine round-trip-only assertions `# REPO-UNAVAILABLE` where they can't run headless).

### Claude's Discretion

- Worker/module/queue names, exact terminal-status spellings (`:executed` vs `:completed`),
  `event_type` names, the run-level idempotency-key composition, `max_attempts` default number and
  backoff curve, `result_summary` formatting, whether execution APIs live directly on
  `Cairnloop.Governance` or a thin submodule, and `Ecto.Multi`-vs-sequential-`with` co-commit
  structure — all discretion as long as D16-01..D16-14 shapes and trust boundaries hold.
- Whether `:execution_failed` sits in the Done group or warrants a distinct operator grouping —
  as long as it is operator-legible as "failed" and not color-alone.
- Exact placement of the success/failure chip and any expander in the Phase 14 card layout.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone boundary & active requirements
- `.planning/ROADMAP.md` — Phase 16 goal + plans **M011-S04-01..03**; Phase 17 (what Phase 16 must
  stay forward-compatible with: optional evidence lane + read-only MCP seam — keep `Spec` pure-data
  and attribution reconstructable).
- `.planning/REQUIREMENTS.md` — **ACT-01, OBS-01, OBS-02** (the requirements this phase delivers);
  Proof Posture Gate (telemetry "Tests for event names and bounded metadata; durable event history
  tests"; approval "re-check before execution"); Support-Truth Gate (approval-gated write "Persist
  approval request or deny; never execute inline"; timeline "durable blocked/pending/error states
  instead of optimistic UI"); out-of-scope (high-risk/financial first action; confidence-only
  approval; treating tool output as canonical truth over KB/evidence).
- `.planning/PROJECT.md` — vM011 posture: extend the M009/M010 trust model; durable records as
  truth; **no autonomous customer-visible side effects** (the internal note is operator-only and
  approval-gated — compliant).
- `.planning/STATE.md` — carried decisions, especially **"Phase 16 execution resumes from
  `:execution_pending`"** and the lifecycle `:pending → :approved → :execution_pending`; the
  integration-harness entry (`MIX_ENV=test mix test.integration`, dockerized pgvector / CI
  `integration` job — the proof vehicle for D16-14); the two Phase-15 defects fixed by integration
  tests (NOT-NULL `to_status` relaxed; resume worker matches `:approved`); environment caveat
  (`Cairnloop.Repo` may be unavailable headless — mark `# REPO-UNAVAILABLE`).

### Prior-phase decisions that constrain Phase 16
- `.planning/phases/15-approval-state-machine-oban-resume/15-CONTEXT.md` — **the direct upstream.**
  D15-10/11 (resume re-validates and stops at `:execution_pending`, never `run/3` → D16-03/04);
  D15-09 (Oban worker idiom + host owns runtime + `safe_enqueue` try/rescue → D16-03); D15-12
  (lazy `expires_at` guard → D16-06); D15-14 (read snapshotted prose, never live `Preview.render`
  on execution surfaces → D16-11); D15-16 (four display groups, zero relabeling, footer slot,
  plain-assign reload → D16-11/12); D15-03 (one `ToolActionEvent` timeline, extend
  `@event_type_values` → D16-08); D15-17 (telemetry observability-only, narrow facade → D16-10/13).
- `.planning/phases/13-governed-tool-contract-proposal-records/13-CONTEXT.md` — **D-22** (reserved
  `attempt`/`oban_job_id`/`result_state`/`result_summary` columns + "Phase 16 can add columns or
  extract `ToolRun`" → D16-08 chooses NOT to extract); **D-25** (idempotency key on `ToolProposal`;
  "Phase 16 derives a per-attempt run-level key" → D16-05); **D-15** (pure re-callable `validate/3`
  → D16-06); **D-26** (Oban enters Phase 15 resume / Phase 16 execution with job uniqueness keyed on
  the run-level key → D16-05); **D-29** (telemetry alongside, never instead of, events → D16-10/13);
  **D-30** (narrow facade); D-09/D-10 (`:low_write` → `:requires_approval` → D16-02); D-17/D-18
  (fail-closed precedence; persist outcomes with reason → D16-07).
- `.planning/phases/14-operator-timeline-preview-surface/14-CONTEXT.md` — **D-02** (no streams — the
  trigger Phase 16 was told to re-evaluate → D16-12 keeps plain-assign); **D-10** (four groups,
  zero relabeling → D16-11); **D-05** (footer action slot); **D-16** (snapshot prose, never live on
  execution surfaces → D16-11); D-13 (status ⊥ risk ⊥ approval axes); AR-14-02 (bounded rail list —
  re-evaluate at Phase 16 → informs D16-12).

### Existing code seams (read before implementing)
- `lib/cairnloop/governance.ex` — the facade. `validate/3` (~L227, **re-call before each `run/3`
  attempt**, D16-06); the approval transition helpers (`update_approval_with_event/3` ~L103,
  `approve/3` ~L603 — mirror its record-before-enqueue ordering for the execute enqueue, D16-04);
  `safe_enqueue/1` (~L86 — reuse for the execution enqueue, D16-03); `get_proposal/1`,
  `get_active_approval/1`, `list_events/1` — add the execution transition/read APIs here (D16-13).
- `lib/cairnloop/workers/approval_resume_worker.ex` — **the success branch (~L80-83) is the Phase 16
  seam**: it transitions `:execution_pending` and STOPs; D16-04 adds the `ToolExecutionWorker`
  enqueue here (additive — still never calls `run/3`). Mirror its `unique:`/repo-indirection/
  `transition_approval`/`humanize_reason` patterns for the new worker.
- `lib/cairnloop/governance/tool_approval.ex` — `@status_values` (~L34) extend with `:executed` +
  `:execution_failed` (D16-08); `decision_changeset` idiom for the execution transition.
- `lib/cairnloop/governance/tool_proposal.ex` — **the reserved Phase-16 columns** (`attempt`,
  `oban_job_id`, `result_state` `[:not_executed,:succeeded,:failed]`, `result_summary`, ~L43-46) —
  populate them in execution (D16-08); the idempotency key field for D16-05 derivation.
- `lib/cairnloop/governance/tool_action_event.ex` — extend `@event_type_values` for execution
  transitions; append-only invariant (`updated_at: false`, insert-only) must hold (D16-08).
- `lib/cairnloop/governance/telemetry.ex` — **extend this bounded allow-list module** with
  execution events + bounded labels (D16-10); mirror `@events`/`@allowed_*`/`normalize_*`.
- `lib/cairnloop/telemetry.ex` — the underlying `execute/3` the bounded module wraps.
- `lib/cairnloop/tool.ex` — the `run/3` contract (`{:ok, result} | {:error, reason}`, ~L42) the
  execution worker finally calls; `__tool_spec__/0`, `scope/0`, `authorize/2` for the example tool.
- `lib/cairnloop/tool_registry.ex` — registry (`Application.get_env(:cairnloop, :tools, [])`); the
  bound for the `tool_ref` telemetry label (D16-10) and where the example note tool is registered.
- `lib/cairnloop/web/conversation_live.ex` — the thin-PubSub → `reload_conversation_with_context`
  reload path that reflects execution outcomes (D16-11); footer-slot area (no new retry button —
  retries are automatic, D16-07).
- `lib/cairnloop/web/tool_proposal_presenter.ex` — `status_group/1` (~L64, already maps
  `:execution_pending` → `:active`) and `approval_outlook_for_approval/1` (~L141) — extend for
  `:executed`/`:execution_failed` chips + humanized result/failure rows (D16-11).
- `lib/cairnloop/knowledge_automation.ex` (`update_task_with_event`-style co-commit) +
  `lib/cairnloop/workers/sla_countdown_worker.ex` — the worker + transactional-co-commit idioms to
  mirror for execution (D16-03/08).
- `priv/test_host/migrations/20260101000000_create_host_owned_tables.exs` — the host-owned
  `cairnloop_messages` (`role`, `metadata`) / `cairnloop_conversations` (`host_user_id`) the example
  note tool writes to (D16-02); models the host the integration harness stands in for.
- `priv/repo/migrations/` (Phase 13/15 governance migrations) — migration style for the new terminal
  statuses + any column/index additions.
- `test/integration/approval_flow_test.exs` + `test/support` (DataCase/ConnCase/Fixtures) +
  `docker-compose.yml` + `mix.exs` `test.integration` alias — **the harness D16-14 uses** for the
  real-Postgres + Oban + LiveView round-trip proof of the write/idempotency/retry guarantees.

### Product & brand posture
- `prompts/cairnloop_brand_book.md` — §5.3/§5.6 (name the state; reason-forward; no raw terms —
  D16-11/13), §7.5 (never state-by-color-alone — D16-11), §13.2 (approval/blocked register),
  §2.2/§7 (brand tokens over hex).
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — host-owned Phoenix/Ecto/Oban
  architecture; **evidence-vs-telemetry separation** (D16-10/13); host-supplied-runtime DX posture.
- `prompts/scoria overview for integration ideas.txt` — the optional evidence lane OBS-02 stays
  *reconstructable for* but does NOT build (Phase 17).
- `docs/cairnloop-jtbd-and-user-flows.md` — the in-thread support-cockpit the execution outcome
  reflects into.

### External references (orientation, not requirements — mostly mined by P13/P15 research)
- Stripe idempotency keys / brandur "Implementing Stripe-like Idempotency Keys in Postgres" — the
  run-level key + idempotent-write pattern (D16-05).
- Terraform `plan -out` → "stale plan" only at *apply*; CloudFormation change-set OBSOLETE-at-execute
  — the re-validate-before-execute invariant extended from resume to execution (D16-06).
- Oban `unique` job options + retry/backoff + `max_attempts` semantics — the at-most-once scheduling
  + transient-retry layer (D16-05/07).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ApprovalResumeWorker` — the Oban worker + `unique:` + repo-indirection + `transition_approval`/
  `humanize_reason` template; its success branch (`:execution_pending`) is the seam the execution
  worker hangs off (D16-03/04).
- `Governance.validate/3` — pure, side-effect-free, re-callable; called again before each `run/3`
  attempt (D16-06).
- `Governance.approve/3` + `update_approval_with_event/3` + `safe_enqueue/1` — record-before-enqueue
  co-commit ordering + host-safe Oban insert to mirror for the execute transition/enqueue.
- Reserved `ToolProposal` columns (`attempt`, `oban_job_id`, `result_state`, `result_summary`) —
  built in Phase 13 for exactly this; populate, don't re-migrate (except adding terminal statuses).
- `Cairnloop.Governance.Telemetry` — the bounded allow-list module to extend for execution events
  (D16-10).
- `SlaCountdownWorker` / `KnowledgeAutomation.update_task_with_event` — worker + co-commit idioms.
- Phase 15 **integration harness** (`test/integration`, `test/support`, `docker-compose.yml`,
  `mix test.integration`) — the real-Postgres + Oban + LiveView round-trip proof lane (D16-14).

### Established Patterns
- Durable denormalized status + separate append-only events table, co-committed; telemetry strictly
  observability, emitted after success.
- Oban introduced only where async is needed; host owns the runtime, library only `Oban.insert`s
  (wrapped in try/rescue).
- Re-validate-before-act (validate/3 + lazy expiry) as the fail-closed gate.
- Snapshot-at-decision-time as the render source; plain-assign reload + thin-PubSub (no streams).
- Calm, fail-closed, reason-forward, humanized operator copy; never color-alone; brand tokens.

### Integration Points
- New `ToolExecutionWorker` (consumes `:execution_pending`, re-validates, calls `run/3`, records
  outcome, retries transient via Oban) enqueued from the resume worker's success branch.
- New terminal `ToolApproval` statuses `:executed` / `:execution_failed`; populated `ToolProposal`
  reserved columns; extended `ToolActionEvent.@event_type_values` (one timeline).
- Extended bounded `Governance.Telemetry` (execution/failure events, enum-bounded labels).
- New execution transition/read APIs on the narrow `Cairnloop.Governance` facade.
- Example `Cairnloop.Tools.InternalNote` governed-write tool registered in config, writing an
  internal-note row to the host `cairnloop_messages` store via the configured repo, idempotent on
  the run-level key.
- Presenter + `ConversationLive` reflection of `:executed`/`:execution_failed` into the existing
  four groups via the existing reload path.

</code_context>

<specifics>
## Specific Ideas

- The internal note is "the safest possible first side effect": append-only, operator-only, never
  customer-visible, approval-gated, and dedupable by key — it proves the *lane* (safe side effects)
  without committing to routing/identity/task infra the milestone defers.
- The execution chain is a clean series of durable, independently-retryable Oban jobs
  (`approve → resume → execute`), each a no-op on replay — mirroring the approve→resume handoff
  already shipped, so there is no new concurrency model to invent.
- Re-validate-before-execute is the same Terraform "stale plan only bites at apply" lesson Phase 15
  applied at resume, now applied one seam later at the actual write.
- The reserved Phase-13 columns + per-attempt events were designed precisely so Phase 16 records
  full execution history without a new `ToolRun` table or rewriting history.
- The Phase 15 integration harness was built anticipating "any future leg that needs a real
  Postgres + Oban-worker + LiveView round-trip" — this write path is that leg; use it for the
  merge-blocking proof.

</specifics>

<deferred>
## Deferred Ideas

- **Auto (`:auto` / read-only) execution** — read-only tools currently open no approval lane and
  have no execution enqueue; building auto-exec is a different lane and risks tool sprawl. Build the
  execution worker forward-compatibly (so it can later serve `:auto` proposals with minimal change)
  but keep Phase 16 on the approved-write proof. (D16-09 scope guard.)
- **Scoria / OpenInference evidence adapter + read-only MCP seam** — Phase 17. Phase 16 only keeps
  attribution reconstructable from durable records (OBS-02), it builds no adapter.
- **`Phoenix.LiveView.stream/3` for the timeline** — evaluated (P14 D-02 trigger) and rejected for
  this phase (D16-12); re-evaluate only under real-host volume pressure.
- **`:destructive` / high-risk / financial writes, rollback, multi-step runbooks (FLOW-04)** —
  ACT-02/FLOW-04, deferred past vM011.
- **Four-eyes / segregation-of-duties enforcement** — host policy hook only (P15 D15-08); Cairnloop
  has no identity/role model.
- **A second governed write tool / broad tool catalog** — this phase ships exactly one example as
  proof; more tools are future work once the lane is proven.

### Reviewed Todos (not folded)
- STATE.md pending "Replace the synchronous `execute_tool` LiveView path with a durable
  approval-aware action workflow" — already satisfied by Phases 13/15; Phase 16 completes the
  execution end of it (the `run/3` write), so it is **closed by this phase**, not carried.
- STATE.md "Unblock repo-backed realism lanes so later milestone verification can include stronger
  live proof" — **satisfied** by the Phase 15 integration harness, which D16-14 uses here.
- STATE.md "Centralize duplicated fail-closed search guards" — retrieval-adjacent, not governed-
  action; out of scope for Phase 16.

</deferred>

---

*Phase: 16-first-approved-write-path-telemetry*
*Context gathered: 2026-05-25*
