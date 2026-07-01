defmodule Cairnloop.Workers.ApprovalExpiryWorker do
  @moduledoc """
  Oban worker that performs the scheduled `:pending → :expired` flip for governed tool approvals.

  This is the scheduled-sweep half of the dual-mechanism TTL enforcement (D15-12):
  1. This worker (scheduled enqueue) — flips `:pending` approvals to `:expired` at `expires_at`.
  2. Lazy guard in `ApprovalResumeWorker` — catches any approval the sweep missed.

  The scheduled enqueue of this worker (`scheduled_at: approval.expires_at`) lives in
  plan 15-03's lane-opening path (`Governance.approve/3`). This worker only performs the flip.

  ## Branch Logic

  1. `nil` approval (deleted) → `:ok` — idempotent no-op.
  2. `:pending` approval → status `:expired` + `:expired` `ToolActionEvent` co-committed.
  3. Any other status (`:approved`, `:rejected`, `:expired`, etc.) → `:ok` — idempotent no-op.

  ## Idempotency

  The no-op catch-all guarantees safety if the worker runs late or twice: a non-`:pending`
  approval will not be re-expired (mirrors `SlaCountdownWorker` `:active → :breached` idiom).

  ## Telemetry

  `:approval_transition` event emitted AFTER the `with` pipeline succeeds (D-29).
  """

  use Oban.Worker, queue: :default

  alias Cairnloop.Governance.{ToolApproval, ToolActionEvent}

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  defp repo_opts, do: Cairnloop.SchemaPrefix.repo_opts()

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"approval_id" => approval_id}}) do
    case repo().get(ToolApproval, approval_id, repo_opts()) do
      nil ->
        # Deleted — idempotent no-op (mirrors SlaCountdownWorker nil branch)
        :ok

      %ToolApproval{status: :pending} = approval ->
        # Flip :pending → :expired (mirrors SlaCountdownWorker :active → :breached flip)
        expire_approval(approval)
        :ok

      _ ->
        # Already resolved — idempotent no-op (mirrors SlaCountdownWorker catch-all)
        :ok
    end
  end

  # Sequential `with` co-commit: update status + insert ToolActionEvent.
  # Mirrors knowledge_automation.ex update_task_with_event/4 (NOT Ecto.Multi).
  # Telemetry emitted AFTER the `with` pipeline succeeds (D-29).
  defp expire_approval(approval) do
    cs =
      Ecto.Changeset.change(approval, %{
        status: :expired,
        decided_at: DateTime.utc_now()
      })

    with {:ok, updated} <- repo().update(cs, repo_opts()),
         {:ok, _event} <-
           %ToolActionEvent{}
           |> ToolActionEvent.changeset(%{
             tool_proposal_id: approval.tool_proposal_id,
             event_type: :expired,
             from_status: nil,
             to_status: nil,
             actor_id: "system",
             reason: nil,
             metadata: %{
               approval_status: approval.status,
               new_approval_status: :expired
             }
           })
           |> repo().insert(repo_opts()) do
      # Telemetry AFTER with success — never inside the with clause list (D-29)
      Cairnloop.Telemetry.execute(
        [:governance, :approval_transition],
        %{count: 1},
        %{event_type: :expired, new_status: :expired}
      )

      {:ok, updated}
    end
  end
end
