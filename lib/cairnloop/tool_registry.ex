defmodule Cairnloop.ToolRegistry do
  @moduledoc """
  Manages registration and advisory filtering of host-injected governed tools.

  Boot-time validation (`validate_configured_tools!/0`) ensures every declared tool
  implements `Cairnloop.Tool` and exposes a valid `__tool_spec__/0`. Call this from
  `Cairnloop.Application.start/2` so a misconfigured tool fails fast at boot.

  `get_available_tools/2` is an **advisory UX filter only** — it applies `scope/0`
  and `authorize/2` as a convenience to hide unavailable tools from the UI. The
  authoritative gate is `Cairnloop.Governance.validate/3` (D-28).
  """

  @doc """
  Called at application boot to validate that every tool in config implements the
  governed-tool contract and exposes a valid `__tool_spec__/0`. Raises `ArgumentError`
  if any tool fails validation (D-07).
  """
  def validate_configured_tools! do
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []

    Enum.each(configured_tools, fn tool_module ->
      # Ensure the module is loaded before checking — `function_exported?/3` returns false
      # for unloaded modules even when the beam file exists (D-07, Rule 1 fix).
      Code.ensure_loaded!(tool_module)

      unless function_exported?(tool_module, :__tool_spec__, 0) do
        raise ArgumentError,
              "Tool #{inspect(tool_module)} does not implement Cairnloop.Tool behaviour or is missing __tool_spec__/0"
      end

      spec = tool_module.__tool_spec__()

      unless is_struct(spec, Cairnloop.Tool.Spec) do
        raise ArgumentError,
              "Tool #{inspect(tool_module)}.__tool_spec__/0 must return %Cairnloop.Tool.Spec{}"
      end
    end)
  end

  @doc """
  Retrieves available tools filtered by `scope/0` and `authorize/2` — advisory UX
  only. `Cairnloop.Governance.validate/3` is the authoritative gate (D-28).
  """
  @spec get_available_tools(Cairnloop.Tool.actor_id(), Cairnloop.Tool.context()) :: [module()]
  def get_available_tools(actor_id, context) do
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []

    Enum.filter(configured_tools, fn tool_module ->
      Enum.all?(tool_module.scope(), &(&1 in Map.get(context, :scopes, []))) &&
        tool_module.authorize(actor_id, context) == :ok
    end)
  end

  @doc """
  Returns all configured tools as `{module, spec}` tuples without any scope or authorization
  filtering. Used by the optional MCP seam (D17-08) to project the full tool registry for
  `tools/list` responses.

  Unlike `get_available_tools/2` — which applies advisory scope/authorize filtering — this
  function returns every tool registered in `:cairnloop, :tools` config regardless of actor
  context. This is correct for MCP listing: the MCP client decides which tools to surface.
  """
  @spec list_all_tools() :: [{module(), Cairnloop.Tool.Spec.t()}]
  def list_all_tools do
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []
    Enum.map(configured_tools, fn mod -> {mod, mod.__tool_spec__()} end)
  end

  @doc """
  Resolves a string `tool_ref` to a module without using `String.to_existing_atom/1` (D-19).

  `inspect(MyTool)` and `Atom.to_string(MyTool)` both produce `"Elixir.MyTool"` — the
  string comparison is safe and does not create new atoms from untrusted input.
  """
  @spec find_tool_module(String.t()) :: {:ok, module()} | {:error, :unknown_tool}
  def find_tool_module(tool_ref) when is_binary(tool_ref) do
    configured_tools = Application.get_env(:cairnloop, :tools, []) || []

    case Enum.find(configured_tools, fn mod -> Atom.to_string(mod) == tool_ref end) do
      nil -> {:error, :unknown_tool}
      mod -> {:ok, mod}
    end
  end
end
