defmodule Cairnloop.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    attach_optional_telemetry()

    # Fail fast at boot if any declared tool is misconfigured (D-07).
    # A non-conforming tool raises ArgumentError here rather than at first user interaction.
    Cairnloop.ToolRegistry.validate_configured_tools!()

    children = [
      # Starts a worker by calling: Cairnloop.Worker.start_link(arg)
      # {Cairnloop.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cairnloop.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp attach_optional_telemetry do
    if Cairnloop.ScrypathConfig.ready?() do
      :telemetry.attach(
        "cairnloop-conversation-resolved-scrypath",
        [:cairnloop, :conversation, :resolved],
        &__MODULE__.handle_conversation_resolved/4,
        nil
      )
    end
  end

  @doc false
  def handle_conversation_resolved(_event, _measurements, metadata, config) do
    config = config || []

    case Cairnloop.ScrypathConfig.status(config) do
      {:ready, _ready_config} -> enqueue_scrypath_ingest(metadata, config)
      :disabled -> :ok
      {:misconfigured, _reasons} -> :ok
    end
  end

  defp enqueue_scrypath_ingest(metadata, config) do
    conversation_id = metadata[:conversation_id] || metadata[:id]

    if is_nil(conversation_id) do
      :ok
    else
      job =
        %{"conversation_id" => conversation_id}
        |> Cairnloop.Workers.IngestScrypath.new()

      enqueue_fn = Keyword.get(config, :enqueue_fn, &Oban.insert/1)

      try do
        enqueue_fn.(job)
        :ok
      rescue
        _ -> :ok
      end
    end
  end
end
