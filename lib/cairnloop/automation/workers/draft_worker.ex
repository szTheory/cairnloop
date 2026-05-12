defmodule Cairnloop.Automation.Workers.DraftWorker do
  use Oban.Worker,
    queue: :default,
    unique: [period: 60, states: [:scheduled]],
    replace: [scheduled: [:scheduled_at]]

  def perform(%Oban.Job{args: %{"conversation_id" => conversation_id}}) do
    trace_id = Ecto.UUID.generate()
    start_time = System.system_time()
    start_mono = System.monotonic_time()

    :telemetry.execute(
      [:openinference, :span, :start],
      %{system_time: start_time},
      %{trace_id: trace_id, span_name: "DraftWorker", span_kind: "AGENT"}
    )

    result =
      case Cairnloop.Automation.ScoriaEngine.generate_draft(conversation_id) do
        {:ok, proposal} ->
          policy =
            Application.get_env(:cairnloop, :automation_policy, Cairnloop.DefaultAutomationPolicy)

          case policy.decide(proposal, %{}) do
            decision when decision in [:draft_only, :require_approval] ->
              handle_create_draft(conversation_id, proposal.content, :pending)

            :allow ->
              handle_create_draft(conversation_id, proposal.content, :approved)

            :deny ->
              :ok
          end

        _error ->
          :error
      end

    duration = System.monotonic_time() - start_mono

    status = if result == :ok, do: :ok, else: :error

    :telemetry.execute(
      [:openinference, :span, :stop],
      %{duration: duration},
      %{status: status}
    )

    result
  end

  defp handle_create_draft(conversation_id, content, status) do
    case Cairnloop.Automation.create_draft(conversation_id, %{content: content, status: status}) do
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
end
