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

  ## Brand tokens (WR-03)

  Every color in this file is expressed as `var(--cl-<name>, <hex-or-rgba>)`
  so a host stylesheet can override the cascade without touching this file.
  The fallback values are inline so headless tests can assert the brand-token
  vocabulary in rendered HTML (see `inbox_live_test.exs` "var(--cl-primary" /
  "var(--cl-danger" gates). Future cleanup may extract the duplicated button
  declarations (`min-height: 44px; padding: 10px 16px; border-radius: 8px;`)
  to a stylesheet class once the project has a CSS pipeline; until then,
  keeping the brand tokens visible in HTML is the test contract.

  Token vocabulary used here (additive to `--cl-primary` / `--cl-surface` /
  `--cl-surface-raised` / `--cl-border` / `--cl-text` / `--cl-danger` that
  already exist in the codebase): `--cl-on-primary` (text on primary brand),
  `--cl-text-muted` (62% text alpha), `--cl-text-soft` (72% text alpha),
  `--cl-overlay` (modal scrim), `--cl-primary-disabled` (disabled-primary
  tint), `--cl-surface-translucent` (translucent panel), `--cl-danger-soft`
  (danger banner tint), `--cl-shadow` (elevation shadow).
  """
  use Phoenix.LiveView

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
    # WR-02: previously a dead `if connected?(socket) do …end` block lived
    # here whose body was a placeholder comment. The `if` evaluated to `nil`
    # and the result was discarded — dead control flow with no phase tracking.
    # When pubsub becomes load-bearing (future phase — most likely Phase 26
    # OBS-01 or whichever phase first ships peer-LiveView coordination),
    # subscribe here and ALSO route the resulting `:conversations` updates
    # through `prune_selected_ids/2` so `@selected_ids` stays consistent
    # with what's actually rendered (a no-longer-visible conversation
    # remaining selected inflates the bulk-bar "N selected" copy and is a
    # silent footgun). Until that surface exists, the helper is wired but
    # unused; mount/3 does not subscribe.

    conversations = Chat.list_conversations()

    {:ok,
     assign(socket,
       conversations: conversations,
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
  # Render.
  # ---------------------------------------------------------------------------

  def render(assigns) do
    ~H"""
    <div class="cairnloop-inbox">
      <h1>Inbox</h1>

      <%= if @conversations == [] do %>
        <%!-- Phase 26 D-08: empty inbox state. Calm, reason-forward, brand-aligned (brand book §7.5). --%>
        <p
          class="inbox-empty-state"
          style="margin-top: 12px; font-size: 14px; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62));"
        >
          No conversations yet.
        </p>
      <% end %>

      <%= if has_visible_eligible?(@conversations) do %>
        <div class="cairnloop-inbox-bulk-header" style="display: flex; align-items: center; gap: 8px; padding: 8px 0;">
          <input
            type="checkbox"
            phx-click="toggle_select_all_visible"
            checked={all_visible_selected?(@conversations, @selected_ids)}
            aria-label="Select all visible resolved conversations"
          />
          <span style="font-size: 14px; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62));">Select all visible</span>
        </div>
      <% end %>

      <ul>
        <%= for conv <- @conversations do %>
          <li>
            <%= if conv.status == :resolved do %>
              <input
                type="checkbox"
                phx-click="toggle_select"
                phx-value-id={conv.id}
                checked={MapSet.member?(@selected_ids, conv.id)}
                aria-label={"Select conversation: #{conv.subject || "No subject"}"}
              />
            <% end %>
            <.link navigate={"/#{conv.id}"}>
              <strong><%= conv.subject || "No Subject" %></strong>
              - <%= conv.status %>
            </.link>
          </li>
        <% end %>
      </ul>

      <%= if MapSet.size(@selected_ids) > 0 do %>
        <%!-- D-05 + research OQ4 — bottom-anchored sticky bulk action bar. --%>
        <div
          role="region"
          aria-label="Bulk actions"
          class="bulk-action-bar"
          style="position: sticky; bottom: 0; background: var(--cl-surface-raised, #FFFFFF); border-top: 1px solid var(--cl-border, #D8D0BF); padding: 12px 16px; display: flex; gap: 12px; align-items: center; z-index: 10;"
        >
          <span><%= MapSet.size(@selected_ids) %> selected</span>
          <button
            type="button"
            phx-click="clear_selection"
            style="min-height: 44px; padding: 10px 16px; border-radius: 8px; border: 1px solid var(--cl-border, #D8D0BF); background: transparent; color: var(--cl-text, #2f241d);"
          >
            Clear selection
          </button>
          <button
            type="button"
            phx-click="open_bulk_confirm"
            style="background: var(--cl-primary, #A94F30); color: var(--cl-on-primary, #fffdf8); border-radius: 8px; min-height: 44px; padding: 10px 16px; border: none; font-weight: 600;"
          >
            Send recovery follow-up to <%= MapSet.size(@selected_ids) %>
          </button>
        </div>
      <% end %>

      <%= if @bulk_modal_open do %>
        <%!-- D-07 / D-08 / D-10 — confirmation modal with focus trap. --%>
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="bulk-confirm-title"
          class="bulk-confirm-backdrop"
          style="position: fixed; inset: 0; background: var(--cl-overlay, rgba(44, 38, 31, 0.42)); display: flex; justify-content: center; align-items: flex-start; padding: 64px 16px; z-index: 50;"
          phx-window-keydown="cancel_bulk_confirm"
          phx-key="Escape"
        >
          <.focus_wrap id="bulk-confirm-wrap">
            <div
              class="bulk-confirm-dialog"
              style="position: relative; background: var(--cl-surface, #FBF7EE); color: var(--cl-text, #2f241d); border-radius: 18px; width: min(640px, 92vw); max-height: 78vh; box-shadow: 0 24px 60px var(--cl-shadow, rgba(47, 36, 29, 0.18)); overflow: hidden; display: flex; flex-direction: column; padding: 24px;"
            >
              <%!-- Phase 26 D-08: visible close affordance. Escape already works via phx-window-keydown. Anchored by position:relative on the dialog div. --%>
              <button
                type="button"
                phx-click="cancel_bulk_confirm"
                aria-label="Close"
                style="position: absolute; top: 12px; right: 12px; min-width: 44px; min-height: 44px; border: none; background: transparent; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62)); font-size: 24px; line-height: 1; cursor: pointer; padding: 0;"
              >
                ×
              </button>

              <%= if @bulk_refusal do %>
                <%!-- D-10 + brand §7.5 — refusal banner: icon + text + danger token. --%>
                <div
                  role="alert"
                  class="bulk-refusal"
                  style="background: var(--cl-danger-soft, rgba(181, 76, 54, 0.08)); border: 1px solid var(--cl-danger, #B54C36); padding: 16px; border-radius: 12px; display: flex; gap: 12px; align-items: flex-start;"
                >
                  <svg aria-hidden="true" width="20" height="20" viewBox="0 0 20 20" fill="none" style="flex-shrink: 0; color: var(--cl-danger, #B54C36); margin-top: 2px;">
                    <circle cx="10" cy="10" r="9" stroke="currentColor" stroke-width="1.5"/>
                    <path d="M10 6v5M10 13.5v.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
                  </svg>
                  <div>
                    <h2 id="bulk-confirm-title" style="margin: 0; font-size: 18px; line-height: 1.3; font-weight: 600;">
                      Batch too large.
                    </h2>
                    <p style="margin: 6px 0 0; font-size: 16px; line-height: 1.5;">
                      This batch exceeds the safe send limit of <%= @bulk_refusal.max %>.
                      Narrow your selection and try again.
                    </p>
                  </div>
                </div>

                <div class="bulk-confirm-actions" style="display: flex; gap: 12px; justify-content: flex-end; margin-top: 20px;">
                  <button
                    type="button"
                    phx-click="cancel_bulk_confirm"
                    style="min-height: 44px; padding: 10px 16px; border-radius: 8px; border: 1px solid var(--cl-border, #D8D0BF); background: transparent; color: var(--cl-text, #2f241d);"
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    disabled
                    aria-disabled="true"
                    style="min-height: 44px; padding: 10px 16px; border-radius: 8px; border: none; background: var(--cl-primary-disabled, rgba(169, 79, 48, 0.36)); color: var(--cl-on-primary, #fffdf8); font-weight: 600; cursor: not-allowed;"
                  >
                    Confirm send
                  </button>
                </div>
              <% else %>
                <h2 id="bulk-confirm-title" style="margin: 0 0 8px; font-size: 22px; line-height: 1.2; font-weight: 600;">
                  Send recovery follow-up
                </h2>
                <p style="margin: 0 0 16px; font-size: 16px; line-height: 1.5;">
                  You're about to send to <strong><%= @bulk_preview.count %></strong> conversation(s).
                </p>

                <section aria-label="First 5 recipients" style="margin-bottom: 16px;">
                  <ul style="list-style: none; padding: 0; margin: 0; display: grid; gap: 4px; font-size: 14px;">
                    <%= for label <- @bulk_preview.sample do %>
                      <li><%= label %></li>
                    <% end %>
                  </ul>
                  <%= if @bulk_preview.more > 0 do %>
                    <p style="margin: 8px 0 0; font-size: 14px; color: var(--cl-text-muted, rgba(47, 36, 29, 0.62));">
                      + <%= @bulk_preview.more %> more
                    </p>
                  <% end %>
                </section>

                <section aria-label="Message body" style="margin-bottom: 24px; padding: 16px; border-radius: 12px; background: var(--cl-surface-translucent, rgba(255, 255, 255, 0.72));">
                  <h3 style="margin: 0 0 8px; font-size: 14px; font-weight: 600; color: var(--cl-text-soft, rgba(47, 36, 29, 0.72)); text-transform: uppercase; letter-spacing: 0.04em;">
                    Message body
                  </h3>
                  <p style="margin: 0; font-size: 16px; line-height: 1.5; white-space: pre-wrap;">
                    <%= @bulk_preview.rendered_body %>
                  </p>
                </section>

                <div class="bulk-confirm-actions" style="display: flex; gap: 12px; justify-content: flex-end;">
                  <button
                    type="button"
                    phx-click="cancel_bulk_confirm"
                    style="min-height: 44px; padding: 10px 16px; border-radius: 8px; border: 1px solid var(--cl-border, #D8D0BF); background: transparent; color: var(--cl-text, #2f241d);"
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    phx-click="confirm_bulk_send"
                    style="background: var(--cl-primary, #A94F30); color: var(--cl-on-primary, #fffdf8); border-radius: 8px; min-height: 44px; padding: 10px 16px; border: none; font-weight: 600;"
                  >
                    Confirm send
                  </button>
                </div>
              <% end %>
            </div>
          </.focus_wrap>
        </div>
      <% end %>
    </div>
    <.live_component
      module={Cairnloop.Web.SearchModalComponent}
      id="search-modal"
      host_surface="inbox"
      host_user_id={@host_user_id}
      current_path="/"
    />
    """
  end

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

    if count > cap do
      # D-10 — calm refusal banner, no bulk_trigger/2 call.
      {:noreply,
       socket
       |> assign(:bulk_modal_open, true)
       |> assign(:bulk_refusal, %{count: count, max: cap})
       |> assign(:bulk_preview, nil)}
    else
      preview = governance_module().preview_bulk_recovery_cohort(ids)
      template_id = recovery_follow_up_template_id()
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
