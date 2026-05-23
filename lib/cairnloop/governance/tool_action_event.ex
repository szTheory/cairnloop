defmodule Cairnloop.Governance.ToolActionEvent do
  @moduledoc """
  Append-only audit event record for governed tool proposals.

  Mirrors `ReviewTaskEvent` exactly (D-20, D-21). Every state transition on a
  `ToolProposal` is recorded here alongside it in the same transaction.

  ## Append-Only Invariant

  This schema is **insert-only**. There is no `update/1` or `delete/1` function.
  The `updated_at: false` timestamp option enforces this at the schema level (Pitfall 4).
  App discipline (no update/delete API) enforces it at the application level.

  Phase 16 will add execution event types (e.g. `:execution_started`, `:execution_succeeded`)
  to `@event_type_values` without changing this schema's structure.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Cairnloop.Governance.ToolProposal

  @event_type_values [:proposal_created, :proposal_blocked]

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
    |> validate_required([:tool_proposal_id, :event_type, :to_status, :actor_id])
    |> validate_metadata()
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
