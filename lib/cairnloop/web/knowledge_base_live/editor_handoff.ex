defmodule Cairnloop.Web.KnowledgeBaseLive.EditorHandoff do
  @moduledoc false

  alias Cairnloop.KnowledgeAutomation.EditorHandoff, as: Token
  alias Cairnloop.KnowledgeAutomation.ReviewTask
  alias Cairnloop.KnowledgeBase.Article

  def sign(suggestion_id, article_id, review_task_id, return_to, opts \\ []) do
    Token.sign(%{
      suggestion_id: suggestion_id,
      article_id: article_id,
      review_task_id: review_task_id,
      return_to: return_to,
      manual_edit_opened_at: Keyword.get(opts, :manual_edit_opened_at)
    })
  end

  def verify!(params, article_id) do
    expected = normalized_attrs(params, article_id)

    with {:ok, payload} <- Token.decode(Map.get(params, "handoff")),
         :ok <- assert_handoff_marker(payload),
         true <- non_marker_attrs(payload) == expected do
      :ok
    else
      _ -> raise Ecto.NoResultsError, queryable: Article
    end
  end

  defp assert_handoff_marker(%{"manual_edit_opened_at" => v}) when is_binary(v) and v != "",
    do: :ok

  defp assert_handoff_marker(_), do: {:error, :missing_handoff_marker}

  defp non_marker_attrs(map) do
    Map.take(map, ["suggestion_id", "article_id", "review_task_id", "return_to"])
  end

  defp normalized_attrs(params, article_id) do
    %{
      "suggestion_id" => normalize_integer(Map.get(params, "suggestion_id")),
      "article_id" => article_id,
      "review_task_id" => normalize_integer(Map.get(params, "review_task_id")),
      "return_to" => Map.get(params, "return_to")
    }
  end

  defp normalize_integer(nil), do: nil
  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> id
      _ -> value
    end
  end

  defp normalize_integer(value), do: value

  def ensure_review_task_match!(task, suggestion) do
    task_suggestion_id =
      Map.get(task, :article_suggestion_id) ||
        case Map.get(task, :article_suggestion) do
          %{id: id} -> id
          _ -> nil
        end

    if task_suggestion_id == suggestion.id do
      :ok
    else
      raise Ecto.NoResultsError, queryable: ReviewTask
    end
  end
end
