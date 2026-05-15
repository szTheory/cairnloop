defmodule Cairnloop.SLAPolicyProvider do
  @moduledoc """
  Behaviour for providing SLA policies.

  Host applications can implement this behaviour to provide custom
  SLA policy configurations dynamically, typically backed by a database.
  """

  @doc """
  Returns a list of active SLA policies.
  """
  @callback get_active_policies() :: {:ok, list(map())} | {:error, term()}

  @doc """
  Sets or creates a new SLA policy for a specific priority.
  """
  @callback set_policy(priority :: atom(), attrs :: map()) :: {:ok, map()} | {:error, term()}
end
