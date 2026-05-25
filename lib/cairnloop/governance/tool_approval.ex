defmodule Cairnloop.Governance.ToolApproval do
  @moduledoc """
  Durable approval record for a governed tool proposal.

  Mirrors the `ReviewTask` idiom exactly (D15-01..04):
  - Denormalized `status` enum for read-your-writes
  - Last-decision fields (`decided_by`, `last_decision`, `decided_at`, `reason`)
  - Transitions co-committed with an append-only `ToolActionEvent` in one transaction
  - One-active-lane enforced by a partial unique index on `tool_proposal_id WHERE status = 'pending'` (APRV-04)

  ## Append-Only Invariant

  This schema is **insert-only** for the approval record itself. Status transitions are
  written via `decision_changeset/6` which updates the denormalized fields. There is no
  `update/1` or `delete/1` function — the `ToolActionEvent` trail is the immutable audit log.

  ## Status Axis (D15-02, D16-08)

  The approval status axis is separate from `ToolProposal.status`:
  - `:pending` — awaiting operator decision (one active lane enforced by partial unique index)
  - `:approved` — operator approved; resume worker will re-validate and transition to `:execution_pending`
  - `:execution_pending` — re-validation passed; `ToolExecutionWorker` enqueued (Phase 16)
  - `:rejected` — operator rejected with reason (FLOW-03)
  - `:deferred` — operator deferred with reason (FLOW-03)
  - `:expired` — TTL elapsed; dual mechanism (scheduled Oban job + lazy guard at resume time)
  - `:invalidated` — re-validation failed; policy/scope changed since approval
  - `:executed` — Phase 16 success terminal; `run/3` returned `{:ok, result}` and outcome co-committed
  - `:execution_failed` — Phase 16 failure terminal; exhausted retries or permanent re-validation failure
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Cairnloop.Governance.ToolProposal

  @status_values [
    :pending,
    :approved,
    :execution_pending,
    :rejected,
    :deferred,
    :expired,
    :invalidated,
    # Phase 16 terminal execution statuses (D16-08) — append only, no DDL needed (status is :string storage)
    :executed,           # success terminal — run/3 returned {:ok, result} and was co-committed
    :execution_failed    # failure terminal — exhausted retries or permanent re-validation failure
  ]

  schema "cairnloop_tool_approvals" do
    field(:status, Ecto.Enum, values: @status_values, default: :pending)

    # Denormalized last-decision fields — mirrors ReviewTask idiom (D15-01)
    field(:decided_by, :string)
    field(:last_decision, :string)
    field(:decided_at, :utc_datetime_usec)
    field(:reason, :string)

    # Durable TTL for expiry (D15-12)
    field(:expires_at, :utc_datetime_usec)

    belongs_to(:tool_proposal, ToolProposal)

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Returns the locked status values for `ToolApproval`.
  """
  def status_values, do: @status_values

  @doc """
  Standard changeset for creating or updating a `ToolApproval`.
  Requires: `tool_proposal_id`, `status`.
  Status defaults to `:pending`.
  Registers the partial unique index constraint for one-active-lane enforcement (APRV-04).
  """
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

  @doc """
  Decision changeset for transitioning an approval to a new status.

  Parameters:
  - `approval` — the existing `ToolApproval` struct
  - `status` — the new status atom
  - `decision` — free-form decision label (e.g. `"approved"`, `"rejected"`)
  - `reason` — operator-provided reason; REQUIRED for `:rejected` and `:deferred` (FLOW-03)
  - `actor_id` — the actor making the decision
  - `decided_at` — timestamp of the decision

  Enforces FLOW-03: reason is required for `:rejected` and `:deferred` transitions.
  """
  def decision_changeset(approval, status, decision, reason, actor_id, decided_at) do
    attrs = %{
      status: status,
      last_decision: decision,
      reason: reason,
      decided_by: actor_id,
      decided_at: decided_at
    }

    approval
    |> changeset(attrs)
    |> validate_reason_present(status)
  end

  # FLOW-03: reason is REQUIRED for reject/defer
  defp validate_reason_present(changeset, status) when status in [:rejected, :deferred] do
    validate_required(changeset, [:reason])
  end

  defp validate_reason_present(changeset, _status), do: changeset

  # NOTE: No update/1 or delete/1 — approval decisions are co-committed with ToolActionEvent
  # inserts as the immutable audit trail. The denormalized status is updated via decision_changeset/6.
end
