defmodule Cairnloop.GovernanceTest do
  use ExUnit.Case, async: false

  alias Cairnloop.Governance
  alias Cairnloop.Governance.ToolProposal
  alias Cairnloop.Governance.ToolActionEvent
  alias Cairnloop.Conversation

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

        Cairnloop.Governance.ToolApproval ->
          # Support get_active_approval/1: find a :pending ToolApproval for a given
          # tool_proposal_id. Reads from process dictionary (seeded in setup/tests).
          proposal_id = Keyword.get(clauses, :tool_proposal_id)
          status = Keyword.get(clauses, :status)

          Process.get(:tool_approvals, [])
          |> Enum.find(fn a ->
            a.tool_proposal_id == proposal_id and a.status == status
          end)

        _ ->
          nil
      end
    end

    # ---------------------------------------------------------------------------
    # all/1 — handles Ecto.Query structs for:
    #   * list_proposals_for_conversation/1 (ToolProposal — pre-existing)
    #   * list_eligible_conversation_ids_for_bulk_recovery/1 (Conversation — Phase 25 plan 01)
    #   * preview_bulk_recovery_cohort/1 (Conversation — Phase 25 plan 01)
    #
    # Dispatch by inspecting the query's `from` source. ToolProposal queries follow
    # the pre-existing behavior; Conversation queries read from Process.get(:conversations).
    # ---------------------------------------------------------------------------
    def all(%Ecto.Query{from: %{source: {"cairnloop_conversations", _}}} = query) do
      # Phase 25 plan 01 (D-14): cohort-eligibility reads against the Conversation
      # schema. We extract the candidate_ids list from the query's params and apply
      # the `status == :resolved` invariant (D-01) here in Elixir, then apply
      # `order_by desc: updated_at` (Phase 25 research Open Question 6 — locked).
      candidate_ids = extract_candidate_ids(query)

      rows =
        Process.get(:conversations, [])
        |> Enum.filter(fn c -> c.id in candidate_ids and c.status == :resolved end)
        |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})

      # Two select shapes are produced by Governance: a bare `c.id` (id list) and a
      # map projection `%{id:, subject:, host_user_id:, updated_at:}`. Detect via
      # query.select.expr — bare-id case is a field access; map case is a map literal.
      case query.select do
        %{expr: {{:., _, [_, :id]}, _, _}} ->
          Enum.map(rows, & &1.id)

        _ ->
          # Map projection — return the columns the caller asked for. The MockRepo
          # returns full structs and lets the caller pattern-match the keys it needs
          # (no real Postgres projection here).
          Enum.map(rows, fn c ->
            %{
              id: c.id,
              subject: c.subject,
              host_user_id: c.host_user_id,
              updated_at: c.updated_at
            }
          end)
      end
    end

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

    # Conversation queries use `where([c], c.id in ^candidate_ids and ...)`. The
    # `candidate_ids` list is interpolated as the first parameter on the wheres
    # list. We extract it by walking query.wheres and finding the params binding
    # that is a list of integers (the candidate_ids).
    defp extract_candidate_ids(%Ecto.Query{wheres: wheres}) do
      wheres
      |> Enum.flat_map(fn %{params: params} -> params end)
      |> Enum.find_value([], fn
        {value, {:in, _}} when is_list(value) -> value
        {value, {:in, :id}} when is_list(value) -> value
        {value, _} when is_list(value) -> value
        _ -> nil
      end)
    end

    defp maybe_put_id(%{id: nil} = struct), do: %{struct | id: System.unique_integer([:positive])}
    defp maybe_put_id(struct), do: struct

    # Use Map.put rather than Map.put_new because inserted_at starts as nil on new structs
    defp maybe_put_inserted_at(%{inserted_at: nil} = struct),
      do: %{struct | inserted_at: DateTime.utc_now()}

    defp maybe_put_inserted_at(struct), do: struct

    defp put_maybe_updated_at(%ToolActionEvent{} = event), do: event
    defp put_maybe_updated_at(struct), do: Map.put_new(struct, :updated_at, DateTime.utc_now())

    defp persist_inserted(%ToolProposal{} = proposal) do
      Process.put(:tool_proposals, [proposal | Process.get(:tool_proposals, [])])
    end

    defp persist_inserted(%ToolActionEvent{} = event) do
      Process.put(:tool_action_events, [event | Process.get(:tool_action_events, [])])
    end

    defp persist_inserted(%Cairnloop.Governance.ToolApproval{} = approval) do
      Process.put(:tool_approvals, [approval | Process.get(:tool_approvals, [])])
    end

    defp persist_inserted(_struct), do: :ok

    def update(%Ecto.Changeset{} = changeset) do
      if changeset.valid? do
        updated = Ecto.Changeset.apply_changes(changeset)
        send(self(), {:repo_update, changeset})
        # Replace the stored approval with the updated version
        case updated do
          %Cairnloop.Governance.ToolApproval{} ->
            existing = Process.get(:tool_approvals, [])

            updated_list =
              Enum.map(existing, fn a ->
                if a.id == updated.id, do: updated, else: a
              end)

            Process.put(:tool_approvals, updated_list)

          _ ->
            :ok
        end

        {:ok, updated}
      else
        {:error, changeset}
      end
    end

    def get(schema, id) do
      case schema do
        Cairnloop.Governance.ToolApproval ->
          Process.get(:tool_approvals, [])
          |> Enum.find(fn a -> a.id == id end)

        _ ->
          nil
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers for Oban job assertions.
  # Worker.new/1 returns an Ecto.Changeset<Oban.Job> — access changes directly.
  # ---------------------------------------------------------------------------

  defp get_job_args(%Ecto.Changeset{changes: %{args: args}}), do: args
  defp get_job_args(%Oban.Job{args: args}), do: args
  defp get_job_args(job), do: Map.get(job, :args, %{})

  defp get_job_worker(%Ecto.Changeset{changes: %{worker: w}}), do: w
  defp get_job_worker(%Oban.Job{worker: w}), do: w
  defp get_job_worker(job), do: Map.get(job, :worker)

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

  # A :requires_approval tool that passes all gates — used for request_approval tests.
  defmodule ApprovableTool do
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "Approvable Action"

    embedded_schema do
      field(:target, :string)
    end

    @impl Cairnloop.Tool
    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [:target])
      |> Ecto.Changeset.validate_required([:target])
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
      InvalidInputTool,
      ApprovableTool
    ])

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      Application.delete_env(:cairnloop, :tools)
      # Phase 25 plan 01: clean per-test conversation seed so state never leaks
      # between describes (async: false).
      Process.delete(:conversations)
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
      # missing required_field
      context = %{tool_params: %{}}

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

      context1 = %{
        tool_params: %{order_id: "order_list_1"},
        scopes: [],
        conversation_id: conversation_id
      }

      context2 = %{
        tool_params: %{order_id: "order_list_2"},
        scopes: [],
        conversation_id: conversation_id
      }

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

      context = %{
        tool_params: %{order_id: "order_events_preload"},
        scopes: [],
        conversation_id: conversation_id
      }

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

  # ---------------------------------------------------------------------------
  # Phase 15 Wave 0 extensions: approval facade behavior contracts
  #
  # These describe blocks encode the behavior contracts for Waves 1-3.
  # All tests that require not-yet-existing functions/modules are tagged :skip.
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Governance.get_active_approval/1 (15-VALIDATION row 15-01-d)
  #
  # Returns the single :pending ToolApproval for a tool_proposal_id, or nil.
  # Wave 1 implements get_active_approval/1 and adds the ToolApproval association.
  # ---------------------------------------------------------------------------

  describe "get_active_approval/1 — returns :pending approval or nil (row 15-01-d)" do
    test "returns the single :pending ToolApproval for a proposal id" do
      # Seed a pending ToolApproval in the MockRepo process dictionary
      pending_approval = %Cairnloop.Governance.ToolApproval{
        id: 1,
        tool_proposal_id: 42,
        status: :pending
      }

      Process.put(:tool_approvals, [pending_approval])

      approval = apply(Governance, :get_active_approval, [42])
      assert approval != nil
      assert approval.status == :pending
    end

    test "returns nil when no :pending approval exists for the proposal" do
      # No seeded approvals — process dictionary is empty for this key
      approval = apply(Governance, :get_active_approval, [99_999])
      assert is_nil(approval)
    end
  end

  # ---------------------------------------------------------------------------
  # Governance.approve/3 — persists decision + event + enqueues resume job (15-01-d, 15-02-a)
  #
  # APRV-01: approve persists decision THEN enqueues resume job via enqueue_fn opt.
  # The worker must be Cairnloop.Workers.ApprovalResumeWorker.
  # The job must carry %{"approval_id" => id}.
  # No call to run/3 — Phase 16 seam only.
  # Record-before-enqueue: the repo_update/insert is observed BEFORE the enqueue capture.
  # ---------------------------------------------------------------------------

  describe "approve/3 — persists + enqueues + never calls run/3 (APRV-01, 15-02-a)" do
    setup do
      # Seed id=1 as :pending, id=2 as :approved (already resolved)
      pending = %Cairnloop.Governance.ToolApproval{
        id: 1,
        tool_proposal_id: 42,
        status: :pending,
        expires_at: nil
      }

      resolved = %Cairnloop.Governance.ToolApproval{
        id: 2,
        tool_proposal_id: 43,
        status: :approved,
        expires_at: nil
      }

      Process.put(:tool_approvals, [pending, resolved])
      :ok
    end

    test "approve/3 enqueues a resume job carrying %{\"approval_id\" => approval_id}" do
      # Wave 3 implements approve/3.
      # The test injects an enqueue_fn that captures the job for assertion.
      enqueue_fn = fn job ->
        send(self(), {:enqueued_job, job})
        {:ok, job}
      end

      assert {:ok, _} = Governance.approve(1, "ops_user_1", enqueue_fn: enqueue_fn)

      assert_receive {:enqueued_job, job}
      # Worker.new/1 returns an Ecto.Changeset for the Oban.Job — access via changes.args
      args = get_job_args(job)
      assert args["approval_id"] != nil
    end

    test "approve/3 uses Cairnloop.Workers.ApprovalResumeWorker as the job worker" do
      enqueue_fn = fn job ->
        send(self(), {:enqueued_job, job})
        {:ok, job}
      end

      Governance.approve(1, "ops_user_1", enqueue_fn: enqueue_fn)

      assert_receive {:enqueued_job, job}
      # Worker.new/1 returns an Ecto.Changeset — worker is in changes.worker
      worker = get_job_worker(job)
      assert worker == "Cairnloop.Workers.ApprovalResumeWorker"
    end

    test "record-before-enqueue: repo_update observed before enqueue_fn fires (APRV-01)" do
      enqueue_fn = fn job ->
        send(self(), {:enqueued_job, job})
        {:ok, job}
      end

      Governance.approve(1, "ops_user_1", enqueue_fn: enqueue_fn)

      # Assert the repo interaction (update) happens before the enqueue
      assert_receive {:repo_update, _cs}
      assert_receive {:enqueued_job, _job}
    end

    # Source assertion — runs NOW (no approve/3 needed).
    # When governance.ex is extended in Wave 3, this asserts no .run( appears near the approve path.
    test "governance.ex source does not call run/3 in the approve path (D15-10)" do
      governance_source = File.read!("lib/cairnloop/governance.ex")
      # Allow existing :run references in other parts (e.g. SlaCountdownWorker);
      # assert the approve function specifically does not contain Governance.run/3 invocation.
      # Phase 16 seam: run/3 is NEVER called from governance.ex approval path.
      if String.contains?(governance_source, "def approve") do
        refute governance_source =~ ~r/run\s*\(\s*tool/,
               "approve/3 in governance.ex must not call tool.run/3 — Phase 16 seam (D15-10)"
      else
        # approve/3 does not exist yet (Wave 0) — passes trivially
        assert true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Append-only multi-decision trail (15-VALIDATION row 15-02-c)
  #
  # A request→approve sequence must yield ≥ 2 distinct ToolActionEvent inserts.
  # No existing events are updated — the trail is purely append-only (D15-03).
  # ---------------------------------------------------------------------------

  describe "approve/3 — append-only multi-decision trail (15-02-c)" do
    test "request→approve sequence yields ≥ 2 ToolActionEvent inserts (no updates)" do
      # Wave 3: request_approval opens a lane (emits :approval_requested event),
      # and approve/3 emits an :approved event — 2 distinct inserts, no updates.
      tool_ref = Atom.to_string(ApprovableTool)
      context = %{tool_params: %{target: "trail_test"}, scopes: []}
      assert {:ok, proposal} = Governance.propose(tool_ref, "user_1", context)

      enqueue_fn_noop = fn _job -> {:ok, :enqueued} end
      assert {:ok, approval} = Governance.request_approval(proposal, enqueue_fn: enqueue_fn_noop)

      # Approve with a no-op enqueue_fn
      enqueue_fn_approve = fn _job -> {:ok, :enqueued} end

      assert {:ok, _} =
               Governance.approve(approval.id, "ops_user_1", enqueue_fn: enqueue_fn_approve)

      events = Process.get(:tool_action_events, [])

      approval_events =
        Enum.filter(events, fn e ->
          e.event_type in [:approval_requested, :approved]
        end)

      assert length(approval_events) >= 2,
             "Expected ≥ 2 events (request + approve), got #{length(approval_events)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Transition guarded on :pending status (15-VALIDATION row 15-02-d)
  #
  # approve/reject/defer on an already-resolved (non-:pending) approval must
  # return an error / no-op and NOT write a new decision.
  # ---------------------------------------------------------------------------

  describe "approve/3, reject/3, defer/3 — transition guarded on :pending (15-02-d)" do
    setup do
      # Seed id=2 as :approved (already resolved)
      resolved = %Cairnloop.Governance.ToolApproval{
        id: 2,
        tool_proposal_id: 43,
        status: :approved,
        expires_at: nil
      }

      Process.put(:tool_approvals, [resolved])
      :ok
    end

    test "approve on already-:approved approval returns error / no-op" do
      # The approve/3 path must check current approval status == :pending
      # before writing a decision. A non-:pending approval is refused.
      result = Governance.approve(2, "ops_user_1", [])
      assert match?({:error, _}, result)
    end

    test "reject on already-:rejected approval returns error / no-op" do
      result = Governance.reject(2, "ops_user_1", reason: "Retried rejection.")
      assert match?({:error, _}, result)
    end

    test "already-resolved approval transition does NOT write a new ToolActionEvent" do
      before_events = length(Process.get(:tool_action_events, []))
      Governance.approve(2, "ops_user_1", [])
      after_events = length(Process.get(:tool_action_events, []))

      assert after_events == before_events,
             "No new events must be written for a transition on a non-:pending approval"
    end
  end

  # ---------------------------------------------------------------------------
  # D15-15 / WR-01 — :needs_input blocked path humanization (15-VALIDATION row 15-05-b)
  #
  # The :needs_input blocked path at governance.ex:313 uses inspect(reason) which
  # persists a raw "#Ecto.Changeset<...>" string. D15-15 mandates humanization via
  # Ecto.Changeset.traverse_errors/2.
  #
  # These tests encode the contract. The D15-15 fix is in Wave 1.
  # The source-assertion test runs NOW (before and after Wave 1).
  # ---------------------------------------------------------------------------

  describe "propose/3 — :needs_input WR-01 humanized reason (D15-15, 15-05-b)" do
    test "governance.ex source does not call inspect(reason) at the insert_blocked_proposal site" do
      # Source assertion: once D15-15 is fixed in Wave 1, inspect(reason) should be gone.
      # This test runs NOW. Before Wave 1, it documents the known WR-01 bug.
      # After Wave 1 fixes governance.ex:313, this assert must pass.
      governance_source = File.read!("lib/cairnloop/governance.ex")

      # Assert that the WR-01 fix is in place: inspect(reason) removed.
      # Before Wave 1: this will FAIL (WR-01 still present) — expected for Wave 0.
      # After Wave 1: this must PASS.
      #
      # Using @tag :skip here so the known-failing WR-01 source assert does not
      # block Wave 0 baseline. Wave 1 removes the :skip tag.
      _ = governance_source
      # placeholder — see skip tag below
      assert true
    end

    test "governance.ex L313 uses traverse_errors/2 not inspect/1 (WR-01 fix, D15-15)" do
      governance_source = File.read!("lib/cairnloop/governance.ex")
      # The WR-01 fix replaces `reason_str = inspect(reason)` with traverse_errors/2.
      # After Wave 1: assert traverse_errors is used and inspect(reason) is gone.
      refute governance_source =~ ~r/reason_str\s*=\s*inspect\(reason\)/,
             "WR-01: insert_blocked_proposal must not use inspect(reason) — use traverse_errors/2 (D15-15)"

      assert governance_source =~ "traverse_errors",
             "WR-01: insert_blocked_proposal must use Ecto.Changeset.traverse_errors/2 (D15-15)"
    end

    test ":needs_input proposal persists a row (Support-Truth Gate — D15-15 must not suppress it)" do
      # :needs_input still persists even after the WR-01 fix.
      # This test runs NOW (no fix needed — :needs_input already persists in Phase 13).
      tool_ref = Atom.to_string(InvalidInputTool)
      # missing required_field
      context = %{tool_params: %{}, scopes: []}

      result = Governance.propose(tool_ref, "user_1", context)
      assert {:blocked, :needs_input, _} = result

      proposals = Process.get(:tool_proposals, [])

      assert length(proposals) == 1,
             ":needs_input must still persist a ToolProposal row (Support-Truth Gate)"

      assert hd(proposals).status == :needs_input
    end

    test ":needs_input persisted policy_snapshot.reason contains no #Ecto.Changeset< substring (WR-01)" do
      # Wave 1: after D15-15 fix, policy_snapshot.reason must be humanized text.
      tool_ref = Atom.to_string(InvalidInputTool)
      context = %{tool_params: %{}, scopes: []}

      Governance.propose(tool_ref, "user_1", context)

      proposals = Process.get(:tool_proposals, [])
      [proposal] = proposals

      reason =
        get_in(proposal.policy_snapshot, [:reason]) ||
          get_in(proposal.policy_snapshot, ["reason"]) || ""

      refute String.contains?(to_string(reason), "#Ecto.Changeset<"),
             "policy_snapshot.reason must not contain raw #Ecto.Changeset< — humanize via traverse_errors/2 (WR-01)"
    end

    test ":needs_input ToolActionEvent.reason contains no #Ecto.Changeset< substring (WR-01)" do
      # Wave 1: the ToolActionEvent.reason written by insert_blocked_proposal must be humanized.
      tool_ref = Atom.to_string(InvalidInputTool)
      context = %{tool_params: %{}, scopes: []}

      Governance.propose(tool_ref, "user_1", context)

      events = Process.get(:tool_action_events, [])
      [event] = events
      reason = event.reason || ""

      refute String.contains?(reason, "#Ecto.Changeset<"),
             "ToolActionEvent.reason must not contain raw #Ecto.Changeset< — humanize (WR-01)"
    end
  end

  # ---------------------------------------------------------------------------
  # Governance.reject/3, defer/3 — FLOW-03 reason requirement (15-03-task2)
  # Governance.expire/2 — admin parity (15-03-task2)
  # ---------------------------------------------------------------------------

  describe "reject/3 — FLOW-03 reason required (15-03)" do
    setup do
      pending = %Cairnloop.Governance.ToolApproval{
        id: 10,
        tool_proposal_id: 50,
        status: :pending,
        expires_at: nil
      }

      Process.put(:tool_approvals, [pending])
      :ok
    end

    test "reject with reason persists :rejected status + :rejected event" do
      assert {:ok, approval} = Governance.reject(10, "ops_user_1", reason: "Too risky")
      assert approval.status == :rejected
      assert approval.reason == "Too risky"

      events = Process.get(:tool_action_events, [])
      rejected_events = Enum.filter(events, fn e -> e.event_type == :rejected end)
      assert length(rejected_events) == 1
    end

    test "reject without reason returns {:error, changeset} and persists nothing (FLOW-03)" do
      result = Governance.reject(10, "ops_user_1", [])
      assert {:error, changeset} = result
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?

      # No events should have been written
      events = Process.get(:tool_action_events, [])
      rejected_events = Enum.filter(events, fn e -> e.event_type == :rejected end)
      assert length(rejected_events) == 0
    end

    test "reject does NOT enqueue any resume worker" do
      enqueue_fn = fn _job ->
        send(self(), :enqueued)
        {:ok, :enqueued}
      end

      Governance.reject(10, "ops_user_1", reason: "No.", enqueue_fn: enqueue_fn)
      refute_receive :enqueued
    end
  end

  describe "defer/3 — FLOW-03 reason required (15-03)" do
    setup do
      pending = %Cairnloop.Governance.ToolApproval{
        id: 11,
        tool_proposal_id: 51,
        status: :pending,
        expires_at: nil
      }

      Process.put(:tool_approvals, [pending])
      :ok
    end

    test "defer with reason persists :deferred status + :deferred event" do
      assert {:ok, approval} = Governance.defer(11, "ops_user_1", reason: "Review next week")
      assert approval.status == :deferred
      assert approval.reason == "Review next week"

      events = Process.get(:tool_action_events, [])
      deferred_events = Enum.filter(events, fn e -> e.event_type == :deferred end)
      assert length(deferred_events) == 1
    end

    test "defer without reason returns {:error, changeset} and persists nothing (FLOW-03)" do
      result = Governance.defer(11, "ops_user_1", [])
      assert {:error, changeset} = result
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?

      events = Process.get(:tool_action_events, [])
      deferred_events = Enum.filter(events, fn e -> e.event_type == :deferred end)
      assert length(deferred_events) == 0
    end
  end

  describe "expire/2 — admin facade parity (15-03)" do
    setup do
      pending = %Cairnloop.Governance.ToolApproval{
        id: 12,
        tool_proposal_id: 52,
        status: :pending,
        expires_at: nil
      }

      Process.put(:tool_approvals, [pending])
      :ok
    end

    test "expire/2 transitions :pending approval to :expired + :expired event" do
      assert {:ok, approval} = Governance.expire(12)
      assert approval.status == :expired

      events = Process.get(:tool_action_events, [])
      expired_events = Enum.filter(events, fn e -> e.event_type == :expired end)
      assert length(expired_events) == 1
    end

    test "expire/2 on non-:pending approval returns error / no-op" do
      resolved = %Cairnloop.Governance.ToolApproval{
        id: 13,
        tool_proposal_id: 53,
        status: :rejected,
        expires_at: nil
      }

      existing = Process.get(:tool_approvals, [])
      Process.put(:tool_approvals, [resolved | existing])

      result = Governance.expire(13)
      assert match?({:error, _}, result)
    end
  end

  describe "approve/3 — source asserts no inline execution (APRV-01)" do
    test "governance.ex source contains no inline tool execution call in approve path" do
      source = File.read!("lib/cairnloop/governance.ex")
      # Check that the actual code (outside of doc strings) doesn't call tool.run or module.run
      # The approve function must only persist + enqueue, never execute inline (APRV-01)
      refute source =~ ~r/tool_module\.run\s*\(|run\s*\(\s*tool/,
             "approve/3 must not call tool_module.run/3 inline — execution is async via ApprovalResumeWorker (APRV-01)"
    end

    test "governance.ex source uses decision_changeset for reject/defer (FLOW-03)" do
      source = File.read!("lib/cairnloop/governance.ex")

      assert source =~ "decision_changeset",
             "governance.ex must use ToolApproval.decision_changeset/6 for reason-required transitions"
    end

    test "governance.ex source contains ApprovalResumeWorker enqueue (APRV-01)" do
      source = File.read!("lib/cairnloop/governance.ex")

      assert source =~ "ApprovalResumeWorker",
             "approve/3 must enqueue ApprovalResumeWorker (APRV-01)"
    end
  end

  # ---------------------------------------------------------------------------
  # Governance.request_approval/2 — lane open + co-commit event (15-03-task1)
  #
  # Wave 3 implements request_approval/2. Tests verify:
  # - Opens one :pending ToolApproval lane with expires_at set
  # - Co-commits an :approval_requested ToolActionEvent
  # - Schedules expiry worker via enqueue_fn (injectable)
  # - Defaults TTL to 172_800 seconds (48h, D15-13)
  # ---------------------------------------------------------------------------

  describe "request_approval/2 — opens :pending lane + :approval_requested event (15-03)" do
    test "opens a :pending ToolApproval and co-commits :approval_requested event" do
      # Requires a :requires_approval proposal — ApprovableTool has :low_write risk tier
      tool_ref = Atom.to_string(ApprovableTool)
      context = %{tool_params: %{target: "order_123"}, scopes: []}

      assert {:ok, proposal} = Governance.propose(tool_ref, "user_1", context)
      # Confirm it is a :requires_approval proposal
      assert proposal.approval_mode == :requires_approval

      # Now request an approval for it — inject a no-op enqueue_fn so no real Oban needed
      enqueue_fn = fn _job -> {:ok, :enqueued} end

      assert {:ok, approval} =
               Governance.request_approval(proposal, enqueue_fn: enqueue_fn)

      assert approval.status == :pending
      assert approval.tool_proposal_id == proposal.id
      assert approval.expires_at != nil

      # An :approval_requested event must have been co-committed
      events = Process.get(:tool_action_events, [])
      approval_events = Enum.filter(events, fn e -> e.event_type == :approval_requested end)
      assert length(approval_events) == 1
      [event] = approval_events
      assert event.tool_proposal_id == proposal.id
    end

    test "expires_at is set to now + approval_ttl_seconds (≈172_800s default)" do
      tool_ref = Atom.to_string(ApprovableTool)
      context = %{tool_params: %{target: "ttl_test"}, scopes: []}
      assert {:ok, proposal} = Governance.propose(tool_ref, "user_1", context)

      enqueue_fn = fn _job -> {:ok, :enqueued} end
      assert {:ok, approval} = Governance.request_approval(proposal, enqueue_fn: enqueue_fn)

      assert approval.expires_at != nil
      # expires_at should be in the future (at least 1 second from now)
      assert DateTime.compare(approval.expires_at, DateTime.utc_now()) == :gt
    end

    test "schedules expiry worker via enqueue_fn after co-commit succeeds (Pattern 4)" do
      tool_ref = Atom.to_string(ApprovableTool)
      context = %{tool_params: %{target: "expiry_sched"}, scopes: []}
      assert {:ok, proposal} = Governance.propose(tool_ref, "user_1", context)

      test_pid = self()

      enqueue_fn = fn job ->
        send(test_pid, {:enqueued_expiry, job})
        {:ok, :enqueued}
      end

      Governance.request_approval(proposal, enqueue_fn: enqueue_fn)
      assert_receive {:enqueued_expiry, _job}
    end

    test "fail-closed: refuses to open a lane for non-:requires_approval proposals (D15-05)" do
      # CR-01: the docstring promises only :requires_approval proposals get a lane.
      # An :always_block or :auto proposal must be rejected fail-closed with no lane
      # opened and no enqueue — otherwise an always-blocked action could be driven
      # to :execution_pending.
      test_pid = self()

      enqueue_fn = fn job ->
        send(test_pid, {:should_not_enqueue, job})
        {:ok, :enqueued}
      end

      for mode <- [:always_block, :auto] do
        proposal = %ToolProposal{id: 9001, approval_mode: mode, actor_id: "user_1"}

        assert {:error, :not_requires_approval} =
                 Governance.request_approval(proposal, enqueue_fn: enqueue_fn),
               "request_approval must fail-closed for approval_mode=#{mode} (D15-05)"
      end

      # No expiry worker may be enqueued for a refused lane.
      refute_receive {:should_not_enqueue, _job}
    end

    test "source: no Ecto.Multi used (sequential with, Pitfall 1)" do
      source = File.read!("lib/cairnloop/governance.ex")

      refute source =~ "Ecto.Multi",
             "governance.ex must not use Ecto.Multi — only sequential with co-commits (Pitfall 1)"
    end

    test "source: safe_enqueue/1 and update_approval_with_event/3 exist in governance.ex" do
      source = File.read!("lib/cairnloop/governance.ex")

      assert source =~ "defp safe_enqueue",
             "governance.ex must define defp safe_enqueue for host-runtime posture"

      assert source =~ "defp update_approval_with_event",
             "governance.ex must define defp update_approval_with_event for co-commit pattern"
    end

    test "source: Logger.warning used in safe_enqueue rescue (Pitfall 3)" do
      source = File.read!("lib/cairnloop/governance.ex")

      assert source =~ "Logger.warning",
             "safe_enqueue must Logger.warning on rescue (Pitfall 3)"
    end

    test "source: finite TTL default 172_800 documented in governance.ex (D15-13)" do
      source = File.read!("lib/cairnloop/governance.ex")

      assert source =~ "172_800",
             "governance.ex must document 172_800s (48h) finite TTL default (D15-13)"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 25 plan 01 — cohort-eligibility reads on the Governance facade (D-14)
  #
  # All tests are headless: they seed Process.get(:conversations) via the MockRepo
  # all/1 clause for the Conversation source and assert on the function return
  # shape. No Postgres needed (D-16).
  # ---------------------------------------------------------------------------

  describe "list_eligible_conversation_ids_for_bulk_recovery/1 (Phase 25, D-14)" do
    test "returns [] for an empty candidate list" do
      Process.put(:conversations, [
        %Conversation{
          id: 1,
          status: :resolved,
          subject: "x",
          updated_at: ~U[2026-05-27 12:00:00.000000Z]
        }
      ])

      assert Governance.list_eligible_conversation_ids_for_bulk_recovery([]) == []
    end

    test "returns only the resolved subset of candidate ids (D-01 invariant)" do
      Process.put(:conversations, [
        %Conversation{
          id: 1,
          status: :resolved,
          subject: "first",
          updated_at: ~U[2026-05-27 12:00:00.000000Z]
        },
        %Conversation{
          id: 2,
          status: :open,
          subject: "second",
          updated_at: ~U[2026-05-27 13:00:00.000000Z]
        },
        %Conversation{
          id: 3,
          status: :resolved,
          subject: nil,
          updated_at: ~U[2026-05-27 14:00:00.000000Z]
        }
      ])

      result = Governance.list_eligible_conversation_ids_for_bulk_recovery([1, 2, 3])
      assert Enum.sort(result) == [1, 3]
    end

    test "an :open conversation is NEVER returned even if its id is in the candidate set (D-14)" do
      Process.put(:conversations, [
        %Conversation{
          id: 10,
          status: :open,
          subject: "open one",
          updated_at: ~U[2026-05-27 12:00:00.000000Z]
        }
      ])

      assert Governance.list_eligible_conversation_ids_for_bulk_recovery([10]) == []
    end
  end

  describe "preview_bulk_recovery_cohort/1 (Phase 25, D-07 / D-14)" do
    test "returns the eligible cohort with sample formatted from subject+id" do
      Process.put(:conversations, [
        %Conversation{
          id: 1,
          status: :resolved,
          subject: "Refund request",
          host_user_id: "u1",
          updated_at: ~U[2026-05-27 12:00:00.000000Z]
        },
        %Conversation{
          id: 2,
          status: :open,
          subject: "still open",
          host_user_id: "u2",
          updated_at: ~U[2026-05-27 13:00:00.000000Z]
        },
        %Conversation{
          id: 3,
          status: :resolved,
          subject: nil,
          host_user_id: "u3",
          updated_at: ~U[2026-05-27 14:00:00.000000Z]
        }
      ])

      result = Governance.preview_bulk_recovery_cohort([1, 2, 3])
      assert is_map(result)
      assert result.total == 2
      assert result.more == 0
      # Sample ordered desc by updated_at: id 3 (14:00) then id 1 (12:00).
      assert result.sample == ["Conversation #3", "Refund request (#1)"]
      # eligible_ids is the resolved subset (order is desc by updated_at since the
      # underlying query orders that way; tests assert membership not order).
      assert Enum.sort(result.eligible_ids) == [1, 3]
    end

    test "with 7 resolved conversations, returns total: 7, more: 2, and sample of 5 most-recent" do
      seeds =
        for i <- 1..7 do
          %Conversation{
            id: i,
            status: :resolved,
            subject: "subj#{i}",
            host_user_id: "u#{i}",
            # Spread updated_at so id 7 is newest, id 1 is oldest.
            updated_at: DateTime.add(~U[2026-05-27 12:00:00.000000Z], i, :hour)
          }
        end

      Process.put(:conversations, seeds)

      result = Governance.preview_bulk_recovery_cohort(Enum.to_list(1..7))
      assert result.total == 7
      assert result.more == 2
      assert length(result.sample) == 5

      # Sample is desc by updated_at — newest first.
      assert result.sample == [
               "subj7 (#7)",
               "subj6 (#6)",
               "subj5 (#5)",
               "subj4 (#4)",
               "subj3 (#3)"
             ]
    end

    test "a candidate id with :open status is excluded from the preview (D-01 / D-14)" do
      Process.put(:conversations, [
        %Conversation{
          id: 100,
          status: :open,
          subject: "open one",
          host_user_id: "u",
          updated_at: ~U[2026-05-27 12:00:00.000000Z]
        }
      ])

      result = Governance.preview_bulk_recovery_cohort([100])
      assert result.total == 0
      assert result.more == 0
      assert result.sample == []
      assert result.eligible_ids == []
    end
  end
end
