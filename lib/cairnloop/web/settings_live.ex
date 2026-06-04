defmodule Cairnloop.Web.SettingsLive do
  use Phoenix.LiveView

  import Ecto.Query
  import Cairnloop.Web.Components
  alias Cairnloop.MCP.Token

  def mount(_params, session, socket) do
    provider =
      Application.get_env(:cairnloop, :sla_policy_provider, Cairnloop.DefaultSLAPolicyProvider)

    notifier = Application.get_env(:cairnloop, :notifier)

    notifier_health =
      if notifier && Code.ensure_loaded?(notifier) &&
           function_exported?(notifier, :on_conversation_resolved, 2) do
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

    tokens =
      repo.all(from(t in Token, where: is_nil(t.revoked_at), order_by: [desc: t.inserted_at]))

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
          updated_tokens =
            Enum.map(socket.assigns.tokens, fn t ->
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
          remaining_tokens =
            Enum.reject(socket.assigns.tokens, &(to_string(&1.id) == to_string(id)))

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
    <.cl_shell current={:settings} destinations={Cairnloop.Web.Nav.destinations()}>
      <.cl_page title="Settings" width="wide">
        <:actions>
          <button
            type="button"
            onclick="document.documentElement.dataset.theme = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'; localStorage.setItem('phx:theme', document.documentElement.dataset.theme); window.dispatchEvent(new CustomEvent('phx:set-theme'));"
            class="cl-button cl-button--ghost"
          >
            Toggle dark mode
          </button>
        </:actions>

        <.live_component
          module={Cairnloop.Web.SearchModalComponent}
          id="search-modal"
          host_surface="settings"
          host_user_id={@host_user_id}
          current_path="/settings"
        />

        <.cl_banner :if={Phoenix.Flash.get(@flash, :info)} variant="success" class="cl-mb-7">
        {Phoenix.Flash.get(@flash, :info)}
      </.cl_banner>
      <.cl_banner :if={Phoenix.Flash.get(@flash, :error)} variant="danger" class="cl-mb-7">
        {Phoenix.Flash.get(@flash, :error)}
      </.cl_banner>

      <.cl_card class="cl-mb-7">
        <:header><h2>System health</h2></:header>
        <div class="cl-stack">
          <div class="cl-row cl-row--between">
            <span>Notifier</span>
            <.cl_chip variant={health_variant(@notifier_health)} label={@notifier_health} />
          </div>
          <div class="cl-row cl-row--between">
            <span>Retrieval (pgvector)</span>
            <.cl_chip variant={health_variant(@retrieval_health)} label={@retrieval_health} />
          </div>
        </div>
      </.cl_card>

      <.cl_card class="cl-mb-7">
        <:header><h2>MCP authentication</h2></:header>

        <.cl_banner :if={@new_raw_token} variant="warning" class="cl-mb-7">
          <strong>Copy your new token now.</strong> It will not be shown again.
          <code class="cl-code-block cl-mt-5">{@new_raw_token}</code>
        </.cl_banner>

        <.cl_empty :if={Enum.empty?(@tokens)} title="No MCP tokens active" icon="shield">
          <p class="cl-text-muted">Add a token to let an external MCP client call governed tools in this app.</p>
        </.cl_empty>

        <ul :if={not Enum.empty?(@tokens)} class="cl-stack">
          <li :for={token <- @tokens} class="cl-row cl-row--between cl-list-row">
            <div class="cl-stack">
              <form phx-submit="update_token" class="cl-row">
                <input type="hidden" name="token_id" value={token.id} />
                <input type="text" name="name" value={token.name} required class="cl-input" />
                <.cl_button type="submit" size="sm">Save</.cl_button>
              </form>
              <span class="cl-text-muted cl-text-small cl-mono">cl_mcp_***</span>
            </div>
            <.cl_button
              variant="danger"
              size="sm"
              phx-click="revoke_token"
              phx-value-id={token.id}
              data-confirm="Revoke token? Active integrations using it will fail immediately."
            >
              Revoke
            </.cl_button>
          </li>
        </ul>

        <hr class="cl-divider" />
        <h3 class="cl-mb-7">Add new token</h3>
        <form phx-submit="create_token" class="cl-row">
          <input type="text" name="name" placeholder="Token name" required class="cl-input cl-grow" />
          <.cl_button type="submit" variant="primary">Add MCP token</.cl_button>
        </form>
      </.cl_card>

      <.cl_card class="cl-mb-7">
        <:header><h2>SLA policies</h2></:header>

        <h3>Active policies</h3>
        <.cl_empty :if={@policies == []} title="No active SLA policies" icon="clock">
          <p class="cl-text-muted">Set a target below to start tracking response and resolution time.</p>
        </.cl_empty>
        <div :if={@policies != []} class="cl-table-scroll" role="region" tabindex="0" aria-label="Policies">
        <table class="cl-table cl-mb-7">
          <thead>
            <tr><th>Priority</th><th>First response</th><th>Resolution</th></tr>
          </thead>
          <tbody>
            <tr :for={policy <- @policies}>
              <td><strong>{Map.get(policy, :priority, "unknown")}</strong></td>
              <td>{Map.get(policy, :target_first_response_minutes, "—")} min</td>
              <td>{Map.get(policy, :target_resolution_minutes, "—")} min</td>
            </tr>
          </tbody>
        </table>
        </div>

        <h3 class="cl-mt-5 cl-mb-7">Update policy</h3>
        <form phx-submit="save_policy" class="cl-stack--lg cl-stack">
          <div class="cl-field">
            <label class="cl-label" for="priority">Priority</label>
            <select name="policy[priority]" id="priority" required class="cl-select">
              <option :for={priority <- @priorities} value={priority}>{priority}</option>
            </select>
          </div>
          <div class="cl-field">
            <label class="cl-label" for="target_first_response_minutes">Target first response (minutes)</label>
            <input type="number" name="policy[target_first_response_minutes]" id="target_first_response_minutes" required min="1" class="cl-input" />
          </div>
          <div class="cl-field">
            <label class="cl-label" for="target_resolution_minutes">Target resolution (minutes)</label>
            <input type="number" name="policy[target_resolution_minutes]" id="target_resolution_minutes" required min="1" class="cl-input" />
          </div>
          <div><.cl_button type="submit" variant="primary">Save policy</.cl_button></div>
        </form>
      </.cl_card>
      </.cl_page>
    </.cl_shell>
    """
  end

  # "Healthy" → success chip; anything else (a degraded/error message) → danger.
  defp health_variant("Healthy"), do: "success"
  defp health_variant(_), do: "danger"
end
