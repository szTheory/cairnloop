defmodule Cairnloop.ToolTest do
  use ExUnit.Case, async: false

  # ---------------------------------------------------------------------------
  # Minimal valid tool used across multiple tests.
  # Declared at module level so it is compiled once and reused.
  # ---------------------------------------------------------------------------
  defmodule MinimalTool do
    use Cairnloop.Tool,
      risk_tier: :read_only,
      title: "Test Tool",
      description: "A minimal tool for contract testing."

    embedded_schema do
      field(:query, :string)
    end

    @impl Cairnloop.Tool
    def changeset(tool, attrs) do
      tool
      |> cast(attrs, [:query])
      |> validate_required([:query])
    end

    @impl Cairnloop.Tool
    def run(_tool, _actor_id, _context), do: {:ok, nil}

    @impl Cairnloop.Tool
    def scope, do: []
  end

  # A tool that overrides authorize/2 to permit.
  defmodule PermittedTool do
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "Permitted Tool",
      description: "A tool with an explicit authorize/2 override."

    embedded_schema do
    end

    @impl Cairnloop.Tool
    def changeset(tool, attrs), do: cast(tool, attrs, [])

    @impl Cairnloop.Tool
    def run(_tool, _actor_id, _context), do: {:ok, nil}

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok
  end

  # ---------------------------------------------------------------------------
  # D-02: Compile-time enum validation — invalid values raise CompileError
  # ---------------------------------------------------------------------------
  describe "D-02: compile-time enum validation" do
    test "raises CompileError for invalid risk_tier at compile time" do
      assert_raise CompileError, ~r/invalid risk_tier/, fn ->
        Code.compile_string("""
        defmodule BadRiskTierTool do
          use Cairnloop.Tool, risk_tier: :explodes
          def changeset(s, a), do: s
          def run(s, _i, _c), do: {:ok, nil}
          def scope, do: []
        end
        """)
      end
    end

    test "raises CompileError for invalid approval_mode at compile time" do
      assert_raise CompileError, ~r/invalid approval_mode/, fn ->
        Code.compile_string("""
        defmodule BadApprovalModeTool do
          use Cairnloop.Tool, risk_tier: :read_only, approval_mode: :nope
          def changeset(s, a), do: s
          def run(s, _i, _c), do: {:ok, nil}
          def scope, do: []
        end
        """)
      end
    end

    test "valid risk_tier and approval_mode compile without error" do
      # If this compiles, the macro accepted the valid values.
      assert Code.compile_string("""
             defmodule ValidTierModeTool do
               use Cairnloop.Tool,
                 risk_tier: :low_write,
                 approval_mode: :requires_approval,
                 title: "Valid"
               def changeset(s, a), do: s
               def run(s, _i, _c), do: {:ok, nil}
               def scope, do: []
             end
             """)
    end
  end

  # ---------------------------------------------------------------------------
  # D-03: Frozen %Cairnloop.Tool.Spec{} returned by __tool_spec__/0
  # ---------------------------------------------------------------------------
  describe "D-03: frozen Spec returned by __tool_spec__/0" do
    test "returns a %Cairnloop.Tool.Spec{} struct" do
      spec = MinimalTool.__tool_spec__()
      assert is_struct(spec, Cairnloop.Tool.Spec)
    end

    test "spec carries declared risk_tier and title" do
      spec = MinimalTool.__tool_spec__()
      assert spec.risk_tier == :read_only
      assert spec.title == "Test Tool"
      assert spec.description == "A minimal tool for contract testing."
    end

    test "spec is pure data — not an Ecto schema" do
      refute function_exported?(Cairnloop.Tool.Spec, :__schema__, 1)
    end

    test "spec has all six required fields" do
      spec = MinimalTool.__tool_spec__()
      # Access all six fields without error
      _ = spec.risk_tier
      _ = spec.approval_mode
      _ = spec.idempotency
      _ = spec.result_states
      _ = spec.title
      _ = spec.description
      assert true
    end
  end

  # ---------------------------------------------------------------------------
  # D-16: Deny-by-default authorize/2
  # ---------------------------------------------------------------------------
  describe "D-16: deny-by-default authorize/2" do
    test "default authorize/2 returns {:error, :no_policy_defined}" do
      assert MinimalTool.authorize("actor_1", %{}) == {:error, :no_policy_defined}
    end

    test "a tool that overrides authorize/2 can return :ok" do
      assert PermittedTool.authorize("actor_1", %{}) == :ok
    end

    test "custom_ui/0 default returns nil" do
      assert MinimalTool.custom_ui() == nil
    end
  end

  # ---------------------------------------------------------------------------
  # D-11: Fail-closed tier -> approval_mode derivation
  # ---------------------------------------------------------------------------
  describe "D-11: fail-closed tier->mode derivation" do
    test "read_only derives :auto" do
      assert Cairnloop.Tool.derive_approval_mode(:read_only) == :auto
    end

    test "low_write derives :requires_approval" do
      assert Cairnloop.Tool.derive_approval_mode(:low_write) == :requires_approval
    end

    test "high_write derives :requires_approval" do
      assert Cairnloop.Tool.derive_approval_mode(:high_write) == :requires_approval
    end

    test "destructive derives :always_block" do
      assert Cairnloop.Tool.derive_approval_mode(:destructive) == :always_block
    end

    test "unknown tier derives :always_block (fail-closed)" do
      assert Cairnloop.Tool.derive_approval_mode(:unknown_tier) == :always_block
    end

    test "nil tier derives :always_block (fail-closed)" do
      assert Cairnloop.Tool.derive_approval_mode(nil) == :always_block
    end

    test "tool declared risk_tier: :read_only gets approval_mode: :auto on spec" do
      spec = MinimalTool.__tool_spec__()
      assert spec.approval_mode == :auto
    end

    test "tool declared risk_tier: :low_write gets approval_mode: :requires_approval on spec" do
      spec = PermittedTool.__tool_spec__()
      assert spec.risk_tier == :low_write
      assert spec.approval_mode == :requires_approval
    end

    test "tool declared risk_tier: :destructive derives :always_block on spec" do
      # Compile a fresh tool with :destructive tier and verify the spec
      [{mod, _bin}] =
        Code.compile_string("""
        defmodule DestructiveTierTool do
          use Cairnloop.Tool, risk_tier: :destructive, title: "Destructive"
          def changeset(s, a), do: s
          def run(s, _i, _c), do: {:ok, nil}
          def scope, do: []
        end
        """)

      spec = mod.__tool_spec__()
      assert spec.risk_tier == :destructive
      assert spec.approval_mode == :always_block
    end
  end
end
