defmodule Cairnloop.ToolRegistry do
  @moduledoc """
  Manages the global registration and dynamic filtering of host-injected tools.
  """

  @doc """
  Retrieves a list of available tools, filtering the global configuration based
  on the `can_execute?/2` callback of each tool.
  """
  @spec get_available_tools(Cairnloop.Tool.actor_id(), Cairnloop.Tool.context()) :: [module()]
  def get_available_tools(actor_id, context) do
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []

    Enum.filter(configured_tools, fn tool_module ->
      tool_module.can_execute?(actor_id, context)
    end)
  end
end
