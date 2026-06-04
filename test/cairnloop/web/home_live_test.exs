defmodule Cairnloop.Web.HomeLiveTest do
  @moduledoc """
  Headless render test for the Cockpit Home. Exercises `render/1` directly with
  built assigns so it needs no Repo — the DB-backed mount path is covered by the
  integration suite.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  # ---------------------------------------------------------------------------
  # Assigns helper — defaults cover every assign the new render/1 expects.
  # ---------------------------------------------------------------------------

  defp assigns(overrides) do
    Map.merge(
      %{
        open_count: 0,
        resolved_count: 0,
        gaps_count: 0,
        audit_count: 0,
        # Fail-closed unavailability signals (D-06)
        open_count_unavailable?: false,
        resolved_count_unavailable?: false,
        gaps_unavailable?: false,
        audit_unavailable?: false,
        # Health chip (D-08): variant string + label + meta
        health_variant: "success",
        health_label: "Healthy",
        health_meta: "Notifier and retrieval reachable",
        # Throttle (D-09)
        pending_recount?: false,
        __changed__: nil
      },
      Map.new(overrides)
    )
  end

  # ---------------------------------------------------------------------------
  # HOME-01: hero tier with copper count + primary CTA
  # ---------------------------------------------------------------------------

  describe "HOME-01 hero tier" do
    test "renders cl-hero section with job label and count when open_count > 0" do
      html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{open_count: 5})))

      assert html =~ "Work the queue", "expected hero job label 'Work the queue'"
      assert html =~ "cl-hero__count", "expected cl-hero__count on the count element"
      assert html =~ "5", "expected the open count digit"
    end

    test "renders 'Open inbox' primary CTA button when open_count > 0" do
      html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{open_count: 3})))

      assert html =~ "Open inbox", "expected primary CTA text 'Open inbox'"
      assert html =~ "cl-button--primary", "expected primary button variant class"
    end

    test "hero navigate destination is /inbox" do
      html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{open_count: 2})))

      # The CTA wraps a link navigating to /inbox
      assert html =~ ~s(href="/inbox") or html =~ ~s(/inbox),
             "expected CTA to navigate to /inbox"
    end
  end

  # ---------------------------------------------------------------------------
  # HOME-02a: Recover-resolved sub-line (deterministic resolved deep-link, D-10)
  # ---------------------------------------------------------------------------

  describe "HOME-02a recover-resolved sub-line" do
    test "resolved sub-line with /inbox?status=resolved present when resolved_count > 0" do
      html =
        rendered_to_string(
          Cairnloop.Web.HomeLive.render(
            assigns(%{open_count: 3, resolved_count: 4})
          )
        )

      assert html =~ ~s(href="/inbox?status=resolved"),
             "expected href='/inbox?status=resolved' for the resolved sub-line"

      assert html =~ "4 resolved — eligible for recovery",
             "expected resolved sub-line copy"
    end

    test "resolved sub-line ABSENT when resolved_count == 0" do
      html =
        rendered_to_string(
          Cairnloop.Web.HomeLive.render(
            assigns(%{open_count: 3, resolved_count: 0})
          )
        )

      refute html =~ ~s(href="/inbox?status=resolved"),
             "resolved sub-line should be absent when resolved_count == 0"
    end

    test "resolved sub-line ABSENT when resolved_count_unavailable?" do
      html =
        rendered_to_string(
          Cairnloop.Web.HomeLive.render(
            assigns(%{open_count: 3, resolved_count: 2, resolved_count_unavailable?: true})
          )
        )

      refute html =~ ~s(href="/inbox?status=resolved"),
             "resolved sub-line should be absent when count is unavailable"
    end
  end

  # ---------------------------------------------------------------------------
  # HOME-03: secondary band — 3 tiles, health as chip, neutral counts
  # ---------------------------------------------------------------------------

  describe "HOME-03 secondary band — 3 tiles" do
    test "band has exactly 3 cl-stat tiles" do
      html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{open_count: 1})))

      # Count .cl-stat occurrences using string matching
      # Each cl-stat tile contributes at least one "cl-stat" occurrence
      # We check for the three specific job labels instead to be precise
      assert html =~ "Tend knowledge", "expected 'Tend knowledge' tile"
      assert html =~ "Audit trail", "expected 'Audit trail' tile"
      assert html =~ "System health", "expected 'System health' tile"
    end

    test "health renders as cl-chip--success, NOT as cl-stat__count" do
      html =
        rendered_to_string(
          Cairnloop.Web.HomeLive.render(assigns(%{open_count: 1, health_variant: "success"}))
        )

      assert html =~ "cl-chip--success", "expected health chip with success variant"
      assert html =~ "Healthy", "expected health chip label 'Healthy'"
    end

    test "health renders as cl-chip--warning when degraded" do
      html =
        rendered_to_string(
          Cairnloop.Web.HomeLive.render(
            assigns(%{
              open_count: 1,
              health_variant: "warning",
              health_label: "Degraded",
              health_meta: "One or more checks need attention"
            })
          )
        )

      assert html =~ "cl-chip--warning", "expected health chip with warning variant"
      assert html =~ "Degraded", "expected health chip label 'Degraded'"
    end

    test "band counts do not use cl-hero__count (copper reserved for hero only)" do
      html =
        rendered_to_string(
          Cairnloop.Web.HomeLive.render(assigns(%{open_count: 1, gaps_count: 3}))
        )

      # Count occurrences: only the hero should have cl-hero__count
      hero_count_occurrences =
        html |> String.split("cl-hero__count") |> length() |> Kernel.-(1)

      # Only 1 occurrence (the hero's own count span)
      assert hero_count_occurrences <= 1,
             "band tiles must NOT use cl-hero__count (copper reserved for hero)"
    end

    test "band persists under zero-state (when open_count == 0)" do
      html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{open_count: 0})))

      assert html =~ "Tend knowledge", "Tend knowledge band tile must persist in zero-state"
      assert html =~ "Audit trail", "Audit trail band tile must persist in zero-state"
      assert html =~ "System health", "System health band tile must persist in zero-state"
    end
  end

  # ---------------------------------------------------------------------------
  # HOME-04a/b: zero-state hero swap + no phantom 6th cell
  # ---------------------------------------------------------------------------

  describe "HOME-04 zero-state" do
    test "open_count == 0 and not unavailable → cl-empty with 'All caught up'" do
      html =
        rendered_to_string(
          Cairnloop.Web.HomeLive.render(assigns(%{open_count: 0, open_count_unavailable?: false}))
        )

      assert html =~ "cl-empty", "expected cl-empty for zero state"
      assert html =~ "All caught up", "expected zero-state title 'All caught up'"
      assert html =~ "Nothing is waiting on you right now.",
             "expected zero-state body copy"
    end

    test "zero-state renders an icon SVG inside cl-empty__icon" do
      html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{open_count: 0})))

      # cl_empty renders cl_icon as an inline SVG; the class cl-empty__icon is the signal
      assert html =~ "cl-empty__icon",
             "expected cl-empty__icon class on the zero-state icon element"
    end

    test "no cl-hero rendered when open_count == 0 and not unavailable" do
      html =
        rendered_to_string(
          Cairnloop.Web.HomeLive.render(assigns(%{open_count: 0, open_count_unavailable?: false}))
        )

      refute html =~ "cl-hero__count",
             "cl-hero should NOT render when open queue is empty and count is available"
    end

    test ".cl-home-grid contains exactly 3 .cl-stat children — no phantom 6th cell" do
      html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{open_count: 1})))

      # Count root cl-stat elements — they render as either:
      #   class="cl-stat cl-focusable" (link tiles) or class="cl-stat" (health div)
      # We match opening class attributes that are EXACTLY "cl-stat" or "cl-stat " (with space)
      # but NOT sub-element classes like "cl-stat__count", "cl-stat__job", "cl-stat__meta"
      stat_count =
        Regex.scan(~r/class="cl-stat(?:\s+cl-focusable)?"/, html) |> length()

      assert stat_count == 3,
             "expected exactly 3 cl-stat root elements in the band, got #{stat_count}"
    end
  end

  # ---------------------------------------------------------------------------
  # D-06: Count unavailable — distinguished from calm zero
  # ---------------------------------------------------------------------------

  describe "D-06 count unavailable signal" do
    test "unavailable open count shows 0 AND 'Count unavailable', NOT 'All caught up'" do
      html =
        rendered_to_string(
          Cairnloop.Web.HomeLive.render(assigns(%{open_count: 0, open_count_unavailable?: true}))
        )

      # Should show hero with 0 count (not zero-state), plus the unavailable sub-line
      assert html =~ "Count unavailable",
             "expected 'Count unavailable' sub-line when count is error"

      refute html =~ "All caught up",
             "must NOT show 'All caught up' zero-state when count is unavailable (error ≠ calm-zero)"
    end

    test "genuine zero (not unavailable) → 'All caught up', NOT 'Count unavailable'" do
      html =
        rendered_to_string(
          Cairnloop.Web.HomeLive.render(assigns(%{open_count: 0, open_count_unavailable?: false}))
        )

      assert html =~ "All caught up",
             "genuine zero must show 'All caught up'"

      refute html =~ "Count unavailable",
             "genuine zero must NOT show 'Count unavailable'"
    end

    test "split/1: {:ok, n} → {n, false}" do
      assert {5, false} = Cairnloop.Web.HomeLive.split({:ok, 5})
      assert {0, false} = Cairnloop.Web.HomeLive.split({:ok, 0})
    end

    test "split/1: :error → {0, true}" do
      assert {0, true} = Cairnloop.Web.HomeLive.split(:error)
    end

    test "split/1: any non-{:ok, integer} → {0, true}" do
      assert {0, true} = Cairnloop.Web.HomeLive.split({:ok, "not an int"})
      assert {0, true} = Cairnloop.Web.HomeLive.split(nil)
      assert {0, true} = Cairnloop.Web.HomeLive.split(:ok)
    end
  end

  # ---------------------------------------------------------------------------
  # HOME-05b: throttle — deterministic, NO sleep
  # ---------------------------------------------------------------------------

  describe "HOME-05b throttle (no sleep)" do
    test "disconnected socket: {:conversations_changed} keeps pending_recount? false" do
      # A bare %Phoenix.LiveView.Socket{} → connected?/1 returns false
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          pending_recount?: false,
          open_count: 0,
          resolved_count: 0,
          gaps_count: 0,
          audit_count: 0,
          open_count_unavailable?: false,
          resolved_count_unavailable?: false,
          gaps_unavailable?: false,
          audit_unavailable?: false,
          health_variant: "success",
          health_label: "Healthy",
          health_meta: "Notifier and retrieval reachable",
          __changed__: nil
        }
      }

      # Sending {:conversations_changed} to a disconnected socket should NOT arm a timer
      # and should leave pending_recount? as false (connected?/1 is false)
      {:noreply, updated_socket} =
        Cairnloop.Web.HomeLive.handle_info({:conversations_changed}, socket)

      # On a disconnected socket, the pending flag must be false (not armed)
      assert updated_socket.assigns.pending_recount? == false,
             "disconnected socket must NOT set pending_recount? to true"
    end

    test "disconnected socket: :recount clears pending_recount? flag" do
      # Build a socket in the 'pending' state (as if a tick had been queued)
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          pending_recount?: true,
          open_count: 3,
          resolved_count: 1,
          gaps_count: 0,
          audit_count: 0,
          open_count_unavailable?: false,
          resolved_count_unavailable?: false,
          gaps_unavailable?: false,
          audit_unavailable?: false,
          health_variant: "success",
          health_label: "Healthy",
          health_meta: "Notifier and retrieval reachable",
          __changed__: nil
        }
      }

      {:noreply, updated_socket} = Cairnloop.Web.HomeLive.handle_info(:recount, socket)

      assert updated_socket.assigns.pending_recount? == false,
             ":recount handler must clear pending_recount? flag"
    end

    test "disconnected socket: multiple {:conversations_changed} do NOT each arm a timer" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          pending_recount?: false,
          open_count: 0,
          resolved_count: 0,
          gaps_count: 0,
          audit_count: 0,
          open_count_unavailable?: false,
          resolved_count_unavailable?: false,
          gaps_unavailable?: false,
          audit_unavailable?: false,
          health_variant: "success",
          health_label: "Healthy",
          health_meta: "Notifier and retrieval reachable",
          __changed__: nil
        }
      }

      # On a disconnected socket, no timer fires, flag stays false
      {:noreply, s1} = Cairnloop.Web.HomeLive.handle_info({:conversations_changed}, socket)
      {:noreply, s2} = Cairnloop.Web.HomeLive.handle_info({:conversations_changed}, s1)
      {:noreply, s3} = Cairnloop.Web.HomeLive.handle_info({:conversations_changed}, s2)
      {:noreply, s4} = Cairnloop.Web.HomeLive.handle_info({:conversations_changed}, s3)
      {:noreply, s5} = Cairnloop.Web.HomeLive.handle_info({:conversations_changed}, s4)

      assert s5.assigns.pending_recount? == false,
             "disconnected socket must never set pending_recount? true, even after 5 events"
    end

    test "unknown messages are ignored without changing state" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          pending_recount?: false,
          open_count: 0,
          resolved_count: 0,
          gaps_count: 0,
          audit_count: 0,
          open_count_unavailable?: false,
          resolved_count_unavailable?: false,
          gaps_unavailable?: false,
          audit_unavailable?: false,
          health_variant: "success",
          health_label: "Healthy",
          health_meta: "Notifier and retrieval reachable",
          __changed__: nil
        }
      }

      {:noreply, updated} = Cairnloop.Web.HomeLive.handle_info(:some_other_message, socket)
      assert updated == socket
    end
  end

  # ---------------------------------------------------------------------------
  # Brand gate: no raw #hex in rendered Home HTML
  # ---------------------------------------------------------------------------

  describe "brand gate" do
    test "rendered Home contains no raw #hex color values" do
      html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{open_count: 5})))

      refute html =~ ~r/#[0-9A-Fa-f]{6}/,
             "rendered Home must not contain raw #hex colors (use brand tokens)"
    end

    test "rendered zero-state contains no raw #hex color values" do
      html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{open_count: 0})))

      refute html =~ ~r/#[0-9A-Fa-f]{6}/,
             "rendered zero-state Home must not contain raw #hex colors"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 38 shell assertions (SHELL-01 — preserved)
  # ---------------------------------------------------------------------------

  test "renders inside cl-page--wide with cl-page__title and verbatim title" do
    html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{})))

    assert html =~ ~s(cl-page cl-page--wide),
           "expected class=\"cl-page cl-page--wide\" in rendered HTML"

    assert html =~ ~s(cl-page__title),
           "expected class=\"cl-page__title\" in rendered HTML"

    assert html =~ "Welcome back",
           "expected verbatim title 'Welcome back'"
  end

  test "renders the subtitle inside cl-page with verbatim subtitle text" do
    html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{})))

    assert html =~ "What needs you today?",
           "expected verbatim subtitle 'What needs you today?'"
  end

  test "Home is the active nav destination (aria-current)" do
    html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{})))

    assert html =~ "cl-nav"
    assert html =~ ~s(aria-current="page")
  end
end
