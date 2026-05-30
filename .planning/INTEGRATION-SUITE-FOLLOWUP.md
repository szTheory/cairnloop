# Follow-up: DB-backed `integration` CI suite — failures (3 clusters)

**Status:** IN PROGRESS · **Filed:** 2026-05-30 · **Branch:** `fix/integration-suite` (PR #6)
**Severity:** pre-existing (red since before v0.2.0) · **Suggested tool:** `/gsd-debug`

## Why this exists

The `integration` job in `.github/workflows/ci.yml` (run via `mix test.integration`,
pgvector Postgres) was **47 tests, 10 failures**, red since before v0.2.0 (which shipped
under the same condition because the old tag-publish never gated on CI). `release_gate`
gates on the **headless** suite only; **add `integration` to `release_gate.needs` once green.**

NOTE: this suite cannot run in the dev workspace (Postgres is up but the `vector` extension
isn't installed; a Phase-16 migration does `CREATE EXTENSION vector`). **CI is the only verifier.**

## Progress

- **Cluster A — `tool_execution_worker_test.exs` (5) — FIXED (CI-verified 10→6).**
  Fixture drift: `cairnloop_messages.conversation_id` is an integer FK; tests used hardcoded
  string ids (`"conv-001"`) with no Conversation row → `{:error, "conversation_id: is invalid"}`.
  Fix: shared `setup` inserts a `conversation_fixture()`; the 5 message-inserting tests use
  `to_string(conversation.id)`. (Non-inserting FailOnceTool tests `conv-transient`/`conv-retry`
  unchanged — they never reach the FK.) Commits `98d1b78`, `bc663f1`, `cc9b874`.

- **Cluster C — `audit_log_live_test.exs` (2) — PARTIALLY fixed, commit `1bf9ba8`. STILL RED.**
  The action-filter raw-atom leak IS fixed (CI-confirmed: test :62 now fails LATER, at line 78,
  not at the `refute "execution_succeeded"` on line 74). What's done: `<option value={action}>`
  → `value={Presenter.action_label(action)}`; the filter matcher compares the humanized label;
  the filter test submits `"Approved"` not raw `"approved"`; `action_options` now derived from the
  FILTERED set so a filtered-out action's label doesn't persist.
  **STILL FAILING:** `assert html =~ "View details"` (test :62, line 78) and the filter test
  (:95). The metadata expander at `audit_log_live.ex:158` LOOKS correct
  (`<details :if={Presenter.has_metadata?(event.metadata)}><summary>View details</summary>`) and
  the MockAuditor events carry non-empty metadata (`%{proposal_id: 1}`), so `has_metadata?` should
  be true — yet "View details" doesn't render. **Next:** add a temporary CI render-trace (or check
  for a SECOND stray `<details … && false>` / event-shape issue) to find why `has_metadata?(
  event.metadata)` is false at render. Don't trust local greps — the dev shell corrupted output
  this session; use the `Read` tool.

- **Cluster B — `tool_execution_outcome_live_test.exs` (3) — NOT FIXED (real logic work).**
  - **2× `assert html =~ "Action completed"`** (Done-group + chip-text tests, mounting
    `/governance/:id`): the string **"Action completed" exists nowhere in `lib/`**. Either the
    governed-action Done-group card must render that chip text for an `:executed` approval and
    doesn't (impl gap — add it to the card/`tool_proposal_presenter.ex`), or the tests assert the
    wrong copy. Needs: read `lib/cairnloop/web/conversation_live.ex` Done-group card +
    `lib/cairnloop/web/tool_proposal_presenter.ex` chip/status functions; decide the canonical
    executed-state chip text and make card + test agree (brand: name the state, not color-alone).
  - **1× `assert executed_approval.decided_by == "operator_42"`** (OBS-02): real attribution
    logic — does `Governance.approve(approval.id, "operator_42", ...)` persist `decided_by`
    through the resume→execute co-commit? Investigate `Governance.approve` + `ToolExecutionWorker`
    co-commit; not a rendering issue.

## Done-when
- [ ] Cluster B green (Done-group chip text + OBS-02 `decided_by`).
- [x] Cluster A green (CI-verified).
- [ ] Cluster C green (awaiting CI on `1bf9ba8`).
- [ ] `integration` added to `release_gate.needs` in `.github/workflows/ci.yml`.
- [ ] PR #6 merged.

## Environment caveats (this session)
Network was flaky (`gh` intermittently failing) and shell output intermittently corrupted
(NUL/ANSI, garbled line numbers, even a fabricated grep line). Use the `Read` tool for source,
not shell `grep`/`cat`; verify CI via `gh run view --log-failed` then read the saved file.
Cluster B was deferred rather than risk unverifiable edits under these conditions.
