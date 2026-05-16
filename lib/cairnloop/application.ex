defmodule Cairnloop.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    attach_telemetry()

    children = [
      # Starts a worker by calling: Cairnloop.Worker.start_link(arg)
      # {Cairnloop.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cairnloop.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp attach_telemetry do
    :telemetry.attach(
      "cairnloop-conversation-resolved-scrypath",
      [:cairnloop, :conversation, :resolved],
      &__MODULE__.handle_conversation_resolved/4,
      nil
    )
  end

  @doc false
  def handle_conversation_resolved(_event, _measurements, metadata, _config) do
    job =
      %{
        "conversation_id" => metadata[:conversation_id] || metadata[:id],
        "text" => metadata[:text] || ""
      }
      |> Cairnloop.Workers.IngestScrypath.new()

    try do
      Oban.insert(job)
    rescue
      _ -> :ok
    end
  end
end
