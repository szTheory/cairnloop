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
          |> maybe_put_inserted_at()
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

    # ---------------------------------------------------------------------------
    # all/1 — handles Ecto.Query structs for list_proposals_for_conversation/1
    #
    # Parses the query's where clause to extract conversation_id, filters the
    # process-stored proposals, applies order_by desc: inserted_at, and
    # populates the events preload from the process-stored events list.
    # ---------------------------------------------------------------------------
    def all(%Ecto.Query{} = query) do
      # Extract conversation_id from the first where clause param
      conversation_id =
        case query.wheres do
          [%{params: [{conv_id, {0, :conversation_id}} | _]} | _] -> conv_id
          _ -> nil
        end

      proposals =
        Process.get(:tool_proposals, [])
        |> Enum.filter(fn p -> p.conversation_id == conversation_id end)
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

      # Handle preload of events (asc: inserted_at) if present
      all_events = Process.get(:tool_action_events, [])

      Enum.map(proposals, fn proposal ->
        events =
          all_events
          |> Enum.filter(fn e -> e.tool_proposal_id == proposal.id end)
          |> Enum.sort_by(& &1.inserted_at, :asc)

        %{proposal | events: events}
      end)
    end

    defp maybe_put_id(%{id: nil} = struct), do: %{struct | id: System.unique_integer([:positive])}
    defp maybe_put_id(struct), do: struct

    # Use Map.put rather than Map.put_new because inserted_at starts as nil on new structs
    defp maybe_put_inserted_at(%{inserted_at: nil} = struct), do: %{struct | inserted_at: DateTime.utc_now()}
    defp maybe_put_inserted_at(struct), do: struct

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

    @impl Cairnloop.Tool
    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [:order_id])
      |> Ecto.Changeset.validate_required([:order_id])
    end

    @impl Cairnloop.Tool
    def run(_tool, _actor, _ctx), do: {:ok, %{}}

    @impl Cairnloop.Tool
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

    @impl Cairnloop.Tool
    def changeset(struct, attrs) do
      Ecto.Changeset.cast(struct, attrs, [:data])
    end

    @impl Cairnloop.Tool
    def run(_tool, _actor, _ctx), do: {:ok, %{}}

    @impl Cairnloop.Tool
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

    @impl Cairnloop.Tool
    def changeset(struct, attrs) do
      Ecto.Changeset.cast(struct, attrs, [:data])
    end

    @impl Cairnloop.Tool
    def run(_tool, _actor, _ctx), do: {:ok, %{}}

    @impl Cairnloop.Tool
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

    @impl Cairnloop.Tool
    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [:required_field])
      |> Ecto.Changeset.validate_required([:required_field])
    end

    @impl Cairnloop.Tool
    def run(_tool, _actor, _ctx), do: {:ok, %{}}

    @impl Cairnloop.Tool
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

  # ---------------------------------------------------------------------------
  # Phase 14 Wave 0 extensions: governed-action surface behavior contracts
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Governance.list_proposals_for_conversation/1 — row 14-01-a
  #
  # This function does not exist until Wave 1 (Phase 14 plan 01). All tests
  # below are @tag :skip so the file compiles and runs now.
  # ---------------------------------------------------------------------------

  describe "list_proposals_for_conversation/1 — ordered scoped proposals (row 14-01-a)" do
    test "returns proposals ordered desc: inserted_at for a given conversation_id" do
      # Wave 1: extend MockRepo.all/1 to filter by conversation_id and return
      # seeded :tool_proposals; assert the result is ordered newest-first.
      conversation_id = 42

      # Insert two proposals with different inserted_at values (oldest first)
      tool_ref = Atom.to_string(ValidTool)
      context1 = %{tool_params: %{order_id: "order_list_1"}, scopes: [], conversation_id: conversation_id}
      context2 = %{tool_params: %{order_id: "order_list_2"}, scopes: [], conversation_id: conversation_id}

      assert {:ok, _p1} = Governance.propose(tool_ref, "user_1", context1)
      assert {:ok, _p2} = Governance.propose(tool_ref, "user_1", context2)

      # Wave 1 will implement list_proposals_for_conversation/1; call it here.
      results = apply(Governance, :list_proposals_for_conversation, [conversation_id])
      assert is_list(results)
      # Newest-first ordering
      ts_list = Enum.map(results, & &1.inserted_at)
      assert ts_list == Enum.sort(ts_list, {:desc, DateTime})
    end

    test "returns [] for a conversation with no proposals" do
      conversation_id = 9999
      results = apply(Governance, :list_proposals_for_conversation, [conversation_id])
      assert results == []
    end

    test "preloads events asc: inserted_at on each returned proposal" do
      conversation_id = 43

      tool_ref = Atom.to_string(ValidTool)
      context = %{tool_params: %{order_id: "order_events_preload"}, scopes: [], conversation_id: conversation_id}
      assert {:ok, _} = Governance.propose(tool_ref, "user_1", context)

      results = apply(Governance, :list_proposals_for_conversation, [conversation_id])
      assert [proposal | _] = results
      # Events must be loaded (not Ecto.Association.NotLoaded)
      assert is_list(proposal.events)
    end
  end

  # ---------------------------------------------------------------------------
  # conversation_id written on valid AND blocked paths (D-07) — row 14-01-b
  #
  # Skipped: conversation_id column does not exist on ToolProposal until
  # Wave 1 adds the migration and belongs_to association.
  # ---------------------------------------------------------------------------

  describe "propose/3 — conversation_id written on valid path (D-07, row 14-01-b)" do
    test "persisted ToolProposal carries conversation_id from context on valid path" do
      tool_ref = Atom.to_string(ValidTool)
      conversation_id = 100
      context = %{
        tool_params: %{order_id: "order_conv_valid"},
        scopes: [],
        conversation_id: conversation_id
      }

      assert {:ok, proposal} = Governance.propose(tool_ref, "user_1", context)
      # Wave 1 will add conversation_id field to ToolProposal and thread it through propose/3
      assert proposal.conversation_id == conversation_id
    end

    test "persisted ToolProposal carries conversation_id from context on blocked path (D-07)" do
      # D-07: blocked proposals (scope_invalid, policy_denied) also appear in the rail —
      # the Support-Truth Gate requires blocked proposals to be conversation-scoped.
      tool_ref = Atom.to_string(ScopeFailingTool)
      conversation_id = 101
      context = %{
        tool_params: %{data: "x"},
        scopes: [],
        conversation_id: conversation_id
      }

      assert {:blocked, :scope_invalid, _} = Governance.propose(tool_ref, "user_1", context)
      proposals = Process.get(:tool_proposals, [])
      assert [proposal] = proposals
      # Wave 1 will add conversation_id field
      assert proposal.conversation_id == conversation_id
    end
  end

  # ---------------------------------------------------------------------------
  # conversation_id EXCLUDED from idempotency key (D-08) — row 14-01-b
  #
  # This test runs NOW: derive_idempotency_key/4 already excludes any key not in
  # the canonical map. Adding conversation_id to context does not change the key.
  # ---------------------------------------------------------------------------

  describe "propose/3 — conversation_id excluded from idempotency key (D-08)" do
    test "identical action params with different conversation_id produce the same idempotency key" do
      # D-08: conversation_id is routing/identity metadata, not action identity.
      # Two propose/3 calls with identical action params but different conversation_id
      # must deduplicate to the same proposal (same idempotency key).
      tool_ref = Atom.to_string(ValidTool)

      context1 = %{
        tool_params: %{order_id: "order_idem_conv"},
        scopes: [],
        idempotency_token: "tok_conv",
        account_id: "acct_conv",
        conversation_id: 201
      }

      context2 = %{
        tool_params: %{order_id: "order_idem_conv"},
        scopes: [],
        idempotency_token: "tok_conv",
        account_id: "acct_conv",
        conversation_id: 202
      }

      assert {:ok, proposal1} = Governance.propose(tool_ref, "user_1", context1)
      assert {:ok, proposal2} = Governance.propose(tool_ref, "user_1", context2)

      # Second call must return the SAME proposal (deduplicated) because
      # conversation_id is not in the canonical map.
      assert proposal1.id == proposal2.id,
             "Expected same proposal id but got #{proposal1.id} and #{proposal2.id}; " <>
               "conversation_id must be excluded from the idempotency key (D-08)"
    end

    test "idempotency key is unchanged when conversation_id is added to context" do
      # Verify the deduplication from the key angle: the idempotency_key on the proposal
      # must be identical whether or not conversation_id is in context.
      tool_ref = Atom.to_string(ValidTool)

      context_without = %{
        tool_params: %{order_id: "order_key_test"},
        scopes: [],
        idempotency_token: "tok_key",
        account_id: "acct_key"
      }

      context_with = Map.put(context_without, :conversation_id, 999)

      assert {:ok, proposal_without} = Governance.propose(tool_ref, "user_1", context_without)
      assert {:ok, proposal_with} = Governance.propose(tool_ref, "user_1", context_with)

      assert proposal_without.idempotency_key == proposal_with.idempotency_key,
             "idempotency_key must not change when conversation_id is present in context (D-08)"
    end
  end
end
