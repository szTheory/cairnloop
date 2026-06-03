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

  # --- cl_stat numeric contract (UIC-02 / D-01) ---

  test "cl_stat renders an integer count inside .cl-stat__count" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_stat job="Triage replies" count={42} href="/inbox" />
      """)

    assert html =~ ~s(cl-stat__count)
    assert html =~ "42"
    assert html =~ "Triage replies"
    refute html =~ ~r/#[0-9a-fA-F]{3,6}/
  end

  test "cl_stat preserves job label and href with integer count" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_stat job="Open conversations" count={0} href="/inbox" calm?={true} />
      """)

    assert html =~ "Open conversations"
    assert html =~ ~s(href="/inbox")
    assert html =~ "cl-stat__count--calm"
    refute html =~ ~r/#[0-9a-fA-F]{3,6}/
  end

  # --- cl_page shell component (UIC-01 / D-08) ---

  test "cl_page renders title as h1 and emits cl-page--wide by default" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_page title="Audit Log">
        <p>content</p>
      </.cl_page>
      """)

    assert html =~ ~s(<h1 class="cl-page__title">Audit Log</h1>)
    assert html =~ "cl-page--wide"
    assert html =~ "content"
    refute html =~ ~r/#[0-9a-fA-F]{3,6}/
  end

  test "cl_page with width='reading' renders cl-page--reading" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_page title="Conversation" width="reading">
        <p>body</p>
      </.cl_page>
      """)

    assert html =~ "cl-page--reading"
    refute html =~ ~r/#[0-9a-fA-F]{3,6}/
  end

  test "cl_page renders breadcrumb, actions, subnav slots and subtitle when provided" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_page title="Inbox" subtitle="Manage your queue">
        <:breadcrumb><nav>Home / Inbox</nav></:breadcrumb>
        <:actions><button>New</button></:actions>
        <:subnav><ul><li>Filter</li></ul></:subnav>
        <p>main content</p>
      </.cl_page>
      """)

    assert html =~ "cl-page__subtitle"
    assert html =~ "Manage your queue"
    assert html =~ "Home / Inbox"
    assert html =~ "New"
    assert html =~ "Filter"
    assert html =~ "main content"
    refute html =~ ~r/#[0-9a-fA-F]{3,6}/
  end

  test "cl_page token-pure: no hex in default render" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_page title="Settings">
        <p>content</p>
      </.cl_page>
      """)

    refute html =~ ~r/#[0-9a-fA-F]{3,6}/
  end

  # --- cl_hero primary-count component (UIC-02 / D-02) ---

  test "cl_hero renders integer count inside .cl-hero__count and job label" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_hero count={128} job="Work the queue" />
      """)

    assert html =~ "cl-hero__count"
    assert html =~ "128"
    assert html =~ "cl-hero__job"
    assert html =~ "Work the queue"
    refute html =~ ~r/#[0-9a-fA-F]{3,6}/
  end

  test "cl_hero with calm?={true} renders .cl-hero__count--calm" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_hero count={0} job="Work the queue" calm?={true} />
      """)

    assert html =~ "cl-hero__count--calm"
    refute html =~ ~r/#[0-9a-fA-F]{3,6}/
  end

  test "cl_hero with cta and href renders a cl_button primary CTA; detail slot renders cl-hero__detail" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_hero count={5} job="Work the queue" cta="Open inbox" href="/inbox">
        <:detail>2 recovered recently</:detail>
      </.cl_hero>
      """)

    assert html =~ "cl-button--primary"
    assert html =~ "Open inbox"
    assert html =~ "cl-hero__detail"
    assert html =~ "2 recovered recently"
    refute html =~ ~r/#[0-9a-fA-F]{3,6}/
  end

  test "cl_hero token-pure: no hex in rendered output" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.cl_hero count={42} job="Recover resolved" />
      """)

    refute html =~ ~r/#[0-9a-fA-F]{3,6}/
  end
end
