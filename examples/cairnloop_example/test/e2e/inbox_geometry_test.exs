defmodule CairnloopExampleWeb.InboxGeometryE2ETest do
  @moduledoc """
  Real-browser E2E for the Inbox's RESPONSIVE RENDERED-GEOMETRY facts (Phase 43 / D3 / RESP-01 +
  RESP-02) that `Phoenix.LiveViewTest` and the source-scan `ResponsiveMarkupTest` structurally
  cannot exercise — they assert that classes/attributes are PRESENT, not that the rendered pixels
  are correct. This suite is the automated replacement for the former 43-03 human-verify checkpoint
  (the same pattern Phases 41/42 used: rail_disclosure_test.exs, thread_navigation_test.exs).

  Because this E2E *replaces a deleted human-verify checkpoint*, a false-passing assertion is worse
  than no test — it would silently re-open the gap. Each test therefore pins its preconditions
  (real scroll happened; the measured row is on-screen) before comparing geometry.

  Covered (all measured at a 768px tablet viewport via the Playwright `evaluate/3` JS bridge):
    1. Tap targets ≥44×44px (D3-07) — both raw inbox checkboxes render a ≥44px hit area, and both
       sticky bulk-bar buttons render ≥44px tall (`getBoundingClientRect()`).
    2. No sticky bulk-bar occlusion (D3-06) — with rows selected and the list scrolled to the
       bottom, the last selectable row is on-screen AND sits fully above the sticky bulk-bar.
    3. No 768px regression (RESP-01) — the mobile-first `min-width:768` step is live: `.cl-main`
       resolves to its 768 tablet padding (≥32px, which the weaker 640 step at 24px would NOT
       satisfy) and the nav still renders.

  The Ecto sandbox is managed by PhoenixTest.Playwright.Case; the dashboard live_session joins it
  via CairnloopExampleWeb.LiveAcceptance (test-only on_mount), so the fixture's resolved rows are
  visible to the rendered (library-owned) InboxLive at `/support/inbox`.
  """
  use PhoenixTest.Playwright.Case,
    async: false,
    browser_context_opts: [viewport: %{width: 768, height: 720}]

  @moduletag :e2e

  import CairnloopExample.RailFixtures

  # Geometry thresholds (single source of truth — avoids bare magic numbers drifting per WR-04/IN-03).
  @min_tap 44
  @tap_rounding_tol 0.01
  @subpixel_tol 1
  # At 768px the @media (min-width: 768) rule must win (32px = --cl-space-8). The weaker 640 step
  # yields only 24px, so >= 32 (not >= 24) is what actually isolates the 768 conversion as live.
  @tablet_pad_min 32

  # Seed count is deliberately DECOUPLED from :max_batch_size (default 25): a value > the cap would
  # not matter here (these tests never open the confirm modal), but the count exists only to make
  # the list overflow a 720px viewport so the occlusion test exercises a real scroll. 30 rows do
  # that with margin; the occlusion test still asserts `scrollHeight > innerHeight` so a future
  # denser row style fails loudly instead of silently skipping the scroll (WR-05).
  @seed_rows 30

  # Stable selectors — the inbox controls carry no ids (class + phx-click is the contract).
  @select_all ~s(input.cl-checkbox[phx-click="toggle_select_all_visible"])
  @row_checkbox ~s(input.cl-checkbox[phx-click="toggle_select"])
  @bulk_bar ".cl-inbox-bulk-bar"
  @bulk_buttons ".cl-inbox-bulk-bar .cl-button--lg"

  # click/2 (click by CSS selector) is a Playwright-only helper, not part of the shared PhoenixTest
  # API surface; it dispatches a real click and waits for the LiveView re-render.
  defp click_sel(conn, selector), do: PhoenixTest.Playwright.click(conn, selector)

  defp tap_target?(%{"w" => width, "h" => height}) do
    width + @tap_rounding_tol >= @min_tap and height + @tap_rounding_tol >= @min_tap
  end

  defp tap_height?(height), do: height + @tap_rounding_tol >= @min_tap

  # Select two specific rows (well under the cap) so the sticky bulk-bar appears WITHOUT risking the
  # over-cap refusal modal that select-all could trigger if the cap is ever lowered.
  defp select_two_rows(conn, id1, id2) do
    conn
    |> click_sel(~s(input.cl-checkbox[phx-click="toggle_select"][phx-value-id="#{id1}"]))
    |> click_sel(~s(input.cl-checkbox[phx-click="toggle_select"][phx-value-id="#{id2}"]))
    |> assert_has(@bulk_bar)
  end

  setup do
    [id1, id2 | _] = ids = resolved_inbox_rows(@seed_rows)
    %{ids: ids, id1: id1, id2: id2}
  end

  describe "Tap targets ≥44px (D3-07 / RESP-02)" do
    test "both checkboxes and both bulk-bar buttons render a ≥44px hit area", %{
      conn: conn,
      id1: id1,
      id2: id2
    } do
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
          assert tap_target?(all),
                 "select-all checkbox hit area is #{all["w"]}×#{all["h"]}px (need ≥#{@min_tap}×#{@min_tap})"

          assert tap_target?(row),
                 "per-row checkbox hit area is #{row["w"]}×#{row["h"]}px (need ≥#{@min_tap}×#{@min_tap})"
        end
      )

      # Surface the sticky bulk-bar (select two rows — under the cap), then measure both action
      # buttons' rendered heights.
      conn = select_two_rows(conn, id1, id2)

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
            assert tap_height?(h), "a bulk-bar button rendered #{h}px tall (need ≥#{@min_tap})"
          end
        end
      )
    end
  end

  describe "No sticky bulk-bar occlusion (D3-06 / RESP-02 — browser-only)" do
    test "the last selectable row is on-screen and clears the sticky bulk-bar at full scroll", %{
      conn: conn,
      id1: id1,
      id2: id2
    } do
      conn =
        conn
        |> visit("/support/inbox")
        |> assert_has("body .phx-connected")
        |> select_two_rows(id1, id2)

      # Scroll the page to the very bottom so the sticky bar settles and the last row is in view.
      conn = evaluate(conn, "window.scrollTo(0, document.body.scrollHeight)")

      evaluate(
        conn,
        """
        (() => {
          // Scope to actual selectable rows (li carrying a checkbox), not just any <li> (IN-02).
          const rows = document.querySelectorAll('ul.cl-inbox-list--bulk-clearance li:has(input.cl-checkbox)');
          const last = rows[rows.length - 1];
          const bar = document.querySelector('#{@bulk_bar}');
          const lr = last.getBoundingClientRect();
          const br = bar.getBoundingClientRect();
          return {
            rowCount: rows.length,
            scrollHeight: document.body.scrollHeight,
            innerHeight: window.innerHeight,
            lastTop: lr.top,
            lastBottom: lr.bottom,
            barTop: br.top
          };
        })()
        """,
        fn m ->
          # Precondition: the list actually overflowed and we really scrolled (WR-05) — otherwise a
          # short, non-scrolling list would make the occlusion check meaningless.
          assert m["scrollHeight"] > m["innerHeight"],
                 "inbox list did not overflow the viewport (scrollHeight #{m["scrollHeight"]} ≤ innerHeight #{m["innerHeight"]}) — occlusion test cannot exercise a real scroll"

          # Precondition: the last row is actually ON-SCREEN, not scrolled above the fold — without
          # this, `last_bottom ≤ bar_top` is trivially true and the test false-passes (WR-02).
          assert m["lastBottom"] > 0 and m["lastBottom"] <= m["innerHeight"] + @subpixel_tol,
                 "last inbox row is not within the viewport (bottom #{m["lastBottom"]}px, innerHeight #{m["innerHeight"]}px) — cannot prove non-occlusion"

          # The real assertion: the last row's bottom edge sits at/above the sticky bar's top edge.
          assert m["lastBottom"] <= m["barTop"] + @subpixel_tol,
                 "last inbox row (bottom #{m["lastBottom"]}px) is occluded by the sticky bulk-bar (top #{m["barTop"]}px)"
        end
      )
    end
  end

  describe "No 768px regression (RESP-01 — mobile-first min-width conversions are live)" do
    test ".cl-main resolves its 768 tablet padding step and the nav still renders", %{conn: conn} do
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
          # At 768px the min-width:768 rule must win (32px). >= 32 isolates the 768 step — the
          # weaker 640 rule (24px) would NOT satisfy this, so a silent 768-rule regression fails
          # here instead of passing on the 640 value (WR-04).
          assert pad_left >= @tablet_pad_min,
                 ".cl-main padding-left is #{pad_left}px at 768px (need ≥#{@tablet_pad_min} — the min-width:768 tablet step must be live, not just the 640 step)"
        end
      )
    end
  end
end
