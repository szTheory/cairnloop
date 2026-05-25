---
phase: 16-first-approved-write-path-telemetry
reviewed: 2026-05-25T00:00:00Z
depth: standard
files_reviewed: 22
files_reviewed_list:
  - config/config.exs
  - lib/cairnloop/governance.ex
  - lib/cairnloop/governance/telemetry.ex
  - lib/cairnloop/governance/tool_action_event.ex
  - lib/cairnloop/governance/tool_approval.ex
  - lib/cairnloop/message.ex
  - lib/cairnloop/tool_registry.ex
  - lib/cairnloop/tools/internal_note.ex
  - lib/cairnloop/web/conversation_live.ex
  - lib/cairnloop/web/tool_proposal_presenter.ex
  - lib/cairnloop/workers/approval_resume_worker.ex
  - lib/cairnloop/workers/tool_execution_worker.ex
  - priv/repo/migrations/20260525000000_add_execution_outcome_index.exs
  - priv/test_host/migrations/20260525000001_add_run_key_to_messages.exs
  - test/cairnloop/governance/telemetry_test.exs
  - test/cairnloop/governance/tool_action_event_test.exs
  - test/cairnloop/governance/tool_approval_test.exs
  - test/cairnloop/web/tool_proposal_presenter_test.exs
  - test/cairnloop/workers/tool_execution_worker_test.exs
  - test/integration/tool_execution_outcome_live_test.exs
  - test/integration/tool_execution_worker_test.exs
  - test/support/fixtures.ex
findings:
  critical: 2
  warning: 6
  info: 4
  total: 12
status: resolved
---

# Phase 16: Code Review Report

> **Resolution (2026-05-25):** Both BLOCKERs (CR-01, CR-02) and warnings WR-02/03/04/05/06 plus
> IN-02 fixed in commits `8ec82b1`, `60c014a`, `4e92c00`, `10e9364`, `1f5e235`, `33a56f2`; CR-01
> proven by a strengthened headless presenter test. WR-01 and IN-01/IN-04 were intentionally NOT
> changed: WR-01 (per-attempt run-key) is the planner's explicit design and the only shipped tool
> (`InternalNote`) is an atomic single-insert — documented as an atomicity precondition (`f500b25`)
> rather than churned, since changing it would contradict 16-02's locked tests. Build warnings-clean;
> headless suite green except the known `DraftTest` baseline.

**Reviewed:** 2026-05-25
**Depth:** standard
**Files Reviewed:** 22
**Status:** issues_found

## Summary

Phase 16 builds the first governed write path: a dedicated `ToolExecutionWorker` as the sole `run/3` caller, three-layer at-most-once defense, bounded observability-only telemetry, and operator-surface reflection of execution outcomes. The telemetry boundary is well-guarded (allow-listed low-cardinality labels, no actor_id/conversation_id leakage, registry-bounded tool_ref), the append-only audit posture is honored, and reads go through the narrow `Cairnloop.Governance` facade.

However, the operator-surface reflection of the success outcome is **broken**: the presenter reads `result_summary` from a field that does not exist on `ToolApproval`, and the only facade path that resolves an active approval for rendering filters to `:pending` only — so the executed/failed terminal outlook is never resolved unless the association happens to be preloaded. The integration tests assert weak substrings (`"Action completed"`) that pass against the broken fallback, so the defect is not caught. There is also a real (if narrow) at-most-once gap in the per-attempt run-key design for non-atomic tools.

## Critical Issues

### CR-01: Presenter reads `result_summary` from `ToolApproval`, which has no such field — success summary is never shown

**File:** `lib/cairnloop/web/tool_proposal_presenter.ex:162-165`
**Issue:**
`approval_outlook_for_approval/1` for `:executed` reads the result summary off the approval struct:

```elixir
def approval_outlook_for_approval(%{status: :executed} = approval) do
  summary = Map.get(approval, :result_summary) || Map.get(approval, "result_summary")
  "Action completed: #{summary || "Done."}"
end
```

But `ToolApproval` (`lib/cairnloop/governance/tool_approval.ex:49-64`) defines **no `result_summary` field**. The worker stores the humanized summary on the *proposal* (`proposal_cs result_summary:` — `tool_execution_worker.ex:153`) and, on the approval, in the `:reason` field (`decision_changeset(approval, :executed, "executed", result_summary, ...)` — `tool_execution_worker.ex:146-148`). Therefore `Map.get(approval, :result_summary)` is always `nil` and the outlook is permanently `"Action completed: Done."` — the operator never sees the actual humanized result (e.g. `"Note written (id: 42)."`). This directly violates the carried decision "render from durable snapshot columns (result_summary/reason)" — the snapshot was written but the read targets the wrong field. The integration test (`tool_execution_outcome_live_test.exs:281`) only asserts `html =~ "Action completed"`, which the broken fallback still satisfies, so the bug is masked.

**Fix:** Read the summary from the durable column that actually holds it. Either read the approval's `:reason` (where the worker stored `result_summary`):

```elixir
def approval_outlook_for_approval(%{status: :executed} = approval) do
  summary = Map.get(approval, :reason) || Map.get(approval, "reason")
  "Action completed: #{summary || "Done."}"
end
```

or change the worker to render the executed card from `proposal.result_summary` and pass the proposal to the presenter. Then tighten the test to assert the actual humanized summary text, not just `"Action completed"`.

### CR-02: Executed/failed terminal outlook is unreachable when the approval is not preloaded — `get_active_approval/1` filters to `:pending`

**File:** `lib/cairnloop/governance.ex:507-509`; `lib/cairnloop/web/conversation_live.ex:942-963`
**Issue:**
In `governed_action_card/1` the active approval is resolved with a fallback to the facade when not preloaded:

```elixir
true ->
  # Not preloaded — resolve via facade (D15-17)
  Cairnloop.Governance.get_active_approval(proposal.id)
```

`get_active_approval/1` is hard-filtered to `:pending`:

```elixir
def get_active_approval(tool_proposal_id) do
  repo().get_by(ToolApproval, tool_proposal_id: tool_proposal_id, status: :pending)
end
```

An `:executed` or `:execution_failed` approval is never `:pending`, so this branch returns `nil` for any terminal lane. When that branch is taken (association not preloaded — e.g. any caller of `governed_action_card` that does not use `list_proposals_for_conversation`'s preload, including the `render_component` path the codebase explicitly supports and the `Map.put_new(:governed_actions, [])` default at `conversation_live.ex:341`), `active_approval` is `nil`, so `approval_outlook` falls back to the future-tense `approval_outlook/1` honesty seam (`conversation_live.ex:958-963`) and the terminal execution outcome (`"Action completed"` / `"Action failed"`) is never displayed. The operator surface silently regresses to pre-execution copy for completed actions. The render is only correct by accident of the one preload path; the documented facade fallback is wrong for exactly the states Phase 16 introduces.

**Fix:** Provide a facade read that returns the single approval for a proposal regardless of status (the one-active-lane index already guarantees at most one non-terminal lane; terminal lanes are also unique per proposal in practice). For example:

```elixir
def get_latest_approval(tool_proposal_id) do
  ToolApproval
  |> where([a], a.tool_proposal_id == ^tool_proposal_id)
  |> order_by([a], desc: a.updated_at)
  |> limit(1)
  |> repo().one()
end
```

and call it from the not-preloaded branch in `governed_action_card/1`, or keep `get_active_approval/1` for the footer affordance but use the status-agnostic read for the outlook line.

## Warnings

### WR-01: Per-attempt run-key weakens at-most-once for non-atomic tools

**File:** `lib/cairnloop/workers/tool_execution_worker.ex:359-362`, `121`
**Issue:**
`derive_run_key/1` composes the key from `proposal.attempt`, so each Oban retry passes a **different** `:run_idempotency_key` into `run/3`:

```elixir
defp derive_run_key(proposal) do
  raw = "#{proposal.idempotency_key}::attempt::#{proposal.attempt}"
  :crypto.hash(:sha256, raw) |> Base.encode16(case: :lower)
end
```

The documented purpose of layer 3 (the run-level idempotency key) is at-most-once at the tool's own write. But if a tool's `run/3` performs its host write and then returns `{:error, reason}` for a *post-write* failure (e.g. a secondary write or a serialization error after the row insert), the transient-failure path increments `proposal.attempt` and the Oban retry derives a *new* key. The tool's existence check (`InternalNote.run/3`, `internal_note.ex:82`) keys on `run_key`, so the retry finds no prior row and writes a **second** row — a double-write. The three-layer defense is only at-most-once for tools whose `run/3` is a single atomic insert (which InternalNote is). The comment at `tool_execution_worker.ex:118-121` frames the per-attempt key as a feature ("a prior failed attempt's existence record does not block the retry"), but that is precisely what allows duplicate writes for non-atomic tools. For a reference implementation that hosts are told to copy, this is a latent foot-gun.

**Fix:** Use a key that is stable across retries of the same logical execution (e.g. derive from `proposal.idempotency_key` alone, dropping the `::attempt::` component), so a retry of a partially-completed write hits the existence check. If attempt-scoping is truly needed for some tools, document the atomicity precondition explicitly in `InternalNote` and `Cairnloop.Tool` so host authors know their `run/3` must be a single atomic write.

### WR-02: Execution worker has no `expires_at` lazy guard before executing

**File:** `lib/cairnloop/workers/tool_execution_worker.ex:53-67`
**Issue:**
`ApprovalResumeWorker.perform/1` fires a lazy `expires_at` guard before re-validating (`approval_resume_worker.ex:57-61`) "so a missed scheduled sweep can never let a stale approval execute." `ToolExecutionWorker.perform/1` has no equivalent guard — it only checks `status == :execution_pending`. Because the resume worker transitions `:approved -> :execution_pending` and enqueues the execution worker, an approval can sit in `:execution_pending` arbitrarily long (queue backlog, retry backoff, paused queue). If the lane's TTL elapses while it waits, the execution worker will still execute it. Re-validation runs `Governance.validate/3`, which checks scope/policy but NOT `expires_at` (TTL is an approval-record concern, not a validation gate), so an expired-but-pending lane executes anyway. This is a fail-closed gap relative to the resume worker's stated belt-and-suspenders posture.

**Fix:** Add the same lazy guard at the top of `execute_pending/4` (or `perform/1`): if `approval.expires_at && DateTime.before?(approval.expires_at, DateTime.utc_now())`, record a terminal `:expired`/`:invalidated` outcome and `{:cancel, ...}` instead of executing.

### WR-03: `record_success` co-commit is not transactional — partial writes leave inconsistent state

**File:** `lib/cairnloop/workers/tool_execution_worker.ex:167-185` (and `record_terminal_failure/4` 281-288, `handle_transient_failure/6` 215-230, 247-253)
**Issue:**
The "co-commit" of approval-update + proposal-update + event-insert is a bare sequential `with` over three separate `repo()` calls — there is no surrounding `Repo.transaction/1`. If `run/3` succeeds and writes the host row, then `repo().update(approval_cs)` succeeds but `repo().update(proposal_cs)` fails (e.g. DB blip), the approval is now `:executed` while `proposal.result_state` is still `:not_executed` and no `:execution_succeeded` event exists. On replay, LAYER-1 sees `status != :execution_pending` → no-op, and LAYER-2 (`proposal.result_state == :succeeded`) is false — so the durable record is permanently inconsistent (approval says executed, proposal/audit say not). The phase's own correctness criterion ("Durable Ecto records + events are workflow truth") depends on these being atomic. The Phase 15 facade helpers it claims to mirror (`update_approval_with_event/3`) are two-step too, but there the failure surface is smaller; here three records plus a real side effect are at stake.

**Fix:** Wrap the three writes in `repo().transaction/1` (Ecto.Multi or a transaction closure) so the outcome is all-or-nothing. The host side effect from `run/3` is already idempotency-guarded by the run_key, so a transaction rollback + retry is safe.

### WR-04: `handle_transient_failure` ignores co-commit failures and returns success-shaped control values

**File:** `lib/cairnloop/workers/tool_execution_worker.ex:215-232`, `247-256`
**Issue:**
Both branches build a `with` whose result is discarded; the function's return value is the hard-coded `{:cancel, humanized}` / `{:error, humanized}` after the `with`:

```elixir
with {:ok, _} <- repo().update(approval_cs),
     {:ok, _} <- repo().update(proposal_cs),
     {:ok, _} <- ... insert event do
  GovTelemetry.emit(...)
  broadcast_execution_failed(...)
end

{:cancel, humanized}
```

If any of the three writes fails, the `with` returns the `{:error, changeset}` (which is silently dropped), telemetry/broadcast do not fire, but the function still returns `{:cancel, humanized}` (terminal branch) telling Oban to discard the job. The terminal `:execution_failed` state was never persisted, yet the job is discarded — the lane is now stuck in `:execution_pending` forever with no further retry. The transient branch has the mirror problem: it returns `{:error, humanized}` (retry) even when the attempt-increment co-commit failed, so `proposal.attempt` may not advance and retries can loop. The control-flow decision (cancel vs retry) must depend on whether the durable write succeeded.

**Fix:** Make the return value depend on the `with` result, e.g. `case (with ... do ... end) do {:ok, _} -> {:cancel, humanized}; _ -> {:error, :persist_failed} end`, so a failed terminal co-commit retries rather than silently discarding the job.

### WR-05: `humanize_result` interpolates arbitrary map values into operator copy

**File:** `lib/cairnloop/workers/tool_execution_worker.ex:331-345`
**Issue:**
The generic fallback for a non-`message_id`/`idempotent` map dumps every key/value via interpolation:

```elixir
map when is_map(map) ->
  map
  |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
  |> Enum.join(", ")
```

`"#{v}"` calls `String.Chars` on `v`. If a tool's `run/3` returns `{:ok, %{detail: %{...}}}` or `{:ok, %{count: [1,2]}}` (a non-`String.Chars` term), this raises `Protocol.UndefinedError` *inside the success co-commit*, turning a successful side effect into a crash — and because the host row was already written, the retry path may not cleanly re-run. Even for `String.Chars`-able values, this leaks raw-ish term text into a durable operator-visible `result_summary` column, contrary to the "humanize; never raw terms to operators" posture. This is a reference implementation hosts will copy.

**Fix:** Restrict the generic branch to known scalar shapes and fall back to `"Completed."` otherwise, or guard with `to_string/1` inside a `try`. Do not blindly interpolate arbitrary map values.

### WR-06: `policy_explanation/1` requires a non-empty `reason` to recognize a policy denial, mislabeling denials with no reason text

**File:** `lib/cairnloop/web/tool_proposal_presenter.ex:272-289`
**Issue:**
The `:policy_denied` branch only matches when `is_binary(reason) and reason != ""`:

```elixir
outcome in [:policy_denied, "policy_denied"] and is_binary(reason) and reason != "" ->
  "This action was blocked by a policy gate."
```

A blocked proposal persisted by `insert_blocked_proposal/10` sets `policy_snapshot: %{outcome: outcome, reason: reason_str}` (`governance.ex:442`). When `reason_str` resolves to `""` (e.g. an empty changeset traverse or a fallback), `outcome` is `:policy_denied` but the reason is empty, so this clause is skipped and execution falls through to the `:proposed`/`nil` branch only if outcome matches — actually it lands in the final `true ->` "Policy details are not available." That is a misleading message: a policy-denied action is shown as "details not available" rather than "blocked by a policy gate." The reason text should not gate the *recognition* of the outcome.

**Fix:** Drop the `reason` condition from the recognition: `outcome in [:policy_denied, "policy_denied"] -> "This action was blocked by a policy gate."` Use the reason only to enrich the sentence, not to decide whether the denial is recognized.

## Info

### IN-01: `execute_approved/2` enqueues but its companion guard accepts only `:execution_pending` — no path sets `:execution_pending` via this API

**File:** `lib/cairnloop/governance.ex:808-834`
**Issue:** `execute_approved/2` requires the approval to already be `:execution_pending`, but the only producer of `:execution_pending` is `ApprovalResumeWorker.transition_approval/5`, which then directly `safe_enqueue`s the execution worker itself (`approval_resume_worker.ex:86-89`). So `execute_approved/2` is effectively dead for the live flow and exists only for the test asserting it is exported (`tool_execution_worker_test.exs:489-494`). It also emits an `:execution_started` event that the normal flow never emits, creating two divergent audit trails depending on which path runs.
**Fix:** Either remove `execute_approved/2` or document it as an explicit operator/admin re-enqueue API and ensure its audit trail matches the resume-worker path (or have the resume worker call it, single source of truth).

### IN-02: `broadcast_executed/2` / `broadcast_execution_failed/2` ignore the `proposal` arg name and broadcast to a possibly-nil conversation topic

**File:** `lib/cairnloop/workers/tool_execution_worker.ex:396-414`
**Issue:** `topic = "conversation:#{proposal.conversation_id}"`. For pre-Phase-14 proposals `conversation_id` is nullable (`tool_proposal.ex` belongs_to is nullable). A nil interpolates to `"conversation:"`, broadcasting to a junk topic. Harmless (no subscriber) but indicates the broadcast is not guarded; the LiveView reload it is meant to trigger will never reach the right surface for a null-conversation proposal.
**Fix:** Skip the broadcast when `conversation_id` is nil.

### IN-03: Integration tests assert only weak substrings, masking CR-01/CR-02

**File:** `test/integration/tool_execution_outcome_live_test.exs:281`, `355`, `399`
**Issue:** The "humanized result_summary" assertions check `html =~ "Action completed"`, which is satisfied by the broken `"Action completed: Done."` fallback. No test asserts the actual computed summary string (e.g. `"Note written"`), so the CR-01 field-name bug and the CR-02 unreachable-outlook bug both pass the suite. The test docstring claims to prove "humanized result_summary" but does not.
**Fix:** Assert the specific humanized text the worker computes (set a deterministic `run/3` return and assert that summary appears in the rendered HTML), and add a test that exercises the not-preloaded card path.

### IN-04: `config/config.exs` comment over-promises registry resolution behavior

**File:** `config/config.exs:7`
**Issue:** The comment "The ToolRegistry resolves modules by Atom.to_string comparison — never String.to_existing_atom" is accurate for `find_tool_module/1`, but `ConversationLive.to_result/1` (`conversation_live.ex:1291`) and `ApprovalResumeWorker.rebuild_context_from_snapshot/1` (`approval_resume_worker.ex:115`) both use `String.to_existing_atom/1` elsewhere in the governed path. The blanket claim in config is misleading to a reader auditing the atom-safety posture.
**Fix:** Scope the comment to tool-module resolution, or note the `String.to_existing_atom`-with-rescue pattern used for scope/evidence rehydration.

---

_Reviewed: 2026-05-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
