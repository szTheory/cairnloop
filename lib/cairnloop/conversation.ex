defmodule Cairnloop.Conversation do
  use Ecto.Schema
  @schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")
  import Ecto.Changeset

  schema "cairnloop_conversations" do
    field(:status, Ecto.Enum, values: [:open, :resolved, :archived], default: :open)
    field(:subject, :string)

    # Operator/governance actor identity. Customer/browser identity belongs in customer_ref.
    field(:host_user_id, :string)
    field(:customer_ref, :string)
    field(:resolved_at, :utc_datetime_usec)
    field(:csat_rating, Ecto.Enum, values: [:positive, :negative])

    has_many(:messages, Cairnloop.Message)
    has_many(:drafts, Cairnloop.Automation.Draft)
    has_many(:tool_proposals, Cairnloop.Governance.ToolProposal)

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:status, :subject, :host_user_id, :customer_ref, :resolved_at, :csat_rating])
    |> validate_required([:status])
  end
end
