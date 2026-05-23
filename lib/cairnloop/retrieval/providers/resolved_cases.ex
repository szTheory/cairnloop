defmodule Cairnloop.Retrieval.Providers.ResolvedCases do
  import Ecto.Query

  alias Cairnloop.Retrieval.{ResolvedCaseChunk, ResolvedCaseEvidence, Result}

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)
    embedding_vector = Keyword.get_lazy(opts, :embedding_vector, fn -> nil end)
    host_user_id = Keyword.get(opts, :host_user_id)

    if host_user_id in [nil, ""] do
      []
    else
      keyword_task = Task.async(fn -> keyword_candidates(query, limit, opts) end)
      semantic_task = Task.async(fn -> semantic_candidates(embedding_vector, limit, opts) end)

      merge_candidates(Task.await(keyword_task), Task.await(semantic_task))
    end
  end

  def keyword_candidates(query, limit, opts \\ []) do
    host_user_id = Keyword.get(opts, :host_user_id)

    ResolvedCaseChunk
    |> join(:inner, [chunk], evidence in ResolvedCaseEvidence,
      on: evidence.id == chunk.resolved_case_evidence_id
    )
    |> maybe_filter_host_user(host_user_id)
    |> where(
      [chunk, _evidence],
      fragment(
        "cairnloop_resolved_case_chunks.search_vector @@ websearch_to_tsquery('english', ?)",
        ^query
      )
    )
    |> order_by(
      [chunk, _evidence],
      desc:
        fragment(
          "ts_rank(cairnloop_resolved_case_chunks.search_vector, websearch_to_tsquery('english', ?))",
          ^query
        )
    )
    |> limit(^limit)
    |> select([chunk, evidence], %{
      id: chunk.id,
      title: evidence.subject,
      content: chunk.content,
      source_type: :resolved_case,
      trust_level: :assistive,
      visibility: :host,
      conversation_id: evidence.conversation_id,
      chunk_index: chunk.chunk_index,
      resolved_at: evidence.resolved_at,
      issue_summary: evidence.issue_summary,
      resolution_note: evidence.resolution_note,
      actions_taken: evidence.actions_taken,
      outcome: evidence.outcome,
      citation_target: %{
        conversation_id: evidence.conversation_id,
        chunk_index: chunk.chunk_index
      },
      metadata: %{
        destination: %{
          type: :resolved_case,
          conversation_id: evidence.conversation_id,
          chunk_index: chunk.chunk_index
        },
        action_label: "Open resolved case",
        citation_backreferences: evidence.citation_backreferences
      }
    })
    |> repo().all()
    |> Enum.with_index(1)
    |> Enum.map(fn {row, rank} -> Map.put(row, :keyword_rank, rank) end)
  end

  def semantic_candidates(embedding_vector, limit, opts \\ [])
  def semantic_candidates(nil, _limit, _opts), do: []

  def semantic_candidates(embedding_vector, limit, opts) do
    host_user_id = Keyword.get(opts, :host_user_id)

    ResolvedCaseChunk
    |> join(:inner, [chunk], evidence in ResolvedCaseEvidence,
      on: evidence.id == chunk.resolved_case_evidence_id
    )
    |> maybe_filter_host_user(host_user_id)
    |> order_by(
      [chunk, _evidence],
      fragment("? <-> ?", chunk.embedding, ^Pgvector.new(embedding_vector))
    )
    |> limit(^limit)
    |> select([chunk, evidence], %{
      id: chunk.id,
      title: evidence.subject,
      content: chunk.content,
      source_type: :resolved_case,
      trust_level: :assistive,
      visibility: :host,
      conversation_id: evidence.conversation_id,
      chunk_index: chunk.chunk_index,
      resolved_at: evidence.resolved_at,
      issue_summary: evidence.issue_summary,
      resolution_note: evidence.resolution_note,
      actions_taken: evidence.actions_taken,
      outcome: evidence.outcome,
      citation_target: %{
        conversation_id: evidence.conversation_id,
        chunk_index: chunk.chunk_index
      },
      metadata: %{
        destination: %{
          type: :resolved_case,
          conversation_id: evidence.conversation_id,
          chunk_index: chunk.chunk_index
        },
        action_label: "Open resolved case",
        citation_backreferences: evidence.citation_backreferences
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
            conversation_id: row[:conversation_id] || acc.conversation_id,
            chunk_index: row[:chunk_index] || acc.chunk_index,
            resolved_at: row[:resolved_at] || acc.resolved_at,
            issue_summary: row[:issue_summary] || acc.issue_summary,
            resolution_note: row[:resolution_note] || acc.resolution_note,
            actions_taken: row[:actions_taken] || acc.actions_taken,
            outcome: row[:outcome] || acc.outcome,
            citation_target: row.citation_target || acc.citation_target,
            metadata: Map.merge(acc.metadata || %{}, row[:metadata] || %{}),
            keyword_rank: row[:keyword_rank] || acc.keyword_rank,
            semantic_rank: row[:semantic_rank] || acc.semantic_rank
        }
      end)
    end)
  end

  defp maybe_filter_host_user(query, nil), do: query

  defp maybe_filter_host_user(query, host_user_id) do
    where(query, [_chunk, evidence], evidence.host_user_id == ^to_string(host_user_id))
  end
end
