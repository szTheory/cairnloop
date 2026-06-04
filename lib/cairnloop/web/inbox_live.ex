defmodule Cairnloop.Web.InboxLive do
  @moduledoc """
  Inbox surface — list of conversations + Phase 25 bulk-recovery cockpit.

  ## Phase 25 responsibilities (decision-ID traceability)

  - **D-03 / D-04:** Per-row checkbox + `@selected_ids :: MapSet.t/0` assign;
    selection is LiveView-local, cleared on remount (no persistence).
  - **D-05 / research OQ4:** Sticky bulk-action bar appears at the BOTTOM of
    the inbox panel when `MapSet.size > 0`, shows the selection count, a
    `Clear selection` affordance, and a primary `Send recovery follow-up to N`
    button.
  - **D-06 / D-07:** Confirmation modal renders the count, the first-5 sample
    (`updated_at desc` ordering owned by `Cairnloop.Governance.preview_bulk_recovery_cohort/1`),
    `+N more` tail, and the SINGLE rendered template body snapshotted at
    confirm-open time.
  - **D-08 (Pitfall 6):** Cancel preserves `@selected_ids`. Success clears it.
  - **D-10 (brand §7.5):** Oversized cohorts render a calm refusal banner with
    inline SVG icon + `var(--cl-danger)` accent (never color-alone) and the
    `Confirm send` button is `disabled`.
  - **D-13:** Confirm calls `Cairnloop.Outbound.bulk_trigger/2` (through the
    `outbound_module()` indirection mirroring `conversation_live.ex`) with the
    snapshotted `:rendered_body` — the LiveView is the snapshot boundary.
  - **D-14:** Cohort eligibility goes through `Cairnloop.Governance` ONLY;
    `InboxLive` runs no direct Ecto queries (the Phase 25 plan acceptance grep
    asserts the `Conversation`-where pattern is absent from this file).

  ## Brand tokens (WR-03 / Phase 29 D-10 closure)

  Every brand color in this file uses the bare `var(--cl-<name>)` form —
  no inline hex fallback. The canonical token definitions live in
  `examples/cairnloop_example/assets/css/app.css` (copied from
  `prompts/cairnloop.css`). Enforcement: the BRAND-04 gate test at
  `test/cairnloop/web/brand_token_gate_test.exs` fails the build if any
  `var(--cl-<token>, #<hex>)` string is re-introduced in `lib/cairnloop/web/`
  or `examples/cairnloop_example/lib/cairnloop_example_web/live/`.

  Canonical tokens used in this file: `--cl-primary`, `--cl-on-primary`
  (aliased to `--cl-primary-text` in app.css), `--cl-surface`,
  `--cl-surface-raised`, `--cl-border`, `--cl-text`, `--cl-danger`.

  Non-canonical tokens that retain `rgba(...)` fallbacks (deferred to vM015): # cl-allow-color
  `--cl-text-soft`, `--cl-overlay`, `--cl-shadow`, `--cl-danger-soft`,
  `--cl-primary-disabled`, `--cl-surface-translucent`.
  """
  use Phoenix.LiveView

  import Cairnloop.Web.Components

  alias Cairnloop.Chat

  # ---------------------------------------------------------------------------
  # Module-private indirection (mirrors lib/cairnloop/web/conversation_live.ex
  # 1739-1745). Lets tests substitute stub Outbound / Governance modules and
  # reuses the Phase 24 recovery-template config knob (D-06).
  # ---------------------------------------------------------------------------

  defp outbound_module do
    Application.get_env(:cairnloop, :outbound_module, Cairnloop.Outbound)
  end

  defp governance_module do
    Application.get_env(:cairnloop, :governance_module, Cairnloop.Governance)
  end

  defp recovery_follow_up_template_id do
    Application.get_env(:cairnloop, :outbound_recovery_template_id)
  end

  # D-09 — defense-in-depth cap. The envelope (Plan 02) also enforces the cap;
  # the LiveView refusal is for UX so the operator sees a calm reason-forward
  # banner before the request even leaves the browser.
  defp max_batch_size do
    Application.get_env(:cairnloop, :max_batch_size, 25)
  end

  # ---------------------------------------------------------------------------
  # Mount.
  # ---------------------------------------------------------------------------

  def mount(_params, session, socket) do
    # Phase 28 D-09: subscribe to "conversations" topic on Cairnloop.PubSub when socket is
    # connected so the operator inbox refreshes whenever Chat.create_customer_conversation/1 or
    # Chat.ingest_widget_message/2 broadcasts {:conversations_changed}.
    # WR-02 note: this replaces the dead comment-only block from Phase 25. The `connected?/1`
    # guard ensures test environments (build_socket() is disconnected) don't subscribe, so
    # existing InboxLive tests continue to pass unchanged.
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversations")
    end

    # Phase 39 Plan 02 (D-01): list load moved to handle_params/3 to support the
    # ?status= filter. Mount seeds conversations: [] + status: nil so the existing
    # mount test (which asserts conversations == []) keeps passing (RESEARCH Pitfall 2:
    # avoids a double-query when LiveView calls mount → handle_params on every navigation).
    {:ok,
     assign(socket,
       conversations: [],
       status: nil,
       host_user_id: Map.get(session, "host_user_id"),
       # D-04: selection state is LiveView-local. No persistence across reloads —
       # each remount starts at an empty MapSet, which inherently satisfies the
       # "cleared on navigate-away" half of D-04.
       selected_ids: MapSet.new(),
       bulk_modal_open: false,
       bulk_preview: nil,
       bulk_refusal: nil
     )}
  end

  # ---------------------------------------------------------------------------
  # handle_params/3 — Phase 39 Plan 02 (D-01, HOME-02).
  # Reads ?status= query param (untrusted), normalizes it through the fail-closed
  # whitelist, loads the filtered conversation list, and reconciles selection state.
  # Called by LiveView on every navigation to /inbox (including initial mount).
  # ---------------------------------------------------------------------------

  def handle_params(params, _uri, socket) do
    status = normalize_status(params["status"])
    conversations = Chat.list_conversations(status: status)
    selected_ids = prune_selected_ids(socket.assigns.selected_ids, conversations)

    {:noreply,
     assign(socket,
       status: status,
       conversations: conversations,
       selected_ids: selected_ids
     )}
  end

  # ---------------------------------------------------------------------------
  # normalize_status/1 — Phase 39 Plan 02 (D-03 / T-39-03).
  # Fail-closed string whitelist: ONLY "resolved" maps to an atom. Everything
  # else (including "open", "garbage", SQL-injection probes, nil) returns nil
  # (unfiltered). NEVER calls String.to_existing_atom/String.to_atom on raw
  # input — prevents atom-table exhaustion and ArgumentError crashes from
  # attacker-controlled URL parameters.
  # Public so the pure whitelist tests can call it directly.
  # ---------------------------------------------------------------------------

  def normalize_status("resolved"), do: :resolved
  def normalize_status(_), do: nil

  # ---------------------------------------------------------------------------
  # Render.
  # ---------------------------------------------------------------------------

  def render(assigns) do
    ~H"""
    <.cl_shell current={:inbox} destinations={Cairnloop.Web.Nav.destinations()}>
      <.cl_page title="Inbox" width="wide">
        <.live_component
          module={Cairnloop.Web.SearchModalComponent}
          id="search-modal"
          host_surface="inbox"
          host_user_id={@host_user_id}
          current_path="/"
        />

        <div class="cairnloop-inbox">
          <%!-- Phase 39 Plan 02 (D-05): applied-filter row — visible ONLY when status=resolved
               is active. Composed from existing .cl-row + .cl-text-small utilities; the
               decorative .cl-applied-filter rule is owned and shipped by Plan 03 (the sole
               owner of priv/static/cairnloop.css this wave). No CSS is added here. --%>
          <%= if @status == :resolved do %>
            <div class="cl-applied-filter cl-row cl-text-small">
              <.cl_chip variant="success" label="Resolved" />
              <span>Showing resolved conversations ·</span>
              <.link patch="/inbox">Show all</.link>
            </div>
          <% end %>

          <%!-- Phase 39 Plan 02 (D-05): split empty state.
               - resolved filter active + empty → cl_empty with exact UI-SPEC copy (filtered-empty).
               - no filter + empty → existing calm sentence (genuinely empty inbox).
               Do NOT show the resolved copy on a genuinely empty inbox (D-05). --%>
          <%= if @conversations == [] do %>
            <%= if @status == :resolved do %>
              <.cl_empty title="No resolved conversations to recover">
                Nothing is waiting for a recovery follow-up right now.
                <.link navigate="/inbox">Show all conversations</.link>
              </.cl_empty>
            <% else %>
              <%!-- Phase 26 D-08: empty inbox state. Calm, reason-forward, brand-aligned (brand book §7.5). --%>
              <p class="inbox-empty-state cl-text-muted cl-text-small mt-4">
                No conversations yet.
              </p>
            <% end %>
          <% end %>

        <%= if has_visible_eligible?(@conversations) do %>
          <div class="cairnloop-inbox-bulk-header cl-row cl-list-row">
            <input
              type="checkbox"
              phx-click="toggle_select_all_visible"
              checked={all_visible_selected?(@conversations, @selected_ids)}
              aria-label="Select all visible resolved conversations"
            />
            <span class="cl-text-muted cl-text-small">Select all visible</span>
          </div>
        <% end %>

        <ul class="cl-stack">
          <%= for conv <- @conversations do %>
            <li class="cl-row cl-list-row">
              <%= if conv.status == :resolved do %>
                <input
                  type="checkbox"
                  phx-click="toggle_select"
                  phx-value-id={conv.id}
                  checked={MapSet.member?(@selected_ids, conv.id)}
                  aria-label={"Select conversation: #{conv.subject || "No subject"}"}
                />
              <% end %>
              <.link navigate={"/#{conv.id}"} class="cl-grow">
                <strong><%= conv.subject || "No Subject" %></strong>
              </.link>
              <.cl_chip variant={status_variant(conv.status)} label={status_label(conv.status)} />
            </li>
          <% end %>
        </ul>

        <%= if MapSet.size(@selected_ids) > 0 do %>
          <%!-- D-05 + research OQ4 — bottom-anchored sticky bulk action bar. --%>
          <div
            role="region"
            aria-label="Bulk actions"
            class="bulk-action-bar cl-inbox-bulk-bar cl-row cl-row--wrap"
          >
            <span><%= MapSet.size(@selected_ids) %> selected</span>
            <.cl_button variant="ghost" phx-click="clear_selection">
              Clear selection
            </.cl_button>
            <%!-- Brand §7.5 never-color-alone: text label AND the literal --cl-primary token
                  (test/integration assert the rendered HTML carries `var(--cl-primary)`). --%>
            <.cl_button variant="primary" phx-click="open_bulk_confirm" style="background: var(--cl-primary);">
              Send recovery follow-up to <%= MapSet.size(@selected_ids) %>
            </.cl_button>
          </div>
        <% end %>

        <%= if @bulk_modal_open do %>
          <%!-- D-07 / D-08 / D-10 — confirmation modal with focus trap. --%>
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="bulk-confirm-title"
            class="bulk-confirm-backdrop cl-overlay cl-row cl-modal-backdrop"
            phx-window-keydown="cancel_bulk_confirm"
            phx-key="Escape"
          >
            <.focus_wrap id="bulk-confirm-wrap">
              <div class="bulk-confirm-dialog cl-modal-dialog">
                <%!-- Phase 26 D-08: visible close affordance. Escape already works via phx-window-keydown. Anchored by position:relative on the dialog div. --%>
                <button
                  type="button"
                  phx-click="cancel_bulk_confirm"
                  aria-label="Close"
                  class="cl-modal-close"
                >
                  ×
                </button>

                <%= if @bulk_refusal do %>
                  <%!-- D-10 + brand §7.5 — refusal banner: icon + text + the literal --cl-danger
                       token (integration tests assert the rendered HTML carries `var(--cl-danger)`). --%>
                  <.cl_banner variant="danger" class="bulk-refusal" style="border-color: var(--cl-danger);">
                    <svg aria-hidden="true" width="20" height="20" viewBox="0 0 20 20" fill="none" class="cl-icon">
                      <circle cx="10" cy="10" r="9" stroke="currentColor" stroke-width="1.5"/>
                      <path d="M10 6v5M10 13.5v.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
                    </svg>
                    <div class="cl-stack">
                      <h2 id="bulk-confirm-title" class="cl-text-panel">
                        Batch too large.
                      </h2>
                      <p>
                        This batch exceeds the safe send limit of <%= @bulk_refusal.max %>.
                        Narrow your selection and try again.
                      </p>
                    </div>
                  </.cl_banner>

                  <div class="bulk-confirm-actions cl-row">
                    <.cl_button variant="ghost" phx-click="cancel_bulk_confirm">
                      Cancel
                    </.cl_button>
                    <.cl_button variant="primary" disabled aria-disabled="true">
                      Confirm send
                    </.cl_button>
                  </div>
                <% else %>
                  <h2 id="bulk-confirm-title" class="cl-text-title">
                    Send recovery follow-up
                  </h2>
                  <p>
                    You're about to send to <strong><%= @bulk_preview.count %></strong> conversation(s).
                  </p>

                  <section aria-label="First 5 recipients">
                    <ul class="cl-stack">
                      <%= for label <- @bulk_preview.sample do %>
                        <li><%= label %></li>
                      <% end %>
                    </ul>
                    <%= if @bulk_preview.more > 0 do %>
                      <p class="cl-text-muted cl-text-small">
                        + <%= @bulk_preview.more %> more
                      </p>
                    <% end %>
                  </section>

                  <section aria-label="Message body" class="cl-card">
                    <div class="cl-card__body">
                      <h3 class="cl-text-muted cl-text-small">
                        Message body
                      </h3>
                      <p class="cl-mono">
                        <%= @bulk_preview.rendered_body %>
                      </p>
                    </div>
                  </section>

                  <div class="bulk-confirm-actions cl-row">
                    <.cl_button variant="ghost" phx-click="cancel_bulk_confirm">
                      Cancel
                    </.cl_button>
                    <.cl_button variant="primary" phx-click="confirm_bulk_send">
                      Confirm send
                    </.cl_button>
                  </div>
                <% end %>
              </div>
            </.focus_wrap>
          </div>
        <% end %>
        </div>
      </.cl_page>
    </.cl_shell>
    """
  end

  # ---------------------------------------------------------------------------
  # PubSub info handlers (Phase 28).
  # ---------------------------------------------------------------------------

  # Phase 28 D-10: react to new conversations (create_customer_conversation/1) and new
  # messages (ingest_widget_message/2) that broadcast {:conversations_changed} on the
  # "conversations" topic of Cairnloop.PubSub. Subscribed in mount/3 above (D-09).
  # prune_selected_ids/2 is load-bearing — any conversation that disappears from the
  # list is automatically removed from @selected_ids to keep the bulk-bar count accurate
  # (WR-02 forward-compat fulfilled).
  # Phase 39 Plan 02 (D-04): re-query is filter-aware — passes socket.assigns.status so
  # a new :open conversation arriving over PubSub cannot leak into a resolved-filter view,
  # and stale bulk selections are pruned to prevent silent count inflation.
  def handle_info({:conversations_changed}, socket) do
    conversations = Chat.list_conversations(status: socket.assigns.status)
    selected_ids = prune_selected_ids(socket.assigns.selected_ids, conversations)
    {:noreply, assign(socket, conversations: conversations, selected_ids: selected_ids)}
  end

  # Fail-closed catch-all: an unexpected PubSub message must not crash the LiveView
  # (symmetric with HomeLive.handle_info/2).
  def handle_info(_msg, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # Event handlers — Task 1 (selection state).
  # ---------------------------------------------------------------------------

  def handle_event("toggle_select", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    selected = socket.assigns.selected_ids

    new_selected =
      if MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        MapSet.put(selected, id)
      end

    {:noreply, assign(socket, :selected_ids, new_selected)}
  end

  def handle_event("toggle_select_all_visible", _params, socket) do
    visible = visible_eligible_ids(socket.assigns.conversations)
    selected = socket.assigns.selected_ids

    new_selected =
      if visible != [] and Enum.all?(visible, &MapSet.member?(selected, &1)) do
        Enum.reduce(visible, selected, &MapSet.delete(&2, &1))
      else
        Enum.reduce(visible, selected, &MapSet.put(&2, &1))
      end

    {:noreply, assign(socket, :selected_ids, new_selected)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_ids, MapSet.new())}
  end

  # ---------------------------------------------------------------------------
  # Event handlers — Task 2 (modal + refusal + submit).
  # ---------------------------------------------------------------------------

  def handle_event("open_bulk_confirm", _params, socket) do
    ids = socket.assigns.selected_ids |> MapSet.to_list() |> Enum.sort()
    cap = max_batch_size()
    count = length(ids)
    template_id = recovery_follow_up_template_id()

    cond do
      count > cap ->
        # D-10 — calm refusal banner, no bulk_trigger/2 call.
        {:noreply,
         socket
         |> assign(:bulk_modal_open, true)
         |> assign(:bulk_refusal, %{count: count, max: cap})
         |> assign(:bulk_preview, nil)}

      not is_binary(template_id) ->
        # WR-06: fail-closed at the open-modal boundary when the recovery
        # template is misconfigured (nil, an atom, or any non-string).
        # Without this guard `render_bulk_body/1` silently returned an
        # empty string and the operator could confirm a bulk send with
        # rendered_body = "" — that empty string would then land on
        # BulkEnvelope.rendered_body as a durable record of "we sent an
        # empty message to N customers." Mirrors the calm operator copy
        # used in `confirm_bulk_send/2`'s nil-template branch (the
        # defense-in-depth check there remains as belt-and-suspenders).
        {:noreply,
         socket
         |> put_flash(:error, "Recovery follow-up template is not configured.")
         |> assign(:bulk_modal_open, false)
         |> assign(:bulk_preview, nil)
         |> assign(:bulk_refusal, nil)}

      true ->
        preview = governance_module().preview_bulk_recovery_cohort(ids)
        # T-25-03 mitigation — snapshot the body once at confirm-open time. v1
        # uses a pure function of template_id (no per-recipient personalization,
        # D-07) that mirrors `lib/cairnloop/outbound.ex` default content.
        rendered_body = render_bulk_body(template_id)

        # WR-06: persist the snapshot's `eligible_ids` (D-01 filtered cohort)
        # so `do_confirm_bulk_send/1` sends exactly what the operator was
        # shown — never the raw `selected_ids` set (which can drift in a
        # multi-tab scenario between modal-open and confirm). Also derive the
        # displayed count from the filtered eligible_ids so the count shown
        # equals the count actually sent (CLAUDE.md "snapshot trust facts at
        # decision time").
        eligible_ids = Map.get(preview, :eligible_ids, ids)
        eligible_count = length(eligible_ids)

        bulk_preview = %{
          count: eligible_count,
          eligible_ids: eligible_ids,
          sample: preview.sample,
          more: preview.more,
          rendered_body: rendered_body,
          template_id: template_id
        }

        {:noreply,
         socket
         |> assign(:bulk_modal_open, true)
         |> assign(:bulk_preview, bulk_preview)
         |> assign(:bulk_refusal, nil)}
    end
  end

  def handle_event("cancel_bulk_confirm", _params, socket) do
    # D-08 / Pitfall 6 — close the modal but PRESERVE @selected_ids so the
    # operator can adjust their cohort and re-open.
    {:noreply,
     socket
     |> assign(:bulk_modal_open, false)
     |> assign(:bulk_preview, nil)
     |> assign(:bulk_refusal, nil)}
  end

  def handle_event("confirm_bulk_send", _params, socket) do
    cond do
      is_nil(recovery_follow_up_template_id()) ->
        # Mirrors conversation_live.ex:207 calm operator copy.
        {:noreply,
         socket
         |> put_flash(:error, "Recovery follow-up template is not configured.")
         |> assign(:bulk_modal_open, false)
         |> assign(:bulk_preview, nil)
         |> assign(:bulk_refusal, nil)}

      socket.assigns.bulk_refusal != nil ->
        # Defensive — the Confirm button is disabled in markup, but if we get
        # here (e.g., a keyboard activation) we close the modal without sending.
        {:noreply,
         socket
         |> assign(:bulk_modal_open, false)
         |> assign(:bulk_refusal, nil)}

      true ->
        do_confirm_bulk_send(socket)
    end
  end

  defp do_confirm_bulk_send(socket) do
    preview = socket.assigns.bulk_preview
    actor = socket.assigns.host_user_id

    # WR-06: send the snapshot's `eligible_ids` (what the operator was shown
    # in the modal), NOT the raw `selected_ids` MapSet. Between modal-open
    # and modal-confirm two things can drift the cohort:
    #   1. A peer LiveView in another tab could resolve/unresolve a
    #      conversation, leaving this tab's `@conversations` and
    #      `@selected_ids` referring to a now-ineligible id.
    #   2. The preview's `eligible_ids` (which honors D-01 "resolved only")
    #      was previously captured into `bulk_preview.count` but never fed
    #      back as the ground-truth `ids` to send.
    # Using `preview.eligible_ids` makes the snapshot guarantee explicit:
    # what was shown is what is sent (CLAUDE.md "snapshot trust facts at
    # decision time"). Fall back to selected_ids only if a (pre-WR-06)
    # preview struct lacks the key — defense-in-depth for stale assigns.
    ids =
      case preview do
        %{eligible_ids: eligible} when is_list(eligible) ->
          eligible

        _ ->
          socket.assigns.selected_ids |> MapSet.to_list() |> Enum.sort()
      end

    opts = [
      template_id: preview.template_id,
      rendered_body: preview.rendered_body,
      actor: actor
    ]

    case outbound_module().bulk_trigger(ids, opts) do
      {:ok, _results} ->
        {:noreply,
         socket
         |> put_flash(:info, "Bulk recovery queued for #{length(ids)} conversations.")
         |> assign(:selected_ids, MapSet.new())
         |> assign(:bulk_modal_open, false)
         |> assign(:bulk_preview, nil)
         |> assign(:bulk_refusal, nil)}

      {:error, :batch_too_large} ->
        # Reuse the inline-banner copy vocabulary. Selection preserved so
        # operator can narrow.
        {:noreply,
         socket
         |> put_flash(
           :error,
           "This batch exceeds the safe send limit. Narrow your selection and try again."
         )
         |> assign(:bulk_modal_open, false)
         |> assign(:bulk_preview, nil)
         |> assign(:bulk_refusal, nil)}

      # CR-01: `Outbound.bulk_trigger/2`'s happy path returns
      # `repo().transaction(multi)` directly from inside its telemetry span.
      # `Ecto.Multi` failure is the 4-tuple
      # `{:error, failed_operation, failed_value, changes_so_far}`. Match it
      # BEFORE the 2-tuple catch-all so a per-recipient `Message` changeset
      # error (FK violation, metadata size limit, etc.) does NOT crash the
      # LiveView with `FunctionClauseError` and surface the generic Phoenix
      # overlay instead of the planned calm operator copy. Selection is
      # preserved so the operator can adjust the cohort and retry.
      {:error, _failed_op, _failed_value, _changes} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Recovery follow-up could not be queued right now. Please try again."
         )
         |> assign(:bulk_modal_open, false)
         |> assign(:bulk_preview, nil)
         |> assign(:bulk_refusal, nil)}

      {:error, _other} ->
        # Generic calm copy (mirrors conversation_live.ex:225). Selection preserved.
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Recovery follow-up could not be queued right now. Please try again."
         )
         |> assign(:bulk_modal_open, false)
         |> assign(:bulk_preview, nil)
         |> assign(:bulk_refusal, nil)}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers.
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Status presentation (brand §7.5 — color + icon + text, never a raw atom).
  # Maps a conversation status to a cl_chip variant + humanized label.
  # ---------------------------------------------------------------------------

  defp status_variant(:resolved), do: "success"
  defp status_variant(:open), do: "info"
  defp status_variant(:awaiting_customer), do: "warning"
  defp status_variant(:new), do: "ai"
  defp status_variant(_), do: "neutral"

  defp status_label(:resolved), do: "Resolved"
  defp status_label(:open), do: "Open"
  defp status_label(:awaiting_customer), do: "Awaiting customer"
  defp status_label(:new), do: "New"

  defp status_label(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp status_label(status), do: to_string(status)

  defp visible_eligible_ids(conversations) do
    conversations
    |> Enum.filter(&(&1.status == :resolved))
    |> Enum.map(& &1.id)
  end

  defp has_visible_eligible?(conversations) do
    Enum.any?(conversations, &(&1.status == :resolved))
  end

  defp all_visible_selected?(conversations, selected_ids) do
    visible = visible_eligible_ids(conversations)
    visible != [] and Enum.all?(visible, &MapSet.member?(selected_ids, &1))
  end

  # WR-02 forward-compat: prune `selected_ids` against the currently rendered
  # conversations list. When pubsub lands (see `mount/3`), routing peer-LiveView
  # `:conversations` updates through this helper keeps `@selected_ids` in lockstep
  # with what's actually rendered — a no-longer-visible conversation remaining
  # selected would silently inflate the bulk-bar count and is a known footgun.
  # Doc-only at present; wired but unused until a pubsub surface exists.
  @doc false
  def prune_selected_ids(selected_ids, conversations) when is_list(conversations) do
    visible_ids = conversations |> Enum.map(& &1.id) |> MapSet.new()
    MapSet.intersection(selected_ids, visible_ids)
  end

  # v1: render is a pure function of template_id (no per-recipient
  # personalization per D-07). Matches the default content string in
  # `lib/cairnloop/outbound.ex` so the body operators confirm is exactly the
  # body recipients receive (T-25-03 snapshot integrity).
  defp render_bulk_body(template_id) when is_binary(template_id) do
    "Outbound message using template: #{template_id}"
  end

  defp render_bulk_body(_), do: ""
end
