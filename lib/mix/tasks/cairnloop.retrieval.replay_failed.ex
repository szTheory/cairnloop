defmodule Mix.Tasks.Cairnloop.Retrieval.ReplayFailed do
  use Mix.Task

  @shortdoc "Replay failed retrieval jobs through the retrieval context"

  @moduledoc """
  Replay failed retrieval jobs through `Cairnloop.Retrieval`.

  Examples:

      mix cairnloop.retrieval.replay_failed --queue default
      mix cairnloop.retrieval.replay_failed --queue default --worker Cairnloop.KnowledgeBase.Workers.ChunkRevision
  """

  @switches [queue: :string, worker: :string]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: @switches)

    replay_opts =
      []
      |> Keyword.put(:queue, Keyword.get(opts, :queue, "default"))
      |> maybe_put_worker(Keyword.get(opts, :worker))

    case retrieval_module().replay_failed(replay_opts) do
      {:ok, jobs} ->
        Mix.shell().info("Replayed #{length(jobs)} retrieval job(s)")

      {:error, reason} ->
        Mix.raise("Retrieval replay failed: #{inspect(reason)}")
    end
  end

  defp maybe_put_worker(opts, nil), do: opts
  defp maybe_put_worker(opts, worker), do: Keyword.put(opts, :worker, worker)

  defp retrieval_module do
    Application.get_env(:cairnloop, :retrieval_module, Cairnloop.Retrieval)
  end
end
