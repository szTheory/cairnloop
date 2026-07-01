# Phase 53: Demo Runtime Contract - Pattern Map

**Mapped:** 2026-06-28
**Files analyzed:** 15
**Analogs found:** 15 / 15

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `examples/cairnloop_example/mix.exs` | config | batch | `examples/cairnloop_example/mix.exs` | exact |
| `examples/cairnloop_example/config/config.exs` | config | request-response | `examples/cairnloop_example/config/config.exs` | exact |
| `examples/cairnloop_example/config/dev.exs` | config | CRUD | `examples/cairnloop_example/config/dev.exs` | exact |
| `examples/cairnloop_example/config/test.exs` | config | CRUD | `examples/cairnloop_example/config/test.exs` | exact |
| `examples/cairnloop_example/config/runtime.exs` | config | request-response | `examples/cairnloop_example/config/runtime.exs` | exact |
| `examples/cairnloop_example/lib/cairnloop_example/demo_notifier.ex` | provider | event-driven | `lib/mix/tasks/cairnloop.gen.notifier.ex` | role-match |
| `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` | route | request-response | `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` | exact |
| `examples/cairnloop_example/compose.demo.yml` | config | request-response | `examples/cairnloop_example/compose.demo.yml` | exact |
| `examples/cairnloop_example/Dockerfile.demo` | config | batch | `examples/cairnloop_example/Dockerfile.demo` | exact |
| `examples/cairnloop_example/priv/repo/seeds.exs` | utility | CRUD | `examples/cairnloop_example/priv/repo/seeds.exs` | exact |
| `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` | test | CRUD | `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` | exact |
| `README.md` | docs | file-I/O | `README.md` | exact |
| `examples/cairnloop_example/README.md` | docs | file-I/O | `examples/cairnloop_example/README.md` | exact |
| `guides/01-quickstart.md` | docs | file-I/O | `guides/01-quickstart.md` | exact |
| `guides/04-troubleshooting.md` | docs | file-I/O | `guides/04-troubleshooting.md` | exact |

## Pattern Assignments

### `examples/cairnloop_example/mix.exs` (config, batch)

**Analog:** `examples/cairnloop_example/mix.exs`

**Dependency pattern** (lines 41-53):
```elixir
defp deps do
  [
    # Phase 28 Plan 03: use path dep so the example app always tests against
    # the latest local cairnloop source (including Plan 03's Chat.get_message/1).
    # The hex dep {:cairnloop, "~> 0.1.0"} references the published package which
    # does not include vM014 phase additions; path dep overrides for local dev/test.
    {:cairnloop, path: "../.."},
    {:phoenix_test_playwright, "~> 0.14", only: :test, runtime: false},
```

**Migration/setup pattern** (lines 89-115):
```elixir
defp aliases do
  cairnloop_migrations =
    if File.dir?("deps/cairnloop/priv/repo/migrations"),
      do: "deps/cairnloop/priv/repo/migrations",
      else: "../../priv/repo/migrations"

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
```

**Test alias pattern** (lines 117-137):
```elixir
test: [
  "ecto.create --quiet",
  "ecto.migrate --quiet",
  reenable_migrate,
  "ecto.migrate --migrations-path #{cairnloop_migrations} --quiet",
  "test"
],
"test.e2e": [
  "assets.setup",
  "assets.build",
  "ecto.create --quiet",
  "ecto.migrate --quiet",
  reenable_migrate,
  "ecto.migrate --migrations-path #{cairnloop_migrations} --quiet",
  "test --only e2e"
],
```

Apply this exact two-phase migration shape. Do not merge host and library migration paths into one `ecto.migrate` command.

---

### `examples/cairnloop_example/config/config.exs` (config, request-response)

**Analog:** `examples/cairnloop_example/config/config.exs`

**Imports/base app pattern** (lines 7-16):
```elixir
import Config

config :cairnloop_example,
  ecto_repos: [CairnloopExample.Repo],
  generators: [timestamp_type: :utc_datetime]

config :cairnloop_example, CairnloopExample.Repo, types: Cairnloop.PostgrexTypes
```

**Cairnloop host wiring pattern** (lines 63-75):
```elixir
config :cairnloop,
  repo: CairnloopExample.Repo,
  tools: [
    Cairnloop.Tools.InternalNote,
    CairnloopExample.Tools.HighRiskDemoAction
  ],
  context_provider: CairnloopExample.DemoContextProvider,
  auditor: Cairnloop.Auditor.Governance
```

**Notifier config source** (from `lib/mix/tasks/cairnloop.gen.notifier.ex` lines 47-50):
```elixir
config_snippet = """

# Configure Cairnloop Notifier
config :cairnloop, :notifier, #{app_module}.CairnloopNotifier
"""
```

If Phase 53 adds `DemoNotifier`, wire it in app config, preferably beside the existing `config :cairnloop` host-wiring block or as the generator-style explicit key. Keep it example-only.

---

### `examples/cairnloop_example/config/dev.exs` (config, CRUD)

**Analog:** `examples/cairnloop_example/config/dev.exs`

**Env parsing and bind allowlist** (lines 1-14):
```elixir
import Config

database_hostname = System.get_env("PGHOST") || "localhost"
database_port = String.to_integer(System.get_env("PGPORT") || "5433")
database_username = System.get_env("PGUSER") || "postgres"
database_password = System.get_env("PGPASSWORD") || "postgres"
database_name = System.get_env("PGDATABASE") || "cairnloop_example_dev"

bind_ip =
  case System.get_env("PHX_BIND") || "127.0.0.1" do
    "0.0.0.0" -> {0, 0, 0, 0}
    "127.0.0.1" -> {127, 0, 0, 1}
    other -> raise "Unsupported PHX_BIND=#{inspect(other)}. Use 127.0.0.1 or 0.0.0.0."
  end
```

**Repo and Chimeway quieting pattern** (lines 17-39):
```elixir
config :cairnloop_example, CairnloopExample.Repo,
  username: database_username,
  password: database_password,
  hostname: database_hostname,
  database: database_name,
  port: database_port,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :chimeway, Chimeway.Repo,
  username: database_username,
  password: database_password,
  hostname: database_hostname,
  database: database_name,
  port: database_port,
  pool_size: 2
```

**Endpoint/Docker port pattern** (lines 47-66):
```elixir
config :cairnloop_example, CairnloopExampleWeb.Endpoint,
  http: [ip: bind_ip, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  reloadable_apps: [:cairnloop_example, :cairnloop],
  debug_errors: true,
  secret_key_base: "toRX4Kr+2AHLpJr5bTeiK39tVP6RDPf4K3X5ajaXWf02C8mg5rODatgbm7zWUom3",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:cairnloop_example, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:cairnloop_example, ~w(--watch)]}
  ]

config :cairnloop, Cairnloop.KnowledgeAutomation.EditorHandoff,
  secret_key_base: "dev_only_64_byte_minimum_secret_for_editor_handoff_tokens_cairnloop"
```

Keep dev/Docker on `PG*`, `PORT`, and `PHX_BIND`; do not switch this path to `DATABASE_URL`.

---

### `examples/cairnloop_example/config/test.exs` (config, CRUD)

**Analog:** `examples/cairnloop_example/config/test.exs`

**Oban and Repo pattern** (lines 1-17):
```elixir
import Config
config :cairnloop_example, Oban, testing: :manual

config :cairnloop_example, CairnloopExample.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "cairnloop_example_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: String.to_integer(System.get_env("PGPORT") || "5433"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
```

**Chimeway quieting pattern** (lines 19-28):
```elixir
config :chimeway, Chimeway.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "cairnloop_example_test#{System.get_env("MIX_TEST_PARTITION")}",
  port: String.to_integer(System.get_env("PGPORT") || "5433"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 2
```

**E2E endpoint/sandbox pattern** (lines 30-54):
```elixir
config :cairnloop_example, CairnloopExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PHX_TEST_PORT") || "4002")],
  secret_key_base: "55SiwpW85WfSTlCQHPel0ISJLNaXjWwXuNKyzdCVp6U+7uu6tKWlBaJCHXI9f6yq",
  server: true

config :cairnloop_example, :sql_sandbox, true

config :phoenix_test,
  otp_app: :cairnloop_example,
  playwright: [
    browser: :chromium,
    headless: System.get_env("PW_HEADLESS", "true") in ~w(t true 1),
    trace: System.get_env("PW_TRACE", "false") in ~w(t true 1),
    screenshot: System.get_env("PW_SCREENSHOT", "false") in ~w(t true 1),
    ecto_sandbox_stop_owner_delay: 50
  ]
```

Use `@moduletag :requires_postgres` for DB-backed tests rather than weakening them for DB-free lanes.

---

### `examples/cairnloop_example/config/runtime.exs` (config, request-response)

**Analog:** `examples/cairnloop_example/config/runtime.exs`

**Runtime endpoint pattern** (lines 19-36):
```elixir
if System.get_env("PHX_SERVER") do
  config :cairnloop_example, CairnloopExampleWeb.Endpoint, server: true
end

if config_env() != :test do
  bind_ip =
    case System.get_env("PHX_BIND") || "127.0.0.1" do
      "0.0.0.0" -> {0, 0, 0, 0}
      "127.0.0.1" -> {127, 0, 0, 1}
      other -> raise "Unsupported PHX_BIND=#{inspect(other)}. Use 127.0.0.1 or 0.0.0.0."
    end

  config :cairnloop_example, CairnloopExampleWeb.Endpoint,
    http: [ip: bind_ip, port: String.to_integer(System.get_env("PORT", "4000"))]
end
```

**Prod-only secrets/database pattern** (lines 38-69):
```elixir
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  config :cairnloop_example, CairnloopExample.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  config :cairnloop, Cairnloop.KnowledgeAutomation.EditorHandoff,
    secret_key_base: System.fetch_env!("CAIRNLOOP_HANDOFF_SECRET_KEY_BASE")
```

Do not let runtime config override the test endpoint port.

---

### `examples/cairnloop_example/lib/cairnloop_example/demo_notifier.ex` (provider, event-driven)

**Analog:** `lib/mix/tasks/cairnloop.gen.notifier.ex`

**Example-module style source** (from `examples/cairnloop_example/lib/cairnloop_example/demo_context_provider.ex` lines 1-22):
```elixir
defmodule CairnloopExample.DemoContextProvider do
  @moduledoc """
  Demo implementation of `Cairnloop.ContextProvider` for the example application.
  """

  @behaviour Cairnloop.ContextProvider

  @impl true
```

**Behaviour contract** (from `lib/cairnloop/notifier.ex` lines 1-22):
```elixir
defmodule Cairnloop.Notifier do
  @callback on_conversation_resolved(conversation :: struct(), metadata :: map()) :: :ok | any()

  @callback on_sla_breach(conversation :: struct(), sla :: struct(), metadata :: map()) ::
              :ok | {:error, term()} | any()

  @callback on_outbound_triggered(message :: struct(), conversation :: struct()) ::
              :ok | {:error, term()} | any()
end
```

**Generator implementation pattern** (from `lib/mix/tasks/cairnloop.gen.notifier.ex` lines 77-107):
```elixir
defmodule <%= @app_module %>.CairnloopNotifier do
  @moduledoc """
  A callback handler for Cairnloop events.
  """
  @behaviour Cairnloop.Notifier

  require Logger

  @impl true
  def on_conversation_resolved(conversation, metadata) do
    Logger.info("Conversation #{conversation.id} was resolved. Metadata: #{inspect(metadata)}")
    :ok
  end

  @impl true
  def on_sla_breach(conversation, sla, _metadata) do
    Logger.info("SLA breach for conversation #{conversation.id}. SLA: #{inspect(sla)}")
    :ok
  end

  @impl true
  def on_outbound_triggered(message, conversation) do
    Logger.info("Outbound message triggered for conversation #{conversation.id}. Template: #{message.metadata["template_id"]}")
    :ok
  end
end
```

**Phase 53 no-op shape to use:** copy the behaviour callbacks, but return `:ok` without Logger or Chimeway side effects:
```elixir
defmodule CairnloopExample.DemoNotifier do
  @moduledoc false
  @behaviour Cairnloop.Notifier

  @impl true
  def on_conversation_resolved(_conversation, _metadata), do: :ok

  @impl true
  def on_sla_breach(_conversation, _sla, _metadata), do: :ok

  @impl true
  def on_outbound_triggered(_message, _conversation), do: :ok
end
```

**Anti-pattern for this phase** (from `lib/cairnloop/notifier/chimeway.ex` lines 11-39):
```elixir
def on_sla_breach(conversation, sla, _metadata) do
  payload = %{conversation_id: conversation.id, account_id: Map.get(conversation, :account_id)}
  idempotency_key = "sla_breach_#{conversation.id}_#{sla.target_type}"
  Chimeway.trigger(SLABreachNotifier, payload, idempotency_key: idempotency_key)
end

def on_outbound_triggered(message, conversation) do
  payload = %{conversation_id: conversation.id, message_id: message.id}
  Chimeway.trigger(Cairnloop.Chimeway.OutboundNotifier, payload, idempotency_key: idempotency_key)
end
```

Do not configure `Cairnloop.Notifier.Chimeway` in Phase 53 unless Chimeway migrations are explicitly added, which is out of scope.

---

### `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` (route, request-response)

**Analog:** `examples/cairnloop_example/lib/cairnloop_example_web/router.ex`

**Imports/pipeline pattern** (lines 1-24):
```elixir
defmodule CairnloopExampleWeb.Router do
  use CairnloopExampleWeb, :router

  require Cairnloop.Router
  import CairnloopExampleWeb.OperatorAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CairnloopExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_operator
  end
```

**Dashboard mount pattern** (lines 34-49):
```elixir
scope "/" do
  pipe_through :browser

  Cairnloop.Router.cairnloop_dashboard("/support",
    session: {CairnloopExampleWeb.OperatorAuth, :cairnloop_session, []},
    on_mount:
      if(Application.compile_env(:cairnloop_example, :sql_sandbox),
        do: [CairnloopExampleWeb.LiveAcceptance],
        else: []
      )
  )
end
```

**Operations route pattern** (lines 59-63):
```elixir
# Operations endpoints (OPS-01, OPS-02): GET /health and GET /metrics. Mounted
# outside the :browser pipeline so infrastructure can probe them without CSRF/session.
scope "/" do
  Cairnloop.Router.cairnloop_operations()
end
```

**Library macro source** (from `lib/cairnloop/router.ex` lines 34-60):
```elixir
defmacro cairnloop_operations(opts \\ []) do
  opts = NimbleOptions.validate!(opts, @operations_opts_schema)
  health_path = opts[:health_path]
  metrics_path = opts[:metrics_path]

  quote do
    forward(unquote(health_path), Cairnloop.Web.HealthPlug)
    forward(unquote(metrics_path), Cairnloop.Web.MetricsPlug)
  end
end
```

**Health response source** (from `lib/cairnloop/web/health_plug.ex` lines 14-19):
```elixir
def call(conn, _opts) do
  conn
  |> put_resp_content_type("application/json")
  |> send_resp(200, ~s({"status": "ok"}))
end
```

Keep `/health` outside `:browser`; keep `/support` inside the browser/session pipeline.

---

### `examples/cairnloop_example/compose.demo.yml` (config, request-response)

**Analog:** `examples/cairnloop_example/compose.demo.yml`

**DB readiness pattern** (lines 1-17):
```yaml
name: ${CAIRNLOOP_COMPOSE_PROJECT:-cairnloop_example}

services:
  db:
    image: pgvector/pgvector:pg16
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: cairnloop_example_dev
    volumes:
      - demo_db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d cairnloop_example_dev"]
      interval: 2s
      timeout: 5s
      retries: 30
      start_period: 5s
```

**Web runtime and healthcheck pattern** (lines 19-58):
```yaml
web:
  build:
    context: ../..
    dockerfile: examples/cairnloop_example/Dockerfile.demo
  depends_on:
    db:
      condition: service_healthy
  environment:
    MIX_ENV: dev
    PGHOST: db
    PGPORT: "5432"
    PGUSER: postgres
    PGPASSWORD: postgres
    PGDATABASE: cairnloop_example_dev
    PORT: "4000"
    PHX_BIND: 0.0.0.0
    OPENAI_API_KEY: ${OPENAI_API_KEY:-}
  ports:
    - name: web
      target: 4000
      published: "${CAIRNLOOP_WEB_PORT:-4100-4199}"
      host_ip: "${CAIRNLOOP_BIND_HOST:-127.0.0.1}"
      protocol: tcp
  healthcheck:
    test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:4000/health >/dev/null"]
    interval: 5s
    timeout: 5s
    retries: 30
    start_period: 20s
```

Do not publish Postgres to the host in the demo Compose contract. Keep web readiness tied to `/health`.

---

### `examples/cairnloop_example/Dockerfile.demo` (config, batch)

**Analog:** `examples/cairnloop_example/Dockerfile.demo`

**Base image/tooling pattern** (lines 1-20):
```dockerfile
# syntax=docker/dockerfile:1.7

FROM hexpm/elixir:1.19.5-erlang-27.2.4-debian-trixie-20260623-slim

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      git \
      inotify-tools \
      postgresql-client && \
    rm -rf /var/lib/apt/lists/*
```

**Workspace/user pattern** (lines 22-38):
```dockerfile
RUN if ! getent group "${GID}" >/dev/null; then groupadd --gid "${GID}" app; fi && \
    useradd --uid "${UID}" --gid "${GID}" --create-home --shell /bin/bash app && \
    mkdir -p \
      /workspace/examples/cairnloop_example/deps \
      /workspace/examples/cairnloop_example/_build \
      /workspace/examples/cairnloop_example/priv/static/assets \
      /home/app/.mix \
      /home/app/.hex \
      /home/app/.cache/rebar3 && \
    chown -R "${UID}:${GID}" /workspace /home/app

USER app
WORKDIR /workspace/examples/cairnloop_example

RUN mix local.hex --force && mix local.rebar --force

EXPOSE 4000
```

**Runtime command pattern** (line 40):
```dockerfile
CMD ["sh", "-lc", "mix setup && exec mix phx.server"]
```

The container contract depends on `mix setup` running migrations and seeds before Phoenix serves traffic.

---

### `examples/cairnloop_example/priv/repo/seeds.exs` (utility, CRUD)

**Analog:** `examples/cairnloop_example/priv/repo/seeds.exs`

**Seed script contract** (lines 12-37):
```elixir
# IDEMPOTENCY CONTRACT (D-02)
# Re-running this script against an already-seeded DB is a no-op. Every insert
# is guarded by `Repo.get_by` on a natural key. No `on_conflict` magic.

# END-OF-SCRIPT OBAN DRAIN (D-08)
# After all builders run, `Oban.drain_queue(queue: :default, with_recursion: true)`
# synchronously executes every enqueued `ChunkRevision` job so the M008 substrate
# self-test completes before this script exits.

# FACADE RULE (D-09)
# Articles + revisions go ONLY through `Cairnloop.KnowledgeBase.create_article/1`,
# `save_draft/2`, `publish_revision/1`. Bypassing the facade with a direct
# `%Revision{}` insert skips the Multi that enqueues `ChunkRevision`.
```

**Run orchestration pattern** (lines 70-109):
```elixir
defmodule CairnloopExample.SeedRun do
  alias CairnloopExample.Repo
  alias Cairnloop.KnowledgeBase
  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.Governance

  def run do
    IO.puts("Seeding Cairnloop example app demo data...")

    articles = build_articles()
    conversations = build_conversations(articles)
    showcase = build_showcase_states()
    gaps = build_gaps(conversations)
    {suggestion, _review_task} = build_suggestion(articles, conversations)
    build_phase45_evidence_states()

    drain_summary = drain_embedding_pipeline()

    emit_seed_summary(articles, conversations ++ showcase, gaps, suggestion, drain_summary)
    :ok
  end
```

**Knowledge Base facade pattern** (lines 124-168):
```elixir
# Each article is created via the KnowledgeBase facade (D-09):
#   get_or_insert!(Article, :title, ...) for the article row,
#   KnowledgeBase.save_draft/2 + KnowledgeBase.publish_revision/1 for each revision.
defp build_articles do
  import Ecto.Query

  api_key_article =
    get_or_insert!(Article, :title, %{
      title: "Resetting your Trailmark API key",
      status: :draft
    })

  unless Repo.one(from r in Revision, where: r.article_id == ^api_key_article.id and r.state == :published, limit: 1) do
    {:ok, draft} = KnowledgeBase.save_draft(api_key_article, %{content: body})
    {:ok, _published} = KnowledgeBase.publish_revision(draft)
  end
end
```

**Suggestion/review-task pattern** (lines 1216-1250):
```elixir
suggestion =
  case Repo.get_by(ArticleSuggestion, stable_key: @demo_suggestion_stable_key) do
    nil ->
      %ArticleSuggestion{}
      |> ArticleSuggestion.changeset(suggestion_attrs)
      |> Repo.insert!()

    existing ->
      existing
  end

{:ok, review_task} =
  KnowledgeAutomation.ensure_review_task_for_suggestion(
    suggestion.id,
    actor_id: "system"
  )

{suggestion, review_task}
```

**Oban drain and summary pattern** (lines 1278-1315):
```elixir
defp drain_embedding_pipeline do
  IO.puts("Draining embedding pipeline (Oban :default queue)...")

  %{success: success, failure: failure} =
    result =
    Oban.drain_queue(queue: :default, with_recursion: true)

  if failure > 0 do
    IO.warn("Seed embedding pipeline drained with #{failure} failures. " <> "Inspect oban_jobs.errors for details.")
  end

  IO.puts("Drained #{success} embedding job(s).")
  result
end
```

**Natural-key helper pattern** (lines 1900-1918):
```elixir
defp get_or_insert!(schema_module, natural_key_field, attrs) do
  case Repo.get_by(schema_module, [{natural_key_field, Map.fetch!(attrs, natural_key_field)}]) do
    nil ->
      struct(schema_module)
      |> schema_module.changeset(attrs)
      |> Repo.insert!()

    existing ->
      existing
  end
end
```

Any seed change should preserve natural keys, facade calls, and the final Oban drain.

---

### `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` (test, CRUD)

**Analog:** `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs`

**DB-backed test pattern** (lines 1-49):
```elixir
defmodule CairnloopExample.SeedsTest do
  use CairnloopExample.DataCase, async: false

  @moduletag :requires_postgres

  alias Cairnloop.Conversation
  alias Cairnloop.Message
  alias Cairnloop.KnowledgeBase.Article
  alias Cairnloop.KnowledgeBase.Chunk
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion
  alias Cairnloop.KnowledgeAutomation.ReviewTask

  import Ecto.Query

  defp run_seed!() do
    seed_path = Path.expand("../../priv/repo/seeds.exs", __DIR__)
    assert File.exists?(seed_path), "seed file not found at resolved path: #{seed_path}"
    Code.eval_file(seed_path)
    :ok
  end
```

**Chunk readiness assertion** (lines 156-170):
```elixir
assert :ok == run_seed!()

assert Repo.aggregate(Chunk, :count) > 0,
       "cairnloop_chunks is empty after seed run. FIX-02 M008 substrate self-test failed. " <>
         "Check that build_articles/0 uses KnowledgeBase.publish_revision/1 (NOT a direct " <>
         "%Revision{} insert) and that drain_embedding_pipeline/0 runs after build_articles/0 " <>
         "in SeedRun.run/0."

assert Repo.aggregate(Chunk, :count) >= 5
```

**ReviewTask companion assertion** (lines 177-200):
```elixir
test "FIX-04: the seeded ArticleSuggestion has a companion ReviewTask with status :pending_review" do
  assert :ok == run_seed!()

  suggestion =
    Repo.one!(
      from s in ArticleSuggestion,
        where: s.stable_key == "demo:article_suggestion:billing_export:v1"
    )

  review_task =
    Repo.one(from t in ReviewTask, where: t.article_suggestion_id == ^suggestion.id)

  assert review_task
  assert review_task.status == :pending_review
end
```

**Idempotency assertion** (lines 357-397):
```elixir
test "D-02 idempotency: running the seed twice produces stable row counts" do
  assert :ok == run_seed!()

  counts_after_run_1 = %{
    conversations: Repo.aggregate(Conversation, :count),
    messages: Repo.aggregate(Message, :count),
    articles: Repo.aggregate(Article, :count),
    suggestions: Repo.aggregate(ArticleSuggestion, :count),
    review_tasks: Repo.aggregate(ReviewTask, :count)
  }

  assert :ok == run_seed!()

  counts_after_run_2 = %{
    conversations: Repo.aggregate(Conversation, :count),
    messages: Repo.aggregate(Message, :count),
    articles: Repo.aggregate(Article, :count),
    suggestions: Repo.aggregate(ArticleSuggestion, :count),
    review_tasks: Repo.aggregate(ReviewTask, :count)
  }

  assert counts_after_run_1 == counts_after_run_2
end
```

**DataCase sandbox source** (from `examples/cairnloop_example/test/support/data_case.ex` lines 17-40):
```elixir
use ExUnit.CaseTemplate

using do
  quote do
    alias CairnloopExample.Repo
    import Ecto
    import Ecto.Changeset
    import Ecto.Query
    import CairnloopExample.DataCase
  end
end

setup tags do
  CairnloopExample.DataCase.setup_sandbox(tags)
  :ok
end

def setup_sandbox(tags) do
  pid = Ecto.Adapters.SQL.Sandbox.start_owner!(CairnloopExample.Repo, shared: not tags[:async])
  on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
end
```

---

### `README.md` (docs, file-I/O)

**Analog:** `README.md`

**Docker-first pattern** (lines 11-26):
````markdown
### Try the live demo first

From a fresh clone, the fastest way to see Cairnloop working is the Docker demo:

```bash
./bin/demo
```

The command starts the example Phoenix app, a private pgvector Postgres container, migrations, and
the realistic Trailmark seed data. It prints the exact local URLs to click: the demo index,
operator cockpit, inbox, customer chat, knowledge base, audit log, settings, and health probe.
````

**Adopter Hex dependency pattern** (lines 38-50):
````markdown
The installer adds `{:cairnloop, "~> 0.1.0"}` to your `mix.exs` deps and generates a
`create_cairnloop_tables` migration against your detected Ecto repo.

```elixir
def deps do
  [
    {:cairnloop, "~> 0.1.0"}
  ]
end
```
````

Keep the docs on Hex dependency syntax even while the example app dogfoods `path: "../.."`.

---

### `examples/cairnloop_example/README.md` (docs, file-I/O)

**Analog:** `examples/cairnloop_example/README.md`

**Docker setup pattern** (lines 9-42):
````markdown
## Requirements

The Docker demo has no local Elixir or Postgres requirement beyond Docker Desktop / Docker Compose
v2. Manual local setup needs:

### Docker demo

From the repository root:

```bash
./bin/demo
```

The command builds the example app, starts a private pgvector Postgres service, runs migrations,
loads the realistic Trailmark seed data, waits for the health probe, and prints the exact URLs to
open.

Useful commands:

```bash
./bin/demo urls
./bin/demo logs
./bin/demo stop
./bin/demo reset
./bin/demo smoke
```
````

**Manual local pattern** (lines 44-71):
````markdown
### Manual local setup

To start the demo app directly on your machine:

1. Setup the project dependencies and database:

   ```bash
   # Make sure your database has pgvector installed.
   # You can run `PGPORT=5433 docker compose up -d db` from the parent repository if you need one.
   mix setup
   ```

2. Start the Phoenix endpoint:

   ```bash
   mix phx.server
   ```
````

**Routing docs pattern** (lines 117-133):
````markdown
Cairnloop's dashboard is mounted in `lib/cairnloop_example_web/router.ex`:

```elixir
require Cairnloop.Router

scope "/" do
  pipe_through :browser

  Cairnloop.Router.cairnloop_dashboard("/support",
    session: {CairnloopExampleWeb.OperatorAuth, :cairnloop_session, []}
  )
end
```
````

Docker users should be told to use the URL printed by `./bin/demo`; only manual local Phoenix should use hard-coded `http://localhost:4000`.

---

### `guides/01-quickstart.md` (docs, file-I/O)

**Analog:** `guides/01-quickstart.md`

**Docker-first pattern** (lines 6-37):
````markdown
## Fastest path: Docker demo

```bash
./bin/demo
```

That single command starts a private pgvector Postgres container, builds the example Phoenix app,
runs migrations, loads the realistic Trailmark seed data, waits for `/health`, and prints the URLs
you need next:

- demo index (`/`)
- operator cockpit (`/support`)
- inbox (`/support/inbox`)
- customer chat (`/chat`)
- knowledge base, gaps, suggestions, audit log, settings, and health probe
````

**Manual DB pattern** (lines 52-67):
````markdown
## Prerequisites

- **Elixir 1.15+ / OTP 26+**
- **Postgres 16+** with the `pgvector` extension installed

You only need these prerequisites for the manual local workflow below. The Docker demo carries its
own Elixir runtime and pgvector Postgres.

```bash
PGPORT=5433 docker compose up -d db
```
````

**Migration docs area to update** (lines 102-127):
````markdown
After the installer has run, apply both your host app's migrations and the Cairnloop
library's own migrations:

```bash
# Run host migrations (generated by the installer or written by hand)
mix ecto.migrate

# Run the Cairnloop library's own migrations
mix ecto.migrate --migrations-path deps/cairnloop/priv/repo/migrations
```

> **Tip:** Add both commands to your `ecto.setup` alias in `mix.exs` so they always run
> together:
````

If editing this guide for Phase 53, update alias examples to include `Mix.Task.reenable("ecto.migrate")` between migration phases, matching `examples/cairnloop_example/mix.exs` lines 99-115.

---

### `guides/04-troubleshooting.md` (docs, file-I/O)

**Analog:** `guides/04-troubleshooting.md`

**Stale migration section to replace** (lines 39-69):
````markdown
## Migration Order: Host Tables Before Library Tables

**Symptom:** `mix ecto.migrate` (or `mix test.setup`) fails with a foreign-key error,
such as a reference to `cairnloop_conversations` that does not yet exist.

**Fix:** Always run host-owned table migrations before library migrations. Pass both
`--migrations-path` flags to `ecto.migrate` in the correct order:

```bash
mix ecto.migrate \
  --migrations-path priv/my_app/migrations \
  --migrations-path priv/repo/migrations
```

Ecto merges and sorts by version timestamp, so host-owned tables (created first with
earlier timestamps such as `20260101...`) precede the library migrations.
````

Replace this merged-path guidance with the two-command pattern from `examples/cairnloop_example/mix.exs` lines 99-115. The current text is wrong for this repo because Ecto globally sorts all paths.

**Missing config docs pattern** (lines 107-143):
````markdown
## Common Mount Configuration Errors

| Config key | Behaviour | Required for |
|---|---|---|
| `:context_provider` | `Cairnloop.ContextProvider` | AI context snippets |
| `:notifier` | `Cairnloop.Notifier` | Outbound delivery callbacks |
| `:automation_policy` | `Cairnloop.AutomationPolicy` | AI drafting policy |
| `:sla_policy_provider` | `Cairnloop.SLAPolicyProvider` | SLA escalation rules |

```elixir
config :cairnloop, :context_provider, MyApp.CairnloopContext
config :cairnloop, :notifier, MyApp.CairnloopNotifier
config :cairnloop, :automation_policy, MyApp.CairnloopPolicy
config :cairnloop, :sla_policy_provider, MyApp.CairnloopSLA
```
````

**pgvector/manual DB pattern** (lines 87-105):
````markdown
1. Verify your Postgres version is 16 or higher.
2. Install the `pgvector` extension in Postgres. For local development with Docker, the
   example app ships a `docker-compose.yml` that starts a pgvector-enabled Postgres:

   ```bash
   # from the repo root
   docker compose up -d db
   ```

3. Enable the extension in your database:

   ```sql
   CREATE EXTENSION IF NOT EXISTS vector;
   ```
````

Add Phase 53 Docker troubleshooting only if it is narrow runtime-contract correction; broader wrapper UX docs belong to Phase 55.

## Shared Patterns

### Ordered Migrations

**Source:** `examples/cairnloop_example/mix.exs` lines 90-115
**Apply to:** `mix.exs`, `Dockerfile.demo`, docs migration examples, setup validation

```elixir
cairnloop_migrations =
  if File.dir?("deps/cairnloop/priv/repo/migrations"),
    do: "deps/cairnloop/priv/repo/migrations",
    else: "../../priv/repo/migrations"

reenable_migrate = fn _ -> Mix.Task.reenable("ecto.migrate") end

"ecto.setup": [
  "ecto.create",
  "ecto.migrate",
  reenable_migrate,
  "ecto.migrate --migrations-path #{cairnloop_migrations}",
  "run priv/repo/seeds.exs"
]
```

### Environment Split

**Source:** `examples/cairnloop_example/config/dev.exs` lines 3-14 and `runtime.exs` lines 38-69
**Apply to:** dev/test/runtime config, Compose, docs

Use `PGHOST` / `PGPORT` / `PGUSER` / `PGPASSWORD` / `PGDATABASE` for dev and Docker. Use `DATABASE_URL` only in prod runtime config. Keep `PHX_BIND` allowlisted to `127.0.0.1` or `0.0.0.0`.

### Operations Health

**Source:** `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` lines 59-63 and `compose.demo.yml` lines 53-58
**Apply to:** router, Compose readiness, Docker smoke docs

```elixir
scope "/" do
  Cairnloop.Router.cairnloop_operations()
end
```

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:4000/health >/dev/null"]
```

### No-Op Demo Notifier

**Source:** `lib/cairnloop/notifier.ex` lines 10-22 and `lib/mix/tasks/cairnloop.gen.notifier.ex` lines 77-107
**Apply to:** `demo_notifier.ex`, `config/config.exs`

Implement all three callbacks and return `:ok`. Do not trigger Chimeway in Phase 53.

### Seed Readiness

**Source:** `examples/cairnloop_example/priv/repo/seeds.exs` lines 96-109, 1278-1315, 1900-1918
**Apply to:** seeds and seed tests

Run builders through real facades, drain `Oban.drain_queue(queue: :default, with_recursion: true)`, then assert seed readiness via DB-backed ExUnit.

### DB-Backed Test Marking

**Source:** `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` lines 1-11 and `widget_channel_oban_test.exs` lines 13-20
**Apply to:** DB-backed example tests

```elixir
use CairnloopExample.DataCase, async: false
@moduletag :requires_postgres
```

### Docker URL And Smoke Docs

**Source:** `bin/demo` lines 61-85 and 130-155
**Apply to:** README, example README, quickstart, troubleshooting references

```bash
./bin/demo urls
./bin/demo logs
./bin/demo stop
./bin/demo reset
./bin/demo smoke
```

Docs should point Docker users to URLs printed by `./bin/demo`. Hard-coded `http://localhost:4000` belongs only to manual local Phoenix setup.

## No Analog Found

No files are completely without analogs. `examples/cairnloop_example/lib/cairnloop_example/demo_notifier.ex` has no exact existing example-only notifier, but the behaviour contract, generator template, and existing example provider module give a close role-match.

## Metadata

**Analog search scope:** `examples/cairnloop_example`, `lib/cairnloop`, `lib/mix/tasks`, `test`, `guides`, root `README.md`, and `bin/demo`; vendored deps, `_build`, and `node_modules` were excluded after an initial noisy search.

**Files scanned:** 312 source/docs/config files after exclusions.

**Pattern extraction date:** 2026-06-28

**Dirty worktree note:** many Phase 53-relevant files are already modified or untracked. Planner/executor should diff current worktree before tasking and must preserve unrelated user changes.
