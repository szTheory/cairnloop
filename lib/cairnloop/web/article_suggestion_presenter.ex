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
    metadata_value(suggestion.grounding_metadata, :failure_reason) ||
      "Grounding stayed below the canonical threshold."
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
end
