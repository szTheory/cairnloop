defmodule Cairnloop.ToolTest do
  use ExUnit.Case, async: true

  defmodule DummyTool do
    use Cairnloop.Tool

    embedded_schema do
      field(:amount, :integer)
      field(:reason, :string)
    end

    def changeset(tool, attrs) do
      import Ecto.Changeset

      tool
      |> cast(attrs, [:amount, :reason])
      |> validate_required([:amount])
    end

    def can_execute?(_actor_id, _context), do: true

    def execute(tool, _actor_id, _context) do
      {:ok, "Executed with amount #{tool.amount}"}
    end
  end

  describe "Cairnloop.Tool" do
    test "defines an Ecto schema" do
      assert %DummyTool{} = struct(DummyTool)
      assert :amount in DummyTool.__schema__(:fields)
    end

    test "requires changeset, can_execute? and execute implementations" do
      # If it compiles and we can call these, the behaviour is satisfied.
      assert DummyTool.can_execute?("actor1", %{}) == true

      changeset = DummyTool.changeset(%DummyTool{}, %{"amount" => 100})
      assert changeset.valid?

      tool = Ecto.Changeset.apply_changes(changeset)
      assert DummyTool.execute(tool, "actor1", %{}) == {:ok, "Executed with amount 100"}
    end

    test "has default custom_ui/0 returning nil" do
      assert DummyTool.custom_ui() == nil
    end
  end
end
