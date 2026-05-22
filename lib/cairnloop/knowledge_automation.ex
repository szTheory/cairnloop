defmodule Cairnloop.KnowledgeAutomation do
  import Ecto.Query

  alias Cairnloop.KnowledgeAutomation.{
    ArticleSuggestion,
    ArticleSuggestionEvidence,
    CandidateBuilder,
    GapCandidate,
    Telemetry,
    ReviewTask,
    ReviewTaskEvent,
    StaleArticleSignal,
    Workers.BackfillGapCandidates,
    Workers.GenerateArticleSuggestion,
    Workers.RefreshGapCandidates
  }

  alias Cairnloop.KnowledgeBase
  alias Cairnloop.Retrieval
  alias Cairnloop.Retrieval.{GapEvent, ResolvedCaseEvidence}

  @pending_markdown "<pending article suggestion generation>"
  @failed_markdown %{
    article: "# Suggestion blocked\n\nCanonical citation-backed grounding was insufficient.",
    revision:
      "# Revision suggestion blocked\n\nCanonical citation-backed grounding was insufficient."
  }
  @quick_fix_shell_reasons [:missing_canonical_grounding]

  @quick_fix_blocked_reasons [
    :canonical_snapshot_unavailable,
    :citation_anchors_unavailable,
    :policy_guard_blocked
  ]

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def list_gap_candidates(opts \\ []) do
    GapCandidate
    |> apply_scope(opts)
    |> maybe_filter_status(opts)
    |> order_by([candidate],
      desc: candidate.score,
      desc: candidate.last_seen_at,
      desc: candidate.id
    )
    |> repo().all()
  end

  def get_gap_candidate!(id, opts \\ []) do
    candidate =
      GapCandidate
      |> apply_scope(opts)
      |> where([candidate], candidate.id == ^id)
      |> preload(:memberships)
      |> repo().one!()
      |> enforce_scope!(opts, GapCandidate)

    hydrate_memberships(candidate)
  end

  def list_article_suggestions(opts \\ []) do
    ArticleSuggestion
    |> apply_scope(opts)
    |> maybe_filter_article_suggestion_status(opts)
    |> order_by([suggestion], desc: suggestion.inserted_at, desc: suggestion.id)
    |> repo().all()
  end

  def get_article_suggestion!(id, opts \\ []) do
    ArticleSuggestion
    |> apply_scope(opts)
    |> where([suggestion], suggestion.id == ^id)
    |> repo().one!()
    |> enforce_scope!(opts, ArticleSuggestion)
  end

  def list_review_tasks(opts \\ []) do
    ReviewTask
    |> apply_scope(opts)
    |> maybe_filter_review_task_status(opts)
    |> order_by(
      [task],
      asc:
        fragment(
          """
          CASE ?
            WHEN 'pending_review' THEN 0
            WHEN 'review_needed' THEN 1
            WHEN 'approved_ready_to_publish' THEN 2
            WHEN 'deferred' THEN 3
            WHEN 'rejected' THEN 4
            WHEN 'published' THEN 5
            ELSE 6
          END
          """,
          task.status
        ),
      desc: task.inserted_at,
      desc: task.id
    )
    |> repo().all()
  end

  def get_review_task!(id, opts \\ []) do
    ReviewTask
    |> apply_scope(opts)
    |> where([task], task.id == ^id)
    |> repo().one!()
    |> enforce_scope!(opts, ReviewTask)
    |> repo().preload([:article_suggestion, :events])
  end

  def ensure_review_task_for_suggestion(id, opts \\ []) do
    actor_id = Keyword.get(opts, :actor_id)
    suggestion = get_article_suggestion!(id, opts)

    ensure_review_task_for_loaded_suggestion(suggestion, actor_id, opts)
  end

  defp ensure_review_task_for_loaded_suggestion(suggestion, actor_id, opts) do
    cond do
      not reviewable_for_review_task?(suggestion) ->
        {:error, :suggestion_not_reviewable}

      existing = find_active_review_task(suggestion, opts) ->
        {:ok, existing}

      true ->
        attrs =
          suggestion
          |> initial_review_task_attrs(actor_id, opts)
          |> Map.merge(%{
            article_suggestion_id: suggestion.id,
            tenant_scope: suggestion.tenant_scope,
            host_user_id: suggestion.host_user_id,
            status: initial_review_task_status(suggestion)
          })

        with {:ok, task} <-
               %ReviewTask{}
               |> ReviewTask.changeset(attrs)
               |> repo().insert(),
             {:ok, _event} <-
               %ReviewTaskEvent{}
               |> ReviewTaskEvent.changeset(%{
                 review_task_id: task.id,
                 event_type: :task_created,
                 to_status: task.status,
                 actor_id: actor_id || suggestion.host_user_id || "system",
                 metadata: %{article_suggestion_id: suggestion.id}
               })
               |> repo().insert() do
          {:ok, task}
        end
    end
  end

  def approve_review_task(id, opts \\ []) do
    now = now_fn(opts).()
    actor_id = Keyword.get(opts, :actor_id) || "system"

    with {:ok, task, suggestion} <- load_review_task_with_suggestion(id, opts) do
      with {:ok, article_id} <- approval_article_id(suggestion, task, opts),
           {:ok, article} <- load_article(article_id, opts),
           :ok <- ensure_no_unrelated_draft(task, article_id, opts),
           {:ok, staged_revision} <-
             save_draft(article, %{content: suggestion.proposed_markdown}, opts) do
        update_task_with_event(
          task,
          ReviewTask.decision_changeset(
            task,
            :approved_ready_to_publish,
            :approved,
            :ready_to_publish,
            actor_id,
            now,
            %{
              staged_article_id: article.id,
              staged_revision_id: staged_revision.id,
              notes: Keyword.get(opts, :note),
              needs_re_review: false
            }
          ),
          %{
            event_type: :decision_recorded,
            from_status: task.status,
            to_status: :approved_ready_to_publish,
            decision: :approved,
            reason: :ready_to_publish,
            actor_id: actor_id,
            notes: Keyword.get(opts, :note),
            metadata: %{staged_article_id: article.id, staged_revision_id: staged_revision.id}
          }
        )
      else
        {:error, {:draft_conflict, conflict_revision}} ->
          note =
            "Approval blocked because draft revision #{conflict_revision.id} is already active for article #{conflict_revision.article_id}."

          {:error, updated_task} =
            update_task_with_event(
              task,
              ReviewTask.decision_changeset(
                task,
                :review_needed,
                :review_needed,
                :draft_conflict,
                actor_id,
                now,
                %{notes: note, needs_re_review: true}
              ),
              %{
                event_type: :decision_recorded,
                from_status: task.status,
                to_status: :review_needed,
                decision: :review_needed,
                reason: :draft_conflict,
                actor_id: actor_id,
                notes: note,
                metadata: %{
                  conflicting_revision_id: conflict_revision.id,
                  article_id: conflict_revision.article_id
                }
              },
              :error
            )

          {:error, {:draft_conflict, updated_task}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def reject_review_task(id, opts \\ []) do
    with reason when is_atom(reason) <- Keyword.get(opts, :reason),
         true <- ReviewTask.valid_reason_for_decision?(:rejected, reason) do
      record_structured_decision(id, :rejected, :rejected, reason, opts)
    else
      _ -> {:error, :invalid_reason}
    end
  end

  def defer_review_task(id, opts \\ []) do
    with reason when is_atom(reason) <- Keyword.get(opts, :reason),
         true <- ReviewTask.valid_reason_for_decision?(:deferred, reason) do
      record_structured_decision(id, :deferred, :deferred, reason, opts)
    else
      _ -> {:error, :invalid_reason}
    end
  end

  def publish_review_task(id, opts \\ []) do
    now = now_fn(opts).()
    actor_id = Keyword.get(opts, :actor_id) || "system"

    with {:ok, task, suggestion} <- load_review_task_with_suggestion(id, opts) do
      with :ok <- ensure_publishable_status(task),
           {:ok, staged_revision} <- load_staged_revision(task, opts),
           :ok <- ensure_publish_freshness(task, suggestion, opts),
           {:ok, published_revision} <- publish_revision(staged_revision, opts) do
        update_task_with_event(
          task,
          ReviewTask.decision_changeset(
            task,
            :published,
            :approved,
            :ready_to_publish,
            actor_id,
            now,
            %{
              published_revision_id: published_revision.id,
              published_at: now,
              publish_status: :published,
              reindex_status: :queued,
              needs_re_review: false
            }
          ),
          %{
            event_type: :publish_recorded,
            from_status: task.status,
            to_status: :published,
            decision: :approved,
            reason: :ready_to_publish,
            actor_id: actor_id,
            metadata: %{
              publish_status: :published,
              staged_revision_id: staged_revision.id,
              published_revision_id: published_revision.id
            }
          }
        )
      else
        {:error, {:stale_base, latest_revision}} ->
          note =
            "Publish blocked because the latest active revision is #{latest_revision.id}, not the reviewed base revision."

          {:error, updated_task} =
            update_task_with_event(
              task,
              ReviewTask.decision_changeset(
                task,
                :review_needed,
                :review_needed,
                :freshness_invalidated,
                actor_id,
                now,
                %{notes: note, publish_status: :not_started, needs_re_review: true}
              ),
              %{
                event_type: :publish_recorded,
                from_status: task.status,
                to_status: :review_needed,
                decision: :review_needed,
                reason: :freshness_invalidated,
                actor_id: actor_id,
                notes: note,
                metadata: %{latest_active_revision_id: latest_revision.id, publish_status: :not_started}
              },
              :error
            )

          {:error, {:stale_base, updated_task}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def mark_review_task_material_edit(id, opts \\ []) do
    now = now_fn(opts).()
    actor_id = Keyword.get(opts, :actor_id) || "system"
    content = Keyword.get(opts, :content)
    saved_revision_id = Keyword.get(opts, :saved_revision_id)

    with {:ok, task, suggestion} <- load_review_task_with_suggestion(id, opts),
         true <- is_binary(content) do
      baseline_content = material_edit_baseline(task, suggestion, opts)

      cond do
        task.status != :approved_ready_to_publish ->
          {:ok, task}

        not material_content_changed?(baseline_content, content) ->
          {:ok, task}

        true ->
          note = "Material edits were made after approval and require review again before publish."

          update_task_with_event(
            task,
            ReviewTask.decision_changeset(
              task,
              :review_needed,
              :review_needed,
              :needs_manual_edit,
              actor_id,
              now,
              %{
                staged_revision_id: saved_revision_id || task.staged_revision_id,
                publish_status: :not_started,
                reindex_status: :not_started,
                needs_re_review: true,
                notes: note
              }
            ),
            %{
              event_type: :material_edit_after_approval,
              from_status: task.status,
              to_status: :review_needed,
              decision: :review_needed,
              reason: :needs_manual_edit,
              actor_id: actor_id,
              notes: note,
              metadata: %{
                saved_revision_id: saved_revision_id || task.staged_revision_id,
                previous_staged_revision_id: task.staged_revision_id
              }
            }
          )
      end
    else
      false -> {:error, :missing_content}
      {:error, reason} -> {:error, reason}
    end
  end

  def record_review_task_reindex_outcome(published_revision_id, result, opts \\ []) do
    case find_review_task_by_published_revision_id(published_revision_id, opts) do
      nil ->
        :ok

      task ->
        persist_reindex_outcome(task, published_revision_id, result, opts)
    end
  end

  def suggest_article(attrs, opts \\ []) do
    attrs = Map.new(attrs)

    case prepare_request(:article, attrs, opts) do
      {:ok, prepared} -> insert_and_enqueue(prepared, opts)
      {:failed, prepared} -> persist_failed(prepared, opts)
    end
  end

  def create_or_reuse_conversation_quick_fix(attrs, opts \\ []) do
    attrs = Map.new(attrs)
    prepared = prepare_conversation_quick_fix(attrs)

    scope_opts =
      [
        tenant_scope: prepared.tenant_scope,
        host_user_id: prepared.host_user_id
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    case find_article_suggestion_by_stable_key(prepared.stable_key, scope_opts) do
      nil ->
        prepared
        |> Map.from_struct()
        |> insert_quick_fix_suggestion(opts)
        |> attach_review_task_to_quick_fix(opts)

      suggestion ->
        emit_suggestion_outcome(:reused, suggestion, :unspecified, :conversation_thread)

        {:ok,
         %{
           suggestion: suggestion,
           reused?: true,
           quick_fix: quick_fix_package_for(suggestion.grounding_metadata, prepared.quick_fix_package)
         }}
        |> attach_review_task_to_quick_fix(opts)
    end
  end

  def get_conversation_quick_fix(conversation_id, opts \\ []) do
    case find_latest_conversation_quick_fix(conversation_id, opts) do
      nil ->
        {:error, :not_found}

      suggestion ->
        {:ok,
         %{
           suggestion: suggestion,
           review_task: find_active_review_task(suggestion, opts),
           quick_fix: quick_fix_package_for(suggestion.grounding_metadata, %{})
         }}
    end
  end

  def suggest_revision(attrs, opts \\ []) do
    attrs = Map.new(attrs)

    latest_revision_fn =
      Keyword.get(opts, :latest_revision_fn, &KnowledgeBase.get_latest_active_revision/1)

    article_id =
      Map.get(attrs, :article_id) || Map.get(attrs, "article_id") ||
        Map.get(attrs, :entrypoint_id) || Map.get(attrs, "entrypoint_id")

    case latest_revision_fn.(article_id) do
      nil ->
        {:error, :missing_published_revision}

      revision ->
        stale_signal =
          stale_article_signal_module(opts).build_revision_gate(
            revision.article_id,
            revision.id,
            revision_gate_opts(attrs, opts)
          )

        if stale_signal.ready? do
          attrs =
            attrs
            |> Map.put(:suggestion_type, :revision)
            |> Map.put(:entrypoint_type, :article_revision)
            |> Map.put(:entrypoint_id, revision.article_id)
            |> Map.put(:article_id, revision.article_id)
            |> Map.put(:base_revision_id, revision.id)

          case prepare_request(:revision, attrs, Keyword.put(opts, :stale_signal, stale_signal)) do
            {:ok, prepared} -> insert_and_enqueue(prepared, opts)
            {:failed, prepared} -> persist_failed(prepared, opts)
          end
        else
          {:error, {:stale_gate_blocked, stale_signal}}
        end
    end
  end

  def dismiss_article_suggestion(id, opts \\ []) do
    now_fn = Keyword.get(opts, :now_fn, &DateTime.utc_now/0)

    id
    |> get_article_suggestion!(opts)
    |> ArticleSuggestion.dismiss_changeset(now_fn.())
    |> repo().update()
  end

  def regenerate_article_suggestion(id, opts \\ []) do
    suggestion = get_article_suggestion!(id, opts)

    with {:ok, regenerated} <-
           suggestion
           |> ArticleSuggestion.regenerate_changeset()
           |> repo().update(),
         {:ok, _job} <- enqueue_generation_job(regenerated, opts) do
      {:ok, regenerated}
    end
  end

  def create_or_reuse_authoring_article_for_suggestion(id, opts \\ []) do
    suggestion = get_article_suggestion!(id, opts)

    existing_authoring_article_id =
      suggestion.grounding_metadata
      |> map_value(:authoring_article_id)

    cond do
      suggestion.suggestion_type == :revision and suggestion.article_id ->
        {:ok, suggestion.article_id}

      existing_authoring_article_id ->
        {:ok, existing_authoring_article_id}

      true ->
        with {:ok, article} <-
               knowledge_base_module(opts).create_article(%{
                 title: suggestion.title || "Suggested Knowledge Base article",
                 status: :draft
               }),
             {:ok, updated} <-
               suggestion
               |> ArticleSuggestion.changeset(%{
                 grounding_metadata:
                   Map.put(
                     suggestion.grounding_metadata || %{},
                     "authoring_article_id",
                     article.id
                   )
               })
               |> repo().update() do
          {:ok, map_value(updated.grounding_metadata, :authoring_article_id)}
        end
    end
  end

  def prepare_generation_bundle_from_suggestion(%ArticleSuggestion{} = suggestion) do
    evidence_snapshot =
      suggestion.evidence_snapshot
      |> List.wrap()
      |> Enum.map(&normalize_existing_evidence/1)

    canonical_evidence = Enum.filter(evidence_snapshot, &canonical_anchor?/1)
    assistive_evidence = Enum.reject(evidence_snapshot, &canonical_anchor?/1)
    grounding_status = normalize_grounding_status(suggestion.grounding_metadata)

    failure_reason =
      cond do
        grounding_status != :strong -> :weak_grounding
        canonical_evidence == [] -> :missing_canonical_citations
        true -> nil
      end

    %{
      suggestion_type: suggestion.suggestion_type,
      entrypoint_type: suggestion.entrypoint_type,
      entrypoint_id: suggestion.entrypoint_id,
      article_id: suggestion.article_id,
      base_revision_id: suggestion.base_revision_id,
      query: map_value(suggestion.grounding_metadata, :query),
      evidence_snapshot: evidence_snapshot,
      canonical_evidence: canonical_evidence,
      assistive_evidence: assistive_evidence,
      evidence_digest: suggestion.evidence_digest || evidence_digest_for(evidence_snapshot),
      grounding_metadata: suggestion.grounding_metadata || %{},
      stale_signal: map_value(suggestion.grounding_metadata, :stale_signal),
      valid?: is_nil(failure_reason),
      failure_reason: failure_reason
    }
  end

  def mark_article_suggestion_ready(%ArticleSuggestion{} = suggestion, proposal, opts \\ []) do
    now_fn = Keyword.get(opts, :now_fn, &DateTime.utc_now/0)
    prepared = prepare_generation_bundle_from_suggestion(suggestion)

    attrs = %{
      status: :ready,
      title: Map.get(proposal, :title),
      change_summary: Map.get(proposal, :change_summary),
      operator_summary: Map.fetch!(proposal, :operator_summary),
      proposed_markdown: Map.fetch!(proposal, :proposed_markdown),
      generated_at: now_fn.(),
      grounding_metadata:
        ready_grounding_metadata(
          suggestion.grounding_metadata || %{},
          prepared,
          Map.get(proposal, :evidence_metadata, %{})
        )
    }

    case suggestion
         |> ArticleSuggestion.changeset(attrs)
         |> repo().update() do
      {:ok, updated} = result ->
        emit_suggestion_outcome(:ready, updated)
        result

      other ->
        other
    end
  end

  def mark_article_suggestion_failed(%ArticleSuggestion{} = suggestion, reason, opts \\ []) do
    now_fn = Keyword.get(opts, :now_fn, &DateTime.utc_now/0)
    prepared = prepare_generation_bundle_from_suggestion(suggestion)
    failure_reason = normalize_failure_reason(reason)

    attrs = %{
      status: :failed,
      operator_summary: failure_operator_summary(suggestion.suggestion_type, failure_reason),
      proposed_markdown: fallback_markdown(suggestion.suggestion_type),
      generated_at: now_fn.(),
      grounding_metadata:
        failed_grounding_metadata(suggestion.grounding_metadata || %{}, prepared, failure_reason)
    }

    case suggestion
         |> ArticleSuggestion.changeset(attrs)
         |> repo().update() do
      {:ok, updated} = result ->
        emit_suggestion_outcome(:failed, updated, failure_reason)
        result

      other ->
        other
    end
  end

  def refresh_gap_candidates(opts \\ []) do
    CandidateBuilder.refresh(opts)
  end

  def schedule_gap_candidate_refresh(args \\ %{}, opts \\ []) do
    enqueue_fn = Keyword.get(opts, :enqueue_fn, &Oban.insert/1)

    enqueue_fn.(
      RefreshGapCandidates.new_job(Map.new(args), schedule_in: Keyword.get(opts, :schedule_in, 5))
    )
  end

  def rebuild_gap_candidates(opts \\ []) do
    if Keyword.get(opts, :sync, true) do
      CandidateBuilder.refresh(opts)
    else
      enqueue_fn = Keyword.get(opts, :enqueue_fn, &Oban.insert/1)
      enqueue_fn.(BackfillGapCandidates.new_job(Map.new(Enum.into(opts, %{}))))
    end
  end

  defp prepare_request(type, attrs, opts) do
    bundle = prepare_evidence_bundle(type, attrs, opts)
    stable_key = derive_stable_key(bundle)

    prepared =
      attrs
      |> Map.put(:stable_key, stable_key)
      |> Map.put(:suggestion_type, type)
      |> Map.put(:status, if(bundle.valid?, do: :pending_generation, else: :failed))
      |> Map.put(:entrypoint_type, bundle.entrypoint_type)
      |> Map.put(:entrypoint_id, bundle.entrypoint_id)
      |> Map.put(:article_id, bundle.article_id)
      |> Map.put(:base_revision_id, bundle.base_revision_id)
      |> Map.put(:title, Map.get(attrs, :title) || Map.get(attrs, "title"))
      |> Map.put(:change_summary, change_summary_for(type, attrs, bundle))
      |> Map.put(:operator_summary, operator_summary_for(type, bundle))
      |> Map.put(:proposed_markdown, proposed_markdown_for(type, bundle))
      |> Map.put(:evidence_snapshot, serialize_evidence_snapshot(bundle.evidence_snapshot))
      |> Map.put(:grounding_metadata, grounding_metadata_for(bundle))
      |> Map.put(:evidence_digest, bundle.evidence_digest)

    if bundle.valid?, do: {:ok, prepared}, else: {:failed, prepared}
  end

  defp prepare_conversation_quick_fix(attrs) do
    conversation_id =
      anchor_id(attrs, :conversation_id) || anchor_id(attrs, :entrypoint_id)

    canonical_evidence =
      attrs
      |> quick_fix_canonical_evidence()
      |> Enum.map(&normalize_existing_evidence/1)
      |> Enum.reject(&is_nil/1)

    evidence_digest = quick_fix_evidence_digest(attrs, canonical_evidence)
    citation_ready? = quick_fix_citation_ready?(attrs, canonical_evidence)
    quick_fix_package = quick_fix_package_for(attrs, evidence_digest, length(canonical_evidence), citation_ready?)
    {quick_fix_outcome, quick_fix_reason} =
      quick_fix_outcome(attrs, canonical_evidence, citation_ready?)

    bundle = %{
      suggestion_type: :article,
      entrypoint_type: :conversation_quick_fix,
      entrypoint_id: conversation_id,
      article_id: nil,
      base_revision_id: nil,
      query: quick_fix_query(attrs),
      evidence_snapshot: canonical_evidence,
      canonical_evidence: canonical_evidence,
      assistive_evidence: [],
      evidence_digest: evidence_digest,
      grounding_status: quick_fix_grounding_status(quick_fix_outcome),
      stale_signal: nil,
      valid?: quick_fix_outcome == :ready,
      failure_reason: quick_fix_reason,
      quick_fix_outcome: quick_fix_outcome,
      quick_fix_reason: quick_fix_reason
    }

    prepared =
      %{
        stable_key: derive_stable_key(bundle),
        suggestion_type: :article,
        status: quick_fix_suggestion_status(quick_fix_outcome),
        tenant_scope:
          anchor_id(attrs, :tenant_scope) || :host_user_scoped,
        host_user_id: anchor_id(attrs, :host_user_id),
        entrypoint_type: :conversation_quick_fix,
        entrypoint_id: conversation_id,
        article_id: nil,
        base_revision_id: nil,
        title: anchor_id(attrs, :title) || map_value(map_value(quick_fix_package, :thread_context), :subject),
        change_summary: anchor_id(attrs, :change_summary),
        operator_summary: quick_fix_operator_summary(bundle),
        proposed_markdown: quick_fix_markdown(bundle),
        evidence_snapshot: serialize_evidence_snapshot(canonical_evidence),
        grounding_metadata:
          grounding_metadata_for(bundle)
          |> Map.put("quick_fix_package", quick_fix_package),
        evidence_digest: evidence_digest
      }

    struct!(ArticleSuggestion, prepared)
    |> Map.put(:quick_fix_package, quick_fix_package)
  end

  defp prepare_evidence_bundle(type, attrs, opts) do
    grounding_bundle = grounding_bundle_for(attrs, opts)
    evidence_snapshot = build_evidence_snapshot(grounding_bundle)
    canonical_evidence = Enum.filter(evidence_snapshot, &canonical_anchor?/1)
    assistive_evidence = Enum.reject(evidence_snapshot, &canonical_anchor?/1)
    evidence_digest = evidence_digest_for(evidence_snapshot)
    grounding_status = normalize_grounding_status(grounding_bundle)
    stale_signal = Keyword.get(opts, :stale_signal)

    failure_reason =
      cond do
        grounding_status != :strong -> :weak_grounding
        canonical_evidence == [] -> :missing_canonical_citations
        true -> nil
      end

    %{
      suggestion_type: type,
      entrypoint_type: entrypoint_type_for(type),
      entrypoint_id: entrypoint_id_for(type, attrs),
      article_id: anchor_id(attrs, :article_id),
      base_revision_id: anchor_id(attrs, :base_revision_id),
      query: map_value(grounding_bundle, :query),
      evidence_snapshot: evidence_snapshot,
      canonical_evidence: canonical_evidence,
      assistive_evidence: assistive_evidence,
      evidence_digest: evidence_digest,
      grounding_bundle: grounding_bundle,
      grounding_status: grounding_status,
      stale_signal: stale_signal,
      valid?: is_nil(failure_reason),
      failure_reason: failure_reason
    }
  end

  defp grounding_bundle_for(attrs, opts) do
    case Keyword.get(opts, :grounding_bundle) do
      nil ->
        fallback_attrs_grounding_bundle(attrs, opts)

      bundle ->
        bundle
    end
  end

  defp fallback_attrs_grounding_bundle(attrs, opts) do
    attrs_evidence =
      Map.get(attrs, :evidence_snapshot) || Map.get(attrs, "evidence_snapshot") ||
        Map.get(attrs, :evidence) || Map.get(attrs, "evidence") || []

    attrs_grounding_metadata =
      Map.get(attrs, :grounding_metadata) || Map.get(attrs, "grounding_metadata") || %{}

    if attrs_evidence != [] or map_size(attrs_grounding_metadata) > 0 do
      evidence =
        attrs_evidence
        |> List.wrap()
        |> Enum.map(&normalize_existing_evidence/1)
        |> Enum.reject(&is_nil/1)

      grouped = Enum.group_by(evidence, & &1.source_type)

      canonical =
        Enum.filter(Map.get(grouped, :knowledge_base, []), &(&1.trust_level == :canonical))

      assistive = Map.get(grouped, :resolved_case, [])
      query = Map.get(attrs, :query) || Map.get(attrs, "query") || "Knowledge Base maintenance"

      %{
        query: query,
        canonical_results: canonical,
        assistive_results: assistive,
        evidence: evidence,
        grounding_assessment: %{
          status: normalize_grounding_status(attrs_grounding_metadata),
          reason: map_value(attrs_grounding_metadata, :reason)
        },
        diagnostic: %{
          reason: map_value(attrs_grounding_metadata, :reason)
        },
        clarification_attempts: map_value(attrs_grounding_metadata, :clarification_attempts) || 0
      }
    else
      retrieval_module = Keyword.get(opts, :retrieval_module, Retrieval)
      query = Map.get(attrs, :query) || Map.get(attrs, "query") || "Knowledge Base maintenance"
      host_user_id = Map.get(attrs, :host_user_id) || Map.get(attrs, "host_user_id")

      retrieval_module.ground_for_draft(
        %{query: query, host_user_id: host_user_id, clarification_attempts: 0},
        surface: :draft_generation,
        host_user_id: host_user_id
      )
    end
  end

  defp build_evidence_snapshot(grounding_bundle) do
    results =
      grounding_bundle
      |> Map.get(:canonical_results, [])
      |> Kernel.++(Map.get(grounding_bundle, :assistive_results, []))
      |> case do
        [] -> Map.get(grounding_bundle, :evidence, [])
        grouped -> grouped
      end

    results
    |> Enum.map(&normalize_evidence_snapshot/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_evidence_snapshot(%ArticleSuggestionEvidence{} = evidence), do: evidence

  defp normalize_evidence_snapshot(%{} = evidence) do
    attrs = %{
      source_type: normalize_source_type(map_value(evidence, :source_type)),
      trust_level: normalize_trust_level(map_value(evidence, :trust_level)),
      title: map_value(evidence, :title) || "Untitled evidence",
      excerpt:
        map_value(evidence, :excerpt) || map_value(evidence, :content_excerpt) ||
          map_value(evidence, :content) || "",
      citation_target:
        normalize_citation_target(
          map_value(evidence, :citation_target),
          map_value(evidence, :article_id),
          map_value(evidence, :revision_id),
          map_value(evidence, :chunk_index)
        ),
      metadata: %{
        destination:
          normalize_destination_metadata(
            map_value(evidence, :metadata),
            map_value(evidence, :article_id),
            map_value(evidence, :revision_id)
          )
      },
      match_reasons:
        evidence
        |> map_value(:match_reasons)
        |> List.wrap()
        |> Enum.map(&to_string/1)
        |> Enum.take(5)
    }

    case ArticleSuggestionEvidence.changeset(%ArticleSuggestionEvidence{}, attrs) do
      %Ecto.Changeset{valid?: true} = changeset -> Ecto.Changeset.apply_changes(changeset)
      _ -> nil
    end
  end

  defp normalize_evidence_snapshot(_), do: nil

  defp normalize_existing_evidence(%ArticleSuggestionEvidence{} = evidence), do: evidence

  defp normalize_existing_evidence(%{} = evidence) do
    normalize_evidence_snapshot(evidence)
  end

  defp normalize_existing_evidence(_), do: nil

  defp canonical_anchor?(%ArticleSuggestionEvidence{} = evidence) do
    evidence.source_type == :knowledge_base and evidence.trust_level == :canonical and
      citation_anchor_present?(evidence.citation_target)
  end

  defp citation_anchor_present?(citation_target) do
    Enum.all?([:article_id, :revision_id, :chunk_index], fn key ->
      map_value(citation_target || %{}, key) not in [nil, ""]
    end)
  end

  defp evidence_digest_for(evidence_snapshot) do
    evidence_snapshot
    |> Enum.map(fn evidence ->
      %{
        source_type: evidence.source_type,
        trust_level: evidence.trust_level,
        title: evidence.title,
        excerpt: evidence.excerpt,
        citation_target: evidence.citation_target,
        match_reasons: evidence.match_reasons
      }
    end)
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp serialize_evidence_snapshot(evidence_snapshot) do
    Enum.map(evidence_snapshot, fn evidence ->
      %{
        source_type: evidence.source_type,
        trust_level: evidence.trust_level,
        title: evidence.title,
        excerpt: evidence.excerpt,
        citation_target: evidence.citation_target,
        metadata: evidence.metadata,
        match_reasons: evidence.match_reasons
      }
    end)
  end

  defp derive_stable_key(bundle) do
    [
      Atom.to_string(bundle.suggestion_type),
      Atom.to_string(bundle.entrypoint_type),
      to_string(bundle.entrypoint_id),
      bundle.base_revision_id && to_string(bundle.base_revision_id),
      bundle.evidence_digest
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(":")
  end

  defp insert_quick_fix_suggestion(prepared, opts) do
    with {:ok, suggestion} <-
           prepared
           |> Map.delete(:quick_fix_package)
           |> then(&ArticleSuggestion.changeset(%ArticleSuggestion{}, &1))
           |> repo().insert(),
         {:ok, _job} <- maybe_enqueue_quick_fix_generation(suggestion, opts) do
      emit_suggestion_outcome(
        quick_fix_telemetry_outcome(suggestion),
        suggestion,
        normalize_failure_reason(map_value(suggestion.grounding_metadata, :quick_fix_reason)),
        :conversation_thread
      )

      {:ok,
       %{
         suggestion: suggestion,
         reused?: false,
         quick_fix: quick_fix_package_for(suggestion.grounding_metadata, prepared.quick_fix_package)
       }}
    end
  end

  defp maybe_enqueue_quick_fix_generation(%ArticleSuggestion{status: status}, _opts)
       when status in [:failed, :ready],
       do: {:ok, :skipped}

  defp maybe_enqueue_quick_fix_generation(%ArticleSuggestion{} = suggestion, opts), do: enqueue_generation_job(suggestion, opts)

  defp attach_review_task_to_quick_fix({:ok, %{suggestion: suggestion} = result}, opts) do
    case ensure_review_task_for_loaded_suggestion(suggestion, Keyword.get(opts, :actor_id), opts) do
      {:ok, review_task} -> {:ok, Map.put(result, :review_task, review_task)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp attach_review_task_to_quick_fix(other, _opts), do: other

  defp insert_and_enqueue(prepared, opts) do
    with {:ok, suggestion} <-
           %ArticleSuggestion{}
           |> ArticleSuggestion.changeset(prepared)
           |> repo().insert(),
         {:ok, _job} <- enqueue_generation_job(suggestion, opts) do
      emit_suggestion_outcome(:queued, suggestion)
      {:ok, suggestion}
    end
  end

  defp persist_failed(prepared, opts) do
    now_fn = Keyword.get(opts, :now_fn, &DateTime.utc_now/0)

    case prepared
         |> Map.put(:status, :failed)
         |> Map.put(:generated_at, now_fn.())
         |> then(&ArticleSuggestion.changeset(%ArticleSuggestion{}, &1))
         |> repo().insert() do
      {:ok, suggestion} = result ->
        emit_suggestion_outcome(
          :failed,
          suggestion,
          normalize_failure_reason(map_value(suggestion.grounding_metadata, :failure_reason))
        )

        result

      other ->
        other
    end
  end

  defp enqueue_generation_job(%ArticleSuggestion{} = suggestion, opts) do
    enqueue_fn = Keyword.get(opts, :enqueue_fn, &Oban.insert/1)
    enqueue_fn.(GenerateArticleSuggestion.new_job(job_args_for(suggestion)))
  end

  defp job_args_for(%ArticleSuggestion{} = suggestion) do
    %{
      suggestion_id: suggestion.id,
      entrypoint_type: suggestion.entrypoint_type,
      entrypoint_id: suggestion.entrypoint_id,
      base_revision_id: suggestion.base_revision_id,
      evidence_digest: suggestion.evidence_digest
    }
  end

  defp entrypoint_type_for(:article), do: :gap_candidate
  defp entrypoint_type_for(:revision), do: :article_revision

  defp entrypoint_id_for(:article, attrs) do
    anchor_id(attrs, :entrypoint_id) || anchor_id(attrs, :gap_candidate_id)
  end

  defp entrypoint_id_for(:revision, attrs) do
    anchor_id(attrs, :entrypoint_id) || anchor_id(attrs, :article_id)
  end

  defp anchor_id(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end

  defp change_summary_for(:article, attrs, _bundle) do
    Map.get(attrs, :change_summary) || Map.get(attrs, "change_summary")
  end

  defp change_summary_for(:revision, attrs, bundle) do
    Map.get(attrs, :change_summary) || Map.get(attrs, "change_summary") ||
      "Revision requested from repeated article-linked failures (#{bundle.stale_signal.signal_count} signals)."
  end

  defp operator_summary_for(type, bundle) do
    if bundle.valid? do
      "#{String.capitalize(Atom.to_string(type))} suggestion queued with #{length(bundle.canonical_evidence)} canonical citation anchors and #{length(bundle.assistive_evidence)} assistive evidence rows."
    else
      failure_operator_summary(type, bundle.failure_reason)
    end
  end

  defp proposed_markdown_for(type, bundle) do
    if bundle.valid?, do: @pending_markdown, else: fallback_markdown(type)
  end

  defp grounding_metadata_for(bundle) do
    %{
      "status" => bundle.grounding_status,
      "query" => bundle.query,
      "evidence_digest" => bundle.evidence_digest,
      "canonical_evidence_count" => length(bundle.canonical_evidence),
      "assistive_evidence_count" => length(bundle.assistive_evidence),
      "citation_validation_result" => if(bundle.valid?, do: "passed", else: "failed"),
      "failure_reason" => stringify_atom(bundle.failure_reason),
      "quick_fix_outcome" => stringify_atom(bundle[:quick_fix_outcome]),
      "quick_fix_reason" => stringify_atom(bundle[:quick_fix_reason]),
      "stale_signal" => stale_signal_metadata(bundle.stale_signal)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  defp ready_grounding_metadata(existing, prepared, evidence_metadata) do
    existing
    |> Map.merge(%{
      "status" => "strong",
      "generation_status" => "ready",
      "citation_validation_result" => "passed",
      "evidence_digest" => prepared.evidence_digest,
      "canonical_evidence_count" => length(prepared.canonical_evidence),
      "assistive_evidence_count" => length(prepared.assistive_evidence),
      "citation_metadata" => Map.get(evidence_metadata, :citations, []),
      "generation_metadata" => evidence_metadata
    })
  end

  defp failed_grounding_metadata(existing, prepared, failure_reason) do
    existing
    |> Map.merge(%{
      "generation_status" => "failed",
      "citation_validation_result" =>
        if(failure_reason == :missing_canonical_citations, do: "failed", else: "passed"),
      "failure_reason" => Atom.to_string(failure_reason),
      "evidence_digest" => prepared.evidence_digest,
      "canonical_evidence_count" => length(prepared.canonical_evidence),
      "assistive_evidence_count" => length(prepared.assistive_evidence)
    })
  end

  defp fallback_markdown(type), do: Map.fetch!(@failed_markdown, type)

  defp failure_operator_summary(type, failure_reason) do
    "#{String.capitalize(Atom.to_string(type))} suggestion blocked: #{failure_reason_message(failure_reason)}"
  end

  defp failure_reason_message(:weak_grounding),
    do: "grounding did not meet the canonical threshold"

  defp failure_reason_message(:missing_canonical_citations),
    do: "canonical citation anchors were missing"

  defp failure_reason_message(:missing_canonical_grounding),
    do: "canonical grounding is incomplete"

  defp failure_reason_message(:canonical_snapshot_unavailable),
    do: "the canonical evidence snapshot could not be built"

  defp failure_reason_message(:citation_anchors_unavailable),
    do: "citation anchors were unavailable"

  defp failure_reason_message(:policy_guard_blocked),
    do: "policy guardrails blocked the automatic suggestion"

  defp failure_reason_message(:generation_failed), do: "Scoria generation failed"
  defp failure_reason_message(other), do: to_string(other)

  defp quick_fix_outcome(attrs, canonical_evidence, citation_ready?) do
    reason =
      attrs
      |> anchor_id(:canonical_retrieval)
      |> map_value(:failure_reason)
      |> normalize_quick_fix_reason(canonical_evidence, citation_ready?)

    cond do
      reason in @quick_fix_shell_reasons -> {:shell_created, reason}
      reason in @quick_fix_blocked_reasons -> {:blocked_manual_required, reason}
      true -> {:ready, nil}
    end
  end

  defp normalize_quick_fix_reason(nil, canonical_evidence, true) when canonical_evidence != [], do: nil
  defp normalize_quick_fix_reason(nil, _canonical_evidence, false), do: :citation_anchors_unavailable
  defp normalize_quick_fix_reason(nil, _canonical_evidence, true), do: :missing_canonical_grounding

  defp normalize_quick_fix_reason(reason, _canonical_evidence, _citation_ready?)
       when is_atom(reason) do
    if reason in @quick_fix_shell_reasons ++ @quick_fix_blocked_reasons do
      reason
    else
      :policy_guard_blocked
    end
  end

  defp normalize_quick_fix_reason(reason, _canonical_evidence, _citation_ready?) when is_binary(reason) do
    reason
    |> String.to_existing_atom()
  rescue
    ArgumentError -> :policy_guard_blocked
  end

  defp quick_fix_grounding_status(:ready), do: :strong
  defp quick_fix_grounding_status(:shell_created), do: :weak
  defp quick_fix_grounding_status(:blocked_manual_required), do: :weak

  defp quick_fix_suggestion_status(:ready), do: :pending_generation
  defp quick_fix_suggestion_status(:shell_created), do: :ready
  defp quick_fix_suggestion_status(:blocked_manual_required), do: :failed

  defp quick_fix_operator_summary(%{quick_fix_outcome: :ready} = bundle),
    do: operator_summary_for(:article, bundle)

  defp quick_fix_operator_summary(%{quick_fix_outcome: :shell_created, quick_fix_reason: reason}) do
    "Article draft shell created: #{failure_reason_message(reason)}. Review and complete the manual grounding in the shared lane."
  end

  defp quick_fix_operator_summary(%{quick_fix_reason: reason}) do
    "Article suggestion blocked: #{failure_reason_message(reason)}. Use manual authoring from the shared review lane."
  end

  defp quick_fix_markdown(%{quick_fix_outcome: :ready} = bundle), do: proposed_markdown_for(:article, bundle)

  defp quick_fix_markdown(%{quick_fix_outcome: :shell_created}) do
    """
    # Draft shell

    Manual grounding is still required before this quick fix can become a canonical KB update.
    """
  end

  defp quick_fix_markdown(_bundle), do: fallback_markdown(:article)

  defp quick_fix_query(attrs) do
    anchor_id(attrs, :query) || anchor_id(attrs, :title) ||
      map_value(anchor_id(attrs, :thread_context) || %{}, :subject) ||
      "Conversation quick fix"
  end

  defp quick_fix_canonical_evidence(attrs) do
    attrs
    |> anchor_id(:canonical_retrieval)
    |> map_value(:evidence)
    |> List.wrap()
  end

  defp quick_fix_evidence_digest(attrs, canonical_evidence) do
    attrs
    |> anchor_id(:canonical_retrieval)
    |> map_value(:evidence_digest) ||
      evidence_digest_for(canonical_evidence)
  end

  defp quick_fix_citation_ready?(attrs, canonical_evidence) do
    attrs
    |> anchor_id(:canonical_retrieval)
    |> map_value(:citation_ready)
    |> case do
      nil -> canonical_evidence != []
      value -> value in [true, "true"]
    end
  end

  defp quick_fix_package_for(attrs, evidence_digest, canonical_evidence_count, citation_ready?) do
    %{
      "thread_context" => normalize_quick_fix_thread_context(anchor_id(attrs, :thread_context), anchor_id(attrs, :conversation_id)),
      "canonical_retrieval" => %{
        "evidence_digest" => evidence_digest,
        "canonical_evidence_count" => canonical_evidence_count,
        "citation_ready" => citation_ready?
      },
      "resolved_case_assists" => normalize_quick_fix_case_assists(anchor_id(attrs, :resolved_case_assists))
    }
  end

  defp normalize_quick_fix_thread_context(thread_context, conversation_id) do
    thread_context = thread_context || %{}

    %{
      "conversation_id" => map_value(thread_context, :conversation_id) || conversation_id,
      "subject" => map_value(thread_context, :subject),
      "message_excerpt" => map_value(thread_context, :message_excerpt),
      "message_count" => map_value(thread_context, :message_count)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  defp normalize_quick_fix_case_assists(case_assists) do
    case_assists = case_assists || %{}

    %{
      "case_count" => map_value(case_assists, :case_count) || length(List.wrap(map_value(case_assists, :summaries))),
      "summaries" => List.wrap(map_value(case_assists, :summaries))
    }
    |> Enum.reject(fn {key, value} -> key != "summaries" and is_nil(value) end)
    |> Enum.into(%{})
  end

  defp quick_fix_package_for(grounding_metadata, fallback_package) do
    map_value(grounding_metadata || %{}, :quick_fix_package) || fallback_package
  end

  defp initial_review_task_attrs(%ArticleSuggestion{status: :failed} = suggestion, actor_id, opts) do
    %{
      last_decision: :review_needed,
      last_reason: :needs_manual_edit,
      last_actor_id: actor_id || suggestion.host_user_id || "system",
      last_decided_at: now_fn(opts).(),
      notes: quick_fix_task_note(suggestion)
    }
  end

  defp initial_review_task_attrs(_suggestion, _actor_id, _opts), do: %{}

  defp quick_fix_task_note(%ArticleSuggestion{entrypoint_type: :conversation_quick_fix} = suggestion) do
    case map_value(suggestion.grounding_metadata || %{}, :quick_fix_reason) do
      nil -> suggestion.operator_summary
      reason -> "Manual draft required: #{failure_reason_message(normalize_failure_reason(reason))}."
    end
  end

  defp quick_fix_task_note(%ArticleSuggestion{} = suggestion), do: suggestion.operator_summary

  defp reviewable_for_review_task?(%ArticleSuggestion{
         entrypoint_type: :conversation_quick_fix,
         status: :pending_generation
       }),
       do: true

  defp reviewable_for_review_task?(%ArticleSuggestion{status: status}), do: status in [:ready, :failed]

  defp revision_gate_opts(attrs, opts) do
    [
      now_fn: Keyword.get(opts, :now_fn, &DateTime.utc_now/0),
      gap_events: Keyword.get(opts, :gap_events),
      grounding_bundle: Keyword.get(opts, :grounding_bundle),
      tenant_scope: Map.get(attrs, :tenant_scope) || Map.get(attrs, "tenant_scope"),
      host_user_id: Map.get(attrs, :host_user_id) || Map.get(attrs, "host_user_id")
    ]
  end

  defp normalize_source_type(value) when value in [:knowledge_base, :resolved_case], do: value
  defp normalize_source_type("knowledge_base"), do: :knowledge_base
  defp normalize_source_type("resolved_case"), do: :resolved_case
  defp normalize_source_type(_), do: :unknown

  defp normalize_trust_level(value) when value in [:canonical, :assistive], do: value
  defp normalize_trust_level("canonical"), do: :canonical
  defp normalize_trust_level("assistive"), do: :assistive
  defp normalize_trust_level(_), do: :unknown

  defp normalize_citation_target(%{} = citation_target, article_id, revision_id, chunk_index) do
    citation_target
    |> Enum.into(%{}, fn {key, value} -> {normalize_map_key(key), value} end)
    |> Map.put_new(:article_id, article_id)
    |> Map.put_new(:revision_id, revision_id)
    |> Map.put_new(:chunk_index, chunk_index)
  end

  defp normalize_citation_target(_, article_id, revision_id, chunk_index) do
    %{
      article_id: article_id,
      revision_id: revision_id,
      chunk_index: chunk_index
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  defp normalize_destination_metadata(%{} = metadata, article_id, revision_id) do
    destination = map_value(metadata, :destination) || %{}

    destination
    |> Enum.into(%{}, fn {key, value} -> {normalize_map_key(key), value} end)
    |> Map.put_new(:article_id, article_id)
    |> Map.put_new(:revision_id, revision_id)
  end

  defp normalize_destination_metadata(_, article_id, revision_id) do
    %{}
    |> maybe_put_destination(:article_id, article_id)
    |> maybe_put_destination(:revision_id, revision_id)
  end

  defp maybe_put_destination(map, _key, nil), do: map
  defp maybe_put_destination(map, key, value), do: Map.put(map, key, value)

  defp normalize_grounding_status(%{grounding_assessment: %{status: status}}), do: status
  defp normalize_grounding_status(%{"grounding_assessment" => %{"status" => status}}), do: status

  defp normalize_grounding_status(metadata) when is_map(metadata) do
    value = map_value(metadata, :status)

    case value do
      "strong" -> :strong
      "clarification" -> :clarification
      "escalation" -> :escalation
      other when is_atom(other) -> other
      _ -> :unknown
    end
  end

  defp normalize_grounding_status(_), do: :unknown

  defp stale_signal_metadata(nil), do: nil

  defp stale_signal_metadata(signal) do
    %{
      ready?: signal.ready?,
      reason: signal.reason,
      signal_count: signal.signal_count,
      fresh_canonical_snapshot?: signal.fresh_canonical_snapshot?
    }
  end

  defp normalize_failure_reason({:error, reason}), do: normalize_failure_reason(reason)
  defp normalize_failure_reason(reason) when is_atom(reason), do: reason
  defp normalize_failure_reason(_), do: :generation_failed

  defp normalize_map_key(key) when is_binary(key), do: String.to_atom(key)
  defp normalize_map_key(key), do: key

  defp stringify_atom(nil), do: nil
  defp stringify_atom(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_atom(value), do: value

  defp map_value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp map_value(_, _), do: nil

  defp stale_article_signal_module(opts) do
    Keyword.get(opts, :stale_article_signal_module, StaleArticleSignal)
  end

  defp now_fn(opts) do
    Keyword.get(opts, :now_fn, &DateTime.utc_now/0)
  end

  defp knowledge_base_module(opts) do
    Keyword.get(opts, :knowledge_base_module, KnowledgeBase)
  end

  defp approval_article_id(%ArticleSuggestion{article_id: article_id}, _task, _opts)
       when is_integer(article_id),
       do: {:ok, article_id}

  defp approval_article_id(_suggestion, %ReviewTask{staged_article_id: article_id}, _opts)
       when is_integer(article_id),
       do: {:ok, article_id}

  defp approval_article_id(_suggestion, _task, _opts), do: {:error, :missing_article}

  defp load_review_task_with_suggestion(id, opts) do
    task =
      id
      |> get_review_task!(opts)
      |> repo().preload(:article_suggestion)

    if task.article_suggestion do
      {:ok, task, task.article_suggestion}
    else
      {:error, :missing_suggestion}
    end
  end

  defp load_article(article_id, opts) do
    case Keyword.get(opts, :load_article_fn) do
      nil ->
        case knowledge_base_module(opts).get_article(article_id) do
          nil -> {:error, :missing_article}
          article -> {:ok, article}
        end

      load_article_fn ->
        load_article_fn.(article_id)
    end
  end

  defp latest_revision(article_id, opts) do
    case Keyword.get(opts, :latest_revision_fn) do
      nil -> knowledge_base_module(opts).get_latest_revision(article_id)
      latest_revision_fn -> latest_revision_fn.(article_id)
    end
  end

  defp load_staged_revision(%ReviewTask{staged_revision_id: nil}, _opts), do: {:error, :missing_staged_revision}

  defp load_staged_revision(%ReviewTask{staged_revision_id: revision_id}, opts) do
    case Keyword.get(opts, :get_revision_fn) do
      nil ->
        case knowledge_base_module(opts).get_revision(revision_id) do
          nil -> {:error, :missing_staged_revision}
          revision -> {:ok, revision}
        end

      get_revision_fn ->
        case get_revision_fn.(revision_id) do
          nil -> {:error, :missing_staged_revision}
          revision -> {:ok, revision}
        end
    end
  end

  defp save_draft(article, attrs, opts) do
    case Keyword.get(opts, :save_draft_fn) do
      nil -> knowledge_base_module(opts).save_draft(article, attrs)
      save_draft_fn -> save_draft_fn.(article, attrs)
    end
  end

  defp publish_revision(revision, opts) do
    case Keyword.get(opts, :publish_revision_fn) do
      nil -> knowledge_base_module(opts).publish_revision(revision)
      publish_revision_fn -> publish_revision_fn.(revision)
    end
  end

  defp ensure_no_unrelated_draft(%ReviewTask{} = task, article_id, opts) do
    case latest_revision(article_id, opts) do
      %{state: :draft, id: draft_id}
      when not is_nil(task.staged_revision_id) and draft_id == task.staged_revision_id ->
        :ok

      %{state: :draft, id: draft_id} = revision when is_nil(task.staged_revision_id) or draft_id != task.staged_revision_id ->
        {:error, {:draft_conflict, revision}}

      _ ->
        :ok
    end
  end

  defp ensure_publishable_status(%ReviewTask{status: :approved_ready_to_publish}), do: :ok
  defp ensure_publishable_status(_task), do: {:error, :invalid_publish_state}

  defp ensure_publish_freshness(%ReviewTask{}, %ArticleSuggestion{suggestion_type: :article}, _opts), do: :ok

  defp ensure_publish_freshness(%ReviewTask{}, %ArticleSuggestion{} = suggestion, opts) do
    latest_active_revision_fn =
      Keyword.get(opts, :latest_active_revision_fn, fn article_id ->
        knowledge_base_module(opts).get_latest_active_revision(article_id)
      end)

    case latest_active_revision_fn.(suggestion.article_id) do
      nil ->
        {:error, :missing_latest_active_revision}

      %{id: id} when id == suggestion.base_revision_id ->
        :ok

      latest_revision ->
        {:error, {:stale_base, latest_revision}}
    end
  end

  defp record_structured_decision(id, status, decision, reason, opts) do
    now = now_fn(opts).()
    actor_id = Keyword.get(opts, :actor_id) || "system"

    with {:ok, task, _suggestion} <- load_review_task_with_suggestion(id, opts) do
      update_task_with_event(
        task,
        ReviewTask.decision_changeset(task, status, decision, reason, actor_id, now, %{notes: Keyword.get(opts, :note)}),
        %{
          event_type: :decision_recorded,
          from_status: task.status,
          to_status: status,
          decision: decision,
          reason: reason,
          actor_id: actor_id,
          notes: Keyword.get(opts, :note),
          metadata: %{}
        }
      )
    end
  end

  defp update_task_with_event(task, changeset, event_attrs, result_type \\ :ok) do
    with {:ok, updated_task} <- repo().update(changeset),
         {:ok, _event} <-
           %ReviewTaskEvent{}
           |> ReviewTaskEvent.changeset(Map.put(event_attrs, :review_task_id, task.id))
           |> repo().insert() do
      emit_review_task_event(updated_task, task, event_attrs)
      {result_type, updated_task}
    end
  end

  defp find_review_task_by_published_revision_id(revision_id, opts) do
    ReviewTask
    |> apply_scope(opts)
    |> where([task], task.published_revision_id == ^revision_id)
    |> repo().all()
    |> repo().preload(:article_suggestion)
    |> List.first()
  end

  defp persist_reindex_outcome(task, published_revision_id, result, opts) do
    actor_id = Keyword.get(opts, :actor_id, "chunk_revision")
    {result_type, reindex_status, metadata} = reindex_outcome_payload(published_revision_id, result)

    update_task_with_event(
      task,
      ReviewTask.changeset(task, %{
        status: :published,
        published_revision_id: task.published_revision_id || published_revision_id,
        published_at: task.published_at,
        publish_status: :published,
        reindex_status: reindex_status
      }),
      %{
        event_type: :reindex_recorded,
        from_status: task.status,
        to_status: :published,
        decision: task.last_decision,
        reason: task.last_reason,
        actor_id: actor_id,
        metadata: metadata
      },
      result_type
    )
  end

  defp reindex_outcome_payload(published_revision_id, :ok) do
    {:ok, :completed,
     %{published_revision_id: published_revision_id, publish_status: :published, reindex_status: :completed}}
  end

  defp reindex_outcome_payload(published_revision_id, {:error, reason}) do
    {:error, :failed,
     %{
       published_revision_id: published_revision_id,
       publish_status: :published,
       reindex_status: :failed,
       error: reason
     }}
  end

  defp material_edit_baseline(%ReviewTask{} = task, %ArticleSuggestion{} = suggestion, opts) do
    case load_staged_revision(task, opts) do
      {:ok, revision} when is_binary(revision.content) -> revision.content
      _ -> suggestion.proposed_markdown || ""
    end
  end

  defp material_content_changed?(left, right) do
    normalize_markdown_for_compare(left) != normalize_markdown_for_compare(right)
  end

  defp normalize_markdown_for_compare(content) when is_binary(content) do
    content
    |> String.replace("\r\n", "\n")
    |> String.trim()
  end

  defp normalize_markdown_for_compare(_), do: ""

  defp apply_scope(query, opts) do
    query
    |> maybe_where_equal(:tenant_scope, Keyword.get(opts, :tenant_scope))
    |> maybe_where_equal(:host_user_id, Keyword.get(opts, :host_user_id))
  end

  defp maybe_filter_status(query, opts) do
    case Keyword.get(opts, :status, :open) do
      :all -> query
      nil -> query
      status -> where(query, [candidate], candidate.status == ^status)
    end
  end

  defp maybe_filter_article_suggestion_status(query, opts) do
    case Keyword.get(opts, :status, :all) do
      :all -> query
      nil -> query
      status -> where(query, [suggestion], suggestion.status == ^status)
    end
  end

  defp maybe_filter_review_task_status(query, opts) do
    case Keyword.get(opts, :status, :all) do
      :all -> query
      nil -> query
      status -> where(query, [task], task.status == ^status)
    end
  end

  defp maybe_where_equal(query, _field, nil), do: query

  defp maybe_where_equal(query, field, value) do
    where(query, [candidate], field(candidate, ^field) == ^value)
  end

  defp emit_suggestion_outcome(outcome, suggestion, reason \\ :unspecified, surface \\ :review_lane) do
    Telemetry.emit(:suggestion_outcome, %{count: 1}, %{
      surface: surface,
      entrypoint_type: suggestion.entrypoint_type,
      outcome: outcome,
      reason: normalize_maintenance_reason(reason),
      canonical_evidence_count: metadata_count(suggestion.grounding_metadata, :canonical_evidence_count),
      assistive_evidence_count: metadata_count(suggestion.grounding_metadata, :assistive_evidence_count)
    })
  end

  defp emit_review_task_event(updated_task, previous_task, event_attrs) do
    metadata = Map.get(event_attrs, :metadata, %{})
    suggestion = updated_task.article_suggestion || previous_task.article_suggestion

    base_metadata = %{
      surface: review_task_surface(Map.get(event_attrs, :event_type)),
      entrypoint_type: suggestion_entrypoint_type(suggestion),
      reason: normalize_maintenance_reason(Map.get(event_attrs, :reason)),
      publish_status: updated_task.publish_status,
      reindex_status: updated_task.reindex_status,
      canonical_evidence_count: suggestion_evidence_count(suggestion, :canonical_evidence_count),
      assistive_evidence_count: suggestion_evidence_count(suggestion, :assistive_evidence_count)
    }

    case Map.get(event_attrs, :event_type) do
      :decision_recorded ->
        Telemetry.emit(:review_decision, %{count: 1}, Map.put(base_metadata, :outcome, Map.get(event_attrs, :decision)))

      :publish_recorded ->
        outcome =
          case updated_task.status do
            :published -> :published
            _ -> :publish_blocked
          end

        Telemetry.emit(
          :publish_outcome,
          %{count: 1},
          base_metadata
          |> Map.put(:outcome, outcome)
          |> Map.put(:publish_status, metadata_value(metadata, :publish_status) || updated_task.publish_status)
        )

      :reindex_recorded ->
        Telemetry.emit(
          :reindex_outcome,
          %{count: 1},
          base_metadata
          |> Map.put(:outcome, reindex_outcome_for(updated_task.reindex_status))
          |> Map.put(:publish_status, metadata_value(metadata, :publish_status) || updated_task.publish_status)
          |> Map.put(:reindex_status, metadata_value(metadata, :reindex_status) || updated_task.reindex_status)
        )

      _ ->
        :ok
    end
  end

  defp review_task_surface(:reindex_recorded), do: :worker
  defp review_task_surface(_event_type), do: :review_lane

  defp quick_fix_telemetry_outcome(%ArticleSuggestion{status: :ready}), do: :shell_created
  defp quick_fix_telemetry_outcome(%ArticleSuggestion{status: :failed}), do: :blocked_manual_required
  defp quick_fix_telemetry_outcome(_suggestion), do: :queued

  defp normalize_maintenance_reason(reason) when reason in [nil, :ready], do: :unspecified
  defp normalize_maintenance_reason(:missing_canonical_citations), do: :missing_canonical_citations
  defp normalize_maintenance_reason(:weak_grounding), do: :weak_grounding
  defp normalize_maintenance_reason(reason), do: normalize_failure_reason(reason)

  defp metadata_count(metadata, key) do
    metadata
    |> map_value(key)
    |> case do
      value when is_integer(value) -> value
      value when is_binary(value) ->
        case Integer.parse(value) do
          {int, _} -> int
          _ -> 0
        end

      _ ->
        0
    end
  end

  defp suggestion_evidence_count(nil, _key), do: 0
  defp suggestion_evidence_count(%Ecto.Association.NotLoaded{}, _key), do: 0
  defp suggestion_evidence_count(%ArticleSuggestion{grounding_metadata: metadata}, key), do: metadata_count(metadata, key)
  defp suggestion_entrypoint_type(nil), do: :unspecified
  defp suggestion_entrypoint_type(%Ecto.Association.NotLoaded{}), do: :unspecified
  defp suggestion_entrypoint_type(%ArticleSuggestion{entrypoint_type: type}), do: type || :unspecified

  defp reindex_outcome_for(:completed), do: :completed
  defp reindex_outcome_for(_status), do: :failed

  defp metadata_value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp metadata_value(_, _), do: nil

  defp enforce_scope!(candidate, opts, queryable) do
    expected_tenant_scope = Keyword.get(opts, :tenant_scope)
    expected_host_user_id = Keyword.get(opts, :host_user_id)

    tenant_scope_matches? =
      is_nil(expected_tenant_scope) or candidate.tenant_scope == expected_tenant_scope

    host_user_id_matches? =
      is_nil(expected_host_user_id) or
        to_string(candidate.host_user_id) == to_string(expected_host_user_id)

    if tenant_scope_matches? and host_user_id_matches? do
      candidate
    else
      raise Ecto.NoResultsError, queryable: queryable
    end
  end

  defp find_active_review_task(%ArticleSuggestion{} = suggestion, opts) do
    ReviewTask
    |> apply_scope(opts)
    |> where([task], task.article_suggestion_id == ^suggestion.id)
    |> where([task], task.status in ^active_review_task_statuses())
    |> repo().all()
    |> List.first()
  end

  defp find_article_suggestion_by_stable_key(stable_key, opts) do
    ArticleSuggestion
    |> apply_scope(opts)
    |> where([suggestion], suggestion.stable_key == ^stable_key)
    |> order_by([suggestion], desc: suggestion.inserted_at, desc: suggestion.id)
    |> repo().all()
    |> List.first()
  end

  defp find_latest_conversation_quick_fix(conversation_id, opts) do
    ArticleSuggestion
    |> apply_scope(opts)
    |> where(
      [suggestion],
      suggestion.entrypoint_type == ^:conversation_quick_fix and
        suggestion.entrypoint_id == ^conversation_id
    )
    |> order_by([suggestion], desc: suggestion.inserted_at, desc: suggestion.id)
    |> repo().all()
    |> List.first()
  end

  defp active_review_task_statuses do
    ReviewTask.active_status_values()
  end

  defp initial_review_task_status(%ArticleSuggestion{status: :failed}), do: :review_needed
  defp initial_review_task_status(%ArticleSuggestion{}), do: :pending_review

  defp hydrate_memberships(%GapCandidate{} = candidate) do
    retrieval_ids =
      candidate.memberships
      |> Enum.filter(&(&1.source_type == :retrieval_gap_event))
      |> Enum.map(& &1.source_id)

    manual_ids =
      candidate.memberships
      |> Enum.filter(&(&1.source_type == :manual_handling_case))
      |> Enum.map(& &1.source_id)

    retrieval_gap_events =
      if retrieval_ids == [] do
        []
      else
        GapEvent
        |> where([event], event.id in ^retrieval_ids)
        |> order_by([event], desc: event.occurred_at, desc: event.id)
        |> repo().all()
        |> Enum.map(&serialize_gap_event/1)
      end

    manual_handling_evidence =
      if manual_ids == [] do
        []
      else
        ResolvedCaseEvidence
        |> where([evidence], evidence.id in ^manual_ids)
        |> order_by([evidence], desc: evidence.resolved_at, desc: evidence.id)
        |> repo().all()
        |> Enum.map(&serialize_manual_handling_evidence/1)
      end

    %{
      candidate
      | retrieval_gap_events: retrieval_gap_events,
        manual_handling_evidence: manual_handling_evidence
    }
  end

  defp serialize_gap_event(event) do
    %{
      id: event.id,
      occurred_at: event.occurred_at,
      surface: event.surface,
      reason: event.reason,
      outcome_class: event.outcome_class,
      canonical_hit_count: event.canonical_hit_count,
      assistive_hit_count: event.assistive_hit_count,
      sanitized_query_excerpt: event.sanitized_query_excerpt
    }
  end

  defp serialize_manual_handling_evidence(evidence) do
    %{
      id: evidence.id,
      conversation_id: evidence.conversation_id,
      subject: evidence.subject,
      issue_summary: evidence.issue_summary,
      resolution_note: evidence.resolution_note,
      actions_taken: evidence.actions_taken,
      resolved_at: evidence.resolved_at,
      citation_backreferences: evidence.citation_backreferences
    }
  end
end
