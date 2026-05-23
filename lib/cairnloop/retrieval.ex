defmodule Cairnloop.Retrieval do
  import Ecto.Query

  alias Cairnloop.Conversation
  alias Cairnloop.KnowledgeBase.Revision
  alias Cairnloop.Retrieval.{Providers, Ranker, Result, Telemetry}

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def search(query, opts \\ []) do
    started_at = System.monotonic_time()

    case validate_scope(opts) do
      :ok ->
        try do
          knowledge_base_results = search_knowledge_base(query, opts)
          resolved_case_results = search_resolved_cases(query, opts)
          results = ranker(opts).merge(knowledge_base_results, resolved_case_results, opts)

          emit_search_telemetry(results, opts, started_at)
          results
        rescue
          error ->
            emit_search_error_telemetry(error, opts, started_at)
            reraise error, __STACKTRACE__
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def ground_for_draft(query_or_context, opts \\ []) do
    started_at = System.monotonic_time()

    try do
      context = normalize_draft_context(query_or_context)
      query = Map.fetch!(context, :query)
      clarification_attempts = Map.get(context, :clarification_attempts, 0)
      search_opts = Keyword.put_new(opts, :surface, :draft_generation)
      results = search(query, search_opts)
      grouped_results = Enum.group_by(results, & &1.source_type)
      canonical = Map.get(grouped_results, :knowledge_base, [])
      assistive = Map.get(grouped_results, :resolved_case, [])
      ranking_summary = Ranker.summarize(results)

      diagnostic =
        diagnostic_for_results(ranking_summary, canonical, assistive, clarification_attempts)

      grounding_assessment = assess_grounding(diagnostic)

      bundle = %{
        query: query,
        canonical_results: canonical,
        assistive_results: assistive,
        evidence: Enum.map(results, &serialize_result/1),
        clarification_attempts: clarification_attempts,
        ranking_summary: ranking_summary,
        diagnostic: diagnostic,
        grounding_assessment: grounding_assessment
      }

      emit_grounding_telemetry(bundle, search_opts, started_at)
      bundle
    rescue
      error ->
        context = normalize_draft_context(query_or_context)
        clarification_attempts = Map.get(context, :clarification_attempts, 0)
        diagnostic = diagnostic_for_error(error, clarification_attempts)

        bundle = %{
          query: extract_query(query_or_context),
          canonical_results: [],
          assistive_results: [],
          evidence: [],
          clarification_attempts: clarification_attempts,
          ranking_summary: Ranker.summarize([]),
          diagnostic: diagnostic,
          grounding_assessment: assess_grounding(diagnostic)
        }

        emit_grounding_telemetry(
          bundle,
          Keyword.put_new(opts, :surface, :draft_generation),
          started_at
        )

        bundle
    end
  end

  def search_knowledge_base(query, opts \\ []) do
    providers(opts).knowledge_base.search(query, opts)
  end

  def search_resolved_cases(query, opts \\ []) do
    providers(opts).resolved_cases.search(query, opts)
  end

  def reindex_revision(revision_id, opts \\ []) do
    enqueue_job(
      Cairnloop.KnowledgeBase.Workers.ChunkRevision.new(%{"revision_id" => revision_id}),
      opts
    )
  end

  def reindex_conversation(conversation_id, opts \\ []) do
    enqueue_job(
      Cairnloop.Retrieval.Workers.IndexResolvedConversation.new(%{
        "conversation_id" => conversation_id
      }),
      opts
    )
  end

  def rebuild_corpus(opts \\ []) do
    corpus = Keyword.fetch!(opts, :corpus)

    if corpus == :all do
      with {:ok, kb} <- rebuild_corpus(Keyword.put(opts, :corpus, :knowledge_base)),
           {:ok, resolved} <- rebuild_corpus(Keyword.put(opts, :corpus, :resolved_cases)) do
        {:ok, kb ++ resolved}
      end
    else
      jobs =
        case corpus do
          :knowledge_base ->
            ids = scoped_ids(opts, :revision_ids, &published_revision_ids/0)

            Enum.map(
              ids,
              &Cairnloop.KnowledgeBase.Workers.ChunkRevision.new(%{"revision_id" => &1})
            )

          :resolved_cases ->
            ids = scoped_ids(opts, :conversation_ids, &resolved_conversation_ids/0)

            Enum.map(
              ids,
              &Cairnloop.Retrieval.Workers.IndexResolvedConversation.new(%{
                "conversation_id" => &1
              })
            )
        end

      Enum.reduce_while(jobs, {:ok, []}, fn job, {:ok, acc} ->
        case enqueue_job(job, opts) do
          {:ok, enqueued_job} -> {:cont, {:ok, [enqueued_job | acc]}}
          error -> {:halt, error}
        end
      end)
      |> reverse_ok_jobs()
    end
  end

  def replay_failed(opts \\ []) do
    queue = Keyword.get(opts, :queue, "default")
    worker = Keyword.get(opts, :worker)

    failed_jobs_query =
      from(job in Oban.Job,
        where: job.state in ["retryable", "discarded"],
        where: job.queue == ^queue
      )

    failed_jobs_query =
      if worker do
        where(failed_jobs_query, [job], job.worker == ^worker)
      else
        failed_jobs_query
      end

    failed_jobs_query
    |> repo().all()
    |> Enum.reduce_while({:ok, []}, fn %Oban.Job{} = job, {:ok, acc} ->
      replay_job = %{job | id: nil, state: "available", attempt: 0}

      case enqueue_job(replay_job, opts) do
        {:ok, replayed_job} -> {:cont, {:ok, [replayed_job | acc]}}
        error -> {:halt, error}
      end
    end)
    |> reverse_ok_jobs()
  end

  defp reverse_ok_jobs({:ok, jobs}), do: {:ok, Enum.reverse(jobs)}
  defp reverse_ok_jobs(error), do: error

  defp providers(opts) do
    provider_overrides = Keyword.get(opts, :providers, %{})

    %{
      knowledge_base: Map.get(provider_overrides, :knowledge_base, Providers.KnowledgeBase),
      resolved_cases: Map.get(provider_overrides, :resolved_cases, Providers.ResolvedCases)
    }
  end

  defp ranker(opts), do: Keyword.get(opts, :ranker, Cairnloop.Retrieval.Ranker)

  defp enqueue_job(job, opts) do
    enqueue_fn = Keyword.get(opts, :enqueue_fn, &Oban.insert/1)
    enqueue_fn.(job)
  end

  defp scoped_ids(opts, key, fallback_fun) do
    case Keyword.get(opts, key) do
      ids when is_list(ids) and ids != [] -> ids
      nil -> fallback_fun.()
      [] -> raise ArgumentError, "expected #{key} to be non-empty when provided"
    end
  end

  defp published_revision_ids do
    Revision
    |> where([revision], revision.state == :published)
    |> select([revision], revision.id)
    |> repo().all()
  end

  defp resolved_conversation_ids do
    Conversation
    |> where([conversation], conversation.status == :resolved)
    |> select([conversation], conversation.id)
    |> repo().all()
  end

  defp normalize_draft_context(query) when is_binary(query) do
    %{query: query, clarification_attempts: 0}
  end

  defp normalize_draft_context(%{} = context) do
    %{
      query: extract_query(context),
      clarification_attempts:
        Map.get(context, :clarification_attempts) || Map.get(context, "clarification_attempts", 0)
    }
  end

  defp extract_query(%{query: query}) when is_binary(query) and query != "", do: query
  defp extract_query(%{"query" => query}) when is_binary(query) and query != "", do: query
  defp extract_query(%{conversation_id: id}), do: "Conversation #{id}"
  defp extract_query(%{"conversation_id" => id}), do: "Conversation #{id}"
  defp extract_query(query) when is_binary(query), do: query
  defp extract_query(_), do: "Conversation"

  defp validate_scope(opts) do
    case {Keyword.get(opts, :surface), Keyword.get(opts, :host_surface),
          Keyword.get(opts, :host_user_id)} do
      {:search_modal, host_surface, host_user_id}
      when host_surface in ["conversation", "inbox", "settings"] and host_user_id in [nil, ""] ->
        {:error, :scope_unavailable}

      _ ->
        :ok
    end
  end

  defp assess_grounding(diagnostic) do
    {status, clarification_allowed?, can_generate_reply?} =
      case diagnostic.class do
        :grounded -> {:strong, false, true}
        :weak_grounding -> {:clarification, true, false}
        :policy_limit -> {:escalation, false, false}
        :empty_recall -> {:escalation, false, false}
        :retrieval_error -> {:escalation, false, false}
      end

    if diagnostic.reason == :assistive_only_results do
      %{
        status: :escalation,
        reason: diagnostic.reason,
        diagnostic_class: diagnostic.class,
        diagnostic_reason: diagnostic.reason,
        clarification_allowed?: false,
        can_generate_reply?: false
      }
    else
      %{
        status: status,
        reason: diagnostic.reason,
        diagnostic_class: diagnostic.class,
        diagnostic_reason: diagnostic.reason,
        clarification_allowed?: clarification_allowed?,
        can_generate_reply?: can_generate_reply?
      }
    end
  end

  defp serialize_result(%Result{} = result) do
    %{
      id: result.id,
      title: result.title,
      content: result.content,
      source_type: result.source_type,
      trust_level: result.trust_level,
      citation_target: result.citation_target,
      match_reasons: result.match_reasons,
      can_ground_reply?: result.can_ground_reply?,
      score: result.score,
      metadata: result.metadata,
      updated_at: result.updated_at,
      resolved_at: result.resolved_at
    }
  end

  defp diagnostic_for_results(ranking_summary, canonical, assistive, clarification_attempts) do
    strong_canonical? = Enum.any?(canonical, &(&1.can_ground_reply? != false))
    has_canonical? = canonical != []

    {diagnostic_class, reason} =
      cond do
        strong_canonical? ->
          {:grounded, :canonical_results}

        has_canonical? and clarification_attempts < 1 ->
          {:weak_grounding, :canonical_insufficient_detail}

        has_canonical? and clarification_attempts >= 1 ->
          {:policy_limit, :clarification_limit_reached}

        assistive != [] ->
          {:weak_grounding, :assistive_only_results}

        true ->
          {:empty_recall, :no_canonical_results}
      end

    %{
      class: diagnostic_class,
      reason: reason,
      canonical_hit_count: ranking_summary.canonical_hit_count,
      assistive_hit_count: ranking_summary.assistive_hit_count
    }
  end

  defp diagnostic_for_error(error, _clarification_attempts) do
    %{
      class: :retrieval_error,
      reason: Telemetry.classify_exception(error),
      canonical_hit_count: 0,
      assistive_hit_count: 0
    }
  end

  defp emit_search_telemetry(results, opts, started_at) do
    Telemetry.emit_search(
      duration_measurements(started_at),
      Telemetry.search_metadata(results, opts)
    )
  end

  defp emit_search_error_telemetry(error, opts, started_at) do
    Telemetry.emit_search(
      duration_measurements(started_at),
      Telemetry.error_metadata(opts, :retrieval_error, Telemetry.classify_exception(error))
    )
  end

  defp emit_grounding_telemetry(bundle, opts, started_at) do
    Telemetry.emit_draft_grounding(
      duration_measurements(started_at),
      Telemetry.grounding_metadata(bundle, opts)
    )
  end

  defp duration_measurements(started_at) do
    %{
      duration_ms:
        System.convert_time_unit(System.monotonic_time() - started_at, :native, :millisecond),
      count: 1
    }
  end
end
