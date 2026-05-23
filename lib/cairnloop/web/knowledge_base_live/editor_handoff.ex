defmodule Cairnloop.Web.KnowledgeBaseLive.EditorHandoff do
  @moduledoc false

  alias Cairnloop.KnowledgeAutomation.EditorHandoff, as: Token
  alias Cairnloop.KnowledgeAutomation.ReviewTask
  alias Cairnloop.KnowledgeBase.Article

  def sign(suggestion_id, article_id, review_task_id, return_to) do
    Token.sign(%{
      suggestion_id: suggestion_id,
      article_id: article_id,
      review_task_id: review_task_id,
      return_to: return_to
    })
  end

  def verify!(params, article_id) do
    attrs = %{
      suggestion_id: Map.get(params, "suggestion_id"),
      article_id: article_id,
      review_task_id: Map.get(params, "review_task_id"),
      return_to: Map.get(params, "return_to")
    }

    case Token.verify(Map.get(params, "handoff"), attrs) do
      :ok -> :ok
      _ -> raise Ecto.NoResultsError, queryable: Article
    end
  end

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
