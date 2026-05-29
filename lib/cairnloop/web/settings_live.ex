defmodule Cairnloop.Web.SettingsLive do
  use Phoenix.LiveView

  def mount(_params, session, socket) do
    provider =
      Application.get_env(:cairnloop, :sla_policy_provider, Cairnloop.DefaultSLAPolicyProvider)

    notifier = Application.get_env(:cairnloop, :notifier)
    notifier_health =
      if notifier && Code.ensure_loaded?(notifier) && function_exported?(notifier, :on_conversation_resolved, 2) do
        "Healthy"
      else
        "Unreachable / Degraded"
      end

    retrieval_health =
      case Cairnloop.Retrieval.system_health() do
        {:ok, msg} -> msg
        {:error, msg} -> msg
      end

    socket =
      socket
      |> assign(:host_user_id, Map.get(session, "host_user_id"))
      |> assign(:provider, provider)
      |> assign(:priorities, [:low, :normal, :high, :urgent])
      |> assign(:notifier_health, notifier_health)
      |> assign(:retrieval_health, retrieval_health)
      |> load_policies()

    {:ok, socket}
  end

  def handle_event("save_policy", %{"policy" => params}, socket) do
    priority_str = params["priority"]

    priority =
      if priority_str in ["low", "normal", "high", "urgent"],
        do: String.to_atom(priority_str),
        else: nil

    if priority do
      attrs = %{
        target_first_response_minutes: String.to_integer(params["target_first_response_minutes"]),
        target_resolution_minutes: String.to_integer(params["target_resolution_minutes"])
      }

      case socket.assigns.provider.set_policy(priority, attrs) do
        {:ok, _policy} ->
          {:noreply,
           socket |> put_flash(:info, "SLA policy updated successfully.") |> load_policies()}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to update SLA policy: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invalid priority")}
    end
  rescue
    _e in ArgumentError ->
      {:noreply, put_flash(socket, :error, "Invalid input values.")}
  end

  defp load_policies(socket) do
    case socket.assigns.provider.get_active_policies() do
      {:ok, policies} ->
        assign(socket, :policies, policies)

      {:error, _reason} ->
        assign(socket, :policies, [])
    end
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={Cairnloop.Web.SearchModalComponent}
      id="search-modal"
      host_surface="settings"
      host_user_id={@host_user_id}
      current_path="/settings"
    />
    <div class="cairnloop-settings">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
        <h1>Settings Cockpit</h1>
        <button 
          type="button" 
          onclick="document.documentElement.dataset.theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'; localStorage.setItem('phx:theme', document.documentElement.dataset.theme); window.dispatchEvent(new CustomEvent('phx:set-theme'));"
          class="cl-btn"
        >
          Toggle Dark Mode
        </button>
      </div>
      
      <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
        <div class="alert alert-info"><%= flash %></div>
      <% end %>
      <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
        <div class="alert alert-error"><%= flash %></div>
      <% end %>

      <div class="cl-card" style="margin-bottom: 24px; border: 1px solid var(--cl-border); padding: 16px; border-radius: 8px;">
        <h2>System Health</h2>
        <ul style="list-style: none; padding: 0;">
          <li style="margin-bottom: 8px;">
            <strong>Notifier:</strong> 
            <span style={if @notifier_health == "Healthy", do: "color: var(--cl-success, green);", else: "color: var(--cl-danger, red);"}>
              <%= if @notifier_health == "Healthy", do: "●", else: "●" %> <%= @notifier_health %>
            </span>
          </li>
          <li>
            <strong>Retrieval (pgvector):</strong> 
            <span style={if @retrieval_health == "Healthy", do: "color: var(--cl-success, green);", else: "color: var(--cl-danger, red);"}>
              <%= if @retrieval_health == "Healthy", do: "●", else: "●" %> <%= @retrieval_health %>
            </span>
          </li>
        </ul>
      </div>

      <div class="cl-card" style="margin-bottom: 24px; border: 1px solid var(--cl-border); padding: 16px; border-radius: 8px;">
        <h2>SLA Policies</h2>
        <div class="policies-list">
          <h3>Active Policies</h3>
          <ul>
            <%= for policy <- @policies do %>
              <li>
                <strong><%= Map.get(policy, :priority, "unknown") %></strong>
                - First Response: <%= Map.get(policy, :target_first_response_minutes, "N/A") %> min
                - Resolution: <%= Map.get(policy, :target_resolution_minutes, "N/A") %> min
              </li>
            <% end %>
          </ul>
        </div>

        <div class="policy-form" style="margin-top: 16px;">
          <h3>Update Policy</h3>
          <form phx-submit="save_policy">
            <div style="margin-bottom: 8px;">
              <label for="priority" style="display: block; margin-bottom: 4px;">Priority</label>
              <select name="policy[priority]" id="priority" required style="width: 100%; padding: 8px;">
                <%= for priority <- @priorities do %>
                  <option value={priority}><%= priority %></option>
                <% end %>
              </select>
            </div>
            
            <div style="margin-bottom: 8px;">
              <label for="target_first_response_minutes" style="display: block; margin-bottom: 4px;">Target First Response (minutes)</label>
              <input type="number" name="policy[target_first_response_minutes]" id="target_first_response_minutes" required min="1" style="width: 100%; padding: 8px;" />
            </div>
            
            <div style="margin-bottom: 16px;">
              <label for="target_resolution_minutes" style="display: block; margin-bottom: 4px;">Target Resolution (minutes)</label>
              <input type="number" name="policy[target_resolution_minutes]" id="target_resolution_minutes" required min="1" style="width: 100%; padding: 8px;" />
            </div>
            
            <button type="submit" class="cl-btn" style="padding: 8px 16px; background: var(--cl-primary, blue); color: white; border: none; border-radius: 4px; cursor: pointer;">Save Policy</button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
