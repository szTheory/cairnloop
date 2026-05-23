defmodule Cairnloop.Automation.ScoriaEngine do
  @moduledoc """
  Mock execution engine for Scoria integration.
  Generates structured grounded proposals for operator review.
  """

  @doc """
  Builds a structured proposal from the retrieval grounding bundle.
  """
  def generate_draft(conversation_id, grounding_bundle) do
    assessment = grounding_bundle.grounding_assessment
    evidence = Map.get(grounding_bundle, :evidence, [])

    proposal =
      case assessment.status do
        :strong ->
          primary_evidence = List.first(grounding_bundle.canonical_results)

          %{
            proposal_type: :reply,
            operator_summary:
              "Grounded in canonical Knowledge Base guidance with explicit citations for operator review.",
            customer_reply: grounded_reply(primary_evidence),
            evidence: evidence,
            grounding_metadata: %{
              grounding_status: :strong,
              reason: assessment.reason,
              query: grounding_bundle.query
            },
            clarification_attempts: grounding_bundle.clarification_attempts
          }

        :clarification ->
          %{
            proposal_type: :clarification,
            operator_summary:
              "Canonical guidance is close, but one customer detail is still missing before a grounded reply is safe.",
            customer_reply:
              "Before I confirm the next step, could you share the specific error message or screen you see when this happens?",
            evidence: evidence,
            grounding_metadata: %{
              grounding_status: :clarification,
              reason: assessment.reason,
              query: grounding_bundle.query
            },
            clarification_attempts: grounding_bundle.clarification_attempts + 1
          }

        :escalation ->
          %{
            proposal_type: :escalation,
            operator_summary:
              "Grounding is insufficient for a safe customer-facing answer. Escalate with the evidence snapshot instead of bluffing.",
            customer_reply:
              "I don't have enough verified guidance to answer confidently from the current information. Please escalate this thread for manual review.",
            evidence: evidence,
            grounding_metadata: %{
              grounding_status: :escalation,
              reason: assessment.reason,
              query: grounding_bundle.query
            },
            clarification_attempts: grounding_bundle.clarification_attempts
          }
      end

    {:ok,
     proposal
     |> Map.put(:conversation_id, conversation_id)
     |> Map.put(:content, proposal.customer_reply)}
  end

  def generate_article_suggestion(suggestion, grounding_bundle) do
    canonical_evidence = Map.get(grounding_bundle, :canonical_evidence, [])
    assistive_evidence = Map.get(grounding_bundle, :assistive_evidence, [])
    citations = Enum.map(canonical_evidence, &citation_metadata/1)

    if canonical_evidence == [] do
      {:error, :missing_canonical_citations}
    else
      proposal =
        case suggestion.suggestion_type do
          :article ->
            %{
              title: suggestion.title || title_from_evidence(canonical_evidence),
              operator_summary:
                "Prepared a citation-backed article suggestion with #{length(canonical_evidence)} canonical anchors and #{length(assistive_evidence)} supporting rows.",
              proposed_markdown: article_markdown(suggestion, canonical_evidence, assistive_evidence),
              evidence_metadata: %{citations: citations, assistive_count: length(assistive_evidence)}
            }

          :revision ->
            %{
              change_summary:
                suggestion.change_summary ||
                  "Revision grounded in repeated article-linked failures and fresh canonical evidence.",
              operator_summary:
                "Prepared a citation-backed revision suggestion with #{length(canonical_evidence)} canonical anchors and #{length(assistive_evidence)} supporting rows.",
              proposed_markdown: revision_markdown(suggestion, canonical_evidence, assistive_evidence),
              evidence_metadata: %{citations: citations, assistive_count: length(assistive_evidence)}
            }
        end

      {:ok, proposal}
    end
  end

  defp grounded_reply(nil) do
    "I found the relevant Knowledge Base guidance and drafted a grounded reply for operator review."
  end

  defp grounded_reply(primary_evidence) do
    excerpt =
      primary_evidence.content
      |> to_string()
      |> String.slice(0, 180)

    "Based on our Knowledge Base guidance, here is the recommended response: #{excerpt}"
  end

  defp article_markdown(suggestion, canonical_evidence, assistive_evidence) do
    [
      "# #{suggestion.title || title_from_evidence(canonical_evidence)}",
      "",
      "## Summary",
      "",
      "Prepared from #{length(canonical_evidence)} canonical Knowledge Base anchors.",
      support_line(assistive_evidence),
      "",
      canonical_evidence
      |> Enum.map_join("\n\n", fn evidence ->
        "### #{evidence.title}\n\n#{truncate_excerpt(evidence.excerpt)}"
      end)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end

  defp revision_markdown(suggestion, canonical_evidence, assistive_evidence) do
    [
      "# #{suggestion.title || title_from_evidence(canonical_evidence)}",
      "",
      "## Suggested revision",
      "",
      suggestion.change_summary || "Clarify the article using the evidence below.",
      "",
      "## Canonical evidence",
      "",
      canonical_evidence
      |> Enum.map_join("\n\n", fn evidence ->
        "* #{evidence.title}: #{truncate_excerpt(evidence.excerpt)}"
      end),
      support_line(assistive_evidence)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end

  defp support_line([]), do: nil
  defp support_line(assistive_evidence), do: "Supporting evidence rows: #{length(assistive_evidence)}."

  defp title_from_evidence([primary | _]), do: primary.title
  defp title_from_evidence(_), do: "Knowledge Base suggestion"

  defp truncate_excerpt(value) when is_binary(value) and byte_size(value) > 240 do
    String.slice(value, 0, 239) <> "…"
  end

  defp truncate_excerpt(value), do: value

  defp citation_metadata(evidence) do
    %{
      title: evidence.title,
      citation_target: evidence.citation_target,
      trust_level: evidence.trust_level
    }
  end
end
