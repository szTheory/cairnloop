defmodule Mix.Tasks.Cairnloop.Install.Slos do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :cairnloop,
      schema: [],
      defaults: []
    }
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_module = Igniter.Project.Application.app_module(igniter)
    slos_module = Module.concat([app_module, Cairnloop, SLOs])
    doctor_module = Module.concat([app_module, Cairnloop, Doctor])

    slos_contents = """
    @moduledoc "Cairnloop SLO definitions"

    # Example template, replace with actual Parapet.SLO.define
    def slos do
      [
        Parapet.SLO.define(
          name: "TTFR",
          description: "Time to First Response",
          target: 95.0,
          window: "30d"
        ),
        Parapet.SLO.define(
          name: "Resolution Time",
          description: "Time to Resolve",
          target: 90.0,
          window: "30d"
        ),
        Parapet.SLO.define(
          name: "System Health",
          description: "Overall System Health",
          target: 99.9,
          window: "30d"
        )
      ]
    end
    """

    doctor_contents = """
    @moduledoc "Cairnloop Doctor checks"

    def checks do
      [
        # Doctor checks
      ]
    end
    """

    # Create modules
    igniter = 
      igniter
      |> Igniter.Project.Module.create_module(slos_module, slos_contents)
      |> Igniter.Project.Module.create_module(doctor_module, doctor_contents)

    # Create runbooks
    runbook_dir = "priv/runbooks"

    ttfr_runbook = """
    # TTFR Breach Runbook
    Respond to TTFR breach.
    """

    resolution_runbook = """
    # Resolution Time Breach Runbook
    Respond to Resolution Time breach.
    """

    health_runbook = """
    # System Health Breach Runbook
    Respond to System Health breach.
    """

    igniter
    |> Igniter.create_new_file(Path.join(runbook_dir, "cairnloop_ttfr_breach.md"), ttfr_runbook)
    |> Igniter.create_new_file(Path.join(runbook_dir, "cairnloop_resolution_breach.md"), resolution_runbook)
    |> Igniter.create_new_file(Path.join(runbook_dir, "cairnloop_system_health.md"), health_runbook)
  end
end
