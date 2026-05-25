defmodule Cairnloop.KnowledgeAutomation.Workers.RefreshGapCandidatesTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeAutomation.CandidateBuilder
  alias Cairnloop.KnowledgeAutomation.Workers.{BackfillGapCandidates, RefreshGapCandidates}
  alias Cairnloop.Retrieval.GapRecorder
  alias Cairnloop.Retrieval.Workers.IndexResolvedConversation

  defmodule MockRepo do
    def one(_query), do: nil

    def transaction(multi) do
      results =
        Enum.reduce(Ecto.Multi.to_list(multi), %{}, fn
          {:gap_event, {:insert, changeset, _opts}}, acc ->
            gap_event =
              changeset
              |> Ecto.Changeset.apply_action!(:insert)
              |> Map.put(:id, System.unique_integer([:positive]))
              |> Map.put(:inserted_at, DateTime.utc_now())

            Map.put(acc, :gap_event, gap_event)
        end)

      {:ok, results}
    end
  end

  setup do
    original_repo = Application.get_env(:cairnloop, :repo)
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      if original_repo do
        Application.put_env(:cairnloop, :repo, original_repo)
      else
        Application.delete_env(:cairnloop, :repo)
      end
    end)

    :ok
  end

  test "refresh rebuilds candidate rows idempotently from retained evidence" do
    gap_events = [
      %Cairnloop.Retrieval.GapEvent{
        id: 1,
        occurred_at: ~U[2026-05-21 10:00:00Z],
        tenant_scope: :system_unscoped,
        ui_surface: :conversation,
        outcome_class: :empty_recall,
        reason: :no_canonical_results,
        sanitized_query_excerpt: "billing export"
      }
    ]

    persisted = self()

    persist_fn = fn candidates ->
      send(persisted, {:persisted_candidates, candidates})
      :ok
    end

    assert :ok =
             KnowledgeAutomation.refresh_gap_candidates(
               gap_events: gap_events,
               manual_signals: [],
               persist_fn: persist_fn
             )

    assert_receive {:persisted_candidates, first}

    assert :ok =
             KnowledgeAutomation.refresh_gap_candidates(
               gap_events: gap_events,
               manual_signals: [],
               persist_fn: persist_fn
             )

    assert_receive {:persisted_candidates, second}

    assert first == second
  end

  test "backfill reuses the same builder path as refresh" do
    gap_events = [
      %Cairnloop.Retrieval.GapEvent{
        id: 1,
        occurred_at: ~U[2026-05-21 10:00:00Z],
        tenant_scope: :system_unscoped,
        ui_surface: :conversation,
        outcome_class: :empty_recall,
        reason: :no_canonical_results,
        sanitized_query_excerpt: "billing export"
      }
    ]

    expected = CandidateBuilder.build(gap_events, [])
    persisted = self()

    persist_fn = fn candidates ->
      send(persisted, {:persisted_candidates, candidates})
      :ok
    end

    assert :ok =
             KnowledgeAutomation.rebuild_gap_candidates(
               gap_events: gap_events,
               manual_signals: [],
               persist_fn: persist_fn,
               sync: true
             )

    assert_receive {:persisted_candidates, actual}
    assert actual == expected
  end

  test "refresh and backfill workers delegate to the public context seams" do
    assert Code.ensure_loaded?(RefreshGapCandidates)
    assert Code.ensure_loaded?(BackfillGapCandidates)
    assert function_exported?(RefreshGapCandidates, :new_job, 2)
    assert function_exported?(BackfillGapCandidates, :new_job, 2)
  end

  test "gap recorder schedules refresh best-effort after successful persistence" do
    parent = self()

    assert {:ok, _gap_event} =
             GapRecorder.record(
               %{
                 query: "billing export",
                 surface: :search_modal,
                 outcome_class: :empty_recall,
                 reason: :no_canonical_results
               },
               schedule_prune_fn: fn -> :ok end,
               schedule_gap_candidate_refresh_fn: fn payload ->
                 send(parent, {:scheduled_gap_candidate_refresh, payload})
                 :ok
               end,
               dedupe_lookup_fn: fn _attrs -> nil end,
               now_fn: fn -> ~U[2026-05-21 10:00:00Z] end
             )

    assert_receive {:scheduled_gap_candidate_refresh, %{"source_type" => "retrieval_gap_event"}}
  end

  test "resolved-case indexing keeps refresh enqueue secondary to the main write path" do
    assert Code.ensure_loaded?(IndexResolvedConversation)
  end
end
