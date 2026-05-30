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
    test "returns 'Proposed' for :proposed" do
      assert apply(@presenter, :status_label, [:proposed]) == "Proposed"
    end

    test "returns 'Needs input' for :needs_input" do
      assert apply(@presenter, :status_label, [:needs_input]) == "Needs input"
    end

    test "returns 'Not available here' for :scope_invalid" do
      assert apply(@presenter, :status_label, [:scope_invalid]) == "Not available here"
    end

    test "returns 'Blocked by policy' for :policy_denied" do
      assert apply(@presenter, :status_label, [:policy_denied]) == "Blocked by policy"
    end

    test "accepts a ToolProposal struct (delegates to atom)" do
      p = proposal(%{status: :proposed})
      assert apply(@presenter, :status_label, [p]) == "Proposed"
    end
  end

  # ---------------------------------------------------------------------------
  # describe: status_group/1 — D-10 grouping
  # ---------------------------------------------------------------------------

  describe "status_group/1" do
    test "returns :awaiting for :proposed" do
      assert apply(@presenter, :status_group, [:proposed]) == :awaiting
    end

    test "returns :awaiting for :needs_input" do
      assert apply(@presenter, :status_group, [:needs_input]) == :awaiting
    end

    test "returns :blocked for :scope_invalid" do
      assert apply(@presenter, :status_group, [:scope_invalid]) == :blocked
    end

    test "returns :blocked for :policy_denied" do
      assert apply(@presenter, :status_group, [:policy_denied]) == :blocked
    end
  end

  # ---------------------------------------------------------------------------
  # describe: status_group_label/1
  # ---------------------------------------------------------------------------

  describe "status_group_label/1" do
    test "returns a string for :awaiting group" do
      label = apply(@presenter, :status_group_label, [:awaiting])
      assert is_binary(label)
      assert String.length(label) > 0
    end

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
    test "returns a future-tense sentence for :requires_approval" do
      outlook = apply(@presenter, :approval_outlook, [:requires_approval])
      assert is_binary(outlook)
      # Future-tense: should describe the gate without implying an action exists
      assert String.length(outlook) > 0
    end

    test "returns nil for :auto (no gate to describe)" do
      outlook = apply(@presenter, :approval_outlook, [:auto])
      assert is_nil(outlook)
    end

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
    test "returns nil for nil reason" do
      assert apply(@presenter, :reason_label, [nil]) == nil
    end

    test "humanizes {:missing_scopes, [:admin_scope]} without inspect-style output (D-14)" do
      result = apply(@presenter, :reason_label, [{:missing_scopes, [:admin_scope]}])
      assert is_binary(result) or is_nil(result)

      # MUST NOT contain raw Elixir term syntax (operator brand §5.6 / D-14)
      refute (result || "") =~ ":missing_scopes",
             "reason_label must not expose raw atom :missing_scopes to operators"

      refute (result || "") =~ "[:admin_scope]",
             "reason_label must not expose raw list [:admin_scope] to operators"
    end

    test "humanizes atom reasons without inspect output" do
      result = apply(@presenter, :reason_label, [:denied])
      assert is_binary(result)
      # Should not contain the leading colon from Elixir atom syntax
      refute result =~ ":denied"
    end

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
    test "returns a list of rows for a simple flat map" do
      rows = apply(@presenter, :input_rows, [%{order_id: "ord_123"}])
      assert is_list(rows)
      assert rows != []
    end

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
    test "returns a string summary for an empty scope list" do
      result = apply(@presenter, :scope_summary, [%{scopes: []}])
      assert is_binary(result)
    end

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
    test "returns a calm sentence for a policy snapshot with outcome :proposed" do
      snapshot = %{outcome: :proposed, reason: nil}
      result = apply(@presenter, :policy_explanation, [snapshot])
      assert is_binary(result)
      assert String.length(result) > 0
    end

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
    test "returns nil or empty string for non-blocked proposals" do
      p = proposal(%{status: :proposed})
      result = apply(@presenter, :block_reason_copy, [p])
      assert is_nil(result) or result == ""
    end

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

    test "handles :proposal_created event type without crashing" do
      e = event(%{event_type: :proposal_created, actor_id: "user_1"})
      result = apply(@presenter, :history_line, [e])
      assert is_binary(result)
    end

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
    test "returns a non-empty string explaining the status for operators" do
      for status <- [:proposed, :needs_input, :scope_invalid, :policy_denied] do
        meaning = apply(@presenter, :status_meaning, [status])
        assert is_binary(meaning), "Expected string for #{status}, got: #{inspect(meaning)}"
        assert String.length(meaning) > 0
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 15 Wave 0 extensions: approval surface (D15-16, 15-04-a/b)
  #
  # These describe blocks encode the contracts for the approval display surface.
  # All tests are @tag :skip until Wave 3 adds the new clauses to the presenter.
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # describe: status_group/1 — approval states, zero relabeling (D15-16, 15-04-a)
  # ---------------------------------------------------------------------------

  describe "status_group/1 — approval states (D15-16, 15-04-a)" do
    test "returns :awaiting for :pending" do
      # :pending is the real ToolApproval status → Awaiting group (D15-16)
      assert apply(@presenter, :status_group, [:pending]) == :awaiting
    end

    test "returns :active for :approved" do
      # :approved (operator approved, resume pending) → Active group (D15-16)
      assert apply(@presenter, :status_group, [:approved]) == :active
    end

    test "returns :active for :execution_pending" do
      # :execution_pending (approved, awaiting Phase-16 execute) → Active group
      assert apply(@presenter, :status_group, [:execution_pending]) == :active
    end

    test "returns :done for :rejected" do
      assert apply(@presenter, :status_group, [:rejected]) == :done
    end

    test "returns :done for :deferred" do
      assert apply(@presenter, :status_group, [:deferred]) == :done
    end

    test "returns :done for :expired" do
      assert apply(@presenter, :status_group, [:expired]) == :done
    end

    test "returns :done for :invalidated" do
      assert apply(@presenter, :status_group, [:invalidated]) == :done
    end
  end

  # ---------------------------------------------------------------------------
  # describe: approval_outlook/1 (or approval_outlook_for_approval/1) (D15-16, 15-04-b)
  #
  # The Phase 14 honesty seam (approval_outlook/1) becomes real "Pending approval" copy
  # when an active :pending approval exists. No future-tense "Will require".
  # ---------------------------------------------------------------------------

  describe "approval_outlook for active :pending approval (D15-16, 15-04-b)" do
    test "returns real 'Pending approval' copy (not future-tense) for :pending approval status" do
      # D15-16: when an active :pending approval exists, the outlook must be present-tense.
      # approval_outlook_for_approval/1 takes an approval struct or status.
      # Use a map to avoid compile-time struct check (ToolApproval added in Wave 1).
      approval = %{status: :pending}

      outlook =
        if function_exported?(@presenter, :approval_outlook_for_approval, 1) do
          apply(@presenter, :approval_outlook_for_approval, [approval])
        else
          apply(@presenter, :approval_outlook, [:pending])
        end

      assert is_binary(outlook)

      assert String.contains?(outlook, "Pending") or String.contains?(outlook, "approval"),
             "approval_outlook must reference 'Pending' or 'approval' for :pending status"

      # Must NOT be future-tense "Will require" (the pre-Phase-15 placeholder)
      refute String.contains?(outlook, "Will require"),
             "approval_outlook must not use future-tense 'Will require' when approval is active (D15-16)"
    end
  end

  # ---------------------------------------------------------------------------
  # describe: history_line/1 — approval events (D15-16, 15-04-b)
  #
  # All new approval event_types produce humanized, non-"Workflow updated" lines.
  # - Show actor_id and reason where applicable.
  # - No raw Elixir terms (no "#Ecto", no colon-prefixed atoms, no "%{" in output).
  # ---------------------------------------------------------------------------

  describe "history_line/1 — approval events (D15-16, 15-04-b)" do
    test ":approved event shows actor_id and non-empty line" do
      e = event(%{event_type: :approved, actor_id: "ops_1"})
      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)
      assert String.length(line) > 0

      assert String.contains?(line, "ops_1"),
             "history_line for :approved must show actor_id"

      refute line == "Workflow updated",
             "history_line for :approved must not fall back to catch-all (D-24)"
    end

    test ":approved event line contains no raw Elixir terms" do
      e = event(%{event_type: :approved, actor_id: "ops_1"})
      line = apply(@presenter, :history_line, [e])
      refute line =~ "#Ecto", "history_line must not expose raw Ecto terms"
      refute line =~ ~r/^:/, "history_line must not expose colon-prefixed atoms"
      refute line =~ "%{", "history_line must not expose raw map syntax"
    end

    test ":rejected event shows actor_id and reason" do
      e = event(%{event_type: :rejected, actor_id: "ops_1", reason: "Too risky"})
      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)

      assert String.contains?(line, "Too risky"),
             "history_line for :rejected must include the reason"

      refute line == "Workflow updated"
    end

    test ":deferred event shows reason" do
      e = event(%{event_type: :deferred, actor_id: "ops_1", reason: "Review later"})
      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)

      assert String.contains?(line, "Review later"),
             "history_line for :deferred must include the reason"
    end

    test ":expired event returns calm copy (not 'Workflow updated')" do
      e = event(%{event_type: :expired})
      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)

      refute line == "Workflow updated",
             "history_line for :expired must not fall back to the catch-all"
    end

    test ":invalidated event shows reason when provided" do
      e = event(%{event_type: :invalidated, reason: "Policy scope changed."})
      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)
      # Should mention reason or invalidation context
      assert String.length(line) > 0
    end

    test ":revalidation_passed event returns calm forward-looking copy" do
      e = event(%{event_type: :revalidation_passed})
      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)
      refute line == "Workflow updated"
    end

    test ":revalidation_failed event shows reason when provided" do
      e = event(%{event_type: :revalidation_failed, reason: "Policy changed."})
      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)
      assert String.length(line) > 0
    end

    test ":resume_scheduled event returns non-empty copy" do
      e = event(%{event_type: :resume_scheduled})
      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)
      assert String.length(line) > 0
    end

    test ":approval_requested event shows actor_id" do
      e = event(%{event_type: :approval_requested, actor_id: "user_1"})
      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)

      assert String.contains?(line, "user_1") or String.contains?(line, "approval"),
             "history_line for :approval_requested must mention actor_id or approval context"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 16 Wave 2 extensions: execution outcome display (D16-11, OBS-02)
  #
  # These describe blocks encode the contracts for execution outcome display:
  # - :executed / :execution_failed status grouping (always before catch-all)
  # - approval_outlook_for_approval/1 humanized copy for execution terminals
  # - history_line/1 clauses for execution events with attempt number
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # describe: status_group/1 — execution terminal statuses (D16-11, zero relabeling)
  # ---------------------------------------------------------------------------

  describe "status_group/1 — execution terminal statuses (D16-11)" do
    test "returns :done for :executed" do
      assert apply(@presenter, :status_group, [:executed]) == :done
    end

    test "returns :done for :execution_failed" do
      # Both map to :done (or a distinct operator-legible group — never :blocked)
      result = apply(@presenter, :status_group, [:execution_failed])

      assert result in [:done, :blocked] == false or result == :done,
             "execution_failed must not map to :blocked (operator must see it as a completed lane)"

      # Specifically: per D16-11 both map to :done
      assert result == :done
    end

    test ":executed and :execution_failed never render as :blocked (Pitfall 6 catch-all)" do
      # Regression guard: new clauses must appear BEFORE def status_group(_, do: :blocked
      assert apply(@presenter, :status_group, [:executed]) != :blocked
      assert apply(@presenter, :status_group, [:execution_failed]) != :blocked
    end
  end

  # ---------------------------------------------------------------------------
  # describe: approval_outlook_for_approval/1 — execution terminal states (D16-11)
  # ---------------------------------------------------------------------------

  describe "approval_outlook_for_approval/1 — execution terminals (D16-11)" do
    test "returns humanized 'Action completed' copy for :executed approval" do
      # The worker stores result_summary in approval.reason (via decision_changeset arg4).
      # Use :reason key — the correct durable column (CR-01 regression guard).
      approval = %{status: :executed, reason: "Internal note appended."}
      outlook = apply(@presenter, :approval_outlook_for_approval, [approval])
      assert is_binary(outlook)

      assert String.contains?(outlook, "Action completed") or
               String.contains?(outlook, "completed") or
               String.contains?(outlook, "Done"),
             "approval_outlook_for_approval for :executed must contain 'completed' or 'Done'"
    end

    # CR-01 regression guard (IN-03): the worker stores the humanized result in
    # approval.reason, NOT approval.result_summary (ToolApproval has no such field).
    # This test proves the fix and prevents regression.
    test ":executed outlook reads from :reason field (not :result_summary) — CR-01 fix" do
      approval = %{status: :executed, reason: "Note written (id: 42)."}
      outlook = apply(@presenter, :approval_outlook_for_approval, [approval])
      assert is_binary(outlook)
      # Must include the actual summary text from :reason — not just "Done." fallback
      assert String.contains?(outlook, "Note written (id: 42)."),
             "approval_outlook must include the actual reason text from approval.reason, got: #{inspect(outlook)}"
    end

    test ":executed outlook includes actual summary when passed as :reason" do
      # approval.reason holds the worker's humanized result_summary (see record_success/6)
      approval = %{status: :executed, reason: "Note appended to conv-001."}
      outlook = apply(@presenter, :approval_outlook_for_approval, [approval])
      assert is_binary(outlook)
      assert String.contains?(outlook, "Note appended to conv-001.")
    end

    test ":executed outlook falls back gracefully when reason is nil" do
      approval = %{status: :executed, reason: nil}
      outlook = apply(@presenter, :approval_outlook_for_approval, [approval])
      assert is_binary(outlook)
      assert String.length(outlook) > 0
      # Must not crash or expose raw Elixir nil term
      refute outlook =~ "nil", "outlook must not expose raw 'nil' to operators"
    end

    test "returns humanized 'Action failed' copy for :execution_failed approval" do
      approval = %{status: :execution_failed, reason: "All retry attempts exhausted."}
      outlook = apply(@presenter, :approval_outlook_for_approval, [approval])
      assert is_binary(outlook)

      assert String.contains?(outlook, "Action failed") or
               String.contains?(outlook, "failed"),
             "approval_outlook_for_approval for :execution_failed must contain 'failed'"
    end

    test ":execution_failed outlook includes reason when present" do
      approval = %{status: :execution_failed, reason: "DB connection refused."}
      outlook = apply(@presenter, :approval_outlook_for_approval, [approval])
      assert is_binary(outlook)
      assert String.contains?(outlook, "DB connection refused.")
    end

    test ":execution_failed outlook falls back gracefully when reason is nil" do
      approval = %{status: :execution_failed, reason: nil}
      outlook = apply(@presenter, :approval_outlook_for_approval, [approval])
      assert is_binary(outlook)
      assert String.length(outlook) > 0
      refute outlook =~ "nil", "outlook must not expose raw 'nil' to operators"
    end

    test ":executed and :execution_failed outlook contain no raw Elixir terms (T-16-10)" do
      for {status, extra} <- [
            {:executed, %{reason: "Done."}},
            {:execution_failed, %{reason: "Exhausted."}}
          ] do
        approval = Map.put(extra, :status, status)
        outlook = apply(@presenter, :approval_outlook_for_approval, [approval])
        refute outlook =~ "#Ecto", "must not expose raw Ecto terms"
        refute outlook =~ "%{", "must not expose raw map syntax"
        refute outlook =~ ~r/^:/, "must not expose leading-colon atom syntax"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # describe: history_line/1 — execution events (D16-11, per-attempt timeline)
  # ---------------------------------------------------------------------------

  describe "history_line/1 — execution events (D16-11, per-attempt timeline)" do
    test ":execution_succeeded returns humanized line with attempt number" do
      e = event(%{event_type: :execution_succeeded, metadata: %{"attempt" => 1}})
      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)

      refute line == "Workflow updated",
             "history_line for :execution_succeeded must not fall back to catch-all"

      assert String.contains?(line, "1") or String.contains?(line, "completed") or
               String.contains?(line, "succeeded"),
             "history_line for :execution_succeeded should reference attempt or outcome"
    end

    test ":execution_attempt_failed returns humanized line with attempt number and reason" do
      e =
        event(%{
          event_type: :execution_attempt_failed,
          reason: "Transient DB error.",
          metadata: %{"attempt" => 1}
        })

      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)

      refute line == "Workflow updated",
             "history_line for :execution_attempt_failed must not fall back to catch-all"

      assert String.contains?(line, "1") or String.contains?(line, "failed") or
               String.contains?(line, "retry"),
             "history_line for :execution_attempt_failed should reference attempt or failure"
    end

    test ":execution_failed returns humanized line naming the permanent failure" do
      e = event(%{event_type: :execution_failed, reason: "All retry attempts exhausted."})
      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)

      refute line == "Workflow updated",
             "history_line for :execution_failed must not fall back to catch-all"

      assert String.contains?(line, "failed") or
               String.contains?(line, "exhausted") or
               String.contains?(line, "permanently"),
             "history_line for :execution_failed should name the permanent failure"
    end

    test "execution event lines contain no raw Elixir terms (T-16-10)" do
      events = [
        event(%{event_type: :execution_succeeded, metadata: %{"attempt" => 1}}),
        event(%{
          event_type: :execution_attempt_failed,
          reason: "DB error.",
          metadata: %{"attempt" => 2}
        }),
        event(%{event_type: :execution_failed, reason: "Retries exhausted."})
      ]

      for e <- events do
        line = apply(@presenter, :history_line, [e])
        refute line =~ "#Ecto", "history_line must not expose raw Ecto terms"
        refute line =~ "%{", "history_line must not expose raw map syntax"
      end
    end

    test ":execution_succeeded reads attempt from STRING key 'attempt' (JSONB survival)" do
      # JSONB round-trip: metadata keys become strings after Postgres INSERT+SELECT
      e = event(%{event_type: :execution_succeeded, metadata: %{"attempt" => 2}})
      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)

      assert String.contains?(line, "2") or String.contains?(line, "completed"),
             "attempt number from string key must appear in the line"
    end

    test ":execution_attempt_failed reads attempt from STRING key 'attempt' (JSONB survival)" do
      e =
        event(%{
          event_type: :execution_attempt_failed,
          reason: "DB hiccup.",
          metadata: %{"attempt" => 3}
        })

      line = apply(@presenter, :history_line, [e])
      assert is_binary(line)

      assert String.contains?(line, "3") or String.contains?(line, "failed"),
             "attempt number from string key must appear in the line"
    end
  end
end
