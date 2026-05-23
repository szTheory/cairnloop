defmodule Cairnloop.ToolRegistryTest do
  use ExUnit.Case, async: false

  # A tool with no scope requirements and an explicit :ok authorize — visible in all contexts.
  defmodule AllowTool do
    use Cairnloop.Tool, risk_tier: :read_only, title: "Allow Tool"

    embedded_schema do
    end

    @impl Cairnloop.Tool
    def changeset(tool, attrs) do
      import Ecto.Changeset
      cast(tool, attrs, [])
    end

    @impl Cairnloop.Tool
    def run(_tool, _actor_id, _context), do: {:ok, "allowed"}

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok
  end

  # A tool that denies by keeping the default authorize/2 (no_policy_defined).
  defmodule DenyTool do
    use Cairnloop.Tool, risk_tier: :read_only, title: "Deny Tool"

    embedded_schema do
    end

    @impl Cairnloop.Tool
    def changeset(tool, attrs) do
      import Ecto.Changeset
      cast(tool, attrs, [])
    end

    @impl Cairnloop.Tool
    def run(_tool, _actor_id, _context), do: {:ok, "denied"}

    @impl Cairnloop.Tool
    def scope, do: []

    # authorize/2 NOT overridden — defaults to {:error, :no_policy_defined}
  end

  setup do
    original_tools = Application.get_env(:cairnloop, :tools, [])
    Application.put_env(:cairnloop, :tools, [AllowTool, DenyTool])

    on_exit(fn ->
      Application.put_env(:cairnloop, :tools, original_tools)
    end)

    :ok
  end

  describe "get_available_tools/2" do
    test "filters tools based on scope/0 and authorize/2 (advisory UX filter)" do
      tools = Cairnloop.ToolRegistry.get_available_tools("actor1", %{})

      assert AllowTool in tools
      refute DenyTool in tools
    end

    test "returns empty list if no tools are configured" do
      Application.put_env(:cairnloop, :tools, nil)
      assert Cairnloop.ToolRegistry.get_available_tools("actor1", %{}) == []
    end
  end

  describe "find_tool_module/1" do
    test "resolves a string tool_ref to a module without String.to_existing_atom/1" do
      ref = Atom.to_string(AllowTool)
      assert {:ok, AllowTool} = Cairnloop.ToolRegistry.find_tool_module(ref)
    end

    test "returns {:error, :unknown_tool} for an unregistered tool ref" do
      assert {:error, :unknown_tool} =
               Cairnloop.ToolRegistry.find_tool_module("Elixir.NonExistentTool")
    end
  end

  describe "validate_configured_tools!/0" do
    test "passes when all tools implement the governed-tool contract" do
      # AllowTool and DenyTool are both valid governed tools
      assert :ok == Cairnloop.ToolRegistry.validate_configured_tools!()
    end
  end
end
