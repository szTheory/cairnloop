defmodule Cairnloop.KnowledgeBase.Workers.ChunkRevision do
  use Oban.Worker, queue: :default, unique: [period: 60]

  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeBase.{Revision, Chunk, MarkdownParser}
  alias Cairnloop.Embedder.ExternalApi
  import Ecto.Query

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  defp support_prefix, do: Cairnloop.SchemaPrefix.configured()
  defp repo_opts, do: Cairnloop.SchemaPrefix.repo_opts()

  defp prefixed(queryable),
    do: queryable |> Ecto.Queryable.to_query() |> put_query_prefix(support_prefix())

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"revision_id" => revision_id}}) do
    :telemetry.execute([:openinference, :span, :start], %{}, %{name: "chunk_revision"})
    _ = knowledge_automation().record_review_task_reindex_started(revision_id)

    result =
      case repo().get(Revision, revision_id, repo_opts()) do
        nil ->
          {:error, :revision_not_found}

        %Revision{content: content} ->
          chunk_sections = MarkdownParser.parse_sections(content || "")
          chunk_texts = Enum.map(chunk_sections, & &1.content)

          case ExternalApi.generate_embeddings(chunk_texts) do
            {:ok, embeddings} ->
              now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
              chunk_query = prefixed(Chunk)

              chunk_records =
                Enum.zip(chunk_sections, embeddings)
                |> Enum.map(fn {section, vector} ->
                  %{
                    revision_id: revision_id,
                    chunk_index: section.chunk_index,
                    heading: section.heading,
                    content: section.content,
                    embedding: Pgvector.new(vector),
                    inserted_at: now,
                    updated_at: now
                  }
                end)

              Ecto.Multi.new()
              |> Ecto.Multi.delete_all(
                :delete_old_chunks,
                chunk_query |> where([c], c.revision_id == ^revision_id),
                repo_opts()
              )
              |> Ecto.Multi.insert_all(:insert_chunks, Chunk, chunk_records, repo_opts())
              |> repo().transaction()

              :ok

            {:error, reason} ->
              {:error, reason}
          end
      end

    :telemetry.execute([:openinference, :span, :stop], %{}, %{
      name: "chunk_revision",
      status: result
    })

    _ = knowledge_automation().record_review_task_reindex_outcome(revision_id, result)

    result
  end

  defp knowledge_automation do
    Application.get_env(:cairnloop, :knowledge_automation, KnowledgeAutomation)
  end
end
