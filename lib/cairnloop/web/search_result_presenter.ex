defmodule Cairnloop.Web.SearchResultPresenter do
  alias Cairnloop.Retrieval.Result

  def section_name(%Result{source_type: :knowledge_base}), do: "Knowledge Base"
  def section_name(%Result{source_type: :resolved_case}), do: "Similar resolved cases"

  def source_label(%Result{source_type: :knowledge_base}), do: "Knowledge Base"
  def source_label(%Result{source_type: :resolved_case}), do: "Resolved case"

  def trust_label(%Result{trust_level: :canonical}), do: "Canonical guidance"
  def trust_label(%Result{trust_level: :assistive}), do: "Supporting evidence"

  def title(%Result{title: title}) when is_binary(title) and title != "", do: title
  def title(%Result{source_type: :knowledge_base}), do: "Knowledge Base article"
  def title(%Result{source_type: :resolved_case}), do: "Resolved case"

  def row_snippet(%Result{} = result) do
    result
    |> preview_excerpt()
    |> truncate(180)
  end

  def preview_heading(%Result{source_type: :knowledge_base} = result) do
    case metadata(result, :heading) do
      heading when is_binary(heading) and heading != "" -> heading
      _ -> title(result)
    end
  end

  def preview_heading(%Result{} = result), do: title(result)

  def preview_copy(%Result{source_type: :knowledge_base} = result) do
    [
      preview_heading(result),
      preview_excerpt(result)
    ]
    |> Enum.filter(&present?/1)
  end

  def preview_copy(%Result{source_type: :resolved_case} = result) do
    [
      preview_block("Issue summary", result.issue_summary),
      preview_block("Resolution note", result.resolution_note),
      preview_actions(result.actions_taken),
      preview_block("Outcome", result.outcome),
      preview_block("Matched excerpt", preview_excerpt(result))
    ]
    |> Enum.filter(&present?/1)
  end

  def recency_label(%Result{source_type: :knowledge_base} = result) do
    "Updated #{relative_time(result.updated_at)}"
  end

  def recency_label(%Result{source_type: :resolved_case} = result) do
    "Resolved #{relative_time(result.resolved_at)}"
  end

  def open_action_label(%Result{source_type: :knowledge_base}), do: "Open article"
  def open_action_label(%Result{source_type: :resolved_case}), do: "Open resolved case"

  def open_path(%Result{source_type: :knowledge_base} = result) do
    case destination(result) do
      %{article_id: article_id} when not is_nil(article_id) ->
        "/knowledge-base/#{article_id}/edit"

      _ ->
        nil
    end
  end

  def open_path(%Result{source_type: :resolved_case} = result) do
    case destination(result) do
      %{conversation_id: conversation_id} when not is_nil(conversation_id) ->
        "/#{conversation_id}"

      _ ->
        nil
    end
  end

  def dom_id(%Result{} = result) do
    key =
      case result.source_type do
        :knowledge_base -> result.article_id || result.revision_id || result.id
        :resolved_case -> result.conversation_id || result.id
      end

    "#{result.source_type}-#{key}-#{result.chunk_index || 0}"
  end

  def preview_sections(%Result{} = result) do
    preview_copy(result)
  end

  def diagnostic_reason_label(:assistive_only_results), do: "Only supporting evidence matched"
  def diagnostic_reason_label(:canonical_insufficient_detail), do: "Canonical detail is still missing"
  def diagnostic_reason_label(:clarification_limit_reached), do: "Clarification limit reached"
  def diagnostic_reason_label(:no_canonical_results), do: "No verified guidance matched"
  def diagnostic_reason_label(:provider_timeout), do: "Search timed out"
  def diagnostic_reason_label(:index_unavailable), do: "Search index unavailable"
  def diagnostic_reason_label(:unexpected_error), do: "Search is temporarily unavailable"
  def diagnostic_reason_label(:canonical_results), do: "Canonical guidance matched"
  def diagnostic_reason_label(:mixed_results), do: "Canonical and supporting evidence matched"
  def diagnostic_reason_label(_reason), do: "Grounding needs review"

  def diagnostic_reason_copy(:assistive_only_results) do
    "Only resolved-case evidence matched, so treat this as supporting context rather than verified guidance."
  end

  def diagnostic_reason_copy(:canonical_insufficient_detail) do
    "Knowledge Base guidance is close, but one customer detail is still missing before a safe reply can be grounded."
  end

  def diagnostic_reason_copy(:clarification_limit_reached) do
    "A clarification was already used once and the reply still lacks enough verified detail to stay safely grounded."
  end

  def diagnostic_reason_copy(:no_canonical_results) do
    "No canonical Knowledge Base guidance matched this request, so the system could not ground a reliable answer."
  end

  def diagnostic_reason_copy(:provider_timeout) do
    "Retrieval did not complete in time. Keep working in the conversation, then try again."
  end

  def diagnostic_reason_copy(:index_unavailable) do
    "Retrieval could not reach the search index. Keep working in the conversation, then try again."
  end

  def diagnostic_reason_copy(:unexpected_error) do
    "Retrieval hit a temporary failure. Keep working in the conversation, then try again."
  end

  def diagnostic_reason_copy(:canonical_results) do
    "Canonical Knowledge Base guidance matched this request."
  end

  def diagnostic_reason_copy(:mixed_results) do
    "Canonical Knowledge Base guidance matched, with supporting resolved-case context alongside it."
  end

  def diagnostic_reason_copy(_reason) do
    "Review the evidence before treating this as a routine grounded reply."
  end

  defp destination(%Result{} = result) do
    metadata(result, :destination) ||
      %{
        article_id: result.article_id,
        revision_id: result.revision_id,
        conversation_id: result.conversation_id,
        chunk_index: result.chunk_index
      }
  end

  defp preview_excerpt(%Result{content: content}) when is_binary(content), do: content
  defp preview_excerpt(_result), do: ""

  defp preview_actions(actions_taken) when is_list(actions_taken) and actions_taken != [] do
    "Actions taken: " <> Enum.join(actions_taken, ", ")
  end

  defp preview_actions(_actions_taken), do: nil

  defp preview_block(_label, value) when value in [nil, ""], do: nil
  defp preview_block(label, value), do: "#{label}: #{value}"

  defp metadata(%Result{metadata: metadata}, key) when is_map(metadata),
    do: Map.get(metadata, key)

  defp metadata(_result, _key), do: nil

  defp truncate(value, max_length) when is_binary(value) and byte_size(value) > max_length do
    String.slice(value, 0, max_length - 1) <> "…"
  end

  defp truncate(value, _max_length), do: value

  defp present?(value), do: value not in [nil, ""]

  defp relative_time(nil), do: "recently"

  defp relative_time(%NaiveDateTime{} = datetime) do
    datetime
    |> DateTime.from_naive!("Etc/UTC")
    |> relative_time()
  end

  defp relative_time(%DateTime{} = datetime) do
    seconds = DateTime.diff(DateTime.utc_now(), datetime, :second)
    humanize_duration(max(seconds, 0))
  end

  defp humanize_duration(seconds) when seconds < 60, do: "just now"
  defp humanize_duration(seconds) when seconds < 3_600, do: "#{div(seconds, 60)}m ago"
  defp humanize_duration(seconds) when seconds < 86_400, do: "#{div(seconds, 3_600)}h ago"
  defp humanize_duration(seconds) when seconds < 2_592_000, do: "#{div(seconds, 86_400)}d ago"

  defp humanize_duration(seconds) when seconds < 31_536_000,
    do: "#{div(seconds, 2_592_000)}mo ago"

  defp humanize_duration(seconds), do: "#{div(seconds, 31_536_000)}y ago"
end
