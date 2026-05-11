defmodule Cairnloop.Channels.WidgetChannelTest do
  use ExUnit.Case, async: false
  alias Cairnloop.Channels.WidgetChannel

  defmodule MockRepo do
    def get!(Cairnloop.Conversation, id) do
      %Cairnloop.Conversation{
        id: String.to_integer(id),
        status: :open
      }
    end

    def update(%Ecto.Changeset{} = changeset) do
      if changeset.changes[:csat_rating] in [:positive, :negative] do
        {:ok, Ecto.Changeset.apply_changes(changeset)}
      else
        {:error, changeset}
      end
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
    end)

    :ok
  end

  describe "handle_in/3 with submit_csat" do
    test "replies :ok when rating is successful" do
      socket = %Phoenix.Socket{topic: "widget:123"}
      payload = %{"rating" => "positive"}

      assert {:reply, :ok, ^socket} = WidgetChannel.handle_in("submit_csat", payload, socket)
    end

    test "replies with error when rating is invalid" do
      socket = %Phoenix.Socket{topic: "widget:123"}
      payload = %{"rating" => "invalid_rating"}

      assert {:reply, {:error, %{reason: "invalid_rating"}}, ^socket} =
               WidgetChannel.handle_in("submit_csat", payload, socket)
    end
  end
end
