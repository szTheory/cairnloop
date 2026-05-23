defmodule Cairnloop.Retrieval.Workers.IndexResolvedConversationTest do
  use ExUnit.Case, async: false

  alias Cairnloop.{Conversation, Message}
  alias Cairnloop.Retrieval.Workers.IndexResolvedConversation

  defmodule MockRepo do
    def get(Conversation, 42) do
      %Conversation{
        id: 42,
        subject: "Escalated billing export",
        host_user_id: 7,
        resolved_at: DateTime.utc_now()
      }
    end

    def get(Conversation, _), do: nil

    def preload(%Conversation{} = conversation, :messages) do
      %{
        conversation
        | messages: [
            %Message{id: 10, role: :user, content: "The CSV export is empty.", inserted_at: DateTime.utc_now()},
            %Message{
              id: 11,
              role: :agent,
              content: "Regenerated export, corrected permissions, and confirmed delivery.",
              inserted_at: DateTime.utc_now()
            }
          ]
      }
    end

    def transaction(fun) when is_function(fun, 0), do: {:ok, fun.()}

    def transaction(multi) do
      operations = Ecto.Multi.to_list(multi)

      results =
        Enum.reduce(operations, %{}, fn
          {name, {:delete_all, _query, _opts}}, acc ->
            Map.put(acc, name, {1, nil})

          {name, {:insert_all, _schema, records, _opts}}, acc ->
            send(self(), {:inserted_resolved_case_chunks, records})
            Map.put(acc, name, {length(records), nil})
        end)

      {:ok, results}
    end

    def one(%Ecto.Query{}), do: Process.get(:existing_evidence)

    def insert_or_update(changeset) do
      evidence =
        changeset
        |> Ecto.Changeset.apply_changes()
        |> Map.put(:id, 222)

      send(self(), {:upserted_resolved_case_evidence, evidence})
      {:ok, evidence}
    end
  end

  setup do
    original_repo = Application.get_env(:cairnloop, :repo)
    Application.put_env(:cairnloop, :repo, MockRepo)
    Process.delete(:existing_evidence)

    original_api_key = System.get_env("OPENAI_API_KEY")
    System.delete_env("OPENAI_API_KEY")

    on_exit(fn ->
      if original_repo, do: Application.put_env(:cairnloop, :repo, original_repo), else: Application.delete_env(:cairnloop, :repo)
      if original_api_key, do: System.put_env("OPENAI_API_KEY", original_api_key), else: System.delete_env("OPENAI_API_KEY")
    end)

    :ok
  end

  test "stores assistive evidence separately from knowledge-base chunks" do
    job = %Oban.Job{args: %{"conversation_id" => 42, "metadata" => %{"product" => "exports"}}}

    assert :ok = IndexResolvedConversation.perform(job)

    assert_received {:upserted_resolved_case_evidence, evidence}
    assert evidence.conversation_id == 42
    assert evidence.subject == "Escalated billing export"
    assert evidence.metadata == %{"product" => "exports"}
    assert evidence.outcome == "resolved"

    assert_received {:inserted_resolved_case_chunks, records}
    assert length(records) >= 3
    assert Enum.all?(records, &Map.has_key?(&1, :resolved_case_evidence_id))
    assert Enum.map(records, & &1.chunk_index) == Enum.to_list(0..(length(records) - 1))
  end

  test "returns error if conversation is not found" do
    job = %Oban.Job{args: %{"conversation_id" => -1}}
    assert {:error, :conversation_not_found} = IndexResolvedConversation.perform(job)
  end
end
