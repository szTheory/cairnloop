defmodule Cairnloop.Web.ArticleSuggestionPresenter do
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion
  alias Cairnloop.Retrieval.Result
  alias Cairnloop.Web.SearchResultPresenter

  def status_label(%ArticleSuggestion{status: :pending_generation}), do: "Queued for generation"
  def status_label(%ArticleSuggestion{status: :ready}), do: "Ready for review"
  def status_label(%ArticleSuggestion{status: :failed}), do: "Generation blocked"
  def status_label(%ArticleSuggestion{status: :dismissed}), do: "Dismissed"

  def stale_pressure_label(%ArticleSuggestion{} = suggestion) do
    stale_signal = metadata_value(suggestion.grounding_metadata, :stale_signal) || %{}
    count = metadata_value(stale_signal, :signal_count) || 0

    case {suggestion.suggestion_type, count} do
      {:revision, 0} -> "No repeated stale pressure captured"
      {:revision, _} -> "#{count} repeated article-linked failures"
      _ -> "Gap-driven article suggestion"
    end
  end

  def action_labels(%ArticleSuggestion{status: :ready}), do: ["regenerate", "dismiss", "open for manual edit"]
  def action_labels(%ArticleSuggestion{status: :failed}), do: ["regenerate", "inspect failure"]
  def action_labels(_suggestion), do: ["inspect"]

  def source_label(evidence), do: evidence |> to_result() |> SearchResultPresenter.source_label()
  def trust_label(evidence), do: evidence |> to_result() |> SearchResultPresenter.trust_label()

  def evidence_path(evidence) do
    result = to_result(evidence)
    SearchResultPresenter.open_path(result)
  end

  def citation_anchor(evidence) do
    target = metadata_value(evidence.citation_target, :revision_id)
    chunk_index = metadata_value(evidence.citation_target, :chunk_index)

    [target && "Revision #{target}", !is_nil(chunk_index) && "Chunk #{chunk_index}"]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  def revision_diff(%ArticleSuggestion{} = suggestion, nil), do: suggestion.proposed_markdown

  def revision_diff(%ArticleSuggestion{} = suggestion, base_content) do
    removed = summarize_lines(base_content, "-")
    added = summarize_lines(suggestion.proposed_markdown, "+")

    ["## Removed", removed, "", "## Added", added]
    |> Enum.join("\n")
  end

  def failure_copy(%ArticleSuggestion{} = suggestion) do
    quick_fix_reason_label(suggestion) ||
      metadata_value(suggestion.grounding_metadata, :failure_reason) ||
      "Grounding stayed below the canonical threshold."
  end

  def quick_fix?(%ArticleSuggestion{entrypoint_type: :conversation_quick_fix}), do: true
  def quick_fix?(%ArticleSuggestion{}), do: false

  def quick_fix_outcome_label(%ArticleSuggestion{} = suggestion) do
    case metadata_value(suggestion.grounding_metadata, :quick_fix_outcome) do
      "ready" -> "Review task ready"
      "shell_created" -> "Draft shell created"
      "blocked_manual_required" -> "Manual draft required"
      :ready -> "Review task ready"
      :shell_created -> "Draft shell created"
      :blocked_manual_required -> "Manual draft required"
      _ -> nil
    end
  end

  def quick_fix_reason_label(%ArticleSuggestion{} = suggestion) do
    case metadata_value(suggestion.grounding_metadata, :quick_fix_reason) ||
           metadata_value(suggestion.grounding_metadata, :failure_reason) do
      "missing_canonical_grounding" -> "Missing canonical grounding"
      "canonical_snapshot_unavailable" -> "Canonical snapshot unavailable"
      "citation_anchors_unavailable" -> "Citation anchors unavailable"
      "policy_guard_blocked" -> "Policy guard blocked automatic suggestion"
      :missing_canonical_grounding -> "Missing canonical grounding"
      :canonical_snapshot_unavailable -> "Canonical snapshot unavailable"
      :citation_anchors_unavailable -> "Citation anchors unavailable"
      :policy_guard_blocked -> "Policy guard blocked automatic suggestion"
      _ -> nil
    end
  end

  def quick_fix_launch_context(%ArticleSuggestion{} = suggestion) do
    thread_context = quick_fix_thread_context(suggestion)
    conversation_id = metadata_value(thread_context, :conversation_id)
    subject = metadata_value(thread_context, :subject)

    [conversation_id && "Conversation #{conversation_id}", subject]
    |> Enum.filter(&present?/1)
    |> Enum.join(" · ")
  end

  def quick_fix_message_excerpt(%ArticleSuggestion{} = suggestion) do
    suggestion
    |> quick_fix_thread_context()
    |> metadata_value(:message_excerpt)
  end

  def quick_fix_layers(%ArticleSuggestion{} = suggestion) do
    quick_fix_package = metadata_value(suggestion.grounding_metadata, :quick_fix_package) || %{}
    thread_context = metadata_value(quick_fix_package, :thread_context) || %{}
    canonical_retrieval = metadata_value(quick_fix_package, :canonical_retrieval) || %{}
    resolved_case_assists = metadata_value(quick_fix_package, :resolved_case_assists) || %{}

    [
      %{
        label: "Thread context",
        trust: "Conversation signal",
        summary:
          metadata_value(thread_context, :message_count)
          |> case do
            nil -> "No bounded thread summary"
            count -> "#{count} messages summarized"
          end
      },
      %{
        label: "Canonical retrieval",
        trust: "Citation-eligible",
        summary:
          canonical_retrieval_summary(
            metadata_value(canonical_retrieval, :canonical_evidence_count),
            metadata_value(canonical_retrieval, :citation_ready)
          )
      },
      %{
        label: "Resolved case assists",
        trust: "Supporting context",
        summary:
          resolved_case_summary(
            metadata_value(resolved_case_assists, :case_count),
            metadata_value(resolved_case_assists, :summaries)
          )
      }
    ]
  end

  defp summarize_lines(content, prefix) do
    content
    |> to_string()
    |> String.split("\n", trim: true)
    |> Enum.take(6)
    |> Enum.map_join("\n", fn line -> "#{prefix} #{line}" end)
  end

  defp to_result(evidence) do
    %Result{
      source_type: evidence.source_type,
      trust_level: evidence.trust_level,
      title: evidence.title,
      content: evidence.excerpt,
      article_id: metadata_value(evidence.citation_target, :article_id),
      revision_id: metadata_value(evidence.citation_target, :revision_id),
      metadata: metadata_value(evidence.metadata, :destination) && %{destination: evidence.metadata.destination}
    }
  end

  defp metadata_value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp metadata_value(_, _), do: nil

  defp quick_fix_thread_context(%ArticleSuggestion{} = suggestion) do
    suggestion.grounding_metadata
    |> metadata_value(:quick_fix_package)
    |> metadata_value(:thread_context) || %{}
  end

  defp canonical_retrieval_summary(count, citation_ready) do
    count = count || 0

    cond do
      citation_ready in [true, "true"] -> "#{count} citation-ready evidence rows"
      count > 0 -> "#{count} evidence rows need citation repair"
      true -> "No citation-ready canonical evidence"
    end
  end

  defp resolved_case_summary(count, summaries) do
    count = count || length(List.wrap(summaries))

    case count do
      0 -> "No supporting resolved cases"
      1 -> "1 supporting case"
      _ -> "#{count} supporting cases"
    end
  end

  defp present?(value), do: value not in [nil, ""]
end
