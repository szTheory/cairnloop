defmodule Cairnloop.Web.SearchModalComponent do
  use Phoenix.LiveComponent

  alias Cairnloop.Retrieval.GapRecorder
  alias Cairnloop.Retrieval.Telemetry
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
      |> assign(
        :gap_recorder,
        Map.get(assigns, :gap_recorder, socket.assigns.gap_recorder)
      )
      |> ensure_preview_state()

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div
      id={"#{@id}-search-root"}
      data-host-surface={@host_surface}
      data-host-user-id={@host_user_id}
      data-current-path={@current_path}
      data-preserve-reply-form={to_string(@preserve_reply_form)}
      phx-window-keydown="toggle_search"
      phx-key="k"
      phx-target={@myself}
    >
      <%= if @open do %>
        <div
          class="cl-overlay cl-modal-backdrop"
          phx-window-keydown="handle_palette_key"
          phx-target={@myself}
        >
          <div
            class="cl-modal-dialog cl-modal" style="width: min(1040px, 92vw);"
            phx-click-away="close"
            phx-target={@myself}
          >
            <form phx-change="search" phx-submit="search" phx-target={@myself} style="padding: 24px 24px 16px; border-bottom: 1px solid var(--cl-border);">
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
                class="cl-input"
              />
            </form>

            <div class="search-modal-body" style="display: flex; flex: 1; gap: 32px; padding: 24px; overflow: hidden; flex-wrap: wrap;">
              <div class="search-results-pane" style="flex: 1 1 432px; min-width: min(432px, 100%); display: flex; flex-direction: column; overflow: hidden;">
                <%= if @error do %>
                  <div class="cl-banner cl-banner-danger">
                    Search is unavailable right now. Keep working in the current conversation, then try the search again.
                  </div>
                <% end %>

                <%= if @search_state == :scoped_unavailable do %>
                  <div class="cl-banner cl-banner-warning">
                    Scoped search is unavailable on this surface until the dashboard session provides `host_user_id`.
                  </div>
                <% end %>

                <%= if @search_state == :no_hit do %>
                  <div class="cl-banner cl-banner-info">
                    No verified guidance matched this search yet. Try different wording, or continue in the conversation with manual review.
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
                        <span class="cl-text-muted" style="font-size: 14px;">
                          <%= length(section.results) %>
                        </span>
                      </div>

                      <%= if Enum.empty?(section.results) do %>
                        <div class="cl-text-muted" style="padding: 16px; border-radius: 12px; background: var(--cl-surface-raised);">
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
                                phx-mouseenter="activate_result"
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
                                    <p class="cl-text-muted" style="margin: 0; font-size: 14px; line-height: 1.5;">
                                      <%= presenter.row_snippet %>
                                    </p>
                                  </div>
                                  <span class="cl-text-muted" style="font-size: 14px; white-space: nowrap;">
                                    <%= presenter.recency_label %>
                                  </span>
                                </div>
                                <div style="margin-top: 12px; font-size: 14px; color: var(--cl-primary); font-weight: 600;">
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

              <div class="search-preview-pane" style="flex: 1 1 480px; min-width: min(420px, 100%); border-radius: 16px; background: var(--cl-surface-raised); border: 1px solid var(--cl-border); padding: 24px; overflow-y: auto;">
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
                  <p class="cl-text-muted" style="margin: 0 0 24px; font-size: 14px;">
                    <%= @preview.recency_label %>
                  </p>

                  <div style="display: grid; gap: 16px;">
                    <%= for block <- @preview.preview_sections do %>
                      <p style="margin: 0; font-size: 16px; line-height: 1.5; color: var(--cl-text);">
                        <%= block %>
                      </p>
                    <% end %>
                  </div>

                  <div style="margin-top: 24px;">
                    <%= if @preview.open_path do %>
                      <button
                        type="button"
                        phx-click="open_active_result"
                        phx-target={@myself}
                        style="display: inline-flex; align-items: center; justify-content: center; min-height: 44px; padding: 0 16px; border-radius: 999px; text-decoration: none; background: var(--cl-primary); color: white; font-weight: 600;"
                      >
                        <%= @preview.open_action_label %>
                      </button>
                    <% else %>
                      <span class="cl-text-muted" style="display: inline-flex; min-height: 44px; align-items: center;">
                        <%= @preview.open_action_label %>
                      </span>
                    <% end %>
                  </div>
                <% else %>
                  <h3 style="margin: 0 0 8px; font-size: 28px; line-height: 1.2; font-weight: 600;">
                    Preview results here
                  </h3>
                  <p class="cl-text-muted" style="margin: 0; font-size: 16px; line-height: 1.5;">
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

  def handle_event("handle_palette_key", %{"key" => key} = params, socket) do
    cond do
      not socket.assigns.open ->
        {:noreply, socket}

      key == "ArrowDown" ->
        {:noreply, move_active_result(socket, 1)}

      key == "ArrowUp" ->
        {:noreply, move_active_result(socket, -1)}

      key == "Enter" ->
        {:noreply, open_active_result(socket, new_tab?: new_tab_shortcut?(params))}

      key == "Escape" and socket.assigns.query != "" ->
        {:noreply, clear_query(socket)}

      key == "Escape" ->
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

  def handle_event("open_active_result", params, socket) do
    {:noreply, open_active_result(socket, new_tab?: truthy?(params["new_tab"]))}
  end

  def handle_event("open_result", %{"dom_id" => dom_id} = params, socket) do
    socket =
      socket
      |> set_active_result(dom_id)
      |> open_result(dom_id, new_tab?: truthy?(params["new_tab"]))

    {:noreply, socket}
  end

  def handle_event("search", %{"query" => query}, socket) when byte_size(query) < 2 do
    {:noreply,
     socket
     |> assign(query: query, loading: false, error: nil)
     |> clear_results()}
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket = assign(socket, query: query, loading: true, error: nil)

    if scope_unavailable?(socket.assigns) do
      {:noreply,
       socket
       |> clear_results()
       |> assign(loading: false, error: nil, search_state: :scoped_unavailable)}
    else
      case run_search(socket.assigns.retrieval_module, query, search_opts(socket)) do
        {:ok, results} ->
          _ = maybe_record_search_gap_for_results(socket, results)

          {:noreply,
           socket
           |> assign(loading: false)
           |> assign_results(results)}

        {:error, :scope_unavailable} ->
          {:noreply,
           socket
           |> clear_results()
           |> assign(loading: false, error: nil, search_state: :scoped_unavailable)}

        {:error, reason} ->
          _ = maybe_record_search_error(socket, reason)

          {:noreply,
           socket
           |> clear_results()
           |> assign(loading: false, error: true, search_state: :error)}
      end
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
      search_state: :idle,
      retrieval_module: Cairnloop.Retrieval,
      gap_recorder: GapRecorder,
      host_surface: nil,
      host_user_id: nil,
      current_path: nil,
      preserve_reply_form: false
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
    |> assign(sections: build_sections([]), active_dom_id: nil, preview: nil, search_state: :idle)
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
    |> assign(
      sections: build_sections(results),
      active_dom_id: active_dom_id,
      search_state: search_state_for(results)
    )
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

  defp move_active_result(socket, delta) do
    results = all_results(socket.assigns.sections)

    case results do
      [] ->
        socket

      _ ->
        dom_ids = Enum.map(results, &SearchResultPresenter.dom_id/1)
        current_index = Enum.find_index(dom_ids, &(&1 == socket.assigns.active_dom_id)) || 0
        next_index = clamp_index(current_index + delta, length(dom_ids) - 1)

        set_active_result(socket, Enum.at(dom_ids, next_index))
    end
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

  defp empty_section_copy(:knowledge_base, query)
       when is_binary(query) and query != "" do
    "No Knowledge Base matches yet. Try a broader phrase, or review similar resolved cases as supporting evidence only."
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

  defp run_search(Cairnloop.Retrieval, query, opts) do
    case Cairnloop.Retrieval.search(query, opts) do
      {:error, reason} -> {:error, reason}
      results -> {:ok, results}
    end
  end

  defp run_search(retrieval_module, query, opts) do
    try do
      case retrieval_module.search(query, opts) do
        results when is_list(results) -> {:ok, results}
        {:error, reason} -> {:error, reason}
        _ -> {:ok, []}
      end
    rescue
      error -> {:error, error}
    end
  end

  defp search_state_for([]), do: :no_hit
  defp search_state_for(_results), do: :results

  defp search_opts(socket) do
    [
      surface: :search_modal,
      host_surface: socket.assigns.host_surface,
      host_user_id: socket.assigns.host_user_id
    ]
  end

  defp scope_unavailable?(assigns) do
    requires_scope?(assigns.host_surface) and blank?(assigns.host_user_id)
  end

  defp requires_scope?(host_surface), do: host_surface in ["conversation", "inbox", "settings"]

  defp blank?(value), do: value in [nil, ""]

  defp maybe_record_search_gap(socket, outcome_class, reason, opts) do
    gap_recorder = socket.assigns.gap_recorder

    attrs = %{
      query: socket.assigns.query,
      surface: :search_modal,
      outcome_class: outcome_class,
      reason: reason,
      host_user_id: socket.assigns.host_user_id,
      tenant_scope: :host_user_scoped,
      ui_surface: socket.assigns.host_surface,
      attempted_evidence: Keyword.get(opts, :attempted_evidence, [])
    }

    case gap_recorder.record(attrs) do
      {:ok, _gap_event} -> :ok
      {:error, _reason} -> :error
      _ -> :ok
    end
  end

  defp maybe_record_search_gap_for_results(socket, results) do
    case search_gap_reason(results) do
      {:empty_recall, :no_canonical_results} ->
        maybe_record_search_gap(socket, :empty_recall, :no_canonical_results,
          attempted_evidence: []
        )

      {:weak_grounding, :assistive_only_results} ->
        maybe_record_search_gap(socket, :weak_grounding, :assistive_only_results,
          attempted_evidence: results
        )

      :skip ->
        :ok
    end
  end

  defp maybe_record_search_error(socket, reason) do
    maybe_record_search_gap(
      socket,
      :retrieval_error,
      Telemetry.classify_exception(reason),
      attempted_evidence: []
    )
  end

  defp search_gap_reason(results) do
    canonical_hit_count = Enum.count(results, &(&1.trust_level == :canonical))
    assistive_hit_count = Enum.count(results, &(&1.trust_level == :assistive))

    cond do
      canonical_hit_count == 0 and assistive_hit_count > 0 ->
        {:weak_grounding, :assistive_only_results}

      results == [] ->
        {:empty_recall, :no_canonical_results}

      true ->
        :skip
    end
  end

  defp toggle_shortcut?(key, params) do
    ((key == "k" or key == "K") and truthy?(params["metaKey"])) or
      (truthy?(params["ctrlKey"]) and (key == "k" or key == "K"))
  end

  defp new_tab_shortcut?(params) do
    truthy?(params["metaKey"]) or truthy?(params["ctrlKey"])
  end

  defp open_active_result(socket, opts) do
    open_result(socket, socket.assigns.active_dom_id, opts)
  end

  defp open_result(socket, nil, _opts), do: socket

  defp open_result(socket, dom_id, _opts) do
    case preview_for_dom_id(socket.assigns.sections, dom_id) do
      %{open_path: open_path} when is_binary(open_path) ->
        socket
        |> close_palette()
        |> push_navigate(to: open_path)

      _ ->
        socket
    end
  end

  defp preview_for_dom_id(sections, dom_id) do
    sections
    |> all_results()
    |> Enum.find(&(SearchResultPresenter.dom_id(&1) == dom_id))
    |> case do
      nil -> nil
      result -> present(result)
    end
  end

  defp clamp_index(index, _max_index) when index < 0, do: 0
  defp clamp_index(index, max_index) when index > max_index, do: max_index
  defp clamp_index(index, _max_index), do: index

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
