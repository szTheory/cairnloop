defmodule Cairnloop.Retrieval.Workers.PruneGapEvents do
  use Oban.Worker, queue: :default, unique: [period: 300]

  import Ecto.Query

  alias Cairnloop.Retrieval.GapEvent

  @retention_days 90

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  defp repo_opts, do: Cairnloop.SchemaPrefix.repo_opts()

  defp prefixed(queryable) do
    query = Ecto.Queryable.to_query(queryable)
    put_query_prefix(query, Cairnloop.SchemaPrefix.configured())
  end

  def retention_days, do: @retention_days

  def new_job(args \\ %{}, opts \\ []) do
    args
    |> Map.put_new("retention_days", @retention_days)
    |> new(opts)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    retention_days =
      args
      |> Map.get("retention_days", @retention_days)
      |> normalize_retention_days()

    case prune_expired(retention_days: retention_days) do
      {:ok, _count} -> :ok
      error -> error
    end
  end

  def prune_expired(opts \\ []) do
    cutoff = cutoff_datetime(opts)
    prune_fn = Keyword.get(opts, :prune_fn, &delete_before/1)

    case prune_fn.(cutoff) do
      {count, _} when is_integer(count) -> {:ok, count}
      count when is_integer(count) -> {:ok, count}
      {:ok, count} when is_integer(count) -> {:ok, count}
      {:error, _reason} = error -> error
      _ -> {:ok, 0}
    end
  end

  def cutoff_datetime(opts \\ []) do
    retention_days =
      opts
      |> Keyword.get(:retention_days, @retention_days)
      |> normalize_retention_days()

    now = Keyword.get(opts, :now_fn, &DateTime.utc_now/0).()
    DateTime.add(now, -retention_days * 86_400, :second)
  end

  defp delete_before(cutoff) do
    GapEvent
    |> prefixed()
    |> where([gap_event], gap_event.occurred_at < ^cutoff)
    |> repo().delete_all(repo_opts())
  end

  defp normalize_retention_days(value) when is_integer(value) and value > 0, do: value

  defp normalize_retention_days(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, _} when parsed > 0 -> parsed
      _ -> @retention_days
    end
  end

  defp normalize_retention_days(_), do: @retention_days
end
