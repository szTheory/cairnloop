defmodule CairnloopExampleWeb.ChatLive do
  use CairnloopExampleWeb, :live_view

  alias Cairnloop.Chat

  # ---------------------------------------------------------------------------
  # Mount — D-02/D-03: initialize the four assigns; do NOT subscribe at mount
  # because the conversation_id is unknown until the JS hook calls back.
  # ---------------------------------------------------------------------------

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:messages, [])
      |> assign(:channel_status, :connecting)
      |> assign(:pending, false)
      |> assign(:conversation_id, nil)
      |> assign(:send_error, false)

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Render — UI-SPEC §1 contract: brand tokens, ARIA, 6 locked copy strings
  # ---------------------------------------------------------------------------

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-4 min-h-screen flex flex-col">
      <%!-- The hook root element: phx-hook=".WidgetChat" uses the leading-dot colocated syntax --%>
      <div
        id="widget-chat-root"
        phx-hook=".WidgetChat"
        data-token="demo_customer"
        class="cl-card flex flex-col flex-1"
        style="background: var(--cl-surface, #FBF7EE); border: 1px solid var(--cl-border, #D8D0BF); border-radius: var(--cl-radius-lg, 14px); padding: 24px;"
      >
        <%!-- Panel header: title + connection state indicator --%>
        <div class="flex items-center justify-between mb-4 pb-4" style="border-bottom: 1px solid var(--cl-border, #D8D0BF);">
          <h1 style="font-size: 18px; font-weight: 600; color: var(--cl-text, #18211F); margin: 0;">
            Cairnloop Support
          </h1>
          <%!-- Connection state dot+label — brand §7.5: never color alone --%>
          <div class="flex items-center gap-2">
            <span
              style={"width: 8px; height: 8px; border-radius: 50%; background: #{connection_dot_color(@channel_status)};"}
              aria-hidden="true"
            >
            </span>
            <span style="font-size: 13px; color: var(--cl-text-muted, #677066);">
              <%= connection_label(@channel_status) %>
            </span>
          </div>
        </div>

        <%!-- Channel join error — rendered when channel_status is :disconnected and no conversation_id yet --%>
        <%= if @channel_status == :disconnected and is_nil(@conversation_id) do %>
          <p role="alert" style="font-size: 13px; color: var(--cl-error, #B23B2C); margin-bottom: 8px;">
            Could not connect to support. Refresh the page to try again.
          </p>
        <% end %>

        <%!-- Message thread: role="log" aria-live="polite" per UI-SPEC §1a accessibility --%>
        <div
          role="log"
          aria-live="polite"
          class="flex-1 overflow-y-auto mb-4"
          style="min-height: 300px;"
        >
          <%= if @messages == [] do %>
            <%!-- Empty state --%>
            <p class="italic text-center mt-10" style="font-size: 15px; color: var(--cl-text-muted, #677066);">
              How can we help you today?
            </p>
          <% else %>
            <%= for msg <- @messages do %>
              <div class={"flex mb-3 #{if msg.role == :customer, do: "justify-end", else: "justify-start"}"}>
                <div
                  aria-label="Chat message"
                  class="max-w-[75%] px-4 py-2 rounded-lg"
                  style={bubble_style(msg.role)}
                >
                  <p style="margin: 0; font-size: 15px; line-height: 1.6;">
                    <%= msg.content %>
                  </p>
                </div>
              </div>
            <% end %>
          <% end %>

          <%!-- Pending row — plain text, NOT a bubble (UI-SPEC §1b explicit) --%>
          <%= if @pending do %>
            <p style="font-size: 13px; color: var(--cl-text-muted, #677066); margin-top: 4px;">
              Message sent — waiting on operator.
            </p>
          <% end %>

          <%!-- Send error row — rendered when hook reports a channel push error (T-28-03-07) --%>
          <%= if @send_error do %>
            <p role="alert" style="font-size: 13px; color: var(--cl-error, #B23B2C); margin-top: 4px;">
              Your message could not be sent. Check your connection and try again.
            </p>
          <% end %>
        </div>

        <%!-- Input form — phx-submit="send_message" (UI-SPEC §1c) --%>
        <form
          phx-submit="send_message"
          class="flex gap-2 mt-4 pt-4"
          style="border-top: 1px solid var(--cl-border, #D8D0BF);"
        >
          <input
            type="text"
            name="message"
            placeholder="Type your message…"
            aria-label="Type your message"
            required
            class="flex-1 px-3 py-2"
            style="background: var(--cl-surface-raised, #FFFFFF); border: 1px solid var(--cl-border, #D8D0BF); border-radius: var(--cl-radius-md, 10px); font-size: 15px; outline: none; box-shadow: none;"
          />
          <%!-- Send button: min-h-[44px] per brand §16.2 touch target --%>
          <button
            type="submit"
            class="phx-submit-loading:opacity-50 min-h-[44px] px-4 py-2 rounded-md hover:opacity-90"
            style="background: var(--cl-primary, #A94F30); color: var(--cl-primary-text, #FFFFFF); font-size: 15px; font-weight: 500; border: none; cursor: pointer;"
          >
            Send
          </button>
        </form>
      </div>
    </div>

    <%!-- Colocated WidgetChat JS hook — D-11/D-12/D-13, CHAT-02.
         CRITICAL: this script is extracted to a standalone ES module at compile time
         by phoenix_live_view's colocated-hook macro. The import below (Pitfall 4)
         is load-bearing — app.js's Socket import is NOT inherited by the extracted module. --%>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".WidgetChat">
      import {Socket} from "phoenix"

      export default {
        mounted() {
          const token = this.el.dataset.token || "demo_customer"
          const socket = new Socket("/widget", {params: {token}})
          this.socket = socket
          socket.connect()

          // Push channel_status events to the LiveView on WebSocket lifecycle events.
          // D-12: LV handle_event("channel_status", ...) uses a closed case over known strings
          // to map status values to atoms safely (T-28-03-04 DoS mitigation).
          socket.onOpen(() => this.pushEvent("channel_status", {status: "connected"}))
          socket.onError(() => this.pushEvent("channel_status", {status: "disconnected"}))
          socket.onClose(() => this.pushEvent("channel_status", {status: "disconnected"}))

          this.channel = socket.channel("widget:lobby", {})
          this.channel.join()
            .receive("ok", ({conversation_id}) => {
              // D-02: hook delivers the conversation_id to the LV so it can subscribe
              // to the per-conversation PubSub topic after the join reply is received.
              this.pushEvent("conversation_id", {id: conversation_id})
            })
            .receive("error", () => {
              this.pushEvent("channel_status", {status: "disconnected"})
            })

          // D-13: LV pushes "widget:send" when the customer submits a message.
          // The hook forwards it to the channel. T-28-03-07: on channel push error,
          // notify LV to render the send-error alert row.
          this.handleEvent("widget:send", ({content}) => {
            if (!this.channel) return
            this.channel.push("new_message", {content})
              .receive("error", () => this.pushEvent("send_error", {}))
          })
        },
        destroyed() {
          if (this.channel) this.channel.leave()
          if (this.socket) this.socket.disconnect()
        }
      }
    </script>
    """
  end

  # ---------------------------------------------------------------------------
  # handle_event("conversation_id", ...) — D-02
  # Called by the JS hook after the channel join reply delivers the conversation_id.
  # Subscribes to the per-conversation PubSub topic (gated on connected?/1 — defensive,
  # consistent with ConversationLive's mount-time subscribe pattern).
  # ---------------------------------------------------------------------------

  def handle_event("conversation_id", %{"id" => id}, socket) do
    # D-02: subscribe is gated on connected?(socket) — handle_event only fires on a
    # connected socket in practice, but the gate keeps the convention consistent with
    # ConversationLive's mount/3 subscribe pattern and is harmless when false.
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:#{id}")
    end

    {:noreply,
     socket
     |> assign(:conversation_id, id)
     |> assign(:channel_status, :connected)}
  end

  # ---------------------------------------------------------------------------
  # handle_event("channel_status", ...) — D-03, T-28-03-04
  # A closed case is used instead of String.to_existing_atom/1 to eliminate the
  # ArgumentError crash surface on unexpected input (CR-01 fix). Unknown status
  # strings preserve the current channel_status assign unchanged rather than crashing.
  # ---------------------------------------------------------------------------

  def handle_event("channel_status", %{"status" => status}, socket) do
    atom =
      case status do
        "connecting" -> :connecting
        "connected" -> :connected
        "disconnected" -> :disconnected
        # unknown status: preserve current state rather than crashing
        _ -> socket.assigns.channel_status
      end

    {:noreply, assign(socket, :channel_status, atom)}
  end

  # ---------------------------------------------------------------------------
  # handle_event("send_message", ...) — D-13, Behavior 4
  # Optimistically append the customer's message, set pending: true,
  # clear send_error, and push "widget:send" to the JS hook.
  # ---------------------------------------------------------------------------

  def handle_event("send_message", %{"message" => text}, socket)
      when is_binary(text) and text != "" do
    optimistic = %{role: :customer, content: text, inserted_at: DateTime.utc_now()}

    socket =
      socket
      |> assign(:messages, socket.assigns.messages ++ [optimistic])
      |> assign(:pending, true)
      |> assign(:send_error, false)
      |> push_event("widget:send", %{content: text})

    {:noreply, socket}
  end

  # Fallback for empty or non-binary message — no-op (no crash, no state change).
  def handle_event("send_message", _params, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------------------
  # handle_event("send_error", ...) — T-28-03-07
  # Called by the JS hook when channel.push.receive("error") fires.
  # WR-03 fix: drop the last optimistically-appended message (the one that failed)
  # and clear the pending indicator, in addition to setting send_error: true.
  # Without this, the failed message remains as a ghost entry in @messages, and
  # the pending indicator is never cleared — both causing confusing UI state.
  # ---------------------------------------------------------------------------

  def handle_event("send_error", _params, socket) do
    # Drop the last optimistically-appended message (the failed one) and clear pending.
    messages = socket.assigns.messages |> Enum.drop(-1)

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:pending, false)
     |> assign(:send_error, true)}
  end

  # ---------------------------------------------------------------------------
  # handle_info({:message_created, msg_id}, ...) — Pitfall 7 role-dedup
  # Called when PubSub broadcasts on "conversation:#{id}" (from
  # Chat.reply_to_conversation/4's OQ-1 additive broadcast).
  # Only :agent-role messages are appended to @messages — the customer's own
  # :user-role messages are already rendered optimistically, so they are skipped
  # here to prevent duplication (Pitfall 7 dedup-by-role).
  # A nil return (stale id) is also skipped to prevent crashing the customer's tab.
  # ---------------------------------------------------------------------------

  def handle_info({:message_created, msg_id}, socket) do
    # Use the Chat.get_message/1 narrow read-side facade (additive, Plan 03).
    # Returns %Cairnloop.Message{} or nil (tolerant lookup — never raises).
    case Chat.get_message(msg_id) do
      %Cairnloop.Message{role: :agent, content: content, inserted_at: inserted_at} ->
        # Operator reply: append to thread and clear the pending indicator.
        operator_msg = %{role: :operator, content: content, inserted_at: inserted_at}

        {:noreply,
         socket
         |> assign(:messages, socket.assigns.messages ++ [operator_msg])
         |> assign(:pending, false)}

      _ ->
        # :user role (customer's own message round-tripping back) or nil (stale id) — skip.
        # Staying true to the dedup-by-role contract: the customer sees their message
        # because it was optimistically appended in handle_event("send_message", ...).
        {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers for rendering
  # ---------------------------------------------------------------------------

  defp connection_label(:connecting), do: "Connecting…"
  defp connection_label(:connected), do: "Connected"
  defp connection_label(:disconnected), do: "Disconnected — reconnecting"

  defp connection_dot_color(:connecting), do: "var(--cl-text-muted, #677066)"
  defp connection_dot_color(:connected), do: "var(--cl-success, #2D7A3A)"
  defp connection_dot_color(:disconnected), do: "var(--cl-danger, #B54C36)"

  defp bubble_style(:customer) do
    "background: var(--cl-primary, #A94F30); color: var(--cl-primary-text, #FFFFFF);"
  end

  defp bubble_style(:operator) do
    "background: var(--cl-surface-raised, #FFFFFF); color: var(--cl-text, #18211F); border: 1px solid var(--cl-border, #D8D0BF);"
  end

  defp bubble_style(_), do: "background: var(--cl-surface-raised, #FFFFFF); color: var(--cl-text, #18211F);"
end
