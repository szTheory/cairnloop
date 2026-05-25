defmodule Cairnloop.KnowledgeAutomation.GapCandidateTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeAutomation.{GapCandidate, GapCandidateMembership}

  defmodule MockRepo do
    def all(%Ecto.Query{} = query) do
      case query.from.source do
        {"cairnloop_gap_candidates", _module} ->
          Process.get(:gap_candidates, [])
          |> Enum.sort_by(
            fn candidate ->
              {candidate.score || 0.0, candidate.last_seen_at, candidate.id}
            end,
            :desc
          )

        {"cairnloop_retrieval_gap_events", _module} ->
          Process.get(:retrieval_gap_events, [])

        {"cairnloop_resolved_case_evidences", _module} ->
          Process.get(:manual_evidence, [])

        _ ->
          []
      end
    end

    def one!(%Ecto.Query{} = query) do
      Process.get(:gap_candidate_detail_lookup).(query)
    end
  end

  setup do
    original_repo = Application.get_env(:cairnloop, :repo)
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      Process.delete(:gap_candidates)
      Process.delete(:retrieval_gap_events)
      Process.delete(:manual_evidence)
      Process.delete(:gap_candidate_detail_lookup)

      if original_repo do
        Application.put_env(:cairnloop, :repo, original_repo)
      else
        Application.delete_env(:cairnloop, :repo)
      end
    end)

    :ok
  end

  test "gap candidate changeset accepts stable identity, freshness, counts, and score metadata" do
    changeset =
      GapCandidate.changeset(%GapCandidate{}, %{
        stable_key: String.duplicate("abc12345", 2),
        status: :open,
        candidate_type: :mixed,
        title: "Billing export",
        seed_excerpt: "billing export",
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        ui_surface: :conversation,
        first_seen_at: ~U[2026-05-20 10:00:00Z],
        last_seen_at: ~U[2026-05-21 10:00:00Z],
        evidence_count: 4,
        manual_case_count: 2,
        weak_grounding_count: 1,
        no_hit_count: 1,
        score: 8.5,
        score_components: %{"manual_handling" => 5.0}
      })

    assert changeset.valid?
  end

  test "gap candidate changeset rejects missing stable identity fields" do
    changeset = GapCandidate.changeset(%GapCandidate{}, %{title: "Billing export"})

    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).stable_key
    assert "can't be blank" in errors_on(changeset).tenant_scope
  end

  test "membership changeset preserves explicit source links without mutating gap events" do
    changeset =
      GapCandidateMembership.changeset(%GapCandidateMembership{}, %{
        source_type: :retrieval_gap_event,
        source_id: 44
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :source_type) == :retrieval_gap_event
    assert Ecto.Changeset.get_change(changeset, :source_id) == 44
  end

  test "migration shape creates separate candidate and membership tables plus indexes" do
    [migration] = Path.wildcard("priv/repo/migrations/*_add_gap_candidates_and_memberships.exs")
    content = File.read!(migration)

    assert content =~ "create table(:cairnloop_gap_candidates)"
    assert content =~ "create table(:cairnloop_gap_candidate_memberships)"
    assert content =~ "create unique_index(:cairnloop_gap_candidates, [:stable_key])"
    assert content =~ "create index(:cairnloop_gap_candidates, [:status])"
    assert content =~ "create index(:cairnloop_gap_candidates, [:last_seen_at])"
    assert content =~ "[:gap_candidate_id, :source_type, :source_id]"
  end

  test "list_gap_candidates returns persisted ordering by score then freshness" do
    Process.put(:gap_candidates, [
      %GapCandidate{
        id: 1,
        title: "Older higher",
        score: 7.0,
        last_seen_at: ~U[2026-05-20 12:00:00Z]
      },
      %GapCandidate{
        id: 2,
        title: "Newest same score",
        score: 7.0,
        last_seen_at: ~U[2026-05-21 12:00:00Z]
      },
      %GapCandidate{id: 3, title: "Top score", score: 9.0, last_seen_at: ~U[2026-05-19 12:00:00Z]}
    ])

    candidates = KnowledgeAutomation.list_gap_candidates()

    assert Enum.map(candidates, & &1.title) == ["Top score", "Newest same score", "Older higher"]
  end

  test "get_gap_candidate! loads memberships and rejects cross-scope access when filters are supplied" do
    candidate =
      %GapCandidate{
        id: 10,
        title: "Billing export",
        candidate_type: :mixed,
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        evidence_count: 3,
        manual_case_count: 1,
        weak_grounding_count: 1,
        no_hit_count: 1,
        score_components: %{"weak_grounding" => 1.4},
        memberships: [
          %GapCandidateMembership{source_type: :retrieval_gap_event, source_id: 55},
          %GapCandidateMembership{source_type: :manual_handling_case, source_id: 99}
        ]
      }

    Process.put(:gap_candidate_detail_lookup, fn _query -> candidate end)

    Process.put(:retrieval_gap_events, [
      %Cairnloop.Retrieval.GapEvent{
        id: 55,
        occurred_at: ~U[2026-05-21 09:00:00Z],
        surface: :conversation,
        reason: :no_canonical_results,
        outcome_class: :empty_recall,
        canonical_hit_count: 0,
        assistive_hit_count: 1,
        sanitized_query_excerpt: "billing export failed"
      }
    ])

    Process.put(:manual_evidence, [
      %Cairnloop.Retrieval.ResolvedCaseEvidence{
        id: 99,
        conversation_id: 123,
        issue_summary: "Billing export failed",
        resolution_note: "Rebuilt the export and confirmed delivery.",
        actions_taken: ["rebuilt export"],
        resolved_at: ~U[2026-05-21 08:00:00Z]
      }
    ])

    loaded = KnowledgeAutomation.get_gap_candidate!(10, host_user_id: "user-1")
    assert length(loaded.retrieval_gap_events) == 1
    assert length(loaded.manual_handling_evidence) == 1

    assert_raise Ecto.NoResultsError, fn ->
      KnowledgeAutomation.get_gap_candidate!(10, host_user_id: "other-user")
    end
  end

  test "refresh and schedule seams exist for phase 9 maintenance" do
    assert function_exported?(KnowledgeAutomation, :refresh_gap_candidates, 1)
    assert function_exported?(KnowledgeAutomation, :schedule_gap_candidate_refresh, 2)
    assert function_exported?(KnowledgeAutomation, :rebuild_gap_candidates, 1)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end
end
