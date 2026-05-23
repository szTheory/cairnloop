defmodule Cairnloop.Web.KnowledgeBaseLive.Editor do
  use Phoenix.LiveView
  alias Cairnloop.KnowledgeBase
  alias Cairnloop.KnowledgeBase.Article
  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.Web.KnowledgeBaseLive.EditorHandoff

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def mount(params, session, socket) do
    id = (is_map(params) && params["id"]) || session["id"]
    scope_filters = scope_filters(session)
    article = repo().get!(Article, id)
    latest_revision = KnowledgeBase.get_latest_revision(id)
    suggestion = load_suggestion(params, scope_filters, article.id)
    :ok = ensure_editor_target_matches!(article, suggestion)
    review_context = load_review_context(params, scope_filters, article, suggestion)
    content = preload_content(suggestion, latest_revision)

    socket = socket
             |> assign(article: article)
             |> assign(revision: latest_revision)
             |> assign(content: content)
             |> assign(preview_html: parse_markdown(content))
             |> assign(review_context: review_context)
             |> assign(review_origin?: review_context.review_task != nil)

    {:ok, socket}
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
               assign(socket, revision: published_rev) |> put_flash(:info, "Published successfully")}

            {:error, _failed_value} ->
              {:noreply, put_flash(socket, :error, "Failed to publish revision")}
          end

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to save draft before publishing")}
      end
    end
  end

  defp parse_markdown(nil), do: ""
  defp parse_markdown(content), do: Earmark.as_html!(content)

  defp preload_content(%{proposed_markdown: proposed_markdown}, _latest_revision), do: proposed_markdown

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

  defp load_review_context(%{"review_task_id" => review_task_id} = params, scope_filters, article, suggestion) do
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
      return_to: Map.get(params, "return_to", "/knowledge-base/suggestions?task=#{task.id}"),
      operator_summary: task.article_suggestion && task.article_suggestion.operator_summary,
      evidence_count: task.article_suggestion |> Map.get(:evidence_snapshot, []) |> List.wrap() |> length()
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
            assign(socket, review_context: %{socket.assigns.review_context | review_task: updated_task})

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
      {id, _} -> id
      _ -> value
    end
  end

  defp normalize_id(value), do: value

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
    ~H"""
    <div class="knowledge-base-editor">
      <.link navigate="/knowledge-base">Back to Index</.link>
      <h2>Editing: <%= @article.title %></h2>
      <%= if @revision && @revision.state == :published do %>
        <p>Loaded from the latest published revision.</p>
      <% end %>
      
      <div class="editor-layout" style="display: flex; gap: 32px;">
        <div class="editor-pane" style="flex: 1;">
          <%= if @review_origin? do %>
            <aside class="review-context" style="margin-bottom: 16px; padding: 16px; border: 1px solid #e5e7eb; border-radius: 8px; background: #f8fafc;">
              <p><strong>Review-origin draft</strong></p>
              <p><%= @review_context.operator_summary %></p>
              <p><%= @review_context.evidence_count %> evidence sources</p>
              <.link navigate={@review_context.return_to}>Return to review task</.link>
              <p>Publish stays in the review lane so approval and publish history remain aligned.</p>
            </aside>
          <% end %>

          <form phx-change="change" onsubmit="event.preventDefault();">
            <textarea name="content" phx-debounce="300" style="width: 100%; min-height: 500px;"><%= @content %></textarea>
          </form>
          <div class="actions" style="margin-top: 16px;">
            <button phx-click="save_draft">Save Draft</button>
            <%= unless @review_origin? do %>
              <button phx-click="publish">Publish</button>
            <% end %>
          </div>
        </div>
        
        <div class="preview-pane" style="flex: 1; padding: 24px; border: 1px solid #e5e7eb; border-radius: 8px; background: #fff;">
          <%= Phoenix.HTML.raw(@preview_html) %>
        </div>
      </div>
    </div>
    """
  end
end
