---
phase: 15-approval-state-machine-oban-resume
reviewed: 2026-05-24T00:00:00Z
depth: standard
files_reviewed: 12
files_reviewed_list:
  - lib/cairnloop/governance.ex
  - lib/cairnloop/governance/policy.ex
  - lib/cairnloop/governance/preview.ex
  - lib/cairnloop/governance/tool_action_event.ex
  - lib/cairnloop/governance/tool_approval.ex
  - lib/cairnloop/governance/tool_proposal.ex
  - lib/cairnloop/web/conversation_live.ex
  - lib/cairnloop/web/tool_proposal_presenter.ex
  - lib/cairnloop/workers/approval_expiry_worker.ex
  - lib/cairnloop/workers/approval_resume_worker.ex
  - priv/repo/migrations/20260524120000_add_tool_approvals.exs
  - priv/repo/migrations/20260524120100_add_snapshot_cols_to_proposals.exs
findings:
  critical: 2
  warning: 7
  info: 4
  total: 13
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-05-24
**Depth:** standard
**Files Reviewed:** 12
**Status:** issues_found

## Summary

Reviewed the Phase 15 approval state machine + Oban resume implementation. The
core invariants are largely honored: `approve/3` never calls `run/3` (APRV-01 —
record-before-enqueue ordering is correct), the resume worker re-validates
against current context and fails closed to `:invalidated` (APRV-03), the lazy
`expires_at` guard fires before re-validation (D15-12), reason humanization uses
`traverse_errors` rather than `inspect/1` (D15-15/WR-01), approval surfaces read
snapshotted `proposal.title`/`rendered_consequence` (D15-14), and all status
transitions are guarded on `status == :pending`.

However, the adversarial pass surfaced two correctness defects that ship working
code with broken contracts, plus several robustness and durability gaps. The two
blockers are: (1) `request_approval/2` does NOT enforce the `:requires_approval`
guard its own docstring guarantees (D15-05), so an approval lane can be opened
for `:auto`/`:always_block` proposals; and (2) `status_group/1` handles the
non-existent atom `:pending_approval` but not the real approval status `:pending`
(nor `:approved`), so a `:pending` approval status routed through that function
falls to the `:blocked` catch-all — a state-classification bug that also risks
state-by-color-alone display.

## Critical Issues

### CR-01: `request_approval/2` does not enforce the `:requires_approval` guard it documents (D15-05)

**File:** `lib/cairnloop/governance.ex:530-574`
**Issue:** The moduledoc (L521-522) and the function `@doc` both state: *"Only
opens a lane for `:requires_approval` proposals; `:auto`/`:always_block` lanes are
never opened here (D15-05)."* The function body has **no guard** on
`proposal.approval_mode`. It unconditionally inserts a `:pending` `ToolApproval`
and an `:approval_requested` event for any proposal passed to it — including
`:auto` (which should never need approval) and `:always_block` (which must never
become approvable). Combined with `approve/3`, which also does not check
`approval_mode`, an `:always_block` proposal can be pushed all the way to
`:execution_pending` via: `request_approval` → `approve` → resume worker
re-validate. That breaks the fail-closed governance posture: an action the policy
declared un-runnable can reach the execution seam. The docstring guarantee is
simply false.
**Fix:** Add an explicit guard at the top of `request_approval/2`:
```elixir
def request_approval(%{approval_mode: :requires_approval} = proposal, opts) do
  # ... existing body ...
end

def request_approval(%{approval_mode: mode}, _opts)
    when mode in [:auto, :always_block] do
  {:error, :not_approvable}
end
```
Also harden `approve/3` to refuse approvals whose proposal is `:always_block`
(re-read the proposal or denormalize approval_mode onto the approval), so the
guarantee holds even if a lane was opened out-of-band.

### CR-02: `status_group/1` is keyed on a nonexistent atom (`:pending_approval`); the real `:pending` (and `:approved`) approval status falls through to `:blocked`

**File:** `lib/cairnloop/web/tool_proposal_presenter.ex:55-66`
**Issue:** `ToolApproval` defines its status set as
`[:pending, :approved, :execution_pending, :rejected, :deferred, :expired, :invalidated]`
(`tool_approval.ex:34`). But `status_group/1` adds a clause for `:pending_approval`
(L60) — an atom that exists nowhere in the approval schema — and has **no clause
for `:pending` or `:approved`**. Any caller that classifies a live approval status
through `status_group/1` will:
- `:pending` → falls to catch-all `status_group(_) -> :blocked` (L66). A
  pending-decision approval would be grouped/labeled as **"Blocked"** — the
  opposite of its meaning, and a trust/audit display defect.
- `:approved` → also falls to `:blocked`.
The `:pending_approval` clause is dead code (never matches a real value). This is
a logic error introduced this phase (the approval status atoms are new in P15).
It also risks state-by-color-alone correctness because the group drives display
grouping. While the current `governed_action_card` template reads
`active_approval.status == :pending` directly rather than via `status_group`, this
function is public API in the presenter and is the documented status-bucketing
contract (D-10); leaving it keyed on a phantom atom guarantees a future caller
mis-buckets every pending approval.
**Fix:** Replace the phantom clause with the real atoms:
```elixir
def status_group(:pending), do: :awaiting
def status_group(:approved), do: :active
def status_group(:execution_pending), do: :active
def status_group(:rejected), do: :done
def status_group(:deferred), do: :done
def status_group(:expired), do: :done
def status_group(:invalidated), do: :done
```
Add a presenter test asserting `status_group(s)` for every atom in
`ToolApproval.status_values()` and `ToolProposal.status_values()` so a future
status atom cannot silently fall to `:blocked`.

## Warnings

### WR-01: Co-commit `with` pipelines are not wrapped in `Repo.transaction` — partial writes possible

**File:** `lib/cairnloop/governance.ex:103-122` (`update_approval_with_event/3`),
`lib/cairnloop/workers/approval_resume_worker.ex:138-170`,
`lib/cairnloop/workers/approval_expiry_worker.ex:57-89`
**Issue:** Every "co-commit" path does `repo().update(cs)` then a separate
`repo().insert(event)` inside a plain `with`, with **no enclosing
`Repo.transaction`**. The docstrings repeatedly claim these are co-committed "in
one transaction" (e.g. `governance.ex:42` "co-committed in one `with` (D-26)",
`tool_approval.ex:7` "co-committed ... in one transaction"). They are not atomic:
if the status update succeeds and the `ToolActionEvent` insert then fails, the
denormalized status flips with **no corresponding audit event** — violating the
"durable events are workflow truth" invariant and the append-only audit
guarantee. Note this mirrors the sanctioned reference idiom
(`knowledge_automation.ex:1771 update_task_with_event/4`, which is also
non-transactional), so it is a carried pattern rather than a fresh regression —
hence WARNING, not BLOCKER. But the docstrings overstate the guarantee.
**Fix:** Either (a) wrap each update+event pair in `repo().transaction(fn -> ... end)`
so the status flip and audit event are genuinely atomic, or (b) correct the
docstrings to say "sequential, non-transactional co-commit (mirrors
`update_task_with_event/4`)" so the durability characteristic is not misrepresented
to future maintainers. Option (a) is strongly preferred for governance/audit code.

### WR-02: Resume worker rebuilds validation context without `account_id` (and other host context keys) — may spuriously invalidate

**File:** `lib/cairnloop/workers/approval_resume_worker.ex:94-128`
**Issue:** `rebuild_context_from_snapshot/1` reconstructs the re-validation context
as **only** `%{scopes: scopes, tool_params: tool_params}`. The original
`propose/3` context carried `account_id`, `conversation_id`, and any host-provided
keys (`load_host_context/1` returns the full provider map). The tool's
`authorize/2` callback receives this context (`governance.ex:231`) and a host tool
may legitimately gate on `context.account_id` or other context fields. On resume,
those keys are absent, so `authorize/2` can deny (fail-closed) and the approval
flips to `:invalidated` even though nothing about the actor's actual entitlement
changed. The snapshot fields needed to faithfully rebuild authorization context
exist (`scope_snapshot`, and `account_id` is on the proposal), but `account_id` is
dropped. Fail-closed is the safe direction, but a re-validation gate that
invalidates correctly-authorized approvals because it forgot to thread
`account_id` is a correctness/UX defect, not just conservatism.
**Fix:** Thread the known snapshot fields back into the rebuilt context:
```elixir
%{
  scopes: scopes,
  tool_params: tool_params,
  account_id: proposal.account_id,
  conversation_id: proposal.conversation_id
}
```
Document explicitly which context keys are re-derivable from snapshots and which
are intentionally dropped, so the invalidation surface is auditable.

### WR-03: `request_approval/2` has no `else` branch — unique-constraint races return a raw changeset, no telemetry, no humanization

**File:** `lib/cairnloop/governance.ex:562-573`
**Issue:** The one-active-lane partial unique index (APRV-04) is the documented
race protection, and the docstring (L517-519) says the function returns
`{:error, changeset}` when it fires. But the `with` has no `else` clause: on a
concurrent second `request_approval` for the same proposal, `repo().insert(insert_cs)`
returns `{:error, %Ecto.Changeset{}}`, which falls straight through the `with` to
the caller un-handled. Unlike `propose/3` (which detects the unique constraint and
converts it to a duplicate-return + telemetry, `governance.ex:350-358`), this path
emits no `:proposal_duplicate`/equivalent telemetry and performs no humanization.
The changeset is returned for a caller to handle, which is tolerable, but it is
inconsistent with every other constraint path in the module and silently drops
observability for a concurrency event the design explicitly anticipates.
**Fix:** Add an `else` clause that detects the one-active-lane unique constraint,
emits an appropriate telemetry event, and returns either the existing pending
approval (idempotent) or a typed `{:error, :lane_already_open}`:
```elixir
else
  {:error, %Ecto.Changeset{} = cs} ->
    if unique_constraint_error?(cs, :tool_proposal_id) do
      {:ok, repo().get_by(ToolApproval, tool_proposal_id: proposal.id, status: :pending)}
    else
      {:error, cs}
    end
end
```

### WR-04: Atom-valued event `metadata` will not round-trip through JSONB — string/atom key drift in audit trail

**File:** `lib/cairnloop/governance.ex:551-554, 611-615, 665-669, 716-720, 764-768`;
`lib/cairnloop/workers/approval_resume_worker.ex:155-158`;
`lib/cairnloop/workers/approval_expiry_worker.ex:73-77`
**Issue:** Every approval event stores `metadata` with **atom keys and atom
values**, e.g. `%{approval_status: :pending, new_approval_status: :approved}`.
After a Postgres JSONB INSERT+SELECT round-trip these become **string keys with
string values** (`%{"approval_status" => "pending", ...}`). Any consumer that
reads `metadata` expecting atoms (the template renders `inspect(event.metadata)`,
which is display-only and tolerant, but future readers may pattern-match) will see
post-round-trip strings, not the atoms written. The codebase elsewhere explicitly
defends this (presenter `metadata_value/2` does dual-key lookup,
`tool_proposal_presenter.ex:397-402`; `policy_snapshot` reads are dual-keyed),
which confirms the project is aware the round-trip mutates key/value shape — but
the approval `metadata` writes assume atoms survive. This is the same class of bug
the project's own `# REPO-UNAVAILABLE` note in CLAUDE.md flags for JSONB
atom→string behavior.
**Fix:** Standardize metadata to string keys/values at write time, or route all
metadata reads through a dual-key/atom-coercing accessor (as `metadata_value/2`
already does). Add a `# REPO-UNAVAILABLE`-marked round-trip test asserting that
`event.metadata["new_approval_status"]` equals `"approved"` after a real DB
round-trip.

### WR-05: `approve_action` LiveView handler ignores `:requires_approval` mode and approval-mode mismatches; flash on generic `{:error, _}` is opaque

**File:** `lib/cairnloop/web/conversation_live.ex:204-223`
**Issue:** The handler approves whatever approval id the client posts
(`String.to_integer(id)`), trusting the rendered button. Because CR-01 leaves
`approve/3` without an `approval_mode` guard, a crafted `phx-value-approval-id`
for an `:always_block` proposal's lane (if one was opened) would be approved and
resumed. Even absent CR-01, the generic `{:error, _}` arm (L220-221) collapses all
unexpected facade errors into "Approval could not be recorded" with no
distinction, so a genuine bug is indistinguishable from a transient failure in the
operator copy. `String.to_integer/1` also raises on a non-integer
`approval-id` param (malformed client input) rather than failing closed with a
flash.
**Fix:** Gate approval on the proposal's `approval_mode` server-side (see CR-01).
Replace `String.to_integer/1` with `Integer.parse/1` and treat a parse failure as
a calm "Approval record not found" rather than an unhandled raise. Keep the
generic arm but log the unexpected shape for observability.

### WR-06: `reject_action`/`defer_action` will raise (MatchError) if the client omits the `reason` field

**File:** `lib/cairnloop/web/conversation_live.ex:225, 247`
**Issue:** Both handlers pattern-match the event params as
`%{"approval-id" => id, "reason" => reason}`. The template always renders a
`<textarea name="reason">`, so the well-behaved client sends it. But a malformed
or adversarial `phx-submit` (or a future template edit that renames the field)
that omits `"reason"` will fail the function-head match and crash the LiveView
process — a fail-open robustness gap for a governance surface that should fail
closed with calm copy. FLOW-03's "reason required" intent is enforced in the
facade, but only if the param reaches it.
**Fix:** Match defensively and default the missing key:
```elixir
def handle_event("reject_action", %{"approval-id" => id} = params, socket) do
  reason = Map.get(params, "reason", "")
  ...
end
```
The facade's `validate_reason_present/2` already returns `{:error, changeset}` for
blank reasons, which the existing generic arm renders as the calm "A reason is
required" flash.

### WR-07: `unique_constraint_error?/2` is registered for `:idempotency_key` but `request_approval` needs it for `:tool_proposal_id` — helper not reused where the new constraint lives

**File:** `lib/cairnloop/governance.ex:482-489` (helper); `lib/cairnloop/governance/tool_approval.ex:76-78` (constraint registration)
**Issue:** The new one-active-lane unique constraint is registered on
`:tool_proposal_id` in `ToolApproval.changeset/2`. The existing
`unique_constraint_error?/2` helper is generic over `field`, but no approval path
calls it (see WR-03 — `request_approval` has no error handling at all). The result
is that the phase added a unique constraint and a generic detection helper but
wired neither together, leaving the documented APRV-04 race path
(`governance.ex:517-519`) effectively unhandled in code. This is the structural
root of WR-03; calling it out separately because the fix is "reuse the existing
helper," which keeps the duplicate-handling pattern consistent across proposal and
approval inserts.
**Fix:** In the WR-03 `else` branch, call
`unique_constraint_error?(cs, :tool_proposal_id)`.

## Info

### IN-01: `status_group` retains dead/forward-looking clauses with misleading comments

**File:** `lib/cairnloop/web/tool_proposal_presenter.ex:55-66`
**Issue:** Beyond the CR-02 phantom `:pending_approval` clause, the comment at
L59 ("Approval status atoms — D15-16 zero relabeling") labels the block as
covering approval atoms, but it omits `:pending` and `:approved` (the two most
common ones). The comment claims completeness the code does not have.
**Fix:** Once CR-02 is fixed, update the comment to reflect the actual atom set
and remove the phantom clause.

### IN-02: `request_approval/2` doc claims a one-transaction co-commit; the reality is two sequential statements

**File:** `lib/cairnloop/governance.ex:513`
**Issue:** "Co-commits the approval record + an `:approval_requested`
`ToolActionEvent`." There is no transaction (see WR-01). Documentation overstates
the durability guarantee.
**Fix:** Align wording with the chosen WR-01 resolution.

### IN-03: `to_status`/`from_status` always `nil` for approval events — audit timeline loses the proposal-status transition

**File:** `lib/cairnloop/governance.ex:608-609` (and all approval event_attrs);
`lib/cairnloop/governance/tool_action_event.ex:78-89`
**Issue:** By design (documented at `tool_action_event.ex:26-37`), approval events
carry the transition in `event_type` + `metadata` and leave `from_status`/
`to_status` nil (these are typed against `ToolProposal.status_values()`, which has
no approval atoms). This is intentional, but it means the structured
`from_status`/`to_status` columns are dead for the entire approval lifecycle and
the transition is only recoverable from `metadata` (which has the round-trip
hazard in WR-04). Not a bug, but worth noting that the audit timeline's typed
transition columns are unusable for the most active state machine in the phase.
**Fix:** No code change required; consider documenting that approval-transition
reconstruction depends on `event_type` + `metadata` (and fix WR-04 so that data is
reliably readable).

### IN-04: `safe_enqueue/1` rescues all exceptions and returns `:ok`, masking enqueue failures behind a log line

**File:** `lib/cairnloop/governance.ex:86-94`
**Issue:** `safe_enqueue/1` swallows any `Oban.insert` exception, logs a warning,
and returns `:ok`. For the expiry worker this means a failed enqueue silently
disables the scheduled-sweep half of the dual TTL mechanism, leaving only the lazy
resume-time guard. This is an intentional host-runtime posture (host may have no
Oban, mirrors `application.ex`), so it is acceptable — but a failed expiry enqueue
in a host that DOES run Oban degrades TTL enforcement to single-mechanism with
only a warning. Note: the lazy guard in `ApprovalResumeWorker` only runs if a
resume job is ever enqueued (i.e. on approval); a `:pending` approval that is
never approved and whose expiry enqueue failed would never expire.
**Fix:** Acceptable as-is for the no-Oban posture. Consider emitting a telemetry
counter (not just a log) on enqueue failure so operators running Oban can alert on
silently-degraded TTL enforcement.

---

_Reviewed: 2026-05-24_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
