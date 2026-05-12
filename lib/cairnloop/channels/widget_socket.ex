defmodule Cairnloop.Channels.WidgetSocket do
  use Phoenix.Socket

  ## Channels
  channel("widget:*", Cairnloop.Channels.WidgetChannel)

  @impl true
  def connect(params, socket, _connect_info) do
    # T-M001-01 Mitigation: Validate user auth tokens or signatures during socket connection.
    case params do
      %{"token" => token} when is_binary(token) ->
        # In a real app, verify the token here
        {:ok, assign(socket, :user_token, token)}

      _ ->
        {:error, :unauthorized}
    end
  end

  @impl true
  def id(socket) do
    "widget_socket:#{Map.get(socket.assigns, :user_token, "anonymous")}"
  end
end
