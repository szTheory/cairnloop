defmodule CairnloopExampleWeb.Router do
  use CairnloopExampleWeb, :router

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

  scope "/support", alias: false, as: false do
    pipe_through :browser

    live_session :cairnloop_dashboard, session: %{"host_user_id" => "demo_operator"} do
      live("/", Cairnloop.Web.InboxLive, :index, as: :cairnloop_inbox)
      live("/knowledge-base", Cairnloop.Web.KnowledgeBaseLive.Index, :index)
      live("/knowledge-base/gaps", Cairnloop.Web.KnowledgeBaseLive.Gaps, :index)
      live("/knowledge-base/suggestions", Cairnloop.Web.KnowledgeBaseLive.SuggestionReview, :index)
      live("/knowledge-base/:id/edit", Cairnloop.Web.KnowledgeBaseLive.Editor, :edit)
      live("/settings", Cairnloop.Web.SettingsLive, :index, as: :cairnloop_settings)
      live("/:id", Cairnloop.Web.ConversationLive, :show, as: :cairnloop_conversation)
    end
  end

  scope "/", CairnloopExampleWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/chat", ChatLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", CairnloopExampleWeb do
  #   pipe_through :api
  # end
end
