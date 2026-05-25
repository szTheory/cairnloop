defmodule Cairnloop.KnowledgeAutomation.CandidateBuilderTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation.CandidateBuilder
  alias Cairnloop.Retrieval.GapEvent

  test "compatible retrieval gap events collapse into one stable key" do
    events = [
      %GapEvent{
        id: 1,
        occurred_at: ~U[2026-05-20 10:00:00Z],
        tenant_scope: :host_user_scoped,
        host_user_id: "u-1",
        ui_surface: :conversation,
        outcome_class: :empty_recall,
        reason: :no_canonical_results,
        sanitized_query_excerpt: "Billing export timeout"
      },
      %GapEvent{
        id: 2,
        occurred_at: ~U[2026-05-21 10:00:00Z],
        tenant_scope: :host_user_scoped,
        host_user_id: "u-1",
        ui_surface: :conversation,
        outcome_class: :weak_grounding,
        reason: :assistive_only_results,
        sanitized_query_excerpt: "billing export timeout?"
      }
    ]

    [candidate] = CandidateBuilder.build(events, [])

    assert candidate.candidate.evidence_count == 2
    assert candidate.candidate.candidate_type == :mixed
    assert length(candidate.memberships) == 2
  end

  test "repeated manual handling is projected only from durable draft and resolved-case state" do
    signals = [
      %{
        source_type: :manual_handling_case,
        source_id: 10,
        tenant_scope: :host_user_scoped,
        host_user_id: "u-1",
        ui_surface: :conversation,
        issue_summary: "Billing export failed",
        topic_seed: "billing export failed",
        occurred_at: ~U[2026-05-20 08:00:00Z]
      },
      %{
        source_type: :manual_handling_case,
        source_id: 11,
        tenant_scope: :host_user_scoped,
        host_user_id: "u-1",
        ui_surface: :conversation,
        issue_summary: "Billing export failed again",
        topic_seed: "billing export failed",
        occurred_at: ~U[2026-05-21 08:00:00Z]
      }
    ]

    [candidate] = CandidateBuilder.build([], signals)

    assert candidate.candidate.manual_case_count == 2
    assert candidate.candidate.candidate_type == :manual_handling
  end

  test "score components stay deterministic and manual handling outranks equivalent pure no-hit volume" do
    no_hit_candidate =
      CandidateBuilder.build(
        [
          %GapEvent{
            id: 1,
            occurred_at: ~U[2026-05-21 10:00:00Z],
            tenant_scope: :system_unscoped,
            ui_surface: :conversation,
            outcome_class: :empty_recall,
            reason: :no_canonical_results,
            sanitized_query_excerpt: "Export issue"
          },
          %GapEvent{
            id: 2,
            occurred_at: ~U[2026-05-21 11:00:00Z],
            tenant_scope: :system_unscoped,
            ui_surface: :conversation,
            outcome_class: :empty_recall,
            reason: :no_canonical_results,
            sanitized_query_excerpt: "Export issue"
          }
        ],
        []
      )
      |> List.first()

    manual_candidate =
      CandidateBuilder.build(
        [],
        [
          %{
            source_type: :manual_handling_case,
            source_id: 10,
            tenant_scope: :system_unscoped,
            ui_surface: :conversation,
            issue_summary: "Export issue",
            topic_seed: "export issue",
            occurred_at: ~U[2026-05-21 10:00:00Z]
          },
          %{
            source_type: :manual_handling_case,
            source_id: 11,
            tenant_scope: :system_unscoped,
            ui_surface: :conversation,
            issue_summary: "Export issue again",
            topic_seed: "export issue",
            occurred_at: ~U[2026-05-21 11:00:00Z]
          }
        ]
      )
      |> List.first()

    assert no_hit_candidate.candidate.score_components ==
             no_hit_candidate.candidate.score_components

    assert manual_candidate.candidate.score > no_hit_candidate.candidate.score
  end
end
