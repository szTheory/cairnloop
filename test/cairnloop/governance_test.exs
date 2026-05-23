defmodule Cairnloop.GovernanceTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Governance
  alias Cairnloop.Governance.ToolProposal
  alias Cairnloop.Governance.ToolActionEvent

  # ---------------------------------------------------------------------------
  # MockRepo — process-dictionary-backed repo (no real DB required)
  # ---------------------------------------------------------------------------

  defmodule MockRepo do
    def insert(%Ecto.Changeset{} = changeset) do
      if changeset.valid? do
        struct =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> maybe_put_id()
          |> Map.put_new(:inserted_at, DateTime.utc_now())
          |> put_maybe_updated_at()

        persist_inserted(struct)
        Process.put(:last_inserted, struct)
        {:ok, struct}
      else
        {:error, changeset}
      end
    end

    def get_by(schema, clauses) do
      case schema do
        ToolProposal ->
          key = Keyword.get(clauses, :idempotency_key)

          Process.get(:tool_proposals, [])
          |> Enum.find(fn p -> p.idempotency_key == key end)

        _ ->
          nil
      end
    end

    defp maybe_put_id(%{id: nil} = struct), do: %{struct | id: System.unique_integer([:positive])}
    defp maybe_put_id(struct), do: struct

    defp put_maybe_updated_at(%ToolActionEvent{} = event), do: event
    defp put_maybe_updated_at(struct), do: Map.put_new(struct, :updated_at, DateTime.utc_now())

    defp persist_inserted(%ToolProposal{} = proposal) do
      Process.put(:tool_proposals, [proposal | Process.get(:tool_proposals, [])])
    end

    defp persist_inserted(%ToolActionEvent{} = event) do
      Process.put(:tool_action_events, [event | Process.get(:tool_action_events, [])])
    end

    defp persist_inserted(_struct), do: :ok
  end

  # ---------------------------------------------------------------------------
  # Test tool modules
  # ---------------------------------------------------------------------------

  defmodule ValidTool do
    use Cairnloop.Tool,
      risk_tier: :read_only,
      title: "Lookup Order",
      description: "Retrieve an order."

    embedded_schema do
      field(:order_id, :string)
    end

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [:order_id])
      |> Ecto.Changeset.validate_required([:order_id])
    end

    def run(_tool, _actor, _ctx), do: {:ok, %{}}
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok
  end

  defmodule ScopeFailingTool do
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "Write Tool"

    embedded_schema do
      field(:data, :string)
    end

    def changeset(struct, attrs) do
      Ecto.Changeset.cast(struct, attrs, [:data])
    end

    def run(_tool, _actor, _ctx), do: {:ok, %{}}
    def scope, do: [:admin_scope]

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok
  end

  defmodule PolicyDenyingTool do
    use Cairnloop.Tool,
      risk_tier: :high_write,
      title: "Policy Denied Tool"

    embedded_schema do
      field(:data, :string)
    end

    def changeset(struct, attrs) do
      Ecto.Changeset.cast(struct, attrs, [:data])
    end

    def run(_tool, _actor, _ctx), do: {:ok, %{}}
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: {:error, :denied}
  end

  defmodule InvalidInputTool do
    use Cairnloop.Tool,
      risk_tier: :read_only,
      title: "Input Required Tool"

    embedded_schema do
      field(:required_field, :string)
    end

    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [:required_field])
      |> Ecto.Changeset.validate_required([:required_field])
    end

    def run(_tool, _actor, _ctx), do: {:ok, %{}}
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok
  end

  # ---------------------------------------------------------------------------
  # Setup / teardown
  # ---------------------------------------------------------------------------

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)

    Application.put_env(:cairnloop, :tools, [
      ValidTool,
      ScopeFailingTool,
      PolicyDenyingTool,
      InvalidInputTool
    ])

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      Application.delete_env(:cairnloop, :tools)
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Governance.validate/3 — pure pipeline tests (Task 2)
  # ---------------------------------------------------------------------------

  describe "validate/3 — unsupported (gate 0)" do
    test "returns {:blocked, :unsupported, :unknown_tool} for unknown tool_ref" do
      result = Governance.validate("Elixir.DoesNotExist.Tool", "user_1", %{})
      assert result == {:blocked, :unsupported, :unknown_tool}
    end

    test "is a pure function — no DB interaction for unknown tool" do
      # Process dictionary is empty — no MockRepo calls should happen
      Governance.validate("Elixir.NonExistent", "user_1", %{})
      assert Process.get(:tool_proposals, []) == []
      assert Process.get(:tool_action_events, []) == []
    end
  end

  describe "validate/3 — needs_input (gate 1)" do
    test "returns {:blocked, :needs_input, changeset} when changeset invalid" do
      tool_ref = Atom.to_string(InvalidInputTool)
      context = %{tool_params: %{}}  # missing required_field

      result = Governance.validate(tool_ref, "user_1", context)
      assert {:blocked, :needs_input, cs} = result
      refute cs.valid?
    end

    test "needs_input is pure — no DB interaction" do
      tool_ref = Atom.to_string(InvalidInputTool)
      context = %{tool_params: %{}}

      Governance.validate(tool_ref, "user_1", context)
      assert Process.get(:tool_proposals, []) == []
    end
  end

  describe "validate/3 — scope_invalid (gate 2)" do
    test "returns {:blocked, :scope_invalid, _} when scope unmet" do
      tool_ref = Atom.to_string(ScopeFailingTool)
      context = %{tool_params: %{data: "x"}, scopes: []}

      result = Governance.validate(tool_ref, "user_1", context)
      assert {:blocked, :scope_invalid, _reason} = result
    end

    test "scope checked before policy (D-17 precedence)" do
      tool_ref = Atom.to_string(ScopeFailingTool)
      # ScopeFailingTool requires :admin_scope but it's absent
      # Even though authorize returns :ok, scope gate fires first
      context = %{tool_params: %{data: "x"}, scopes: []}

      result = Governance.validate(tool_ref, "user_1", context)
      assert {:blocked, :scope_invalid, _} = result
    end
  end

  describe "validate/3 — policy_denied (gate 3)" do
    test "returns {:blocked, :policy_denied, :denied} when authorize denies" do
      tool_ref = Atom.to_string(PolicyDenyingTool)
      context = %{tool_params: %{data: "x"}, scopes: []}

      result = Governance.validate(tool_ref, "user_1", context)
      assert {:blocked, :policy_denied, :denied} = result
    end
  end

  describe "validate/3 — success" do
    test "returns {:ok, validated_attrs} when all gates pass" do
      tool_ref = Atom.to_string(ValidTool)
      context = %{tool_params: %{order_id: "123"}, scopes: []}

      result = Governance.validate(tool_ref, "user_1", context)
      assert {:ok, attrs} = result
      assert attrs.risk_tier == :read_only
      assert attrs.approval_mode == :auto
      assert is_map(attrs.input_snapshot)
      assert is_map(attrs.scope_snapshot)
      assert is_map(attrs.policy_snapshot)
    end
  end

  describe "validate/3 — D-17 precedence" do
    test "unsupported wins over all other gates when tool is unknown" do
      result = Governance.validate("Elixir.DoesNotExist", "user_1", %{tool_params: %{}})
      assert {:blocked, :unsupported, :unknown_tool} = result
    end
  end

  # ---------------------------------------------------------------------------
  # Governance.propose/3 — persistence tests (Task 3)
  # ---------------------------------------------------------------------------

  describe "propose/3 — happy path" do
    test "returns {:ok, proposal} when all gates pass" do
      tool_ref = Atom.to_string(ValidTool)
      context = %{tool_params: %{order_id: "order_abc"}, scopes: []}

      assert {:ok, proposal} = Governance.propose(tool_ref, "user_1", context)
      assert proposal.status == :proposed
      assert proposal.tool_ref == tool_ref
    end

    test "co-commits proposal AND a :proposal_created ToolActionEvent" do
      tool_ref = Atom.to_string(ValidTool)
      context = %{tool_params: %{order_id: "order_co_commit"}, scopes: []}

      assert {:ok, _proposal} = Governance.propose(tool_ref, "user_1", context)

      proposals = Process.get(:tool_proposals, [])
      events = Process.get(:tool_action_events, [])

      assert length(proposals) == 1
      assert length(events) == 1

      [event] = events
      assert event.event_type == :proposal_created
      assert event.to_status == :proposed
      assert event.from_status == nil
    end

    test "co-commit event has matching tool_proposal_id" do
      tool_ref = Atom.to_string(ValidTool)
      context = %{tool_params: %{order_id: "order_link"}, scopes: []}

      assert {:ok, proposal} = Governance.propose(tool_ref, "user_1", context)

      [event] = Process.get(:tool_action_events, [])
      assert event.tool_proposal_id == proposal.id
    end
  end

  describe "propose/3 — unknown tool (no row, D-18)" do
    test "returns {:blocked, :unsupported, :unknown_tool} and inserts NO rows" do
      result = Governance.propose("Elixir.NoSuchTool", "user_1", %{})

      assert result == {:blocked, :unsupported, :unknown_tool}
      assert Process.get(:tool_proposals, []) == []
      assert Process.get(:tool_action_events, []) == []
    end
  end

  describe "propose/3 — blocked but registered tool (persisted, D-18)" do
    test "scope_invalid persists a ToolProposal with status :scope_invalid" do
      tool_ref = Atom.to_string(ScopeFailingTool)
      context = %{tool_params: %{data: "x"}, scopes: []}

      assert {:blocked, :scope_invalid, _reason} = Governance.propose(tool_ref, "user_1", context)

      proposals = Process.get(:tool_proposals, [])
      assert length(proposals) == 1
      assert hd(proposals).status == :scope_invalid
    end

    test "scope_invalid also persists a :proposal_blocked ToolActionEvent" do
      tool_ref = Atom.to_string(ScopeFailingTool)
      context = %{tool_params: %{data: "x"}, scopes: []}

      Governance.propose(tool_ref, "user_1", context)

      events = Process.get(:tool_action_events, [])
      assert length(events) == 1
      assert hd(events).event_type == :proposal_blocked
      assert hd(events).to_status == :scope_invalid
    end

    test "policy_denied persists a ToolProposal with status :policy_denied" do
      tool_ref = Atom.to_string(PolicyDenyingTool)
      context = %{tool_params: %{data: "x"}, scopes: []}

      assert {:blocked, :policy_denied, _} = Governance.propose(tool_ref, "user_1", context)

      proposals = Process.get(:tool_proposals, [])
      assert length(proposals) == 1
      assert hd(proposals).status == :policy_denied
    end
  end

  describe "propose/3 — idempotency (D-25)" do
    test "identical inputs return the same proposal on duplicate propose" do
      tool_ref = Atom.to_string(ValidTool)
      context = %{
        tool_params: %{order_id: "order_idem"},
        scopes: [],
        idempotency_token: "token_abc",
        account_id: "acct_1"
      }

      assert {:ok, proposal1} = Governance.propose(tool_ref, "user_1", context)
      assert {:ok, proposal2} = Governance.propose(tool_ref, "user_1", context)

      assert proposal1.id == proposal2.id
    end

    test "differing input yields a different idempotency key" do
      tool_ref = Atom.to_string(ValidTool)

      context1 = %{tool_params: %{order_id: "order_A"}, scopes: [], idempotency_token: "tok1"}
      context2 = %{tool_params: %{order_id: "order_B"}, scopes: [], idempotency_token: "tok2"}

      assert {:ok, proposal1} = Governance.propose(tool_ref, "user_1", context1)
      assert {:ok, proposal2} = Governance.propose(tool_ref, "user_1", context2)

      assert proposal1.idempotency_key != proposal2.idempotency_key
    end

    test "repeated blocked submission dedupes via idempotency key (CR-02/WR-06 regression)" do
      # A scope_invalid submission with identical params should not insert a second row.
      # Before CR-02/WR-06, propose_blocked/5 had no get_by pre-check and no else clause,
      # so the second insert would hit the unique index and the error was silently dropped.
      tool_ref = Atom.to_string(ScopeFailingTool)
      context = %{tool_params: %{data: "x"}, scopes: [], idempotency_token: "tok_blocked"}

      assert {:blocked, :scope_invalid, _} = Governance.propose(tool_ref, "user_1", context)
      assert {:blocked, :scope_invalid, _} = Governance.propose(tool_ref, "user_1", context)

      # Only one row should exist — the second call hit the pre-check and returned :ok.
      proposals = Process.get(:tool_proposals, [])
      assert length(proposals) == 1
      assert hd(proposals).status == :scope_invalid
    end

    test "deep-canonicalized input hashes identically regardless of nested map key order (WR-02)" do
      # Construct two contexts whose nested tool_params are semantically identical but
      # may differ in runtime map ordering. Both should produce the same idempotency key.
      tool_ref = Atom.to_string(ValidTool)

      context1 = %{
        tool_params: %{order_id: "order_nested"},
        scopes: [],
        idempotency_token: "tok_deep",
        account_id: "acct_deep"
      }

      context2 = %{
        tool_params: %{"order_id" => "order_nested"},
        scopes: [],
        idempotency_token: "tok_deep",
        account_id: "acct_deep"
      }

      # Both contexts produce valid proposals; after the first insert the second should
      # dedupe (same idempotency key because apply_changes normalizes atom/string keys).
      assert {:ok, proposal1} = Governance.propose(tool_ref, "user_1", context1)
      assert {:ok, proposal2} = Governance.propose(tool_ref, "user_1", context2)

      assert proposal1.id == proposal2.id
    end
  end
end
