defmodule CairnloopExampleWeb.PageControllerTest do
  use CairnloopExampleWeb.ConnCase

  test "GET / renders the guided demo index", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    # The demo index frames the Trailmark scenario and links to the operator inbox + customer chat.
    assert html =~ "Support that leaves a trail"
    assert html =~ "Trailmark"
    assert html =~ ~s(href="/support")
    assert html =~ ~s(href="/chat")
  end
end
