---
phase: 13-governed-tool-contract-proposal-records
verified: 2026-05-24T12:20:00Z
status: passed
score: 20/20 must-haves verified
overrides_applied: 0
---

# Phase 13: Governed Tool Contract & Proposal Records — Verification Report

**Phase Goal:** Host developers can define governed support tools and Cairnloop can create fail-closed proposals without executing them inline.
**Verified:** 2026-05-24T12:20:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | `%Cairnloop.Tool.Spec{}` is a pure defstruct with `@enforce_keys [:risk_tier, :approval_mode]` and no Ecto.Schema coupling (D-03, MCP-01) | VERIFIED | `lib/cairnloop/tool/spec.ex` — plain `defstruct` with 6 fields, `@enforce_keys [:risk_tier, :approval_mode]`, zero `use Ecto.Schema` occurrences |
| 2  | Declaring an invalid `risk_tier` or `approval_mode` fails the build with `CompileError` before runtime (D-02) | VERIFIED | `lib/cairnloop/tool.ex:84-94` — validation inside `defmacro __using__` body BEFORE `quote do`; `test/cairnloop/tool_test.exs` has 2 `assert_raise CompileError` + 4 `Code.compile_string` calls; all pass |
| 3  | A tool declaring no policy is denied by default — `authorize/2` returns `{:error, :no_policy_defined}` (D-16) | VERIFIED | `lib/cairnloop/tool.ex:115` injects default `def authorize(_actor_id, _context), do: {:error, :no_policy_defined}`; test confirmed via tool_test.exs |
| 4  | `approval_mode` is derived fail-closed from `risk_tier` when omitted; unknown/missing → `:always_block` (D-08/D-09/D-10/D-11) | VERIFIED | `lib/cairnloop/tool.ex:135-139` — `derive_approval_mode/1` with 5 clauses; final catch-all `def derive_approval_mode(_), do: :always_block`; all tiers tested in tool_test.exs |
| 5  | `changeset/2` remains a required, host-implemented callback — no default injected (D-04) | VERIFIED | `lib/cairnloop/tool.ex:48` declares `@callback changeset/2`; `quote do` block in `__using__` contains no `def changeset` |
| 6  | `can_execute?/2` removed; `execute/3` renamed `run/3`; `scope/0` and `authorize/2` added (D-05, D-06) | VERIFIED | `grep -rn "def can_execute?"` returns 0 in lib/; `@callback run/3` at line 42; `@callback scope/0` at line 54 |
| 7  | `ToolProposal` and `ToolActionEvent` schemas exist with correct structure, mirroring ReviewTask idiom (D-20, D-21) | VERIFIED | `lib/cairnloop/governance/tool_proposal.ex` — `schema "cairnloop_tool_proposals"` with discrete snapshots + Phase 16 reserved columns; `lib/cairnloop/governance/tool_action_event.ex` — `timestamps(updated_at: false)`, no update/delete API |
| 8  | `ToolActionEvent` is append-only: no `update/1`/`delete/1`, `timestamps(updated_at: false)` (D-21, Pitfall 4) | VERIFIED | `tool_action_event.ex:36` — `timestamps(type: :utc_datetime_usec, updated_at: false)`; grep returns 0 for `def update\|def delete` |
| 9  | `Governance.validate/3` is a pure, re-callable, ordered `with` pipeline — clause order enforces precedence `unsupported→needs_input→scope_invalid→policy_denied` (D-15, D-17) | VERIFIED | `lib/cairnloop/governance.ex:152-161` — 4-clause `with` pipeline; `else` clauses in exact locked order; no `repo()` call in `validate/3` or its gate helpers |
| 10 | An unknown tool name is rejected pre-persistence with telemetry only — NO proposal row (D-18, D-19) | VERIFIED | `governance.ex:182-185` — `:unsupported` branch calls `Telemetry.emit` and returns `blocked` with no insert; `governance_test.exs` asserts `Process.get(:tool_proposals, []) == []` for unknown tool |
| 11 | A registered tool that fails scope or policy IS persisted as a blocked proposal (D-18 Support-Truth Gate) | VERIFIED | `governance.ex:187-193` — `{:blocked, outcome, reason}` calls `propose_blocked/5` which inserts `ToolProposal{status: outcome}` + `:proposal_blocked` event; governance test covers both `scope_invalid` and `policy_denied` |
| 12 | `propose/3` co-commits proposal + `proposal_created` event synchronously; no Oban, no `run/3` (D-26) | VERIFIED | `governance.ex:229-243` — single `with` inserting proposal then event; `grep "Oban\|run(\|execute("` in governance.ex returns only comments/docs |
| 13 | Resolved `risk_tier` + `approval_mode` + `policy_snapshot` snapshotted at propose time; never re-read live (D-14, D-24) | VERIFIED | `governance.ex:85-101` — `build_validated_attrs/4` captures `spec.risk_tier`, resolved `approval_mode`, and builds 3 discrete snapshot maps; fields written to proposal row at insert time |
| 14 | Idempotency key is deterministic; duplicate propose returns existing proposal (D-25) | VERIFIED | `governance.ex:103-120` — `derive_idempotency_key/4` using `sha256(Jason.encode!(canonical))` with `deep_sort_map/1`; `propose_valid/4` does `get_by(idempotency_key)` pre-check; governance test asserts same id on second call |
| 15 | Tools resolved via `Atom.to_string` module-list match, never `String.to_existing_atom/1` (D-19) | VERIFIED | `tool_registry.ex:61` — `Enum.find(fn mod -> Atom.to_string(mod) == tool_ref end)`; `governance.ex:55` delegates to `ToolRegistry.find_tool_module/1`; zero executable occurrences of `String.to_existing_atom` in governance.ex or tool_registry.ex |
| 16 | `Governance.Policy.resolve/3` is the Phase 15 approval-resolver seam, referencing `derive_approval_mode/1` as fallback (D-12) | VERIFIED | `lib/cairnloop/governance/policy.ex:30-32` — `spec.approval_mode \|\| host_config_override(risk_tier) \|\| Cairnloop.Tool.derive_approval_mode(spec.risk_tier)`; `grep -c "derive_approval_mode"` returns 3 |
| 17 | `Governance.Telemetry` is bounded/allow-listed, emitted AFTER with-success, never instead of inserts (D-29) | VERIFIED | `telemetry.ex:42` guards `when event in @events`; `@allowed_outcomes` defined; `governance.ex:244-250` — `Telemetry.emit` after `with ... do` body; 2 `@allowed_outcomes` occurrences confirmed |
| 18 | `ToolRegistry.validate_configured_tools!/0` called at application boot; fails fast on misconfigured tool (D-07) | VERIFIED | `application.ex:14` — `Cairnloop.ToolRegistry.validate_configured_tools!()` called BEFORE `Supervisor.start_link/2`; tool_registry.ex raises `ArgumentError` on missing `__tool_spec__/0` |
| 19 | `execute_tool` LiveView handler uses `Governance.propose/3` — no `try/rescue`, no `run/3`/`execute/3`, no `String.to_existing_atom`, no optimistic UI (D-27, TOOL-02) | VERIFIED | `conversation_live.ex:173-186` — `case Cairnloop.Governance.propose(tool_ref, actor_id, context)`; no `try`, no `.execute(`, no `.run(`, no `String.to_existing_atom` in the handler region |
| 20 | CR-01 (tuple-flash crash) and CR-02 (blocked-proposal silent swallow) fixed with regression tests | VERIFIED | `conversation_live.ex:192-195` uses `inspect(reason)`; `governance.ex:347-354` has `else` clause in `insert_blocked_proposal`; CR-01 regression tests at `conversation_live_test.exs:964-1018`; CR-02 regression test in `governance_test.exs` |

**Score:** 20/20 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/cairnloop/tool/spec.ex` | Pure `%Cairnloop.Tool.Spec{}` struct (D-03, MCP-01) | VERIFIED | `defstruct` with 6 fields, `@enforce_keys [:risk_tier, :approval_mode]`, no Ecto.Schema |
| `lib/cairnloop/tool.ex` | Governed `Cairnloop.Tool` behaviour + compile-time macro | VERIFIED | `@callback run/3`, `@callback changeset/2`, `@callback scope/0`, `@callback authorize/2`; `derive_approval_mode/1`; `@optional_callbacks [preview: 1, custom_ui: 0]` |
| `lib/cairnloop/governance/tool_proposal.ex` | Durable proposal schema (status, snapshots, idempotency, Phase 16 seam) | VERIFIED | `schema "cairnloop_tool_proposals"`; `@status_values [:proposed,:needs_input,:scope_invalid,:policy_denied]`; 3 discrete snapshot fields; 4 reserved Phase 16 columns |
| `lib/cairnloop/governance/tool_action_event.ex` | Append-only event schema | VERIFIED | `timestamps(updated_at: false)`; no update/delete API; `from_status` nullable |
| `lib/cairnloop/governance/policy.ex` | `Policy.resolve/3` Phase 15 seam | VERIFIED | `def resolve/3` with 3-level precedence and `derive_approval_mode/1` fallback |
| `lib/cairnloop/governance/telemetry.ex` | Bounded governance telemetry | VERIFIED | `@events`, `@allowed_outcomes`, `@allowed_risk_tiers`, `@allowed_approval_modes`; guard `when event in @events` |
| `lib/cairnloop/governance.ex` | Narrow facade: `propose/3` + `validate/3` | VERIFIED | Both functions exported; `validate/3` pure (no repo); `propose/3` co-commits proposal + event |
| `priv/repo/migrations/20260524000000_add_tool_proposals_and_action_events.exs` | Migration with idempotency unique index + cascade FK | VERIFIED | `unique_index(:cairnloop_tool_proposals, [:idempotency_key])`; `on_delete: :delete_all`; `updated_at: false` |
| `lib/cairnloop/tool_registry.ex` | Evolved registry: `validate_configured_tools!/0`, `find_tool_module/1`, advisory `get_available_tools/2` | VERIFIED | All 3 functions present; `Atom.to_string` match only; no `String.to_existing_atom` |
| `lib/cairnloop/application.ex` | Boot-time `validate_configured_tools!()` call | VERIFIED | Line 14, BEFORE `Supervisor.start_link/2` |
| `lib/cairnloop/web/conversation_live.ex` | `execute_tool` handler → `Governance.propose/3` | VERIFIED | Lines 173-198; `failure_reason_message/2` with 5 clauses; `inspect(reason)` for non-string reasons |
| `test/cairnloop/tool_test.exs` | TOOL-01 contract tests | VERIFIED | 19 tests; `assert_raise CompileError` + `Code.compile_string`; `:no_policy_defined`; all 4 tiers |
| `test/cairnloop/governance/tool_proposal_test.exs` | TOOL-04 changeset tests | VERIFIED | Pure changeset tests; status enum bounds; snapshot fields |
| `test/cairnloop/governance/tool_action_event_test.exs` | TOOL-04 append-only changeset tests | VERIFIED | `from_status nil` valid; non-map metadata invalid; no update/delete exported |
| `test/cairnloop/governance_test.exs` | TOOL-02/03/04 governance tests under MockRepo | VERIFIED | MockRepo `Process.get/put`; all 4 validate outcomes; precedence; unknown-tool-no-row; co-commit; idempotency; blocked persistence; CR-02/WR-01/WR-02 regression guards |
| `test/cairnloop/tool_registry_test.exs` | Registry: find_tool_module, boot validation, advisory filter | VERIFIED | 5 tests; `find_tool_module/1`, `validate_configured_tools!/0`, scope+authorize filter |
| `test/cairnloop/web/conversation_live_test.exs` | TOOL-02 handler tests + CR-01 regression | VERIFIED | 29 tests; scope_invalid + policy_denied flash tests; proposal-first flash with id; no inline execution |

---

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| `lib/cairnloop/tool.ex (__using__)` | `lib/cairnloop/tool/spec.ex` | `%Cairnloop.Tool.Spec{}` in generated `__tool_spec__/0` | WIRED — `tool.ex:103-110` |
| `lib/cairnloop/tool.ex (__using__)` | `derive_approval_mode/1` | Called at macro-expansion time before `quote do` | WIRED — `tool.ex:96` |
| `lib/cairnloop/governance.ex (validate/3 gate 0)` | `lib/cairnloop/tool_registry.ex (find_tool_module/1)` | `resolve_tool/1` delegates to `ToolRegistry.find_tool_module/1` | WIRED — `governance.ex:55` |
| `lib/cairnloop/governance.ex (validate/3 gate 1)` | tool `changeset/2` callback | `validate_input/2` calls `tool_module.changeset(struct, params)` | WIRED — `governance.ex:62` |
| `lib/cairnloop/governance.ex (propose/3)` | `lib/cairnloop/governance/tool_action_event.ex` | Co-committed `proposal_created` event insert in `insert_new_proposal/5` | WIRED — `governance.ex:233-243` |
| `lib/cairnloop/governance/policy.ex (resolve/3)` | `lib/cairnloop/tool.ex (derive_approval_mode/1)` | `Cairnloop.Tool.derive_approval_mode(spec.risk_tier)` fallback | WIRED — `policy.ex:32` |
| `lib/cairnloop/governance.ex (propose/3)` | `lib/cairnloop/governance/telemetry.ex` | `Telemetry.emit` after `with` success (not inside clause list) | WIRED — `governance.ex:244-249` |
| `lib/cairnloop/web/conversation_live.ex (handle_event execute_tool)` | `lib/cairnloop/governance.ex (propose/3)` | `Cairnloop.Governance.propose(tool_ref, actor_id, context)` | WIRED — `conversation_live.ex:179` |
| `lib/cairnloop/application.ex (start/2)` | `lib/cairnloop/tool_registry.ex (validate_configured_tools!/0)` | Boot-time call before `Supervisor.start_link/2` | WIRED — `application.ex:14` |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `governance.ex propose/3` | `proposal` (ToolProposal) | `ToolProposal.changeset/2 \|> repo().insert()` | Yes — real insert path via configurable repo | FLOWING |
| `governance.ex validate/3` | `validated_attrs` | `build_validated_attrs/4` reading `tool_module.__tool_spec__()` and `Policy.resolve/3` | Yes — reads live spec and config | FLOWING |
| `conversation_live.ex execute_tool` | `proposal.id` | `Governance.propose/3` return value | Yes — proposal.id from inserted struct | FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `mix compile --warnings-as-errors` clean | `mix compile --warnings-as-errors; echo "EXIT:$?"` | EXIT:0, no output | PASS |
| All Phase 13 tests pass (108 tests) | `mix test test/cairnloop/tool_test.exs test/cairnloop/tool_registry_test.exs test/cairnloop/governance_test.exs test/cairnloop/governance/tool_proposal_test.exs test/cairnloop/governance/tool_action_event_test.exs test/cairnloop/web/conversation_live_test.exs` | 108 tests, 0 failures | PASS |
| Full suite: exactly 1 pre-existing failure | `mix test` | 1 doctest, 303 tests, 1 failure — `Cairnloop.Automation.DraftTest: changeset/2 requires content, status, and conversation_id` (pre-existing at baseline b5e5012) | PASS |
| No `can_execute?` in lib/ | `grep -rn "def can_execute?" lib/` | 0 results | PASS |
| No stale `.execute(` or `.run(` in governed tool path | `grep -rn "\.can_execute?\|\.execute(" lib/ \| grep -v "Telemetry\|telemetry"` | 0 results | PASS |
| No `String.to_existing_atom` in governance or registry | `grep -rn "String.to_existing_atom\|String.to_atom" lib/cairnloop/governance.ex lib/cairnloop/tool_registry.ex` | 2 results — both in comments only (one comment saying "NOT using it", one doc comment) | PASS |

---

### Probe Execution

No conventional `scripts/*/tests/probe-*.sh` probes declared for this phase. Step 7c: SKIPPED (no probe files declared).

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| TOOL-01 | 13-01-PLAN.md | Host developer can define a governed support tool with typed input validation, declared risk tier, approval mode, idempotency metadata, and structured result states | SATISFIED | `Cairnloop.Tool.Spec` + `Cairnloop.Tool` behaviour; compile-time enum validation; `__tool_spec__/0`; `derive_approval_mode/1`; 19 tool_test.exs tests green |
| TOOL-02 | 13-03-PLAN.md | System can propose a governed tool call from scoped conversation and account context without executing it inline | SATISFIED | `ConversationLive.handle_event("execute_tool")` calls `Governance.propose/3`; no `run/3`/`execute/3`; proposal id returned in flash; 5 propose-first tests in conversation_live_test.exs |
| TOOL-03 | 13-02-PLAN.md | Governed tool proposal fails closed with explicit outcomes | SATISFIED | `Governance.validate/3` — 4-clause `with` pipeline with locked precedence; all 4 outcomes covered and tested under MockRepo |
| TOOL-04 | 13-02-PLAN.md | Governed tool execution stores durable proposal and execution records plus append-only action events | SATISFIED | `ToolProposal` + `ToolActionEvent` schemas + migration; co-commit in single `with`; `timestamps(updated_at: false)`; idempotency unique index; changeset tests green |
| M011-S01-01 | Roadmap | Extend the tool contract with risk tier, approval mode, idempotency, preview, and structured result metadata | SATISFIED | Full governed `Cairnloop.Tool` + `Cairnloop.Tool.Spec` evolution; preview/1 optional callback as Phase 14 seam |
| M011-S01-02 | Roadmap | Add durable proposal, action-event, and run records plus the public governed-action facade | SATISFIED | `Cairnloop.Governance` facade with `propose/3` + `validate/3`; `ToolProposal` + `ToolActionEvent`; migration; Phase 16 reserved columns |
| M011-S01-03 | Roadmap | Replace direct `execute_tool` entrypoints with proposal-first, fail-closed action creation and scope validation | SATISFIED | `ConversationLive` handler replaced; boot validation wired; gate-0 delegated to `find_tool_module/1` |

No orphaned requirements — all 4 TOOL requirements and all 3 M011-S01 plan IDs are claimed and verified.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `lib/cairnloop/web/conversation_live.ex` | 391 | `placeholder=` HTML attribute in textarea | Info | Template attribute only — not a code stub |
| `lib/cairnloop/web/conversation_live.ex` | 747 | `String.to_existing_atom/1` present in file | Info | In a different function (map key atomization), NOT the `execute_tool` handler. Plan note explicitly permitted this line. Handler region verified clean. |
| `lib/cairnloop/application.ex` | 45-49 | Bare `rescue _ -> :ok` in Oban insert (WR-05) | Warning | Pre-existing defect outside Phase 13 scope. Swallows failed Oban job enqueue silently. Not introduced by Phase 13. |

No TBD/FIXME/XXX debt markers found in any Phase 13 modified files.

WR-05 (`handle_conversation_resolved/4` bare rescue) is a pre-existing defect outside Phase 13's scope. IN-04 (tool form input reset on re-render), IN-02, and IN-03 were explicitly deferred by the review fix report as out of scope.

---

### Human Verification Required

None. All must-haves are verifiable programmatically for this phase's scope.

The migration (`20260524000000_add_tool_proposals_and_action_events.exs`) requires a live Postgres database to execute. Per `13-VALIDATION.md` and the plan's stated no-DB caveat (STATE.md), DB-level proof is deferred: real constraint enforcement, `on_conflict` duplicate resolution at the Postgres level, and DB-level append-only are manual-only verifications to run with `mix test --only db` in a live-repo environment. This is not a gap — it is explicitly documented and scoped out per the phase design.

---

## Gaps Summary

None. All 20 must-have truths are VERIFIED, all artifacts pass all three levels (exists, substantive, wired), all key links are WIRED, no debt markers found, and both BLOCKER code review findings (CR-01, CR-02) are confirmed fixed with regression tests.

---

_Verified: 2026-05-24T12:20:00Z_
_Verifier: Claude (gsd-verifier)_
