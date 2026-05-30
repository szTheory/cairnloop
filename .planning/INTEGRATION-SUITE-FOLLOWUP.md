# Follow-up: DB-backed `integration` CI suite — 10 failures (3 clusters)

**Status:** OPEN · **Filed:** 2026-05-30 · **Severity:** pre-existing (red since before v0.2.0)
**Owner:** unassigned · **Suggested tool:** `/gsd-debug`

## Why this exists

The `integration` job in `.github/workflows/ci.yml` (run via `mix test.integration`,
pgvector Postgres) reports **47 tests, 10 failures**. This has been red on every recent CI
run going back to 2026-05-27 — i.e. **v0.2.0 was published with it red**, because the old
tag-triggered `release.yml` never gated on CI.

As of the v0.2.1 release-automation work, `release_gate` (the single required status check
for branch protection) gates on the **headless** `phase-12-shift-left` suite only (218 tests,
green). **Once this suite is green, add `integration` to `release_gate.needs` in `ci.yml`** so
the gate becomes comprehensive.

The headless suite passing is a real signal: the v0.2.1 fixes (AUDIT-01 presenter, OPS
plugs/router macro, TECH-01 pagination) are covered there and pass. These 10 failures are in
the DB-backed legs and are **not** a v0.2.1 regression.

## The 3 clusters (investigated 2026-05-30, not yet fixed)

### Cluster A — `test/integration/tool_execution_worker_test.exs` (5 failures)
Lines 92, 146, 167, 361, 493. All fail `assert :ok = …` / `assert {:ok, _} = InternalNote.run(…)`
with `right: {:error, "conversation_id: is invalid"}`.

**Root cause:** fixture drift. The proposals built here use
`input_snapshot: %{conversation_id: "conv-001", …}` (hardcoded strings) but never insert a
matching `Conversation`, so the `cairnloop_messages.conversation_id` FK
(`priv/test_host/migrations/20260101000000_create_host_owned_tables.exs`) rejects the insert →
changeset error surfaced as `"conversation_id: is invalid"`.
**Fix sketch:** add a `conversation_fixture/1` to the shared `setup` block (~lines 82-86) and
reference `to_string(conversation.id)` in each proposal's `input_snapshot` — the pattern
`tool_execution_outcome_live_test.exs` already uses correctly (its ~lines 120-128). ~1 file.
The `[warning] Oban enqueue failed: No Oban instance named Oban` lines are **by-design noise**
(the library ships no Oban; `lib/cairnloop/application.ex` rescues the enqueue), not the cause.

### Cluster B — `test/integration/tool_execution_outcome_live_test.exs` (3 failures)
Lines 112/170 (`assert executed_approval.decided_by == "operator_42"`), 268/309 & 402/439
(`assert html =~ "Action completed"`). These DO create conversations and drive the worker via
`perform/1`. Needs its own root-cause: either real attribution/copy drift (does `decided_by`
persist through execute? does the Done-group card render "Action completed"?) or a fixture/
harness mismatch. **Unknown size.**

### Cluster C — `test/integration/audit_log_live_test.exs` (2 failures)
Line 74 (`refute html =~ "execution_succeeded"`) and line 102 (after filtering by "approved",
`refute html =~ "Executed"`). Uses an in-test `MockAuditor`; no conversations/worker.
`Cairnloop.Web.AuditLogPresenter` is **pure, total, and correct** — so the leak is in the
**AuditLogLive view template**, not the presenter: most likely the action-filter `<option>`
list emitting the raw atom name `execution_succeeded`, and the action filter not actually
narrowing rendered rows. Real-but-contained LiveView-wiring bug; modest size. (NOT the
systemic raw-term leak AUDIT-01 addressed — that path goes through the presenter, which is clean.)

## Done-when
- [ ] All 3 clusters green under `mix test.integration`.
- [ ] `integration` added to `release_gate.needs` in `.github/workflows/ci.yml`.
- [ ] (Optional) factor the conversation-fixture pattern so worker tests can't drift again.
