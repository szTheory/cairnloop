defmodule Cairnloop.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cairnloop_conversations" do
    field(:status, Ecto.Enum, values: [:open, :resolved, :archived], default: :open)
    field(:subject, :string)

    # External reference for the user or host context
    field(:host_user_id, :string)
    field(:resolved_at, :utc_datetime_usec)

    has_many(:messages, Cairnloop.Message)
    has_many(:drafts, Cairnloop.Automation.Draft)

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:status, :subject, :host_user_id, :resolved_at])
    |> validate_required([:status])
  end
end
