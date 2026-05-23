defmodule Cairnloop.KnowledgeAutomation.ManualHandlingSignal do
  import Ecto.Query

  alias Cairnloop.Automation
  alias Cairnloop.Automation.Draft
  alias Cairnloop.Retrieval.ResolvedCaseEvidence

  @default_window_days 90

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def list_recent(opts \\ []) do
    window_days = Keyword.get(opts, :window_days, @default_window_days)

    evidences =
      Keyword.get_lazy(opts, :resolved_case_evidences, fn ->
        cutoff = DateTime.add(DateTime.utc_now(), -window_days * 86_400, :second)

        ResolvedCaseEvidence
        |> where([evidence], evidence.resolved_at >= ^cutoff)
        |> order_by([evidence], desc: evidence.resolved_at, desc: evidence.id)
        |> repo().all()
      end)

    latest_draft_fn = Keyword.get(opts, :latest_draft_fn, &latest_draft_for_conversation/1)

    evidences
    |> Enum.map(&build_signal(&1, latest_draft_fn.(&1.conversation_id)))
    |> Enum.reject(&is_nil/1)
  end

  defp latest_draft_for_conversation(conversation_id) do
    Automation.latest_draft_for_conversation(conversation_id)
  end

  defp build_signal(%ResolvedCaseEvidence{} = evidence, %Draft{} = draft) do
    if manual_handling_draft?(draft) do
      %{
        source_type: :manual_handling_case,
        source_id: evidence.id,
        conversation_id: evidence.conversation_id,
        tenant_scope: tenant_scope_for(evidence),
        host_user_id: blank_to_nil(evidence.host_user_id),
        ui_surface: :conversation,
        subject: evidence.subject,
        issue_summary: evidence.issue_summary,
        resolution_note: evidence.resolution_note,
        actions_taken: evidence.actions_taken || [],
        citation_backreferences: evidence.citation_backreferences || [],
        topic_seed: normalize_topic_seed(evidence.issue_summary || evidence.subject || ""),
        occurred_at: evidence.resolved_at,
        draft_status: draft.status,
        draft_proposal_type: draft.proposal_type
      }
    end
  end

  defp build_signal(_evidence, _draft), do: nil

  defp manual_handling_draft?(%Draft{status: :edited}), do: true

  defp manual_handling_draft?(%Draft{proposal_type: proposal_type})
       when proposal_type in [:clarification, :escalation],
       do: true

  defp manual_handling_draft?(_draft), do: false

  defp tenant_scope_for(%ResolvedCaseEvidence{host_user_id: host_user_id}) do
    if blank_to_nil(host_user_id), do: :host_user_scoped, else: :system_unscoped
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: to_string(value)

  def normalize_topic_seed(text) do
    text
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]+/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.split(" ", trim: true)
    |> Enum.take(8)
    |> Enum.join(" ")
  end
end
