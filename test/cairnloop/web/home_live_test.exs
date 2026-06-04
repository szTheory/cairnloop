defmodule Cairnloop.Web.HomeLiveTest do
  @moduledoc """
  Headless render test for the Cockpit Home. Exercises `render/1` directly with
  built assigns so it needs no Repo — the DB-backed mount path is covered by the
  integration suite.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  defp assigns(overrides) do
    Map.merge(
      %{
        open_count: 0,
        resolved_count: 0,
        gaps_count: 0,
        audit_count: 0,
        health_ok?: true,
        health_label: "Healthy",
        __changed__: nil
      },
      Map.new(overrides)
    )
  end

  test "renders the five task-oriented job cards inside the nav shell" do
    html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{})))

    for job <- [
          "Work the queue",
          "Recover resolved",
          "Tend knowledge",
          "System health",
          "Audit trail"
        ] do
      assert html =~ job
    end

    assert html =~ "cl-nav"
    # Home is the active destination (you-are-here), not by color alone (aria-current).
    assert html =~ ~s(aria-current="page")
  end

  test "zero state reads as calm success, not an empty void" do
    html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{open_count: 0})))
    assert html =~ "All caught up"
    assert html =~ "cl-stat__count--calm"
  end

  test "non-zero queue surfaces an actionable count linking to the inbox" do
    html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{open_count: 7})))
    assert html =~ "7"
    assert html =~ "need a reply"
    assert html =~ ~s(href="/inbox")
  end

  test "unavailable counts degrade to a dash rather than crashing" do
    html = rendered_to_string(Cairnloop.Web.HomeLive.render(assigns(%{gaps_count: nil})))
    assert html =~ "—"
    assert html =~ "Knowledge gaps unavailable"
  end

  # ---------------------------------------------------------------------------
  # Phase 38 Task 1 — cl_page shell migration render assertions (SHELL-01).
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
end
