defmodule Mix.Tasks.Cairnloop.Doctor do
  @shortdoc "Check that your app's Cairnloop wiring is complete and reachable"

  @moduledoc """
  Diagnoses your host application's Cairnloop wiring and prints calm, reason-forward findings.

  It inspects your router and `:cairnloop` config to catch the "compiles but isn't wired"
  problems that are easy to miss: a dashboard or `/health` route that was never mounted, a
  `/metrics` endpoint that will 501 because the optional Prometheus dependency is absent, or an
  audit log that will render empty because no auditor is configured.

  ## Usage

      # Infer your router (<App>Web.Router):
      mix cairnloop.doctor

      # Name the router explicitly (umbrellas / non-standard names):
      mix cairnloop.doctor MyAppWeb.Router

      # Treat warnings as failures (CI):
      mix cairnloop.doctor --strict

  ## Exit codes

  - `0` — no blocking issues (warnings allowed unless `--strict`).
  - `1` — at least one blocking issue (or any warning under `--strict`).
  """

  use Mix.Task

  alias Cairnloop.Doctor

  @impl Mix.Task
  def run(args) do
    {opts, rest, _} = OptionParser.parse(args, strict: [strict: :boolean])
    strict? = Keyword.get(opts, :strict, false)

    # Load config (populates Application env) without starting the supervision tree.
    Mix.Task.run("app.config")

    router = resolve_router(rest)
    findings = Doctor.checks(router)

    Mix.shell().info("\nCairnloop doctor\n")
    Enum.each(findings, &print_finding/1)

    counts = Doctor.tally(findings)
    Mix.shell().info("\n" <> summary(counts))

    cond do
      counts.error > 0 ->
        System.halt(1)

      strict? and counts.warn > 0 ->
        Mix.shell().info("\n(--strict: treating items to review as failures)")
        System.halt(1)

      true ->
        :ok
    end
  end

  defp print_finding({:ok, msg}), do: Mix.shell().info([:green, "  [ok] ", :reset, msg])
  defp print_finding({:warn, msg}), do: Mix.shell().info([:yellow, "  [check] ", :reset, msg])
  defp print_finding({:error, msg}), do: Mix.shell().info([:red, "  [blocked] ", :reset, msg])

  defp summary(%{ok: ok, warn: warn, error: error}) do
    "#{ok} ok · #{warn} to review · #{error} blocking"
  end

  defp resolve_router([name | _]) when is_binary(name) do
    mod = Module.concat([name])
    if loadable_router?(mod), do: mod, else: nil
  end

  defp resolve_router([]) do
    case Mix.Project.config()[:app] do
      nil ->
        nil

      app ->
        base = app |> to_string() |> Macro.camelize()

        [Module.concat([base <> "Web", "Router"]), Module.concat([base, "Router"])]
        |> Enum.find(&loadable_router?/1)
    end
  end

  defp loadable_router?(mod) do
    Code.ensure_loaded?(mod) and function_exported?(mod, :__routes__, 0)
  end
end
