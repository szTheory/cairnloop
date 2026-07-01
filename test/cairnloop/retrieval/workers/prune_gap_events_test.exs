defmodule Cairnloop.Retrieval.Workers.PruneGapEventsTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Retrieval.Workers.PruneGapEvents

  defmodule MockRepo do
    def delete_all(query), do: delete_all(query, [])

    def delete_all(_query, opts) do
      calls = Process.get(:repo_calls, [])
      Process.put(:repo_calls, calls ++ [%{operation: :delete_all, opts: opts}])

      now = Process.get(:prune_now)
      cutoff = DateTime.add(now, -90 * 86_400, :second)

      remaining =
        Process.get(:gap_events, [])
        |> Enum.reject(&(DateTime.compare(&1.occurred_at, cutoff) == :lt))

      Process.put(:gap_events, remaining)
      {1, nil}
    end
  end

  setup do
    original_repo = Application.get_env(:cairnloop, :repo)
    Application.put_env(:cairnloop, :repo, MockRepo)
    Process.put(:repo_calls, [])

    on_exit(fn ->
      Process.delete(:gap_events)
      Process.delete(:prune_now)
      Process.delete(:repo_calls)

      if original_repo do
        Application.put_env(:cairnloop, :repo, original_repo)
      else
        Application.delete_env(:cairnloop, :repo)
      end
    end)

    :ok
  end

  test "prunes rows older than the default 90-day retention window" do
    now = DateTime.from_naive!(~N[2026-05-20 20:45:00], "Etc/UTC")
    old_event = %{id: 1, occurred_at: DateTime.add(now, -91 * 86_400, :second)}
    recent_event = %{id: 2, occurred_at: DateTime.add(now, -10 * 86_400, :second)}

    assert {:ok, 1} =
             PruneGapEvents.prune_expired(
               now_fn: fn -> now end,
               prune_fn: fn cutoff ->
                 remaining =
                   [old_event, recent_event]
                   |> Enum.reject(&(DateTime.compare(&1.occurred_at, cutoff) == :lt))

                 assert Enum.map(remaining, & &1.id) == [2]
                 1
               end
             )
  end

  test "perform/1 uses explicit retention maintenance without changing product semantics" do
    now = DateTime.from_naive!(~N[2026-05-20 20:45:00], "Etc/UTC")
    Process.put(:prune_now, now)

    Process.put(:gap_events, [
      %{id: 1, occurred_at: DateTime.add(now, -91 * 86_400, :second)},
      %{id: 2, occurred_at: DateTime.add(now, -5 * 86_400, :second)}
    ])

    assert PruneGapEvents.retention_days() == 90

    assert :ok == PruneGapEvents.perform(%Oban.Job{args: %{"retention_days" => 90}})
    assert Enum.map(Process.get(:gap_events), & &1.id) == [2]

    assert Enum.any?(Process.get(:repo_calls, []), fn call ->
             call.operation == :delete_all and Keyword.get(call.opts, :prefix) == "cairnloop"
           end)
  end

  test "cutoff_datetime/1 computes the default 90-day boundary" do
    now = DateTime.from_naive!(~N[2026-05-20 20:45:00], "Etc/UTC")
    cutoff = PruneGapEvents.cutoff_datetime(now_fn: fn -> now end)

    assert DateTime.diff(now, cutoff, :day) == 90
  end
end
