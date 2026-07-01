defmodule Cairnloop.Channels.WidgetSocketTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Channels.WidgetSocket

  defmodule RejectingVerifier do
    def verify(_token_or_params, _opts), do: {:error, :rejected}
  end

  setup do
    original_verifier = Application.get_env(:cairnloop, :widget_token_verifier)

    on_exit(fn ->
      restore_env(:widget_token_verifier, original_verifier)
    end)

    Application.delete_env(:cairnloop, :widget_token_verifier)
    {:ok, socket: %Phoenix.Socket{}}
  end

  describe "connect/3" do
    test "fails closed when a token is present but no verifier is configured", %{socket: socket} do
      assert {:error, :unauthorized} =
               WidgetSocket.connect(%{"token" => "browser-token"}, socket, %{})
    end

    test "uses the explicitly configured demo verifier to assign customer_ref", %{socket: socket} do
      Application.put_env(:cairnloop, :widget_token_verifier, Cairnloop.Widget.Verifier.Demo)

      assert {:ok, connected_socket} =
               WidgetSocket.connect(%{"token" => "customer_123"}, socket, %{})

      assert connected_socket.assigns.customer_ref == "customer_123"
      refute Map.has_key?(connected_socket.assigns, :user_token)
    end

    test "rejects verifier failures without assigning customer state", %{socket: socket} do
      Application.put_env(:cairnloop, :widget_token_verifier, RejectingVerifier)

      assert {:error, :unauthorized} =
               WidgetSocket.connect(%{"token" => "browser-token"}, socket, %{})
    end
  end

  describe "example app config" do
    test "opts into demo widget verification explicitly" do
      for path <- [
            "examples/cairnloop_example/config/dev.exs",
            "examples/cairnloop_example/config/test.exs"
          ] do
        source = File.read!(path)

        assert source =~ ":widget_token_verifier"
        assert source =~ "Cairnloop.Widget.Verifier.Demo"
      end
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:cairnloop, key)
  defp restore_env(key, value), do: Application.put_env(:cairnloop, key, value)
end
