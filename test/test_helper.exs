# Cairnloop.Application starts ZERO children by design (host-owned library). The
# integration suite needs a real Repo + PubSub + Endpoint, so we start them here under
# a dedicated supervisor ONLY when integration tests are actually included — the
# application's own tree stays empty, preserving the contract.
#
# The fast headless suite (the default — `:integration` excluded) starts nothing extra,
# so it needs no Postgres and emits no DB connection noise. Run the DB-backed suite with
# `mix test.integration` (or `mix test --include integration`).

ExUnit.start(exclude: [:integration])

integration? =
  ExUnit.configuration()
  |> Keyword.get(:include, [])
  |> Enum.any?(fn
    :integration -> true
    {:integration, _} -> true
    _ -> false
  end)

if integration? do
  children = [
    Cairnloop.Repo,
    {Phoenix.PubSub, name: Cairnloop.PubSub},
    Cairnloop.Web.Endpoint
  ]

  {:ok, _} =
    Supervisor.start_link(children, strategy: :one_for_one, name: Cairnloop.TestSupervisor)

  Ecto.Adapters.SQL.Sandbox.mode(Cairnloop.Repo, :manual)
end
