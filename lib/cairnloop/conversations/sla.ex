defmodule Cairnloop.Conversations.SLA do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cairnloop_conversation_slas" do
    belongs_to(:conversation, Cairnloop.Conversation)

    field(:target_type, Ecto.Enum, values: [:first_response, :next_response, :resolution])
    field(:status, Ecto.Enum, values: [:active, :fulfilled, :breached])

    field(:target_at, :utc_datetime_usec)
    # When it was fulfilled or breached
    field(:completed_at, :utc_datetime_usec)

    timestamps()
  end

  def changeset(sla, attrs) do
    sla
    |> cast(attrs, [:target_type, :status, :target_at, :completed_at, :conversation_id])
    |> validate_required([:target_type, :status, :target_at, :conversation_id])
  end
end
