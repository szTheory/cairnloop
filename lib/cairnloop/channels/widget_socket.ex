defmodule Cairnloop.Channels.WidgetSocket do
  use Phoenix.Socket

  ## Channels
  channel("widget:*", Cairnloop.Channels.WidgetChannel)

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) when is_binary(token) do
    case verify_widget_token(token) do
      {:ok, %{customer_ref: customer_ref}} when is_binary(customer_ref) and customer_ref != "" ->
        {:ok, assign(socket, :customer_ref, customer_ref)}

      _ ->
        {:error, :unauthorized}
    end
  end

  def connect(_params, _socket, _connect_info), do: {:error, :unauthorized}

  @impl true
  def id(socket) do
    "widget_socket:#{Map.get(socket.assigns, :customer_ref, "anonymous")}"
  end

  defp verify_widget_token(token) do
    {verifier, opts} = widget_verifier()

    with {:module, ^verifier} <- Code.ensure_loaded(verifier),
         true <- function_exported?(verifier, :verify, 2) do
      verifier.verify(token, opts)
    else
      _ -> {:error, :invalid_verifier}
    end
  end

  defp widget_verifier do
    case Application.get_env(:cairnloop, :widget_token_verifier) do
      {module, opts} when is_atom(module) and is_list(opts) ->
        {module, opts}

      module when is_atom(module) ->
        {module, []}

      _other ->
        {Cairnloop.Widget.Verifier.FailClosed, []}
    end
  end
end
