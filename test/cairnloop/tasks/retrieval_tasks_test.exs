defmodule Cairnloop.Tasks.RetrievalTasksTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  defmodule RetrievalMock do
    def rebuild_corpus(opts) do
      send(self(), {:rebuild_corpus_called, opts})
      {:ok, [%Oban.Job{}, %Oban.Job{}]}
    end

    def replay_failed(opts) do
      send(self(), {:replay_failed_called, opts})
      {:ok, [%Oban.Job{}]}
    end
  end

  setup do
    Application.put_env(:cairnloop, :retrieval_module, RetrievalMock)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :retrieval_module)
    end)

    :ok
  end

  test "rebuild task routes into the retrieval context with explicit scope" do
    output =
      capture_io(fn ->
        Mix.Tasks.Cairnloop.Retrieval.Rebuild.run([
          "--corpus",
          "knowledge_base",
          "--revision-id",
          "42"
        ])
      end)

    assert_received {:rebuild_corpus_called, opts}
    assert opts[:corpus] == :knowledge_base
    assert opts[:revision_ids] == [42]
    assert output =~ "Enqueued 2 rebuild job(s) for knowledge_base"
  end

  test "replay_failed task routes into the retrieval context" do
    output =
      capture_io(fn ->
        Mix.Tasks.Cairnloop.Retrieval.ReplayFailed.run([
          "--queue",
          "default",
          "--worker",
          "Cairnloop.KnowledgeBase.Workers.ChunkRevision"
        ])
      end)

    assert_received {:replay_failed_called, opts}
    assert opts[:queue] == "default"
    assert opts[:worker] == "Cairnloop.KnowledgeBase.Workers.ChunkRevision"
    assert output =~ "Replayed 1 retrieval job(s)"
  end
end
