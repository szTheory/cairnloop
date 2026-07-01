defmodule Cairnloop.Governance.ToolActionEvent do
  @moduledoc """
  Append-only audit event record for governed tool proposals.

  Mirrors `ReviewTaskEvent` exactly (D-20, D-21). Every state transition on a
  `ToolProposal` is recorded here alongside it in the same transaction.

  ## Append-Only Invariant

  This schema is **insert-only**. There is no `update/1` or `delete/1` function.
  The `updated_at: false` timestamp option enforces this at the schema level (Pitfall 4).
  App discipline (no update/delete API) enforces it at the application level.

  Phase 16 adds execution event types (`:execution_started`, `:execution_succeeded`,
  `:execution_attempt_failed`, `:execution_failed`) to `@event_type_values` without
  changing this schema's structure (D16-08).
  """

  use Ecto.Schema
  @schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")
  import Ecto.Changeset

  alias Cairnloop.Governance.ToolProposal

  @event_type_values [
    :proposal_created,
    :proposal_blocked,
    # Approval lifecycle (Phase 15) — D15-03
    # from_status/to_status are nil for approval events; transition carried in event_type + metadata
    :approval_requested,
    :approved,
    :rejected,
    :deferred,
    :expired,
    :invalidated,
    :resume_scheduled,
    :revalidation_passed,
    :revalidation_failed,
    # Phase 16 execution lifecycle (D16-08) — append-only, no schema migration needed
    # from_status/to_status are nil for execution events (Pitfall 7: typed against ToolProposal.status_values/0,
    # NOT ToolApproval; execution statuses are NOT ToolProposal statuses — carry in event_type + metadata)
    # optional; emitted before run/3 for latency tracing
    :execution_started,
    # run/3 returned {:ok, result}; co-committed with :executed
    :execution_succeeded,
    # transient failure; Oban will retry up to max_attempts
    :execution_attempt_failed,
    # terminal failure; no further retry
    :execution_failed
  ]

  @proposal_event_types [:proposal_created, :proposal_blocked]

  schema "cairnloop_tool_action_events" do
    field(:event_type, Ecto.Enum, values: @event_type_values)
    field(:from_status, Ecto.Enum, values: ToolProposal.status_values())
    field(:to_status, Ecto.Enum, values: ToolProposal.status_values())
    field(:actor_id, :string)
    field(:reason, :string)
    field(:metadata, :map, default: %{})

    belongs_to(:tool_proposal, ToolProposal)

    # append-only: no updated_at (Pitfall 4 — D-21)
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc """
  Changeset for inserting an append-only `ToolActionEvent`.

  Required fields: `tool_proposal_id`, `event_type`, `to_status`, `actor_id`.
  `from_status` is optional — it is nil for `proposal_created` events (first event has
  no prior status). Nil `metadata` is coerced to `%{}`.
  """
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :tool_proposal_id,
      :event_type,
      :from_status,
      :to_status,
      :actor_id,
      :reason,
      :metadata
    ])
    |> validate_required([:tool_proposal_id, :event_type, :actor_id])
    |> validate_to_status_for_proposal_events()
    |> validate_metadata()
  end

  # :to_status is required only for proposal event types (D15-03).
  # Approval event types carry the transition in event_type + metadata; from_status and
  # to_status remain nil (they are typed against ToolProposal.status_values() — Pitfall 4 preserved).
  defp validate_to_status_for_proposal_events(changeset) do
    event_type = get_field(changeset, :event_type)

    if event_type in @proposal_event_types do
      validate_required(changeset, [:to_status])
    else
      changeset
    end
  end

  defp validate_metadata(changeset) do
    case get_field(changeset, :metadata) do
      nil -> put_change(changeset, :metadata, %{})
      value when is_map(value) -> changeset
      _ -> add_error(changeset, :metadata, "must be a map")
    end
  end

  # NOTE: No update/1 or delete/1 — insert-only API enforces append-only invariant (D-21, Pitfall 4).
end
