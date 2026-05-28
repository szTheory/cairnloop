defmodule Cairnloop.Web.KnowledgeBaseLive.Index do
  use Phoenix.LiveView
  import Cairnloop.Web.KnowledgeBaseLive.NavComponent
  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeBase

  def mount(_params, session, socket) do
    articles = KnowledgeBase.list_articles(scope_filters(session))
    {:ok, assign(socket, articles: articles, scope_filters: scope_filters(session))}
  end

  def handle_event("suggest_revision", %{"article_id" => article_id}, socket) do
    attrs = %{
      article_id: String.to_integer(article_id),
      tenant_scope: Keyword.get(socket.assigns.scope_filters, :tenant_scope, :system_unscoped),
      host_user_id: Keyword.get(socket.assigns.scope_filters, :host_user_id)
    }

    case knowledge_automation().suggest_revision(attrs) do
      {:ok, suggestion} ->
        with {:ok, task} <-
               knowledge_automation().ensure_review_task_for_suggestion(
                 suggestion.id,
                 socket.assigns.scope_filters
               ) do
          {:noreply, push_navigate(socket, to: "/knowledge-base/suggestions?task=#{task.id}")}
        else
          _ ->
            {:noreply,
             put_flash(socket, :error, "Unable to open the shared review task right now.")}
        end

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "Unable to create the revision suggestion right now.")}
    end
  end

  def handle_event("new_article", _params, socket) do
    case KnowledgeBase.create_article(%{title: "Untitled article", status: :draft}) do
      {:ok, article} ->
        {:noreply, push_navigate(socket, to: "/knowledge-base/#{article.id}/edit")}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Unable to create the article right now. Try again.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="knowledge-base-index">
      <.kb_nav current={:index} />
      <div style="display: flex; align-items: center; justify-content: space-between; padding: 24px 24px 0;">
        <h1>Knowledge Base</h1>
        <button
          phx-click="new_article"
          phx-disable-with="Creating..."
          style="background: var(--cl-primary); color: var(--cl-primary-text); border: none; border-radius: var(--cl-radius-sm); padding: 8px 16px; min-height: 44px; font-size: 13px; font-weight: 600; cursor: pointer; letter-spacing: 0.015em;"
        >
          New article
        </button>
      </div>
      <p style="padding: 0 24px;">
        <.link navigate="/knowledge-base/gaps">Review KB gap candidates</.link>
      </p>
      <%= if @articles == [] do %>
        <div style="padding: 24px; text-align: center;">
          <p>No articles yet.</p>
          <p>Create the first article to start building your knowledge base.</p>
        </div>
      <% else %>
        <ul style="padding: 0 24px;">
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
      <% end %>
    </div>
    """
  end

  defp knowledge_automation do
    Application.get_env(:cairnloop, :knowledge_automation, KnowledgeAutomation)
  end

  defp scope_filters(session) do
    host_user_id = Map.get(session, "host_user_id") || Map.get(session, :host_user_id)

    if host_user_id do
      [tenant_scope: :host_user_scoped, host_user_id: to_string(host_user_id)]
    else
      []
    end
  end
end
