defmodule Cairnloop.Router do
  defmacro cairnloop_dashboard(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        # Host apps should provide `host_user_id` in the live session payload so
        # dashboard surfaces can keep operator search tenant-scoped.
        live_session :cairnloop_dashboard, opts do
          live("/", Cairnloop.Web.InboxLive, :index, as: :cairnloop_inbox)
          live("/audit-log", Cairnloop.Web.AuditLogLive, :index, as: :cairnloop_audit_log)
          live("/knowledge-base", Cairnloop.Web.KnowledgeBaseLive.Index, :index)
          live("/knowledge-base/gaps", Cairnloop.Web.KnowledgeBaseLive.Gaps, :index)

          live(
            "/knowledge-base/suggestions",
            Cairnloop.Web.KnowledgeBaseLive.SuggestionReview,
            :index
          )

          live("/knowledge-base/:id/edit", Cairnloop.Web.KnowledgeBaseLive.Editor, :edit)
          live("/settings", Cairnloop.Web.SettingsLive, :index, as: :cairnloop_settings)
          live("/:id", Cairnloop.Web.ConversationLive, :show, as: :cairnloop_conversation)
        end
      end
    end
  end
end
