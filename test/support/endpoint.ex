defmodule Cairnloop.Web.Endpoint do
  @moduledoc """
  Minimal Phoenix Endpoint for the integration suite — `server: false` (no port bound),
  just enough to drive `Phoenix.LiveViewTest`. Test-only (`elixirc_paths(:test)`).
  """
  use Phoenix.Endpoint, otp_app: :cairnloop

  @session_options [
    store: :cookie,
    key: "_cairnloop_test_key",
    signing_salt: "cairnloop_test_cookie_salt",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.Session, @session_options)
  plug(Cairnloop.Web.TestRouter)
end
