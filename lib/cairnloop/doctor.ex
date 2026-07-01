defmodule Cairnloop.Doctor do
  @moduledoc """
  Diagnoses a host application's Cairnloop wiring and returns calm, reason-forward findings.

  This is the engine behind `mix cairnloop.doctor`. It is deliberately a pure-ish function over
  a host router module + the application environment so it can be unit-tested with a fabricated
  router and config (no live app required). Each check returns `{level, message}` where `level`
  is `:ok | :warn | :error`:

    - `:error` — Cairnloop will not work (e.g. no repo). The task exits non-zero.
    - `:warn`  — a surface is reachable-but-degraded or unmounted (e.g. audit log will render
      empty). Exits zero unless `--strict`.
    - `:ok`    — wired correctly.

  Checks are conservative: when the host router cannot be located, route-dependent checks are
  skipped with a single `:warn` rather than guessing (precise over alarming).
  """

  @type level :: :ok | :warn | :error
  @type finding :: {level(), String.t()}

  @prometheus_module TelemetryMetricsPrometheus.Core
  @noop_auditor Cairnloop.Auditor.NoOp

  @dashboard_live_views [
    Cairnloop.Web.InboxLive,
    Cairnloop.Web.AuditLogLive,
    Cairnloop.Web.ConversationLive,
    Cairnloop.Web.SettingsLive,
    Cairnloop.Web.KnowledgeBaseLive.Index
  ]

  @doc """
  Runs all diagnostics for the given host `router` module (or `nil` if it could not be resolved).

  `opts` may override config lookups for testing (e.g. `repo:`, `auditor:`, `tools:`); anything
  not given falls back to `Application.get_env(:cairnloop, key)`.
  """
  @spec checks(module() | nil, keyword()) :: [finding()]
  def checks(router, opts \\ []) do
    routes = safe_routes(router)
    handlers = route_handlers(routes)
    dashboard_mounted? = Enum.any?(@dashboard_live_views, &(&1 in handlers))
    metrics_mounted? = Cairnloop.Web.MetricsPlug in handlers

    repo = config(opts, :repo)

    [
      check_repo(repo),
      check_schema_prefix(opts),
      check_router(router),
      check_dashboard(router, dashboard_mounted?),
      check_audit_log(router, dashboard_mounted?, Cairnloop.Web.AuditLogLive in handlers),
      check_operations(router, Cairnloop.Web.HealthPlug in handlers, metrics_mounted?),
      check_metrics_dep(metrics_mounted?),
      check_auditor(config(opts, :auditor), dashboard_mounted?),
      check_tools(config(opts, :tools, [])),
      check_widget_verifier(config(opts, :widget_token_verifier)),
      check_email_webhook_auth(
        config(opts, :email_webhook_verifier),
        config(opts, :email_webhook_token)
      ),
      check_mcp_auth(repo),
      check_optional(config(opts, :context_provider), "context provider", :context_provider),
      check_notifier(config(opts, :notifier)),
      check_oban(),
      check_retrieval(),
      check_scrypath(opts)
    ]
    |> List.flatten()
  end

  @doc "Tallies findings by level: `%{ok: n, warn: n, error: n}`."
  @spec tally([finding()]) :: %{
          ok: non_neg_integer(),
          warn: non_neg_integer(),
          error: non_neg_integer()
        }
  def tally(findings) do
    Enum.reduce(findings, %{ok: 0, warn: 0, error: 0}, fn {level, _msg}, acc ->
      Map.update!(acc, level, &(&1 + 1))
    end)
  end

  # --- individual checks ----------------------------------------------------

  defp check_repo(nil),
    do:
      {:error,
       "Blocked: no `:cairnloop, :repo` is configured — Cairnloop cannot start. " <>
         "Add `config :cairnloop, repo: MyApp.Repo`."}

  defp check_repo(repo), do: {:ok, "Ready: Repo configured for #{module_name(repo)}."}

  defp check_schema_prefix(opts) do
    schema_opts =
      if Keyword.has_key?(opts, :schema_prefix) do
        [schema_prefix: Keyword.fetch!(opts, :schema_prefix)]
      else
        []
      end

    case Cairnloop.SchemaPrefix.configured(schema_opts) do
      "public" ->
        {:ok,
         "Ready: Cairnloop is explicitly configured for public-schema compatibility. " <>
           "Not checked here: doctor did not query information_schema or Cairnloop tables."}

      nil ->
        {:ok,
         "Ready: Cairnloop is using legacy public-schema compatibility. " <>
           "Not checked here: doctor did not query information_schema or Cairnloop tables."}

      prefix ->
        {:ok,
         "Ready: Cairnloop support tables are configured for Postgres schema `#{prefix}`. " <>
           "Not checked here: doctor did not query information_schema or Cairnloop tables."}
    end
  rescue
    ArgumentError ->
      {:error,
       "Blocked: Cairnloop schema prefix is invalid; expected nil, `public`, or a single SQL identifier. " <>
         "Not checked here: doctor did not query information_schema or Cairnloop tables."}
  end

  defp check_router(nil),
    do:
      {:warn,
       "Not checked here: Could not locate your Phoenix router, so route checks were skipped. " <>
         "Re-run with the router named explicitly: `mix cairnloop.doctor MyAppWeb.Router`."}

  defp check_router(router), do: {:ok, "Ready: Router found: #{module_name(router)}."}

  defp check_dashboard(nil, _), do: []

  defp check_dashboard(_router, true), do: {:ok, "Ready: Operator dashboard is mounted."}

  defp check_dashboard(_router, false),
    do:
      {:warn,
       "Blocked: the operator dashboard is not mounted, so operators cannot reach the inbox/KB/settings. " <>
         "Add `cairnloop_dashboard \"/support\"` inside a scope in your router."}

  defp check_audit_log(nil, _, _), do: []
  defp check_audit_log(_router, false, _), do: []
  defp check_audit_log(_router, true, true), do: {:ok, "Ready: Audit-log timeline is mounted."}

  defp check_audit_log(_router, true, false),
    do:
      {:warn,
       "Blocked: the dashboard is mounted but the audit-log route is not — operators lose the action " <>
         "timeline. Mount it via `cairnloop_dashboard/2` (it includes `/audit-log`)."}

  defp check_operations(nil, _, _), do: []

  defp check_operations(_router, true, _) do
    {:ok,
     "Ready: `/health` is mounted as liveness only. Not checked here: database, Oban, " <>
       "pgvector, notifier, ingress, MCP, and Scrypath readiness."}
  end

  defp check_operations(_router, false, _),
    do:
      {:warn,
       "Blocked: `/health` and `/metrics` are not mounted, so infrastructure cannot probe this app. " <>
         "Add `cairnloop_operations()` inside a scope in your router."}

  defp check_metrics_dep(false), do: []

  defp check_metrics_dep(true) do
    if Code.ensure_loaded?(@prometheus_module) do
      {:ok, "Ready: `/metrics` is mounted and the Prometheus core is available."}
    else
      {:warn,
       "Not checked here: `/metrics` is mounted but `:telemetry_metrics_prometheus_core` is not installed, " <>
         "so the endpoint will return 501. Add it to your deps to expose real metrics."}
    end
  end

  defp check_auditor(auditor, dashboard_mounted?)
       when (is_nil(auditor) or auditor == @noop_auditor) and dashboard_mounted? do
    {:warn,
     "Not checked here: the audit log is mounted but `:cairnloop, :auditor` is unset/no-op, so the timeline will " <>
       "render empty. Set `config :cairnloop, :auditor, Cairnloop.Auditor.Governance` to surface " <>
       "governed-action events."}
  end

  defp check_auditor(nil, _), do: {:ok, "Not checked here: no auditor configured."}

  defp check_auditor(auditor, _),
    do: {:ok, "Ready: Auditor configured for #{module_name(auditor)}."}

  defp check_tools([]),
    do: {:ok, "Ready: no governed tools registered (`:cairnloop, :tools` is empty)."}

  defp check_tools(tools) when is_list(tools),
    do: {:ok, "Ready: #{length(tools)} governed tool(s) registered."}

  defp check_tools(_other),
    do:
      {:error,
       "Blocked: `:cairnloop, :tools` must be a list of tool modules. " <>
         "Fix the value in your config."}

  defp check_widget_verifier(nil) do
    {:warn,
     "Blocked: Widget ingress is blocked because no host verifier is configured. " <>
       "Add `config :cairnloop, :widget_token_verifier, MyApp.WidgetVerifier` before accepting customer sessions in production."}
  end

  defp check_widget_verifier(Cairnloop.Widget.Verifier.FailClosed), do: check_widget_verifier(nil)

  defp check_widget_verifier({module, verifier_opts})
       when is_atom(module) and is_list(verifier_opts),
       do: check_widget_verifier_module(module)

  defp check_widget_verifier(module) when is_atom(module),
    do: check_widget_verifier_module(module)

  defp check_widget_verifier(_other) do
    {:warn,
     "Blocked: Widget ingress verifier config is not a module or `{module, opts}` pair. " <>
       "Fix `:widget_token_verifier` before accepting customer sessions."}
  end

  defp check_widget_verifier_module(module) do
    if loaded_callback?(module, :verify, 2) do
      {:ok, "Ready: Widget ingress has a host verifier configured."}
    else
      {:warn,
       "Blocked: Widget ingress verifier is configured but does not expose `verify/2`. " <>
         "Fix the host verifier module before accepting customer sessions."}
    end
  end

  defp check_email_webhook_auth(verifier, token) do
    cond do
      email_verifier_configured?(verifier) ->
        {:ok, "Ready: Email webhook request authentication is configured."}

      is_binary(token) and String.trim(token) != "" ->
        {:ok,
         "Ready: Email webhook shared-token authentication is configured. Doctor does not print shared tokens."}

      true ->
        {:warn,
         "Blocked: Email webhook ingress is blocked until the host configures request authentication. " <>
           "Set `:email_webhook_verifier` or `:email_webhook_token` before mounting the webhook in production."}
    end
  end

  defp email_verifier_configured?(nil), do: false
  defp email_verifier_configured?(verifier) when is_function(verifier, 1), do: true

  defp email_verifier_configured?({module, function}) when is_atom(module) and is_atom(function),
    do: loaded_callback?(module, function, 1)

  defp email_verifier_configured?(module) when is_atom(module),
    do: loaded_callback?(module, :verify, 1)

  defp email_verifier_configured?(_other), do: false

  defp check_mcp_auth(nil) do
    {:warn,
     "Blocked: MCP token validation cannot run until the Cairnloop repo is configured. " <>
       "Configure `:cairnloop, :repo` before exposing MCP JSON-RPC routes."}
  end

  defp check_mcp_auth(_repo) do
    [
      {:ok,
       "Ready: MCP token-required methods enforce Bearer authentication before `initialize`, `tools/list`, and `tools/call`."},
      {:ok,
       "Not checked here: doctor did not query stored MCP token rows. Generate a token in Settings or verify token presence with a DB-backed integration test."}
    ]
  end

  defp check_optional(nil, label, _key),
    do: {:ok, "Not checked here: no custom #{label} configured; using the default behavior."}

  defp check_optional(mod, label, _key),
    do: {:ok, "Ready: custom #{label} configured for #{module_name(mod)}."}

  defp check_notifier(nil) do
    {:ok,
     "Not checked here: No custom notifier configured. Outbound delivery callbacks stay no-op until the host configures `:notifier`."}
  end

  defp check_notifier(module) when is_atom(module) do
    callbacks = [
      on_conversation_resolved: 2,
      on_sla_breach: 3,
      on_outbound_triggered: 2
    ]

    if Enum.all?(callbacks, fn {function, arity} -> loaded_callback?(module, function, arity) end) do
      {:ok, "Ready: Notifier callbacks are configured."}
    else
      {:warn,
       "Blocked: Notifier is configured but required callbacks are not all available. " <>
         "Implement `on_conversation_resolved/2`, `on_sla_breach/3`, and `on_outbound_triggered/2`."}
    end
  end

  defp check_notifier(_other) do
    {:warn,
     "Blocked: Notifier config is not a module. Fix `:notifier` before relying on outbound delivery callbacks."}
  end

  defp check_oban do
    if Code.ensure_loaded?(Oban) do
      {:ok,
       "Ready: Oban is available. Not checked here: doctor did not inspect a running Oban supervisor or queue state."}
    else
      {:warn,
       "Blocked: Oban is not available to Cairnloop. Add and start Oban in the host app before relying on background jobs."}
    end
  end

  defp check_retrieval do
    if Code.ensure_loaded?(Pgvector) do
      {:ok,
       "Ready: pgvector library is available. Not checked here: doctor did not query the database, Oban queues, or pgvector indexes."}
    else
      {:warn,
       "Blocked: pgvector is not available, so retrieval embeddings cannot run. Add the dependency and database extension before relying on retrieval."}
    end
  end

  defp check_scrypath(opts) do
    case Cairnloop.ScrypathConfig.status(scrypath_opts(opts)) do
      :disabled ->
        {:ok,
         "Scrypath automation is disabled. Resolved conversations will stay inside Cairnloop unless the host opts in."}

      {:ready, _config} ->
        {:ok,
         "Ready: Scrypath automation is enabled with non-placeholder config. Not checked here: doctor did not contact Scrypath."}

      {:misconfigured, reasons} ->
        {:warn,
         "Blocked: Scrypath automation is enabled but not ready. " <>
           "Fix #{human_reasons(reasons)} before Cairnloop can enqueue external indexing."}
    end
  end

  # --- helpers --------------------------------------------------------------

  defp config(opts, key, default \\ nil) do
    Keyword.get_lazy(opts, key, fn -> Application.get_env(:cairnloop, key, default) end)
  end

  defp safe_routes(nil), do: []

  defp safe_routes(router) do
    if Code.ensure_loaded?(router) and function_exported?(router, :__routes__, 0) do
      router.__routes__()
    else
      []
    end
  rescue
    _ -> []
  end

  defp route_handlers(routes) do
    routes
    |> Enum.map(fn route ->
      case route do
        %{metadata: %{phoenix_live_view: {live_view, _action, _opts, _meta}}} -> live_view
        %{plug: plug} -> plug
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp loaded_callback?(module, function, arity) do
    Code.ensure_loaded?(module) and function_exported?(module, function, arity)
  end

  defp module_name(module) when is_atom(module) do
    module
    |> Atom.to_string()
    |> String.replace_prefix("Elixir.", "")
  end

  defp module_name(_other), do: "the configured host module"

  defp scrypath_opts(opts) do
    for key <- [
          :scrypath_automation_enabled,
          :scrypath_api_url,
          :scrypath_api_key,
          :scrypath_req_options
        ],
        Keyword.has_key?(opts, key) do
      {key, Keyword.fetch!(opts, key)}
    end
  end

  defp human_reasons(reasons) do
    reasons
    |> Enum.map(&human_reason/1)
    |> Enum.uniq()
    |> case do
      [] -> "the Scrypath host config"
      [reason] -> reason
      [first, second] -> first <> " and " <> second
      many -> Enum.join(Enum.drop(many, -1), ", ") <> ", and " <> List.last(many)
    end
  end

  defp human_reason(:missing_api_url), do: "missing API URL"
  defp human_reason(:missing_api_key), do: "missing API key"
  defp human_reason(:unsafe_api_url), do: "placeholder API URL"
  defp human_reason(:unsafe_api_key), do: "placeholder API key"
  defp human_reason(_reason), do: "the Scrypath host config"
end
