defmodule Cairnloop.Retrieval.ResolvedCaseEvidence do
  use Ecto.Schema
  @schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")
  import Ecto.Changeset

  schema "cairnloop_resolved_case_evidences" do
    field(:subject, :string)
    field(:issue_summary, :string)
    field(:resolution_note, :string)
    field(:actions_taken, {:array, :string}, default: [])
    field(:outcome, :string)
    field(:resolved_at, :utc_datetime_usec)
    field(:host_user_id, :string)
    field(:metadata, :map, default: %{})
    field(:citation_backreferences, {:array, :map}, default: [])

    belongs_to(:conversation, Cairnloop.Conversation)
    has_many(:chunks, Cairnloop.Retrieval.ResolvedCaseChunk)

    timestamps()
  end

  def changeset(evidence, attrs) do
    evidence
    |> cast(attrs, [
      :conversation_id,
      :subject,
      :issue_summary,
      :resolution_note,
      :actions_taken,
      :outcome,
      :resolved_at,
      :host_user_id,
      :metadata,
      :citation_backreferences
    ])
    |> validate_required([
      :conversation_id,
      :subject,
      :issue_summary,
      :resolution_note,
      :outcome,
      :resolved_at
    ])
    |> validate_metadata_size()
    |> unique_constraint(:conversation_id,
      name: :cairnloop_resolved_case_evidences_conversation_id_index
    )
  end

  defp validate_metadata_size(changeset) do
    validate_change(changeset, :metadata, fn :metadata, metadata ->
      if map_size(metadata || %{}) <= 10 do
        []
      else
        [metadata: "must contain at most 10 keys"]
      end
    end)
  end
end
