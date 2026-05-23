defmodule Cairnloop.Web.InboxLiveTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias Cairnloop.Web.InboxLive

  test "renders the inbox and mounts the search modal with explicit scope context" do
    assigns = %{
      host_user_id: "user_42",
      conversations: [
        %Cairnloop.Conversation{id: 7, subject: "Refund request", status: :open}
      ]
    }

    html = render_html(assigns)

    assert html =~ "Inbox"
    assert html =~ "Refund request"
    assert html =~ "data-host-surface=\"inbox\""
    assert html =~ "data-host-user-id=\"user_42\""
    assert html =~ "data-current-path=\"/\""
  end

  defp render_html(assigns) do
    render_component(&InboxLive.render/1, assigns)
  end
end
