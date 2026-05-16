defmodule Cairnloop.Web.KnowledgeBaseLive.Index do
  use Phoenix.LiveView
  alias Cairnloop.KnowledgeBase.Article

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def mount(_params, _session, socket) do
    articles = repo().all(Article)
    {:ok, assign(socket, articles: articles)}
  end

  def render(assigns) do
    ~H"""
    <div class="knowledge-base-index">
      <h1>Knowledge Base</h1>
      <ul>
        <%= for article <- @articles do %>
          <li>
            <.link navigate={"/knowledge-base/#{article.id}/edit"}><%= article.title %></.link>
            (<%= article.status %>)
          </li>
        <% end %>
      </ul>
    </div>
    """
  end
end