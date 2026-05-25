defmodule Cairnloop.Repo do
  @moduledoc """
  Test-only Ecto repo for the integration suite.

  Cairnloop is a host-owned library and defines no Repo in `lib/` — production code
  resolves the repo at runtime via `Application.fetch_env!(:cairnloop, :repo)`. This
  module exists ONLY under `MIX_ENV=test` (via `elixirc_paths(:test)`) so the integration
  tests have a real Postgres-backed repo to inject as `:cairnloop, :repo`. It is never
  compiled into or shipped with the published package.
  """
  use Ecto.Repo,
    otp_app: :cairnloop,
    adapter: Ecto.Adapters.Postgres
end
