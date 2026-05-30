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

- **Cluster C — `audit_log_live_test.exs` (2) — FIXED (pending CI confirm), commit `1bf9ba8`.**
  Both `refute`s leaked via the action-filter dropdown. (1) `<option value={action}>` emitted the
  raw atom (`execution_succeeded`) → now `value={Presenter.action_label(action)}` and the filter
  matcher compares the humanized label; the filter test now submits `"Approved"` (what the
  humanized control emits), not raw `"approved"`. (2) `action_options` was derived from ALL events
  so a filtered-out action's label persisted → derive from the FILTERED set. Also repaired the
  metadata expander: `<details :if={has_metadata?(event.action) && false}>` (wrong arg + dead
  `&& false`) meant "View details" never rendered — collapsed the doubled `<details>` into one
  keyed on `event.metadata`.

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
