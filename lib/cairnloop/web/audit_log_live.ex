defmodule Cairnloop.Web.AuditLogLive do
  @moduledoc """
  Operator audit log (AUDIT-01): a searchable, filterable timeline of
  `Cairnloop.Auditor` events.

  The event source is the configured `:cairnloop, :auditor` (default
  `Cairnloop.Auditor.Governance`, which surfaces the governance `ToolActionEvent`
  trail through the `Cairnloop.Governance` facade). Hosts can override with their own
  `Cairnloop.Auditor` implementation.

  Events are rendered through `Cairnloop.Web.AuditLogPresenter` — actions are humanized
  and metadata is only ever shown behind an explicit expander, never raw inline
  (brand §5.6: no raw Elixir terms / JSON to operators).
  """
  use Phoenix.LiveView

  alias Cairnloop.Web.AuditLogPresenter, as: P

  @page_size 50

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(query: "", action_filter: "all", limit: @page_size)
      |> load_events()

    {:ok, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, socket |> assign(query: query) |> recompute()}
  end

  def handle_event("filter", %{"action" => action}, socket) do
    {:noreply, socket |> assign(action_filter: action) |> recompute()}
  end

  def handle_event("load_more", _params, socket) do
    {:noreply, socket |> assign(limit: socket.assigns.limit + @page_size) |> load_events()}
  end

  # Fetch from the configured auditor, then apply the current search/filter.
  defp load_events(socket) do
    auditor = Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.Governance)
    events = auditor.list_events(limit: socket.assigns.limit)

    socket
    |> assign(events: events, maybe_more?: length(events) >= socket.assigns.limit)
    |> recompute()
  end

  # Pure re-derivation of the visible rows + the action-filter options.
  defp recompute(socket) do
    %{events: events, query: query, action_filter: action_filter} = socket.assigns

    visible =
      events
      |> Enum.filter(&P.matches?(&1, query))
      |> Enum.filter(&action_matches?(&1, action_filter))

    # Options derive from the VISIBLE (filtered) set so a filtered-out action's label
    # never persists in the dropdown — and so no raw action atom ever leaks as an
    # <option value> (brand §5.6: humanized labels only to operators).
    assign(socket, visible_events: visible, action_options: action_options(visible))
  end

  defp action_matches?(_event, "all"), do: true

  defp action_matches?(event, action_filter) do
    # Filter on the humanized label — the operator-facing value the <select> submits
    # (never the raw action atom, which must not appear in rendered HTML).
    P.action_label(Map.get(event, :action)) == action_filter
  end

  # Distinct humanized action labels present in the set — used as BOTH the <option>
  # value and display text so no raw atom leaks (brand §5.6).
  defp action_options(events) do
    events
    |> Enum.map(&Map.get(&1, :action))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&P.action_label/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def render(assigns) do
    ~H"""
    <div class="cairnloop-audit-log">
      <h2>Audit Log</h2>
      <p class="cairnloop-audit-intro">
        A timeline of governed actions and their outcomes. Search or filter to narrow the view.
      </p>

      <form class="cairnloop-audit-controls" phx-change="search" phx-submit="search">
        <input
          type="text"
          name="query"
          value={@query}
          placeholder="Search actor, action, reason, or details…"
          phx-debounce="200"
          aria-label="Search audit events"
        />
      </form>

      <form class="cairnloop-audit-controls" phx-change="filter">
        <label>
          Action
          <select name="action">
            <option value="all" selected={@action_filter == "all"}>All actions</option>
            <%= for label <- @action_options do %>
              <option value={label} selected={@action_filter == label}><%= label %></option>
            <% end %>
          </select>
        </label>
      </form>

      <div class="cairnloop-audit-timeline">
        <%= if @visible_events == [] do %>
          <p class="cairnloop-audit-empty">No audit events found.</p>
        <% else %>
          <table class="cairnloop-audit-table">
            <thead>
              <tr>
                <th>Time</th>
                <th>Actor</th>
                <th>Action</th>
                <th>Reason</th>
                <th>Details</th>
              </tr>
            </thead>
            <tbody>
              <%= for event <- @visible_events do %>
                <tr>
                  <td><%= P.timestamp_label(Map.get(event, :inserted_at)) %></td>
                  <td><%= P.actor_label(Map.get(event, :actor_id)) %></td>
                  <td><%= P.action_label(Map.get(event, :action)) %></td>
                  <td><%= P.reason_label(Map.get(event, :reason)) %></td>
                  <td>
                    <%= case P.metadata_rows(Map.get(event, :metadata)) do %>
                      <% [] -> %>
                        —
                      <% rows -> %>
                        <details class="cairnloop-audit-details">
                          <summary>View details</summary>
                          <dl>
                            <%= for {label, value} <- rows do %>
                              <div>
                                <dt><%= label %></dt>
                                <dd><%= value %></dd>
                              </div>
                            <% end %>
                          </dl>
                        </details>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>

          <%= if @maybe_more? do %>
            <button type="button" phx-click="load_more" class="cairnloop-audit-load-more">
              Load more
            </button>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
