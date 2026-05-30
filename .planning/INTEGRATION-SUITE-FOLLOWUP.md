# Follow-up: DB-backed `integration` CI suite — failures (3 clusters)

**Status:** IN PROGRESS · **Filed:** 2026-05-30 · **Branch:** `fix/integration-suite` (PR #6)
**Severity:** pre-existing (red since before v0.2.0) · **Suggested tool:** `/gsd-debug`

---

## ▶ RESUME HERE (read this first after a context clear)

**One-liner state:** v0.2.1 is already shipped to hex.pm via the release-please pipeline (DONE,
don't touch). The ONLY open work is greening this DB-backed `integration` suite on branch
**`fix/integration-suite`** (PR #6, open, NOT merged). Latest CI: **6 failures left** (down from 10).

**To resume, first do this (verbatim):**
1. `cd /Users/jon/projects/cairnloop && git checkout fix/integration-suite && git pull`
2. Read this whole file. The DB suite CANNOT run locally (no pgvector `vector` extension) — **CI
   is the only verifier.** Use `gh run view <id> --log-failed` and inspect via the `Read` tool,
   NOT shell grep/cat (this session's shell corrupted output with NUL/ANSI).
3. Work the remaining failures (Cluster B + the tails of A & C — see Progress below), one edit →
   compile (`mix compile --warnings-as-errors`) + `mix format` → commit → push → watch the
   `integration` job on PR #6. Iterate until **0 failures**.
4. When `mix test.integration` is green in CI: add `integration` to `release_gate.needs` in
   `.github/workflows/ci.yml`, push, then merge PR #6 (`gh pr merge 6 --merge`).
5. Update this file's Done-when boxes; optionally then `/gsd-complete-milestone vM015`.

**Autonomy:** the owner wants this driven autonomously (decide + proceed; don't ask per-step).
Only escalate a genuinely irreversible/scope call. Keep commits atomic and conventional.

**Working tree is clean and pushed as of the pause** (branch tip was `bbdee52`).

---

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

- **Cluster B — `tool_execution_outcome_live_test.exs` (3) — NOT STARTED (real logic work).**
  - **2× `assert html =~ "Action completed"`** (Done-group test :268 + chip-text test :402,
    both mount `/governance/:id` = `Cairnloop.Web.ConversationLive`, route confirmed in
    `lib/cairnloop/router.ex:51`). CORRECTION to an earlier note: the string DOES exist —
    `lib/cairnloop/web/tool_proposal_presenter.ex:174` (`"Action completed: #{summary || "Done."}"`)
    and `:385` (`"Action completed (attempt #{attempt})."`). So this is a **render-wiring gap**:
    `ConversationLive` isn't surfacing that presenter text for an `:executed` approval's Done-group
    card. Next: read `conversation_live.ex` (how it renders the Done group / governed-action card
    for executed approvals) and wire in the presenter's executed-outcome text. Brand: name the
    state in text, not color-alone; use `var(--cl-primary)` token (the test also asserts that).
  - **1× `assert executed_approval.decided_by == "operator_42"`** (OBS-02, test :112): real
    attribution logic — does `Governance.approve(approval.id, "operator_42", ...)` persist
    `decided_by` through the resume→execute co-commit so it survives to `:executed`? Investigate
    `Governance.approve` + `ToolExecutionWorker` co-commit; not a rendering issue.

## Done-when
- [ ] Cluster A fully green (4/5 done; recheck the InternalNote idempotency test — the FK-drift
      theory was incomplete for that one specifically).
- [ ] Cluster C fully green (dropdown raw-atom leak done; "View details" expander + filter test
      still red).
- [ ] Cluster B green (Done-group "Action completed" render wiring + OBS-02 `decided_by`).
- [ ] `integration` added to `release_gate.needs` in `.github/workflows/ci.yml`.
- [ ] PR #6 merged.

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
