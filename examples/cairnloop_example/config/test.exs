import Config
config :cairnloop_example, Oban, testing: :manual

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :cairnloop_example, CairnloopExample.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "cairnloop_example_test#{System.get_env("MIX_TEST_PARTITION")}",
  # Honor PGPORT (matches dev.exs + the library's config/test.exs). Defaults to 5433.
  port: String.to_integer(System.get_env("PGPORT") || "5433"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Quiet Chimeway's auto-started Repo in tests too (see dev.exs for why). The demo doesn't use it;
# it just needs a valid connection so it doesn't log connection errors during the suite.
config :chimeway, Chimeway.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "cairnloop_example_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: String.to_integer(System.get_env("PGPORT") || "5433"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2

# Run the endpoint during test so browser E2E (phoenix_test_playwright) can drive a real
# Chromium against it. Unit/LiveViewTest specs are unaffected by an idle listener.
config :cairnloop_example, CairnloopExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PHX_TEST_PORT") || "4002")],
  secret_key_base: "55SiwpW85WfSTlCQHPel0ISJLNaXjWwXuNKyzdCVp6U+7uu6tKWlBaJCHXI9f6yq",
  server: true

config :cairnloop, :widget_token_verifier, Cairnloop.Widget.Verifier.Demo

# Browser E2E plumbing (test env only).
# `:sql_sandbox` activates the Phoenix.Ecto.SQL.Sandbox endpoint plug + the dashboard
# `LiveAcceptance` on_mount, so a real browser session can join the test's shared DB connection.
config :cairnloop_example, :sql_sandbox, true

# phoenix_test_playwright: which OTP app's `:ecto_repos` to checkout for the sandbox, and the
# Playwright knobs. Headless by default; flip PW_TRACE/PW_SCREENSHOT/PW_HEADLESS for local
# debugging. `ecto_sandbox_stop_owner_delay` gives the LiveView a beat to release the connection
# on teardown (avoids DBConnection.OwnershipError races).
config :phoenix_test,
  otp_app: :cairnloop_example,
  playwright: [
    browser: :chromium,
    headless: System.get_env("PW_HEADLESS", "true") in ~w(t true 1),
    trace: System.get_env("PW_TRACE", "false") in ~w(t true 1),
    screenshot: System.get_env("PW_SCREENSHOT", "false") in ~w(t true 1),
    ecto_sandbox_stop_owner_delay: 50
  ]

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
