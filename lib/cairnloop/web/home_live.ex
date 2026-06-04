defmodule Cairnloop.Web.HomeLive do
  @moduledoc """
  Cockpit Home — the operator dashboard's D1 two-tier primacy model:

    * Tier 1 (hero): "Work the queue" — full-width copper count hero with a primary
      "Open inbox" CTA. Swaps to a calm "All caught up" zero-state when the queue
      is empty (D-07). Recover-resolved sub-line shows deterministically to
      `/inbox?status=resolved` only when resolved_count > 0 (HOME-02, D-10).

    * Tier 2 (band): three secondary "Tend the trail" tiles — Tend knowledge,
      Audit trail, System health. Health renders as a cl_chip (D-08), never a
      numeric count slot. Copper is reserved for the hero (70/20/10).

  Counts are fail-closed: `safe_count/1` + `split/1` keep the integer at 0 on
  error but raise a separate `unavailable?` signal so error ≠ calm-zero (D-06).
  Open/resolved counts use scoped `Chat.count_conversations/1` queries instead of
  a full list + Enum.count, throttled to ≤1 recount per 500ms window via the
  `pending_recount?` coalescing flag + `Process.send_after` (D-09, HOME-05).
  """
  use Phoenix.LiveView

  import Cairnloop.Web.Components

  alias Cairnloop.Chat
  alias Cairnloop.Governance
  alias Cairnloop.KnowledgeAutomation

  # D-09: 500ms trailing-edge coalesce for PubSub recount bursts.
  @recount_ms 500

  @impl true
  def mount(_params, session, socket) do
    # Same topic InboxLive uses (Phase 28 D-09) so counts refresh on new/changed conversations.
    if connected?(socket), do: Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")

    socket =
      socket
      |> assign(:host_user_id, Map.get(session, "host_user_id"))
      |> assign(:page_title, "Cockpit")
      |> assign(:pending_recount?, false)
      |> assign_counts()

    {:ok, socket}
  end

  @impl true
  # D-09: Coalescing throttle — a burst of {:conversations_changed} broadcasts collapses into
  # at most one recount per @recount_ms window. Connected-only guard prevents orphan timers
  # on dead render (bare sockets in tests / disconnected preloads).
  def handle_info({:conversations_changed}, socket) do
    if socket.assigns.pending_recount? do
      # Already armed — coalesce; do nothing.
      {:noreply, socket}
    else
      if connected?(socket), do: Process.send_after(self(), :recount, @recount_ms)
      # Set flag to connected?(socket) — false on disconnected sockets so the flag never
      # deadlocks and tests never arm a real timer (RESEARCH Pitfall 1 / T-39-06).
      {:noreply, assign(socket, :pending_recount?, connected?(socket))}
    end
  end

  def handle_info(:recount, socket) do
    {:noreply, socket |> assign(:pending_recount?, false) |> assign_counts()}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp assign_counts(socket) do
    # HOME-05 / D-09: scoped SELECT count(*) per status — not full-list Enum.count.
    {open_count, open_count_unavailable?} =
      safe_count(fn -> Chat.count_conversations(status: :open) end) |> split()

    {resolved_count, resolved_count_unavailable?} =
      safe_count(fn -> Chat.count_conversations(status: :resolved) end) |> split()

    # Band counts: these are NOT conversation-status counts, so they are deliberately
    # NOT subject to HOME-05's scoped-count + throttle requirement (that is scoped to
    # the open/resolved counts that hit the per-PubSub-tick re-query footgun, D-09).
    # They still flow through safe_count/1 + split/1 (NOT safe/2) so a real count is
    # reported honestly on success and only a genuine error yields {0, true} (D-06).
    {gaps_count, gaps_unavailable?} =
      safe_count(fn -> KnowledgeAutomation.list_gap_candidates() |> length() end)
      |> split()

    {audit_count, audit_unavailable?} =
      safe_count(fn -> Governance.list_action_events(limit: 100) |> length() end)
      |> split()

    {health_ok?, health_label} = system_health()

    health_variant = if health_ok?, do: "success", else: "warning"

    health_meta =
      if health_ok?,
        do: "Notifier and retrieval reachable",
        else: "One or more checks need attention"

    assign(socket,
      open_count: open_count,
      open_count_unavailable?: open_count_unavailable?,
      resolved_count: resolved_count,
      resolved_count_unavailable?: resolved_count_unavailable?,
      gaps_count: gaps_count,
      gaps_unavailable?: gaps_unavailable?,
      audit_count: audit_count,
      audit_unavailable?: audit_unavailable?,
      health_variant: health_variant,
      health_label: health_label,
      health_meta: health_meta
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.cl_shell current={:home} destinations={Cairnloop.Web.Nav.destinations()}>
      <.cl_page title="Welcome back" subtitle="What needs you today?" width="wide">
        <%!-- Tier 1: hero OR zero-state swap (D-07) --%>
        <%= if @open_count == 0 and not @open_count_unavailable? do %>
          <.cl_empty icon="check-circle" title="All caught up">
            Nothing is waiting on you right now.
          </.cl_empty>
        <% else %>
          <.cl_hero job="Work the queue" count={@open_count}>
            <:detail>
              <%= if @open_count_unavailable? do %>
                <span class="cl-text-small cl-text-muted">Count unavailable</span>
              <% end %>
              <%= if @resolved_count > 0 and not @resolved_count_unavailable? do %>
                <a href="/inbox?status=resolved" class="cl-text-small cl-text-muted">
                  {@resolved_count} resolved — eligible for recovery
                </a>
              <% end %>
            </:detail>
            <:cta_slot>
              <%!-- A1 RESOLVED: cl_button is a plain <button> — wrap in <.link> for navigation. --%>
              <.link navigate="/inbox"><.cl_button variant="primary" size="lg">Open inbox</.cl_button></.link>
            </:cta_slot>
          </.cl_hero>
        <% end %>

        <%!-- Tier 2: exactly 3 tiles → fills 3-up grid, no phantom 6th cell (HOME-04) --%>
        <div class="cl-home-grid cl-mt-5">
          <.cl_stat
            job="Tend knowledge"
            icon="book"
            count={@gaps_count}
            calm?={@gaps_count == 0 and not @gaps_unavailable?}
            meta={gaps_meta(@gaps_count, @gaps_unavailable?)}
            href="/knowledge-base/gaps"
            cta="Review gaps"
          />
          <.cl_stat
            job="Audit trail"
            icon="dot"
            count={@audit_count}
            calm?={true}
            meta={audit_meta(@audit_unavailable?)}
            href="/audit-log"
            cta="View audit log"
          />
          <%!-- Health cell: .cl-stat shell (div, not link), chip replaces count slot (D-08) --%>
          <div class="cl-stat">
            <span class="cl-stat__job"><.cl_icon name="shield" class="cl-chip__icon" /> System health</span>
            <.cl_chip variant={@health_variant} label={@health_label} />
            <span class="cl-stat__meta">{@health_meta}</span>
          </div>
        </div>
      </.cl_page>
    </.cl_shell>
    """
  end

  # ---- count metadata copy (calm, reason-forward) --------------------------

  defp gaps_meta(_, true), do: "Count unavailable"
  defp gaps_meta(0, false), do: "No open knowledge gaps"
  defp gaps_meta(1, false), do: "gap waiting to become an article"
  defp gaps_meta(_, false), do: "gaps waiting to become articles"

  defp audit_meta(true), do: "Count unavailable"
  defp audit_meta(false), do: "Recent governed actions"

  # ---- health (same checks as SettingsLive) ---------------------------------

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

  # ---- defensive helpers ---------------------------------------------------

  # safe_count/1: returns {:ok, result} on success, :error on exception/throw.
  # Use with split/1 to get {integer, unavailable?} — keeps the integer at 0 on error
  # while raising a separate unavailable? signal so error ≠ calm-zero (D-06, T-39-07).
  @doc false
  def safe_count(fun) do
    {:ok, fun.()}
  rescue
    _ -> :error
  catch
    _, _ -> :error
  end

  # split/1: {:ok, n} when integer → {n, false}; anything else → {0, true} (fail-closed).
  @doc false
  def split({:ok, n}) when is_integer(n), do: {n, false}
  def split(_), do: {0, true}

  # safe/2: rescue/catch wrapper (preserved verbatim — other callers depend on it).
  defp safe(fun, fallback) do
    fun.()
  rescue
    _ -> fallback
  catch
    _, _ -> fallback
  end
end
