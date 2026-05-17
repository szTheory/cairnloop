defmodule Cairnloop.Web.SearchModalComponent do
  use Phoenix.LiveComponent

  alias Cairnloop.Web.SearchResultPresenter
  alias Phoenix.LiveView.JS

  @section_order [:knowledge_base, :resolved_case]

  def mount(socket) do
    {:ok, assign_defaults(socket)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign_defaults()
      |> assign(assigns)
      |> assign(
        :retrieval_module,
        Map.get(assigns, :retrieval_module, socket.assigns.retrieval_module)
      )
      |> ensure_preview_state()

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div phx-window-keydown="toggle_search" phx-target={@myself}>
      <%= if @open do %>
        <div
          class="search-modal-backdrop"
          style="position: fixed; inset: 0; background: rgba(44, 38, 31, 0.42); display: flex; justify-content: center; align-items: flex-start; padding: 24px 16px; z-index: 50;"
        >
          <div
            class="search-modal-content"
            style="background: var(--cl-surface, #FBF7EE); color: var(--cl-text, #2f241d); border-radius: 18px; width: min(1040px, 92vw); min-height: 560px; max-height: 78vh; box-shadow: 0 24px 60px rgba(47, 36, 29, 0.18); overflow: hidden; display: flex; flex-direction: column;"
            phx-click-away="close"
            phx-target={@myself}
          >
            <form phx-change="search" phx-submit="search" phx-target={@myself} style="padding: 24px 24px 16px; border-bottom: 1px solid rgba(64, 51, 43, 0.08);">
              <input
                id={"#{@id}-search-input"}
                type="text"
                name="query"
                value={@query}
                phx-debounce="250"
                phx-mounted={JS.focus()}
                placeholder="Search knowledge and resolved cases"
                role="combobox"
                aria-expanded="true"
                aria-controls={"#{@id}-search-results"}
                aria-activedescendant={@active_dom_id}
                style="width: 100%; padding: 16px; font-size: 16px; line-height: 1.5; border: 1px solid rgba(64, 51, 43, 0.12); border-radius: 12px; outline-color: var(--cl-primary, #A94F30); background: #fffdfa;"
              />
            </form>

            <div class="search-modal-body" style="display: flex; flex: 1; gap: 32px; padding: 24px; overflow: hidden; flex-wrap: wrap;">
              <div class="search-results-pane" style="flex: 1 1 432px; min-width: min(432px, 100%); display: flex; flex-direction: column; overflow: hidden;">
                <%= if @error do %>
                  <div style="margin-bottom: 16px; padding: 16px; border-radius: 12px; background: rgba(181, 76, 54, 0.08); color: var(--cl-danger, #B54C36);">
                    Search is unavailable right now. Keep working in the current conversation, then try the search again.
                  </div>
                <% end %>

                <div
                  id={"#{@id}-search-results"}
                  role="listbox"
                  aria-label="Search results"
                  style="overflow-y: auto; padding-right: 8px;"
                >
                  <%= for section <- @sections do %>
                    <section style="margin-bottom: 24px;">
                      <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px;">
                        <h3 style="margin: 0; font-size: 20px; line-height: 1.3; font-weight: 600;">
                          <%= section.title %>
                        </h3>
                        <span style="font-size: 14px; color: rgba(47, 36, 29, 0.62);">
                          <%= length(section.results) %>
                        </span>
                      </div>

                      <%= if Enum.empty?(section.results) do %>
                        <div style="padding: 16px; border-radius: 12px; background: rgba(255, 255, 255, 0.72); color: rgba(47, 36, 29, 0.68);">
                          <%= empty_section_copy(section.source_type, @query) %>
                        </div>
                      <% else %>
                        <ul style="list-style: none; padding: 0; margin: 0; display: grid; gap: 12px;">
                          <%= for result <- section.results do %>
                            <% presenter = present(result) %>
                            <% active? = presenter.dom_id == @active_dom_id %>
                            <li id={presenter.dom_id} role="option" aria-selected={active?}>
                              <button
                                type="button"
                                phx-click="activate_result"
                                phx-value-dom_id={presenter.dom_id}
                                phx-target={@myself}
                                style={result_row_style(active?)}
                              >
                                <div style="display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 8px;">
                                  <span style={source_badge_style(result.source_type)}>
                                    <%= presenter.source_label %>
                                  </span>
                                  <span style={trust_badge_style(result.trust_level)}>
                                    <%= presenter.trust_label %>
                                  </span>
                                </div>
                                <div style="display: flex; align-items: flex-start; justify-content: space-between; gap: 16px;">
                                  <div>
                                    <p style="margin: 0 0 8px; font-size: 16px; line-height: 1.4; font-weight: 600;">
                                      <%= presenter.title %>
                                    </p>
                                    <p style="margin: 0; font-size: 14px; line-height: 1.5; color: rgba(47, 36, 29, 0.76);">
                                      <%= presenter.row_snippet %>
                                    </p>
                                  </div>
                                  <span style="font-size: 14px; color: rgba(47, 36, 29, 0.62); white-space: nowrap;">
                                    <%= presenter.recency_label %>
                                  </span>
                                </div>
                                <div style="margin-top: 12px; font-size: 14px; color: var(--cl-primary, #A94F30); font-weight: 600;">
                                  <%= presenter.open_action_label %>
                                </div>
                              </button>
                            </li>
                          <% end %>
                        </ul>
                      <% end %>
                    </section>
                  <% end %>
                </div>
              </div>

              <div class="search-preview-pane" style="flex: 1 1 480px; min-width: min(420px, 100%); border-radius: 16px; background: rgba(255, 255, 255, 0.76); border: 1px solid rgba(64, 51, 43, 0.08); padding: 24px; overflow-y: auto;">
                <%= if @preview do %>
                  <div style="display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 12px;">
                    <span style={source_badge_style(@preview.result.source_type)}>
                      <%= @preview.source_label %>
                    </span>
                    <span style={trust_badge_style(@preview.result.trust_level)}>
                      <%= @preview.trust_label %>
                    </span>
                  </div>
                  <h3 style="margin: 0 0 8px; font-size: 28px; line-height: 1.2; font-weight: 600;">
                    <%= @preview.title %>
                  </h3>
                  <p style="margin: 0 0 24px; font-size: 14px; color: rgba(47, 36, 29, 0.62);">
                    <%= @preview.recency_label %>
                  </p>

                  <div style="display: grid; gap: 16px;">
                    <%= for block <- @preview.preview_sections do %>
                      <p style="margin: 0; font-size: 16px; line-height: 1.5; color: rgba(47, 36, 29, 0.84);">
                        <%= block %>
                      </p>
                    <% end %>
                  </div>

                  <div style="margin-top: 24px;">
                    <%= if @preview.open_path do %>
                      <.link
                        navigate={@preview.open_path}
                        phx-click="close"
                        phx-target={@myself}
                        style="display: inline-flex; align-items: center; justify-content: center; min-height: 44px; padding: 0 16px; border-radius: 999px; text-decoration: none; background: var(--cl-primary, #A94F30); color: white; font-weight: 600;"
                      >
                        <%= @preview.open_action_label %>
                      </.link>
                    <% else %>
                      <span style="display: inline-flex; min-height: 44px; align-items: center; color: rgba(47, 36, 29, 0.62);">
                        <%= @preview.open_action_label %>
                      </span>
                    <% end %>
                  </div>
                <% else %>
                  <h3 style="margin: 0 0 8px; font-size: 28px; line-height: 1.2; font-weight: 600;">
                    Preview results here
                  </h3>
                  <p style="margin: 0; font-size: 16px; line-height: 1.5; color: rgba(47, 36, 29, 0.76);">
                    Move through results to inspect source details before you open anything.
                  </p>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("toggle_search", %{"key" => key} = params, socket) do
    cond do
      toggle_shortcut?(key, params) ->
        {:noreply, toggle_palette(socket)}

      key == "Escape" and socket.assigns.open and socket.assigns.query != "" ->
        {:noreply, clear_query(socket)}

      key == "Escape" and socket.assigns.open ->
        {:noreply, close_palette(socket)}

      true ->
        {:noreply, socket}
    end
  end

  def handle_event("close", _, socket) do
    {:noreply, close_palette(socket)}
  end

  def handle_event("activate_result", %{"dom_id" => dom_id}, socket) do
    {:noreply, set_active_result(socket, dom_id)}
  end

  def handle_event("search", %{"query" => query}, socket) when byte_size(query) < 2 do
    {:noreply,
     socket
     |> assign(query: query, loading: false, error: nil)
     |> clear_results()}
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket = assign(socket, query: query, loading: true, error: nil)

    case run_search(socket.assigns.retrieval_module, query) do
      {:ok, results} ->
        {:noreply,
         socket
         |> assign(loading: false)
         |> assign_results(results)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(loading: false, error: true)
         |> clear_results()}
    end
  end

  defp assign_defaults(socket) do
    socket
    |> assign(
      open: false,
      query: "",
      loading: false,
      error: nil,
      active_dom_id: nil,
      sections: build_sections([]),
      preview: nil,
      retrieval_module: Cairnloop.Retrieval
    )
  end

  defp toggle_palette(socket) do
    if socket.assigns.open do
      close_palette(socket)
    else
      assign(socket, open: true, query: "", loading: false, error: nil)
      |> clear_results()
    end
  end

  defp close_palette(socket) do
    socket
    |> assign(open: false, loading: false, error: nil)
    |> clear_query()
  end

  defp clear_query(socket) do
    socket
    |> assign(query: "")
    |> clear_results()
  end

  defp clear_results(socket) do
    socket
    |> assign(sections: build_sections([]), active_dom_id: nil, preview: nil)
  end

  defp assign_results(socket, results) do
    active_dom_id =
      results
      |> List.first()
      |> case do
        nil -> nil
        result -> SearchResultPresenter.dom_id(result)
      end

    socket
    |> assign(sections: build_sections(results), active_dom_id: active_dom_id)
    |> ensure_preview_state()
  end

  defp ensure_preview_state(socket) do
    preview =
      socket.assigns.sections
      |> all_results()
      |> Enum.find(&(SearchResultPresenter.dom_id(&1) == socket.assigns.active_dom_id))
      |> case do
        nil -> nil
        result -> present(result)
      end

    assign(socket, :preview, preview)
  end

  defp set_active_result(socket, dom_id) do
    socket
    |> assign(:active_dom_id, dom_id)
    |> ensure_preview_state()
  end

  defp build_sections(results) do
    Enum.map(@section_order, fn source_type ->
      %{
        source_type: source_type,
        title: section_title(source_type),
        results: Enum.filter(results, &(&1.source_type == source_type))
      }
    end)
  end

  defp all_results(sections) do
    Enum.flat_map(sections, & &1.results)
  end

  defp section_title(:knowledge_base), do: "Knowledge Base"
  defp section_title(:resolved_case), do: "Similar resolved cases"

  defp empty_section_copy(_source_type, query) when byte_size(query) < 2 do
    "Type at least 2 characters to search the Knowledge Base first, then similar resolved cases for supporting evidence."
  end

  defp empty_section_copy(:knowledge_base, _query),
    do: "No knowledge base matches for this query."

  defp empty_section_copy(:resolved_case, _query), do: "No similar resolved cases for this query."

  defp present(result) do
    %{
      result: result,
      dom_id: SearchResultPresenter.dom_id(result),
      title: SearchResultPresenter.title(result),
      source_label: SearchResultPresenter.source_label(result),
      trust_label: SearchResultPresenter.trust_label(result),
      row_snippet: SearchResultPresenter.row_snippet(result),
      recency_label: SearchResultPresenter.recency_label(result),
      preview_sections: SearchResultPresenter.preview_sections(result),
      open_action_label: SearchResultPresenter.open_action_label(result),
      open_path: SearchResultPresenter.open_path(result)
    }
  end

  defp run_search(Cairnloop.Retrieval, query), do: {:ok, Cairnloop.Retrieval.search(query, [])}

  defp run_search(retrieval_module, query) do
    try do
      case retrieval_module.search(query, []) do
        results when is_list(results) -> {:ok, results}
        {:error, reason} -> {:error, reason}
        _ -> {:ok, []}
      end
    rescue
      error -> {:error, error}
    end
  end

  defp toggle_shortcut?(key, params) do
    ((key == "k" or key == "K") and truthy?(params["metaKey"])) or
      (truthy?(params["ctrlKey"]) and (key == "k" or key == "K"))
  end

  defp truthy?(value), do: value in [true, "true"]

  defp result_row_style(true) do
    "width: 100%; text-align: left; padding: 16px; border-radius: 16px; border: 1px solid rgba(169, 79, 48, 0.22); background: rgba(169, 79, 48, 0.08); cursor: pointer;"
  end

  defp result_row_style(false) do
    "width: 100%; text-align: left; padding: 16px; border-radius: 16px; border: 1px solid rgba(64, 51, 43, 0.08); background: rgba(255, 255, 255, 0.9); cursor: pointer;"
  end

  defp source_badge_style(:knowledge_base) do
    "display: inline-flex; align-items: center; min-height: 28px; padding: 0 10px; border-radius: 999px; background: rgba(74, 98, 56, 0.12); color: #4A6238; font-size: 14px; font-weight: 600;"
  end

  defp source_badge_style(:resolved_case) do
    "display: inline-flex; align-items: center; min-height: 28px; padding: 0 10px; border-radius: 999px; background: rgba(63, 111, 128, 0.12); color: #3F6F80; font-size: 14px; font-weight: 600;"
  end

  defp trust_badge_style(:canonical) do
    "display: inline-flex; align-items: center; min-height: 28px; padding: 0 10px; border-radius: 999px; background: rgba(74, 98, 56, 0.08); color: rgba(47, 36, 29, 0.82); font-size: 14px; font-weight: 600;"
  end

  defp trust_badge_style(:assistive) do
    "display: inline-flex; align-items: center; min-height: 28px; padding: 0 10px; border-radius: 999px; background: rgba(63, 111, 128, 0.08); color: rgba(47, 36, 29, 0.82); font-size: 14px; font-weight: 600;"
  end
end
