defmodule Cairnloop.Web.AuditLogPresenterTest do
  use ExUnit.Case, async: true

  alias Cairnloop.Web.AuditLogPresenter, as: P

  describe "action_label/1" do
    test "humanizes known governance event types" do
      assert P.action_label(:proposal_created) == "Action proposed"
      assert P.action_label(:approved) == "Approved"
      assert P.action_label(:execution_succeeded) == "Executed"
      assert P.action_label(:execution_failed) == "Execution failed"
    end

    test "humanizes unknown atoms and strings without raw inspect" do
      assert P.action_label(:some_custom_event) == "Some custom event"
      assert P.action_label("host_logged_in") == "Host logged in"
    end

    test "is total for nil and unexpected input" do
      assert P.action_label(nil) == "Unknown action"
      assert P.action_label("") == "Unknown action"
      assert P.action_label(123) == "Unknown action"
    end
  end

  describe "actor_label/1" do
    test "passes through a binary actor" do
      assert P.actor_label("user_42") == "user_42"
    end

    test "renders system/automated actions as System" do
      assert P.actor_label(nil) == "System"
      assert P.actor_label("") == "System"
    end
  end

  describe "timestamp_label/1" do
    test "formats a DateTime as a calm UTC string" do
      assert P.timestamp_label(~U[2024-01-02 09:30:00Z]) == "2024-01-02 09:30:00 UTC"
    end

    test "is total for unexpected input" do
      assert P.timestamp_label(nil) == "—"
      assert P.timestamp_label("nope") == "—"
    end
  end

  describe "reason_label/1" do
    test "passes through a non-blank reason and dashes otherwise" do
      assert P.reason_label("manual override") == "manual override"
      assert P.reason_label(nil) == "—"
      assert P.reason_label("") == "—"
    end
  end

  describe "metadata_rows/1" do
    test "produces humanized, sorted scalar rows" do
      rows = P.metadata_rows(%{proposal_id: 1, tool: "refund", dry_run: true})

      assert {"Dry run", "Yes"} in rows
      assert {"Proposal id", "1"} in rows
      assert {"Tool", "refund"} in rows
      # sorted by label
      assert rows == Enum.sort_by(rows, fn {label, _} -> label end)
    end

    test "summarizes nested values instead of leaking raw terms" do
      rows = P.metadata_rows(%{payload: %{a: 1}})
      assert {"Payload", "(structured value)"} in rows
    end

    test "is empty for non-maps and empty maps" do
      assert P.metadata_rows(%{}) == []
      assert P.metadata_rows(nil) == []
    end
  end

  describe "matches?/2" do
    setup do
      %{
        event: %{
          inserted_at: ~U[2024-01-02 09:30:00Z],
          actor_id: "agent_smith",
          action: :execution_succeeded,
          reason: "approved by supervisor",
          metadata: %{tool: "refund"}
        }
      }
    end

    test "a blank query matches everything", %{event: event} do
      assert P.matches?(event, "")
      assert P.matches?(event, nil)
    end

    test "matches on actor, humanized action, reason, and metadata (case-insensitive)", %{
      event: event
    } do
      assert P.matches?(event, "smith")
      assert P.matches?(event, "executed")
      assert P.matches?(event, "supervisor")
      assert P.matches?(event, "refund")
      assert P.matches?(event, "REFUND")
    end

    test "does not match an unrelated query", %{event: event} do
      refute P.matches?(event, "nonexistent-token")
    end
  end
end
