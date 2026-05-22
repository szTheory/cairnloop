defmodule Cairnloop.Web.KnowledgeBaseLive.Editor do
  use Phoenix.LiveView
  alias Cairnloop.KnowledgeBase
  alias Cairnloop.KnowledgeBase.Article
  alias Cairnloop.KnowledgeAutomation

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def mount(params, session, socket) do
    id = (is_map(params) && params["id"]) || session["id"]
    article = repo().get!(Article, id)
    latest_revision = KnowledgeBase.get_latest_revision(id)
    content = preload_content(params, latest_revision)
    review_context = load_review_context(params)

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

  defp preload_content(%{"suggestion_id" => suggestion_id}, _latest_revision) do
    suggestion =
      suggestion_id
      |> normalize_id()
      |> knowledge_automation().get_article_suggestion!()

    suggestion.proposed_markdown
  end

  defp preload_content(_params, latest_revision) do
    if latest_revision, do: latest_revision.content, else: ""
  end

  defp load_review_context(%{"review_task_id" => review_task_id} = params) do
    task =
      review_task_id
      |> normalize_id()
      |> knowledge_automation().get_review_task!()

    %{
      review_task: task,
      return_to: Map.get(params, "return_to", "/knowledge-base/suggestions?task=#{task.id}"),
      operator_summary: task.article_suggestion && task.article_suggestion.operator_summary,
      evidence_count: task.article_suggestion |> Map.get(:evidence_snapshot, []) |> List.wrap() |> length()
    }
  end

  defp load_review_context(_params) do
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
        attrs = %{
          host_user_id: Map.get(review_task, :host_user_id),
          content: socket.assigns.content,
          saved_revision_id: Map.get(review_task, :staged_revision_id) || revision.id
        }

        case knowledge_automation().mark_review_task_material_edit(review_task.id, attrs, []) do
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
