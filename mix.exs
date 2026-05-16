defmodule Cairnloop.MixProject do
  use Mix.Project

  def project do
    [
      app: :cairnloop,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:chimeway, "~> 1.0", optional: true},
      {:scrypath, ">= 0.0.0", optional: true}
    ]
  end
end
