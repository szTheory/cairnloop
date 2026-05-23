defmodule Cairnloop.Governance do
  @moduledoc """
  Public facade for the governed-tool proposal system (D-30).

  ## Public API

  - `validate/3` — pure, re-callable, ordered `with` pipeline returning a fail-closed
    outcome for every governance gate (TOOL-03, D-15, D-17).
  - `propose/3` — thin persistence wrapper: validates, derives idempotency key,
    co-commits `ToolProposal` + `ToolActionEvent` synchronously, handles duplicates
    (TOOL-04, D-26, D-25).
  - `get_proposal/1` — read helper.
  - `list_events/1` — read helper.

  ## Validation Pipeline (validate/3)

  Clause order IS the precedence (D-17). Never reorder:

      gate 0 (resolve_tool)   → {:blocked, :unsupported, :unknown_tool}  — pre-persistence
      gate 1 (validate_input) → {:blocked, :needs_input, changeset}
      gate 2 (check_scope)    → {:blocked, :scope_invalid, reason}
      gate 3 (authorize)      → {:blocked, :policy_denied, reason}
      success                 → {:ok, validated_attrs}

  ## Persistence (propose/3)

  - Unknown tool (`:unsupported`): telemetry only, NO row inserted (D-18, Pitfall 7).
  - Known tool blocked by scope/policy: proposal persisted with blocked status + reason,
    plus a `:proposal_blocked` event (D-18 Support-Truth Gate).
  - Happy path: proposal + `:proposal_created` event co-committed in one `with` (D-26).
  - Duplicate idempotency key: returns existing proposal, no second insert (D-25).

  ## No Execution

  `propose/3` never calls `run/3`. No Oban job is enqueued in Phase 13 (D-26). Execution
  lands in Phase 16; approval state machine lands in Phase 15.
  """

  import Ecto.Query

  alias Cairnloop.Governance.{Policy, Telemetry, ToolActionEvent, ToolProposal}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  # Gate 0: resolve tool_ref to a module via Atom.to_string comparison.
  # NEVER String.to_existing_atom/1 — D-19, T-13-05.
  defp resolve_tool(tool_ref) when is_binary(tool_ref) do
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []

    case Enum.find(configured_tools, fn mod -> Atom.to_string(mod) == tool_ref end) do
      nil -> {:error, :unknown_tool}
      mod -> {:ok, mod}
    end
  end

  # Gate 1: validate typed input through the tool's changeset/2 callback (D-04).
  defp validate_input(tool_module, context) do
    params = Map.get(context, :tool_params, %{})
    struct = struct(tool_module)
    changeset = tool_module.changeset(struct, params)

    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, :invalid_input, changeset}
    end
  end

  # Gate 2: static scope check (D-16).
  defp check_scope(tool_module, _actor_id, context) do
    required = tool_module.scope()
    granted = Map.get(context, :scopes, [])

    if Enum.all?(required, &(&1 in granted)) do
      :ok
    else
      missing = Enum.reject(required, &(&1 in granted))
      {:error, :scope_mismatch, {:missing_scopes, missing}}
    end
  end

  # Build validated_attrs with propose-time snapshots (D-14, D-24).
  defp build_validated_attrs(tool_module, input_struct, actor_id, context) do
    spec = tool_module.__tool_spec__()
    approval_mode = Policy.resolve(tool_module, actor_id, context)

    %{
      risk_tier: spec.risk_tier,
      approval_mode: approval_mode,
      tool_version: nil,
      input_snapshot: Map.from_struct(input_struct),
      scope_snapshot: %{scopes: Map.get(context, :scopes, [])},
      policy_snapshot: %{
        resolution_source: :phase_13_policy_resolve,
        declared_approval_mode: spec.approval_mode,
        resolved_approval_mode: approval_mode
      }
    }
  end

  # Derive a deterministic idempotency key (D-25, Stripe-style).
  # sha256(canonical_json(%{tool_ref, actor_id, account_id, input, dedupe_token}))
  defp derive_idempotency_key(tool_ref, actor_id, context, input_snapshot) do
    account_id = Map.get(context, :account_id)
    dedupe_token = Map.get(context, :idempotency_token)

    canonical =
      %{
        tool_ref: tool_ref,
        actor_id: actor_id,
        account_id: account_id,
        input: input_snapshot |> Map.to_list() |> Enum.sort() |> Map.new(),
        dedupe_token: dedupe_token
      }
      |> Jason.encode!()

    :crypto.hash(:sha256, canonical) |> Base.encode16(case: :lower)
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Pure, re-callable validation pipeline. No DB interaction, no side effects (D-15).

  Returns one of:
  - `{:ok, validated_attrs}` — all gates pass; attrs include resolved risk_tier,
    approval_mode, and three snapshot maps.
  - `{:blocked, :unsupported, :unknown_tool}` — tool_ref not in registry.
  - `{:blocked, :needs_input, changeset}` — typed input invalid.
  - `{:blocked, :scope_invalid, reason}` — actor scope unmet.
  - `{:blocked, :policy_denied, reason}` — authorize/2 denied.

  Clause ORDER is the precedence (D-17). Never reorder.
  """
  def validate(tool_ref, actor_id, context) do
    with {:ok, tool_module} <- resolve_tool(tool_ref),
         {:ok, input} <- validate_input(tool_module, context),
         :ok <- check_scope(tool_module, actor_id, context),
         :ok <- tool_module.authorize(actor_id, context) do
      {:ok, build_validated_attrs(tool_module, input, actor_id, context)}
    else
      {:error, :unknown_tool} -> {:blocked, :unsupported, :unknown_tool}
      {:error, :invalid_input, cs} -> {:blocked, :needs_input, cs}
      {:error, :scope_mismatch, r} -> {:blocked, :scope_invalid, r}
      {:error, reason} -> {:blocked, :policy_denied, reason}
    end
  end

  @doc """
  Synchronously propose a governed tool call, persisting proposal + event (D-26).

  Calls `validate/3` then:
  - `{:blocked, :unsupported, _}`: telemetry only — NO row inserted (D-18, Pitfall 7).
  - `{:blocked, outcome, reason}` for a resolved tool: persists proposal with blocked
    status + a `:proposal_blocked` event (D-18 Support-Truth Gate).
  - `{:ok, validated}`: derives idempotency key, co-commits proposal + `:proposal_created`
    event; on duplicate unique constraint, returns the existing proposal (D-25).

  Does NOT call `run/3`. Does NOT enqueue Oban (D-26).
  """
  def propose(tool_ref, actor_id, context) do
    case validate(tool_ref, actor_id, context) do
      {:ok, validated} ->
        propose_valid(tool_ref, actor_id, context, validated)

      {:blocked, :unsupported, reason} = blocked ->
        # Pre-persistence reject — NO row, telemetry only (D-18, Pitfall 7)
        Telemetry.emit(:proposal_blocked, %{count: 1}, %{outcome: :unsupported})
        blocked

      {:blocked, outcome, reason} = blocked ->
        # Registered tool blocked — persist with status=outcome (D-18 Support-Truth Gate)
        propose_blocked(tool_ref, actor_id, context, outcome, reason)
        blocked
    end
  end

  defp propose_valid(tool_ref, actor_id, context, validated) do
    idempotency_key = derive_idempotency_key(tool_ref, actor_id, context, validated.input_snapshot)
    account_id = Map.get(context, :account_id)

    # Check for existing proposal first — avoids the on_conflict footgun (Pitfall 6, D-25).
    # In a real Repo this is a SELECT before INSERT; a race condition is still handled by
    # the unique_constraint error path below (defense-in-depth).
    case repo().get_by(ToolProposal, idempotency_key: idempotency_key) do
      %ToolProposal{} = existing ->
        Telemetry.emit(:proposal_duplicate, %{count: 1}, %{outcome: :duplicate})
        {:ok, existing}

      nil ->
        insert_new_proposal(tool_ref, account_id, idempotency_key, actor_id, validated)
    end
  end

  defp insert_new_proposal(tool_ref, account_id, idempotency_key, actor_id, validated) do
    proposal_attrs = %{
      tool_ref: tool_ref,
      tool_version: validated.tool_version,
      idempotency_key: idempotency_key,
      status: :proposed,
      risk_tier: validated.risk_tier,
      approval_mode: validated.approval_mode,
      actor_id: actor_id,
      account_id: account_id,
      input_snapshot: validated.input_snapshot,
      scope_snapshot: validated.scope_snapshot,
      policy_snapshot: validated.policy_snapshot
    }

    with {:ok, proposal} <-
           %ToolProposal{}
           |> ToolProposal.changeset(proposal_attrs)
           |> repo().insert(),
         {:ok, _event} <-
           %ToolActionEvent{}
           |> ToolActionEvent.changeset(%{
             tool_proposal_id: proposal.id,
             event_type: :proposal_created,
             from_status: nil,
             to_status: :proposed,
             actor_id: actor_id,
             metadata: %{}
           })
           |> repo().insert() do
      # Telemetry AFTER with success — never inside the with clause list (D-29)
      Telemetry.emit(:proposal_created, %{count: 1}, %{
        outcome: :proposed,
        risk_tier: validated.risk_tier,
        approval_mode: validated.approval_mode
      })

      {:ok, proposal}
    else
      {:error, %Ecto.Changeset{} = cs} ->
        # Handle unique constraint violation (race condition defense-in-depth)
        if unique_constraint_error?(cs, :idempotency_key) do
          existing = repo().get_by(ToolProposal, idempotency_key: idempotency_key)
          Telemetry.emit(:proposal_duplicate, %{count: 1}, %{outcome: :duplicate})
          {:ok, existing}
        else
          {:error, cs}
        end
    end
  end

  defp propose_blocked(tool_ref, actor_id, context, outcome, reason) do
    account_id = Map.get(context, :account_id)

    # Derive a key even for blocked proposals so idempotency works for blocked outcomes
    input_snapshot = Map.get(context, :tool_params, %{})
    idempotency_key = derive_idempotency_key(tool_ref, actor_id, context, input_snapshot)

    # Resolve risk_tier from the tool module for snapshot (gate 0 passed so module exists)
    tool_module =
      (Application.get_env(:cairnloop, :tools, []) || [])
      |> Enum.find(fn mod -> Atom.to_string(mod) == tool_ref end)

    {risk_tier, approval_mode} =
      if tool_module do
        spec = tool_module.__tool_spec__()
        mode = Policy.resolve(tool_module, actor_id, context)
        {spec.risk_tier, mode}
      else
        {:unknown, :always_block}
      end

    reason_str = inspect(reason)

    proposal_attrs = %{
      tool_ref: tool_ref,
      idempotency_key: idempotency_key,
      status: outcome,
      risk_tier: risk_tier,
      approval_mode: approval_mode,
      actor_id: actor_id,
      account_id: account_id,
      input_snapshot: input_snapshot,
      scope_snapshot: %{scopes: Map.get(context, :scopes, [])},
      policy_snapshot: %{outcome: outcome, reason: reason_str}
    }

    with {:ok, proposal} <-
           %ToolProposal{}
           |> ToolProposal.blocked_changeset(proposal_attrs)
           |> repo().insert(),
         {:ok, _event} <-
           %ToolActionEvent{}
           |> ToolActionEvent.changeset(%{
             tool_proposal_id: proposal.id,
             event_type: :proposal_blocked,
             from_status: nil,
             to_status: outcome,
             actor_id: actor_id,
             reason: reason_str,
             metadata: %{}
           })
           |> repo().insert() do
      # Telemetry AFTER with success (D-29)
      Telemetry.emit(:proposal_blocked, %{count: 1}, %{
        outcome: outcome,
        risk_tier: risk_tier,
        approval_mode: approval_mode
      })

      :ok
    end
  end

  defp unique_constraint_error?(changeset, field) do
    Enum.any?(changeset.errors, fn
      {^field, {_msg, opts}} when is_list(opts) ->
        Keyword.get(opts, :constraint) == :unique
      _ ->
        false
    end)
  end

  @doc """
  Returns a `ToolProposal` by id, or nil if not found.
  """
  def get_proposal(id) do
    repo().get(ToolProposal, id)
  end

  @doc """
  Returns all `ToolActionEvent` records for a given proposal id, ordered by inserted_at.
  """
  def list_events(proposal_id) do
    ToolActionEvent
    |> where([e], e.tool_proposal_id == ^proposal_id)
    |> order_by([e], asc: e.inserted_at)
    |> repo().all()
  end
end
