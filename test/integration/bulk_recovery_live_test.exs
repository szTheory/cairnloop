defmodule Cairnloop.Integration.BulkRecoveryLiveTest do
  @moduledoc """
  Integration coverage for Phase 25 human-verification item 3 (Plan 25-03 Task 3):
  the bulk-recovery cockpit in `Cairnloop.Web.InboxLive`, mounted for real via
  `Phoenix.LiveViewTest` against a real Postgres-backed inbox.

  Asserts the decisive, automatable behaviors that the operator UAT walked:

  - Only `:resolved` rows render a checkbox (D-01 / D-03).
  - Selecting rows surfaces the sticky bulk-action bar with the brand primary
    token (D-05 + brand §7.5 never-color-alone — text label AND token).
  - Opening the confirm modal renders the cohort sample, the rendered template
    body, the `<.focus_wrap>` markup (D-07 / D-08 focus-trap contract — the
    focus cycling itself is Phoenix's contract, asserted via component presence),
    and Cancel/Confirm affordances.
  - Pressing Escape closes the modal AND preserves the selection (D-08 /
    Pitfall 6).
  - Confirming routes through the real `Outbound.bulk_trigger/2`: flash fires,
    selection clears, and one `system_outbound` `Message` is appended per
    recipient (D-A — N cards, not a new card type), all carrying the envelope
    correlation key.
  - With `:cairnloop, :max_batch_size, 2`, an oversized cohort opens the modal
    in refusal mode: SVG icon + "Batch too large." heading + safe-limit copy +
    `var(--cl-danger)` accent + disabled Confirm (D-10 / brand §7.5).

  Focus-trap interior tab cycling is owned by Phoenix's `<.focus_wrap>`
  component (browser DOM contract — out of scope for LiveViewTest's headless
  renderer); asserting the component is in the markup is the right level for
  this surface.
  """
  use Cairnloop.ConnCase, async: false

  alias Cairnloop.Message
  alias Cairnloop.Outbound.BulkEnvelope

  # ConnCase does not import Ecto.Query (DataCase does — they're a single
  # `using do` block apart). Bring in the query macros so the `order_by`,
  # `limit`, and `where` calls in the persist-assertion blocks below compile.
  import Ecto.Query
  import Cairnloop.Fixtures

  @template_id "recovery_v1"

  setup %{conn: conn} do
    prior_template = Application.get_env(:cairnloop, :outbound_recovery_template_id)
    prior_batch = Application.get_env(:cairnloop, :max_batch_size)

    Application.put_env(:cairnloop, :outbound_recovery_template_id, @template_id)

    on_exit(fn ->
      if is_nil(prior_template) do
        Application.delete_env(:cairnloop, :outbound_recovery_template_id)
      else
        Application.put_env(:cairnloop, :outbound_recovery_template_id, prior_template)
      end

      if is_nil(prior_batch) do
        Application.delete_env(:cairnloop, :max_batch_size)
      else
        Application.put_env(:cairnloop, :max_batch_size, prior_batch)
      end
    end)

    conn = Plug.Test.init_test_session(conn, %{"host_user_id" => "operator_25"})

    %{conn: conn}
  end

  describe "happy path: select → confirm → fan-out (Plan 25-03 Task 3)" do
    test "resolved-only rows show a checkbox; open rows do not (D-01 / D-03)", %{conn: conn} do
      resolved = conversation_fixture(%{status: :resolved, subject: "Resolved row"})
      open = conversation_fixture(%{status: :open, subject: "Open row"})

      {:ok, _view, html} = live(conn, "/inbox")

      assert html =~ ~s(phx-value-id="#{resolved.id}")
      refute html =~ ~s(phx-value-id="#{open.id}")
    end

    test "selecting rows surfaces the sticky bar with brand primary token and N selected (D-05 / brand §7.5)",
         %{conn: conn} do
      c1 = conversation_fixture(%{status: :resolved, subject: "Bulk row 1"})
      c2 = conversation_fixture(%{status: :resolved, subject: "Bulk row 2"})

      {:ok, view, _html} = live(conn, "/inbox")

      view
      |> element(~s(input[phx-click="toggle_select"][phx-value-id="#{c1.id}"]))
      |> render_click()

      html =
        view
        |> element(~s(input[phx-click="toggle_select"][phx-value-id="#{c2.id}"]))
        |> render_click()

      assert html =~ "2 selected"
      assert html =~ "Send recovery follow-up to 2"
      # Brand §7.5 — text label AND token (never-color-alone).
      assert html =~ "var(--cl-primary)"
    end

    test "opening the confirm modal renders <.focus_wrap>, cohort sample, body, and actions (D-07 / D-08)",
         %{conn: conn} do
      c1 = conversation_fixture(%{status: :resolved, subject: "Sample alpha"})
      c2 = conversation_fixture(%{status: :resolved, subject: "Sample beta"})

      {:ok, view, _html} = live(conn, "/inbox")

      view
      |> element(~s(input[phx-click="toggle_select"][phx-value-id="#{c1.id}"]))
      |> render_click()

      view
      |> element(~s(input[phx-click="toggle_select"][phx-value-id="#{c2.id}"]))
      |> render_click()

      html =
        view
        |> element(~s(button[phx-click="open_bulk_confirm"]))
        |> render_click()

      assert html =~ ~s(role="dialog")
      # Focus trap — Phoenix's <.focus_wrap> compiles to an id'd wrapper.
      assert html =~ ~s(id="bulk-confirm-wrap")
      # Cohort labels rendered through Governance.preview_bulk_recovery_cohort/1.
      assert html =~ "Sample alpha"
      assert html =~ "Sample beta"
      # Snapshotted rendered body — pure function of template_id at v1.
      assert html =~ "Outbound message using template: #{@template_id}"
      # Both affordances present.
      assert html =~ ~s(phx-click="cancel_bulk_confirm")
      assert html =~ ~s(phx-click="confirm_bulk_send")
    end

    test "Escape closes the modal AND preserves selection (D-08 / Pitfall 6)", %{conn: conn} do
      c1 = conversation_fixture(%{status: :resolved, subject: "Preserve 1"})
      c2 = conversation_fixture(%{status: :resolved, subject: "Preserve 2"})

      {:ok, view, _html} = live(conn, "/inbox")

      view
      |> element(~s(input[phx-click="toggle_select"][phx-value-id="#{c1.id}"]))
      |> render_click()

      view
      |> element(~s(input[phx-click="toggle_select"][phx-value-id="#{c2.id}"]))
      |> render_click()

      view
      |> element(~s(button[phx-click="open_bulk_confirm"]))
      |> render_click()

      # The backdrop carries `phx-window-keydown="cancel_bulk_confirm"`; firing
      # the named event with Escape mirrors what the browser dispatches.
      html = render_keydown(view, "cancel_bulk_confirm", %{"key" => "Escape"})

      # Modal closed — no dialog markup left.
      refute html =~ ~s(role="dialog")
      # Selection preserved — sticky bar still shows the cohort.
      assert html =~ "2 selected"
      assert html =~ "Send recovery follow-up to 2"
    end

    test "confirming routes through Outbound.bulk_trigger/2: flash + selection cleared + N system_outbound messages persist (D-13 / D-A)",
         %{conn: conn} do
      c1 = conversation_fixture(%{status: :resolved, subject: "Confirm 1"})
      c2 = conversation_fixture(%{status: :resolved, subject: "Confirm 2"})

      envelope_count_before = Repo.aggregate(BulkEnvelope, :count, :id)

      {:ok, view, _html} = live(conn, "/inbox")

      view
      |> element(~s(input[phx-click="toggle_select"][phx-value-id="#{c1.id}"]))
      |> render_click()

      view
      |> element(~s(input[phx-click="toggle_select"][phx-value-id="#{c2.id}"]))
      |> render_click()

      view
      |> element(~s(button[phx-click="open_bulk_confirm"]))
      |> render_click()

      view
      |> element(~s(button[phx-click="confirm_bulk_send"]))
      |> render_click()

      # NOTE on the flash: `Outbound.bulk_trigger/2`'s happy path fires
      # `put_flash(:info, "Bulk recovery queued for N conversations.")` on the
      # socket (lib/cairnloop/web/inbox_live.ex:489). The minimal TestLayouts
      # root (test/support/layouts.ex) renders only `@inner_content` — it does
      # NOT render `@flash` — so the flash text never appears in `render(view)`
      # output here. The flash contract is asserted at the headless layer
      # (test/cairnloop/web/inbox_live_test.exs inspects `socket.assigns.flash`
      # directly); the integration layer asserts the LOAD-BEARING side effects
      # — selection cleared, BulkEnvelope row landed, N system_outbound
      # Messages with envelope correlation key — which collectively prove the
      # confirm path ran end-to-end through real Postgres.
      html = render(view)

      # Selection cleared — the sticky bar disappears entirely.
      refute html =~ "Send recovery follow-up to"
      # Modal dismissed.
      refute html =~ ~s(role="dialog")

      # One envelope row landed; recipient cohort + status are correct.
      assert Repo.aggregate(BulkEnvelope, :count, :id) == envelope_count_before + 1

      envelope =
        BulkEnvelope
        |> order_by([e], desc: e.inserted_at)
        |> limit(1)
        |> Repo.one!()

      assert envelope.status == :submitted
      assert envelope.count == 2
      assert envelope.recipient_conversation_ids == Enum.sort([c1.id, c2.id])

      # D-A — one `system_outbound` Message per recipient, each carrying the
      # envelope correlation key (NOT a new card type — the existing role).
      messages =
        Message
        |> where(
          [m],
          m.conversation_id in ^[c1.id, c2.id] and m.role == :system_outbound
        )
        |> Repo.all()

      assert length(messages) == 2
      assert Enum.all?(messages, &(&1.metadata["bulk_envelope_id"] == envelope.id))
    end
  end

  describe "refusal lane: max_batch_size cap triggers calm refusal modal (D-10 / brand §7.5)" do
    test "selecting 3 resolved with cap=2 opens refusal modal: SVG + heading + safe-limit copy + danger token + disabled Confirm",
         %{conn: conn} do
      Application.put_env(:cairnloop, :max_batch_size, 2)

      c1 = conversation_fixture(%{status: :resolved, subject: "Refuse 1"})
      c2 = conversation_fixture(%{status: :resolved, subject: "Refuse 2"})
      c3 = conversation_fixture(%{status: :resolved, subject: "Refuse 3"})

      {:ok, view, _html} = live(conn, "/inbox")

      view
      |> element(~s(input[phx-click="toggle_select"][phx-value-id="#{c1.id}"]))
      |> render_click()

      view
      |> element(~s(input[phx-click="toggle_select"][phx-value-id="#{c2.id}"]))
      |> render_click()

      view
      |> element(~s(input[phx-click="toggle_select"][phx-value-id="#{c3.id}"]))
      |> render_click()

      html =
        view
        |> element(~s(button[phx-click="open_bulk_confirm"]))
        |> render_click()

      # Refusal banner — never-color-alone: SVG icon + heading text + token.
      assert html =~ "<svg"
      assert html =~ "Batch too large."
      assert html =~ "safe send limit of 2"
      assert html =~ "var(--cl-danger)"

      # Confirm send button is disabled (no phx-click; markup carries disabled).
      assert html =~ ~s(disabled)
      assert html =~ ~s(aria-disabled="true")
      assert html =~ "Confirm send"
      # Cancel still present so the operator can back out.
      assert html =~ ~s(phx-click="cancel_bulk_confirm")
    end
  end
end
