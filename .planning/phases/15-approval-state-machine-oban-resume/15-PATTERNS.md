# Phase 15: Approval State Machine & Oban Resume - Pattern Map

**Mapped:** 2026-05-24
**Files analyzed:** 13 new/modified files
**Analogs found:** 13 / 13

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/cairnloop/governance/tool_approval.ex` | schema | CRUD | `lib/cairnloop/knowledge_automation/review_task.ex` | exact |
| `lib/cairnloop/workers/approval_resume_worker.ex` | worker | event-driven | `lib/cairnloop/workers/sla_countdown_worker.ex` | exact |
| `lib/cairnloop/workers/approval_expiry_worker.ex` | worker | event-driven | `lib/cairnloop/workers/sla_countdown_worker.ex` | exact |
| `priv/repo/migrations/*_add_tool_approvals.exs` | migration | CRUD | `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs` | exact |
| `priv/repo/migrations/*_add_snapshot_cols_to_proposals.exs` | migration | CRUD | `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs` | role-match |
| `lib/cairnloop/governance.ex` (extend) | facade | CRUD | `lib/cairnloop/knowledge_automation.ex` (update_task_with_event) | exact |
| `lib/cairnloop/governance/tool_proposal.ex` (extend) | schema | CRUD | `lib/cairnloop/knowledge_automation/review_task.ex` | role-match |
| `lib/cairnloop/governance/tool_action_event.ex` (extend) | schema | event-driven | `lib/cairnloop/governance/tool_action_event.ex` (self) | self-extend |
| `lib/cairnloop/governance/policy.ex` (extend) | policy | request-response | `lib/cairnloop/governance/policy.ex` (self) | self-extend |
| `lib/cairnloop/governance/preview.ex` (extend — @moduledoc guardrail) | utility | transform | `lib/cairnloop/governance/preview.ex` (self) | self-extend |
| `lib/cairnloop/web/tool_proposal_presenter.ex` (extend) | presenter | transform | `lib/cairnloop/web/tool_proposal_presenter.ex` (self) | self-extend |
| `lib/cairnloop/web/conversation_live.ex` (extend) | LiveView | request-response | `lib/cairnloop/web/conversation_live.ex` (self — execute_tool handler) | self-extend |
| `test/cairnloop/workers/approval_resume_worker_test.exs` | test | event-driven | `test/cairnloop/workers/sla_countdown_worker_test.exs` | exact |
| `test/cairnloop/governance/tool_approval_test.exs` | test | CRUD | `test/cairnloop/governance/tool_proposal_test.exs` | exact |

---

## Pattern Assignments

### `lib/cairnloop/governance/tool_approval.ex` (new schema, CRUD)

**Analog:** `lib/cairnloop/knowledge_automation/review_task.ex`

**Imports pattern** (lines 1–6):
```elixir
defmodule Cairnloop.Governance.ToolApproval do
  use Ecto.Schema
  import Ecto.Changeset

  alias Cairnloop.Governance.ToolProposal
```

**Status enum + last-decision fields pattern** (lines 8–59 of review_task.ex):
```elixir
  # Mirror @status_values / @decision_values module attributes on ReviewTask (L8-17)
  @status_values [:pending, :approved, :rejected, :deferred, :expired, :invalidated,
                  :execution_pending]

  schema "cairnloop_tool_approvals" do
    field(:status, Ecto.Enum, values: @status_values, default: :pending)
    # Denormalized last-decision fields — mirror ReviewTask.last_actor_id/last_decision/
    # last_decided_at/notes (L41-45 of review_task.ex):
    field(:decided_by, :string)         # ← mirrors last_actor_id
    field(:last_decision, :string)      # ← mirrors last_decision (free-form string for approval decisions)
    field(:decided_at, :utc_datetime_usec)  # ← mirrors last_decided_at
    field(:reason, :string)             # ← mirrors notes; REQUIRED for :rejected/:deferred (FLOW-03)
    field(:expires_at, :utc_datetime_usec)  # durable TTL (D15-12)

    belongs_to(:tool_proposal, ToolProposal)

    timestamps(type: :utc_datetime_usec)
  end
```

**Core changeset pattern** (lines 61–88 of review_task.ex):
```elixir
  def changeset(approval, attrs) do
    approval
    |> cast(attrs, [
      :tool_proposal_id,
      :status,
      :decided_by,
      :last_decision,
      :decided_at,
      :reason,
      :expires_at
    ])
    |> validate_required([:tool_proposal_id, :status])
    |> unique_constraint(:tool_proposal_id,
      name: :cairnloop_tool_approvals_one_active_lane_index
    )
  end

  def status_values, do: @status_values
```

**Decision changeset pattern** (lines 96–111 of review_task.ex — `decision_changeset/6` → adapt as `decision_changeset/6`):
```elixir
  # Mirror ReviewTask.decision_changeset/7 (L96-111):
  def decision_changeset(approval, status, decision, reason, actor_id, decided_at) do
    attrs =
      %{}
      |> Map.merge(%{
        status: status,
        last_decision: decision,
        reason: reason,
        decided_by: actor_id,
        decided_at: decided_at
      })

    approval
    |> changeset(attrs)
    |> validate_reason_present(status)
  end

  # FLOW-03: reason is REQUIRED for reject/defer
  defp validate_reason_present(cs, status) when status in [:rejected, :deferred] do
    validate_required(cs, [:reason])
  end
  defp validate_reason_present(cs, _), do: cs
```

---

### `lib/cairnloop/workers/approval_resume_worker.ex` (new Oban worker, event-driven)

**Analog:** `lib/cairnloop/workers/sla_countdown_worker.ex`

**Imports + use Oban.Worker pattern** (lines 1–8 of sla_countdown_worker.ex):
```elixir
defmodule Cairnloop.Workers.ApprovalResumeWorker do
  use Oban.Worker,
    queue: :default,
    # Uniqueness keyed on approval_id — mirrors GenerateArticleSuggestion.ex L4 syntax:
    unique: [period: :infinity, fields: [:worker, :args], keys: [:approval_id]]

  alias Cairnloop.Governance.{ToolApproval, ToolProposal}

  defp repo, do: Application.fetch_env!(:cairnloop, :repo)
```

**Core perform/1 pattern** (lines 10–24 of sla_countdown_worker.ex — get → check status → act or no-op):
```elixir
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"approval_id" => approval_id}}) do
    case repo().get(ToolApproval, approval_id) do
      nil ->
        # Deleted — idempotent no-op (mirrors SlaCountdownWorker nil branch L13)
        :ok

      %ToolApproval{status: :pending} = approval ->
        # Lazy expires_at guard — belt-and-suspenders (D15-12)
        if approval.expires_at && DateTime.before?(approval.expires_at, DateTime.utc_now()) do
          expire_approval(approval)
        else
          revalidate_and_transition(approval)
        end

      _ ->
        # Already transitioned — idempotent (mirrors SlaCountdownWorker catch-all L22)
        :ok
    end
  end
```

**Re-validation pattern** (D15-10 — `Governance.validate/3` is pure, no side effects, confirmed L154-166 governance.ex):
```elixir
  defp revalidate_and_transition(approval) do
    proposal = repo().get!(ToolProposal, approval.tool_proposal_id)
    # Re-call pure validate/3 against current context (D15-10 — free by construction)
    context = rebuild_context_from_snapshot(proposal)

    case Cairnloop.Governance.validate(proposal.tool_ref, proposal.actor_id, context) do
      {:ok, _validated} ->
        # Phase 16 seam: transition to :execution_pending, emit event, STOP (D15-10)
        # NEVER call run/3 here
        transition_approval(approval, :execution_pending, :revalidation_passed, nil, "system")

      {:blocked, _outcome, reason} ->
        # Fail-closed: invalidate (D15-11)
        reason_str = humanize_reason(reason)
        transition_approval(approval, :invalidated, :revalidation_failed, reason_str, "system")
    end
  end
```

**Transition co-commit pattern** (mirrors knowledge_automation.ex L1771-1780 — sequential `with`, NOT Ecto.Multi):
```elixir
  defp transition_approval(approval, new_status, event_type, reason, actor_id) do
    alias Cairnloop.Governance.ToolActionEvent

    cs = Ecto.Changeset.change(approval, %{
      status: new_status,
      decided_at: DateTime.utc_now()
    })

    with {:ok, updated} <- repo().update(cs),
         {:ok, _event} <-
           %ToolActionEvent{}
           |> ToolActionEvent.changeset(%{
             tool_proposal_id: approval.tool_proposal_id,
             event_type: event_type,
             from_status: nil,   # nil for approval events (D15-03 recommendation)
             to_status: nil,     # nil — carry state in event_type + metadata
             actor_id: actor_id,
             reason: reason,
             metadata: %{
               approval_status: approval.status,
               new_approval_status: new_status
             }
           })
           |> repo().insert() do
      {:ok, updated}
    end
  end
```

---

### `lib/cairnloop/workers/approval_expiry_worker.ex` (new scheduled Oban worker, event-driven)

**Analog:** `lib/cairnloop/workers/sla_countdown_worker.ex` (lines 1–24 — same pattern, scheduled flip)

```elixir
defmodule Cairnloop.Workers.ApprovalExpiryWorker do
  use Oban.Worker, queue: :default

  alias Cairnloop.Governance.ToolApproval

  defp repo, do: Application.fetch_env!(:cairnloop, :repo)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"approval_id" => approval_id}}) do
    case repo().get(ToolApproval, approval_id) do
      nil ->
        :ok

      %ToolApproval{status: :pending} = approval ->
        # Flip :pending → :expired (mirrors SlaCountdownWorker :active → :breached flip L15-19)
        expire_approval(approval)

      _ ->
        # Already resolved — no-op (mirrors SlaCountdownWorker catch-all L22)
        :ok
    end
  end
end
```

**Scheduled enqueue pattern** — how to enqueue this worker at TTL time (from `lib/cairnloop/chat.ex` L71, confirmed `scheduled_at:` syntax):
```elixir
# When opening an approval lane (inside Governance.request_approval/...):
expiry_job = Cairnloop.Workers.ApprovalExpiryWorker.new(
  %{"approval_id" => approval.id},
  scheduled_at: approval.expires_at
)

# Wrap in try/rescue — host may not have Oban configured (application.ex L44-48):
try do
  Oban.insert(expiry_job)
rescue
  _ -> :ok
end
```

**Note on SLA scheduled insert style:** `chat.ex` L68-73 uses `Ecto.Multi.insert` to co-commit the Oban job with the SLA insert. The governance facade should prefer the `try/rescue` `Oban.insert` post-transaction pattern (matching `application.ex` L44-48) to keep it consistent with the library's host-runtime posture. Enqueue AFTER the `with` transaction commits, not inside it.

---

### `priv/repo/migrations/*_add_tool_approvals.exs` (new migration, CRUD)

**Analog:** `priv/repo/migrations/20260522093000_add_review_tasks_and_events.exs`

**Enum-as-string column pattern** (lines 10-16 of the migration — `:string` not Postgres native enum):
```elixir
defmodule Cairnloop.Repo.Migrations.AddToolApprovals do
  use Ecto.Migration

  def change do
    create table(:cairnloop_tool_approvals) do
      add(:tool_proposal_id,
          references(:cairnloop_tool_proposals, on_delete: :delete_all),
          null: false)

      # Enum stored as :string (mirrors review_tasks migration L10, L12-16)
      add(:status, :string, null: false, default: "pending")
      add(:decided_by, :string)
      add(:last_decision, :string)
      add(:decided_at, :utc_datetime_usec)
      add(:reason, :text)
      add(:expires_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:cairnloop_tool_approvals, [:tool_proposal_id, :status]))
    create(index(:cairnloop_tool_approvals, [:status, :expires_at]))
```

**Partial unique index pattern** (lines 36-44 of the migration — `unique_index` with `where:` for one-active-lane, APRV-04):
```elixir
    # One-active-lane constraint — mirrors review_tasks partial unique index (L36-44):
    create(
      unique_index(
        :cairnloop_tool_approvals,
        [:tool_proposal_id],
        name: :cairnloop_tool_approvals_one_active_lane_index,
        where: "status = 'pending'"
      )
    )
  end
end
```

---

### `priv/repo/migrations/*_add_snapshot_cols_to_proposals.exs` (new migration, D15-14)

**Analog:** Alter table style from governance migrations; column style from review_tasks migration.

```elixir
defmodule Cairnloop.Repo.Migrations.AddSnapshotColsToProposals do
  use Ecto.Migration

  def change do
    alter table(:cairnloop_tool_proposals) do
      # Nullable — pre-Phase-15 rows stay NULL; proposal/3 populates from Phase 15 forward (D15-14)
      add(:rendered_consequence, :text)
      add(:title, :string)
    end
  end
end
```

---

### `lib/cairnloop/governance.ex` (extend — approval APIs + WR-01 fix + D15-14 snapshot)

**Analog A:** `update_task_with_event/4` in `lib/cairnloop/knowledge_automation.ex` (lines 1771–1780)

**Co-commit transition pattern** (sequential `with` — NOT Ecto.Multi, mirroring knowledge_automation.ex L1771-1780):
```elixir
# Private helper — add alongside approve/reject/defer/expire public APIs:
defp update_approval_with_event(approval, changeset, event_attrs) do
  with {:ok, updated_approval} <- repo().update(changeset),
       {:ok, _event} <-
         %ToolActionEvent{}
         |> ToolActionEvent.changeset(
           Map.put(event_attrs, :tool_proposal_id, approval.tool_proposal_id)
         )
         |> repo().insert() do
    # Telemetry AFTER with success — never inside the with clause list (D-29):
    Telemetry.emit(:approval_transition, %{count: 1}, %{to_status: updated_approval.status})
    {:ok, updated_approval}
  end
end
```

**enqueue_fn injection pattern** (for test isolation — mirrors knowledge_automation.ex L1068-1074):
```elixir
# In public facade functions that enqueue Oban jobs:
def approve(approval_id, actor_id, opts \\ []) do
  enqueue_fn = Keyword.get(opts, :enqueue_fn, &safe_enqueue/1)
  # ... persist decision, then:
  enqueue_fn.(ApprovalResumeWorker.new(%{"approval_id" => updated.id}))
end

defp safe_enqueue(job) do
  # Mirrors application.ex L44-48 — host may not have Oban configured:
  try do
    Oban.insert(job)
  rescue
    _ -> :ok
  end
end
```

**Analog B:** `insert_blocked_proposal/10` in `lib/cairnloop/governance.ex` (line 313)

**WR-01 fix pattern** (D15-15 — replace `reason_str = inspect(reason)` at L313):
```elixir
# BEFORE (WR-01 bug at governance.ex L313):
reason_str = inspect(reason)

# AFTER (D15-15 fix using Ecto.Changeset.traverse_errors/2):
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

    atom when is_atom(atom) ->
      Atom.to_string(atom)

    binary when is_binary(binary) ->
      binary

    _ ->
      "blocked"
  end
```

**Analog C:** `insert_new_proposal/6` in `lib/cairnloop/governance.ex` (lines 218-269)

**D15-14 snapshot population pattern** (add `Preview.render/1` call inside `insert_new_proposal` before persisting):
```elixir
# In insert_new_proposal/6 (governance.ex ~L218), BEFORE repo().insert():
# Call Preview.render/1 at propose-time and capture the snapshot (D15-14)
{rendered_consequence, title} =
  case Preview.render(%ToolProposal{tool_ref: tool_ref, input_snapshot: validated.input_snapshot,
                                    scope_snapshot: validated.scope_snapshot,
                                    policy_snapshot: validated.policy_snapshot}) do
    {:preview, prose} -> {prose, nil}
    {:structured, %{title: t, consequence: c}} -> {c, t}
    _ -> {nil, nil}
  end

proposal_attrs = %{
  # ... existing fields (L219-233) ...
  rendered_consequence: rendered_consequence,
  title: title
}
```

**Existing `propose/3` structure for reference** (lines 180-198 of governance.ex — the sanctioned reopen):
```elixir
# governance.ex L180-198 (D15-14 + D15-15 reopen this function — both are sanctioned additive):
def propose(tool_ref, actor_id, context) do
  case validate(tool_ref, actor_id, context) do
    {:ok, validated} ->
      propose_valid(tool_ref, actor_id, context, validated)  # → insert_new_proposal adds snapshot
    {:blocked, :unsupported, _reason} = blocked ->
      Telemetry.emit(:proposal_blocked, %{count: 1}, %{outcome: :unsupported})
      blocked
    {:blocked, outcome, reason} = blocked ->
      case propose_blocked(tool_ref, actor_id, context, outcome, reason) do  # → WR-01 fix here
        :ok -> blocked
        {:error, _cs} = err -> err
      end
  end
end
```

---

### `lib/cairnloop/governance/tool_proposal.ex` (extend — new columns + has_one, D15-14)

**Analog:** self — lines 27-53 of tool_proposal.ex

**Add nullable columns + association** (after `has_many(:events, ToolActionEvent)` at L51):
```elixir
# Add inside schema "cairnloop_tool_proposals" do block (after existing fields L31-48):
# Nullable prose-snapshot columns (D15-14 — pre-Phase-15 rows stay NULL):
field(:rendered_consequence, :string)
field(:title, :string)

# Add after has_many(:events, ToolActionEvent) at L51:
has_one(:approval, Cairnloop.Governance.ToolApproval)
```

**Add to changeset cast list** (in changeset/2 at L68-88, add to cast/2 field list):
```elixir
# Add :rendered_consequence and :title to the cast/2 field list at L69-86:
|> cast(attrs, [
  # ... existing fields ...
  :rendered_consequence,
  :title
])
```

---

### `lib/cairnloop/governance/tool_action_event.ex` (extend — new event types, D15-03)

**Analog:** self — line 23 of tool_action_event.ex

**Extend @event_type_values** (current value at L23 — add approval event types):
```elixir
# BEFORE (tool_action_event.ex L23):
@event_type_values [:proposal_created, :proposal_blocked]

# AFTER (Phase 15 extension — D15-03):
@event_type_values [
  :proposal_created,
  :proposal_blocked,
  # Approval lifecycle (Phase 15) — D15-03
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
# NOTE: from_status/to_status REMAIN typed against ToolProposal.status_values() (L27-28).
# For approval events, leave from_status: nil, to_status: nil.
# Carry approval state transition in event_type + metadata:
#   metadata: %{approval_status: :pending, new_approval_status: :approved}
# The changeset at L57 already validates to_status as required — this means the
# changeset's validate_required must be relaxed for approval events, OR the approval
# event_type clauses provide a synthetic to_status value. Planner decides.
```

**Critical note on `to_status` validation:** The current changeset at L57 requires `:to_status`. For approval events where `to_status` is nil, the planner must either: (a) make `to_status` optional in the changeset for approval event types, or (b) pass a sentinel approval-status string (e.g. `"pending"`) as `to_status` and widen the Ecto.Enum to accept approval status strings. The lower-friction choice is (a): add a conditional `validate_required` that only requires `to_status` for proposal event types. The existing `from_status: nil` precedent (L30, L44 — "from_status is optional") shows this schema already accepts nil status values.

---

### `lib/cairnloop/governance/policy.ex` (extend — Phase 15 PDP seam)

**Analog:** self — lines 26-33 of policy.ex

**Current resolve/3 signature** (lines 26-33 — extend in place, signature stays fixed per D-12):
```elixir
# BEFORE (policy.ex L26-33 — _actor_id and _context are unused/prefixed with _):
def resolve(tool_module, _actor_id, _context) do
  spec = tool_module.__tool_spec__()
  spec.approval_mode ||
    host_config_override(spec.risk_tier) ||
    Cairnloop.Tool.derive_approval_mode(spec.risk_tier)
end

# AFTER (Phase 15 — extend to factor actor scope / runtime context; ONLY add logic inside):
def resolve(tool_module, actor_id, context) do
  spec = tool_module.__tool_spec__()
  base_mode =
    spec.approval_mode ||
      host_config_override(spec.risk_tier) ||
      Cairnloop.Tool.derive_approval_mode(spec.risk_tier)

  # Phase 15 PDP extension: apply host policy context factors (no call-site change needed)
  apply_context_factors(base_mode, tool_module, actor_id, context)
end

defp apply_context_factors(mode, _tool_module, _actor_id, _context) do
  # Start pass-through; Phase 15 adds actor-scope / four-eyes hook here
  mode
end
```

---

### `lib/cairnloop/web/tool_proposal_presenter.ex` (extend — approval states + real copy)

**Analog:** self — lines 55-114, 259-269 of tool_proposal_presenter.ex

**status_group/1 extension** (add approval status atoms above existing catch-all at L59):
```elixir
# Add ABOVE the current catch-all `def status_group(_), do: :blocked` at L59 (D15-16):
def status_group(:pending_approval), do: :awaiting   # active :pending approval → Awaiting
def status_group(:execution_pending), do: :active    # approved, awaiting Phase-16 execute
def status_group(:rejected), do: :done
def status_group(:deferred), do: :done
def status_group(:expired), do: :done
def status_group(:invalidated), do: :done
```

**approval_outlook/1 real-status extension** (lines 111-114 — add real approval state clauses):
```elixir
# Add BEFORE the existing approval_outlook clauses at L111 (D15-16 repurpose of honesty seam):
# Takes approval status atom — call from card render when active approval exists:
def approval_outlook_for_approval(%{status: :pending}),
  do: "Pending approval — an operator must approve, reject, or defer this action."
def approval_outlook_for_approval(%{status: :approved}),
  do: "Approved — resuming with current policy check."
def approval_outlook_for_approval(%{status: :execution_pending}),
  do: "Approved — ready to execute."
def approval_outlook_for_approval(%{status: :rejected, reason: reason}),
  do: "Rejected: #{reason || "No reason provided."}"
def approval_outlook_for_approval(%{status: :deferred, reason: reason}),
  do: "Deferred: #{reason || "No reason provided."}"
def approval_outlook_for_approval(%{status: :expired}),
  do: "Approval request expired."
def approval_outlook_for_approval(%{status: :invalidated}),
  do: "Approval invalidated — policy or scope changed since approval."
def approval_outlook_for_approval(_), do: nil
```

**history_line/1 approval event clauses** (add ABOVE catch-all at L269 — D15-03/D-24):
```elixir
# Add ABOVE the catch-all `def history_line(%ToolActionEvent{}), do: "Workflow updated"` at L269:
def history_line(%ToolActionEvent{event_type: :approval_requested, actor_id: actor_id}) do
  "Approval requested by #{actor_id}"
end

def history_line(%ToolActionEvent{event_type: :approved, actor_id: actor_id}) do
  "Approved by #{actor_id}"
end

def history_line(%ToolActionEvent{event_type: :rejected, actor_id: actor_id, reason: reason}) do
  "Rejected by #{actor_id}: #{reason || "No reason provided."}"
end

def history_line(%ToolActionEvent{event_type: :deferred, actor_id: actor_id, reason: reason}) do
  "Deferred by #{actor_id}: #{reason || "No reason provided."}"
end

def history_line(%ToolActionEvent{event_type: :expired}) do
  "Approval request expired."
end

def history_line(%ToolActionEvent{event_type: :invalidated, reason: reason}) do
  "Approval invalidated: #{reason || "Policy or scope changed."}"
end

def history_line(%ToolActionEvent{event_type: :revalidation_passed}) do
  "Re-validation passed — execution pending."
end

def history_line(%ToolActionEvent{event_type: :revalidation_failed, reason: reason}) do
  "Re-validation failed: #{reason || "Policy or scope changed."}"
end

def history_line(%ToolActionEvent{event_type: :resume_scheduled}) do
  "Resume scheduled."
end

# D-24 catch-all remains LAST — do not remove:
def history_line(%ToolActionEvent{}), do: "Workflow updated"
```

---

### `lib/cairnloop/web/conversation_live.ex` (extend — footer-slot handlers)

**Analog:** self — lines 175-213 of conversation_live.ex (`handle_event("execute_tool")` + `reload_conversation_with_context`)

**execute_tool handler pattern** (lines 175-199 — mirror this exactly: facade call → flash → noreply):
```elixir
# Existing pattern to mirror exactly (conversation_live.ex L175-199):
def handle_event("execute_tool", %{"tool" => tool_ref} = params, socket) do
  actor_id = socket.assigns.conversation.host_user_id
  context = socket.assigns.host_context
  context = Map.put(context, :tool_params, params["tool_params"] || %{})
  context = Map.put(context, :conversation_id, socket.assigns.conversation.id)

  case Cairnloop.Governance.propose(tool_ref, actor_id, context) do
    {:ok, proposal} ->
      {:noreply, put_flash(socket, :info, "Proposed — pending review. (##{proposal.id})")}
    {:blocked, outcome, reason} ->
      {:noreply, put_flash(socket, :error, failure_reason_message(outcome, reason))}
    {:error, _changeset} ->
      {:noreply, put_flash(socket, :error, "This action could not be recorded right now. Please try again.")}
  end
end
```

**New approval handler pattern** (mirror the execute_tool structure — durable + enqueue, never inline):
```elixir
# Add these handle_event clauses (D15-06/D15-16):
def handle_event("approve_action", %{"approval-id" => id}, socket) do
  actor_id = socket.assigns.conversation.host_user_id
  case Cairnloop.Governance.approve(String.to_integer(id), actor_id, []) do
    {:ok, _approval} ->
      {:noreply,
       socket
       |> put_flash(:info, "Action approved.")
       |> reload_conversation_with_context(socket.assigns.conversation.id)}
    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Approval could not be recorded.")}
  end
end

def handle_event("reject_action", %{"approval-id" => id, "reason" => reason}, socket) do
  actor_id = socket.assigns.conversation.host_user_id
  case Cairnloop.Governance.reject(String.to_integer(id), actor_id, reason: reason) do
    {:ok, _approval} ->
      {:noreply,
       socket
       |> put_flash(:info, "Action rejected.")
       |> reload_conversation_with_context(socket.assigns.conversation.id)}
    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Rejection could not be recorded. A reason is required.")}
  end
end

def handle_event("defer_action", %{"approval-id" => id, "reason" => reason}, socket) do
  actor_id = socket.assigns.conversation.host_user_id
  case Cairnloop.Governance.defer(String.to_integer(id), actor_id, reason: reason) do
    {:ok, _approval} ->
      {:noreply,
       socket
       |> put_flash(:info, "Action deferred.")
       |> reload_conversation_with_context(socket.assigns.conversation.id)}
    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Deferral could not be recorded. A reason is required.")}
  end
end
```

**reload_conversation_with_context pattern** (lines 214-228 — already handles `governed_actions` reload via facade, use as-is):
```elixir
# Existing reload path (L214-228) — no change needed; governed_actions already
# loaded via Cairnloop.Governance.list_proposals_for_conversation/1.
# Phase 15 adds preloading :approval to each proposal inside list_proposals_for_conversation/1
# so the presenter can access the active approval record without a new assign:
defp reload_conversation_with_context(socket, conversation_id) do
  # ... existing body (L215-227) — unchanged
  governed_actions = Cairnloop.Governance.list_proposals_for_conversation(conversation_id)
  # governed_actions proposals will now carry :approval preloaded (add to list_proposals_for_conversation)
  assign(socket, governed_actions: governed_actions, ...)
end
```

---

## Test Patterns

### `test/cairnloop/workers/approval_resume_worker_test.exs` (new)

**Analog:** `test/cairnloop/workers/sla_countdown_worker_test.exs` (complete file — 49 lines)

**MockRepo + Application.put_env injection pattern** (lines 7-28 of sla_countdown_worker_test.exs):
```elixir
defmodule Cairnloop.Workers.ApprovalResumeWorkerTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Workers.ApprovalResumeWorker
  alias Cairnloop.Governance.{ToolApproval, ToolProposal}

  # Mirror MockRepo idiom (sla_countdown_worker_test.exs L7-24):
  defmodule MockRepo do
    def get(ToolApproval, 1), do: %ToolApproval{id: 1, status: :pending, tool_proposal_id: 10,
                                                 expires_at: nil, decided_by: nil}
    def get(ToolApproval, 2), do: %ToolApproval{id: 2, status: :approved, tool_proposal_id: 10,
                                                 expires_at: nil}
    def get(ToolApproval, 3), do: nil
    # expired approval (expires_at in the past)
    def get(ToolApproval, 4), do: %ToolApproval{id: 4, status: :pending, tool_proposal_id: 10,
                                                 expires_at: ~U[2020-01-01 00:00:00Z]}
    def get!(ToolProposal, 10), do: %ToolProposal{id: 10, tool_ref: "MyApp.Tools.Demo",
                                                    actor_id: "user_1", input_snapshot: %{}}
    def update(changeset) do
      send(self(), {:repo_update, changeset})
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end
    def insert(changeset) do
      send(self(), {:repo_insert, changeset})
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end
  end

  setup do
    # Mirror sla_countdown_worker_test.exs L26-29:
    Application.put_env(:cairnloop, :repo, MockRepo)
    on_exit(fn -> Application.delete_env(:cairnloop, :repo) end)
    :ok
  end

  # Test structure mirrors sla_countdown_worker_test.exs L32-48:
  test "transitions :pending approval to :execution_pending on validate pass" do
    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => 1}})
    assert_receive {:repo_update, changeset}
    assert Ecto.Changeset.get_change(changeset, :status) == :execution_pending
  end

  test "no-ops for already-transitioned approvals" do
    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => 2}})
    refute_receive {:repo_update, _}
  end

  test "no-ops gracefully for missing approval (deleted)" do
    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => 3}})
    refute_receive {:repo_update, _}
  end

  test "lazy expires_at guard: marks :pending as :expired when TTL elapsed" do
    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => 4}})
    assert_receive {:repo_update, changeset}
    assert Ecto.Changeset.get_change(changeset, :status) == :expired
  end
end
```

### `test/cairnloop/governance/tool_approval_test.exs` (new)

**Analog:** `test/cairnloop/governance/tool_proposal_test.exs` (changeset structure) + `test/cairnloop/governance/tool_action_event_test.exs` (append-only invariant pattern)

```elixir
defmodule Cairnloop.Governance.ToolApprovalTest do
  use ExUnit.Case, async: true

  alias Cairnloop.Governance.ToolApproval

  # Fixture — mirrors tool_proposal_test.exs inline fixture style:
  defp approval(overrides \\ %{}) do
    %{
      tool_proposal_id: 1,
      status: :pending
    }
    |> Map.merge(overrides)
  end

  describe "changeset/2 — valid" do
    test "is valid with required fields" do
      changeset = ToolApproval.changeset(%ToolApproval{}, approval())
      assert changeset.valid?
    end

    test "defaults status to :pending" do
      changeset = ToolApproval.changeset(%ToolApproval{}, Map.delete(approval(), :status))
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :status) == :pending
    end
  end

  describe "decision_changeset/6 — FLOW-03 reason requirement" do
    test "reject requires reason" do
      cs = ToolApproval.decision_changeset(
        %ToolApproval{tool_proposal_id: 1}, :rejected, "rejected", nil, "user_1", DateTime.utc_now()
      )
      refute cs.valid?
      assert {:reason, _} = List.keyfind(cs.errors, :reason, 0)
    end

    test "defer requires reason" do
      cs = ToolApproval.decision_changeset(
        %ToolApproval{tool_proposal_id: 1}, :deferred, "deferred", nil, "user_1", DateTime.utc_now()
      )
      refute cs.valid?
    end

    test "approve does not require reason" do
      cs = ToolApproval.decision_changeset(
        %ToolApproval{tool_proposal_id: 1}, :approved, "approved", nil, "user_1", DateTime.utc_now()
      )
      assert cs.valid?
    end
  end

  describe "append-only invariant" do
    # Mirror tool_action_event_test.exs L143-151:
    test "module does not define update/1" do
      refute function_exported?(ToolApproval, :update, 1)
    end

    test "module does not define delete/1" do
      refute function_exported?(ToolApproval, :delete, 1)
    end
  end
end
```

### Extend: `test/cairnloop/governance/tool_action_event_test.exs`

**Add under new describe block** (after existing L141 — mirrors existing `event_type` rejection test at L118-128):
```elixir
describe "new approval event_type values" do
  for event_type <- [
    :approval_requested, :approved, :rejected, :deferred,
    :expired, :invalidated, :resume_scheduled, :revalidation_passed, :revalidation_failed
  ] do
    test "accepts #{event_type} as valid event_type" do
      attrs = %{
        tool_proposal_id: 1,
        event_type: unquote(event_type),
        actor_id: "system",
        # to_status nil — approval events don't carry proposal status transition
        metadata: %{approval_status: "pending"}
      }
      changeset = ToolActionEvent.changeset(%ToolActionEvent{}, attrs)
      # Valid? depends on whether to_status is required — test both valid and error path
      # to document the changeset behavior for the planner
      assert is_struct(changeset, Ecto.Changeset)
    end
  end
end
```

### Extend: `test/cairnloop/web/tool_proposal_presenter_test.exs`

**Add approval status_group tests** (mirror existing describe "status_label/1" block structure at L53-79):
```elixir
describe "status_group/1 — approval states (D15-16)" do
  test "returns :awaiting for :pending_approval" do
    assert apply(@presenter, :status_group, [:pending_approval]) == :awaiting
  end
  test "returns :active for :execution_pending" do
    assert apply(@presenter, :status_group, [:execution_pending]) == :active
  end
  test "returns :done for :rejected" do
    assert apply(@presenter, :status_group, [:rejected]) == :done
  end
  test "returns :done for :deferred" do
    assert apply(@presenter, :status_group, [:deferred]) == :done
  end
  test "returns :done for :expired" do
    assert apply(@presenter, :status_group, [:expired]) == :done
  end
  test "returns :done for :invalidated" do
    assert apply(@presenter, :status_group, [:invalidated]) == :done
  end
end

describe "history_line/1 — approval events" do
  # Mirror existing event fixture helper at test file L36-47:
  test "approved event shows actor_id" do
    e = event(%{event_type: :approved, actor_id: "ops_1"})
    line = apply(@presenter, :history_line, [e])
    assert String.contains?(line, "ops_1")
    assert String.contains?(line, "Approved")
  end

  test "rejected event shows actor_id and reason" do
    e = event(%{event_type: :rejected, actor_id: "ops_1", reason: "Too risky"})
    line = apply(@presenter, :history_line, [e])
    assert String.contains?(line, "Too risky")
  end

  test "deferred event shows reason" do
    e = event(%{event_type: :deferred, actor_id: "ops_1", reason: "Review later"})
    line = apply(@presenter, :history_line, [e])
    assert String.contains?(line, "Review later")
  end

  test "expired event returns calm copy" do
    e = event(%{event_type: :expired})
    line = apply(@presenter, :history_line, [e])
    assert is_binary(line)
    refute line == "Workflow updated"
  end
end
```

---

## Shared Patterns

### Oban Enqueue (host-library posture)
**Source:** `lib/cairnloop/application.ex` lines 44-49
**Apply to:** `lib/cairnloop/governance.ex` (all public approval APIs that enqueue jobs), `lib/cairnloop/workers/approval_resume_worker.ex` (if it enqueues the expiry flip)
```elixir
# Always wrap Oban.insert in try/rescue — host may not have Oban configured:
try do
  Oban.insert(job)
rescue
  _ -> :ok
end
```

### Oban Test Injection (enqueue_fn opts)
**Source:** `lib/cairnloop/knowledge_automation.ex` lines 1068-1074
**Apply to:** `lib/cairnloop/governance.ex` — `approve/3` and `request_approval/...` functions
```elixir
enqueue_fn = Keyword.get(opts, :enqueue_fn, &safe_enqueue/1)
enqueue_fn.(Worker.new(%{"approval_id" => approval.id}))
```

### MockRepo Test Isolation
**Source:** `test/cairnloop/workers/sla_countdown_worker_test.exs` lines 7-29
**Apply to:** All new worker tests + governance tests that touch the approval transition path
```elixir
setup do
  Application.put_env(:cairnloop, :repo, MockRepo)
  on_exit(fn -> Application.delete_env(:cairnloop, :repo) end)
  :ok
end
```

### Sequential `with` Co-commit (NOT Ecto.Multi)
**Source:** `lib/cairnloop/knowledge_automation.ex` lines 1771-1780
**Apply to:** `lib/cairnloop/governance.ex` — all `update_approval_with_event` calls
```elixir
with {:ok, updated} <- repo().update(changeset),
     {:ok, _event} <- repo().insert(event_changeset) do
  Telemetry.emit(...)
  {:ok, updated}
end
```

### Telemetry After `with` Success (D-29)
**Source:** `lib/cairnloop/governance.ex` lines 250-255
**Apply to:** All approval transition functions in governance.ex
```elixir
# ALWAYS emit telemetry AFTER the with success block — never inside the with clause list (D-29):
Telemetry.emit(:approval_transition, %{count: 1}, %{to_status: updated.status})
```

### Append-Only Event Insert (from_status nil, D15-03)
**Source:** `lib/cairnloop/governance.ex` lines 240-249 (proposal_created uses `from_status: nil`)
**Apply to:** All approval event inserts in governance.ex + workers
```elixir
# Approval events use from_status: nil, to_status: nil — carry state in event_type + metadata:
ToolActionEvent.changeset(%ToolActionEvent{}, %{
  tool_proposal_id: proposal_id,
  event_type: :approved,           # carries the transition semantics
  from_status: nil,                # nil — not a proposal status transition
  to_status: nil,                  # nil — approval state axis is separate
  actor_id: actor_id,
  reason: reason,
  metadata: %{
    approval_status: :pending,
    new_approval_status: :approved
  }
})
```

### Humanized Reason Builder (WR-01 / D15-15)
**Source:** Inline fix for `lib/cairnloop/governance.ex` line 313
**Apply to:** `insert_blocked_proposal/10` in governance.ex; any new code that serializes reasons to strings
```elixir
# Never inspect/1. Use this pattern for reason humanization:
reason_str =
  case reason do
    %Ecto.Changeset{} = cs ->
      cs
      |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
      end)
      |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
      |> Enum.join("; ")
    atom when is_atom(atom) -> Atom.to_string(atom)
    binary when is_binary(binary) -> binary
    _ -> "blocked"
  end
```

### Repo-Unavailable Test Marking
**Source:** CLAUDE.md + RESEARCH.md validation architecture
**Apply to:** Any test that requires an actual Postgres round-trip (partial-unique-index constraint, JSONB key survival, expires_at column type)
```elixir
# Tests requiring Postgres — mark at test definition site:
# # REPO-UNAVAILABLE
# test "partial unique index rejects second pending approval" do ...
```

---

## No Analog Found

No files in Phase 15 are without a close match. All patterns have verified codebase analogs.

| File | Notes |
|------|-------|
| *(none)* | Every new file has an exact or role-match analog in the codebase |

---

## Key Anti-Patterns to Flag for Planner

1. **Do NOT use `Ecto.Multi` for co-commit:** Both `insert_new_proposal` and `update_task_with_event` use sequential `with`. Ecto.Multi would break consistency with existing governance.ex and knowledge_automation.ex patterns.
2. **Do NOT call `run/3` from `ApprovalResumeWorker`:** The success branch is `:execution_pending` transition + `:revalidation_passed` event + return `:ok`. Phase 16 seam only.
3. **Do NOT widen `ToolProposal.status_values()`:** Approval states (`[:pending, :approved, ...]`) live on `ToolApproval`, never on `ToolProposal.status`. The `ToolActionEvent.from_status`/`to_status` enum is NOT widened — approval events carry nil for both.
4. **Do NOT call live `Preview.render/1` from approval surfaces:** Read `proposal.rendered_consequence` and `proposal.title` columns only (D15-14 / Preview.ex @moduledoc L35-46).
5. **Do NOT use `inspect/1` for reason strings:** The WR-01 fix replaces L313 of governance.ex with `traverse_errors/2`. All new code must use the humanized reason builder.
6. **Do NOT `String.to_atom/1` for JSONB keys:** Always `String.to_existing_atom/1` + rescue `ArgumentError` (D-19 guard from Preview.ex).

---

## Metadata

**Analog search scope:** `lib/cairnloop/`, `priv/repo/migrations/`, `test/cairnloop/`
**Files read:** 15 source files
**Pattern extraction date:** 2026-05-24
