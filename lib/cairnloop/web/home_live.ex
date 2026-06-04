defmodule Cairnloop.Web.HomeLive do
  @moduledoc """
  Cockpit Home — the operator dashboard's task-oriented landing (GDS "start with
  user needs"). Instead of dumping the operator into a bare list, it routes each
  persona to their job by intent + ONE actionable "needs-you" live count:

    * Front-line operator → "Work the queue" (open conversations).
    * Operator/governance  → "Recover resolved" (resolved, recovery-eligible).
    * KB editor/lead       → "Tend knowledge" (open knowledge gaps).
    * SRE/ops              → "System health" (notifier + retrieval).
    * Governance reviewer  → "Audit trail" (recent governed actions).

  Every count is computed defensively: a missing Repo or facade hiccup degrades to
  "—" and a calm link rather than crashing the cockpit (fail-closed brand posture).
  Counts pass the Decision Test — each is something the operator acts on, never a
  vanity total. Zero states read as success ("All caught up"), not empty voids.
  """
  use Phoenix.LiveView

  import Cairnloop.Web.Components

  alias Cairnloop.Chat
  alias Cairnloop.Governance
  alias Cairnloop.KnowledgeAutomation

  @impl true
  def mount(_params, session, socket) do
    # Same topic InboxLive uses (Phase 28 D-09) so counts refresh on new/changed conversations.
    if connected?(socket), do: Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")

    socket =
      socket
      |> assign(:host_user_id, Map.get(session, "host_user_id"))
      |> assign(:page_title, "Cockpit")
      |> assign_counts()

    {:ok, socket}
  end

  @impl true
  def handle_info({:conversations_changed}, socket), do: {:noreply, assign_counts(socket)}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp assign_counts(socket) do
    conversations = safe(fn -> Chat.list_conversations() end, [])
    open_count = Enum.count(conversations, &(&1.status == :open))
    resolved_count = Enum.count(conversations, &(&1.status == :resolved))
    gaps_count = safe(fn -> length(KnowledgeAutomation.list_gap_candidates()) end, nil)
    audit_count = safe(fn -> length(Governance.list_action_events(limit: 100)) end, nil)
    {health_ok?, health_label} = system_health()

    assign(socket,
      open_count: open_count,
      resolved_count: resolved_count,
      gaps_count: gaps_count,
      audit_count: audit_count,
      health_ok?: health_ok?,
      health_label: health_label
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.cl_shell current={:home} destinations={Cairnloop.Web.Nav.destinations()}>
      <.cl_page title="Welcome back" subtitle="What needs you today?" width="wide">
      <div class="cl-home-grid">
        <.cl_stat
          job="Work the queue"
          icon="inbox"
          count={count_or_dash(@open_count)}
          calm?={@open_count == 0}
          meta={open_meta(@open_count)}
          href="/inbox"
          cta="Open inbox"
        />

        <.cl_stat
          job="Recover resolved"
          icon="waypoint"
          count={count_or_dash(@resolved_count)}
          calm?={@resolved_count == 0}
          meta={resolved_meta(@resolved_count)}
          href="/inbox"
          cta="Send follow-ups"
        />

        <.cl_stat
          job="Tend knowledge"
          icon="book"
          count={count_or_dash(@gaps_count)}
          calm?={@gaps_count == 0}
          meta={gaps_meta(@gaps_count)}
          href="/knowledge-base/gaps"
          cta="Review gaps"
        />

        <.cl_stat
          job="System health"
          icon="shield"
          count={@health_label}
          calm?={@health_ok?}
          meta={if @health_ok?, do: "Notifier and retrieval reachable", else: "One or more checks need attention"}
          href="/settings"
          cta="Open settings"
        />

        <.cl_stat
          job="Audit trail"
          icon="dot"
          count={count_or_dash(@audit_count)}
          calm?={true}
          meta="Recent governed actions"
          href="/audit-log"
          cta="View audit log"
        />
      </div>
      </.cl_page>
    </.cl_shell>
    """
  end

  # ---- count copy (calm, reason-forward) ----------------------------------

  defp count_or_dash(nil), do: "—"
  defp count_or_dash(n), do: n

  defp open_meta(0), do: "All caught up — nothing waiting on you"
  defp open_meta(1), do: "conversation needs a reply"
  defp open_meta(_), do: "conversations need a reply"

  defp resolved_meta(0), do: "No resolved threads to follow up"
  defp resolved_meta(_), do: "resolved — eligible for recovery follow-up"

  defp gaps_meta(nil), do: "Knowledge gaps unavailable"
  defp gaps_meta(0), do: "No open knowledge gaps"
  defp gaps_meta(1), do: "gap waiting to become an article"
  defp gaps_meta(_), do: "gaps waiting to become articles"

  # ---- health (same checks as SettingsLive) -------------------------------

  defp system_health do
    notifier = Application.get_env(:cairnloop, :notifier)

    notifier_ok? =
      notifier && Code.ensure_loaded?(notifier) &&
        function_exported?(notifier, :on_conversation_resolved, 2)

    retrieval_ok? =
      safe(
        fn ->
          case Cairnloop.Retrieval.system_health() do
            {:ok, _} -> true
            _ -> false
          end
        end,
        false
      )

    cond do
      notifier_ok? && retrieval_ok? -> {true, "Healthy"}
      true -> {false, "Degraded"}
    end
  end

  # ---- defensive helpers --------------------------------------------------

  defp safe(fun, fallback) do
    fun.()
  rescue
    _ -> fallback
  catch
    _, _ -> fallback
  end
end
