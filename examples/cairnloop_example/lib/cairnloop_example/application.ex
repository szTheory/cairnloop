defmodule CairnloopExample.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CairnloopExampleWeb.Telemetry,
      CairnloopExample.Repo,
      {DNSCluster, query: Application.get_env(:cairnloop_example, :dns_cluster_query) || :ignore},
      Supervisor.child_spec({Phoenix.PubSub, name: CairnloopExample.PubSub}, id: :cairnloop_example_pubsub),
      # Phase 28 D-08 / Pitfall 1: start the library's named PubSub registry so that
      # Cairnloop.Chat and worker broadcasts (e.g. ingest_widget_message/2, reply_to_conversation/4)
      # have a live registry to land in. Independent from CairnloopExample.PubSub — each is a
      # separately named process with zero shared state; the example endpoint continues to use
      # CairnloopExample.PubSub as its pubsub_server.
      # Rule 1 fix: use unique child_spec ids to prevent duplicate supervisor id error when
      # two Phoenix.PubSub children are in the same supervisor (#supervisorid-conflict).
      Supervisor.child_spec({Phoenix.PubSub, name: Cairnloop.PubSub}, id: :cairnloop_pubsub),
      {Oban, Application.fetch_env!(:cairnloop_example, Oban)},
      # Start a worker by calling: CairnloopExample.Worker.start_link(arg)
      # {CairnloopExample.Worker, arg},
      # Start to serve requests, typically the last entry
      CairnloopExampleWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CairnloopExample.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CairnloopExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
