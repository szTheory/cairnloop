defmodule Cairnloop.Workers.ProcessMessage do
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"channel" => channel, "content" => content}}) do
    # Here we would persist the message to the database using the core context.
    # For now, we simulate this as the context may not fully exist yet.
    require Logger
    Logger.info("Processed message from channel #{channel}: #{content}")
    :ok
  end
end
