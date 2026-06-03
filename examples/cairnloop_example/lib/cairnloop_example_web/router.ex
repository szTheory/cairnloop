defmodule CairnloopExampleWeb.Router do
  use CairnloopExampleWeb, :router

  require Cairnloop.Router

  # Brings `fetch_current_operator/2` into scope as a function plug for the :browser pipeline,
  # mirroring how a phx.gen.auth app imports its `UserAuth` module.
  import CairnloopExampleWeb.OperatorAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CairnloopExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # Resolve the signed-in operator before any dashboard mount. In a real app this is your
    # phx.gen.auth `fetch_current_user` plug; here it falls back to a demo operator.
    plug :fetch_current_operator
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Cairnloop operator dashboard. Dogfood the shipped `cairnloop_dashboard/2` router macro — the
  # exact one-liner adopters use — instead of hand-copying its route list. This guarantees every
  # shipped surface (including `/support/audit-log`) is mounted and reachable here, so the example
  # app proves the macro rather than drifting from it.
  #
  # Identity is injected via the MFA `:session` form — the production pattern — not a static map.
  # `OperatorAuth.cairnloop_session/1` runs per request with the live `conn` and returns the real
  # operator's `host_user_id`. See the "Auth & Operator Identity" guide.
  scope "/" do
    pipe_through :browser

    Cairnloop.Router.cairnloop_dashboard("/support",
      session: {CairnloopExampleWeb.OperatorAuth, :cairnloop_session, []}
    )
  end

  scope "/", CairnloopExampleWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/chat", ChatLive
  end

  # Operations endpoints (OPS-01, OPS-02): GET /health and GET /metrics. Mounted
  # outside the :browser pipeline so infrastructure can probe them without CSRF/session.
  scope "/" do
    Cairnloop.Router.cairnloop_operations()
  end

  # Other scopes may use custom stacks.
  # scope "/api", CairnloopExampleWeb do
  #   pipe_through :api
  # end
end
