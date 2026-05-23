defmodule Cairnloop.Automation.ScoriaEngineTest do
  use ExUnit.Case, async: true

  alias Cairnloop.Automation.ScoriaEngine

  describe "ScoriaEngine" do
    test "generate_draft/2 returns a structured grounded reply proposal" do
      grounding_bundle = %{
        query: "billing export",
        canonical_results: [
          %{
            content: "Exports are available under Billing > Reports.",
            source_type: :knowledge_base
          }
        ],
        assistive_results: [],
        evidence: [%{source_type: :knowledge_base, trust_level: :canonical}],
        clarification_attempts: 0,
        grounding_assessment: %{status: :strong, reason: :canonical_grounding}
      }

      assert {:ok, proposal} = ScoriaEngine.generate_draft("conv_987", grounding_bundle)

      assert proposal.conversation_id == "conv_987"
      assert proposal.proposal_type == :reply
      assert is_binary(proposal.operator_summary)
      assert is_binary(proposal.customer_reply)
      assert proposal.customer_reply =~ "Knowledge Base guidance"
      assert proposal.grounding_metadata.grounding_status == :strong
    end

    test "generate_draft/2 returns escalation copy for weak grounding" do
      grounding_bundle = %{
        query: "mystery failure",
        canonical_results: [],
        assistive_results: [%{source_type: :resolved_case}],
        evidence: [%{source_type: :resolved_case, trust_level: :assistive}],
        clarification_attempts: 1,
        grounding_assessment: %{status: :escalation, reason: :clarification_limit_reached}
      }

      assert {:ok, proposal} = ScoriaEngine.generate_draft("conv_123", grounding_bundle)

      assert proposal.proposal_type == :escalation
      assert proposal.customer_reply =~ "escalate"
      assert proposal.clarification_attempts == 1
    end
  end
end
