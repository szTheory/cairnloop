defmodule Cairnloop.MixProject do
  use Mix.Project

  def project do
    [
      app: :cairnloop,
      version: "0.2.1",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      description:
        "Host-owned customer support automation for Phoenix apps — governed drafting, retrieval-backed answers, and durable workflow tools.",
      source_url: "https://github.com/szTheory/cairnloop",
      homepage_url: "https://github.com/szTheory/cairnloop",
      package: [
        name: "cairnloop",
        files: ~w(lib priv guides mix.exs README.md LICENSE CHANGELOG.md),
        licenses: ["MIT"],
        links: %{
          "GitHub" => "https://github.com/szTheory/cairnloop",
          "Changelog" => "https://hexdocs.pm/cairnloop/changelog.html"
        },
        maintainers: ["szTheory"]
      ],
      docs: [
        main: "readme",
        extras: [
          {"guides/01-quickstart.md", title: "Quickstart"},
          {"guides/02-jtbd-walkthrough.md", title: "JTBD Walkthrough"},
          {"guides/03-host-integration.md", title: "Host Integration"},
          {"guides/04-troubleshooting.md", title: "Troubleshooting"},
          {"guides/05-mcp-clients.md", title: "MCP Clients"},
          {"guides/06-extending.md", title: "Extending Cairnloop"},
          "README.md",
          "CHANGELOG.md"
        ],
        groups_for_extras: [
          Guides: ~r/^guides\//
        ],
        # assets: "guides/assets"  # uncomment once PNG screenshots are captured
        groups_for_modules: [
          Governance: [~r/^Cairnloop\.Governance/, ~r/^Cairnloop\.Tool/],
          "Knowledge Base": [~r/^Cairnloop\.KnowledgeBase/, ~r/^Cairnloop\.KnowledgeAutomation/],
          Retrieval: [~r/^Cairnloop\.Retrieval/],
          MCP: [~r/^Cairnloop\.Web\.MCP/],
          Web: [~r/^Cairnloop\.Web/],
          Core: [~r/^Cairnloop/]
        ]
      ]
    ]
  end

  # Run the integration aliases under MIX_ENV=test without an explicit prefix.
  def cli do
    [preferred_envs: ["test.integration": :test, "test.setup": :test]]
  end

  # test/support holds the integration test host (Repo, Endpoint, Router, case
  # templates). Compiled ONLY under MIX_ENV=test so the published library never
  # ships a stray Repo/Endpoint — the host-owned, zero-children contract holds.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      # DB bootstrap for the integration suite (Cairnloop.Repo + Chimeway.Repo boot DB).
      # Host-owned tables (conversations/messages/drafts) are created FIRST via the
      # test-host migration path — the library's own migrations reference but do not
      # create them (the host owns them). Then the library migrations run.
      # One migrate call with BOTH paths (a task runs once per mix invocation). Ecto merges
      # and sorts by version: host tables (20260101…) precede the library migrations, so the
      # library's FKs to cairnloop_conversations resolve.
      # Create BOTH repos in one call (a task runs once per mix invocation; -r is :keep).
      # Chimeway.Repo's DB only needs to EXIST so its unconditional supervisor boots cleanly
      # (no migrations run against it). Migrate only Cairnloop.Repo.
      "test.setup": [
        "ecto.create --quiet -r Cairnloop.Repo -r Chimeway.Repo",
        "ecto.migrate --quiet --migrations-path priv/test_host/migrations --migrations-path priv/repo/migrations"
      ],
      # Default `mix test` stays DB-free and excludes :integration (fast inner loop).
      # Run the DB-backed suite explicitly with `mix test.integration`.
      "test.integration": ["test.setup", "test --include integration test/integration"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Cairnloop.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:pgvector, "~> 0.3.1"},
      {:igniter, "~> 0.5"},
      {:phoenix_live_view, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:oban, "~> 2.17"},
      {:mailglass, "~> 0.2"},
      {:hackney, "~> 1.9"},
      {:earmark, "~> 1.4"},
      {:req, "~> 0.5"},
      {:chimeway, "~> 1.0", optional: true},
      {:scrypath, ">= 0.0.0", optional: true},
      {:telemetry_metrics_prometheus_core, "~> 1.2", optional: true},
      # phoenix_live_view 1.1 uses lazy_html (not floki) as its test-time HTML parser
      # for Phoenix.LiveViewTest element/form helpers.
      {:lazy_html, ">= 0.1.0", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
