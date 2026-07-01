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

    def get!(schema, id, _opts), do: get!(schema, id)

    def update(%Ecto.Changeset{} = changeset) do
      if changeset.changes[:csat_rating] in [:positive, :negative] do
        {:ok, Ecto.Changeset.apply_changes(changeset)}
      else
        {:error, changeset}
      end
    end

    def insert(%Ecto.Changeset{} = changeset) do
      conversation = Ecto.Changeset.apply_changes(changeset) |> Map.put(:id, 42)
      send(self(), {:inserted_conversation, conversation})
      {:ok, conversation}
    end

    def insert(%Ecto.Changeset{} = changeset, _opts), do: insert(changeset)
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    Process.delete(:inserted_conversation)

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

  # Phase 58 Plan 02: join("widget:lobby") creates a Conversation via Chat facade
  # with verified customer_ref identity and stores conversation_id in socket assigns.
  describe "join/3 widget:lobby" do
    test "creates a customer conversation with customer_ref and no operator host_user_id" do
      socket = %Phoenix.Socket{
        assigns: %{customer_ref: "customer_123"},
        topic: "widget:lobby"
      }

      assert {:ok, %{conversation_id: id}, updated_socket} =
               WidgetChannel.join("widget:lobby", %{}, socket)

      # MockRepo.insert/1 returns id: 42 as sentinel
      assert id == 42
      assert updated_socket.assigns[:conversation_id] == 42

      assert_received {:inserted_conversation, conversation}
      assert conversation.customer_ref == "customer_123"
      assert conversation.host_user_id == nil
    end

    test "fails closed without verified customer_ref and does not create a conversation" do
      socket = %Phoenix.Socket{
        assigns: %{},
        topic: "widget:lobby"
      }

      assert {:error, %{reason: "unauthorized"}} =
               WidgetChannel.join("widget:lobby", %{}, socket)

      refute_received {:inserted_conversation, _conversation}
    end
  end

  describe "handle_in/3 with new_message" do
    test "keeps conversation_id server-assigned instead of payload-provided" do
      source = File.read!("lib/cairnloop/channels/widget_channel.ex")

      assert source =~ "conversation_id = socket.assigns[:conversation_id]"
      assert source =~ "conversation_id: conversation_id"
      refute source =~ ~r/conversation_id\s*=\s*.*payload/
    end
  end
end
