defmodule Mix.Tasks.Cairnloop.Install.Parapet do
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
    module_name = Module.concat(app_module, CairnloopInstrumenter)

    contents = """
    import Telemetry.Metrics

    @doc "Returns the telemetry metrics definitions for Cairnloop SLIs."
    def metrics do
      [
        # Resolution Time SLI
        summary("cairnloop.support_resolution_time",
          event_name: [:cairnloop, :conversation, :resolve, :stop],
          measurement: fn _measurements, metadata ->
            Map.get(metadata, :business_duration_seconds, 0)
          end,
          description: "Time taken to resolve a support conversation",
          tags: [:status]
        ),

        # Reply Time SLI
        summary("cairnloop.support_reply_time",
          event_name: [:cairnloop, :conversation, :reply, :stop],
          measurement: :duration,
          description: "Time taken to reply to a support conversation",
          tags: [:role]
        ),

        # CSAT Score SLI
        summary("cairnloop.support_csat_score",
          event_name: [:cairnloop, :feedback, :csat, :stop],
          measurement: fn _measurements, metadata ->
            Map.get(metadata, :rating, 0)
          end,
          description: "Customer Satisfaction score",
          tags: []
        )
      ]
    end
    """

    Igniter.Project.Module.create_module(igniter, module_name, contents)
  end
end
