defmodule CairnloopExampleWeb.RailDisclosureE2ETest do
  @moduledoc """
  Real-browser E2E for the conversation rail's CLIENT-ONLY behaviors (Phase 41 / D2) that
  `Phoenix.LiveViewTest` structurally cannot exercise (it runs no JS). This suite is the
  automated replacement for the former 41-04 human-verify checkpoint.

  Covered:
    1. Expand all / Collapse all (`Phoenix.LiveView.JS`) toggle `open` on the three
       `details[data-tier="2"]` groups ONLY — never the Tier-3 trace group, never Tier-1.
    2. The colocated `RailDensity` hook flips `data-density` and writes `localStorage`.
    3. That density choice survives a page reload (hook re-reads localStorage on mount).
    4. A manually-opened Tier-2 panel survives a real LiveView re-render (`phx-update="ignore"`).
    5. Accessibility: a Tier-2 `<summary>` is keyboard-operable; Tier-1 is never hidden.

  The Ecto sandbox is managed by PhoenixTest.Playwright.Case; the dashboard live_session joins it
  via CairnloopExampleWeb.LiveAcceptance (test-only on_mount), so the fixture's data is visible to
  the rendered (library-owned) ConversationLive.
  """
  use PhoenixTest.Playwright.Case, async: false

  @moduletag :e2e

  import CairnloopExample.RailFixtures

  # reload_page/2 is a Playwright-only helper (not part of the shared PhoenixTest API surface).
  defp reload(conn), do: PhoenixTest.Playwright.reload_page(conn)

  setup do
    %{conv_id: conv_id, proposal_id: proposal_id} = pending_governed_action_conversation()
    %{conv_id: conv_id, proposal_id: proposal_id}
  end

  describe "Expand all / Collapse all (Behavior 1: JS scoping)" do
    test "toggle open only on Tier-2; Tier-3 trace and Tier-1 are untouched", %{
      conn: conn,
      conv_id: conv_id
    } do
      conn =
        conn
        |> visit("/support/#{conv_id}")
        # Wait for LiveView to connect so phx-click JS commands are bound and the hook is mounted.
        |> assert_has("body .phx-connected")
        |> assert_has("#evidence-rail-density")
        # Exactly three Tier-2 disclosure groups exist.
        |> assert_has("details[data-tier='2']", count: 3)

      # Collapse all → no Tier-2 group is open.
      conn
      |> click_button("Collapse all")
      |> refute_has("details[data-tier='2'][open]")
      # Tier-1 safety footer stays visible regardless (it lives outside any <details>).
      |> assert_has("button", text: "Approve")
      # Expand all → all three Tier-2 groups open...
      |> click_button("Expand all")
      |> assert_has("details[data-tier='2'][open]", count: 3)
      # ...and nothing WITHOUT data-tier (the Tier-3 trace group + nested raw snapshots) opened.
      |> refute_has("details:not([data-tier])[open]")
      |> assert_has("button", text: "Approve")
    end
  end

  describe "Density toggle (Behaviors 2 + 3: localStorage round-trip + reload persistence)" do
    test "toggling flips data-density, persists to localStorage, and survives reload", %{
      conn: conn,
      conv_id: conv_id
    } do
      conn =
        conn
        |> visit("/support/#{conv_id}")
        |> assert_has("body .phx-connected")
        # Default density before any interaction.
        |> assert_has("#evidence-rail-density[data-density='comfortable']")

      # Toggle (button label starts as "Comfortable") → compact.
      conn =
        conn
        |> click_button("Comfortable")
        |> assert_has("#evidence-rail-density[data-density='compact']")

      # The hook persisted the choice to localStorage["cl:rail:density"].
      evaluate(conn, "window.localStorage.getItem('cl:rail:density')", fn value ->
        assert value == "compact"
      end)

      # Reload: the hook re-reads localStorage on mount and re-applies compact (no flash to default).
      conn
      |> reload()
      |> assert_has("body .phx-connected")
      |> assert_has("#evidence-rail-density[data-density='compact']")
    end
  end

  describe "Open survives PubSub re-render (Behavior 4: phx-update=ignore)" do
    test "an opened Tier-2 panel stays open across a LiveView re-render", %{
      conn: conn,
      conv_id: conv_id
    } do
      conn =
        conn
        |> visit("/support/#{conv_id}")
        |> assert_has("body .phx-connected")
        |> click_button("Expand all")
        |> assert_has("details[data-tier='2'][open]", count: 3)

      # Force a genuine server-driven re-render: broadcast the same :message_created event the
      # production reply path emits → handle_info → reload_conversation_with_context → re-render.
      marker = CairnloopExample.RailFixtures.inject_message_and_broadcast(conv_id, "RAIL_E2E_RERENDER_MARKER")

      conn
      # The new message appears, proving the re-render landed...
      |> assert_has("body", text: marker)
      # ...and the three Tier-2 panels are STILL open (phx-update="ignore" preserved client state).
      |> assert_has("details[data-tier='2'][open]", count: 3)
    end
  end

  describe "Accessibility (Behavior 5: keyboard + Tier-1 pinning)" do
    test "a Tier-2 summary is keyboard-operable and Tier-1 is never collapsed", %{
      conn: conn,
      conv_id: conv_id,
      proposal_id: proposal_id
    } do
      conn
      |> visit("/support/#{conv_id}")
      |> assert_has("body .phx-connected")
      # Start from all-collapsed so the keyboard open is unambiguous.
      |> click_button("Collapse all")
      |> refute_has("#ga-#{proposal_id}-history[open]")
      # Native <details> keyboard operability: focus the summary and press Enter to open it.
      |> press("#ga-#{proposal_id}-history > summary", "Enter")
      |> assert_has("#ga-#{proposal_id}-history[open]")
      # Tier-1 safety surface (Approve/Reject/Defer) is outside every <details> — always visible.
      |> assert_has("button", text: "Approve")
      |> assert_has("button", text: "Reject")
    end
  end
end
