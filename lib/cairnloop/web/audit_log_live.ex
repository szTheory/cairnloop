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

  import Cairnloop.Web.Components
  alias Cairnloop.Web.AuditLogPresenter, as: P

  @page_size 50

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(query: "", action_filter: "all", limit: @page_size, proposal_filter: nil)
      |> load_events()

    {:ok, socket}
  end

  # handle_params/2 — tolerant ?proposal filter (THREAD-03a, T-42-07).
  # Parses the raw query param with Integer.parse/1; valid positive integer → assign filter
  # and load filtered events; invalid/garbage/missing → proposal_filter: nil, full honest view.
  # NEVER string-interpolate raw param into a query (Pitfall: param tampering, V5).
  def handle_params(%{"proposal" => raw}, _uri, socket) do
    proposal_filter =
      case Integer.parse(raw) do
        {id, _rest} when id > 0 -> id
        _ -> nil
      end

    {:noreply,
     socket
     |> assign(proposal_filter: proposal_filter)
     |> load_events()}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(proposal_filter: nil)
     |> load_events()}
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
  # Threads proposal_filter into the auditor read via the proposal_id: opt when non-nil
  # (THREAD-03a, D-10). The unfiltered path is byte-identical to before when filter is nil.
  defp load_events(socket) do
    auditor = Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.Governance)
    limit = socket.assigns.limit

    # WR-03/WR-04: fetch one sentinel row beyond the page so "Load more" reflects whether
    # the SERVER actually has more rows, not whether the fetch happened to hit the limit.
    # length(events) >= limit was true even when exactly `limit` rows existed (off-by-one:
    # the button showed once spuriously whenever the total was an exact multiple of the page
    # size). Fetching limit + 1 and rendering only the first `limit` removes that off-by-one.
    opts = [limit: limit + 1]

    opts =
      case Map.get(socket.assigns, :proposal_filter) do
        nil -> opts
        id -> Keyword.put(opts, :proposal_id, id)
      end

    fetched = auditor.list_events(opts)
    more? = length(fetched) > limit
    events = Enum.take(fetched, limit)

    socket
    |> assign(events: events, maybe_more?: more?)
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
    <.cl_shell current={:audit} destinations={Cairnloop.Web.Nav.destinations()}>
      <.cl_page
        title="Audit Log"
        subtitle="A timeline of governed actions and their outcomes. Search or filter to narrow the view."
        width="wide"
      >
      <.cl_card>
        <:header>
          <div class="cl-row cl-row--wrap cl-grow">
            <form class="cl-grow" phx-change="search" phx-submit="search">
              <input
                type="text"
                name="query"
                value={@query}
                class="cl-input"
                placeholder="Search actor, action, reason, or details…"
                phx-debounce="200"
                aria-label="Search audit events"
              />
            </form>
            <form phx-change="filter">
              <div class="cl-field">
                <label class="cl-label" for="action-filter">Action</label>
                <select name="action" id="action-filter" class="cl-select">
                  <option value="all" selected={@action_filter == "all"}>All actions</option>
                  <option :for={label <- @action_options} value={label} selected={@action_filter == label}>
                    {label}
                  </option>
                </select>
              </div>
            </form>
          </div>
        </:header>

        <.cl_empty :if={@visible_events == []} title="No audit events found" icon="shield">
          <p class="cl-text-muted">Governed actions and their outcomes will appear here as operators work.</p>
        </.cl_empty>

        <div :if={@visible_events != []} class="cl-table-scroll" role="region" tabindex="0" aria-label="Audit log">
        <table class="cl-table">
          <thead>
            <tr><th>Time</th><th>Actor</th><th>Action</th><th>Reason</th><th>Conversation</th><th>Details</th></tr>
          </thead>
          <tbody>
            <tr :for={event <- @visible_events}>
              <td>{P.timestamp_label(Map.get(event, :inserted_at))}</td>
              <td>{P.actor_label(Map.get(event, :actor_id))}</td>
              <td>{P.action_label(Map.get(event, :action))}</td>
              <td>{P.reason_label(Map.get(event, :reason))}</td>
              <td>
                <%!-- Subject link: scope-relative /#{id} when conversation is present; plain fallback on nil (D-08, T-42-09, Pitfall 3/4/6). --%>
                <%= case P.subject_href(event) do %>
                  <% nil -> %>
                    <span class="cl-text-muted">—</span>
                  <% href -> %>
                    <.link
                      navigate={href}
                      aria-label={"View conversation #{Map.get(event, :conversation_id)}"}
                    >View conversation</.link>
                <% end %>
              </td>
              <td>
                <%= case P.metadata_rows(Map.get(event, :metadata)) do %>
                  <% [] -> %>
                    —
                  <% rows -> %>
                    <details class="cl-details">
                      <summary>View details</summary>
                      <dl>
                        <div :for={{label, value} <- rows}>
                          <dt>{label}</dt>
                          <dd>{value}</dd>
                        </div>
                      </dl>
                    </details>
                <% end %>
              </td>
            </tr>
          </tbody>
        </table>
        </div>

        <div :if={@visible_events != [] and @maybe_more?} class="cl-pagination">
          <.cl_button type="button" phx-click="load_more" variant="ghost">Load more</.cl_button>
        </div>
      </.cl_card>
      </.cl_page>
    </.cl_shell>
    """
  end
end
