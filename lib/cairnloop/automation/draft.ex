defmodule Cairnloop.Automation.Draft do
  use Ecto.Schema
  @schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")
  import Ecto.Changeset

  schema "cairnloop_drafts" do
    field(:content, :string)

    field(:proposal_type, Ecto.Enum,
      values: [:reply, :clarification, :escalation],
      default: :reply
    )

    field(:operator_summary, :string)
    field(:customer_reply, :string)
    field(:evidence_snapshot, :map, default: %{})
    field(:grounding_metadata, :map, default: %{})
    field(:clarification_attempts, :integer, default: 0)

    field(:status, Ecto.Enum,
      values: [:pending, :approved, :edited, :discarded],
      default: :pending
    )

    belongs_to(:conversation, Cairnloop.Conversation)

    timestamps()
  end

  def changeset(draft, attrs) do
    draft
    |> cast(attrs, [
      :content,
      :proposal_type,
      :operator_summary,
      :customer_reply,
      :evidence_snapshot,
      :grounding_metadata,
      :clarification_attempts,
      :status,
      :conversation_id
    ])
    |> sync_content_from_reply()
    |> validate_required([:status, :conversation_id, :proposal_type])
    |> validate_reply_present()
  end

  def reply_content(%__MODULE__{} = draft) do
    draft.customer_reply || draft.content
  end

  defp sync_content_from_reply(changeset) do
    case get_field(changeset, :content) || get_field(changeset, :customer_reply) do
      value when is_binary(value) and value != "" -> put_change(changeset, :content, value)
      _ -> changeset
    end
  end

  defp validate_reply_present(changeset) do
    if blank?(get_field(changeset, :content)) and blank?(get_field(changeset, :customer_reply)) do
      add_error(changeset, :customer_reply, "can't be blank")
    else
      changeset
    end
  end

  defp blank?(value), do: value in [nil, ""]
end
