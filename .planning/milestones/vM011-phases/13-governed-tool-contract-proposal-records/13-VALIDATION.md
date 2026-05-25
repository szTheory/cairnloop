---
phase: 13
slug: governed-tool-contract-proposal-records
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-23
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `13-RESEARCH.md` § Validation Architecture. Phase 13 executes nothing —
> all proofs target the contract, the durable records, and the fail-closed `validate/3` pipeline.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in to Elixir/OTP) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/cairnloop/governance/ test/cairnloop/tool_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~10–30 seconds (unit-level; no live DB) |

---

## DB Availability Context

`Cairnloop.Repo` is unavailable in this workspace. All DB-touching tests use the established
**MockRepo pattern** (`Process.get/put` in-process state, injected via
`Application.put_env(:cairnloop, :repo, MockRepo)` in setup) exactly as `review_task_test.exs` does.

**Provable without a live DB (the bulk of coverage):** changeset validity + enum bounds + required
fields; insert-only event changeset; the pure `validate/3` pipeline (all four fail-closed outcomes
and their precedence); compile-time `CompileError` for bad enum values; deny-by-default `authorize/2`;
`scope/0` mismatch detection; idempotency-key determinism; registry module-resolution safety (no
`String.to_existing_atom/1`); telemetry metadata boundedness.

**Requires a live DB (environment-blocked / deferred to integration):** full `propose/3` insert +
transaction co-commit against Postgres; idempotency unique-constraint duplicate detection via
`on_conflict: :nothing`; DB-level append-only enforcement.

---

## Sampling Rate

- **After every task commit:** Run `mix test test/cairnloop/governance/ test/cairnloop/tool_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Requirement Verification Map

> Task IDs are assigned by the planner; rows here are keyed to the phase requirements (TOOL-01..04)
> and the locked decisions they prove. The planner must attach each row's command to a task `<automated>`
> block or a Wave 0 dependency.

| Requirement | Decision | Secure / Fail-Closed Behavior | Test Type | Automated Command | File Exists |
|-------------|----------|-------------------------------|-----------|-------------------|-------------|
| TOOL-01 | D-02 | `use Cairnloop.Tool, risk_tier: :bad` raises `CompileError` at compile time | unit (`Code.compile_string` + `assert_raise`) | `mix test test/cairnloop/tool_test.exs` | ❌ W0 |
| TOOL-01 | D-03 | `__tool_spec__/0` returns a frozen pure `%Spec{}` with declared fields | unit | `mix test test/cairnloop/tool_test.exs` | ❌ W0 |
| TOOL-01 | D-16 | `authorize/2` default returns `{:error, :no_policy_defined}` (deny-by-default) | unit | `mix test test/cairnloop/tool_test.exs` | ❌ W0 |
| TOOL-01 | D-11 | approval-mode derivation: tier→mode defaults; unknown/missing → `:always_block` | unit | `mix test test/cairnloop/tool_test.exs` | ❌ W0 |
| TOOL-02 | D-26 | `Governance.propose/3` returns `{:ok, proposal}` for valid tool + actor (MockRepo) | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ❌ W0 |
| TOOL-02 | D-27 | `ConversationLive` handler no longer calls `execute/3` or `run/3`; emits "Proposed — pending review" | unit | `mix test test/cairnloop/web/conversation_live_test.exs` | ❌ W0 |
| TOOL-03 | D-18/D-19 | `validate/3` → `{:blocked, :unsupported, _}` for unknown tool, **no DB row** | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ❌ W0 |
| TOOL-03 | D-17 | `validate/3` → `{:blocked, :needs_input, _}` for invalid changeset | unit | `mix test test/cairnloop/governance_test.exs` | ❌ W0 |
| TOOL-03 | D-16/D-17 | `validate/3` → `{:blocked, :scope_invalid, _}` when scope not met | unit | `mix test test/cairnloop/governance_test.exs` | ❌ W0 |
| TOOL-03 | D-16/D-17 | `validate/3` → `{:blocked, :policy_denied, _}` when `authorize/2` rejects | unit | `mix test test/cairnloop/governance_test.exs` | ❌ W0 |
| TOOL-03 | D-17 | Outcome precedence `unsupported → needs_input → scope_invalid → policy_denied` (inject ≥2 failures, assert first wins) | unit | `mix test test/cairnloop/governance_test.exs` | ❌ W0 |
| TOOL-04 | D-21/D-23 | `ToolProposal` changeset valid with required fields; rejects unknown statuses (Ecto.Enum bounds) | unit | `mix test test/cairnloop/governance/tool_proposal_test.exs` | ❌ W0 |
| TOOL-04 | D-21 | `ToolActionEvent` changeset insert-only; no `updated_at` field | unit | `mix test test/cairnloop/governance/tool_action_event_test.exs` | ❌ W0 |
| TOOL-04 | D-20/D-26 | `propose/3` co-commits proposal + `proposal_created` event in one transaction (MockRepo) | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ❌ W0 |
| TOOL-04 | D-25 | Duplicate idempotency key returns the existing proposal (MockRepo) | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ❌ W0 |
| TOOL-04 | D-18 | Persisted fail-closed proposal carries `outcome` + `reason` for `scope_invalid`/`policy_denied` | unit (MockRepo) | `mix test test/cairnloop/governance_test.exs` | ❌ W0 |

*Status legend: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

All test files for this phase are new — none exist yet. Wave 0 must create the stubs:

- [ ] `test/cairnloop/tool_test.exs` — TOOL-01: compile-time enum validation (`CompileError`), `__tool_spec__/0` frozen, `authorize/2` deny-by-default, tier→mode derivation
- [ ] `test/cairnloop/governance_test.exs` — TOOL-02/03/04: all four `validate/3` outcomes + precedence, `propose/3` co-commit, idempotency duplicate, unknown-tool-no-row
- [ ] `test/cairnloop/governance/tool_proposal_test.exs` — TOOL-04: changeset validations, Ecto.Enum bounds, discrete bounded snapshot fields
- [ ] `test/cairnloop/governance/tool_action_event_test.exs` — TOOL-04: append-only changeset, insert-only API (no update/delete)
- [ ] `test/cairnloop/web/conversation_live_test.exs` — TOOL-02: handler no longer calls `execute/3`/`run/3`; proposal-first flash
- [ ] MockRepo fixture available to governance tests (reuse the `review_task_test.exs` pattern)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full `propose/3` insert + transaction against real Postgres | TOOL-02/04 | `Cairnloop.Repo` unavailable in workspace (STATE.md caveat) | Run `mix test --only db` in an environment with a live `Cairnloop.Repo`; assert proposal + event rows persist and idempotency unique constraint fires |
| DB-level append-only enforcement (no UPDATE on event rows) | TOOL-04 | Requires live DB to exercise constraint behavior | With live DB, attempt `repo().update` on a `ToolActionEvent` and confirm the public API exposes no such path |

---

## Validation Sign-Off

- [ ] All requirement rows mapped to a task `<automated>` verify or a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING (❌ W0) references
- [ ] No watch-mode flags in any command
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter (after planner attaches commands to tasks)

**Approval:** pending
