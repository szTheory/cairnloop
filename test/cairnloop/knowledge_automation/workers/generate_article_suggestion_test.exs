defmodule Cairnloop.KnowledgeAutomation.Workers.GenerateArticleSuggestionTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion
  alias Cairnloop.KnowledgeAutomation.Workers.GenerateArticleSuggestion

  defmodule MockKnowledgeAutomation do
    def get_article_suggestion!(id) do
      Process.get(:worker_suggestion_lookup).(id)
    end

    def prepare_generation_bundle_from_suggestion(suggestion) do
      Process.get(:prepared_bundle, %{
        valid?: true,
        canonical_evidence: suggestion.evidence_snapshot,
        assistive_evidence: [],
        evidence_digest: suggestion.evidence_digest
      })
    end

    def mark_article_suggestion_ready(suggestion, proposal) do
      Process.put(:worker_ready, {suggestion, proposal})
      {:ok, suggestion}
    end

    def mark_article_suggestion_failed(suggestion, reason) do
      Process.put(:worker_failed, {suggestion, reason})
      {:ok, suggestion}
    end
  end

  defmodule MockScoriaEngine do
    def generate_article_suggestion(_suggestion, _bundle) do
      Process.get(:worker_scoria_result, {:ok, %{operator_summary: "ok", proposed_markdown: "# Draft", evidence_metadata: %{citations: []}}})
    end
  end

  setup do
    Application.put_env(:cairnloop, :knowledge_automation, MockKnowledgeAutomation)
    Application.put_env(:cairnloop, :scoria_engine, MockScoriaEngine)

    on_exit(fn ->
      [
        :worker_suggestion_lookup,
        :prepared_bundle,
        :worker_ready,
        :worker_failed,
        :worker_scoria_result
      ]
      |> Enum.each(&Process.delete/1)

      Application.delete_env(:cairnloop, :knowledge_automation)
      Application.delete_env(:cairnloop, :scoria_engine)
    end)

    :ok
  end

  test "new_job keeps entrypoint identity and evidence digest in the Oban args" do
    job =
      GenerateArticleSuggestion.new_job(%{
        suggestion_id: 12,
        entrypoint_type: :gap_candidate,
        entrypoint_id: 101,
        base_revision_id: 44,
        evidence_digest: "digest-1"
      })

    args = Ecto.Changeset.get_change(job, :args)

    assert args["suggestion_id"] == 12
    assert args["entrypoint_type"] == :gap_candidate
    assert args["entrypoint_id"] == 101
    assert args["base_revision_id"] == 44
    assert args["evidence_digest"] == "digest-1"
  end

  test "perform marks a suggestion ready when the generation seam returns a proposal" do
    suggestion = %ArticleSuggestion{id: 12, evidence_snapshot: [], evidence_digest: "digest-1"}
    Process.put(:worker_suggestion_lookup, fn 12 -> suggestion end)

    assert :ok = GenerateArticleSuggestion.perform(%Oban.Job{args: %{"suggestion_id" => 12}})
    assert {^suggestion, %{proposed_markdown: "# Draft"}} = Process.get(:worker_ready)
  end

  test "perform fails closed when the prepared bundle is not generation-safe" do
    suggestion = %ArticleSuggestion{id: 12, evidence_snapshot: [], evidence_digest: "digest-1"}
    Process.put(:worker_suggestion_lookup, fn 12 -> suggestion end)
    Process.put(:prepared_bundle, %{valid?: false, failure_reason: :missing_canonical_citations})

    assert :ok = GenerateArticleSuggestion.perform(%Oban.Job{args: %{"suggestion_id" => 12}})
    assert {^suggestion, :missing_canonical_citations} = Process.get(:worker_failed)
  end
end
