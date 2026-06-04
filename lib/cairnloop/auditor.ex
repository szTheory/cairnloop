defmodule Cairnloop.Auditor do
  @moduledoc """
  Behaviour for providing host application auditing to Cairnloop.

  Cairnloop uses this behaviour to achieve compliance-grade, durable auditing.
  Host applications implement this behaviour to insert their own Ecto.Multi operations
  to log evidence within the same database transaction.
  """

  @doc """
  Injects an audit log operation into an existing Ecto.Multi pipeline.
  """
  @callback audit(
              multi :: Ecto.Multi.t(),
              action :: atom(),
              actor :: map() | String.t() | nil,
              metadata :: map()
            ) :: Ecto.Multi.t()

  @doc """
  Retrieves a list of audit events.
  """
  @callback list_events(opts :: keyword()) :: [map()]
end

defmodule Cairnloop.Auditor.NoOp do
  @moduledoc """
  A default, no-op implementation of the `Cairnloop.Auditor` behaviour.
  """
  @behaviour Cairnloop.Auditor

  @impl true
  def audit(multi, _action, _actor, _metadata) do
    multi
  end

  @impl true
  def list_events(_opts), do: []
end

defmodule Cairnloop.Auditor.Governance do
  @moduledoc """
  Default `Cairnloop.Auditor` implementation backed by the governance audit trail.

  `list_events/1` surfaces the durable `Cairnloop.Governance.ToolActionEvent` rows that
  the governed-action pipeline writes (every proposal/approval/execution transition),
  read through the narrow `Cairnloop.Governance` facade (D-30). This makes the operator
  Audit Log non-empty out of the box without the host having to wire its own auditor.

  Events are normalized to the plain-map shape the audit surface expects:
  `%{inserted_at:, actor_id:, action:, reason:, metadata:}`. `action` carries the
  `ToolActionEvent.event_type` atom; `Cairnloop.Web.AuditLogPresenter` humanizes it.

  `audit/4` is a pass-through: governance co-commits its own `ToolActionEvent` rows, so
  this auditor never needs to inject additional multi operations. Hosts that want their
  own durable audit log alongside governance can configure a custom `:auditor` instead.
  """
  @behaviour Cairnloop.Auditor

  alias Cairnloop.Governance

  @impl true
  def audit(multi, _action, _actor, _metadata), do: multi

  @impl true
  def list_events(opts) do
    opts
    |> Governance.list_action_events()
    |> Enum.map(fn event ->
      proposal = event.tool_proposal

      %{
        inserted_at: event.inserted_at,
        actor_id: event.actor_id,
        action: event.event_type,
        reason: event.reason,
        metadata: event.metadata || %{},
        # Navigational subject refs — structural FK, not a trust fact (D-02, D-09).
        # :tool_proposal is already preloaded by list_action_events/1 (governance.ex).
        # Guard nil proposal so conversation_id resolves to nil (fail-closed, D-08).
        conversation_id: if(proposal, do: proposal.conversation_id),
        proposal_id: event.tool_proposal_id
      }
    end)
  end
end
