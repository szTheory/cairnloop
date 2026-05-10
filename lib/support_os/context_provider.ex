defmodule SupportOS.ContextProvider do
  @moduledoc """
  Behaviour for providing host application context to Cairnloop.
  """
  
  @doc """
  Returns a map of context details for a given user or host_user_id.
  For example, could include lifetime value, plan type, recent activity.
  """
  @callback get_context(host_user_id :: String.t()) :: map()
end
