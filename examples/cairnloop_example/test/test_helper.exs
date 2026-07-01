# `:e2e` (real-browser, phoenix_test_playwright) tests are excluded from the fast default lane.
# Run them with `mix test.e2e` (which compiles + builds assets so the colocated RailDensity hook
# is bundled, then runs `test --only e2e`).
ExUnit.start(exclude: [:e2e])

# Start the Playwright driver supervisor and point phoenix_test at the running endpoint. The
# supervisor is cheap when idle (no browser launches until a PhoenixTest.Playwright.Case test
# runs), so it's harmless for the non-e2e lane.
{:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()
Application.put_env(:phoenix_test, :base_url, CairnloopExampleWeb.Endpoint.url())

Ecto.Adapters.SQL.Sandbox.mode(CairnloopExample.Repo, :manual)
