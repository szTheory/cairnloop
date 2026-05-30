defmodule CairnloopExampleWeb.Router do
  use CairnloopExampleWeb, :router

  require Cairnloop.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CairnloopExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Cairnloop operator dashboard. Dogfood the shipped `cairnloop_dashboard/2` router macro — the
  # exact one-liner adopters use — instead of hand-copying its route list. This guarantees every
  # shipped surface (including `/support/audit-log`) is mounted and reachable here, so the example
  # app proves the macro rather than drifting from it.
  scope "/" do
    pipe_through :browser

    Cairnloop.Router.cairnloop_dashboard("/support",
      session: %{"host_user_id" => "demo_operator"}
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
