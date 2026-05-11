defmodule Cairnloop.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cairnloop_messages" do
    field(:content, :string)
    field(:role, Ecto.Enum, values: [:user, :agent, :system], default: :user)
    field(:metadata, :map, default: %{})

    belongs_to(:conversation, Cairnloop.Conversation)

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :role, :conversation_id, :metadata])
    |> validate_required([:content, :role, :conversation_id])
  end
end
