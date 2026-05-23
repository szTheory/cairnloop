defmodule Cairnloop.Automation.Workers.DraftWorker do
  use Oban.Worker,
    queue: :default,
    unique: [period: 60, states: [:scheduled]],
    replace: [scheduled: [:scheduled_at]]

  alias Cairnloop.Retrieval.GapRecorder

  def perform(%Oban.Job{args: %{"conversation_id" => conversation_id}}) do
    trace_id = Ecto.UUID.generate()
    start_time = System.system_time()
    start_mono = System.monotonic_time()

    :telemetry.execute(
      [:openinference, :span, :start],
      %{system_time: start_time},
      %{trace_id: trace_id, span_name: "DraftWorker", span_kind: "AGENT"}
    )

    result = execute_draft(conversation_id)
    duration = System.monotonic_time() - start_mono
    status = if result == :ok, do: :ok, else: :error

    :telemetry.execute(
      [:openinference, :span, :stop],
      %{duration: duration},
      %{status: status}
    )

    result
  end

  defp execute_draft(conversation_id) do
    latest_draft = Cairnloop.Automation.latest_draft_for_conversation(conversation_id)
    retrieval = Application.get_env(:cairnloop, :retrieval_module, Cairnloop.Retrieval)
    query_builder = Application.get_env(:cairnloop, :draft_query_builder, &default_query/1)
    conversation_lookup =
      Application.get_env(:cairnloop, :conversation_lookup, &Cairnloop.Chat.get_conversation!/1)

    conversation = conversation_lookup.(conversation_id)

    draft_context = %{
      conversation_id: conversation_id,
      query: query_builder.(conversation_id),
      clarification_attempts: (latest_draft && latest_draft.clarification_attempts) || 0,
      host_user_id: conversation.host_user_id,
      host_surface: "conversation"
    }

    retrieval_opts = [
      surface: :draft_generation,
      host_surface: draft_context.host_surface,
      host_user_id: draft_context.host_user_id
    ]

    grounding_bundle = retrieval.ground_for_draft(draft_context, retrieval_opts)
    _ = maybe_record_grounding_gap(grounding_bundle, draft_context)

    case Cairnloop.Automation.ScoriaEngine.generate_draft(conversation_id, grounding_bundle) do
      {:ok, proposal} ->
        case proposal.proposal_type do
          :reply -> apply_policy_and_create_draft(conversation_id, proposal)
          :clarification -> handle_create_draft(conversation_id, proposal, :pending)
          :escalation -> handle_create_draft(conversation_id, proposal, :pending)
        end

      _error ->
        :error
    end
  end

  defp apply_policy_and_create_draft(conversation_id, proposal) do
    policy =
      Application.get_env(:cairnloop, :automation_policy, Cairnloop.DefaultAutomationPolicy)

    case policy.decide(proposal, %{}) do
      decision when decision in [:draft_only, :require_approval] ->
        handle_create_draft(conversation_id, proposal, :pending)

      :allow ->
        handle_create_draft(conversation_id, proposal, :approved)

      :deny ->
        :ok
    end
  end

  defp handle_create_draft(conversation_id, proposal, status) do
    attrs = %{
      status: status,
      proposal_type: proposal.proposal_type,
      operator_summary: proposal.operator_summary,
      customer_reply: proposal.customer_reply,
      content: proposal.customer_reply,
      evidence_snapshot: %{evidence: proposal.evidence},
      grounding_metadata: proposal.grounding_metadata,
      clarification_attempts: proposal.clarification_attempts
    }

    case Cairnloop.Automation.create_draft(conversation_id, attrs) do
      {:ok, draft} ->
        Phoenix.PubSub.broadcast(
          Cairnloop.PubSub,
          "conversation:#{conversation_id}",
          {:draft_created, draft.id}
        )

        :ok

      {:error, _changeset} ->
        :error
    end
  end

  defp default_query(conversation_id), do: "Conversation #{conversation_id}"

  defp maybe_record_grounding_gap(%{diagnostic: %{class: :grounded}}, _draft_context), do: :ok

  defp maybe_record_grounding_gap(%{} = grounding_bundle, draft_context) do
    diagnostic = Map.get(grounding_bundle, :diagnostic, %{})

    attrs = %{
      query: grounding_bundle.query || draft_context.query,
      surface: :draft_generation,
      outcome_class: diagnostic.class || :retrieval_error,
      reason: diagnostic.reason || :unexpected_error,
      host_user_id: draft_context.host_user_id,
      tenant_scope: :host_user_scoped,
      ui_surface: draft_context.host_surface,
      canonical_hit_count: diagnostic.canonical_hit_count || 0,
      assistive_hit_count: diagnostic.assistive_hit_count || 0,
      clarification_attempts: grounding_bundle.clarification_attempts || 0,
      attempted_evidence: Map.get(grounding_bundle, :evidence, [])
    }

    case gap_recorder().record(attrs) do
      {:ok, _gap_event} -> :ok
      {:error, _reason} -> :error
      _ -> :ok
    end
  end

  defp gap_recorder do
    Application.get_env(:cairnloop, :gap_recorder, GapRecorder)
  end
end
