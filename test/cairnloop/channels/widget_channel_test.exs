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

    # Phase 28 Plan 02: top-level insert/1 for create_customer_conversation/1.
    # Returns a Conversation with id: 42 as the sentinel value for join tests.
    def insert(%Ecto.Changeset{} = changeset) do
      {:ok, Ecto.Changeset.apply_changes(changeset) |> Map.put(:id, 42)}
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
    end)

    :ok
  end

  # Phase 28 Plan 02: PubSub is needed because Chat.create_customer_conversation/1
  # broadcasts on "conversations" post-commit. Without the registry, the broadcast
  # would raise — we start it here so the join test doesn't fail on a missing registry.
  setup_all do
    case start_supervised({Phoenix.PubSub, name: Cairnloop.PubSub}) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    :ok
  end

  describe "handle_in/3 with submit_csat" do
    # CR-02 fix: submit_csat is deferred (CONTEXT.md OQ-4) and now returns a structured
    # error reply on any topic rather than crashing with an Ecto.Query.CastError on
    # "widget:lobby". Both lobby and conversation-scoped topics must return csat_not_available.
    test "replies with csat_not_available error on lobby topic" do
      socket = %Phoenix.Socket{topic: "widget:lobby"}
      payload = %{"rating" => "positive"}

      assert {:reply, {:error, %{reason: "csat_not_available"}}, ^socket} =
               WidgetChannel.handle_in("submit_csat", payload, socket)
    end

    test "replies with csat_not_available error on conversation-scoped topic" do
      socket = %Phoenix.Socket{topic: "widget:123"}
      payload = %{"rating" => "positive"}

      assert {:reply, {:error, %{reason: "csat_not_available"}}, ^socket} =
               WidgetChannel.handle_in("submit_csat", payload, socket)
    end
  end

  # Phase 28 Plan 02 D-01: join("widget:lobby") creates a Conversation via Chat facade
  # and stores conversation_id in socket assigns.
  describe "join/3 widget:lobby" do
    test "creates a conversation and replies with conversation_id" do
      socket = %Phoenix.Socket{
        assigns: %{user_token: "demo_customer"},
        topic: "widget:lobby"
      }

      assert {:ok, %{conversation_id: id}, updated_socket} =
               WidgetChannel.join("widget:lobby", %{}, socket)

      # MockRepo.insert/1 returns id: 42 as sentinel
      assert id == 42
      assert updated_socket.assigns[:conversation_id] == 42
    end
  end
end
