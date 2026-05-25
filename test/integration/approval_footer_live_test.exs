defmodule Cairnloop.Integration.ApprovalFooterLiveTest do
  @moduledoc """
  Integration coverage for Phase 15 manual item 4 (FLOW-03 / D15-14): the ConversationLive
  approval footer, mounted for real via Phoenix.LiveViewTest against a real Postgres-backed
  conversation.

  Asserts the decisive, automatable behavior:
  - The footer renders Approve/Reject/Defer with BOTH a text label AND the brand color token
    (discharges brand §7.5 never-color-alone as a correctness check).
  - The snapshot card shows the propose-time title + rendered_consequence (D15-14).
  - Reject/Defer with a blank reason persists NOTHING and keeps the lane :pending (FLOW-03).
  - Reject with a reason persists :rejected (+ event) and the footer affordances disappear.

  (The exact calm-error flash copy is covered by the headless conversation_live_test.exs,
  which inspects socket.assigns.flash directly; ConversationLive does not render @flash.)
  """
  use Cairnloop.ConnCase, async: false

  alias Cairnloop.Governance
  alias Cairnloop.Governance.ToolApproval

  import Cairnloop.Fixtures

  defmodule StubContextProvider do
    def get_context(_host_user_id, _opts), do: {:ok, %{}}
  end

  setup %{conn: conn} do
    Application.put_env(:cairnloop, :context_provider, StubContextProvider)
    on_exit(fn -> Application.delete_env(:cairnloop, :context_provider) end)

    conversation = conversation_fixture(%{host_user_id: "operator_42"})

    # title nil + rendered_consequence set exercises the {:preview, prose} snapshot path —
    # the live-prose value the card must read from the column, never re-render (D15-14).
    proposal =
      proposal_fixture(%{
        conversation_id: conversation.id,
        approval_mode: :requires_approval,
        rendered_consequence: "This will refund $42.00 to the customer."
      })

    approval = approval_fixture(proposal, %{status: :pending})

    %{conn: conn, conversation: conversation, proposal: proposal, approval: approval}
  end

  test "footer renders Approve/Reject/Defer with a text label AND the brand color token", ctx do
    {:ok, view, html} = live(ctx.conn, "/governance/#{ctx.conversation.id}")

    # never-color-alone (brand §7.5): the affordance carries BOTH a text label and the token.
    assert html =~ "var(--cl-primary, #A94F30)"
    assert has_element?(view, "button[phx-click='approve_action']")
    assert has_element?(view, "form[phx-submit='reject_action']")
    assert has_element?(view, "form[phx-submit='defer_action']")
    assert html =~ "Approve"
    assert html =~ "Reject"
    assert html =~ "Defer"
  end

  test "snapshot card shows the propose-time rendered_consequence prose (D15-14)", ctx do
    {:ok, _view, html} = live(ctx.conn, "/governance/#{ctx.conversation.id}")

    # The card reads the snapshotted prose column, never a live Preview.render/1.
    assert html =~ "This will refund $42.00 to the customer."
  end

  test "rejecting with a blank reason persists nothing and keeps the lane :pending (FLOW-03)",
       ctx do
    {:ok, view, _html} = live(ctx.conn, "/governance/#{ctx.conversation.id}")

    view
    |> element("form[phx-submit='reject_action']")
    |> render_submit(%{"reason" => ""})

    assert Repo.get!(ToolApproval, ctx.approval.id).status == :pending
    refute Enum.any?(Governance.list_events(ctx.proposal.id), &(&1.event_type == :rejected))
  end

  test "deferring with a blank reason persists nothing and keeps the lane :pending (FLOW-03)",
       ctx do
    {:ok, view, _html} = live(ctx.conn, "/governance/#{ctx.conversation.id}")

    view
    |> element("form[phx-submit='defer_action']")
    |> render_submit(%{"reason" => ""})

    assert Repo.get!(ToolApproval, ctx.approval.id).status == :pending
    refute Enum.any?(Governance.list_events(ctx.proposal.id), &(&1.event_type == :deferred))
  end

  test "rejecting with a reason persists :rejected and removes the footer affordances", ctx do
    {:ok, view, _html} = live(ctx.conn, "/governance/#{ctx.conversation.id}")

    view
    |> element("form[phx-submit='reject_action']")
    |> render_submit(%{"reason" => "Not authorized for this customer."})

    reloaded = Repo.get!(ToolApproval, ctx.approval.id)
    assert reloaded.status == :rejected
    assert reloaded.reason == "Not authorized for this customer."

    event = Enum.find(Governance.list_events(ctx.proposal.id), &(&1.event_type == :rejected))
    assert event
    assert event.reason == "Not authorized for this customer."

    # plain-assign reload (no streams): the :pending-only footer affordances are gone.
    refute has_element?(view, "form[phx-submit='reject_action']")
  end
end
