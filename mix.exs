defmodule Cairnloop.MixProject do
  use Mix.Project

  def project do
    [
      app: :cairnloop,
      version: "0.5.1",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      # Required so the LiveView 1.1 compiler extracts this library's colocated hooks/JS
      # (e.g. the rail's `RailDensity` hook) into `phoenix-colocated/cairnloop/` at compile time.
      # Without it the hook is silently never emitted, so a consumer's esbuild import of
      # `phoenix-colocated/cairnloop` can't resolve and the hook never loads in the browser.
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      aliases: aliases(),
      deps: deps(),
      description:
        "Host-owned customer support automation for Phoenix apps — governed drafting, retrieval-backed answers, and durable workflow tools.",
      source_url: "https://github.com/szTheory/cairnloop",
      homepage_url: "https://github.com/szTheory/cairnloop",
      package: [
        name: "cairnloop",
        files: ~w(
            lib
            priv
            mix.exs
            README.md
            logo/cairnloop-lockup-horizontal.svg
            LICENSE
            SECURITY.md
            UPGRADING.md
            CHANGELOG.md
            guides/01-quickstart.md
            guides/02-jtbd-walkthrough.md
            guides/03-host-integration.md
            guides/04-troubleshooting.md
            guides/05-mcp-clients.md
            guides/06-extending.md
            guides/07-auth-and-operator-identity.md
          ),
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
          {"guides/07-auth-and-operator-identity.md", title: "Auth & Operator Identity"},
          {"guides/04-troubleshooting.md", title: "Troubleshooting"},
          {"guides/05-mcp-clients.md", title: "MCP Clients"},
          {"guides/06-extending.md", title: "Extending Cairnloop"},
          "UPGRADING.md",
          "README.md",
          "SECURITY.md",
          "CHANGELOG.md"
        ],
        groups_for_extras: [
          Guides: ~r/^guides\//
        ],
        assets: %{"guides/assets" => "assets", "logo" => "logo"},
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
    [
      preferred_envs: [
        "ci.fast": :test,
        "ci.integration": :test,
        "test.integration": :test,
        "test.setup": :test
      ]
    ]
  end

  # test/support holds the integration test host (Repo, Endpoint, Router, case
  # templates). Compiled ONLY under MIX_ENV=test so the published library never
  # ships a stray Repo/Endpoint — the host-owned, zero-children contract holds.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      ci: [
        "cmd mix ci.fast",
        "cmd mix ci.integration",
        "cmd mix ci.quality"
      ],
      "ci.full": [
        "cmd mix ci",
        "cmd --cd examples/cairnloop_example mix test.e2e"
      ],
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
      "test.integration": ["test.setup", "test --include integration test/integration"],
      # Fast CI lane: DB-free, locked deps, warnings-clean compile, and the complete headless
      # ExUnit suite. DB-backed checks stay in `ci.integration`.
      "ci.fast": [
        "deps.get --check-locked",
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test --exclude integration --warnings-as-errors"
      ],
      "ci.integration": ["deps.get --check-locked", "test.integration"],
      # Static quality gate (mirrors the CI `quality` job). Tests are NOT bundled here —
      # they run via `ci.fast` + `ci.integration` so docs/package/audit failures remain easy
      # to distinguish from behavioral regressions.
      "ci.quality": [
        "deps.get --check-locked",
        "deps.unlock --check-unused",
        "compile --warnings-as-errors",
        "credo --strict",
        "cmd mix hex.build",
        "docs --warnings-as-errors",
        # Hackney advisories are currently unsolvable through optional Chimeway 1.0.0:
        # chimeway -> tzdata ~> 1.1 -> hackney ~> 1.17. Keep the gate active for
        # every other advisory and remove this list when Chimeway can resolve Hackney 4.x.
        "deps.audit --ignore-advisory-ids GHSA-gp9c-pm5m-5cxr,GHSA-j9wq-vxxc-94wf,GHSA-mp55-p8c9-rfw2,GHSA-pj7v-xfvx-wmjq"
      ],
      check: [
        "ci.quality"
      ]
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
      {:pgvector, "~> 0.4.0"},
      {:igniter, "~> 0.5"},
      {:phoenix_live_view, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:nimble_options, "~> 1.0"},
      {:oban, "~> 2.17"},
      {:mailglass, "~> 0.2"},
      {:earmark_parser, "~> 1.4"},
      {:req, "~> 0.5"},
      {:chimeway, "~> 1.0", optional: true},
      {:scrypath, ">= 0.0.0", optional: true},
      {:telemetry_metrics_prometheus_core, "~> 1.2", optional: true},
      # phoenix_live_view 1.1 uses lazy_html (not floki) as its test-time HTML parser
      # for Phoenix.LiveViewTest element/form helpers.
      {:lazy_html, ">= 0.1.0", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end
end
