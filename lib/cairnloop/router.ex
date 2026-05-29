defmodule Cairnloop.Router do
  @doc """
  Mounts the operations endpoints a host needs for monitoring (OPS-01, OPS-02):

    - `GET /health` → `Cairnloop.Web.HealthPlug` (liveness/readiness probe, 200 JSON).
    - `GET /metrics` → `Cairnloop.Web.MetricsPlug` (Prometheus text; 501 until
      `:telemetry_metrics_prometheus_core` is added).

  Call it from your host router, typically outside any authentication pipeline so
  infrastructure can reach the probes:

      scope "/" do
        cairnloop_operations()
      end

  Options:
    - `:health_path` — override the health path (default `"/health"`).
    - `:metrics_path` — override the metrics path (default `"/metrics"`).
  """
  defmacro cairnloop_operations(opts \\ []) do
    health_path = Keyword.get(opts, :health_path, "/health")
    metrics_path = Keyword.get(opts, :metrics_path, "/metrics")

    quote do
      forward(unquote(health_path), Cairnloop.Web.HealthPlug)
      forward(unquote(metrics_path), Cairnloop.Web.MetricsPlug)
    end
  end

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
