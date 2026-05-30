# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :cairnloop_example,
  ecto_repos: [CairnloopExample.Repo],
  generators: [timestamp_type: :utc_datetime]

# Register pgvector with Postgrex so `vector` columns work from the example app
# (mirrors the library's own `config :cairnloop, Cairnloop.Repo, types: Cairnloop.PostgrexTypes`).
config :cairnloop_example, CairnloopExample.Repo, types: Cairnloop.PostgrexTypes

# Configure the endpoint
config :cairnloop_example, CairnloopExampleWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: CairnloopExampleWeb.ErrorHTML, json: CairnloopExampleWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CairnloopExample.PubSub,
  live_view: [signing_salt: "FUcI65o1"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  cairnloop_example: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  cairnloop_example: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :cairnloop_example, Oban,
  repo: CairnloopExample.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10]

config :cairnloop,
  repo: CairnloopExample.Repo,
  tools: [Cairnloop.Tools.InternalNote],
  context_provider: CairnloopExample.DemoContextProvider,
  # The /support/audit-log timeline reads through a pluggable auditor. This is the library
  # default, shown explicitly so adopters see the knob: `Cairnloop.Auditor.Governance` surfaces
  # durable ToolActionEvent rows via the Governance facade. Point it at your own module to source
  # the timeline elsewhere.
  auditor: Cairnloop.Auditor.Governance

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
