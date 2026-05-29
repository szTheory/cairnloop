defmodule Cairnloop.Web.AuditLogLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    auditor = Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp)
    events = auditor.list_events([])

    {:ok, assign(socket, events: events)}
  end

  def render(assigns) do
    ~H"""
    <div class="cairnloop-audit-log">
      <h2>Audit Log</h2>
      
      <div class="audit-timeline">
        <%= if @events == [] do %>
          <p class="audit-empty">No audit events found.</p>
        <% else %>
          <table class="audit-table">
            <thead>
              <tr>
                <th>Timestamp</th>
                <th>Actor</th>
                <th>Action</th>
                <th>Metadata</th>
              </tr>
            </thead>
            <tbody>
              <%= for event <- @events do %>
                <tr>
                  <td><%= Map.get(event, :inserted_at) %></td>
                  <td><%= inspect(Map.get(event, :actor_id)) %></td>
                  <td><%= Map.get(event, :action) %></td>
                  <td>
                    <pre class="audit-trace"><%= inspect(Map.get(event, :metadata, %{}), pretty: true) %></pre>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>
    </div>
    """
  end
end
