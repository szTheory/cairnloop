defmodule CairnloopExampleWeb.InboxGeometryE2ETest do
  @moduledoc """
  Real-browser E2E for the Inbox's RESPONSIVE RENDERED-GEOMETRY facts (Phase 43 / D3 / RESP-01 +
  RESP-02) that `Phoenix.LiveViewTest` and the source-scan `ResponsiveMarkupTest` structurally
  cannot exercise — they assert that classes/attributes are PRESENT, not that the rendered pixels
  are correct. This suite is the automated replacement for the former 43-03 human-verify checkpoint
  (the same pattern Phases 41/42 used: rail_disclosure_test.exs, thread_navigation_test.exs).

  Covered (all measured at a 768px tablet viewport via the Playwright `evaluate/3` JS bridge):
    1. Tap targets ≥44×44px (D3-07) — both raw inbox checkboxes render a ≥44px hit area, and both
       sticky bulk-bar buttons render ≥44px tall (`getBoundingClientRect()`).
    2. No sticky bulk-bar occlusion (D3-06) — with rows selected and the list scrolled to the
       bottom, the last selectable row sits fully above the sticky bulk-bar (the genuinely
       browser-only fact: source scan can prove the clearance class exists but never that the bar
       doesn't cover the last row). Also guards against a future `position: fixed` regression that
       would silently re-introduce occlusion.
    3. No 768px regression (RESP-01) — the mobile-first `min-width` conversions are behaviorally
       live: `.cl-main` resolves to its tablet horizontal padding step and the nav still renders.

  The Ecto sandbox is managed by PhoenixTest.Playwright.Case; the dashboard live_session joins it
  via CairnloopExampleWeb.LiveAcceptance (test-only on_mount), so the fixture's resolved rows are
  visible to the rendered (library-owned) InboxLive at `/support/inbox`.
  """
  use PhoenixTest.Playwright.Case,
    async: false,
    browser_context_opts: [viewport: %{width: 768, height: 720}]

  @moduletag :e2e

  import CairnloopExample.RailFixtures

  # Stable selectors — the inbox controls carry no ids (class + phx-click is the contract).
  @select_all ~s(input.cl-checkbox[phx-click="toggle_select_all_visible"])
  @row_checkbox ~s(input.cl-checkbox[phx-click="toggle_select"])
  @bulk_bar ".cl-inbox-bulk-bar"
  @bulk_buttons ".cl-inbox-bulk-bar .cl-button--lg"

  # click/2 (click by CSS selector) is a Playwright-only helper, not part of the shared PhoenixTest
  # API surface; it dispatches a real click and waits for the LiveView re-render.
  defp click_sel(conn, selector), do: PhoenixTest.Playwright.click(conn, selector)

  setup do
    # 25 resolved rows overflow the 720px-tall viewport, so the sticky bulk-bar clearance is
    # exercised under a real scroll (not a short, non-scrolling list).
    %{ids: resolved_inbox_rows(25)}
  end

  describe "Tap targets ≥44px (D3-07 / RESP-02)" do
    test "both checkboxes and both bulk-bar buttons render a ≥44px hit area", %{conn: conn} do
      conn =
        conn
        |> visit("/support/inbox")
        |> assert_has("body .phx-connected")
        |> assert_has(@select_all)
        |> assert_has(@row_checkbox)

      # Raw checkbox hit areas (the .cl-checkbox utility forces min 44×44 even though the native
      # control is tiny). Measure the rendered boxes, not the source class.
      evaluate(
        conn,
        """
        (() => {
          const box = (sel) => {
            const b = document.querySelector(sel).getBoundingClientRect();
            return {w: b.width, h: b.height};
          };
          return {all: box('#{@select_all}'), row: box('#{@row_checkbox}')};
        })()
        """,
        fn %{"all" => all, "row" => row} ->
          assert all["w"] >= 44 and all["h"] >= 44,
                 "select-all checkbox hit area is #{all["w"]}×#{all["h"]}px (need ≥44×44)"

          assert row["w"] >= 44 and row["h"] >= 44,
                 "per-row checkbox hit area is #{row["w"]}×#{row["h"]}px (need ≥44×44)"
        end
      )

      # Surface the sticky bulk-bar (select-all selects every visible resolved row), then measure
      # both action buttons' rendered heights.
      conn = conn |> click_sel(@select_all) |> assert_has(@bulk_bar)

      evaluate(
        conn,
        """
        Array.from(document.querySelectorAll('#{@bulk_buttons}'))
          .map(el => el.getBoundingClientRect().height)
        """,
        fn heights ->
          assert length(heights) >= 2,
                 "expected ≥2 size=lg bulk-bar buttons, got #{length(heights)}"

          for h <- heights do
            assert h >= 44, "a bulk-bar button rendered #{h}px tall (need ≥44)"
          end
        end
      )
    end
  end

  describe "No sticky bulk-bar occlusion (D3-06 / RESP-02 — browser-only)" do
    test "the last selectable row clears the sticky bulk-bar when scrolled to the bottom", %{
      conn: conn
    } do
      conn =
        conn
        |> visit("/support/inbox")
        |> assert_has("body .phx-connected")
        |> click_sel(@select_all)
        |> assert_has(@bulk_bar)

      # Scroll the page to the very bottom so the sticky bar settles and the last row is in view.
      conn = evaluate(conn, "window.scrollTo(0, document.body.scrollHeight)")

      evaluate(
        conn,
        """
        (() => {
          const rows = document.querySelectorAll('ul.cl-inbox-list--bulk-clearance li');
          const last = rows[rows.length - 1];
          const bar = document.querySelector('#{@bulk_bar}');
          return {
            lastBottom: last.getBoundingClientRect().bottom,
            barTop: bar.getBoundingClientRect().top,
            innerHeight: window.innerHeight
          };
        })()
        """,
        fn %{"lastBottom" => last_bottom, "barTop" => bar_top, "innerHeight" => inner_h} ->
          # The last row's bottom edge must not extend below the sticky bar's top edge
          # (1px tolerance for sub-pixel rounding). If this fails, the bulk-bar clearance is
          # insufficient (or the bar regressed to position: fixed) and occludes the last row.
          assert last_bottom <= bar_top + 1,
                 "last inbox row (bottom #{last_bottom}px) is occluded by the sticky bulk-bar " <>
                   "(top #{bar_top}px); viewport #{inner_h}px"
        end
      )
    end
  end

  describe "No 768px regression (RESP-01 — mobile-first min-width conversions are live)" do
    test ".cl-main resolves its tablet padding step and the nav still renders", %{conn: conn} do
      conn =
        conn
        |> visit("/support/inbox")
        |> assert_has("body .phx-connected")
        |> assert_has(".cl-nav__link")

      evaluate(
        conn,
        """
        (() => {
          const cs = window.getComputedStyle(document.querySelector('.cl-main'));
          return {padLeft: parseFloat(cs.paddingLeft), padRight: parseFloat(cs.paddingRight)};
        })()
        """,
        fn %{"padLeft" => pad_left} ->
          # At a 768px viewport the min-width:768 (or :640) rule has fired — base mobile padding is
          # 16px, tablet/desktop is ≥24px. A value <24 means the min-width conversion regressed and
          # the page is stuck at the mobile base.
          assert pad_left >= 24,
                 ".cl-main padding-left is #{pad_left}px at 768px (need ≥24 — the min-width " <>
                   "conversion should have applied the tablet/desktop gutter)"
        end
      )
    end
  end
end
