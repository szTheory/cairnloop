defmodule Cairnloop.KnowledgeAutomation.Workers.BackfillGapCandidates do
  use Oban.Worker, queue: :default, unique: [period: 300]

  alias Cairnloop.KnowledgeAutomation

  def new_job(args \\ %{}, opts \\ []) do
    new(args, opts)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    opts =
      args
      |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)

    case KnowledgeAutomation.rebuild_gap_candidates(opts) do
      {:ok, _result} -> :ok
      :ok -> :ok
      other -> other
    end
  end
end
