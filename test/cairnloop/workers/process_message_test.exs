defmodule Cairnloop.Workers.ProcessMessageTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias Cairnloop.Workers.ProcessMessage

  # Phase 28 Plan 02: MockRepo for headless testing of the widget branch.
  # Mirrors test/cairnloop/chat_test.exs MockRepo pattern.
  # No Multi/transaction needed because Chat.ingest_widget_message/2 uses repo().insert/1
  # directly (D-06 explicit: NOT calling reply_to_conversation/4 which uses Multi).
  defmodule MockRepo do
    def insert(%Ecto.Changeset{} = changeset) do
      {:ok, Ecto.Changeset.apply_changes(changeset) |> Map.put(:id, 777)}
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
    end)

    :ok
  end

  setup_all do
    case start_supervised({Phoenix.PubSub, name: Cairnloop.PubSub}) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    :ok
  end

  describe "perform/1 widget channel" do
    # Behavior 2 (widget branch): calls Chat.ingest_widget_message/2 and returns :ok.
    # Also validates the worker → Chat facade → PubSub broadcast chain (D-06):
    # ingest_widget_message/2 broadcasts {:message_created, msg_id} on "conversation:1".
    test "widget channel ingests via Chat.ingest_widget_message/2" do
      Phoenix.PubSub.subscribe(Cairnloop.PubSub, "conversation:1")

      job = %Oban.Job{
        args: %{"channel" => "widget", "conversation_id" => 1, "content" => "hi"}
      }

      assert :ok = ProcessMessage.perform(job)

      # Proves the worker → facade → broadcast pattern fires end-to-end
      assert_receive {:message_created, _id}, 200
    end
  end

  describe "perform/1 email channel" do
    # Behavior 2 (email branch): preserves existing logger stub (Pitfall 2 / OQ-2).
    # The EmailWebhookPlug calls ProcessMessage.new(%{channel: "email", content: content})
    # — this clause keeps that secondary caller working under D-07's arg reshape.
    test "email channel preserves logger stub (Pitfall 2)" do
      log =
        capture_log(fn ->
          :ok =
            ProcessMessage.perform(%Oban.Job{
              args: %{"channel" => "email", "content" => "hello"}
            })
        end)

      assert log =~ "Processed email message: hello"
    end
  end
end
