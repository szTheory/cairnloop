defmodule Cairnloop.Web.TestRouter do
  @moduledoc """
  Test-only router that mounts real LiveViews inside a `live_session` (the genuine
  LiveView mount path Phase 15 Item 4 + Phase 25 bulk-recovery UAT exercise).
  Test-only (`elixirc_paths(:test)`).

  Mounted LiveViews:
  - `/governance/:id` → `Cairnloop.Web.ConversationLive` (Phase 15 approval footer).
  - `/inbox` → `Cairnloop.Web.InboxLive` (Phase 25 bulk-recovery cockpit).

  NOTE: We mount the route directly rather than via `Cairnloop.Router.cairnloop_dashboard/2`.
  That macro restricts its internal `import Phoenix.LiveView.Router` to `live: 4` while its
  own routes also call `live/3`; it only compiles when the *host* router's full import wins.
  Reproducing that here would mean touching sealed Phase 14 code — the macro is out of scope
  for this integration harness, which targets the Phase 15 approval footer + Phase 25 bulk
  behaviors.
  """
  use Phoenix.Router

  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {Cairnloop.Web.TestLayouts, :root})
  end

  scope "/" do
    pipe_through(:browser)

    live_session :cairnloop_test do
      live("/governance/:id", Cairnloop.Web.ConversationLive, :show)
      live("/inbox", Cairnloop.Web.InboxLive, :index)
    end
  end
end
