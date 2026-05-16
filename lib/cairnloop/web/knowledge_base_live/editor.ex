defmodule Cairnloop.Web.KnowledgeBaseLive.Editor do
  use Phoenix.LiveView
  alias Cairnloop.KnowledgeBase
  alias Cairnloop.KnowledgeBase.Article

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def mount(params, session, socket) do
    id = (is_map(params) && params["id"]) || session["id"]
    article = repo().get!(Article, id)
    latest_revision = KnowledgeBase.get_latest_revision(id)
    content = if latest_revision, do: latest_revision.content, else: ""

    socket = socket
             |> assign(article: article)
             |> assign(revision: latest_revision)
             |> assign(content: content)
             |> assign(preview_html: parse_markdown(content))

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
        {:noreply, assign(socket, revision: revision) |> put_flash(:info, "Draft saved")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save draft")}
    end
  end

  def handle_event("publish", _, socket) do
    case KnowledgeBase.save_draft(socket.assigns.article, %{content: socket.assigns.content}) do
      {:ok, revision} ->
        case KnowledgeBase.publish_revision(revision) do
          {:ok, published_rev} ->
            {:noreply, assign(socket, revision: published_rev) |> put_flash(:info, "Published successfully")}
          {:error, _failed_value} ->
            {:noreply, put_flash(socket, :error, "Failed to publish revision")}
        end
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save draft before publishing")}
    end
  end

  defp parse_markdown(nil), do: ""
  defp parse_markdown(content), do: Earmark.as_html!(content)

  def render(assigns) do
    ~H"""
    <div class="knowledge-base-editor">
      <.link navigate="/knowledge-base">Back to Index</.link>
      <h2>Editing: <%= @article.title %></h2>
      
      <div class="editor-layout" style="display: flex; gap: 32px;">
        <div class="editor-pane" style="flex: 1;">
          <form phx-change="change" onsubmit="event.preventDefault();">
            <textarea name="content" phx-debounce="300" style="width: 100%; min-height: 500px;"><%= @content %></textarea>
          </form>
          <div class="actions" style="margin-top: 16px;">
            <button phx-click="save_draft">Save Draft</button>
            <button phx-click="publish">Publish</button>
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