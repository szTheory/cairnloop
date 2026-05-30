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

    [
      check_repo(config(opts, :repo)),
      check_router(router),
      check_dashboard(router, dashboard_mounted?),
      check_audit_log(router, dashboard_mounted?, Cairnloop.Web.AuditLogLive in handlers),
      check_operations(router, Cairnloop.Web.HealthPlug in handlers, metrics_mounted?),
      check_metrics_dep(metrics_mounted?),
      check_auditor(config(opts, :auditor), dashboard_mounted?),
      check_tools(config(opts, :tools, [])),
      check_optional(config(opts, :context_provider), "context provider", :context_provider),
      check_optional(config(opts, :notifier), "notifier", :notifier)
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
       "No `:cairnloop, :repo` is configured — Cairnloop cannot start. " <>
         "Add `config :cairnloop, repo: MyApp.Repo`."}

  defp check_repo(repo), do: {:ok, "Repo configured (#{inspect(repo)})."}

  defp check_router(nil),
    do:
      {:warn,
       "Could not locate your Phoenix router — route checks were skipped. " <>
         "Re-run with the router named explicitly: `mix cairnloop.doctor MyAppWeb.Router`."}

  defp check_router(router), do: {:ok, "Router found (#{inspect(router)})."}

  defp check_dashboard(nil, _), do: []

  defp check_dashboard(_router, true), do: {:ok, "Operator dashboard is mounted."}

  defp check_dashboard(_router, false),
    do:
      {:warn,
       "The operator dashboard is not mounted, so operators cannot reach the inbox/KB/settings. " <>
         "Add `cairnloop_dashboard \"/support\"` inside a scope in your router."}

  defp check_audit_log(nil, _, _), do: []
  defp check_audit_log(_router, false, _), do: []
  defp check_audit_log(_router, true, true), do: {:ok, "Audit-log timeline is mounted."}

  defp check_audit_log(_router, true, false),
    do:
      {:warn,
       "The dashboard is mounted but the audit-log route is not — operators lose the action " <>
         "timeline. Mount it via `cairnloop_dashboard/2` (it includes `/audit-log`)."}

  defp check_operations(nil, _, _), do: []
  defp check_operations(_router, true, _), do: {:ok, "`/health` is mounted."}

  defp check_operations(_router, false, _),
    do:
      {:warn,
       "`/health` and `/metrics` are not mounted, so infrastructure cannot probe this app. " <>
         "Add `cairnloop_operations()` inside a scope in your router."}

  defp check_metrics_dep(false), do: []

  defp check_metrics_dep(true) do
    if Code.ensure_loaded?(@prometheus_module) do
      {:ok, "`/metrics` is mounted and the Prometheus core is available."}
    else
      {:warn,
       "`/metrics` is mounted but `:telemetry_metrics_prometheus_core` is not installed, " <>
         "so the endpoint will return 501. Add it to your deps to expose real metrics."}
    end
  end

  defp check_auditor(auditor, dashboard_mounted?)
       when (is_nil(auditor) or auditor == @noop_auditor) and dashboard_mounted? do
    {:warn,
     "The audit log is mounted but `:cairnloop, :auditor` is unset/no-op, so the timeline will " <>
       "render empty. Set `config :cairnloop, :auditor, Cairnloop.Auditor.Governance` to surface " <>
       "governed-action events."}
  end

  defp check_auditor(nil, _), do: {:ok, "Auditor: using the default (no audit timeline)."}
  defp check_auditor(auditor, _), do: {:ok, "Auditor configured (#{inspect(auditor)})."}

  defp check_tools([]),
    do: {:ok, "No governed tools registered (`:cairnloop, :tools` is empty)."}

  defp check_tools(tools) when is_list(tools),
    do: {:ok, "#{length(tools)} governed tool(s) registered."}

  defp check_tools(_other),
    do:
      {:error,
       "`:cairnloop, :tools` must be a list of tool modules. " <>
         "Fix the value in your config."}

  defp check_optional(nil, label, _key),
    do: {:ok, "No custom #{label} configured (using default)."}

  defp check_optional(mod, label, _key),
    do: {:ok, "Custom #{label} configured (#{inspect(mod)})."}

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
end
