defmodule Cairnloop.Router do
  defmacro cairnloop_dashboard(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        live_session :cairnloop_dashboard, opts do
          live("/", Cairnloop.Web.InboxLive, :index, as: :cairnloop_inbox)
          live("/settings", Cairnloop.Web.SettingsLive, :index, as: :cairnloop_settings)
          live("/:id", Cairnloop.Web.ConversationLive, :show, as: :cairnloop_conversation)
        end
      end
    end
  end
end
