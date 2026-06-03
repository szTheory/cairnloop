defmodule Cairnloop.Web.SettingsLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest

  alias Cairnloop.Web.SettingsLive

  defmodule MockRepo do
    def all(_query), do: []
  end

  setup do
    original_repo = Application.get_env(:cairnloop, :repo)
    Application.put_env(:cairnloop, :repo, MockRepo)
    on_exit(fn -> Application.put_env(:cairnloop, :repo, original_repo) end)
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

  defp render_html(assigns) do
    render_component(&SettingsLive.render/1, assigns)
  end
end
