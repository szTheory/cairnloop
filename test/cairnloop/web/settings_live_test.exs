defmodule Cairnloop.Web.SettingsLiveTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cairnloop.Web.SettingsLive

  test "renders SLA policies and mounts the shared search palette with settings context" do
    assigns = %{
      flash: %{},
      priorities: [:low, :normal, :high, :urgent],
      policies: [
        %{
          priority: :normal,
          target_first_response_minutes: 30,
          target_resolution_minutes: 240
        }
      ]
    }

    html = render_html(assigns)

    assert html =~ "SLA Policies"
    assert html =~ "Active Policies"
    assert html =~ "data-host-surface=\"settings\""
    assert html =~ "data-current-path=\"/settings\""
  end

  defp render_html(assigns) do
    render_component(&SettingsLive.render/1, assigns)
  end
end
