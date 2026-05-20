defmodule Cairnloop.Retrieval.TelemetryTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Retrieval
  alias Cairnloop.Retrieval.Result
  alias Cairnloop.Retrieval.Telemetry

  defmodule KnowledgeBaseProviderMock do
    def search("billing export", _opts) do
      [
        %Result{
          id: 1,
          title: "Billing export policy",
          content: "Canonical article on billing exports",
          source_type: :knowledge_base,
          trust_level: :canonical,
          visibility: :host,
          citation_target: %{revision_id: 10, chunk_index: 0},
          keyword_rank: 1,
          semantic_rank: 1
        }
      ]
    end
  end

  defmodule ResolvedCasesProviderMock do
    def search("billing export", _opts) do
      [
        %Result{
          id: 2,
          title: "Resolved billing export case",
          content: "Assistive case with a similar failure mode",
          source_type: :resolved_case,
          trust_level: :assistive,
          visibility: :host,
          citation_target: %{conversation_id: 20, chunk_index: 0},
          keyword_rank: 1,
          semantic_rank: 2,
          can_ground_reply?: false
        }
      ]
    end
  end

  defmodule TimeoutProviderMock do
    def search(_query, _opts),
      do: raise(RuntimeError, "provider timeout while retrieving results")
  end

  setup do
    test_pid = self()
    handler_id = "retrieval-telemetry-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      [Telemetry.search_event_name(), Telemetry.draft_grounding_event_name()],
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  test "search telemetry emits bounded metadata without raw query text or identifiers" do
    Retrieval.search("billing export",
      surface: :search_modal,
      providers: %{
        knowledge_base: KnowledgeBaseProviderMock,
        resolved_cases: ResolvedCasesProviderMock
      }
    )

    assert_receive {:telemetry_event, [:cairnloop, :retrieval, :search], measurements, metadata}
    assert measurements.count == 1
    assert is_integer(measurements.duration_ms)
    assert measurements.duration_ms >= 0
    assert metadata.surface == :search_modal
    assert metadata.source_mix == :mixed
    assert metadata.result_bucket == :few
    assert metadata.grounding_status == :not_applicable
    assert metadata.diagnostic_class == :search_results
    assert metadata.reason == :mixed_results
    assert metadata.canonical_hit_count == 1
    assert metadata.assistive_hit_count == 1
    assert metadata.ranking_outcome == :canonical_first
    refute Map.has_key?(metadata, :query)
    refute Map.has_key?(metadata, :evidence)
    refute Map.has_key?(metadata, :citation_target)
  end

  test "draft grounding telemetry carries structured diagnostics with the coarse status preserved" do
    Retrieval.ground_for_draft("billing export",
      providers: %{
        knowledge_base: KnowledgeBaseProviderMock,
        resolved_cases: ResolvedCasesProviderMock
      }
    )

    assert_receive {:telemetry_event, [:cairnloop, :retrieval, :search], _measurements, _metadata}

    assert_receive {:telemetry_event, [:cairnloop, :retrieval, :draft_grounding], measurements,
                    metadata}

    assert measurements.count == 1
    assert metadata.surface == :draft_generation
    assert metadata.source_mix == :mixed
    assert metadata.result_bucket == :few
    assert metadata.grounding_status == :strong
    assert metadata.diagnostic_class == :grounded
    assert metadata.reason == :canonical_results
    assert metadata.canonical_hit_count == 1
    assert metadata.assistive_hit_count == 1
    assert metadata.ranking_outcome == :canonical_first
  end

  test "retrieval errors emit bounded telemetry for both search and draft grounding" do
    grounding =
      Retrieval.ground_for_draft("billing export",
        surface: :api,
        providers: %{
          knowledge_base: TimeoutProviderMock,
          resolved_cases: ResolvedCasesProviderMock
        }
      )

    assert grounding.grounding_assessment.reason == :provider_timeout

    assert_receive {:telemetry_event, [:cairnloop, :retrieval, :search], _measurements,
                    search_meta}

    assert search_meta.surface == :api
    assert search_meta.diagnostic_class == :retrieval_error
    assert search_meta.reason == :provider_timeout
    assert search_meta.canonical_hit_count == 0
    assert search_meta.assistive_hit_count == 0

    assert_receive {:telemetry_event, [:cairnloop, :retrieval, :draft_grounding], _measurements,
                    grounding_meta}

    assert grounding_meta.surface == :api
    assert grounding_meta.grounding_status == :escalation
    assert grounding_meta.diagnostic_class == :retrieval_error
    assert grounding_meta.reason == :provider_timeout
    refute Map.has_key?(grounding_meta, :query)
  end
end
