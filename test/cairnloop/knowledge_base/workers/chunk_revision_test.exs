defmodule Cairnloop.KnowledgeBase.Workers.ChunkRevisionTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeBase.Workers.ChunkRevision
  alias Cairnloop.KnowledgeBase.Revision

  defmodule MockRepo do
    def get(Revision, id) do
      if id == 42 do
        %Revision{id: 42, content: "## Header 1\nSome text here.\n### Subheader\nMore text."}
      else
        nil
      end
    end

    def transaction(multi) do
      operations = Ecto.Multi.to_list(multi)

      results =
        Enum.reduce(operations, %{}, fn
          {name, {:delete_all, _query, _opts}}, acc ->
            Map.put(acc, name, {1, nil})

          {name, {:insert_all, _schema, records, _opts}}, acc ->
            send(self(), {:inserted_chunk_records, records})
            Map.put(acc, name, {length(records), nil})

          {name, {:run, run_fn}}, acc ->
            {:ok, result} = run_fn.(__MODULE__, acc)
            Map.put(acc, name, result)
        end)

      # Send a message to the test process so we can assert on what was inserted
      send(self(), {:transaction_results, results})

      {:ok, results}
    end
  end

  defmodule MockKnowledgeAutomation do
    def record_review_task_reindex_started(revision_id, _opts \\ []) do
      send(self(), {:reindex_started_recorded, revision_id})
      :ok
    end

    def record_review_task_reindex_outcome(revision_id, result, _opts \\ []) do
      send(self(), {:reindex_outcome_recorded, revision_id, result})
      :ok
    end
  end

  setup do
    original_repo = Application.get_env(:cairnloop, :repo)
    Application.put_env(:cairnloop, :repo, MockRepo)
    original_knowledge_automation = Application.get_env(:cairnloop, :knowledge_automation)
    Application.put_env(:cairnloop, :knowledge_automation, MockKnowledgeAutomation)

    # Temporarily set OPENAI_API_KEY to nil so we use mock embeddings
    original_api_key = System.get_env("OPENAI_API_KEY")
    System.delete_env("OPENAI_API_KEY")

    on_exit(fn ->
      if original_repo,
        do: Application.put_env(:cairnloop, :repo, original_repo),
        else: Application.delete_env(:cairnloop, :repo)

      if original_knowledge_automation,
        do: Application.put_env(:cairnloop, :knowledge_automation, original_knowledge_automation),
        else: Application.delete_env(:cairnloop, :knowledge_automation)

      if original_api_key,
        do: System.put_env("OPENAI_API_KEY", original_api_key),
        else: System.delete_env("OPENAI_API_KEY")
    end)

    :ok
  end

  test "performs successfully and creates chunks" do
    job = %Oban.Job{args: %{"revision_id" => 42}}
    assert :ok = ChunkRevision.perform(job)

    assert_received {:reindex_started_recorded, 42}
    assert_received {:transaction_results, results}
    assert_received {:inserted_chunk_records, records}
    assert {count, _} = results[:insert_chunks]
    # "Some text here." and "More text." chunks
    assert count == 2
    assert Enum.map(records, & &1.chunk_index) == [0, 1]
    assert Enum.map(records, & &1.heading) == ["Header 1", "Subheader"]
    assert_received {:reindex_outcome_recorded, 42, :ok}
  end

  test "returns error if revision is not found" do
    job = %Oban.Job{args: %{"revision_id" => -1}}
    assert {:error, :revision_not_found} = ChunkRevision.perform(job)
    assert_received {:reindex_started_recorded, -1}
    assert_received {:reindex_outcome_recorded, -1, {:error, :revision_not_found}}
  end
end
