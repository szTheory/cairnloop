defmodule Cairnloop.Web.SearchModalComponent do
  use Phoenix.LiveComponent
  alias Phoenix.LiveView.JS

  def mount(socket) do
    {:ok, assign(socket, show: false, query: "", results: [])}
  end

  def render(assigns) do
    ~H"""
    <div phx-window-keydown="toggle_search" phx-target={@myself}>
      <%= if @show do %>
        <div class="search-modal-backdrop" style="position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: rgba(0,0,0,0.5); display: flex; justify-content: center; align-items: flex-start; padding-top: var(--cl-spacing-3xl, 64px); z-index: 50;">
          <div class="search-modal-content" style="background: var(--cl-surface, #fff); padding: var(--cl-spacing-md, 16px); border-radius: 8px; width: 600px; max-width: 90vw; box-shadow: 0 4px 6px rgba(0,0,0,0.1);" phx-click-away="close" phx-target={@myself}>
            <form phx-change="search" phx-submit="search" phx-target={@myself}>
              <input type="text" name="query" value={@query} phx-debounce="300" phx-mounted={JS.focus()} placeholder="Search resolved conversations (cmd+k)..." style="width: 100%; padding: var(--cl-spacing-md, 16px); font-size: 16px; border: 1px solid var(--cl-border, #ccc); border-radius: 4px; outline-color: var(--cl-primary, #A94F30);" />
            </form>
            <div class="search-results" style="margin-top: 16px; max-height: 400px; overflow-y: auto;">
              <%= if Enum.empty?(@results) and @query != "" do %>
                <h3 style="margin-bottom: 8px; font-weight: 600; font-size: 20px;">No results found.</h3>
                <p style="color: var(--cl-text-muted, #666);">Try adjusting your search terms to find relevant history.</p>
              <% else %>
                <ul style="list-style: none; padding: 0; margin: 0;">
                  <%= for result <- @results do %>
                    <li style="padding: 12px; border-bottom: 1px solid var(--cl-border, #eee);">
                      <.link navigate={"/#{result["conversation_id"] || result["id"]}"} style="text-decoration: none; color: var(--cl-text, #333); display: block;" phx-click="close" phx-target={@myself}>
                        <strong><%= result["subject"] || "Conversation ##{result["conversation_id"] || result["id"]}" %></strong>
                        <p style="margin: 5px 0 0; font-size: 0.9em; color: var(--cl-text-muted, #666);"><%= (result["text"] || "") |> String.slice(0..150) %>...</p>
                      </.link>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("toggle_search", %{"key" => key} = params, socket) do
    is_cmd_k = (key == "k" or key == "K") and (params["metaKey"] == true or params["ctrlKey"] == true)
    
    if is_cmd_k do
      {:noreply, assign(socket, show: !socket.assigns.show, query: "", results: [])}
    else
      if key == "Escape" and socket.assigns.show do
        {:noreply, assign(socket, show: false)}
      else
        {:noreply, socket}
      end
    end
  end

  def handle_event("close", _, socket) do
    {:noreply, assign(socket, show: false)}
  end

  def handle_event("search", %{"query" => query}, socket) when byte_size(query) < 3 do
    {:noreply, assign(socket, query: query, results: [])}
  end

  def handle_event("search", %{"query" => query}, socket) do
    api_url = Application.get_env(:cairnloop, :scrypath_api_url, "https://api.scrypath.local/v1/index")
    search_url = String.replace(api_url, "/index", "/search")
    api_key = Application.get_env(:cairnloop, :scrypath_api_key, "dummy")
    
    req_options = Application.get_env(:cairnloop, :scrypath_req_options, [])
    
    req = 
      Req.new(
        url: search_url,
        auth: {:bearer, api_key}
      )
      |> Req.merge(req_options)

    case Req.post(req, json: %{query: query}) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        results = 
          case body do
            %{"results" => results} when is_list(results) -> results
            %{"data" => results} when is_list(results) -> results
            results when is_list(results) -> results
            _ -> []
          end
        {:noreply, assign(socket, query: query, results: results)}
      
      _ ->
        {:noreply, 
          socket
          |> assign(query: query, results: [])
          |> put_flash(:error, "Search service unavailable. Please try again later.")
        }
    end
  end
end
