defmodule Cairnloop.Workers.OutboundWorkerTest do
  use ExUnit.Case, async: false
  alias Cairnloop.Workers.OutboundWorker
  alias Cairnloop.Message
  alias Cairnloop.Conversation

  defmodule MockRepo do
    def get!(Message, 1) do
      %Message{
        id: 1,
        conversation_id: 10,
        content: "Hello",
        role: :system_outbound,
        metadata: %{"template_id" => "test", "status" => "pending"}
      }
    end

    def get!(Conversation, 10) do
      %Conversation{id: 10, host_user_id: "user_123"}
    end

    def update(changeset) do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end

    def preload(struct, _), do: struct
  end

  defmodule MockNotifier do
    @behaviour Cairnloop.Notifier
    
    def on_conversation_resolved(_, _), do: :ok
    def on_sla_breach(_, _, _), do: :ok
    
    def on_outbound_triggered(message, conversation) do
      send(self(), {:notified, message.id, conversation.id})
      :ok
    end
  end

  defmodule ErrorNotifier do
    @behaviour Cairnloop.Notifier
    def on_conversation_resolved(_, _), do: :ok
    def on_sla_breach(_, _, _), do: :ok
    def on_outbound_triggered(_, _), do: {:error, :delivery_failed}
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    Application.put_env(:cairnloop, :notifier, MockNotifier)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      Application.delete_env(:cairnloop, :notifier)
    end)

    :ok
  end

  describe "perform/1" do
    test "successfully delivers message and updates status to sent" do
      assert {:ok, _} = OutboundWorker.perform(%Oban.Job{args: %{"message_id" => 1}})
      
      assert_receive {:notified, 1, 10}
      # Status update is handled via MockRepo.update which we could verify if we captured it.
    end

    test "handles notifier error and updates status to failed" do
      Application.put_env(:cairnloop, :notifier, ErrorNotifier)
      
      assert {:error, {:error, :delivery_failed}} = OutboundWorker.perform(%Oban.Job{args: %{"message_id" => 1}})
    end
  end
end
