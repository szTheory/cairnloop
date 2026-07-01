defmodule Cairnloop.Workers.ApprovalResumeWorker do
  @moduledoc """
  Oban worker that re-validates a governed tool approval before it can proceed to execution.

  This is the Phase 15 deliverable: the "stale-plan" re-validation gate (Terraform semantics).
  An approval valid at decision time is re-checked against the CURRENT policy/scope at resume
  time before transitioning to `:execution_pending`.

  ## Branch Logic

  The resume worker is enqueued by `Governance.approve/3`, which has already transitioned the
  lane to `:approved`. It therefore acts on `:approved` approvals (the documented state axis:
  `:approved → resume → :execution_pending`). A still-`:pending` lane (awaiting an operator
  decision) is a no-op — re-validation must never bypass the approval gate.

  1. `nil` approval (deleted) → `:ok` — idempotent no-op.
  2. `:approved` + `expires_at < now` → `:expired` + `:expired` event (lazy guard, D15-12).
  3. `:approved` + re-validation pass → `:execution_pending` + `:revalidation_passed` event.
     STOP — does NOT call `run/3` (Phase 16 seam, D15-10).
  4. `:approved` + re-validation fail → `:invalidated` + `:revalidation_failed` event with
     humanized reason (fail-closed, APRV-03).
  5. Any other status (`:pending`, `:rejected`, etc.) → `:ok` — idempotent no-op.

  ## Idempotency

  `unique: [period: :infinity, keys: [:approval_id]]` prevents double-enqueue (D15-09).
  `perform/1` re-checks status so a duplicate job is a true no-op.

  ## Telemetry

  `:approval_transition` event emitted AFTER the `with` pipeline succeeds (D-29).
  """

  use Oban.Worker,
    queue: :default,
    unique: [period: :infinity, fields: [:worker, :args], keys: [:approval_id]]

  require Logger

  alias Cairnloop.Governance.{ToolApproval, ToolProposal, ToolActionEvent}
  alias Cairnloop.Governance.Telemetry.Traces
  alias Cairnloop.Workers.ToolExecutionWorker

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

      %ToolApproval{status: :approved} = approval ->
        # Lazy expires_at guard: belt-and-suspenders — fires BEFORE re-validation (D15-12)
        # so a missed scheduled sweep can never let a stale approval execute
        if approval.expires_at && DateTime.before?(approval.expires_at, DateTime.utc_now()) do
          expire_approval(approval)
        else
          revalidate_and_transition(approval)
        end

        :ok

      _ ->
        # Still :pending (awaiting decision) or already transitioned — idempotent no-op.
        # Re-validation must never act on a lane the operator has not approved.
        :ok
    end
  end

  # Re-calls the pure Governance.validate/3 against CURRENT context (D15-10).
  # validate/3 is free by construction — no side effects, no DB reads.
  defp revalidate_and_transition(approval) do
    proposal = repo().get!(ToolProposal, approval.tool_proposal_id, repo_opts())

    # Rebuild context from the proposal's snapshot fields.
    # String keys from JSONB are rehydrated to atoms safely via String.to_existing_atom/1
    # with ArgumentError rescue — never String.to_atom/1 (D-19, T-15-08).
    context = rebuild_context_from_snapshot(proposal)

    case Cairnloop.Governance.validate(proposal.tool_ref, proposal.actor_id, context) do
      {:ok, _validated} ->
        # Phase 16 additive (D16-04): transition to :execution_pending, then enqueue
        # ToolExecutionWorker. Still NEVER calls run/3 — execution is the worker's job.
        transition_approval(approval, :execution_pending, :revalidation_passed, nil, "system")
        # Phase 16 additive: enqueue execution worker (record-before-enqueue ordering preserved).
        # safe_enqueue wraps Oban.insert in try/rescue — host may have no Oban runtime.
        safe_enqueue(ToolExecutionWorker.new(%{"approval_id" => approval.id}))

      {:blocked, _outcome, reason} ->
        # Fail-closed: invalidate with humanized operator-visible reason (APRV-03, D15-11)
        transition_approval(
          approval,
          :invalidated,
          :revalidation_failed,
          humanize_reason(reason),
          "system"
        )
    end
  end

  # Builds the validation context from the snapshotted proposal fields.
  # The snapshot maps come from JSONB (string keys at runtime), so we rebuild
  # a context map that validate/3 / check_scope / validate_input expect.
  defp rebuild_context_from_snapshot(proposal) do
    # scope_snapshot stores %{"scopes" => [...]}; rehydrate the list safely
    scopes =
      case proposal.scope_snapshot do
        %{"scopes" => scope_list} when is_list(scope_list) ->
          Enum.flat_map(scope_list, fn s ->
            if is_binary(s) do
              try do
                [String.to_existing_atom(s)]
              rescue
                ArgumentError -> []
              end
            else
              [s]
            end
          end)

        %{scopes: scope_list} when is_list(scope_list) ->
          scope_list

        _ ->
          []
      end

    # input_snapshot stores the tool params — pass through as tool_params so
    # validate_input can run the tool changeset against them.
    # String keys from JSONB stay as-is; the tool changeset's cast/2 handles them.
    tool_params =
      case proposal.input_snapshot do
        params when is_map(params) -> params
        _ -> %{}
      end

    %{scopes: scopes, tool_params: tool_params}
  end

  # Lazy expiry: transition :pending → :expired without re-validation (D15-12).
  defp expire_approval(approval) do
    transition_approval(approval, :expired, :expired, nil, "system")
  end

  # Sequential `with` co-commit: update approval status + insert ToolActionEvent.
  # Mirrors knowledge_automation.ex update_task_with_event/4 (NOT Ecto.Multi).
  # Telemetry is emitted AFTER the `with` pipeline succeeds (D-29).
  defp transition_approval(approval, new_status, event_type, reason, actor_id) do
    cs =
      Ecto.Changeset.change(approval, %{
        status: new_status,
        decided_at: DateTime.utc_now()
      })

    with {:ok, updated} <- repo().update(cs, repo_opts()),
         {:ok, _event} <-
           %ToolActionEvent{}
           |> ToolActionEvent.changeset(%{
             tool_proposal_id: approval.tool_proposal_id,
             event_type: event_type,
             from_status: nil,
             to_status: nil,
             actor_id: actor_id,
             reason: reason,
             metadata: %{
               approval_status: approval.status,
               new_approval_status: new_status
             }
           })
           |> repo().insert(repo_opts()) do
      # Telemetry AFTER with success — never inside the with clause list (D-29)
      Cairnloop.Telemetry.execute(
        [:governance, :approval_transition],
        %{count: 1},
        %{event_type: event_type, new_status: new_status}
      )

      # OI trace event — additive, fire-and-forget, after bounded-metrics (Phase 17)
      Traces.emit(event_type, %{
        tool_proposal_id: approval.tool_proposal_id,
        actor_id: actor_id,
        decided_by: Map.get(updated, :decided_by),
        attempt: nil
      })

      {:ok, updated}
    end
  end

  # NOTE: mirrors Governance.safe_enqueue/1 — host may have no Oban runtime
  defp safe_enqueue(job) do
    try do
      Oban.insert(job)
    rescue
      e ->
        require Logger
        Logger.warning("Oban enqueue failed: #{inspect(e)}")
        :ok
    end
  end

  # WR-01 / D15-15: humanize a blocked reason — never inspect/1, never raw Elixir terms.
  # Mirrors the governance.ex insert_blocked_proposal/10 humanize_reason pattern.
  defp humanize_reason(reason) do
    case reason do
      %Ecto.Changeset{} = cs ->
        cs
        |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
          Enum.reduce(opts, msg, fn {k, v}, acc ->
            String.replace(acc, "%{#{k}}", to_string(v))
          end)
        end)
        |> Enum.map(fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
        |> Enum.join("; ")

      atom when is_atom(atom) ->
        Atom.to_string(atom)

      binary when is_binary(binary) ->
        binary

      _ ->
        "blocked"
    end
  end
end
