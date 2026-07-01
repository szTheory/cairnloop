defmodule Cairnloop.Web.SettingsLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest

  alias Cairnloop.Web.SettingsLive

  defmodule MockRepo do
    def all(_query), do: []
  end

  setup do
    original_repo = Application.get_env(:cairnloop, :repo)
    original_sla_policy_provider = Application.get_env(:cairnloop, :sla_policy_provider)
    Application.put_env(:cairnloop, :repo, MockRepo)
    Application.put_env(:cairnloop, :sla_policy_provider, Cairnloop.DefaultSLAPolicyProvider)

    on_exit(fn ->
      Application.put_env(:cairnloop, :repo, original_repo)

      if original_sla_policy_provider do
        Application.put_env(:cairnloop, :sla_policy_provider, original_sla_policy_provider)
      else
        Application.delete_env(:cairnloop, :sla_policy_provider)
      end
    end)

    :ok
  end

  test "mount/3 stores host_user_id from the dashboard session" do
    {:ok, socket} =
      SettingsLive.mount(%{}, %{"host_user_id" => "user_42"}, %Phoenix.LiveView.Socket{})

    assert socket.assigns.host_user_id == "user_42"
  end

  test "renders SLA policies and mounts the shared search palette with explicit scope context" do
    assigns = %{
      flash: %{},
      host_user_id: "user_42",
      priorities: [:low, :normal, :high, :urgent],
      notifier_health: "Healthy",
      retrieval_health: "Healthy",
      tokens: [],
      new_raw_token: nil,
      policies: [
        %{
          priority: :normal,
          target_first_response_minutes: 30,
          target_resolution_minutes: 240
        }
      ]
    }

    html = render_html(assigns)

    assert html =~ "SLA policies"
    assert html =~ "Active policies"
    # persistent nav shell present with a "you are here" cue on Settings
    assert html =~ "cl-nav"
    assert html =~ "aria-current=\"page\""
    assert html =~ "data-host-surface=\"settings\""
    assert html =~ "data-host-user-id=\"user_42\""
    assert html =~ "data-current-path=\"/settings\""
  end

  # ---------------------------------------------------------------------------
  # Phase 38 Task 2 — cl_page shell migration render assertions (SHELL-01).
  # ---------------------------------------------------------------------------

  describe "Phase 38 SHELL-01 — Settings cl_page migration" do
    defp base_assigns do
      %{
        flash: %{},
        host_user_id: "user_42",
        priorities: [:low, :normal, :high, :urgent],
        notifier_health: "Healthy",
        retrieval_health: "Healthy",
        tokens: [],
        new_raw_token: nil,
        policies: []
      }
    end

    test "Test 2 (Settings): rendered HTML contains cl-page cl-page--wide" do
      html = render_html(base_assigns())

      assert html =~ ~s(cl-page cl-page--wide),
             "expected class=\"cl-page cl-page--wide\" in rendered HTML"
    end

    test "Test 2 (Settings): rendered HTML contains cl-page__title with verbatim 'Settings'" do
      html = render_html(base_assigns())

      assert html =~ ~s(cl-page__title),
             "expected class=\"cl-page__title\" in rendered HTML"

      assert html =~ "Settings",
             "expected verbatim text 'Settings'"
    end

    test "Test 2 (Settings): Toggle dark mode button is in the :actions header region" do
      html = render_html(base_assigns())

      assert html =~ "Toggle dark mode",
             "expected 'Toggle dark mode' button text in rendered HTML"

      # The button must appear inside the cl-page header before the cl-page__body.
      # Both the title and the button must be inside cl-page__header (before cl-page__body).
      header_to_body = html |> String.split("cl-page__body") |> List.first()

      assert header_to_body =~ "Toggle dark mode",
             "expected 'Toggle dark mode' to appear in the cl-page header region (before cl-page__body), not just in the body"
    end
  end

  defp render_html(assigns) do
    render_component(&SettingsLive.render/1, assigns)
  end
end
