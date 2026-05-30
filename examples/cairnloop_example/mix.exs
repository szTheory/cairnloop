defmodule CairnloopExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :cairnloop_example,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {CairnloopExample.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Phase 28 Plan 03: use path dep so the example app always tests against
      # the latest local cairnloop source (including Plan 03's Chat.get_message/1).
      # The hex dep {:cairnloop, "~> 0.1.0"} references the published package which
      # does not include vM014 phase additions; path dep overrides for local dev/test.
      {:cairnloop, path: "../.."},
      {:chimeway, "~> 1.0"},
      {:oban, "~> 2.17"},
      {:pgvector, "~> 0.3.1"},
      {:igniter, "~> 0.5"},
      {:phoenix, "~> 1.8.7"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    # Cairnloop ships its migrations under its own priv/. Resolve their path in a way that works
    # in BOTH modes: as a hex dep (`deps/cairnloop/...`, the adopter flow) and as the local path
    # dep used for development (`{:cairnloop, path: "../.."}`), where Mix does not populate
    # `deps/cairnloop` so we fall back to the source tree. Keeps `mix setup` bootable either way.
    cairnloop_migrations =
      if File.dir?("deps/cairnloop/priv/repo/migrations"),
        do: "deps/cairnloop/priv/repo/migrations",
        else: "../../priv/repo/migrations"

    # Migrations run as TWO ordered phases: the example's own host tables first (conversations,
    # messages, drafts), then Cairnloop's library tables — several of which reference the
    # host-owned conversations table, so they must come after it (merging both paths into one
    # call would sort by version globally and run a library migration before its host dependency).
    # Mix runs a task only once per invocation, so the second `ecto.migrate` would be silently
    # skipped; reenable it between the phases.
    reenable_migrate = fn _ -> Mix.Task.reenable("ecto.migrate") end

    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": [
        "ecto.create",
        "ecto.migrate",
        reenable_migrate,
        "ecto.migrate --migrations-path #{cairnloop_migrations}",
        "run priv/repo/seeds.exs"
      ],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: [
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        reenable_migrate,
        "ecto.migrate --migrations-path #{cairnloop_migrations} --quiet",
        "test"
      ],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind cairnloop_example", "esbuild cairnloop_example"],
      "assets.deploy": [
        "tailwind cairnloop_example --minify",
        "esbuild cairnloop_example --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
