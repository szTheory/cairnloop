defmodule Cairnloop.ToolRegistryTest do
  use ExUnit.Case, async: false

  defmodule AllowTool do
    use Cairnloop.Tool

    embedded_schema do
    end

    def changeset(tool, attrs) do
      import Ecto.Changeset
      cast(tool, attrs, [])
    end

    def can_execute?(_actor_id, _context), do: true

    def execute(_tool, _actor_id, _context) do
      {:ok, "allowed"}
    end
  end

  defmodule DenyTool do
    use Cairnloop.Tool

    embedded_schema do
    end

    def changeset(tool, attrs) do
      import Ecto.Changeset
      cast(tool, attrs, [])
    end

    def can_execute?(_actor_id, _context), do: false

    def execute(_tool, _actor_id, _context) do
      {:ok, "denied"}
    end
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
    test "filters tools based on can_execute?/2" do
      tools = Cairnloop.ToolRegistry.get_available_tools("actor1", %{})
      
      assert AllowTool in tools
      refute DenyTool in tools
    end

    test "returns empty list if no tools are configured" do
      Application.put_env(:cairnloop, :tools, nil)
      assert Cairnloop.ToolRegistry.get_available_tools("actor1", %{}) == []
    end
  end
end
