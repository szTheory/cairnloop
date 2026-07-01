defmodule Cairnloop.Web.KnowledgeBaseLive.Index do
  use Phoenix.LiveView
  import Cairnloop.Web.Components
  import Cairnloop.Web.KnowledgeBaseLive.NavComponent
  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeBase
  alias Cairnloop.Web.DashboardPath

  def mount(_params, session, socket) do
    scope_filters = scope_filters(session)
    articles = KnowledgeBase.list_articles(scope_filters)

    {:ok,
     assign(socket,
       articles: articles,
       scope_filters: scope_filters,
       dashboard_path: DashboardPath.from_session(session)
     )}
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
          {:noreply,
           push_navigate(socket,
             to:
               DashboardPath.to(
                 dashboard_path(socket),
                 "/knowledge-base/suggestions?task=#{task.id}"
               )
           )}
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
        {:noreply,
         push_navigate(socket,
           to: DashboardPath.to(dashboard_path(socket), "/knowledge-base/#{article.id}/edit")
         )}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Unable to create the article right now. Try again.")}
    end
  end

  def render(assigns) do
    assigns = assign_new(assigns, :dashboard_path, fn -> "" end)

    ~H"""
    <.cl_shell current={:knowledge} destinations={Cairnloop.Web.Nav.destinations(@dashboard_path)}>
      <.cl_page title="Knowledge Base" width="wide">
        <:subnav><.kb_nav current={:index} dashboard_path={@dashboard_path} /></:subnav>
        <:actions>
          <.cl_button variant="primary" phx-click="new_article" phx-disable-with="Creating...">
            New article
          </.cl_button>
        </:actions>

        <section class="cl-workflow-band" aria-label="Knowledge workflow">
          <div class="cl-workflow-band__step">
            <span class="cl-workflow-band__index">1</span>
            <div>
              <h3>Find evidence gaps</h3>
              <p>Start from conversations where operators needed better canonical answers.</p>
              <.link navigate={DashboardPath.to(@dashboard_path, "/knowledge-base/gaps")}>
                Review KB gap candidates
              </.link>
            </div>
          </div>
          <div class="cl-workflow-band__step">
            <span class="cl-workflow-band__index">2</span>
            <div>
              <h3>Review suggestions</h3>
              <p>Approve, defer, reject, or edit proposed article changes before publishing.</p>
              <.link navigate={DashboardPath.to(@dashboard_path, "/knowledge-base/suggestions")}>
                Open suggestions
              </.link>
            </div>
          </div>
          <div class="cl-workflow-band__step">
            <span class="cl-workflow-band__index">3</span>
            <div>
              <h3>Publish and reindex</h3>
              <p>Keep the retrieval corpus aligned with reviewed, operator-approved knowledge.</p>
            </div>
          </div>
        </section>

        <.cl_card>
        <:header><h2>Articles</h2></:header>

        <.cl_empty
          :if={@articles == []}
          title="No articles yet"
          icon="book"
        >
          <p class="cl-text-muted">Create the first article to start building your knowledge base.</p>
        </.cl_empty>

        <div :if={@articles != []} class="cl-table-scroll" role="region" tabindex="0" aria-label="Knowledge base articles">
        <table class="cl-table">
          <thead>
            <tr><th>Title</th><th>Status</th><th>Actions</th></tr>
          </thead>
          <tbody>
            <tr :for={article <- @articles}>
              <td>
                <.link navigate={DashboardPath.to(@dashboard_path, "/knowledge-base/#{article.id}/edit")}>{article.title}</.link>
              </td>
              <td>
                <.cl_chip
                  variant={if article.status == :published, do: "success", else: "neutral"}
                  label={to_string(article.status)}
                />
              </td>
              <td>
                <.cl_button
                  variant="ghost"
                  size="sm"
                  phx-click="suggest_revision"
                  phx-value-article_id={article.id}
                >
                  Suggest revision
                </.cl_button>
              </td>
            </tr>
          </tbody>
        </table>
        </div>
        </.cl_card>
      </.cl_page>
    </.cl_shell>
    """
  end

  defp knowledge_automation do
    Application.get_env(:cairnloop, :knowledge_automation, KnowledgeAutomation)
  end

  defp dashboard_path(socket), do: Map.get(socket.assigns, :dashboard_path, "")

  defp scope_filters(session) do
    host_user_id = Map.get(session, "host_user_id") || Map.get(session, :host_user_id)

    if host_user_id do
      [tenant_scope: :host_user_scoped, host_user_id: to_string(host_user_id)]
    else
      []
    end
  end
end
