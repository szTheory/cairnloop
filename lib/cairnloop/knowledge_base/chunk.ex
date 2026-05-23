defmodule Cairnloop.KnowledgeBase.Chunk do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cairnloop_chunks" do
    field :chunk_index, :integer
    field :heading, :string
    field :content, :string
    field :embedding, Pgvector.Ecto.Vector

    belongs_to :revision, Cairnloop.KnowledgeBase.Revision

    timestamps()
  end

  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [:chunk_index, :heading, :content, :embedding, :revision_id])
    |> validate_required([:chunk_index, :content, :embedding, :revision_id])
    |> unique_constraint(:chunk_index, name: :cairnloop_chunks_revision_id_chunk_index_index)
  end
end
