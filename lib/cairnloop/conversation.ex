defmodule Cairnloop.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cairnloop_conversations" do
    field :status, Ecto.Enum, values: [:open, :resolved, :archived], default: :open
    field :subject, :string
    
    # External reference for the user or host context
    field :host_user_id, :string

    has_many :messages, Cairnloop.Message

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:status, :subject, :host_user_id])
    |> validate_required([:status])
  end
end
