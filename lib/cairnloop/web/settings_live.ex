defmodule Cairnloop.Web.SettingsLive do
  use Phoenix.LiveView

  import Ecto.Query
  alias Cairnloop.MCP.Token

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

    repo = Application.fetch_env!(:cairnloop, :repo)
    tokens = repo.all(from t in Token, where: is_nil(t.revoked_at), order_by: [desc: t.inserted_at])

    socket =
      socket
      |> assign(:host_user_id, Map.get(session, "host_user_id"))
      |> assign(:provider, provider)
      |> assign(:priorities, [:low, :normal, :high, :urgent])
      |> assign(:notifier_health, notifier_health)
      |> assign(:retrieval_health, retrieval_health)
      |> assign(:tokens, tokens)
      |> assign(:new_raw_token, nil)
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

  def handle_event("create_token", %{"name" => name}, socket) do
    case Cairnloop.MCP.issue_token(%{name: name}) do
      {:ok, token, raw_token} ->
        socket =
          socket
          |> assign(:tokens, [token | socket.assigns.tokens])
          |> assign(:new_raw_token, raw_token)
          |> put_flash(:info, "MCP token created successfully.")
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create MCP token.")}
    end
  end

  def handle_event("update_token", %{"token_id" => id, "name" => new_name}, socket) do
    token = Enum.find(socket.assigns.tokens, &(to_string(&1.id) == to_string(id)))

    if token do
      case Cairnloop.MCP.update_token(token, %{name: new_name}) do
        {:ok, updated_token} ->
          updated_tokens = Enum.map(socket.assigns.tokens, fn t ->
            if t.id == updated_token.id, do: updated_token, else: t
          end)

          socket =
            socket
            |> assign(:tokens, updated_tokens)
            |> put_flash(:info, "Token name updated.")
          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update token name.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Token not found.")}
    end
  end

  def handle_event("revoke_token", %{"id" => id}, socket) do
    token = Enum.find(socket.assigns.tokens, &(to_string(&1.id) == to_string(id)))

    if token do
      case Cairnloop.MCP.revoke_token(token) do
        {:ok, _revoked} ->
          remaining_tokens = Enum.reject(socket.assigns.tokens, &(to_string(&1.id) == to_string(id)))
          socket =
            socket
            |> assign(:tokens, remaining_tokens)
            |> assign(:new_raw_token, nil)
            |> put_flash(:info, "Token revoked successfully.")
          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to revoke token.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Token not found.")}
    end
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
        <h2>MCP Authentication</h2>
        
        <%= if @new_raw_token do %>
          <div class="alert alert-warning" style="background-color: var(--cl-warning-bg); padding: 16px; margin-bottom: 16px; border-radius: 4px; border: 1px solid var(--cl-warning-border);">
            <strong>Important:</strong> Copy your new token now. It will not be shown again.
            <br/><br/>
            <code style="background: rgba(0,0,0,0.1); padding: 4px; border-radius: 4px; word-break: break-all;"><%= @new_raw_token %></code>
          </div>
        <% end %>

        <%= if Enum.empty?(@tokens) do %>
          <div class="empty-state" style="text-align: center; padding: 24px; color: var(--cl-text-muted);">
            <h3>No MCP tokens active</h3>
            <p>Add a token to enable external tool capabilities for this app.</p>
          </div>
        <% else %>
          <ul style="list-style: none; padding: 0;">
            <%= for token <- @tokens do %>
              <li style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--cl-border); padding: 12px 0;">
                <div>
                  <form phx-submit="update_token" style="display: inline-flex; align-items: center; gap: 8px;">
                    <input type="hidden" name="token_id" value={token.id} />
                    <input type="text" name="name" value={token.name} required style="padding: 4px; border: 1px solid var(--cl-border); border-radius: 4px;" />
                    <button type="submit" class="cl-btn" style="padding: 4px 8px; font-size: 12px;">Save</button>
                  </form>
                  <div style="color: var(--cl-text-muted); font-size: 14px; margin-top: 4px;">
                    cl_mcp_***
                  </div>
                </div>
                <button type="button" phx-click="revoke_token" phx-value-id={token.id} data-confirm="Revoke Token: Are you sure? Active integrations using this token will fail immediately." class="cl-btn cl-btn-danger" style="padding: 6px 12px; background: var(--cl-danger, red); color: white; border: none; border-radius: 4px; cursor: pointer;">Revoke</button>
              </li>
            <% end %>
          </ul>
        <% end %>

        <div style="margin-top: 24px; border-top: 1px solid var(--cl-border); padding-top: 16px;">
          <h3>Add New Token</h3>
          <form phx-submit="create_token" style="display: flex; gap: 8px; align-items: center;">
            <input type="text" name="name" placeholder="Token Name" required style="padding: 8px; border: 1px solid var(--cl-border); border-radius: 4px; flex-grow: 1;" />
            <button type="submit" class="cl-btn" style="padding: 8px 16px; background: var(--cl-primary, blue); color: white; border: none; border-radius: 4px; cursor: pointer;">Add MCP Token</button>
          </form>
        </div>
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
