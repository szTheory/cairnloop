defmodule Cairnloop.KnowledgeAutomation.ReviewTaskEvent do
  use Ecto.Schema
  @schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")
  import Ecto.Changeset

  alias Cairnloop.KnowledgeAutomation.ReviewTask

  @event_type_values [
    :task_created,
    :decision_recorded,
    :publish_recorded,
    :reindex_recorded,
    :material_edit_after_approval
  ]

  schema "cairnloop_review_task_events" do
    field(:event_type, Ecto.Enum, values: @event_type_values)
    field(:from_status, Ecto.Enum, values: ReviewTask.status_values())
    field(:to_status, Ecto.Enum, values: ReviewTask.status_values())
    field(:decision, Ecto.Enum, values: ReviewTask.decision_values())
    field(:reason, Ecto.Enum, values: ReviewTask.reason_values())
    field(:actor_id, :string)
    field(:notes, :string)
    field(:metadata, :map, default: %{})

    belongs_to(:review_task, ReviewTask)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :review_task_id,
      :event_type,
      :from_status,
      :to_status,
      :decision,
      :reason,
      :actor_id,
      :notes,
      :metadata
    ])
    |> validate_required([:review_task_id, :event_type, :to_status, :actor_id])
    |> validate_metadata()
  end

  defp validate_metadata(changeset) do
    case get_field(changeset, :metadata) do
      nil -> put_change(changeset, :metadata, %{})
      value when is_map(value) -> changeset
      _ -> add_error(changeset, :metadata, "must be a map")
    end
  end
end
