defmodule Cairnloop.Router do
  @moduledoc """
  Host-router macros for mounting Cairnloop's operator surfaces.

  Cairnloop is host-owned: you mount its operations endpoints and operator dashboard into
  *your* router, under *your* pipelines, so auth, session, layout, and route placement stay
  yours. See `cairnloop_operations/1` and `cairnloop_dashboard/2`.
  """

  @operations_opts_schema NimbleOptions.new!(
                            health_path: [
                              type: :string,
                              default: "/health",
                              doc: "Path the `/health` liveness probe is mounted at."
                            ],
                            metrics_path: [
                              type: :string,
                              default: "/metrics",
                              doc: "Path the `/metrics` Prometheus scrape endpoint is mounted at."
                            ]
                          )

  @dashboard_opts_schema NimbleOptions.new!(
                           live_session_name: [
                             type: :atom,
                             default: :cairnloop_dashboard,
                             doc:
                               "Name of the generated `live_session`. Override when mounting the " <>
                                 "dashboard more than once in a single host router, so the two " <>
                                 "`live_session` names do not collide."
                           ]
                         )

  @doc """
  Mounts the operations endpoints a host needs for monitoring (OPS-01, OPS-02):

    - `GET /health` → `Cairnloop.Web.HealthPlug` (liveness only, 200 JSON).
    - `GET /metrics` → `Cairnloop.Web.MetricsPlug` (Prometheus text; 501 until
      `:telemetry_metrics_prometheus_core` is added).

  Call it from your host router, typically outside any authentication pipeline so
  infrastructure can reach the probes:

      scope "/" do
        cairnloop_operations()
      end

  ## Options

  #{NimbleOptions.docs(@operations_opts_schema)}
  """
  defmacro cairnloop_operations(opts \\ []) do
    opts = NimbleOptions.validate!(opts, @operations_opts_schema)
    health_path = opts[:health_path]
    metrics_path = opts[:metrics_path]

    quote do
      forward(unquote(health_path), Cairnloop.Web.HealthPlug)
      forward(unquote(metrics_path), Cairnloop.Web.MetricsPlug)
    end
  end

  @doc """
  Mounts the Cairnloop operator dashboard (inbox, conversations, knowledge base, settings, and
  the audit-log timeline) under `path` as a single `Phoenix.LiveView` `live_session`.

  Wrap it in your own `scope` so auth/session/layout stay host-owned — Cairnloop does not embed
  auth:

      scope "/support" do
        pipe_through [:browser, :require_admin]

        cairnloop_dashboard "/",
          on_mount: [{MyAppWeb.UserAuth, :ensure_admin}],
          session: {MyAppWeb.UserAuth, :cairnloop_session, []}
      end

  ## Operator identity (`host_user_id`)

  Cairnloop uses the `host_user_id` value in the live session as the **operator's identity** — it
  is the actor recorded on governed audit events and the scope key for operator search. Provide it
  through the `:session` option, and use the **MFA form** so each request carries the *actually
  signed-in* operator:

      def cairnloop_session(conn) do
        %{"host_user_id" => to_string(conn.assigns.current_user.id)}
      end

  A static `session: %{"host_user_id" => "demo_operator"}` map is fine for a single-operator demo,
  but it is frozen at compile time and is identical for every request — ship it and your audit log
  attributes every operator's actions to one placeholder id. See the
  [Auth & Operator Identity](07-auth-and-operator-identity.html) guide for the full pattern.

  Any option other than the Cairnloop-specific ones below is forwarded verbatim to
  `Phoenix.LiveView.Router.live_session/3` (e.g. `:session`, `:on_mount`, `:root_layout`,
  `:layout`).

  ## Options

  #{NimbleOptions.docs(@dashboard_opts_schema)}
  """
  defmacro cairnloop_dashboard(path, opts \\ []) do
    # Split Cairnloop's own options from the live_session pass-through options, validate ours,
    # and forward the rest unchanged. Done at expansion so a bad `:live_session_name` raises a
    # clear compile-time error instead of a confusing Phoenix failure.
    {cairnloop_opts, session_opts} = Keyword.split(opts, [:live_session_name])
    cairnloop_opts = NimbleOptions.validate!(cairnloop_opts, @dashboard_opts_schema)
    live_session_name = cairnloop_opts[:live_session_name]
    session_opts = put_dashboard_session(session_opts, path)

    quote do
      scope unquote(path), alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 3, live: 4, live_session: 3]

        # Host apps should provide `host_user_id` in the live session payload so
        # dashboard surfaces can keep operator search tenant-scoped.
        live_session unquote(live_session_name), unquote(session_opts) do
          # Cockpit Home is the task-oriented landing; the inbox moves to /inbox so
          # an operator who lands on "/" is oriented, not dumped into a bare list.
          live("/", Cairnloop.Web.HomeLive, :index, as: :cairnloop_home)
          live("/inbox", Cairnloop.Web.InboxLive, :index, as: :cairnloop_inbox)
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

  def dashboard_session(conn, dashboard_path, original_session) do
    original_session
    |> evaluate_dashboard_session(conn)
    |> Map.put("cairnloop_dashboard_path", normalize_dashboard_path(dashboard_path))
  end

  defp put_dashboard_session(session_opts, path) do
    default_session = quote(do: %{})

    Keyword.update(session_opts, :session, default_session, fn original_session ->
      quote do
        {Cairnloop.Router, :dashboard_session, [unquote(path), unquote(original_session)]}
      end
    end)
  end

  defp evaluate_dashboard_session({module, function, args}, conn) when is_list(args) do
    module
    |> apply(function, [conn | args])
    |> normalize_dashboard_session()
  end

  defp evaluate_dashboard_session(session, _conn), do: normalize_dashboard_session(session)

  defp normalize_dashboard_session(session) when is_map(session), do: session
  defp normalize_dashboard_session(session) when is_list(session), do: Map.new(session)
  defp normalize_dashboard_session(_session), do: %{}

  defp normalize_dashboard_path(nil), do: ""
  defp normalize_dashboard_path(""), do: ""
  defp normalize_dashboard_path("/"), do: ""
  defp normalize_dashboard_path(path) when is_binary(path), do: String.trim_trailing(path, "/")
  defp normalize_dashboard_path(_path), do: ""
end
