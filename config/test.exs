import Config

# ---------------------------------------------------------------------------
# Integration test host configuration.
#
# Cairnloop ships no Repo/Endpoint/Oban of its own (host-owned library). The
# integration suite (test/integration/*, tagged :integration) needs a real
# Postgres + Oban + Phoenix Endpoint to exercise the legs that headless tests
# can't (partial unique index, JSONB round-trip, async Oban flow, LiveView).
#
# The fast headless suite is unaffected: it injects its own MockRepo per-test
# and never dispatches through the Endpoint.
# ---------------------------------------------------------------------------

# Test Repo — sandbox pool for per-test isolation. `types:` is merged in from
# config.exs (Cairnloop.PostgrexTypes for pgvector).
config :cairnloop, Cairnloop.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  database: "cairnloop_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  priv: "priv/repo"

# Manage only Cairnloop.Repo for ecto.create/migrate by default (Chimeway.Repo
# is created explicitly via `-r` and never migrated — see test.setup alias).
config :cairnloop, ecto_repos: [Cairnloop.Repo]

# Baseline repo injection — the key every lib module reads via
# Application.fetch_env!(:cairnloop, :repo). Headless tests override per-test.
config :cairnloop, :repo, Cairnloop.Repo

# NOTE on Oban: Cairnloop is a library and ships NO Oban migration (the host owns
# the oban_jobs table + Oban runtime). The integration suite therefore drives the
# approval workers by calling `perform/1` directly (as the headless worker tests do)
# and verifies scheduling via a capturing `enqueue_fn` — no running Oban instance and
# no oban_jobs table are required, while real Postgres transitions are still exercised.

# Minimal Phoenix Endpoint for Phoenix.LiveViewTest (server: false — no port bound).
config :cairnloop, Cairnloop.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: String.duplicate("cairnloop_test_secret_key_base_0123456789", 2),
  live_view: [signing_salt: "cairnloop_test_salt"],
  pubsub_server: Cairnloop.PubSub,
  render_errors: [formats: [], layout: false],
  server: false

# ---------------------------------------------------------------------------
# Chimeway boot fix: the `chimeway` dep's Application unconditionally starts
# Chimeway.Repo. Without a :database key it raises at boot ("missing the
# :database key in options for Chimeway.Repo"). We give it a throwaway test DB
# (same Postgres server, sandbox pool) so its supervisor boots cleanly. We never
# use it and never run migrations against it. No `config :chimeway, Oban` so its
# oban_child/0 stays empty.
# ---------------------------------------------------------------------------
config :chimeway, Chimeway.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  database: "chimeway_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2

config :logger, level: :warning
