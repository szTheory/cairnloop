defmodule Cairnloop.ChatTest do
  use ExUnit.Case, async: false
  alias Cairnloop.Chat

  defmodule MockRepo do
    def get!(Cairnloop.Conversation, id) do
      if id == 1 do
        %Cairnloop.Conversation{
          id: 1,
          status: :open,
          host_user_id: 10,
          inserted_at: DateTime.utc_now() |> DateTime.add(-100, :second)
        }
      else
        raise Ecto.NoResultsError, queryable: Cairnloop.Conversation
      end
    end

    def transaction(multi) do
      operations = Ecto.Multi.to_list(multi)

      results =
        Enum.into(operations, %{}, fn
          {name, {:insert, changeset, _}} ->
            {name, Ecto.Changeset.apply_changes(changeset) |> Map.put(:id, 999)}

          {name, {:update, changeset, _}} ->
            {name, Ecto.Changeset.apply_changes(changeset)}
        end)

      {:ok, results}
    end

    def update(changeset) do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end
  end

  defmodule MockNotifier do
    def on_conversation_resolved(conversation, metadata) do
      send(self(), {:notified, conversation, metadata})
      :ok
    end
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

  describe "reply_to_conversation/3" do
    test "inserts message and job when role is :user" do
      assert {:ok, results} = Chat.reply_to_conversation(1, "hello", :user)
      assert %{content: "hello", role: :user, conversation_id: 1} = results.message
      assert %{status: :open, resolved_at: nil} = results.conversation

      assert job = results.draft_job
      assert job.worker == "Cairnloop.Automation.Workers.DraftWorker"
      assert job.args == %{"conversation_id" => 1}
    end

    test "inserts message but no job when role is :agent" do
      assert {:ok, results} = Chat.reply_to_conversation(1, "hello again", :agent)
      assert %{content: "hello again", role: :agent, conversation_id: 1} = results.message

      refute Map.has_key?(results, :draft_job)
    end
  end

  describe "resolve_conversation/2" do
    test "sets status to :resolved, resolved_at to current UTC time, and inserts system message" do
      actor = %{type: "user", id: 1}
      assert {:ok, results} = Chat.resolve_conversation(1, resolved_by: actor)
      conversation = results.conversation
      assert conversation.status == :resolved
      assert conversation.resolved_at != nil
      assert %DateTime{} = conversation.resolved_at

      assert %{
               content: "Please rate your experience.",
               role: :system,
               conversation_id: 1,
               metadata: %{"type" => "csat_request"}
             } = results.system_message
    end

    test "requires resolved_by in options and emits telemetry" do
      actor = %{type: "system", id: "system"}

      # Attach handler to capture telemetry
      :telemetry.attach(
        "test-resolve-handler",
        [:cairnloop, :conversation, :resolved],
        fn _event, measurements, metadata, _config ->
          send(self(), {:telemetry_event, measurements, metadata})
        end,
        nil
      )

      assert {:ok, _} = Chat.resolve_conversation(1, resolved_by: actor, custom_meta: "foo")

      assert_receive {:telemetry_event, measurements, metadata}
      assert Map.has_key?(measurements, :duration_seconds)
      assert measurements.duration_seconds >= 100

      assert metadata.actor == actor
      assert metadata.metadata[:custom_meta] == "foo"
      assert metadata.conversation_id == 1

      :telemetry.detach("test-resolve-handler")
    end

    test "invokes the configured Notifier behaviour" do
      actor = %{type: "user", id: 2}
      assert {:ok, _results} = Chat.resolve_conversation(1, resolved_by: actor)

      assert_receive {:notified, conversation, metadata}
      assert conversation.id == 1
      assert metadata[:resolved_by] == actor
    end
  end

  describe "submit_csat/2" do
    test "updates csat_rating and emits telemetry" do
      # Attach handler to capture telemetry
      :telemetry.attach(
        "test-csat-handler",
        [:cairnloop, :feedback, :csat_submitted],
        fn _event, measurements, metadata, _config ->
          send(self(), {:csat_telemetry, measurements, metadata})
        end,
        nil
      )

      assert {:ok, conversation} = Chat.submit_csat(1, "positive")
      assert conversation.csat_rating == :positive

      assert_receive {:csat_telemetry, %{count: 1}, %{conversation_id: 1, rating: "positive"}}

      :telemetry.detach("test-csat-handler")
    end
  end
end
