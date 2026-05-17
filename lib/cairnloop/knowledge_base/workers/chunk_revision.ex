defmodule Cairnloop.KnowledgeBase.Workers.ChunkRevision do
  use Oban.Worker, queue: :default, unique: [period: 60]

  alias Cairnloop.KnowledgeBase.{Revision, Chunk, MarkdownParser}
  alias Cairnloop.Embedder.ExternalApi
  import Ecto.Query

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"revision_id" => revision_id}}) do
    :telemetry.execute([:openinference, :span, :start], %{}, %{name: "chunk_revision"})

    result =
      case repo().get(Revision, revision_id) do
        nil ->
          {:error, :revision_not_found}

        %Revision{content: content} ->
          chunks = MarkdownParser.parse(content || "")

          case ExternalApi.generate_embeddings(chunks) do
            {:ok, embeddings} ->
              now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

              chunk_records =
                Enum.zip(chunks, embeddings)
                |> Enum.map(fn {text, vector} ->
                  %{
                    revision_id: revision_id,
                    content: text,
                    embedding: Pgvector.new(vector),
                    inserted_at: now,
                    updated_at: now
                  }
                end)

              Ecto.Multi.new()
              |> Ecto.Multi.delete_all(:delete_old_chunks, from(c in Chunk, where: c.revision_id == ^revision_id))
              |> Ecto.Multi.insert_all(:insert_chunks, Chunk, chunk_records)
              |> repo().transaction()

              :ok

            {:error, reason} ->
              {:error, reason}
          end
      end

    :telemetry.execute([:openinference, :span, :stop], %{}, %{name: "chunk_revision", status: result})
    
    result
  end
end
