defmodule CairnloopExampleWeb.ThreadNavigationE2ETest do
  @moduledoc """
  Real-browser E2E proof for the four cross-screen threading transitions added in Phase 42
  (plans 03-05). `Phoenix.LiveViewTest` cannot exercise these because it runs no JS and does
  not actually follow `<.link navigate>` transitions; only a real browser proves the URL change.

  All four threads:
    THREAD-01  Resolved conversation → "Next in queue →" → next open conversation
    THREAD-02  /support/audit-log row "View conversation" → subject conversation
    THREAD-03a Governed-action card "View audit trail" → /support/audit-log?proposal=<id>
    THREAD-03b KB editor breadcrumb "From conversation" → originating conversation

  URL assertions use the HOST `/support/...` prefix (the library is mounted at /support in
  the example app's router — router.ex:42). Library links are scope-root-relative (`/id`,
  `/audit-log?proposal=...`); under the mount they resolve to `/support/id`, etc.
  Assertions NEVER expect a doubled `/support/support/...` prefix (Pitfall 3 regression guard,
  T-42-16).

  The Ecto sandbox is managed by PhoenixTest.Playwright.Case; the dashboard live_session joins
  it via CairnloopExampleWeb.LiveAcceptance (test-only on_mount hook), so each test's fixture
  data is visible to the rendered library LiveViews.
  """
  use PhoenixTest.Playwright.Case, async: false

  @moduletag :e2e

  import CairnloopExample.RailFixtures

  # ---------------------------------------------------------------------------
  # THREAD-01: Resolved conversation → "Next in queue →" → next open conversation
  # ---------------------------------------------------------------------------
  describe "THREAD-01: Next in queue from a resolved conversation" do
    test "clicking 'Next in queue' navigates to the next open conversation", %{conn: conn} do
      %{resolved_id: resolved_id, next_open_id: next_open_id} =
        resolved_conversation_with_next_open()

      conn
      |> visit("/support/#{resolved_id}")
      |> assert_has("body .phx-connected")
      # The resolved state renders outbound_recovery_card/1 which includes "Next in queue →"
      # when next_open_id is non-nil (conversation_live.ex — case @next_open_id).
      |> click_link("Next in queue →")
      # Landed URL must be the next open conversation, NOT the inbox.
      # scope-relative /#{next_open_id} resolves to /support/#{next_open_id} under the mount.
      |> assert_has("body .phx-connected")
      |> assert_path("/support/#{next_open_id}")
      # Regression guard: never a doubled /support/support/... prefix (T-42-16).
      |> refute_has("body", text: "/support/support/")
    end
  end

  # ---------------------------------------------------------------------------
  # THREAD-02: /support/audit-log row "View conversation" → subject conversation
  # ---------------------------------------------------------------------------
  describe "THREAD-02: Audit-log row subject link navigates to the conversation" do
    test "clicking 'View conversation' lands on the subject conversation", %{conn: conn} do
      %{conv_id: conv_id} = conversation_with_audit_event()

      conn
      |> visit("/support/audit-log")
      |> assert_has("body .phx-connected")
      # The audit log renders a "View conversation" <.link navigate> for each row whose
      # proposal has a conversation_id (audit_log_live.ex — subject_href/1 non-nil branch).
      |> click_link("View conversation")
      # Landed on the subject conversation view.
      |> assert_has("body .phx-connected")
      |> assert_path("/support/#{conv_id}")
      # Regression guard (T-42-16).
      |> refute_has("body", text: "/support/support/")
    end
  end

  # ---------------------------------------------------------------------------
  # THREAD-03a: Governed-action card "View audit trail" → /support/audit-log?proposal=<id>
  # ---------------------------------------------------------------------------
  describe "THREAD-03a: Governed-action card audit deep-link" do
    test "clicking 'View audit trail' navigates to the filtered audit log", %{conn: conn} do
      %{conv_id: conv_id, proposal_id: proposal_id} = pending_governed_action_conversation()

      conn
      |> visit("/support/#{conv_id}")
      |> assert_has("body .phx-connected")
      # The Tier-3 "Identifiers & trace" disclosure is default-closed; open it first.
      # Its summary text is "Identifiers & trace" (conversation_live.ex:1103).
      # PhoenixTest.Playwright.click/3 clicks non-button/non-link elements by selector + text.
      |> PhoenixTest.Playwright.click("summary", "Identifiers & trace")
      # Now the "View audit trail" link inside the disclosure is visible and clickable.
      # Link renders: <.link navigate={"/audit-log?proposal=#{@trace.proposal_id}"}>
      |> click_link("View audit trail")
      # Landed on the filtered audit log.
      |> assert_has("body .phx-connected")
      # scope-relative /audit-log?proposal=<id> resolves to /support/audit-log?proposal=<id>.
      |> assert_path("/support/audit-log", query_params: %{"proposal" => to_string(proposal_id)})
      # Regression guard (T-42-16).
      |> refute_has("body", text: "/support/support/")
    end
  end

  # ---------------------------------------------------------------------------
  # THREAD-03b: KB editor "From conversation" crumb → originating conversation
  # ---------------------------------------------------------------------------
  describe "THREAD-03b: KB editor 'From conversation' breadcrumb crumb" do
    test "clicking 'From conversation' navigates to the originating conversation", %{conn: conn} do
      %{article_id: article_id, conv_id: conv_id} = article_with_origin_conversation()

      conn
      |> visit("/support/knowledge-base/#{article_id}/edit")
      |> assert_has("body .phx-connected")
      # The breadcrumb prepends "From conversation" when origin_conversation_id is non-nil
      # (breadcrumb_presenter.ex — editor_items/3 non-nil clause).
      |> click_link("From conversation")
      # Landed on the originating conversation.
      |> assert_has("body .phx-connected")
      |> assert_path("/support/#{conv_id}")
      # Regression guard (T-42-16).
      |> refute_has("body", text: "/support/support/")
    end
  end
end
