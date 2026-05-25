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

> **UPDATE 2026-05-25 — no longer manual.** All four behaviors below are now covered by the
> DB-backed integration suite (`test/integration/`, run via `mix test.integration` + CI), so
> Phase 15 requires **0 human verification**. See the *Integration Harness Audit 2026-05-25*
> section and `15-HUMAN-UAT.md` (status: complete) for the covering tests. Table retained for
> provenance.

| Behavior | Requirement | Why Manual (orig.) | Now Automated By |
|----------|-------------|------------|-------------------|
| Partial unique index actually rejects a second `:pending` approval on a live INSERT | APRV-04 | `Cairnloop.Repo` unavailable in this workspace; the constraint only bites on a real Postgres INSERT | `test/integration/partial_unique_index_test.exs` (real INSERT → `{:error, changeset}`; non-`:pending` second lane allowed; `request_approval/2` conflict path) |
| JSONB atom→string round-trip on approval snapshot fields | APRV-02 | Repo unavailable; the footgun only surfaces on a Postgres INSERT+SELECT | `test/integration/jsonb_roundtrip_test.exs` (insert atom-keyed snapshots, reload→string keys, resume worker rehydrates → `:execution_pending`; unknown-atom → `:invalidated`) |
| `expires_at` + scheduled expiry + async resume flow | APRV-01/02/03 | Library does not run Oban; the host owns the runtime | `test/integration/approval_flow_test.exs` (request→approve→resume → `:execution_pending` + event trail; `ApprovalExpiryWorker` `:pending → :expired`) |
| Footer affordances render text+color (never color-alone), reason-required, snapshot card | FLOW-03 / D15-14 | Visual/behavioral; needs a live LiveView | `test/integration/approval_footer_live_test.exs` (LiveViewTest: brand token + labels in DOM; blank-reason persists nothing; with-reason persists `:rejected`; snapshot prose shown) |

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

---

## Integration Harness Audit 2026-05-25

Shift-left of the 4 Manual-Only items into automated DB-backed integration tests, so Phase 15
needs **0 human verification**. Built a `test/support` test host (test-only `Cairnloop.Repo`,
`Cairnloop.Web.Endpoint` + router, `DataCase`/`ConnCase`, `Fixtures`) compiled only under
`MIX_ENV=test` via `elixirc_paths(:test)`; host-owned tables (conversations/messages/drafts)
created by a `priv/test_host/migrations` migration; runs locally on dockerized Postgres
(`docker-compose.yml`, pgvector image) and in a new CI `integration` job.

| Metric | Count |
|--------|-------|
| Manual items automated | 4 / 4 |
| Integration tests added | 12 (4 suites) |
| Phase-15 defects found & fixed | 2 |

**Suites** (tag `:integration`, excluded from the fast headless lane):
`partial_unique_index_test.exs`, `jsonb_roundtrip_test.exs`, `approval_flow_test.exs`,
`approval_footer_live_test.exs`.

**Defects surfaced by real-runtime testing (masked by the headless MockRepo suite):**
1. **Schema (APRV-04 trail):** `cairnloop_tool_action_events.to_status` was `NOT NULL`, but
   Phase-15 approval events insert it as `nil` (D15-03 — transition carried in
   `event_type`+`metadata`). Every approval transition would fail on a real host DB. Fixed
   additively by migration `20260524120200_relax_action_event_to_status_null` (no sealed
   migration edited).
2. **Logic (APRV-01/02 handoff):** `approve/3` sets the lane to `:approved` and enqueues
   `ApprovalResumeWorker`, but the worker's `perform/1` matched `status: :pending`, so the
   real approve→resume handoff no-op'd and the lane never reached `:execution_pending`. The
   documented state axis is `:approved → resume → :execution_pending`. Fixed by matching
   `:approved` (owner-approved 2026-05-25); headless `approval_resume_worker_test.exs`
   fixtures updated from `:pending` to `:approved` accordingly.

**Evidence.**
- `MIX_ENV=test mix test.integration` → **12 tests, 0 failures** (real Postgres, no boot noise).
- Full headless suite `mix test` → **472 tests, 1 failure (12 excluded)** — the single
  failure is the documented baseline `Automation.DraftTest` (M005 drift), not a regression.
- `mix compile --warnings-as-errors` → exit 0 in both `:dev` and `:test`.

**Carried decision (durable):** Phase-15 approval lanes flow `:pending → :approved →
:execution_pending`; the resume worker acts on `:approved` (never `:pending` — re-validation
must not bypass the approval gate). Phase 16 execution should resume from `:execution_pending`.
