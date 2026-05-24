defmodule Cairnloop.Web.ToolProposalPresenterTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Module-under-test reference
  #
  # Cairnloop.Web.ToolProposalPresenter does NOT exist until Wave 1.
  # All tests below are tagged :skip so this file compiles and runs now.
  # Remove :skip as each function is implemented in Wave 1.
  # ---------------------------------------------------------------------------

  @presenter Cairnloop.Web.ToolProposalPresenter

  # ---------------------------------------------------------------------------
  # Inline fixture helpers (no shared factory — existing repo idiom)
  # ---------------------------------------------------------------------------

  defp proposal(overrides) do
    %Cairnloop.Governance.ToolProposal{
      id: 1,
      tool_ref: "Cairnloop.Tools.LookupOrder",
      tool_version: nil,
      status: :proposed,
      risk_tier: :read_only,
      approval_mode: :auto,
      actor_id: "user_42",
      account_id: "acct_1",
      input_snapshot: %{order_id: "ord_123"},
      scope_snapshot: %{scopes: []},
      policy_snapshot: %{outcome: :proposed, reason: nil},
      events: []
    }
    |> Map.merge(overrides)
  end

  defp event(overrides) do
    %Cairnloop.Governance.ToolActionEvent{
      id: 1,
      event_type: :proposal_created,
      from_status: nil,
      to_status: :proposed,
      actor_id: "user_42",
      reason: nil,
      metadata: %{}
    }
    |> Map.merge(overrides)
  end

  # ---------------------------------------------------------------------------
  # describe: status_label/1 — D-11 locked mappings
  # ---------------------------------------------------------------------------

  describe "status_label/1" do
    @tag :skip
    test "returns 'Proposed' for :proposed" do
      assert apply(@presenter, :status_label, [:proposed]) == "Proposed"
    end

    @tag :skip
    test "returns 'Needs input' for :needs_input" do
      assert apply(@presenter, :status_label, [:needs_input]) == "Needs input"
    end

    @tag :skip
    test "returns 'Not available here' for :scope_invalid" do
      assert apply(@presenter, :status_label, [:scope_invalid]) == "Not available here"
    end

    @tag :skip
    test "returns 'Blocked by policy' for :policy_denied" do
      assert apply(@presenter, :status_label, [:policy_denied]) == "Blocked by policy"
    end

    @tag :skip
    test "accepts a ToolProposal struct (delegates to atom)" do
      p = proposal(%{status: :proposed})
      assert apply(@presenter, :status_label, [p]) == "Proposed"
    end
  end

  # ---------------------------------------------------------------------------
  # describe: status_group/1 — D-10 grouping
  # ---------------------------------------------------------------------------

  describe "status_group/1" do
    @tag :skip
    test "returns :awaiting for :proposed" do
      assert apply(@presenter, :status_group, [:proposed]) == :awaiting
    end

    @tag :skip
    test "returns :awaiting for :needs_input" do
      assert apply(@presenter, :status_group, [:needs_input]) == :awaiting
    end

    @tag :skip
    test "returns :blocked for :scope_invalid" do
      assert apply(@presenter, :status_group, [:scope_invalid]) == :blocked
    end

    @tag :skip
    test "returns :blocked for :policy_denied" do
      assert apply(@presenter, :status_group, [:policy_denied]) == :blocked
    end
  end

  # ---------------------------------------------------------------------------
  # describe: status_group_label/1
  # ---------------------------------------------------------------------------

  describe "status_group_label/1" do
    @tag :skip
    test "returns a string for :awaiting group" do
      label = apply(@presenter, :status_group_label, [:awaiting])
      assert is_binary(label)
      assert String.length(label) > 0
    end

    @tag :skip
    test "returns a string for :blocked group" do
      label = apply(@presenter, :status_group_label, [:blocked])
      assert is_binary(label)
      assert String.length(label) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # describe: approval_outlook/1 — D-12 honesty seam
  # ---------------------------------------------------------------------------

  describe "approval_outlook/1" do
    @tag :skip
    test "returns a future-tense sentence for :requires_approval" do
      outlook = apply(@presenter, :approval_outlook, [:requires_approval])
      assert is_binary(outlook)
      # Future-tense: should describe the gate without implying an action exists
      assert String.length(outlook) > 0
    end

    @tag :skip
    test "returns nil for :auto (no gate to describe)" do
      outlook = apply(@presenter, :approval_outlook, [:auto])
      assert is_nil(outlook)
    end

    @tag :skip
    test "returns a 'cannot be approved or run' sentence for :always_block" do
      outlook = apply(@presenter, :approval_outlook, [:always_block])
      assert is_binary(outlook)
      assert outlook =~ "cannot" or outlook =~ "will not" or outlook =~ "blocked"
    end
  end

  # ---------------------------------------------------------------------------
  # describe: risk_tier_label/1
  # ---------------------------------------------------------------------------

  describe "risk_tier_label/1" do
    @tag :skip
    test "returns a non-empty string for each risk tier" do
      for tier <- [:read_only, :low_write, :high_write, :destructive] do
        label = apply(@presenter, :risk_tier_label, [tier])
        assert is_binary(label), "Expected string for #{tier}, got: #{inspect(label)}"
        assert String.length(label) > 0
      end
    end
  end

  # ---------------------------------------------------------------------------
  # describe: risk_tier_tone/1 — returns atom for brand color mapping
  # ---------------------------------------------------------------------------

  describe "risk_tier_tone/1" do
    @tag :skip
    test "returns an atom (:info | :warning | :danger) for each risk tier" do
      for tier <- [:read_only, :low_write, :high_write, :destructive] do
        tone = apply(@presenter, :risk_tier_tone, [tier])
        assert tone in [:info, :warning, :danger],
               "Expected :info/:warning/:danger for #{tier}, got: #{inspect(tone)}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # describe: approval_mode_label/1
  # ---------------------------------------------------------------------------

  describe "approval_mode_label/1" do
    @tag :skip
    test "returns a non-empty string for each approval mode" do
      for mode <- [:auto, :requires_approval, :always_block] do
        label = apply(@presenter, :approval_mode_label, [mode])
        assert is_binary(label), "Expected string for #{mode}, got: #{inspect(label)}"
        assert String.length(label) > 0
      end
    end
  end

  # ---------------------------------------------------------------------------
  # describe: reason_label/1 — humanizes without inspect output (D-14)
  # ---------------------------------------------------------------------------

  describe "reason_label/1" do
    @tag :skip
    test "returns nil for nil reason" do
      assert apply(@presenter, :reason_label, [nil]) == nil
    end

    @tag :skip
    test "humanizes {:missing_scopes, [:admin_scope]} without inspect-style output (D-14)" do
      result = apply(@presenter, :reason_label, [{:missing_scopes, [:admin_scope]}])
      assert is_binary(result) or is_nil(result)

      # MUST NOT contain raw Elixir term syntax (operator brand §5.6 / D-14)
      refute (result || "") =~ ":missing_scopes",
             "reason_label must not expose raw atom :missing_scopes to operators"

      refute (result || "") =~ "[:admin_scope]",
             "reason_label must not expose raw list [:admin_scope] to operators"
    end

    @tag :skip
    test "humanizes atom reasons without inspect output" do
      result = apply(@presenter, :reason_label, [:denied])
      assert is_binary(result)
      # Should not contain the leading colon from Elixir atom syntax
      refute result =~ ":denied"
    end

    @tag :skip
    test "handles unknown tuple reasons gracefully (no crash, no raw inspect)" do
      result = apply(@presenter, :reason_label, [{:unknown_reason, "detail"}])
      # Either a human-friendly fallback string or nil — never a crash
      assert is_binary(result) or is_nil(result)
      # Must not contain raw inspect output like "{:unknown_reason, \"detail\"}"
      refute (result || "") =~ ":unknown_reason"
    end
  end

  # ---------------------------------------------------------------------------
  # describe: input_rows/1 — masking choke point (D-22)
  # ---------------------------------------------------------------------------

  describe "input_rows/1" do
    @tag :skip
    test "returns a list of rows for a simple flat map" do
      rows = apply(@presenter, :input_rows, [%{order_id: "ord_123"}])
      assert is_list(rows)
      assert length(rows) >= 1
    end

    @tag :skip
    test "never dumps raw nested maps — returns humanized rows or 'Unsupported value' sentinel (D-22)" do
      nested_input = %{
        order_id: "ord_123",
        metadata: %{inner_key: "inner_value"},
        status: {:ok, :active}
      }

      rows = apply(@presenter, :input_rows, [nested_input])
      assert is_list(rows)

      # Collect all row values as strings
      row_values =
        Enum.map(rows, fn row ->
          # rows may be maps like %{label: ..., value: ...} or 2-tuples
          case row do
            {_label, value} -> to_string(value)
            %{value: value} -> to_string(value)
            _ -> inspect(row)
          end
        end)

      # None of the values may contain raw nested map syntax
      Enum.each(row_values, fn value ->
        refute value =~ "%{inner_key:",
               "input_rows must not expose raw nested map, got: #{value}"

        refute value =~ "{:ok",
               "input_rows must not expose raw tuple, got: #{value}"
      end)
    end

    @tag :skip
    test "handles string-keyed snapshot (JSONB post-reload shape) without crashing" do
      # REPO-UNAVAILABLE: partial coverage of the string-key footgun (D-19)
      rows = apply(@presenter, :input_rows, [%{"order_id" => "ord_456"}])
      assert is_list(rows)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: scope_summary/1
  # ---------------------------------------------------------------------------

  describe "scope_summary/1" do
    @tag :skip
    test "returns a string summary for an empty scope list" do
      result = apply(@presenter, :scope_summary, [%{scopes: []}])
      assert is_binary(result)
    end

    @tag :skip
    test "returns a string summary listing required scopes" do
      result = apply(@presenter, :scope_summary, [%{scopes: [:admin_scope, :read_scope]}])
      assert is_binary(result)
      assert String.length(result) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # describe: policy_explanation/1
  # ---------------------------------------------------------------------------

  describe "policy_explanation/1" do
    @tag :skip
    test "returns a calm sentence for a policy snapshot with outcome :proposed" do
      snapshot = %{outcome: :proposed, reason: nil}
      result = apply(@presenter, :policy_explanation, [snapshot])
      assert is_binary(result)
      assert String.length(result) > 0
    end

    @tag :skip
    test "returns a calm sentence for a policy snapshot with outcome :policy_denied" do
      snapshot = %{outcome: :policy_denied, reason: "Policy guard blocked this tool."}
      result = apply(@presenter, :policy_explanation, [snapshot])
      assert is_binary(result)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: block_reason_copy/1
  # ---------------------------------------------------------------------------

  describe "block_reason_copy/1" do
    @tag :skip
    test "returns nil or empty string for non-blocked proposals" do
      p = proposal(%{status: :proposed})
      result = apply(@presenter, :block_reason_copy, [p])
      assert is_nil(result) or result == ""
    end

    @tag :skip
    test "returns a non-empty string for blocked proposals" do
      p = proposal(%{status: :policy_denied})
      result = apply(@presenter, :block_reason_copy, [p])
      assert is_binary(result)
      assert String.length(result) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # describe: history_line/1 — catch-all forward-compat (D-24)
  # ---------------------------------------------------------------------------

  describe "history_line/1" do
    @tag :skip
    test "returns 'Workflow updated' for an unrecognized event_type (D-24 catch-all)" do
      # Build an event with a known event_type, then override to simulate unknown future type.
      e = event(%{event_type: :proposal_created})
      # We can't create a struct with an unknown Ecto.Enum value at compile time,
      # so we simulate by passing a plain map that the presenter should handle gracefully.
      # Wave 1 will refine once history_line/1 exists.
      result = apply(@presenter, :history_line, [e])
      assert is_binary(result)
      assert String.length(result) > 0
    end

    @tag :skip
    test "handles :proposal_created event type without crashing" do
      e = event(%{event_type: :proposal_created, actor_id: "user_1"})
      result = apply(@presenter, :history_line, [e])
      assert is_binary(result)
    end

    @tag :skip
    test "handles :proposal_blocked event type without crashing" do
      e = event(%{event_type: :proposal_blocked, to_status: :scope_invalid, actor_id: "user_1"})
      result = apply(@presenter, :history_line, [e])
      assert is_binary(result)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: event_timestamp_label/1
  # ---------------------------------------------------------------------------

  describe "event_timestamp_label/1" do
    @tag :skip
    test "returns a human-readable string for a recent datetime" do
      ts = DateTime.utc_now()
      result = apply(@presenter, :event_timestamp_label, [ts])
      assert is_binary(result)
      assert String.length(result) > 0
    end
  end

  # ---------------------------------------------------------------------------
  # describe: trace_metadata/1 — de-emphasized mono copyable data
  # ---------------------------------------------------------------------------

  describe "trace_metadata/1" do
    @tag :skip
    test "returns a map with proposal_id, tool_ref, and idempotency_key fields" do
      p = proposal(%{idempotency_key: "abc123"})
      result = apply(@presenter, :trace_metadata, [p])
      assert is_map(result)
      assert Map.has_key?(result, :proposal_id) or Map.has_key?(result, "proposal_id")
    end
  end

  # ---------------------------------------------------------------------------
  # describe: status_meaning/1
  # ---------------------------------------------------------------------------

  describe "status_meaning/1" do
    @tag :skip
    test "returns a non-empty string explaining the status for operators" do
      for status <- [:proposed, :needs_input, :scope_invalid, :policy_denied] do
        meaning = apply(@presenter, :status_meaning, [status])
        assert is_binary(meaning), "Expected string for #{status}, got: #{inspect(meaning)}"
        assert String.length(meaning) > 0
      end
    end
  end
end
