defmodule Cairnloop.ChatTest do
  use ExUnit.Case, async: false
  alias Cairnloop.Chat

  defmodule MockRepo do
    def get!(Cairnloop.Conversation, id) do
      if id == 1 do
        %Cairnloop.Conversation{
          id: 1,
          status: :open,
          host_user_id: 10
        }
      else
        raise Ecto.NoResultsError, queryable: Cairnloop.Conversation
      end
    end

    def transaction(multi) do
      operations = Ecto.Multi.to_list(multi)
      
      results = Enum.into(operations, %{}, fn 
        {name, {:insert, changeset, _}} -> 
          {name, Ecto.Changeset.apply_changes(changeset) |> Map.put(:id, 999)}
        {name, {:update, changeset, _}} -> 
          {name, Ecto.Changeset.apply_changes(changeset)}
      end)
      
      {:ok, results}
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    
    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
    end)
    
    :ok
  end

  describe "reply_to_conversation/3" do
    test "inserts message and job when role is :user" do
      assert {:ok, results} = Chat.reply_to_conversation(1, "hello", :user)
      assert %{content: "hello", role: :user, conversation_id: 1} = results.message
      assert %{status: :open} = results.conversation
      
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
end
