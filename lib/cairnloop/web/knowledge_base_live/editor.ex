defmodule Cairnloop.Web.KnowledgeBaseLive.Editor do
  use Phoenix.LiveView
  import Cairnloop.Web.Components
  import Cairnloop.Web.KnowledgeBaseLive.NavComponent
  alias Cairnloop.KnowledgeBase
  alias Cairnloop.KnowledgeBase.Article
  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.Web.KnowledgeBaseLive.EditorHandoff
  alias Cairnloop.Web.GapCandidatePresenter
  alias Cairnloop.Web.BreadcrumbPresenter
  alias Cairnloop.Web.DashboardPath

  def mount(params, session, socket) do
    try do
      id = (is_map(params) && params["id"]) || session["id"]
      scope_filters = scope_filters(session)
      article = KnowledgeBase.get_article!(id)
      latest_revision = KnowledgeBase.get_latest_revision(id)
      suggestion = load_suggestion(params, scope_filters, article.id)
      :ok = ensure_editor_target_matches!(article, suggestion)
      review_context = load_review_context(params, scope_filters, article, suggestion)
      content = preload_content(suggestion, latest_revision)
      gap_candidate = load_gap_candidate_from_suggestion(suggestion, scope_filters)

      # WR-02: avoid a guaranteed-nil SELECT on every mount. Only :conversation_quick_fix
      # suggestions can ever yield an origin (D-12). When the in-scope suggestion is already
      # loaded we know its entrypoint_type in-process, so short-circuit. The nil-suggestion
      # branch preserves the article-keyed lookup for the direct-visit case (Pitfall 2), so
      # the deep-link still resolves.
      origin_conversation_id =
        case suggestion do
          %{entrypoint_type: :conversation_quick_fix, entrypoint_id: entrypoint_id} ->
            entrypoint_id

          %{} ->
            nil

          nil ->
            knowledge_automation().originating_conversation_id(article.id, scope_filters)
        end

      socket =
        socket
        |> assign(article: article)
        |> assign(revision: latest_revision)
        |> assign(content: content)
        |> assign(preview_html: parse_markdown(content))
        |> assign(review_context: review_context)
        |> assign(review_origin?: review_context.review_task != nil)
        |> assign(gap_candidate: gap_candidate)
        |> assign(origin_conversation_id: origin_conversation_id)
        |> assign(dashboard_path: DashboardPath.from_session(session))

      {:ok, socket}
    rescue
      Ecto.NoResultsError ->
        {:ok,
         socket
         |> put_flash(
           :error,
           "This editor can only be opened from the review queue. Return to Suggestions and use 'Open for manual edit' to begin editing."
         )
         |> push_navigate(
           to:
             DashboardPath.to(DashboardPath.from_session(session), "/knowledge-base/suggestions")
         )}
    end
  end

  def handle_event("change", %{"content" => content}, socket) do
    {:noreply,
     socket
     |> assign(content: content)
     |> assign(preview_html: parse_markdown(content))}
  end

  def handle_event("save_draft", _, socket) do
    case KnowledgeBase.save_draft(socket.assigns.article, %{content: socket.assigns.content}) do
      {:ok, revision} ->
        socket =
          socket
          |> assign(revision: revision)
          |> maybe_mark_review_task_material_edit(revision)
          |> put_flash(:info, draft_saved_message(socket))

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save draft")}
    end
  end

  def handle_event("publish", _, socket) do
    if socket.assigns.review_origin? do
      {:noreply,
       put_flash(
         socket,
         :error,
         "Publish from the review task to preserve the review audit trail."
       )}
    else
      case KnowledgeBase.save_draft(socket.assigns.article, %{content: socket.assigns.content}) do
        {:ok, revision} ->
          case KnowledgeBase.publish_revision(revision) do
            {:ok, published_rev} ->
              {:noreply,
               assign(socket, revision: published_rev)
               |> put_flash(:info, "Published successfully")}

            {:error, _failed_value} ->
              {:noreply, put_flash(socket, :error, "Failed to publish revision")}
          end

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to save draft before publishing")}
      end
    end
  end

  defp parse_markdown(nil), do: ""
  defp parse_markdown(content), do: Cairnloop.Markdown.to_html(content)

  defp preload_content(%{proposed_markdown: proposed_markdown}, _latest_revision),
    do: proposed_markdown

  defp preload_content(_params, latest_revision) do
    if latest_revision, do: latest_revision.content, else: ""
  end

  defp load_suggestion(%{"suggestion_id" => suggestion_id} = params, scope_filters, article_id) do
    :ok = EditorHandoff.verify!(params, article_id)

    suggestion_id
    |> normalize_id()
    |> knowledge_automation().get_article_suggestion!(scope_filters)
  end

  defp load_suggestion(_params, _scope_filters, _article_id), do: nil

  defp load_gap_candidate_from_suggestion(nil, _scope_filters), do: nil

  defp load_gap_candidate_from_suggestion(suggestion, scope_filters) do
    case {suggestion.entrypoint_type, suggestion.entrypoint_id} do
      {:gap_candidate, gid} when is_integer(gid) ->
        knowledge_automation().get_gap_candidate(gid, scope_filters)

      _ ->
        nil
    end
  end

  defp load_review_context(
         %{"review_task_id" => review_task_id} = params,
         scope_filters,
         article,
         suggestion
       ) do
    task =
      review_task_id
      |> normalize_id()
      |> knowledge_automation().get_review_task!(scope_filters)

    if suggestion do
      :ok = EditorHandoff.ensure_review_task_match!(task, suggestion)
    end

    :ok = ensure_review_task_target_matches!(task, article)

    %{
      review_task: task,
      return_to:
        verified_return_to_from_token(params) ||
          "/knowledge-base/suggestions?task=#{task.id}",
      operator_summary: task.article_suggestion && task.article_suggestion.operator_summary,
      evidence_count:
        task.article_suggestion |> Map.get(:evidence_snapshot, []) |> List.wrap() |> length()
    }
  end

  defp load_review_context(_params, _scope_filters, _article, _suggestion) do
    %{
      review_task: nil,
      return_to: nil,
      operator_summary: nil,
      evidence_count: 0
    }
  end

  defp maybe_mark_review_task_material_edit(socket, revision) do
    case socket.assigns.review_context.review_task do
      nil ->
        socket

      review_task ->
        attrs = [
          host_user_id: Map.get(review_task, :host_user_id),
          content: socket.assigns.content,
          saved_revision_id: revision.id
        ]

        case knowledge_automation().mark_review_task_material_edit(review_task.id, attrs) do
          {:ok, updated_task} ->
            assign(socket,
              review_context: %{socket.assigns.review_context | review_task: updated_task}
            )

          {:error, _reason} ->
            socket
        end
    end
  end

  defp draft_saved_message(%{assigns: %{review_origin?: true}}),
    do: "Draft saved. Return to the review task before publishing."

  defp draft_saved_message(_socket), do: "Draft saved"

  defp knowledge_automation do
    Application.get_env(:cairnloop, :knowledge_automation, KnowledgeAutomation)
  end

  defp normalize_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> id
      _ -> value
    end
  end

  defp normalize_id(value), do: value

  defp verified_return_to_from_token(%{"handoff" => token}) do
    case Cairnloop.KnowledgeAutomation.EditorHandoff.decode(token) do
      {:ok, %{"return_to" => rt}} when is_binary(rt) and rt != "" -> rt
      _ -> nil
    end
  end

  defp verified_return_to_from_token(_), do: nil

  defp scope_filters(session) do
    host_user_id = Map.get(session, "host_user_id") || Map.get(session, :host_user_id)

    if host_user_id do
      [tenant_scope: :host_user_scoped, host_user_id: to_string(host_user_id)]
    else
      []
    end
  end

  defp ensure_editor_target_matches!(_article, nil), do: :ok

  defp ensure_editor_target_matches!(article, suggestion) do
    allowed_article_id =
      suggestion.article_id ||
        metadata_value(suggestion.grounding_metadata || %{}, :authoring_article_id)

    if is_nil(allowed_article_id) || allowed_article_id == article.id do
      :ok
    else
      raise Ecto.NoResultsError, queryable: Article
    end
  end

  defp ensure_review_task_target_matches!(%{article_suggestion: suggestion}, article) do
    allowed_article_id =
      suggestion.article_id ||
        metadata_value(suggestion.grounding_metadata || %{}, :authoring_article_id)

    if is_nil(allowed_article_id) || allowed_article_id == article.id do
      :ok
    else
      raise Ecto.NoResultsError, queryable: Article
    end
  end

  defp ensure_review_task_target_matches!(_task, _article), do: :ok

  defp metadata_value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp metadata_value(_, _), do: nil

  def render(assigns) do
    assigns = assign_new(assigns, :dashboard_path, fn -> "" end)

    ~H"""
    <.cl_shell current={:knowledge} destinations={Cairnloop.Web.Nav.destinations(@dashboard_path)}>
      <.cl_page title={"Editing: #{@article.title}"} width="wide">
        <:breadcrumb>
          <.cl_breadcrumb items={BreadcrumbPresenter.editor_items(@origin_conversation_id, @review_context.return_to, @article.title) |> DashboardPath.scope_items(@dashboard_path)} />
        </:breadcrumb>
        <:subnav><.kb_nav current={:editor} dashboard_path={@dashboard_path} /></:subnav>

        <.cl_banner
        :if={@revision && @revision.state == :published}
        variant="info"
        class="cl-mb-7"
      >
        Loaded from the latest published revision. Your edits start a new draft.
      </.cl_banner>

      <.cl_banner :if={@review_origin?} variant="ai" class="cl-mb-7">
        <div class="cl-stack">
          <strong>Review-origin draft</strong>
          <span>{@review_context.operator_summary}</span>
          <span class="cl-text-muted">{@review_context.evidence_count} evidence sources</span>
          <.link navigate={DashboardPath.to(@dashboard_path, @review_context.return_to)}>Return to review task</.link>
          <span class="cl-text-muted">
            Publish stays in the review lane so approval and publish history remain aligned.
          </span>
        </div>
      </.cl_banner>

      <div style="display:grid; grid-template-columns: 1fr 1fr; gap: var(--cl-space-5)">
        <.cl_card>
          <:header>
            <div class="cl-row cl-row--between">
              <h2>Markdown</h2>
              <.cl_chip
                :if={@revision && @revision.state == :published}
                variant="success"
                label="Published"
              />
              <.cl_chip
                :if={!(@revision && @revision.state == :published)}
                variant="neutral"
                label="Draft"
              />
            </div>
          </:header>

          <form phx-change="change" onsubmit="event.preventDefault();">
            <textarea name="content" phx-debounce="300" class="cl-textarea"><%= @content %></textarea>
          </form>

          <div class="cl-row cl-mt-5">
            <.cl_button variant="ghost" phx-click="save_draft">Save Draft</.cl_button>
            <.cl_button :if={!@review_origin?} variant="primary" phx-click="publish">Publish</.cl_button>
          </div>
        </.cl_card>

        <.cl_card>
          <:header><h2>Preview</h2></:header>
          {Phoenix.HTML.raw(@preview_html)}
        </.cl_card>
      </div>

        <.cl_card :if={@gap_candidate} class="cl-mt-5" aria-label="Source gap evidence">
          <:header><h3>Source gap</h3></:header>
          <div class="cl-stack">
            <strong>{@gap_candidate.title}</strong>
            <div class="cl-row">
              <span class="cl-text-muted">{"#{@gap_candidate.evidence_count} evidence"}</span>
              <span class="cl-text-muted">{GapCandidatePresenter.freshness_label(@gap_candidate)}</span>
            </div>
            <h4>Retrieval evidence</h4>
            <p :if={@gap_candidate.evidence_count == 0} class="cl-text-muted">
              No retrieval evidence linked to this gap.
            </p>
          </div>
        </.cl_card>
      </.cl_page>
    </.cl_shell>
    """
  end
end
