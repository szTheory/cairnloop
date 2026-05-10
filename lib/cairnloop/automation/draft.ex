defmodule Cairnloop.Automation.Draft do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cairnloop_drafts" do
    field(:content, :string)
    field(:status, Ecto.Enum, values: [:pending, :approved, :edited, :discarded], default: :pending)

    belongs_to(:conversation, Cairnloop.Conversation)

    timestamps()
  end

  def changeset(draft, attrs) do
    draft
    |> cast(attrs, [:content, :status, :conversation_id])
    |> validate_required([:content, :status, :conversation_id])
  end
end
