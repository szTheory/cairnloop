# Phase 15: Approval State Machine & Oban Resume - Research

**Researched:** 2026-05-24
**Domain:** Elixir / Ecto / Oban approval state machine; host-owned library pattern
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**State model (D15-01..04)**
- New `ToolApproval` record mirroring `ReviewTask` idiom: denormalized `status` enum +
  `decided_by` / `last_decision` / `decided_at` / `reason` last-decision fields + transitions
  co-committed with an append-only event in one transaction. Approval lifecycle lives on
  `ToolApproval`, not on `ToolProposal.status`.
- Approval status axis: `[:pending, :approved, :rejected, :deferred, :expired, :invalidated]`
  (planner may refine names). `:ToolProposal.status` unchanged.
- Reuse single `ToolActionEvent` append-only table (extend `@event_type_values`). Do NOT fork
  a second approval-events table.
- One-active-lane via partial unique index on `tool_proposal_id WHERE status = 'pending'`.

**Triggering and decisions (D15-05..08)**
- Approval lane opens iff resolved `approval_mode == :requires_approval`.
- Approve writes decision record + event + enqueues Oban resume job. NEVER executes inline.
- Reject and Defer REQUIRE a persisted, operator-visible reason.
- No four-eyes enforcement; host policy hook via `Policy.resolve/3`.

**Resume and re-validation (D15-09..11)**
- New Oban worker using `Application.fetch_env!(:cairnloop, :repo)` indirection. Library
  only `Oban.insert/1`s; host runs the Oban runtime.
- Resume worker re-calls pure `Governance.validate/3` against CURRENT context. On pass →
  execution-pending seam state. Does NOT call `run/3`.
- On re-validation failure → `:invalidated` + operator-visible reason + event; never execute.

**Expiry (D15-12..13)**
- `ToolApproval.expires_at` (durable). Dual mechanism: (1) scheduled Oban job flips
  `:pending → :expired` + event; (2) lazy guard treats `expires_at < now` as expired at
  resume/read time. Host-configurable TTL; must be finite.

**Carried guardrails (D15-14..15)**
- Add nullable `rendered_consequence` + `title` columns to `cairnloop_tool_proposals`.
  Populate in `propose/3` from Phase 15 forward. Approval surfaces read snapshotted columns,
  NEVER call live `Preview.render/1`. Test asserting snapshotted-vs-live divergence required.
- Replace `reason_str = inspect(reason)` at `governance.ex:313` with humanized reason
  builder using `Ecto.Changeset.traverse_errors/2`. Test asserting no `#Ecto.Changeset<`
  substring in `policy_snapshot` or event `reason`.

**UI reflection (D15-16)**
- Approve / Reject / Defer affordances in Phase 14 footer action slot.
- `approval_outlook/1` becomes real "Pending approval" status when active `:pending` approval.
- State groups: Awaiting = `:pending`; Active = `:approved`/execution-pending; Done =
  `:rejected`/`:deferred`/`:expired`/`:invalidated`; Blocked unchanged. No relabeling.
- Still plain-assign, no streams.

**Architecture posture (D15-17..18)**
- Telemetry observability-only alongside `ToolActionEvent` inserts.
- All reads through narrow `Cairnloop.Governance` facade.
- Calm, fail-closed, reason-forward, humanized copy. Brand tokens over hex. Never color-alone.

### Claude's Discretion

- Exact module/table names (recommended: `Cairnloop.Governance.ToolApproval`;
  `cairnloop_tool_approvals`), enum value spellings, index predicate exact syntax, TTL
  default number, event-type names, `from_status`/`to_status` handling, Ecto.Multi structure,
  copy wording within calm brand voice, footer-slot placement.
- Whether `:invalidated` and `:expired` are one status or two (must remain operator-legible).
- Whether approval read API lives directly in `Cairnloop.Governance` or a thin
  `Governance.Approval` submodule — one narrow public facade required.

### Deferred Ideas (OUT OF SCOPE)

- Actual execution (`run/3`), first narrow approved write path, run-level idempotency,
  retry/backoff, execution telemetry alignment — Phase 16.
- OBS-02 full attribution lineage — Phase 16/17.
- Four-eyes / segregation-of-duties enforcement — host policy hook only.
- `Phoenix.LiveView.stream/3` for timeline — re-evaluate Phase 16.
- Pending-too-long notifications / escalation.
- Richer snooze / re-request UX beyond defer + open-a-new-lane.
- MCP seam / optional Scoria evidence lane — Phase 17.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FLOW-03 | Operator can reject or defer a proposed action with a persisted reason that remains visible in the action timeline. | Reject/Defer transition functions write `reason` to `ToolApproval` + `ToolActionEvent`; `ToolProposalPresenter` and history_line render it. |
| APRV-01 | High-risk or sensitive governed actions create a durable approval record and never execute inside LiveView or a blocked worker process. | `ToolApproval` insert on `approval_mode == :requires_approval`; approve handler enqueues Oban job, returns immediately; no `run/3` anywhere in Phase 15. |
| APRV-02 | Approved governed actions resume through a new Oban job that re-validates scope and policy before execution. | New `Cairnloop.Workers.ApprovalResumeWorker` (mirrors SlaCountdownWorker); calls `Governance.validate/3` (pure, no side effects); transitions to execution-pending seam on pass. |
| APRV-03 | Approval requests can expire or become invalid when policy, actor scope, or action context changes, and the timeline shows that state explicitly. | Dual expiry: scheduled Oban job + lazy `expires_at < now` guard; re-validation failure → `:invalidated`; `ToolActionEvent` records both; presenter maps to Done group. |
| APRV-04 | System allows only one active approval lane per governed action proposal and records all approval decisions as append-only events. | Partial unique index on `cairnloop_tool_approvals(tool_proposal_id) WHERE status = 'pending'`; all transitions are inserts into `ToolActionEvent`; `ToolApproval` updates denormalized status only. |
</phase_requirements>

---

## Summary

Phase 15 builds the durable approval state machine that sits between `Governance.propose/3`
(Phase 13) and `run/3` execution (Phase 16). The phase is exceptionally well-seamed: every
code pattern needed already exists in the codebase in a directly clone-able form. Research
confirmed all claimed seams exist with the signatures described in CONTEXT.md.

The `ReviewTask`/`ReviewTaskEvent`/`KnowledgeAutomation` idiom is the exact template for
`ToolApproval` transitions: denormalized status + `last_*` decision fields + `update_task_with_event/4`
co-commit (repo update + append-only event insert in a sequential `with`). `SlaCountdownWorker`
with `scheduled_at: target_at` is the exact template for both the expiry sweep and the resume
worker. `Governance.validate/3` is confirmed pure (no DB, no side effects) — re-callable for free.

The two critical implementation choices left to the planner are: (1) how `from_status` /
`to_status` on `ToolActionEvent` handles the new approval namespace (leave them nil and carry
transition in `event_type` + `metadata` is the lower-friction approach given the current
`ToolProposal.status_values()` enum cross-reference), and (2) the TTL default (recommend 48
hours as a finite, non-surprising bound for a human review window).

**Primary recommendation:** Clone `ReviewTask`/`update_task_with_event` for `ToolApproval`
transitions; clone `SlaCountdownWorker` with `scheduled_at:` for both the expiry job and
the resume job; extend `ToolActionEvent.@event_type_values` for approval event types and
leave `from_status`/`to_status` nil for approval events (carry state in `event_type` +
`metadata`). All three are zero-new-pattern work.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| ToolApproval record storage & transitions | Database / Ecto | — | Durable workflow truth; all state in Ecto Multi transactions |
| One-active-lane enforcement | Database / Ecto | API facade | Partial unique index is the hard constraint; app guard is belt-and-suspenders |
| Approve/Reject/Defer decisions | API / Backend (`Governance` facade) | Browser/LiveView (initiates) | Decision logic and persistence belong in the facade, not the LiveView handler |
| Resume job enqueue | API / Backend | — | `Oban.insert/1` called from `Governance.approve/...` after transaction commits |
| Re-validation before execute | Oban worker (async) | Governance.validate/3 (pure) | Worker owns the re-check; validate/3 is side-effect-free |
| Expiry sweep | Oban worker (scheduled) | Lazy guard at read time | Scheduled job + lazy guard = defense-in-depth; both backend |
| Approval display / state labels | Frontend Server (LiveView presenter) | — | ToolProposalPresenter is the pure mapping layer |
| Approve/Reject/Defer affordances | Browser / LiveView | — | Footer-slot buttons are LiveView event handlers; state persisted via facade |
| Timeline reflection | Frontend Server (LiveView) | — | Plain-assign reload via existing PubSub → `reload_conversation_with_context` path |
| Prose snapshot (`rendered_consequence`/`title`) | Database / Ecto | API facade writes | Snapshotted at propose time; approval surfaces read from column only |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ecto / Ecto.Multi | ~> 3.10 (in mix.exs) | ToolApproval schema, migrations, co-commit transactions | Already the project's ORM; `update_task_with_event` idiom confirmed in codebase |
| Oban | ~> 2.17 (in mix.exs) | Resume worker + expiry sweep; `scheduled_at:` scheduling | Already used for `SlaCountdownWorker`, `GenerateArticleSuggestion`, etc. |
| Phoenix.LiveView | ~> 1.0 (in mix.exs) | Footer-slot Approve/Reject/Defer handlers + reload path | Existing `handle_event` / `reload_conversation_with_context` pattern |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Ecto.Changeset.traverse_errors/2 | stdlib (Ecto 3.x) | Humanize changeset errors for WR-01 fix | In `insert_blocked_proposal/10` to replace `inspect(reason)` |

No new external packages are required for Phase 15. All libraries are already in mix.exs.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Sequential `with` for co-commit | `Ecto.Multi` named steps | `Ecto.Multi` adds named-step debugging; `with` is the current codebase idiom (see `insert_new_proposal`). Either works; planner should choose consistency with existing governance.ex code (with). |
| Partial unique index on `status = 'pending'` | Application-level uniqueness guard only | Index is the hard constraint (race-safe); application guard is belt-and-suspenders only |
| Separate `ToolApprovalEvent` table | Extend `ToolActionEvent` | D15-03 is locked: one table, one operator timeline |

---

## Package Legitimacy Audit

No new external packages are installed in Phase 15. All required libraries (Ecto, Oban,
Phoenix LiveView) are already declared in `mix.exs`. Audit section is not applicable.

---

## Architecture Patterns

### System Architecture Diagram

```
ConversationLive.handle_event("approve_tool_approval")
        │
        ▼
Cairnloop.Governance.approve(approval_id, actor_id, opts)
        │
        ├─── repo().update(ToolApproval changeset → :approved)
        │           co-committed with:
        ├─── repo().insert(ToolActionEvent → :approved event)
        │
        └─── Oban.insert(ApprovalResumeWorker.new(%{approval_id: id}))
                    [wrapped in try/rescue — host may have no Oban]
                    │
                    ▼ (async, later)
        Cairnloop.Workers.ApprovalResumeWorker.perform/1
                    │
                    ├─── [lazy expires_at guard] if expired → :expired + event, done
                    │
                    ├─── Governance.validate/3 (pure, no DB)
                    │       ├─ {:ok, _} ──→ transition ToolApproval → :execution_pending
                    │       │                emit :revalidation_passed event
                    │       │                [Phase 16 seam — stop here]
                    │       └─ {:blocked, outcome, reason}
                    │                ──→ transition ToolApproval → :invalidated
                    │                    emit :revalidation_failed event + reason
                    │                    [never execute]
```

```
Approval expiry (parallel path):
ExpiryFlipWorker.perform/1          OR     lazy guard in resume worker
(scheduled_at: approval.expires_at)         (expires_at < DateTime.utc_now())
        │                                           │
        ▼                                           ▼
ToolApproval → :expired + event            return :expired immediately
```

```
ConversationLive reload path:
PubSub broadcast → reload_conversation_with_context
        │
        └─── Governance.list_proposals_for_conversation/1
                     (preloads :approval via has_one or active-lane query)
                            │
                            ▼
                    ToolProposalPresenter
                    approval_outlook/1 → "Pending approval" (real action)
                    status_group → :awaiting/:active/:done
```

### Recommended Project Structure

```
lib/cairnloop/governance/
├── tool_approval.ex          # New: ToolApproval schema + status enum + decision_changeset/7
├── tool_action_event.ex      # Extend: add approval event_type values
├── tool_proposal.ex          # Extend: add rendered_consequence/title + has_one(:approval)
├── policy.ex                 # Extend: Policy.resolve/3 with actor-scope factor (Phase 15 PDP)
└── governance.ex             # Extend: approve/reject/defer/expire + get_active_approval/1

lib/cairnloop/workers/
└── approval_resume_worker.ex # New: Oban worker; validate/3 re-check + seam

priv/repo/migrations/
├── YYYYMMDDHHMMSS_add_tool_approvals.exs             # New table + partial unique index
└── YYYYMMDDHHMMSS_add_snapshot_cols_to_proposals.exs # rendered_consequence + title cols

lib/cairnloop/web/
├── tool_proposal_presenter.ex  # Extend: approval states, approval_outlook/1 real copy
└── conversation_live.ex        # Extend: approve/reject/defer handle_event handlers

test/cairnloop/governance/
├── tool_approval_test.exs      # New: changeset, one-active-lane, decision_changeset
└── governance_test.exs         # Extend: approve/reject/defer/expire + WR-01 humanization

test/cairnloop/workers/
└── approval_resume_worker_test.exs   # New: validate pass→seam, fail→invalidated, expiry guard

test/cairnloop/web/
└── tool_proposal_presenter_test.exs  # Extend: approval status groups, approval_outlook/1
```

### Pattern 1: ToolApproval Schema (ReviewTask Clone)

**What:** Denormalized lifecycle status + last-decision fields, co-committed transition
**When to use:** Every approve/reject/defer/expire/invalidate transition

```elixir
# Source: lib/cairnloop/knowledge_automation/review_task.ex (VERIFIED in codebase)
# Directly mirrors ReviewTask — clone this shape for ToolApproval

defmodule Cairnloop.Governance.ToolApproval do
  use Ecto.Schema
  import Ecto.Changeset

  @status_values [:pending, :approved, :rejected, :deferred, :expired, :invalidated,
                  :execution_pending]
  # Planner picks exact enum names; keep :expired distinct from :invalidated (D15-02)

  schema "cairnloop_tool_approvals" do
    field(:status, Ecto.Enum, values: @status_values, default: :pending)
    field(:decided_by, :string)          # mirrors ReviewTask.last_actor_id
    field(:last_decision, :string)       # mirrors ReviewTask.last_decision (free-form or Enum)
    field(:decided_at, :utc_datetime_usec)
    field(:reason, :string)              # REQUIRED for reject/defer (FLOW-03)
    field(:expires_at, :utc_datetime_usec)  # durable TTL (D15-12)

    belongs_to(:tool_proposal, Cairnloop.Governance.ToolProposal)

    timestamps(type: :utc_datetime_usec)
  end

  def status_values, do: @status_values

  def decision_changeset(approval, status, decision, reason, actor_id, decided_at) do
    %{status: status, last_decision: decision, reason: reason,
      decided_by: actor_id, decided_at: decided_at}
    |> then(&changeset(approval, &1))
    |> validate_reason_present(status)
  end

  defp validate_reason_present(cs, status) when status in [:rejected, :deferred] do
    validate_required(cs, [:reason])
  end
  defp validate_reason_present(cs, _), do: cs
end
```

### Pattern 2: Transition Co-commit (update_approval_with_event idiom)

**What:** Sequential `with` — update `ToolApproval` + insert `ToolActionEvent`
**When to use:** Every approval state transition

```elixir
# Source: lib/cairnloop/knowledge_automation.ex L1771 (VERIFIED in codebase)
# update_task_with_event is the exact idiom; clone for approvals

defp update_approval_with_event(approval, changeset, event_attrs) do
  with {:ok, updated_approval} <- repo().update(changeset),
       {:ok, _event} <-
         %ToolActionEvent{}
         |> ToolActionEvent.changeset(Map.put(event_attrs, :tool_proposal_id, approval.tool_proposal_id))
         |> repo().insert() do
    Telemetry.emit(:approval_transition, %{count: 1}, %{to_status: updated_approval.status})
    {:ok, updated_approval}
  end
end
```

### Pattern 3: Oban Resume Worker (SlaCountdownWorker Clone)

**What:** `use Oban.Worker, queue: :default` + `Application.fetch_env!(:cairnloop, :repo)` +
`try/rescue` around `Oban.insert/1`
**When to use:** Resume worker AND expiry flip worker

```elixir
# Source: lib/cairnloop/workers/sla_countdown_worker.ex (VERIFIED in codebase)
# lib/cairnloop/application.ex L44-48 (VERIFIED — try/rescue Oban.insert pattern)

defmodule Cairnloop.Workers.ApprovalResumeWorker do
  use Oban.Worker, queue: :default,
    unique: [period: :infinity, fields: [:worker, :args], keys: [:approval_id]]
    # uniqueness keyed on approval_id prevents double-enqueue (D15-09)

  defp repo, do: Application.fetch_env!(:cairnloop, :repo)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"approval_id" => approval_id}}) do
    case repo().get(ToolApproval, approval_id) do
      nil -> :ok  # deleted — no-op
      %ToolApproval{status: :pending} = approval ->
        # Lazy expires_at guard (D15-12 belt-and-suspenders)
        if approval.expires_at && DateTime.before?(approval.expires_at, DateTime.utc_now()) do
          expire_approval(approval)
        else
          revalidate_and_transition(approval)
        end
      _ -> :ok  # already transitioned — idempotent
    end
  end

  defp revalidate_and_transition(approval) do
    proposal = repo().get!(ToolProposal, approval.tool_proposal_id)
    # Rebuild context from proposal snapshot (scope_snapshot, policy_snapshot, etc.)
    context = rebuild_context(proposal)

    case Governance.validate(proposal.tool_ref, proposal.actor_id, context) do
      {:ok, _validated} ->
        # Transition to execution-pending seam (Phase 16 hook) — no run/3 (D15-10)
        transition_to_execution_pending(approval)
      {:blocked, outcome, reason} ->
        # Fail-closed: invalidate (D15-11)
        invalidate_approval(approval, outcome, reason)
    end
  end
end
```

### Pattern 4: Scheduled Expiry Job Enqueue (chat.ex clone)

**What:** `Worker.new(%{...}, scheduled_at: expires_at)` wrapped in `Ecto.Multi.insert`
**When to use:** When opening a new approval lane (approve_lane/create_approval)

```elixir
# Source: lib/cairnloop/chat.ex L71 (VERIFIED in codebase)
# SlaCountdownWorker.new(%{"sla_id" => sla.id}, scheduled_at: target_at)

# In the approval-creation transaction:
expiry_job =
  Cairnloop.Workers.ApprovalExpiryWorker.new(
    %{"approval_id" => approval.id},
    scheduled_at: approval.expires_at
  )

try do
  Oban.insert(expiry_job)
rescue
  _ -> :ok  # host may have no Oban configured (application.ex L44-48 idiom)
end
```

### Pattern 5: Partial Unique Index Migration

**What:** `unique_index` with `where:` clause for one-active-lane enforcement (APRV-04)
**When to use:** `cairnloop_tool_approvals` migration

```elixir
# Source: priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs (VERIFIED)
# ReviewTask uses same pattern for one-active-task-per-suggestion

create(
  unique_index(
    :cairnloop_tool_approvals,
    [:tool_proposal_id],
    name: :cairnloop_tool_approvals_one_active_lane_index,
    where: "status = 'pending'"
  )
)
```

### Pattern 6: WR-01 Humanized Error (insert_blocked_proposal fix)

**What:** Replace `inspect(reason)` with `traverse_errors/2` + formatted string
**When to use:** `governance.ex` `insert_blocked_proposal/10` at L313

```elixir
# Source: lib/cairnloop/governance.ex L313 (VERIFIED — the exact WR-01 site)
# BEFORE (WR-01 bug):
reason_str = inspect(reason)

# AFTER (D15-15 fix):
reason_str =
  case reason do
    %Ecto.Changeset{} = cs ->
      cs
      |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {k, v}, acc ->
          String.replace(acc, "%{#{k}}", to_string(v))
        end)
      end)
      |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
      |> Enum.join("; ")
    atom when is_atom(atom) -> Atom.to_string(atom)
    binary when is_binary(binary) -> binary
    _ -> "blocked"
  end
```

### Pattern 7: Oban Job Enqueueing in Governance Facade (host-library posture)

**What:** `try/rescue` around `Oban.insert/1` — host may not have Oban configured
**When to use:** Any `Oban.insert` call from within the library

```elixir
# Source: lib/cairnloop/application.ex L44-48 (VERIFIED — canonical library pattern)
defp safe_enqueue(job) do
  try do
    Oban.insert(job)
  rescue
    _ -> :ok
  end
end
```

### Pattern 8: ToolActionEvent Extension for Approval Events (D15-03)

**What:** Extend `@event_type_values` list; leave `from_status`/`to_status` nil for approval
events (they reference the `ToolApproval` state axis, not `ToolProposal.status`)
**When to use:** Extending `tool_action_event.ex`

```elixir
# Source: lib/cairnloop/governance/tool_action_event.ex L23 (VERIFIED)
# Current: @event_type_values [:proposal_created, :proposal_blocked]
# Phase 15 extension:
@event_type_values [
  :proposal_created, :proposal_blocked,
  # approval lifecycle (Phase 15)
  :approval_requested,
  :approved,
  :rejected,
  :deferred,
  :expired,
  :invalidated,
  :resume_scheduled,
  :revalidation_passed,
  :revalidation_failed
]

# NOTE: from_status/to_status remain typed against ToolProposal.status_values().
# For approval events, leave from_status/to_status nil and carry the approval
# state transition in event_type + metadata: %{approval_status: :pending, new_approval_status: :approved}.
# This avoids widening the ToolProposal.status enum and keeps the constraint clear.
```

### Pattern 9: ToolProposalPresenter Extensions

**What:** `approval_outlook/1` → real "Pending approval" with real action; new status group mappings
**When to use:** Extending `tool_proposal_presenter.ex`

```elixir
# Source: lib/cairnloop/web/tool_proposal_presenter.ex L111 (VERIFIED)
# BEFORE (Phase 14 honesty seam — future-tense, no action):
def approval_outlook(:requires_approval), do: "Will require approval before it can run."

# AFTER (Phase 15 — real status based on active approval):
# When approval record exists and status == :pending:
def approval_outlook(:pending_approval), do: "Pending approval."
# New status_group entries (no relabeling of existing four):
def status_group(:pending_approval), do: :awaiting    # D15-16
def status_group(:execution_pending), do: :active     # D15-16
def status_group(:rejected), do: :done
def status_group(:deferred), do: :done
def status_group(:expired), do: :done
def status_group(:invalidated), do: :done
# New history_line clauses — catch-all already handles unknown types (D-24 forward-compat)
def history_line(%ToolActionEvent{event_type: :approved, actor_id: actor}) do
  "Approved by #{actor}"
end
def history_line(%ToolActionEvent{event_type: :rejected, actor_id: actor, reason: reason}) do
  "Rejected by #{actor}: #{reason}"
end
# etc.
```

### Pattern 10: ConversationLive Footer-Slot Handlers

**What:** New `handle_event` clauses for approve/reject/defer; durable decision + enqueue, never inline
**When to use:** Extending `conversation_live.ex`

```elixir
# Source: lib/cairnloop/web/conversation_live.ex L175 (VERIFIED — existing execute_tool handler)
# Mirror this pattern: call Governance facade, flash, reload — never execute inline

def handle_event("approve_action", %{"approval-id" => id}, socket) do
  actor_id = socket.assigns.conversation.host_user_id
  case Cairnloop.Governance.approve(String.to_integer(id), actor_id, []) do
    {:ok, _approval} ->
      {:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}
    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Approval could not be recorded.")}
  end
end

def handle_event("reject_action", %{"approval-id" => id, "reason" => reason}, socket) do
  actor_id = socket.assigns.conversation.host_user_id
  case Cairnloop.Governance.reject(String.to_integer(id), actor_id, reason: reason) do
    {:ok, _approval} ->
      {:noreply, reload_conversation_with_context(socket, socket.assigns.conversation.id)}
    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Rejection could not be recorded. A reason is required.")}
  end
end
```

### Anti-Patterns to Avoid

- **Calling `run/3` from the resume worker:** Phase 16 only. The success branch of the resume
  worker transitions to `:execution_pending` and stops — this IS the Phase 15 deliverable.
- **Executing inline in the LiveView approve handler:** `handle_event("approve_action")` must
  only persist the decision + enqueue the Oban job, then return. Never call the resume logic
  synchronously. (APRV-01, Requirements out-of-scope: "Blocking human approval inside LiveView
  or one long-running worker.")
- **Using `inspect/1` for reason strings:** WR-01. Use `traverse_errors/2` for changesets,
  `Atom.to_string/1` for atoms, pass-through for binaries.
- **Forking a second approval-events table:** D15-03 locks this. Extend `ToolActionEvent`.
- **Adding approval states to `ToolProposal.status`:** D15-01 locks this. The lifecycle lives
  on `ToolApproval`, not on the proposal.
- **Using `String.to_atom/1` for JSONB key rehydration:** T-14-01/D-19. Always
  `String.to_existing_atom/1` + rescue `ArgumentError`.
- **Re-reading live `Preview.render/1` from approval surfaces:** D15-14 / D-16. Only read
  the snapshotted `rendered_consequence`/`title` columns.
- **Calling `Oban.insert/1` without `try/rescue`:** The host may not have Oban configured.
  Always wrap per the `application.ex` idiom.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Approval state machine | Custom FSM module or GenServer | Ecto schema + changeset + `update_approval_with_event/3` | ReviewTask idiom already proven; Ecto transaction = durability |
| One-active-lane guarantee | Application-level locking | Postgres partial unique index | Race-safe; `unique_constraint` in changeset surfaces conflicts cleanly |
| Async resume | Inline synchronous resume or background Task | Oban.Worker + `perform/1` | Host-owned runtime; library only inserts jobs (library posture) |
| Scheduled expiry | Polling loop or cron | `Oban.Worker.new(args, scheduled_at: dt)` | Already used in `chat.ex` for SLA; Oban handles missed jobs |
| Error humanization | `inspect/1` | `Ecto.Changeset.traverse_errors/2` | Produces human-readable field:message strings; no raw Elixir terms |
| Status grouping display logic | Inline LiveView if/case | `ToolProposalPresenter.status_group/1` | Pure, total, testable without DB; existing presenter idiom |

**Key insight:** Every hard problem in this phase has a proven solution already in the codebase.
The work is additive cloning of existing patterns, not invention of new ones.

---

## Seam Verification: Confirmed Code Evidence

All seams listed in CONTEXT.md were verified by reading the actual source files.

### `Governance.validate/3` — Pure, re-callable, no side effects [VERIFIED: codebase]

**File:** `lib/cairnloop/governance.ex` L154–166

Signature: `def validate(tool_ref, actor_id, context)`

The function is a `with` pipeline calling:
- `resolve_tool/1` — module lookup only
- `validate_input/2` — `tool_module.changeset(struct, params)` — pure
- `check_scope/3` — list comparison — pure
- `tool_module.authorize/2` — pure callback

No `repo()` calls. No DB interaction. No side effects. Confirmed re-callable for free from
the resume worker exactly as stated in D15-10.

Return shape: `{:ok, validated_attrs}` | `{:blocked, :unsupported, :unknown_tool}` |
`{:blocked, :needs_input, changeset}` | `{:blocked, :scope_invalid, reason}` |
`{:blocked, :policy_denied, reason}`

### `Governance.insert_blocked_proposal/10` WR-01 site [VERIFIED: codebase]

**File:** `lib/cairnloop/governance.ex` L313

Exact line: `reason_str = inspect(reason)`

This site persists the raw `inspect/1` output into:
- `proposal_attrs.policy_snapshot` → `%{outcome: outcome, reason: reason_str}`
- `event_attrs.reason` → `reason_str`

Both columns receive the raw `#Ecto.Changeset<...>` string when `reason` is a changeset.
The D15-15 fix replaces this single line with the `traverse_errors/2` builder.

### `ReviewTask` transition idiom — exact template [VERIFIED: codebase]

**File:** `lib/cairnloop/knowledge_automation/review_task.ex`

Confirmed fields:
- `@status_values` — Ecto.Enum on `:status`
- `last_decision`, `last_reason`, `last_actor_id`, `last_decided_at`, `notes` — denormalized
- `decision_changeset/6` — builds attrs map, merges, calls `changeset/2`

**File:** `lib/cairnloop/knowledge_automation.ex` L1771

`update_task_with_event/4`:
```elixir
defp update_task_with_event(task, changeset, event_attrs, result_type \\ :ok) do
  with {:ok, updated_task} <- repo().update(changeset),
       {:ok, _event} <-
         %ReviewTaskEvent{}
         |> ReviewTaskEvent.changeset(Map.put(event_attrs, :review_task_id, task.id))
         |> repo().insert() do
    emit_review_task_event(updated_task, task, event_attrs)
    {result_type, updated_task}
  end
end
```

This is NOT using `Ecto.Multi` — it is a sequential `with`. The governance.ex
`insert_new_proposal` also uses a sequential `with`. The planner should clone the `with`
pattern (not Ecto.Multi) for consistency with both precedents.

### `SlaCountdownWorker` — Oban worker + scheduled flip idiom [VERIFIED: codebase]

**File:** `lib/cairnloop/workers/sla_countdown_worker.ex`

```elixir
defmodule Cairnloop.Workers.SlaCountdownWorker do
  use Oban.Worker, queue: :default

  defp repo, do: Application.fetch_env!(:cairnloop, :repo)

  def perform(%Oban.Job{args: %{"sla_id" => sla_id}}) do
    case repo().get(SLA, sla_id) do
      nil -> :ok
      %SLA{status: :active} = sla ->
        sla
        |> Ecto.Changeset.change(%{status: :breached, completed_at: DateTime.utc_now()})
        |> repo().update!()
        :ok
      _ -> :ok
    end
  end
end
```

The resume worker mirrors this structure exactly: `get` by id → check current status → act or
no-op. The `Application.fetch_env!(:cairnloop, :repo)` indirection is confirmed.

`scheduled_at:` usage confirmed in `lib/cairnloop/chat.ex` L71:
```elixir
job = Cairnloop.Workers.SlaCountdownWorker.new(%{"sla_id" => sla.id}, scheduled_at: target_at)
```

### `Application.ex` — host-owned Oban posture [VERIFIED: codebase]

**File:** `lib/cairnloop/application.ex` L44–48

```elixir
try do
  Oban.insert(job)
rescue
  _ -> :ok
end
```

No Oban supervisor in `children = []`. Confirmed: library only inserts; host runs the runtime.

### `Policy.resolve/3` — PDP seam [VERIFIED: codebase]

**File:** `lib/cairnloop/governance/policy.ex` L26

Current signature: `def resolve(tool_module, _actor_id, _context)`

Both `_actor_id` and `_context` are currently ignored (prefixed with `_`). Phase 15 extends
ONLY this function to factor in actor scope and runtime context — no call-site changes
needed. The `@moduledoc` explicitly documents this as "Phase 15 seam."

### `ToolActionEvent` — append-only, event_type list [VERIFIED: codebase]

**File:** `lib/cairnloop/governance/tool_action_event.ex`

Current `@event_type_values`: `[:proposal_created, :proposal_blocked]`

`from_status`/`to_status` typed against `ToolProposal.status_values()`:
`[:proposed, :needs_input, :scope_invalid, :policy_denied]`

For approval events, these four values do NOT cover the approval state axis. The planner
must choose: (a) widen the enum to include approval states (requires migration, wider
Ecto.Enum), or (b) leave `from_status`/`to_status` nil for approval events and carry the
transition in `event_type` + `metadata`. **Recommendation: option (b)** — lower migration
surface, consistent with the `proposal_created` event already using `from_status: nil`, and
the `metadata: %{}` field is explicitly designed for this. The history_line catch-all
(D-24) already handles nil from_status gracefully.

`timestamps(type: :utc_datetime_usec, updated_at: false)` — confirmed append-only enforcement.

### `ToolProposalPresenter` — approval_outlook/1 honesty seam [VERIFIED: codebase]

**File:** `lib/cairnloop/web/tool_proposal_presenter.ex` L111–114

```elixir
def approval_outlook(:auto), do: nil
def approval_outlook(:requires_approval), do: "Will require approval before it can run."
def approval_outlook(:always_block), do: "This action cannot be approved or run."
def approval_outlook(_), do: nil
```

Phase 15 adds a `approval_outlook/1` clause (or repurposes) that takes the approval state
atom (`:pending_approval` or a proposal+approval combined shape) and returns real
"Pending approval" copy. The planner should decide whether `approval_outlook/1` receives
the `approval_mode` atom or an approval struct — the simplest approach is to add a
`approval_outlook_for_approval/1` taking a `%ToolApproval{}` struct and dispatch from
the card render.

`history_line/1` catch-all confirmed at L269: `def history_line(%ToolActionEvent{}), do: "Workflow updated"`.
New approval event type clauses slot above this catch-all.

### `Preview.ex` — D-16 guardrail embedded in @moduledoc [VERIFIED: codebase]

**File:** `lib/cairnloop/governance/preview.ex` L35–46

The `@moduledoc` contains the 4-step Phase 15 mandate verbatim. The discoverable marker
confirming Phase 15 must: (1) add columns, (2) populate in propose/3, (3) read snapshot
only from approval surfaces, (4) add divergence test. This is the canonical source to
satisfy the planner's D15-14 obligation.

### `ToolProposal` schema — no rendered_consequence/title yet [VERIFIED: codebase]

**File:** `lib/cairnloop/governance/tool_proposal.ex`

Current fields do NOT include `rendered_consequence` or `title`. Phase 15 adds them as
nullable columns. The `has_one(:approval)` or `has_many(:approvals)` association is also
not yet present.

### Migration style — confirmed [VERIFIED: codebase]

**File:** `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs`

Uses `:string` for enum columns (not Postgres native enum). Uses `unique_index` with `where:`
for partial unique constraint. Named index `cairnloop_review_tasks_one_active_task_per_suggestion_index`.
Uses `timestamps(type: :utc_datetime_usec, updated_at: false)` for append-only events table.

### Oban version and unique options [VERIFIED: codebase]

`{:oban, "~> 2.17"}` in mix.exs.

`unique: [period: :infinity, fields: [:worker, :args], keys: [...]]` syntax confirmed in
`lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex` L4.
The resume worker should use `unique: [period: :infinity, keys: [:approval_id]]` to prevent
double-enqueue of resume for the same approval.

`enqueue_fn` injection pattern confirmed in `knowledge_automation.ex` L680 and L1071 for
test isolation. The planner should add an `enqueue_fn` or `oban_insert_fn` option to the
`Governance.approve/...` function for headless testing.

---

## Common Pitfalls

### Pitfall 1: Sequential `with` vs Ecto.Multi for co-commit

**What goes wrong:** Choosing `Ecto.Multi` when the codebase pattern uses sequential `with`.
**Why it happens:** `Ecto.Multi` is commonly recommended; but governance.ex and
knowledge_automation.ex both use sequential `with` for co-commits.
**How to avoid:** Mirror `update_task_with_event` exactly — `with {:ok, updated} <- repo().update(cs)` then `with {:ok, _event} <- repo().insert(...)`.
**Warning signs:** If the planner writes `Ecto.Multi.new() |> Multi.update(...) |> Multi.insert(...)`, ask why.

### Pitfall 2: Calling run/3 from the resume worker

**What goes wrong:** Phase 16 seam violated; execution happens without idempotency, retry
protection, or first-write-path proof.
**Why it happens:** The resume worker logically "should" execute after re-validation passes.
**How to avoid:** The success branch transitions `ToolApproval → :execution_pending`, emits
`:revalidation_passed` event, and returns `:ok`. That IS the Phase 15 deliverable.
**Warning signs:** Any call to `tool_module.run/3` or `Cairnloop.Governance.execute/...` in the Phase 15 worker.

### Pitfall 3: No-op on failed Oban.insert instead of logging

**What goes wrong:** Expiry or resume job silently not enqueued; operator has no visibility.
**Why it happens:** The `try/rescue → :ok` pattern swallows failures.
**How to avoid:** Add `Logger.warning` in the rescue clause (pattern from `check_sla.ex` L24).
**Warning signs:** Bare `rescue _ -> :ok` with no logging.

### Pitfall 4: Widening ToolProposal.status_values() for approval states

**What goes wrong:** `ToolActionEvent.from_status`/`to_status` accept approval states, confusing
the proposal-status axis with the approval-status axis.
**Why it happens:** The event table currently uses `ToolProposal.status_values()` for `from_status`/`to_status`.
**How to avoid:** Leave `from_status`/`to_status` nil for approval events; carry state in
`event_type` + `metadata`. The `proposal_created` event already uses `from_status: nil`.
**Warning signs:** Migration that adds `:pending`, `:approved`, etc. to `ToolProposal.status_values()`.

### Pitfall 5: Race condition in one-active-lane without unique constraint

**What goes wrong:** Two concurrent approve requests open two approval lanes.
**Why it happens:** Checking for existing pending approval then inserting is a TOCTOU race.
**How to avoid:** The partial unique index is the hard constraint. Add `unique_constraint(:tool_proposal_id, name: :cairnloop_tool_approvals_one_active_lane_index)` to the changeset and handle `{:error, changeset}` from the insert.
**Warning signs:** Application-only check with no database constraint.

### Pitfall 6: Blocking LiveView with synchronous approval logic

**What goes wrong:** `handle_event("approve_action")` calls resume logic synchronously; if
`validate/3` is slow or context loading fails, the LiveView process stalls.
**Why it happens:** Pure `validate/3` is fast but context loading (e.g. fetching host context)
might not be.
**How to avoid:** The handler only calls `Governance.approve(...)` (persists decision + enqueues
Oban job) and returns immediately. Resume happens async in the worker. (APRV-01.)

### Pitfall 7: Exposing `#Ecto.Changeset<` in policy_snapshot or event reason

**What goes wrong:** `:needs_input` blocked proposals persist raw changeset repr in durable
columns.
**Why it happens:** `reason_str = inspect(reason)` at governance.ex L313.
**How to avoid:** The D15-15 fix (traverse_errors for changesets; Atom.to_string for atoms;
pass-through for binaries) replaces this single line.
**Warning signs:** Any test that asserts `policy_snapshot["reason"]` may be a changeset string.

### Pitfall 8: Live Preview.render on approval surfaces

**What goes wrong:** Approval card shows different prose after a tool implementation changes
post-approval. Trust and audit correctness failure.
**Why it happens:** Reusing the Phase 14 live `Preview.render/1` on the approval card.
**How to avoid:** Approval card reads `proposal.rendered_consequence` and `proposal.title`
(snapshotted columns). Live `Preview.render/1` is only for the Phase 14 read-only timeline.
**Warning signs:** Any call to `Preview.render(proposal)` from within an approval card component.

---

## Runtime State Inventory

Phase 15 is an additive greenfield feature (new table, new worker, schema extension). It does
NOT rename any existing entity.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | None — `cairnloop_tool_approvals` table does not exist yet | New migration adds it |
| Live service config | None — no external service has approval config | N/A |
| OS-registered state | None | N/A |
| Secrets/env vars | None — no new env vars needed | N/A |
| Build artifacts | None | N/A |

**Nothing found in any category** — verified by confirming no existing `tool_approvals`
table, no existing `ApprovalResumeWorker`, and no external service references to approval
state.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Synchronous inline execution from LiveView | Async Oban resume after durable approval | Phase 15 (now) | APRV-01 — never block LiveView on execution |
| `inspect(reason)` for blocked-proposal persistence | `traverse_errors/2` humanization | Phase 15 (WR-01 fix) | Human-readable reasons in durable policy_snapshot |
| Purely optimistic approval (no expiry) | Expiry TTL + scheduled flip + lazy guard | Phase 15 | APRV-03 — stale approvals cannot execute |
| No re-validation before execution | `validate/3` re-check at resume time | Phase 15 | APRV-02 — Terraform "stale plan" pattern |

**Deprecated/outdated:**
- `reason_str = inspect(reason)` at governance.ex L313: replaced by D15-15 humanizer.
- Future-tense `approval_outlook/1` copy: replaced by real "Pending approval" status.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Oban ~> 2.17 | Resume worker + expiry job | ✓ | ~> 2.17 (in mix.exs) | library `try/rescue` pattern for host-not-configured |
| Ecto 3.10 | ToolApproval schema + migration | ✓ | ~> 3.10 (in mix.exs) | N/A |
| PostgreSQL | Partial unique index, JSONB | ✗ (Repo unavailable in workspace) | — | Tests use MockRepo; mark DB-round-trip tests `# REPO-UNAVAILABLE` |
| Phoenix.LiveView 1.0 | Footer-slot handlers | ✓ | ~> 1.0 (in mix.exs) | N/A |

**Missing dependencies with no fallback:** None (all libs already in mix.exs).

**Missing dependencies with fallback:**
- PostgreSQL: `Cairnloop.Repo` unavailable in this workspace. All DB-backed tests (actual
  insert/select round-trips, partial-index constraint tests, JSONB string-key tests) must
  be written but marked `# REPO-UNAVAILABLE` where they cannot run here. MockRepo pattern
  is the established workaround (see `sla_countdown_worker_test.exs`, `governance_test.exs`).

---

## Validation Architecture

> `workflow.nyquist_validation` is absent from `.planning/config.json` → treated as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix test test/cairnloop/governance/ test/cairnloop/workers/approval_resume_worker_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| APRV-04 | One-active-lane: second pending approval rejected by DB constraint | unit (changeset unique_constraint) | `mix test test/cairnloop/governance/tool_approval_test.exs` | ❌ Wave 0 |
| APRV-04 | Append-only invariant: no update/1 or delete/1 on ToolApproval events | unit | `mix test test/cairnloop/governance/tool_action_event_test.exs` | ✅ (extend) |
| APRV-01 | Approve handler enqueues Oban job, never calls run/3 | unit (MockRepo + enqueue_fn capture) | `mix test test/cairnloop/governance/governance_test.exs` | ✅ (extend) |
| APRV-01 | Approval record persisted before any Oban enqueue | unit | `mix test test/cairnloop/governance/governance_test.exs` | ✅ (extend) |
| APRV-02 | Resume worker re-calls validate/3 before transitioning | unit (MockRepo) | `mix test test/cairnloop/workers/approval_resume_worker_test.exs` | ❌ Wave 0 |
| APRV-02 | Resume validate pass → :execution_pending seam, no run/3 | unit (MockRepo) | `mix test test/cairnloop/workers/approval_resume_worker_test.exs` | ❌ Wave 0 |
| APRV-03 | Resume validate fail → :invalidated + reason event, no execute | unit (MockRepo) | `mix test test/cairnloop/workers/approval_resume_worker_test.exs` | ❌ Wave 0 |
| APRV-03 | Lazy expires_at guard: approval marked expired before re-validate when TTL elapsed | unit (MockRepo, DateTime injection) | `mix test test/cairnloop/workers/approval_resume_worker_test.exs` | ❌ Wave 0 |
| APRV-03 | Scheduled expiry worker flips :pending → :expired + event | unit (MockRepo) | `mix test test/cairnloop/workers/approval_expiry_worker_test.exs` | ❌ Wave 0 |
| FLOW-03 | Reject/Defer persists reason on ToolApproval + in ToolActionEvent | unit (changeset, MockRepo) | `mix test test/cairnloop/governance/tool_approval_test.exs` | ❌ Wave 0 |
| FLOW-03 | Reject without reason → changeset error (not persisted) | unit | `mix test test/cairnloop/governance/tool_approval_test.exs` | ❌ Wave 0 |
| D15-14 | Approval card reads snapshotted rendered_consequence, not live Preview.render | unit (presenter test, two-proposal divergence fixture) | `mix test test/cairnloop/governance/preview_test.exs` | ✅ (extend) |
| D15-15 | policy_snapshot and event reason contain no "#Ecto.Changeset<" substring | unit (MockRepo, :needs_input path) | `mix test test/cairnloop/governance/governance_test.exs` | ✅ (extend) |
| D15-12 | Expired approval cannot resume (dual guard: lazy + scheduled) | unit (MockRepo, expired approval fixture) | `mix test test/cairnloop/workers/approval_resume_worker_test.exs` | ❌ Wave 0 |
| APRV-04 | All approval decisions appear in ToolActionEvent timeline (append-only trail) | unit (MockRepo, multi-decision fixture) | `mix test test/cairnloop/governance/governance_test.exs` | ✅ (extend) |
| D15-16 | status_group maps approval states to correct four groups | unit (headless presenter) | `mix test test/cairnloop/web/tool_proposal_presenter_test.exs` | ✅ (extend) |
| D15-16 | history_line/1 produces human-readable lines for all approval event types | unit | `mix test test/cairnloop/web/tool_proposal_presenter_test.exs` | ✅ (extend) |

### Headless vs Repo-required Classification

**Headless / pure-testable (can run in this workspace):**
- All `ToolApproval` changeset tests (validation, decision_changeset, reason required)
- `ToolActionEvent` event_type validity for new approval event atoms
- `ToolProposalPresenter` status_group/approval_outlook/history_line for approval states
- Resume worker logic via `MockRepo` + `enqueue_fn` injection
- Expiry worker logic via `MockRepo` + DateTime injection
- WR-01 humanization: policy_snapshot contains no `#Ecto.Changeset<` (governance_test.exs with MockRepo)
- D15-14 snapshot divergence test (presenter test — no DB needed)
- Append-only invariant: no update/delete on ToolApproval

**Requires Postgres / REPO-UNAVAILABLE:**
- Partial unique index one-active-lane: actual DB insert of second pending approval →
  unique constraint error (mark `# REPO-UNAVAILABLE`)
- JSONB string-key survival in approval snapshot fields after round-trip through Postgres
  (mark `# REPO-UNAVAILABLE`)
- `expires_at` column type and query correctness (mark `# REPO-UNAVAILABLE`)

### Sampling Rate

- **Per task commit:** `mix test test/cairnloop/governance/ test/cairnloop/workers/approval_resume_worker_test.exs test/cairnloop/web/tool_proposal_presenter_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** `mix compile --warnings-as-errors && mix test` — full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/cairnloop/governance/tool_approval_test.exs` — covers APRV-04 (one-active-lane changeset), FLOW-03 (reason required), D15-01 (decision_changeset), append-only invariant
- [ ] `test/cairnloop/workers/approval_resume_worker_test.exs` — covers APRV-02 (validate pass→seam), APRV-03 (validate fail→invalidated), D15-12 (lazy expiry guard), APRV-02 (no run/3)
- [ ] `test/cairnloop/workers/approval_expiry_worker_test.exs` — covers APRV-03 (scheduled flip)
- Extend: `test/cairnloop/governance/governance_test.exs` — APRV-01 (enqueue + no inline execute), D15-15 (WR-01 humanization)
- Extend: `test/cairnloop/governance/preview_test.exs` — D15-14 (snapshotted-vs-live divergence)
- Extend: `test/cairnloop/web/tool_proposal_presenter_test.exs` — D15-16 (approval status groups, history_line for approval events)
- Extend: `test/cairnloop/governance/tool_action_event_test.exs` — new approval event_type values valid

---

## Security Domain

> `security_enforcement` not explicitly set to false in config → security section required.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Actor identity is host-supplied (`actor_id` string); Cairnloop does not authenticate |
| V3 Session Management | No | Host owns sessions; approval decisions captured as `decided_by` string |
| V4 Access Control | Yes | `Policy.resolve/3` + `authorize/2` deny-by-default; no four-eyes enforcement in Phase 15 (D15-08) |
| V5 Input Validation | Yes | `reason` string validated as required for reject/defer; changeset validation; `traverse_errors/2` for error humanization |
| V6 Cryptography | No | No new crypto; idempotency key derivation (sha256) already in governance.ex |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Approve-then-execute race (stale approval executes after policy change) | Elevation of Privilege | Re-validation in resume worker (`Governance.validate/3` against current context); lazy `expires_at` guard; `Policy.resolve/3` re-checked at resume |
| Double-enqueue of resume worker (approve called twice) | Tampering | Oban `unique: [keys: [:approval_id]]` prevents duplicate jobs; idempotent `perform/1` (checks current status) |
| Forced approve on already-resolved approval | Tampering | `Governance.approve/...` validates current status == :pending before transition; partial unique index prevents two active lanes |
| Raw Elixir terms persisted as reasons (WR-01) | Information Disclosure | `traverse_errors/2` humanization; never `inspect/1`; asserted by test |
| Live Preview.render on approval surface (trust drift) | Spoofing / Integrity | Read snapshotted `rendered_consequence`/`title` only; asserted by divergence test |
| Unbounded atoms from JSONB rehydration in resume worker | DoS | `String.to_existing_atom/1` + rescue `ArgumentError` (D-19 guard; already in Preview.ex) |
| Inline execution blocking LiveView process | Availability | `handle_event("approve_action")` only persists + enqueues; all execution is async (APRV-01) |

---

## Assumptions Log

> All claims in this research were verified against source files or authoritative in-repo
> documentation (CONTEXT.md backed by prior phase research). No `[ASSUMED]` items.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | (no assumed claims) | — | — |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

---

## Open Questions (RESOLVED)

> All three resolved inline below; the plans adopt these recommendations (D15-18 makes them planner discretion). No user confirmation needed.

1. **TTL default value**
   - What we know: D15-13 requires a finite default; host-configurable via config/Policy seam.
   - What's unclear: Exact value. 48 hours is conventional for human review windows; 24 hours
     is more aggressive; 7 days is lenient.
   - RESOLVED: Default 48 hours (`172_800` seconds). Planner discretion. Document in
     `@moduledoc` so host knows what to override.

2. **`:invalidated` vs `:expired` — one status or two**
   - What we know: D15-02 says they may merge if the planner finds the distinction noise.
     D15-02 also says operator must be able to tell "timed out" from "policy/scope changed."
   - What's unclear: Whether the timeline UX is clearer with two distinct labels.
   - RESOLVED: Keep both — `:expired` for TTL flip, `:invalidated` for re-validation
     failure. Two event_types (`:expired`, `:revalidation_failed`) drive the history_line
     wording, making the distinction clear even if statuses merge. Given operator legibility
     is required, two statuses is safer.

3. **`enqueue_fn` injection for Governance.approve test isolation**
   - What we know: `knowledge_automation.ex` uses `enqueue_fn` opts injection. Resume worker
     tests use `MockRepo` injection via `Application.put_env`.
   - What's unclear: Whether `Governance.approve/...` should accept `enqueue_fn` as an opt
     or whether `Application.put_env(:cairnloop, :oban_insert_fn, ...)` is cleaner.
   - RESOLVED: `opts` injection (`enqueue_fn` opt defaulting to `&Oban.insert/1`) is
     the established pattern and keeps tests pure. Planner should use it.

---

## Sources

### Primary (HIGH confidence)

- `lib/cairnloop/governance.ex` — confirmed `validate/3` signature, `propose/3` flow, `insert_blocked_proposal/10` WR-01 site at L313
- `lib/cairnloop/knowledge_automation/review_task.ex` — confirmed `@status_values`, denormalized fields, `decision_changeset/6`
- `lib/cairnloop/knowledge_automation.ex` — confirmed `update_task_with_event/4` sequential-`with` idiom (not Ecto.Multi)
- `lib/cairnloop/workers/sla_countdown_worker.ex` — confirmed Oban worker + `fetch_env!` + scheduled_at pattern
- `lib/cairnloop/application.ex` — confirmed host-owned Oban posture (no supervisor, try/rescue)
- `lib/cairnloop/governance/tool_action_event.ex` — confirmed `@event_type_values`, `from_status`/`to_status` enum reference, append-only invariant
- `lib/cairnloop/governance/tool_proposal.ex` — confirmed no `rendered_consequence`/`title` columns, no `has_one(:approval)`
- `lib/cairnloop/governance/policy.ex` — confirmed `_actor_id`/`_context` unused, Phase 15 seam documented
- `lib/cairnloop/governance/preview.ex` — confirmed D-16 guardrail in `@moduledoc`, 4-step mandate
- `lib/cairnloop/web/tool_proposal_presenter.ex` — confirmed `approval_outlook/1`, `history_line/1` catch-all, `status_group/1`
- `lib/cairnloop/web/conversation_live.ex` — confirmed `handle_event("execute_tool")` pattern, `reload_conversation_with_context/2`
- `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs` — confirmed partial unique index style, `:string` enum columns, `updated_at: false`
- `mix.exs` — confirmed Oban ~> 2.17, Ecto ~> 3.10, Phoenix LiveView ~> 1.0
- `lib/cairnloop/chat.ex` — confirmed `scheduled_at:` Oban job insertion pattern
- `lib/cairnloop/retrieval/workers/index_resolved_conversation.ex` — confirmed `unique: [period: 60]` Oban option syntax
- `lib/cairnloop/knowledge_automation/workers/generate_article_suggestion.ex` — confirmed `unique: [fields:, keys:]` syntax

### Secondary (MEDIUM confidence)

- `.planning/phases/15-approval-state-machine-oban-resume/15-CONTEXT.md` — CONTEXT decisions cross-verified against actual code seams above
- `.planning/phases/14-operator-timeline-preview-surface/14-CONTEXT.md` — D-16 guardrail, footer-slot, D-24 catch-all
- `.planning/phases/13-governed-tool-contract-proposal-records/13-CONTEXT.md` — D-15 pure validate/3, D-12 Policy.resolve/3 seam, D-20/21 ReviewTask idiom

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libs already in mix.exs, versions confirmed
- Architecture: HIGH — all seams verified in actual source files with exact line references
- Pitfalls: HIGH — derived from verified code (WR-01 confirmed at L313, idiom mismatches from actual code reading)
- Validation architecture: HIGH — test files verified to exist or not exist; MockRepo pattern confirmed from existing tests

**Research date:** 2026-05-24
**Valid until:** 2026-06-24 (stable Elixir/Oban/Ecto ecosystem; review if Oban major version changes)
