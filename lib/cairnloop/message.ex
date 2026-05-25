defmodule Cairnloop.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cairnloop_messages" do
    field(:content, :string)
    field(:role, Ecto.Enum, values: [:user, :agent, :system, :internal_note], default: :user)
    field(:metadata, :map, default: %{})
    # Phase 16 run-level idempotency key (D16-05).
    # Added by test-host migration 20260525000001_add_run_key_to_messages.exs.
    # A real host app must add this column via its own migration.
    field(:run_key, :string)

    belongs_to(:conversation, Cairnloop.Conversation)

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :role, :conversation_id, :metadata, :run_key])
    |> validate_required([:content, :role])
  end
end
