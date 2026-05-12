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
end