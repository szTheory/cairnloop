defmodule Cairnloop.Web.SettingsLive do
  use Phoenix.LiveView

  def mount(_params, session, socket) do
    provider =
      Application.get_env(:cairnloop, :sla_policy_provider, Cairnloop.DefaultSLAPolicyProvider)

    socket =
      socket
      |> assign(:host_user_id, Map.get(session, "host_user_id"))
      |> assign(:provider, provider)
      |> assign(:priorities, [:low, :normal, :high, :urgent])
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
      <h1>SLA Policies</h1>
      
      <%= if flash = Phoenix.Flash.get(@flash, :info) do %>
        <div class="alert alert-info"><%= flash %></div>
      <% end %>
      <%= if flash = Phoenix.Flash.get(@flash, :error) do %>
        <div class="alert alert-error"><%= flash %></div>
      <% end %>

      <div class="policies-list">
        <h2>Active Policies</h2>
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

      <div class="policy-form">
        <h2>Update Policy</h2>
        <form phx-submit="save_policy">
          <div>
            <label for="priority">Priority</label>
            <select name="policy[priority]" id="priority" required>
              <%= for priority <- @priorities do %>
                <option value={priority}><%= priority %></option>
              <% end %>
            </select>
          </div>
          
          <div>
            <label for="target_first_response_minutes">Target First Response (minutes)</label>
            <input type="number" name="policy[target_first_response_minutes]" id="target_first_response_minutes" required min="1" />
          </div>
          
          <div>
            <label for="target_resolution_minutes">Target Resolution (minutes)</label>
            <input type="number" name="policy[target_resolution_minutes]" id="target_resolution_minutes" required min="1" />
          </div>
          
          <button type="submit">Save Policy</button>
        </form>
      </div>
    </div>
    """
  end
end
