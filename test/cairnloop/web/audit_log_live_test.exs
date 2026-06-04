defmodule Cairnloop.Web.AuditLogLiveTest do
  @moduledoc """
  Headless render test for the Audit Log LiveView. Exercises `render/1` directly
  with built assigns so it needs no Repo — the DB-backed mount path is covered by
  the integration suite.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  defp base_assigns do
    %{
      visible_events: [],
      query: "",
      action_filter: "all",
      action_options: [],
      maybe_more?: false,
      __changed__: nil
    }
  end

  # ---------------------------------------------------------------------------
  # Phase 38 Task 2 — cl_page shell migration render assertions (SHELL-01).
  # ---------------------------------------------------------------------------

  describe "Phase 38 SHELL-01 — Audit Log cl_page migration" do
    test "Test 1 (Audit Log): rendered HTML contains cl-page cl-page--wide" do
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(base_assigns()))

      assert html =~ ~s(cl-page cl-page--wide),
             "expected class=\"cl-page cl-page--wide\" in rendered HTML"
    end

    test "Test 1 (Audit Log): rendered HTML contains cl-page__title with verbatim 'Audit Log'" do
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(base_assigns()))

      assert html =~ ~s(cl-page__title),
             "expected class=\"cl-page__title\" in rendered HTML"

      assert html =~ "Audit Log",
             "expected verbatim text 'Audit Log'"
    end

    test "Test 1 (Audit Log): rendered HTML contains the subtitle text" do
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(base_assigns()))

      assert html =~ "A timeline of governed actions",
             "expected subtitle text 'A timeline of governed actions' in rendered HTML"
    end

    test "Test 1 (Audit Log): filter form markup stays in the card body (not in :actions)" do
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(base_assigns()))

      # The filter form (phx-change="filter") must still be present — it stays in
      # the card body (D-04: substantial filter bars stay in body, NOT in :actions).
      assert html =~ ~s(phx-change="filter"),
             "expected filter form markup in rendered HTML — filter bar must stay in body"

      assert html =~ ~s(phx-change="search"),
             "expected search form markup in rendered HTML — search bar must stay in body"
    end
  end
end
