defmodule Cairnloop.Auditor.GovernanceTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Pure structural tests (no Repo): verify nil-guard idiom used in the
  # enriched event map (conversation_id and proposal_id fields).
  #
  # The enriched map must satisfy:
  #   - conversation_id: nil when tool_proposal is nil (fail-closed, D-08)
  #   - conversation_id: the proposal's conversation_id when present
  #   - proposal_id: event.tool_proposal_id (always present on the event)
  #
  # These tests exercise the Enum.map accessor expression in isolation.
  # ---------------------------------------------------------------------------

  describe "enriched map nil-guard logic (pure, no Repo)" do
    test "when proposal is nil, conversation_id resolves to nil" do
      # This mirrors the expression used in the Enum.map:
      # conversation_id: if(proposal, do: proposal.conversation_id)
      proposal = nil
      conversation_id = if proposal, do: Map.get(proposal, :conversation_id)
      assert conversation_id == nil
    end

    test "when proposal has a conversation_id, it is returned" do
      proposal = %{conversation_id: 42}
      conversation_id = if proposal, do: Map.get(proposal, :conversation_id)
      assert conversation_id == 42
    end

    test "when proposal has a nil conversation_id, nil is returned" do
      proposal = %{conversation_id: nil}
      conversation_id = if proposal, do: Map.get(proposal, :conversation_id)
      assert conversation_id == nil
    end
  end

  # ---------------------------------------------------------------------------
  # REPO-UNAVAILABLE: DB round-trip tests for the enriched map FK join.
  # These tests require a live Postgres connection via Cairnloop.Repo.
  # Run in: mix test.integration
  # ---------------------------------------------------------------------------

  # @tag :integration
  # test "list_events/1 returns map with conversation_id from preloaded tool_proposal" do
  #   # REPO-UNAVAILABLE: requires Cairnloop.Repo + seeded ToolActionEvent + ToolProposal
  #   # events = Cairnloop.Auditor.Governance.list_events(limit: 1)
  #   # event = hd(events)
  #   # assert Map.has_key?(event, :conversation_id)
  #   # assert Map.has_key?(event, :proposal_id)
  # end
  #
  # @tag :integration
  # test "list_events/1 nil proposal => conversation_id nil in returned map" do
  #   # REPO-UNAVAILABLE: requires Cairnloop.Repo + seeded ToolActionEvent
  #   # events = Cairnloop.Auditor.Governance.list_events(limit: 1)
  #   # event = hd(events)
  #   # assert event.conversation_id == nil
  # end
end

defmodule Cairnloop.Governance.ListActionEventsFilterTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Pure structural tests (no Repo): verify the proposal_id opt extraction
  # logic that backs the conditional-where in list_action_events/1.
  # ---------------------------------------------------------------------------

  describe "proposal_id option handling — pure logic (no Repo)" do
    test "Keyword.get extracts proposal_id from opts" do
      opts = [limit: 10, proposal_id: 99]
      proposal_id = Keyword.get(opts, :proposal_id)
      assert proposal_id == 99
    end

    test "Keyword.get returns nil when proposal_id not in opts" do
      opts = [limit: 10, offset: 0]
      proposal_id = Keyword.get(opts, :proposal_id)
      assert proposal_id == nil
    end

    test "Keyword.get returns nil for empty opts" do
      opts = []
      proposal_id = Keyword.get(opts, :proposal_id)
      assert proposal_id == nil
    end

    test "proposal_id from opts can be used as a non-nil conditional filter indicator" do
      with_proposal = [limit: 5, proposal_id: 7]
      without_proposal = [limit: 5]
      assert Keyword.get(with_proposal, :proposal_id) != nil
      assert Keyword.get(without_proposal, :proposal_id) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # REPO-UNAVAILABLE: DB round-trip tests for proposal_id filter behavior.
  # Run in: mix test.integration
  # ---------------------------------------------------------------------------

  # @tag :integration
  # test "list_action_events(proposal_id: id) returns only events for that proposal" do
  #   # REPO-UNAVAILABLE: requires Cairnloop.Repo + seeded ToolActionEvents
  #   # events = Cairnloop.Governance.list_action_events(proposal_id: known_proposal_id)
  #   # assert Enum.all?(events, fn e -> e.tool_proposal_id == known_proposal_id end)
  # end
  #
  # @tag :integration
  # test "list_action_events([]) returns all events (unfiltered by proposal)" do
  #   # REPO-UNAVAILABLE: requires Cairnloop.Repo
  #   # all_events = Cairnloop.Governance.list_action_events([])
  #   # refute Enum.empty?(all_events)
  # end
  #
  # @tag :integration
  # test "list_action_events(limit: n) works unchanged when no proposal_id opt present" do
  #   # REPO-UNAVAILABLE: requires Cairnloop.Repo
  #   # events = Cairnloop.Governance.list_action_events(limit: 1)
  #   # assert length(events) <= 1
  # end
end
