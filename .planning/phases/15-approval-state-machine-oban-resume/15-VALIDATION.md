---
phase: 15
slug: approval-state-machine-oban-resume
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-24
validated: 2026-05-24
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `15-RESEARCH.md` › Validation Architecture. Trust surface: the durable approval
> lane + re-validate-before-execute gate. The COMMON path is headless (changeset / presenter /
> worker-logic via MockRepo); the rare Postgres-only legs (partial unique index, JSONB round-trip,
> `expires_at` column) are written but marked `# REPO-UNAVAILABLE` — design tests around the
> headless reality, not the DB-bound leg.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Phoenix.LiveViewTest (already configured) |
| **Config file** | `test/test_helper.exs` (existing) |
| **Quick run command** | `mix test test/cairnloop/governance/ test/cairnloop/workers/ test/cairnloop/web/tool_proposal_presenter_test.exs` |
| **Full suite command** | `mix test` |
| **Compile gate** | `mix compile --warnings-as-errors` (MANDATORY — warnings fail the build) |
| **Estimated runtime** | ~15–30 seconds (changeset / presenter / worker-via-MockRepo tests are headless, no DB) |

---

## Sampling Rate

- **After every task commit:** `mix compile --warnings-as-errors && {quick run command}`
- **After every plan wave:** `mix compile --warnings-as-errors && mix test`
- **Before `/gsd:verify-work`:** Full suite green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

Provisional task IDs (the planner refines to real IDs); each row is a behavior the plan's
`<automated>` verify block MUST satisfy. `T-*` threat refs link to the planner's `<threat_model>`.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 15-W0-01 | W0 | 0 | APRV-04 / FLOW-03 | — | — | scaffold | `mix test test/cairnloop/governance/tool_approval_test.exs` | ✅ new | ✅ green |
| 15-W0-02 | W0 | 0 | APRV-02 / APRV-03 | — | — | scaffold | `mix test test/cairnloop/workers/approval_resume_worker_test.exs` | ✅ new | ✅ green |
| 15-W0-03 | W0 | 0 | APRV-03 | — | — | scaffold | `mix test test/cairnloop/workers/approval_expiry_worker_test.exs` | ✅ new | ✅ green |
| 15-W0-04 | W0 | 0 | APRV-01 / D15-15 | — | — | scaffold | `mix test test/cairnloop/governance_test.exs` | ✅ extend | ✅ green |
| 15-01-a | M011-S03-01 | 1 | APRV-04 | T-two-lane | `ToolApproval` partial unique index on `tool_proposal_id WHERE status = :pending`; second active lane rejected (changeset `unique_constraint`; DB-leg `# REPO-UNAVAILABLE`) | unit (changeset) | `mix test test/cairnloop/governance/tool_approval_test.exs` | ✅ new | ✅ green |
| 15-01-b | M011-S03-01 | 1 | APRV-04 / FLOW-03 | — | `decision_changeset` requires `reason` for reject/defer; `decided_by`/`decided_at` captured; denormalized `last_decision` mirrors ReviewTask idiom | unit (changeset) | `mix test test/cairnloop/governance/tool_approval_test.exs` | ✅ new | ✅ green |
| 15-01-c | M011-S03-01 | 1 | APRV-04 | T-append-only | `ToolActionEvent` append-only invariant holds for new approval event_types (`updated_at: false`; no `update/1`/`delete/1`); new `@event_type_values` atoms valid | unit | `mix test test/cairnloop/governance/tool_action_event_test.exs` | ✅ extend | ✅ green |
| 15-01-d | M011-S03-01 | 1 | APRV-04 | — | `get_active_approval/1` returns the single `:pending` lane (or nil); narrow `Cairnloop.Governance` facade exposes approval read APIs, pipeline internals stay private | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ✅ extend | ✅ green |
| 15-02-a | M011-S03-02 | 2 | APRV-01 | T-inline-exec | `approve/...` persists approval record + event **and** enqueues resume job; **never calls `run/3`**; record written before enqueue | unit (MockRepo + `enqueue_fn` capture) | `mix test test/cairnloop/governance_test.exs` | ✅ extend | ✅ green |
| 15-02-b | M011-S03-02 | 2 | FLOW-03 | — | reject/defer persist reason on `ToolApproval` + in `ToolActionEvent`; reject/defer **without** reason → changeset error (not persisted) | unit (changeset, MockRepo) | `mix test test/cairnloop/governance/tool_approval_test.exs` | ✅ new | ✅ green |
| 15-02-c | M011-S03-02 | 2 | APRV-04 | T-append-only | all approval decisions appear in the single `ToolActionEvent` timeline (append-only trail reconstructable; multi-decision fixture) | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ✅ extend | ✅ green |
| 15-02-d | M011-S03-02 | 2 | APRV-04 | T-force-resolved | transition guarded on current status `== :pending`; forcing a decision on a resolved approval is refused | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ✅ extend | ✅ green |
| 15-03-a | M011-S03-03 | 2 | APRV-02 | T-stale-exec | resume worker re-calls `Governance.validate/3` (+ `Policy.resolve/3`) against CURRENT context; on pass → `:execution_pending` seam + event; **no `run/3`** | unit (MockRepo) | `mix test test/cairnloop/workers/approval_resume_worker_test.exs` | ✅ new | ✅ green |
| 15-03-b | M011-S03-03 | 2 | APRV-03 | T-stale-exec | resume re-validate **fail** → `:invalidated` + operator-visible reason event; **never executes** (fail-closed) | unit (MockRepo) | `mix test test/cairnloop/workers/approval_resume_worker_test.exs` | ✅ new | ✅ green |
| 15-03-c | M011-S03-03 | 2 | APRV-03 / D15-12 | T-expired-exec | lazy `expires_at < now` guard marks approval expired at resume/read time before re-validate → stale approval can never execute even if the sweep never ran | unit (MockRepo, DateTime injection) | `mix test test/cairnloop/workers/approval_resume_worker_test.exs` | ✅ new | ✅ green |
| 15-03-d | M011-S03-03 | 2 | APRV-02 | T-double-enqueue | resume worker `unique: [keys: [:approval_id]]`; `perform/1` idempotent (re-checks status, no-ops if not resumable) | unit (MockRepo) | `mix test test/cairnloop/workers/approval_resume_worker_test.exs` | ✅ new | ✅ green |
| 15-03-e | M011-S03-03 | 2 | APRV-03 | — | scheduled expiry worker (`scheduled_at` ≈ `expires_at`) flips `:pending → :expired` + emits event (SlaCountdownWorker flip idiom) | unit (MockRepo) | `mix test test/cairnloop/workers/approval_expiry_worker_test.exs` | ✅ new | ✅ green |
| 15-04-a | M011-S03-04 | 3 | FLOW-03 | — | presenter maps approval states into the **existing four groups, zero relabeling** (D15-16): Awaiting=`:pending`; Active=`:approved`/`:execution_pending`; Done=`:rejected`/`:deferred`/`:expired`/`:invalidated` | unit (headless presenter) | `mix test test/cairnloop/web/tool_proposal_presenter_test.exs` | ✅ extend | ✅ green |
| 15-04-b | M011-S03-04 | 3 | FLOW-03 | T-raw-terms | `approval_outlook/1` becomes real "Pending approval" when active lane exists; `history_line/1` produces humanized lines for **all** new approval event types; reason/`decided_by` shown; no raw Elixir terms/JSON | unit (pure) | `mix test test/cairnloop/web/tool_proposal_presenter_test.exs` | ✅ extend | ✅ green |
| 15-04-c | M011-S03-04 | 3 | FLOW-03 | T-color-alone | footer-slot Approve/Reject/Defer affordances render; status conveyed by text **and** color (brand §7.5, never color-alone); reload via existing thin-notification → `reload_conversation_with_context` (plain-assign, no streams) | unit (LiveView render) | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ extend | ✅ green |
| 15-04-d | M011-S03-04 | 3 | FLOW-03 | T-inline-exec | `handle_event("approve"/"reject"/"defer")` only persists + enqueues; **no inline execution**, no blocked LiveView process | unit (LiveView) | `mix test test/cairnloop/web/conversation_live_test.exs` | ✅ extend | ✅ green |
| 15-05-a | M011-S03-01 (reopen) | 1 | D15-14 | T-trust-drift | `propose/3` snapshots `rendered_consequence` + `title` at propose time; approval surface **reads the snapshot, never live `Preview.render`**; divergence fixture proves snapshotted value is shown | unit (presenter, two-proposal divergence) | `mix test test/cairnloop/governance/preview_test.exs` | ✅ extend | ✅ green |
| 15-05-b | M011-S03-01 (reopen) | 1 | D15-15 / WR-01 | T-raw-terms | `insert_blocked_proposal` humanizes via `traverse_errors/2`, never `inspect/1`; `policy_snapshot` + event reason contain **no `#Ecto.Changeset<` substring**; `:needs_input` still persists | unit (MockRepo, source assertion) | `mix test test/cairnloop/governance_test.exs` | ✅ extend | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/cairnloop/governance/tool_approval_test.exs` (new, 16 tests) — `ToolApproval` changeset: one-active-lane `unique_constraint`, reason required for reject/defer, `decision_changeset` denormalized fields, append-only intent
- [x] `test/cairnloop/workers/approval_resume_worker_test.exs` (new, 9 tests) — re-validate pass→`:execution_pending` (no `run/3`); fail→`:invalidated`; lazy `expires_at` guard; uniqueness/idempotency
- [x] `test/cairnloop/workers/approval_expiry_worker_test.exs` (new, 4 tests) — scheduled `:pending → :expired` flip + event
- [x] `test/cairnloop/governance_test.exs` (extend, 60 tests) — `approve` enqueues + never inline-executes; record-before-enqueue; D15-15 WR-01 humanization (no `#Ecto.Changeset<`); append-only multi-decision trail; transition guarded on `:pending`
- [x] `test/cairnloop/governance/tool_action_event_test.exs` (extend, 24 tests) — new approval `@event_type_values` valid; append-only invariant holds
- [x] `test/cairnloop/governance/preview_test.exs` (extend, 12 tests) — D15-14 snapshotted-vs-live divergence (approval surface reads snapshot)
- [x] `test/cairnloop/web/tool_proposal_presenter_test.exs` (extend, 54 tests) — approval status groups (zero relabeling), `approval_outlook/1` → "Pending approval", `history_line/1` for approval events
- [x] `test/cairnloop/web/conversation_live_test.exs` (extend, 55 tests) — footer Approve/Reject/Defer affordances, snapshot card, no-streams reload, FLOW-03 reason-required error path
- [x] No framework install required (ExUnit + Phoenix.LiveViewTest already configured)

Shared fixture: inline `%ToolProposal{}` / `%ToolApproval{}` struct factories per test file (existing
repo idiom — no shared factory module). Worker tests inject `MockRepo` (via `Application.put_env`,
per `sla_countdown_worker_test.exs`) and an `enqueue_fn` opt (defaulting to `&Oban.insert/1`, per
`knowledge_automation.ex`) so logic is exercised headlessly without Oban or Postgres.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Partial unique index actually rejects a second `:pending` approval on a live INSERT | APRV-04 | `Cairnloop.Repo` unavailable in this workspace (STATE.md); the constraint only bites on a real Postgres INSERT | When a repo-backed lane is available: insert two pending approvals for one proposal, assert the second raises a unique-constraint error. Mark the stub `# REPO-UNAVAILABLE`. |
| JSONB atom→string round-trip on approval snapshot/`policy_snapshot` fields | APRV-02 | Repo unavailable; the footgun only surfaces on a Postgres INSERT+SELECT | Insert an approval, reload from Postgres, assert re-validation + presenter behave identically to the string-keyed unit fixtures. Mark stubs `# REPO-UNAVAILABLE`. |
| `expires_at` column type + scheduled-job timing in the host's Oban runtime | APRV-03 | Library does not run Oban; the host owns the runtime | In a host app with Oban configured: approve an action, let the scheduled expiry job fire, confirm the `:pending → :expired` flip and the timeline event. |
| Visual brand compliance of the approval affordances (footer slot, calm reason-forward copy, chip color+text pairing, rail placement) | FLOW-03 | Visual judgement | Run the app, open a conversation with a `:requires_approval` action, confirm Approve/Reject/Defer match brand §13.2/§10.2 and never convey state by color alone (§7.5). |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (3 new test files + 5 extensions)
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter (all 24 task rows green; auditor confirmed)

**Approval:** validated 2026-05-24 — Nyquist-compliant

---

## Validation Audit 2026-05-24

State A audit (existing pre-execution contract reconciled against executed-and-verified phase).

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

**Method.** Read 5 SUMMARY files + 15-VERIFICATION.md; cross-referenced all 24 Per-Task
Verification Map rows against the 8 test files on disk. Confirmed every referenced
automated command exists and runs green; confirmed **zero active `@tag :skip`** remain
(all skip mentions are Wave 0 comment prose — the scaffolds turned green by Wave 4).

**Evidence.**
- `mix compile --warnings-as-errors` → exit 0 (clean).
- Scoped Phase 15 suite (8 files) → **234 tests, 0 failures**. (`Chimeway.Repo` boot
  noise is the documented pre-existing baseline per CLAUDE.md, not a regression.)
- 15-VERIFICATION.md: 10/10 must-have truths verified in code.

**Outcome.** No MISSING or PARTIAL requirements; auditor spawn unnecessary. The 4
Manual-Only items (see section above) are genuinely environment-blocked in this workspace (no live
Oban runtime, no Postgres-backed `Cairnloop.Repo`, no browser) and are tracked in
`15-HUMAN-UAT.md` (status: partial) — they are not Nyquist gaps. Frontmatter flipped to
`nyquist_compliant: true`, `wave_0_complete: true`, `status: complete`.
