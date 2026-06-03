defmodule Cairnloop.Web.ComponentsTest do
  @moduledoc """
  Headless render tests for the shared `.cl-*` component library. No Repo/DB needed —
  these are pure function components, so they run in the fast default suite.
  """
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import Cairnloop.Web.Components

  test "cl_button renders variant + size classes and content" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_button variant="primary" size="lg" phx-click="save">Save policy</.cl_button>
      """)

    assert html =~ "cl-button"
    assert html =~ "cl-button--primary"
    assert html =~ "cl-button--lg"
    assert html =~ ~s(phx-click="save")
    assert html =~ "Save policy"
  end

  test "cl_chip pairs color + icon + text (never state-by-color-alone)" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_chip variant="warning" label="Needs review" />
      """)

    assert html =~ "cl-chip--warning"
    # a distinct-silhouette icon is present (the SVG), not color alone
    assert html =~ "<svg"
    assert html =~ "Needs review"
  end

  test "cl_banner has a status role and renders its message + icon" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_banner variant="danger">Outbound delivery failed.</.cl_banner>
      """)

    assert html =~ ~s(role="status")
    assert html =~ "cl-banner--danger"
    assert html =~ "<svg"
    assert html =~ "Outbound delivery failed."
  end

  test "cl_stat renders an actionable count card linking to its queue" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_stat job="Triage replies" count={7} meta="need your approval" href="/inbox" cta="Open inbox" />
      """)

    assert html =~ "cl-stat"
    assert html =~ "Triage replies"
    assert html =~ "7"
    assert html =~ ~s(href="/inbox")
  end

  test "cl_shell marks the active destination with aria-current (you-are-here)" do
    assigns = %{
      dests: [
        %{key: :home, label: "Home", href: "/", icon: "home", count: nil},
        %{key: :inbox, label: "Inbox", href: "/inbox", icon: "inbox", count: 3}
      ]
    }

    html =
      rendered_to_string(~H"""
      <.cl_shell current={:inbox} destinations={@dests}>
        <p>body</p>
      </.cl_shell>
      """)

    assert html =~ "cl-nav"
    assert html =~ ~s(aria-current="page")
    # count badge appears for the inbox (3), not for home (nil)
    assert html =~ "cl-chip"
    assert html =~ "body"
  end

  test "cl_icon renders a self-contained inline svg (no icon-font dependency)" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_icon name="check-circle" />
      """)

    assert html =~ "<svg"
    assert html =~ "polyline" or html =~ "path"
    assert html =~ ~s(aria-hidden="true")
  end
end
