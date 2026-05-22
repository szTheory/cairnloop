defmodule Cairnloop.Web.KnowledgeBaseLive.Index do
  use Phoenix.LiveView
  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeBase.Article

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def mount(_params, _session, socket) do
    articles = repo().all(Article)
    {:ok, assign(socket, articles: articles)}
  end

  def handle_event("suggest_revision", %{"article_id" => article_id}, socket) do
    case knowledge_automation().suggest_revision(%{article_id: String.to_integer(article_id)}) do
      {:ok, suggestion} ->
        with {:ok, task} <- knowledge_automation().ensure_review_task_for_suggestion(suggestion.id) do
          {:noreply, push_navigate(socket, to: "/knowledge-base/suggestions?task=#{task.id}")}
        else
          _ ->
            {:noreply, put_flash(socket, :error, "Unable to open the shared review task right now.")}
        end

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to create the revision suggestion right now.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="knowledge-base-index">
      <h1>Knowledge Base</h1>
      <p>
        <.link navigate="/knowledge-base/gaps">Review KB gap candidates</.link>
      </p>
      <ul>
        <%= for article <- @articles do %>
          <li>
            <.link navigate={"/knowledge-base/#{article.id}/edit"}><%= article.title %></.link>
            (<%= article.status %>)
            <button phx-click="suggest_revision" phx-value-article_id={article.id}>
              Suggest revision
            </button>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  defp knowledge_automation do
    Application.get_env(:cairnloop, :knowledge_automation, KnowledgeAutomation)
  end
end
