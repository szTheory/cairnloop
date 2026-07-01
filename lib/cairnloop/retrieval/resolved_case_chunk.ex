defmodule Cairnloop.Retrieval.ResolvedCaseChunk do
  use Ecto.Schema
  @schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")
  import Ecto.Changeset

  schema "cairnloop_resolved_case_chunks" do
    field(:chunk_index, :integer)
    field(:content, :string)
    field(:embedding, Pgvector.Ecto.Vector)

    belongs_to(:resolved_case_evidence, Cairnloop.Retrieval.ResolvedCaseEvidence)

    timestamps()
  end

  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [:resolved_case_evidence_id, :chunk_index, :content, :embedding])
    |> validate_required([:resolved_case_evidence_id, :chunk_index, :content, :embedding])
    |> unique_constraint(:chunk_index,
      name: :cairnloop_resolved_case_chunks_resolved_case_evidence_id_chunk_index_index
    )
  end
end
