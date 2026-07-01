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

    def get(schema, id, opts) do
      send(self(), {:repo_get, schema, id, opts})
      get(schema, id)
    end

    def preload(%Conversation{} = conversation, messages: query) do
      if match?(%Ecto.Query{}, query) do
        send(self(), {:preload_messages_query, query})
      end

      %{
        conversation
        | messages: [
            %Message{
              id: 10,
              role: :user,
              content: "The CSV export is empty.",
              inserted_at: DateTime.utc_now()
            },
            %Message{
              id: 11,
              role: :agent,
              content: "Regenerated export, corrected permissions, and confirmed delivery.",
              inserted_at: DateTime.utc_now()
            }
          ]
      }
    end

    def preload(%Conversation{} = conversation, :messages),
      do: preload(conversation, messages: nil)

    def transaction(fun) when is_function(fun, 0), do: {:ok, fun.()}

    def transaction(multi) do
      operations = Ecto.Multi.to_list(multi)

      results =
        Enum.reduce(operations, %{}, fn
          {name, {:delete_all, query, opts}}, acc ->
            send(self(), {:delete_resolved_chunks_query, query, opts})
            Map.put(acc, name, {1, nil})

          {name, {:insert_all, schema, records, opts}}, acc ->
            send(self(), {:insert_resolved_chunks_opts, schema, opts})
            send(self(), {:inserted_resolved_case_chunks, records})
            Map.put(acc, name, {length(records), nil})
        end)

      {:ok, results}
    end

    def one(%Ecto.Query{} = query) do
      send(self(), {:evidence_lookup_query, query})
      Process.get(:existing_evidence)
    end

    def insert_or_update(changeset, opts \\ []) do
      send(self(), {:evidence_insert_or_update_opts, opts})

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
      if original_repo,
        do: Application.put_env(:cairnloop, :repo, original_repo),
        else: Application.delete_env(:cairnloop, :repo)

      if original_api_key,
        do: System.put_env("OPENAI_API_KEY", original_api_key),
        else: System.delete_env("OPENAI_API_KEY")
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
    assert_received {:repo_get, Conversation, 42, get_opts}
    assert Keyword.get(get_opts, :prefix) == "cairnloop"
    assert_received {:preload_messages_query, preload_query}
    assert preload_query.prefix == "cairnloop"
    assert_received {:evidence_lookup_query, evidence_query}
    assert evidence_query.prefix == "cairnloop"
    assert_received {:evidence_insert_or_update_opts, evidence_opts}
    assert Keyword.get(evidence_opts, :prefix) == "cairnloop"

    assert_received {:inserted_resolved_case_chunks, records}
    assert length(records) >= 3
    assert Enum.all?(records, &Map.has_key?(&1, :resolved_case_evidence_id))
    assert Enum.map(records, & &1.chunk_index) == Enum.to_list(0..(length(records) - 1))
    assert_received {:delete_resolved_chunks_query, delete_query, delete_opts}
    assert delete_query.prefix == "cairnloop"
    assert Keyword.get(delete_opts, :prefix) == "cairnloop"

    assert_received {:insert_resolved_chunks_opts, Cairnloop.Retrieval.ResolvedCaseChunk,
                     insert_opts}

    assert Keyword.get(insert_opts, :prefix) == "cairnloop"
  end

  test "returns error if conversation is not found" do
    job = %Oban.Job{args: %{"conversation_id" => -1}}
    assert {:error, :conversation_not_found} = IndexResolvedConversation.perform(job)
  end
end
