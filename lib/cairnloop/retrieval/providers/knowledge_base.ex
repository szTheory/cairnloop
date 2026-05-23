defmodule Cairnloop.Retrieval.Providers.KnowledgeBase do
  import Ecto.Query

  alias Cairnloop.KnowledgeBase.Article
  alias Cairnloop.KnowledgeBase.Chunk
  alias Cairnloop.KnowledgeBase.Revision
  alias Cairnloop.Retrieval.Result

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    embedding_vector = Keyword.get_lazy(opts, :embedding_vector, fn -> nil end)

    keyword_task = Task.async(fn -> keyword_candidates(query, limit, opts) end)
    semantic_task = Task.async(fn -> semantic_candidates(embedding_vector, limit, opts) end)

    merge_candidates(Task.await(keyword_task), Task.await(semantic_task))
  end

  def keyword_candidates(query, limit, _opts \\ []) do
    Chunk
    |> join(:inner, [chunk], revision in Revision, on: revision.id == chunk.revision_id)
    |> join(:inner, [_chunk, revision], article in Article, on: article.id == revision.article_id)
    |> where([_chunk, revision], revision.state == :published)
    |> where(
      [chunk, _revision, _article],
      fragment("cairnloop_chunks.search_vector @@ websearch_to_tsquery('english', ?)", ^query)
    )
    |> order_by(
      [chunk, _revision, _article],
      desc:
        fragment(
          "ts_rank(cairnloop_chunks.search_vector, websearch_to_tsquery('english', ?))",
          ^query
        )
    )
    |> limit(^limit)
    |> select([chunk, revision, article], %{
      id: chunk.id,
      title: article.title,
      content: chunk.content,
      source_type: :knowledge_base,
      trust_level: :canonical,
      visibility: :host,
      article_id: article.id,
      revision_id: revision.id,
      chunk_index: chunk.chunk_index,
      updated_at: revision.updated_at,
      citation_target: %{
        article_id: article.id,
        revision_id: revision.id,
        chunk_index: chunk.chunk_index
      },
      metadata: %{
        heading: chunk.heading,
        destination: %{
          type: :knowledge_base_article,
          article_id: article.id,
          revision_id: revision.id,
          chunk_index: chunk.chunk_index
        },
        action_label: "Open article"
      }
    })
    |> repo().all()
    |> Enum.with_index(1)
    |> Enum.map(fn {row, rank} -> Map.put(row, :keyword_rank, rank) end)
  end

  def semantic_candidates(embedding_vector, limit, opts \\ [])
  def semantic_candidates(nil, _limit, _opts), do: []

  def semantic_candidates(embedding_vector, limit, _opts) do
    Chunk
    |> join(:inner, [chunk], revision in Revision, on: revision.id == chunk.revision_id)
    |> join(:inner, [_chunk, revision], article in Article, on: article.id == revision.article_id)
    |> where([_chunk, revision], revision.state == :published)
    |> order_by(
      [chunk, _revision, _article],
      fragment("? <-> ?", chunk.embedding, ^Pgvector.new(embedding_vector))
    )
    |> limit(^limit)
    |> select([chunk, revision, article], %{
      id: chunk.id,
      title: article.title,
      content: chunk.content,
      source_type: :knowledge_base,
      trust_level: :canonical,
      visibility: :host,
      article_id: article.id,
      revision_id: revision.id,
      chunk_index: chunk.chunk_index,
      updated_at: revision.updated_at,
      citation_target: %{
        article_id: article.id,
        revision_id: revision.id,
        chunk_index: chunk.chunk_index
      },
      metadata: %{
        heading: chunk.heading,
        destination: %{
          type: :knowledge_base_article,
          article_id: article.id,
          revision_id: revision.id,
          chunk_index: chunk.chunk_index
        },
        action_label: "Open article"
      }
    })
    |> repo().all()
    |> Enum.with_index(1)
    |> Enum.map(fn {row, rank} -> Map.put(row, :semantic_rank, rank) end)
  end

  defp merge_candidates(keyword_rows, semantic_rows) do
    (keyword_rows ++ semantic_rows)
    |> Enum.group_by(& &1.citation_target)
    |> Enum.map(fn {_citation_target, rows} ->
      Enum.reduce(rows, %Result{}, fn row, %Result{} = acc ->
        %Result{
          acc
          | id: row.id || acc.id,
            title: row.title || acc.title,
            content: row.content || acc.content,
            source_type: row.source_type || acc.source_type,
            trust_level: row.trust_level || acc.trust_level,
            visibility: row.visibility || acc.visibility,
            article_id: row[:article_id] || acc.article_id,
            revision_id: row[:revision_id] || acc.revision_id,
            chunk_index: row[:chunk_index] || acc.chunk_index,
            updated_at: row[:updated_at] || acc.updated_at,
            citation_target: row.citation_target || acc.citation_target,
            metadata: Map.merge(acc.metadata || %{}, row[:metadata] || %{}),
            keyword_rank: row[:keyword_rank] || acc.keyword_rank,
            semantic_rank: row[:semantic_rank] || acc.semantic_rank
        }
      end)
    end)
  end
end
