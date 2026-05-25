defmodule Cairnloop.Workers.ToolExecutionWorker do
  @moduledoc """
  The ONLY place `run/3` is ever called in Cairnloop.

  Consumes a `:execution_pending` `ToolApproval` lane, re-validates the proposal
  against current policy/scope, calls the tool's `run/3` on success, and
  co-commits the outcome (`:executed` + `:succeeded` result state + append-only event).

  Fail-closed on re-validation: policy/scope change since the resume worker ran causes
  `:invalidated`/`:execution_failed` with a humanized reason — nothing is written (T-16-02).

  ## Idempotency layers (D16-05, T-16-01)

  1. **Oban job uniqueness** — `unique: [period: :infinity, keys: [:approval_id]]` prevents
     double-enqueue (no two workers race for the same approval).
  2. **Pre-execution terminal guard (LAYER-1)** — any non-`:execution_pending` status is a
     true no-op (replayed/duplicate job, wrong-lane approval, already executed).
  3. **LAYER-2 terminal guard** — if `ToolProposal.result_state == :succeeded`, the approval
     has already been executed; another no-op (guards against TOCTOU between LAYER-1 check
     and commit, e.g. very fast replay).
  4. **Run-level idempotency key** — passed into `run/3` context as `:run_idempotency_key`;
     the tool uses an indexed existence check to dedup its own host write (Stripe-style).

  ## Retry semantics (D16-07)

  - Transient `{:error, reason}` from `run/3` with `attempt < max_attempts` → return
    `{:error, reason}` so Oban's built-in backoff retries.
  - Permanent failure (re-validation fail, or `attempt >= max_attempts`) → record terminal
    `:execution_failed` and return `{:cancel, reason}` (Oban discards; never retries).

  ## Telemetry (D16-10)

  `[:cairnloop, :governance, :action_executed]` and `[:cairnloop, :governance, :action_failed]`
  are emitted AFTER a successful `with` pipeline via `Governance.Telemetry` — never inside
  the clause list and never instead of a `ToolActionEvent` (D-29).
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: :infinity, fields: [:worker, :args], keys: [:approval_id]]

  require Logger

  alias Cairnloop.Governance.{ToolActionEvent, ToolApproval, ToolProposal}
  alias Cairnloop.Governance.Telemetry, as: GovTelemetry

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{attempt: attempt, max_attempts: max_attempts, args: %{"approval_id" => approval_id}}) do
    case repo().get(ToolApproval, approval_id) do
      nil ->
        # Deleted — idempotent no-op (mirrors SlaCountdownWorker nil branch)
        :ok

      %ToolApproval{status: :execution_pending} = approval ->
        execute_pending(approval, attempt, max_attempts)

      _ ->
        # Already terminal, wrong status, or still :pending — idempotent no-op.
        # Re-validation must not act on a lane not yet at :execution_pending.
        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Core execution path — only entered for :execution_pending approvals
  # ---------------------------------------------------------------------------

  defp execute_pending(approval, attempt, max_attempts) do
    proposal = repo().get!(ToolProposal, approval.tool_proposal_id)

    # LAYER-2 terminal guard (D16-05): if result_state == :succeeded, run/3 already
    # completed. This guards the TOCTOU window between the LAYER-1 status check and
    # the actual write under fast replay.
    if proposal.result_state == :succeeded do
      :ok
    else
      revalidate_and_execute(approval, proposal, attempt, max_attempts)
    end
  end

  defp revalidate_and_execute(approval, proposal, attempt, max_attempts) do
    # Rebuild the validation context from proposal snapshots (Pitfall 3: never pass empty context).
    # NOTE: mirrors ApprovalResumeWorker.rebuild_context_from_snapshot/1
    context = rebuild_context_from_snapshot(proposal)

    case Cairnloop.Governance.validate(proposal.tool_ref, proposal.actor_id, context) do
      {:ok, _validated} ->
        execute_tool(approval, proposal, context, attempt, max_attempts)

      {:blocked, _outcome, reason} ->
        # Re-validation failed — fail closed, write nothing (T-16-02, APRV-03)
        humanized = humanize_reason(reason)
        record_terminal_failure(approval, proposal, :invalidated, humanized)
        {:cancel, humanized}
    end
  end

  defp execute_tool(approval, proposal, context, attempt, max_attempts) do
    tool_ref = proposal.tool_ref

    case Cairnloop.ToolRegistry.find_tool_module(tool_ref) do
      {:error, :unknown_tool} ->
        humanized = "Tool #{tool_ref} is no longer registered"
        record_terminal_failure(approval, proposal, :execution_failed, humanized)
        {:cancel, humanized}

      {:ok, tool_module} ->
        # Build the tool struct from input_snapshot (cast via the tool's own changeset)
        tool_params = Map.get(context, :tool_params, %{})
        tool_struct = tool_module.changeset(struct(tool_module), tool_params) |> Ecto.Changeset.apply_changes()

        # Pass the run-level idempotency key into context (D16-05)
        # The per-attempt key is derived deterministically from the proposal's idempotency key
        # and the current attempt number so a retry gets a fresh key that won't collide with
        # any prior (failed) attempt's key at the tool's existence check.
        run_context = Map.put(context, :run_idempotency_key, derive_run_key(proposal))

        start = System.monotonic_time(:millisecond)
        result = tool_module.run(tool_struct, proposal.actor_id, run_context)
        duration_ms = System.monotonic_time(:millisecond) - start

        case result do
          {:ok, outcome} ->
            record_success(approval, proposal, outcome, attempt, duration_ms, tool_ref)

          {:error, reason} ->
            handle_transient_failure(approval, proposal, reason, attempt, max_attempts, tool_ref)
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Co-commit: success path
  # ---------------------------------------------------------------------------

  defp record_success(approval, proposal, outcome, attempt, duration_ms, tool_ref) do
    result_summary = humanize_result(outcome)
    new_attempt = attempt + 1

    approval_cs =
      ToolApproval.decision_changeset(
        approval, :executed, "executed", result_summary, "system", DateTime.utc_now()
      )

    proposal_cs =
      Ecto.Changeset.change(proposal, %{
        result_state: :succeeded,
        result_summary: result_summary,
        attempt: new_attempt
      })

    event_attrs = %{
      tool_proposal_id: proposal.id,
      event_type: :execution_succeeded,
      from_status: nil,
      to_status: nil,
      actor_id: "system",
      reason: nil,
      metadata: %{attempt: new_attempt}
    }

    with {:ok, _updated_approval} <- repo().update(approval_cs),
         {:ok, _updated_proposal} <- repo().update(proposal_cs),
         {:ok, _event} <-
           %ToolActionEvent{}
           |> ToolActionEvent.changeset(event_attrs)
           |> repo().insert() do
      # Telemetry AFTER the with pipeline — never inside (D-29)
      GovTelemetry.emit(:action_executed, %{count: 1, duration_ms: duration_ms}, %{
        risk_tier: proposal.risk_tier,
        approval_mode: proposal.approval_mode,
        result_state: :succeeded,
        tool_ref: tool_ref
      })

      # PubSub broadcast — after co-commit; failures are non-fatal (D16-11)
      broadcast_executed(approval.id, proposal)

      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Co-commit: transient failure path (attempt < max_attempts)
  # ---------------------------------------------------------------------------

  defp handle_transient_failure(approval, proposal, reason, attempt, max_attempts, tool_ref) do
    humanized = humanize_reason(reason)
    new_attempt = attempt + 1

    if attempt >= max_attempts do
      # Exhausted — record terminal failure
      proposal_cs = Ecto.Changeset.change(proposal, %{result_state: :failed, attempt: new_attempt})

      event_attrs = %{
        tool_proposal_id: proposal.id,
        event_type: :execution_failed,
        from_status: nil,
        to_status: nil,
        actor_id: "system",
        reason: humanized,
        metadata: %{attempt: new_attempt}
      }

      approval_cs =
        ToolApproval.decision_changeset(
          approval, :execution_failed, "execution_failed", humanized, "system", DateTime.utc_now()
        )

      with {:ok, _} <- repo().update(approval_cs),
           {:ok, _} <- repo().update(proposal_cs),
           {:ok, _} <-
             %ToolActionEvent{}
             |> ToolActionEvent.changeset(event_attrs)
             |> repo().insert() do
        GovTelemetry.emit(:action_failed, %{count: 1}, %{
          risk_tier: proposal.risk_tier,
          approval_mode: proposal.approval_mode,
          result_state: :failed,
          tool_ref: tool_ref
        })
      end

      {:cancel, humanized}
    else
      # Transient — record attempt_failed event + increment attempt, return {:error, _} for Oban retry
      proposal_cs = Ecto.Changeset.change(proposal, %{attempt: new_attempt})

      event_attrs = %{
        tool_proposal_id: proposal.id,
        event_type: :execution_attempt_failed,
        from_status: nil,
        to_status: nil,
        actor_id: "system",
        reason: humanized,
        metadata: %{attempt: new_attempt}
      }

      with {:ok, _} <- repo().update(proposal_cs),
           {:ok, _} <-
             %ToolActionEvent{}
             |> ToolActionEvent.changeset(event_attrs)
             |> repo().insert() do
        :ok
      end

      {:error, humanized}
    end
  end

  # ---------------------------------------------------------------------------
  # Co-commit: terminal failure (re-validation fail or permanent error)
  # ---------------------------------------------------------------------------

  defp record_terminal_failure(approval, proposal, new_status, humanized) do
    approval_cs =
      ToolApproval.decision_changeset(
        approval, new_status, Atom.to_string(new_status), humanized, "system", DateTime.utc_now()
      )

    event_type = if new_status == :invalidated, do: :revalidation_failed, else: :execution_failed

    event_attrs = %{
      tool_proposal_id: proposal.id,
      event_type: event_type,
      from_status: nil,
      to_status: nil,
      actor_id: "system",
      reason: humanized,
      metadata: %{}
    }

    with {:ok, _} <- repo().update(approval_cs),
         {:ok, _} <-
           %ToolActionEvent{}
           |> ToolActionEvent.changeset(event_attrs)
           |> repo().insert() do
      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Context reconstruction from proposal snapshots (Pitfall 3: never empty context)
  # NOTE: mirrors ApprovalResumeWorker.rebuild_context_from_snapshot/1
  # ---------------------------------------------------------------------------

  defp rebuild_context_from_snapshot(proposal) do
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

    tool_params =
      case proposal.input_snapshot do
        params when is_map(params) -> params
        _ -> %{}
      end

    %{scopes: scopes, tool_params: tool_params}
  end

  # ---------------------------------------------------------------------------
  # Humanize result for result_summary (never raw terms to operators)
  # ---------------------------------------------------------------------------

  defp humanize_result(outcome) do
    case outcome do
      %{message_id: id} when not is_nil(id) -> "Note written (id: #{id})."
      %{idempotent: true} -> "Note already written (idempotent replay)."
      map when is_map(map) ->
        map
        |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
        |> Enum.join(", ")
        |> case do
          "" -> "Completed."
          str -> str
        end
      _ -> "Completed."
    end
  end

  # ---------------------------------------------------------------------------
  # derive_run_key/1 — D16-05 layer 3: per-attempt deterministic idempotency key.
  #
  # Composes the proposal's own idempotency key (P13 D-25) with the current attempt
  # number, then SHA-256 hashes the composite to produce a fixed-length lowercase hex
  # string. Properties:
  #   - Deterministic: same (proposal.idempotency_key, proposal.attempt) → same key.
  #   - Attempt-scoped: a different attempt number produces a different key, so a
  #     prior failed attempt's existence record does not block the retry.
  #   - Fixed cardinality: 64-char hex — safe to index and store.
  # ---------------------------------------------------------------------------

  defp derive_run_key(proposal) do
    raw = "#{proposal.idempotency_key}::attempt::#{proposal.attempt}"
    :crypto.hash(:sha256, raw) |> Base.encode16(case: :lower)
  end

  # ---------------------------------------------------------------------------
  # humanize_reason/1 — WR-01 / D15-15: never inspect/1 on operator-visible reasons.
  # NOTE: mirrors ApprovalResumeWorker.humanize_reason/1
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # PubSub broadcast — non-fatal; failures must not block the co-commit result
  # ---------------------------------------------------------------------------

  defp broadcast_executed(approval_id, proposal) do
    topic = "conversation:#{proposal.conversation_id}"

    try do
      Phoenix.PubSub.broadcast(Cairnloop.PubSub, topic, {:tool_executed, approval_id})
    rescue
      _ -> :ok
    end
  end
end
