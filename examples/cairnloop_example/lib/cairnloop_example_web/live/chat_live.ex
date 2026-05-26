defmodule CairnloopExampleWeb.ChatLive do
  use CairnloopExampleWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :messages, [])}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto p-4">
      <h1 class="text-2xl font-bold mb-4">Cairnloop Support</h1>
      <div class="bg-white shadow rounded-lg p-6 min-h-[400px] flex flex-col">
        <div class="flex-1 overflow-y-auto mb-4 border-b pb-4">
          <%= if Enum.empty?(@messages) do %>
            <p class="text-gray-500 italic text-center mt-10">How can we help you today?</p>
          <% else %>
            <%= for msg <- @messages do %>
              <div class={"mb-2 #{if msg.role == :user, do: "text-right", else: "text-left"}"}>
                <span class={"inline-block px-4 py-2 rounded-lg #{if msg.role == :user, do: "bg-cl-primary text-white", else: "bg-gray-100"}"}>
                  <%= msg.content %>
                </span>
              </div>
            <% end %>
          <% end %>
        </div>

        <form phx-submit="send_message" class="flex gap-2">
          <input type="text" name="message" class="flex-1 border rounded px-3 py-2" placeholder="Type your message..." required />
          <button type="submit" class="bg-cl-primary text-white px-4 py-2 rounded hover:opacity-90">Send</button>
        </form>
      </div>
    </div>
    """
  end

  def handle_event("send_message", %{"message" => text}, socket) do
    # In a real app this would call Cairnloop.Chat.send_message
    # but for a demo UI we'll just push it to the socket.
    messages = socket.assigns.messages ++ [%{role: :user, content: text}]
    
    # Simulate a delayed bot reply
    Process.send_after(self(), :bot_reply, 1000)
    
    {:noreply, assign(socket, :messages, messages)}
  end
  
  def handle_info(:bot_reply, socket) do
    messages = socket.assigns.messages ++ [%{role: :bot, content: "We have received your message and an operator will be with you shortly. Support that leaves a trail."}]
    {:noreply, assign(socket, :messages, messages)}
  end
end
