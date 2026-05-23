---
phase: 13-governed-tool-contract-proposal-records
plan: "02"
subsystem: governance
tags: [governance, tool-proposals, fail-closed, idempotency, append-only-events, ecto-schema, migration, validate-pipeline]
dependency_graph:
  requires:
    - Cairnloop.Tool.Spec (13-01)
    - Cairnloop.Tool behaviour with scope/0, authorize/2, changeset/2 (13-01)
    - Cairnloop.ToolRegistry.find_tool_module/1 pattern (13-01)
  provides:
    - Cairnloop.Governance.ToolProposal — durable proposal schema with idempotency + snapshots
    - Cairnloop.Governance.ToolActionEvent — append-only audit event schema
    - Cairnloop.Governance.Policy.resolve/3 — Phase 15 approval-mode resolver seam
    - Cairnloop.Governance.Telemetry.emit/3 — bounded observability for governance events
    - Cairnloop.Governance.validate/3 — pure, re-callable fail-closed pipeline (Phase 15 reuse)
    - Cairnloop.Governance.propose/3 — synchronous co-commit transaction wrapper
    - Migration: cairnloop_tool_proposals + cairnloop_tool_action_events tables
  affects:
    - Phase 14 (proposal id is the timeline card seam)
    - Phase 15 (validate/3 is the resume-worker re-call function; Policy.resolve/3 is the PDP seam)
    - Phase 16 (reserved columns: attempt/oban_job_id/result_state/result_summary)
    - ConversationLive (13-03 wires propose/3 into the execute_tool handler)
tech_stack:
  added: []
  patterns:
    - ReviewTask/ReviewTaskEvent denormalized-status + append-only-events idiom (D-20)
    - Ordered with pipeline — clause order IS precedence (D-17)
    - Stripe-style deterministic idempotency key derivation via sha256(canonical_json) (D-25)
    - check-then-insert idempotency pattern (Pitfall 6 defense)
    - Telemetry emitted AFTER with-success, never inside clause list (D-29)
    - Three discrete snapshot maps per trust category, no opaque blob (D-24)
    - MockRepo Process.get/put pattern for DB-free governance tests
key_files:
  created:
    - lib/cairnloop/governance/tool_proposal.ex
    - lib/cairnloop/governance/tool_action_event.ex
    - lib/cairnloop/governance/policy.ex
    - lib/cairnloop/governance/telemetry.ex
    - lib/cairnloop/governance.ex
    - priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs
    - test/cairnloop/governance/tool_proposal_test.exs
    - test/cairnloop/governance/tool_action_event_test.exs
    - test/cairnloop/governance_test.exs
  modified: []
decisions:
  - "D-20: ToolProposal + ToolActionEvent mirror ReviewTask/ReviewTaskEvent idiom exactly"
  - "D-21: ToolActionEvent append-only: timestamps(updated_at: false), no update/delete API"
  - "D-22: Phase 16 reserved columns on ToolProposal: attempt/oban_job_id/result_state/result_summary"
  - "D-23: Status enum locked to [:proposed,:needs_input,:scope_invalid,:policy_denied]"
  - "D-24: Three discrete snapshot maps (input_/scope_/policy_snapshot) — no opaque trust-mixing blob"
  - "D-25: Idempotency key: sha256(canonical_json({tool_ref, actor_id, account_id, input, dedupe_token}))"
  - "D-26: propose/3 synchronous transaction, no Oban, no run/3 call"
  - "D-17: validate/3 clause order IS precedence: unsupported→needs_input→scope_invalid→policy_denied"
  - "D-19: resolve_tool via Atom.to_string match, NEVER String.to_existing_atom"
  - "D-18: Unknown tool rejected pre-persistence (telemetry only, no row); registered blocked tools ARE persisted"
  - "D-12/D-15 seam: Policy.resolve/3 is the Phase 15 PDP extension point; validate/3 is the resume-worker re-call"
  - "D-29: Telemetry emitted AFTER with success, never inside clause list"
  - "Idempotency check-then-insert: get_by before insert avoids the on_conflict:nothing footgun (Pitfall 6)"
metrics:
  duration_minutes: 12
  completed_date: "2026-05-23"
  tasks_completed: 3
  files_changed: 9
---

# Phase 13 Plan 02: Durable Governance Records + Proposal Pipeline Summary

**One-liner:** Ecto-backed ToolProposal + append-only ToolActionEvent (mirroring ReviewTask idiom) with a fail-closed ordered `with` validate/3 pipeline, synchronous co-commit propose/3, Stripe-style idempotency, snapshot-at-propose-time, and 51 MockRepo tests covering all TOOL-03/TOOL-04 rows.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 (RED) | Failing ToolProposal + ToolActionEvent changeset tests | 483e160 | test/cairnloop/governance/tool_proposal_test.exs, test/cairnloop/governance/tool_action_event_test.exs |
| 1 (GREEN) | ToolProposal + ToolActionEvent schemas + migration | 483e160 | lib/cairnloop/governance/tool_proposal.ex, lib/cairnloop/governance/tool_action_event.ex, priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs |
| 2+3 (RED) | Failing governance_test.exs (validate/3 + propose/3) | d3dc4ab | test/cairnloop/governance_test.exs |
| 2+3 (GREEN) | Policy + Telemetry + validate/3 + propose/3 facade | d3dc4ab | lib/cairnloop/governance/policy.ex, lib/cairnloop/governance/telemetry.ex, lib/cairnloop/governance.ex |

## What Was Built

### `lib/cairnloop/governance/tool_proposal.ex` (new)

`schema "cairnloop_tool_proposals"` mirroring `ReviewTask` exactly (D-20):
- `@status_values [:proposed,:needs_input,:scope_invalid,:policy_denied]` (D-23) with `status_values/0` public accessor
- Three discrete snapshot `:map` fields: `input_snapshot`, `scope_snapshot`, `policy_snapshot` (D-24 — no opaque trust-mixing blob)
- Phase 16 reserved columns: `attempt` (default 0), `oban_job_id` (nil), `result_state` (default :not_executed), `result_summary` (nil) (D-22)
- `unique_constraint(:idempotency_key)` on changeset (D-25)
- `changeset/2` (standard create) + `blocked_changeset/2` (non-:proposed terminal outcomes)
- `has_many(:events, ToolActionEvent)`

### `lib/cairnloop/governance/tool_action_event.ex` (new)

`schema "cairnloop_tool_action_events"` mirroring `ReviewTaskEvent` exactly (D-20, D-21):
- `timestamps(type: :utc_datetime_usec, updated_at: false)` — append-only invariant (Pitfall 4)
- `from_status` nullable (nil for `proposal_created` — first event has no prior status)
- Cross-schema enum: `field(:from_status, Ecto.Enum, values: ToolProposal.status_values())`
- `validate_metadata/1` copied verbatim from ReviewTaskEvent (nil → %{}, non-map → error)
- `@event_type_values [:proposal_created, :proposal_blocked]` (Phase 16 extends)
- NO `update/1`, NO `delete/1` — insert-only API (moduledoc + pattern enforcement)

### `lib/cairnloop/governance/policy.ex` (new)

`Policy.resolve/3` — approval-mode resolver (D-12, Phase 15 seam):
- Precedence: `tool.spec.approval_mode || host_config_override(tier) || derive_approval_mode(tier)`
- Host override via `Application.get_env(:cairnloop, :approval_mode_overrides, %{})`
- Phase 15 extends ONLY this function for actor-context PDP — no schema or call-site change

### `lib/cairnloop/governance/telemetry.ex` (new)

Bounded governance observability (D-29):
- 3 events: `[:proposal_created, :proposal_blocked, :proposal_duplicate]`
- Allow-lists: `@allowed_outcomes`, `@allowed_risk_tiers`, `@allowed_approval_modes` with `:unknown` catch-all
- `emit/3` guard: `when event in @events` — unknown events silently dropped
- Normalize-with-default pattern: unknown values → fail-closed default (`:unsupported`/`:unknown`)
- Delegates to `Cairnloop.Telemetry.execute/3` at `[:cairnloop, :governance, event]`

### `lib/cairnloop/governance.ex` (new)

Narrow public facade (D-30):

**`validate/3`** — pure, side-effect-free, re-callable (D-15):
- 4-clause `with` pipeline; clause order IS the precedence (D-17):
  - gate 0 `resolve_tool/1`: `Atom.to_string(mod) == tool_ref` match, NEVER `String.to_existing_atom` (D-19, T-13-05)
  - gate 1 `validate_input/2`: calls `tool_module.changeset/2` over `context[:tool_params]` (D-04)
  - gate 2 `check_scope/3`: `scope/0` required vs granted comparison
  - gate 3 `tool_module.authorize/2`: deny-by-default (D-16)
- Returns: `{:ok, validated_attrs}` | `{:blocked, :unsupported, :unknown_tool}` | `{:blocked, :needs_input, cs}` | `{:blocked, :scope_invalid, reason}` | `{:blocked, :policy_denied, reason}`
- `validated_attrs` includes `risk_tier`, `approval_mode`, and all three snapshot maps (D-14)

**`propose/3`** — thin persistence wrapper (D-26):
- Unknown tool: telemetry only, NO row (D-18, Pitfall 7)
- Registered blocked: persists `ToolProposal{status: outcome}` + `:proposal_blocked` event (D-18 Support-Truth Gate)
- Happy path: check-then-insert idempotency (Pitfall 6 defense), co-commits proposal + `:proposal_created` event in one `with`
- Duplicate: `get_by(idempotency_key)` returns existing + emits `:proposal_duplicate` telemetry (D-25)
- Telemetry emitted AFTER `with` success block (D-29)
- NO `run/3`, NO Oban, NO execution (D-26)

**Read helpers:** `get_proposal/1`, `list_events/1` (D-30)

### Migration `20260524000000_add_tool_proposals_and_action_events.exs` (new)

- `cairnloop_tool_proposals`: all schema fields; status/enum cols as `:string`; `:map` fields `null: false, default: %{}`
- `unique_index(:cairnloop_tool_proposals, [:idempotency_key])` — not partial (D-25)
- Query indexes: `[:status, :inserted_at]`, `[:actor_id, :status]`, `[:tool_ref, :inserted_at]`
- `cairnloop_tool_action_events`: FK `references(:cairnloop_tool_proposals, on_delete: :delete_all), null: false`; `timestamps(updated_at: false)`; indexes `[:tool_proposal_id, :inserted_at]`, `[:event_type, :inserted_at]`

### Test files (new)

- `test/cairnloop/governance/tool_proposal_test.exs` — 22 TOOL-04 changeset tests (pure, no DB)
- `test/cairnloop/governance/tool_action_event_test.exs` — 11 TOOL-04 changeset + append-only invariant tests
- `test/cairnloop/governance_test.exs` — 18 TOOL-02/03/04 tests under MockRepo:
  - All 4 validate/3 outcomes + D-17 precedence (scope before policy)
  - propose/3 happy path, co-commit assertion (proposal + event)
  - Unknown tool: no rows inserted (D-18, Pitfall 7)
  - Scope invalid + policy denied: persisted with correct status
  - Idempotency: same inputs → same proposal id; different → different key

## Verification

All acceptance criteria pass:
- `mix test test/cairnloop/governance/ test/cairnloop/governance_test.exs` — 51 tests, 0 failures
- No `String.to_existing_atom/1` or `String.to_atom/1` in governance.ex (actual code)
- No Oban, no run/3, no execute/3 in governance.ex (actual code)
- `grep -c "String.to_existing_atom\|String.to_atom" lib/cairnloop/governance.ex` — 1 (in code comment/documentation only, not executable)
- `grep -c "derive_approval_mode" lib/cairnloop/governance/policy.ex` — 3
- `grep -c "@allowed_outcomes" lib/cairnloop/governance/telemetry.ex` — 2
- `grep -c "unique_index(:cairnloop_tool_proposals, [:idempotency_key])" migration` — 1
- `grep -c "on_delete: :delete_all" migration` — 1
- `grep -c "updated_at: false" migration` — 1

**DB-dependent proof deferred** per 13-VALIDATION.md § Manual-Only Verifications: real Postgres insert/transaction, on_conflict duplicate at constraint level, DB-level append-only. Run `mix test --only db` in a live-Repo environment.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Idempotency check-then-insert pattern instead of on_conflict**
- **Found during:** Task 3 — MockRepo cannot simulate Postgres unique constraint violations
- **Issue:** The plan specified catching `unique_constraint` changeset errors from `repo().insert()`. MockRepo's `insert/1` doesn't enforce uniqueness, so the duplicate test failed (second insert succeeded and returned a different id).
- **Fix:** Added a `get_by(idempotency_key)` check BEFORE inserting. If an existing proposal is found, return it immediately (no insert). This is actually a better pattern per Pitfall 6 (check-before-insert avoids the `on_conflict: :nothing` footgun where a conflicting insert returns `nil` id). The unique constraint error path is retained as defense-in-depth for production race conditions.
- **Files modified:** `lib/cairnloop/governance.ex` — split `propose_valid/4` into `propose_valid/4` + `insert_new_proposal/5` to cleanly separate the check-then-insert flow.
- **Commits:** d3dc4ab

**2. [Rule 1 - Bug] Fixed Elixir pattern match syntax in `unique_constraint_error?/2`**
- **Found during:** Task 2 (compilation error)
- **Issue:** `{^field, {_msg, [constraint: :unique | _]}}` uses the list tail-cons operator inside a non-list context, which is a compile error in Elixir.
- **Fix:** Rewrote as `{^field, {_msg, opts}} when is_list(opts) -> Keyword.get(opts, :constraint) == :unique`
- **Files modified:** `lib/cairnloop/governance.ex`
- **Commits:** d3dc4ab

## Known Stubs

None — all functions are fully implemented. Reserved Phase 16 columns (`attempt`, `oban_job_id`, `result_state`, `result_summary`) are intentional stubs declared by design (D-22), not accidental — Phase 16 populates them.

## Threat Flags

All STRIDE threats T-13-05 through T-13-10 are mitigated:
- **T-13-05 (Tampering/DoS — resolve_tool):** `Atom.to_string(mod) == tool_ref` matching, no atom creation from untrusted input — NEVER `String.to_existing_atom` (0 occurrences in executable code)
- **T-13-06 (DoS/integrity — unknown-tool path):** Unknown tool rejected pre-persistence, 0 rows inserted — verified by `test "returns {:blocked, :unsupported, :unknown_tool} and inserts NO rows"`
- **T-13-07 (EoP — scope/policy gates):** Fail-closed `with` pipeline; scope checked before policy; deny-by-default `authorize/2` — verified by 4 distinct blocked-outcome tests + precedence test
- **T-13-08 (Repudiation — snapshots):** input/scope/policy snapshots written at propose time; `validate/3` is the only live-spec reader — history cannot be rewritten by config edits
- **T-13-09 (Repudiation — append-only events):** `timestamps(updated_at: false)`, no update/delete API — verified by `function_exported?` tests
- **T-13-10 (Information disclosure — telemetry):** Bounded allow-lists; observability-only alongside durable inserts

## Self-Check: PASSED

Files exist:
- lib/cairnloop/governance/tool_proposal.ex: FOUND
- lib/cairnloop/governance/tool_action_event.ex: FOUND
- lib/cairnloop/governance/policy.ex: FOUND
- lib/cairnloop/governance/telemetry.ex: FOUND
- lib/cairnloop/governance.ex: FOUND
- priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs: FOUND
- test/cairnloop/governance/tool_proposal_test.exs: FOUND
- test/cairnloop/governance/tool_action_event_test.exs: FOUND
- test/cairnloop/governance_test.exs: FOUND

Commits exist:
- 483e160: Task 1 — schemas + migration + changeset tests
- d3dc4ab: Tasks 2+3 — Policy + Telemetry + validate/3 + propose/3 + governance tests
