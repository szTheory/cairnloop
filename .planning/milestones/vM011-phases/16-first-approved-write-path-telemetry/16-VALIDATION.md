---
phase: 16
slug: first-approved-write-path-telemetry
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-25
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: `16-RESEARCH.md` § Validation Architecture (HIGH confidence).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in Elixir) |
| **Config file** | `test/test_helper.exs` (excludes `:integration` tag by default) |
| **Quick run command** | `MIX_ENV=test mix test` |
| **Full suite command** | `MIX_ENV=test mix test.integration` (alias: `test.setup` + `mix test --include integration test/integration`) |
| **Integration prerequisite** | `docker-compose up -d postgres` (pgvector — see `docker-compose.yml`) |
| **Estimated runtime** | headless ~<10s; integration ~30–60s (DB round-trip + Oban worker + LiveView) |

**Headless caveat (carried):** `Cairnloop.Repo` may be unavailable in this workspace. Genuine
Postgres round-trip assertions (at-most-once under replay, idempotent re-enqueue, attempt
increment) live in `test/integration/` and are proven via `mix test.integration`; mark
round-trip-only assertions `# REPO-UNAVAILABLE` where they cannot run headless. Fast `mix test`
stays DB-free and covers worker branch logic with the mock repo.

---

## Sampling Rate

- **After every task commit:** Run `MIX_ENV=test mix test` (headless, < 10s)
- **After every plan wave:** Run `MIX_ENV=test mix test.integration` (DB-backed; requires Docker Postgres)
- **Before `/gsd:verify-work`:** Full integration suite must be green
- **Max feedback latency:** ~10s headless / ~60s integration

---

## Per-Task Verification Map

> Task IDs are bound to plan tasks during planning (the planner assigns `16-NN-MM`). The rows
> below are the **requirement-level coverage contract** the per-task verifies must satisfy; the
> Nyquist auditor reconciles exact task IDs against this map post-planning.

| Requirement | Behavior to prove | Test Type | Automated Command | Harness | Status |
|-------------|-------------------|-----------|-------------------|---------|--------|
| ACT-01 | `ToolExecutionWorker` calls `run/3` and writes the note row | integration | `MIX_ENV=test mix test.integration` | `test/integration/` | ✅ green (16-01 happy-path + 16-02 at-most-once) |
| ACT-01 | Pre-execution terminal guard: 2nd `perform/1` on a `:succeeded` proposal is a no-op | integration | `MIX_ENV=test mix test.integration` | `test/integration/` | ✅ green (16-02 terminal-guard no-op) |
| ACT-01 | Oban unique job: 2nd `Governance.execute/3` enqueue rejected (no duplicate job) | unit+integration | `MIX_ENV=test mix test` | `__opts__/0` headless | ✅ green (16-02 Oban unique opts assert; live queue-count REPO-UNAVAILABLE) |
| ACT-01 | Transient `{:error, reason}` increments `attempt`, emits per-attempt event, returns `{:error, reason}` | integration | `MIX_ENV=test mix test.integration` | `test/integration/` | ✅ green (16-02 attempt increment) |
| ACT-01 | Terminal failure: re-validation fail → `:execution_failed`, `{:cancel, reason}`, humanized reason | unit | `MIX_ENV=test mix test` | mock repo | ✅ green (16-02 headless worker branch tests) |
| ACT-01 | `InternalNote.run/3` idempotent: duplicate call w/ same run-key → `{:ok, %{idempotent: true}}` | integration | `MIX_ENV=test mix test.integration` | `test/integration/` | ✅ green (16-02 InternalNote idempotency test) |
| OBS-01 | Execution telemetry emitted with bounded enum labels; no high-cardinality keys | unit | `MIX_ENV=test mix test` | `:telemetry.attach` | ✅ green (16-02 Task 1 telemetry_test.exs) |
| OBS-01 | `normalize_tool_ref/1` maps unknown ref → `:unknown` | unit | `MIX_ENV=test mix test` | pure function | ✅ green (16-02 Task 1 telemetry_test.exs) |
| OBS-02 | `ToolApproval.decided_by` + `policy_snapshot` attributable after execute | integration | `MIX_ENV=test mix test.integration` | `test/integration/` | ✅ green (16-03 OBS-02 attribution test) |
| OBS-02 | `ToolActionEvent` trail carries attempt number + actor attribution (one timeline) | integration | `MIX_ENV=test mix test.integration` | `test/integration/` | ✅ green (16-03 OBS-02 attribution test) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

### Observation points (per guarantee)

| Guarantee | Observation point | Assertion pattern |
|-----------|-------------------|-------------------|
| At-most-once (no double-write) | `cairnloop_messages` count after two identical `perform/1` | `assert Repo.aggregate(Message, :count) == 1` |
| Terminal guard (no-op on replay) | `ToolApproval.status` after second perform | `assert Repo.get!(ToolApproval, id).status == :executed` |
| Attempt increment | `ToolProposal.attempt` after transient failure | `assert Repo.get!(ToolProposal, id).attempt == 2` |
| Per-attempt events | `ToolActionEvent` trail | `assert :execution_attempt_failed in event_types` |
| Telemetry bounded | emitted metadata keys | `refute Map.has_key?(meta, :actor_id)` (and `:conversation_id`, `:reason`) |
| OBS-02 attribution | `ToolApproval.decided_by` + `policy_snapshot` | `assert approval.decided_by != nil and approval.policy_snapshot != %{}` |

---

## Wave 0 Requirements

New test files needed (mirror `test/integration/approval_flow_test.exs` structure):

- [x] `test/integration/tool_execution_worker_test.exs` — at-most-once, idempotent replay, transient
  retry, terminal failure, full event trail, `InternalNote.run/3` idempotency (ACT-01, OBS-02) — complete (16-02)
- [x] `test/cairnloop/governance/telemetry_test.exs` (new or extend) — execution event names, bounded
  metadata (no high-cardinality leakage), `normalize_tool_ref/1` (OBS-01) — complete (16-02)

Existing infrastructure re-used without change:
- `Cairnloop.DataCase` (`use Cairnloop.DataCase, async: false`)
- `Cairnloop.Fixtures` — `proposal_fixture/1`, `approval_fixture/1` already exist; extend with
  `message_fixture/1` only if needed
- `docker-compose.yml`, `mix.exs` `test.integration` alias, `test/test_helper.exs` `:integration`
  exclusion — all in place from Phase 15

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `:executed` success chip + humanized `result_summary` renders in the Done group | ACT-01 / FLOW reflection (D16-11) | ✅ Shifted left to automated rendered-HTML assertion in `test/integration/tool_execution_outcome_live_test.exs` (16-03). Final brand/visual fidelity still requires eyeball in dev, but correctness (chip text present, brand token used, state named not color-alone) is automated. | Run `MIX_ENV=test mix test.integration` to verify. |

*All worker/idempotency/telemetry/attribution behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (integration) / < 10s (headless)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
