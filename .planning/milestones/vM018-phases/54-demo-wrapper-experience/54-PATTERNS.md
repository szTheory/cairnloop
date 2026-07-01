# Phase 54: Demo Wrapper Experience - Pattern Map

**Mapped:** 2026-06-28
**Files analyzed:** 5
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `bin/demo` | utility / CLI wrapper | request-response + batch | `bin/demo` | exact |
| `test/cairnloop/demo_wrapper_contract_test.exs` | test | file-I/O + transform | `test/cairnloop/web/collateral_wiring_test.exs` | role-match |
| `examples/cairnloop_example/compose.demo.yml` | config | request-response | `examples/cairnloop_example/compose.demo.yml` | exact |
| `examples/cairnloop_example/Dockerfile.demo` | config | batch | `examples/cairnloop_example/Dockerfile.demo` | exact |
| `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` | route | request-response | `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` + `lib/cairnloop/router.ex` | exact |

## Pattern Assignments

### `bin/demo` (utility / CLI wrapper, request-response + batch)

**Analog:** `bin/demo`

Use this file as the exact implementation surface. Harden it in place; do not add a competing primary wrapper.

**Bash prelude and Compose scoping pattern** (lines 1-24):

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT/examples/cairnloop_example/compose.demo.yml"
CONTAINER_PORT=4000

default_project_name() {
  local base hash
  base="$(basename "$ROOT" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-')"
  base="${base%-}"
  hash="$(printf '%s' "$ROOT" | cksum | awk '{print $1}')"
  printf '%s_demo_%s' "$base" "$hash"
}

export CAIRNLOOP_COMPOSE_PROJECT="${CAIRNLOOP_COMPOSE_PROJECT:-$(default_project_name)}"
export CAIRNLOOP_WEB_PORT="${CAIRNLOOP_WEB_PORT:-4100-4199}"
export CAIRNLOOP_BIND_HOST="${CAIRNLOOP_BIND_HOST:-127.0.0.1}"
export LOCAL_UID="${LOCAL_UID:-$(id -u)}"
export LOCAL_GID="${LOCAL_GID:-$(id -g)}"

compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}
```

Copy the `ROOT`, `COMPOSE_FILE`, exported env, and `compose()` wrapper shape for every command. All Docker operations should remain project-scoped through this helper.

**Docker prerequisite guard pattern** (lines 26-35):

```bash
require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed or not on PATH." >&2
    exit 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose v2 is required. Install Docker Desktop or the Compose plugin." >&2
    exit 1
  fi
}
```

Keep command availability checks, not version-string parsing. Local research found `docker compose version` reports `v5.1.3`, so do not hard-code a `v2.*` prefix.

**Authoritative URL discovery pattern** (lines 37-59):

```bash
web_endpoint() {
  compose port web "$CONTAINER_PORT" 2>/dev/null | tail -n 1
}

base_url() {
  local endpoint host port
  endpoint="$(web_endpoint)"
  if [[ -z "$endpoint" ]]; then
    echo "The demo web service is not running yet. Run ./bin/demo first." >&2
    exit 1
  fi

  host="${endpoint%:*}"
  port="${endpoint##*:}"
  host="${host#[}"
  host="${host%]}"

  if [[ "$host" == "0.0.0.0" || "$host" == "::" ]]; then
    host="127.0.0.1"
  fi

  printf 'http://%s:%s' "$host" "$port"
}
```

Copy the `docker compose port web 4000` source of truth and wildcard-host normalization. Harden `start`/`smoke` so delayed port discovery retries before treating this as fatal; keep `urls` fail-closed when no running web service exists.

**Printed route block pattern** (lines 61-85):

```bash
print_urls() {
  local url
  url="$(base_url)"

  cat <<URLS

Cairnloop demo is ready.

Demo index:        $url/
Operator cockpit:  $url/support
Inbox:             $url/support/inbox
Customer chat:     $url/chat
Knowledge Base:    $url/support/knowledge-base
Gaps:              $url/support/knowledge-base/gaps
Suggestions:       $url/support/knowledge-base/suggestions
Audit log:         $url/support/audit-log
Settings:          $url/support/settings
Health:            $url/health

Useful commands:
  ./bin/demo logs    Follow web and db logs
  ./bin/demo stop    Stop containers, keep the seeded database
  ./bin/demo reset   Delete demo volumes and reseed from scratch

URLS
}
```

`./bin/demo urls` should print this same block after discovering the running port. Keep route labels and paths synchronized with the smoke route list and `Cairnloop.Router.cairnloop_dashboard/2`.

**Readiness and web-log failure pattern** (lines 88-121):

```bash
wait_for_health() {
  local url attempts
  url="$(base_url)/health"
  attempts=120

  printf 'Waiting for %s' "$url"
  until curl -fsS "$url" >/dev/null 2>&1; do
    attempts=$((attempts - 1))
    if [[ "$attempts" -le 0 ]]; then
      echo
      echo "Demo did not become healthy. Recent web logs:" >&2
      compose logs --tail=80 web >&2 || true
      exit 1
    fi
    printf '.'
    sleep 1
  done
  echo
}

smoke_route() {
  local url route
  url="$1"
  route="$2"

  if curl -fsSL "$url$route" >/dev/null; then
    printf 'ok  %s\n' "$route"
  else
    echo "Smoke check failed for $url$route" >&2
    echo "Recent web logs:" >&2
    compose logs --tail=80 web >&2 || true
    exit 1
  fi
}
```

Extract or reuse small helpers for recent web logs and failure messages if it makes `compose up` diagnostics consistent. Preserve the calm, route-specific error copy and recent web logs.

**Start, smoke, cleanup, and route smoke pattern** (lines 123-156):

```bash
start_demo() {
  require_docker
  compose up -d --build
  wait_for_health
  print_urls
}

smoke_demo() (
  require_docker

  export CAIRNLOOP_COMPOSE_PROJECT="${CAIRNLOOP_COMPOSE_PROJECT}_smoke"
  export CAIRNLOOP_WEB_PORT="${CAIRNLOOP_SMOKE_WEB_PORT:-${CAIRNLOOP_WEB_PORT}}"

  trap 'compose down -v --remove-orphans >/dev/null 2>&1 || true' EXIT

  compose down -v --remove-orphans >/dev/null 2>&1 || true
  compose up -d --build
  wait_for_health

  url="$(base_url)"
  echo "Running smoke checks against $url"

  smoke_route "$url" "/"
  smoke_route "$url" "/support"
  smoke_route "$url" "/support/inbox"
  smoke_route "$url" "/chat"
  smoke_route "$url" "/support/knowledge-base"
  smoke_route "$url" "/support/knowledge-base/gaps"
  smoke_route "$url" "/support/knowledge-base/suggestions"
  smoke_route "$url" "/support/audit-log"
  smoke_route "$url" "/support/settings"

  echo "Docker demo smoke passed."
)
```

Keep smoke in a subshell with `_smoke` project suffix, optional `CAIRNLOOP_SMOKE_WEB_PORT`, and `down -v --remove-orphans` EXIT cleanup. If wrapping `compose up` for diagnostics, do it without weakening the cleanup trap.

**Command surface pattern** (lines 158-223):

```bash
usage() {
  cat <<'HELP'
Usage: ./bin/demo [command]

Commands:
  start, up    Build/start the Docker demo and print clickable URLs (default)
  smoke        Boot an isolated stack, check the main demo routes, then clean up
  urls         Print URLs for the running demo
  logs         Follow web and db logs
  stop         Stop containers and preserve named volumes
  down         Remove containers/network and preserve named volumes
  reset        Remove containers/network/volumes, then rebuild and reseed
  ps           Show Compose service status
  help         Show this help

Environment:
  CAIRNLOOP_WEB_PORT=4100-4199       Localhost port range, or a fixed port
  CAIRNLOOP_SMOKE_WEB_PORT=<range>   Optional port/range for ./bin/demo smoke
  CAIRNLOOP_BIND_HOST=127.0.0.1      Host interface for the browser-facing port
  CAIRNLOOP_COMPOSE_PROJECT=<name>   Compose project namespace
  OPENAI_API_KEY=<key>               Optional semantic embeddings in seeded data
HELP
}

cmd="${1:-start}"

case "$cmd" in
  start|up)
    start_demo
    ;;
  smoke)
    smoke_demo
    ;;
  urls)
    require_docker
    print_urls
    ;;
  logs)
    require_docker
    compose logs -f web db
    ;;
  stop)
    require_docker
    compose stop
    ;;
  down)
    require_docker
    compose down --remove-orphans
    ;;
  reset)
    require_docker
    compose down -v --remove-orphans
    start_demo
    ;;
  ps|status)
    require_docker
    compose ps
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
```

Preserve every command and alias. The known Phase 54 help drift is here: `status` works in the case branch but is missing from help. Add it without renaming `ps`.

---

### `test/cairnloop/demo_wrapper_contract_test.exs` (test, file-I/O + transform)

**Primary analog:** `test/cairnloop/web/collateral_wiring_test.exs`
**Secondary analogs:** `test/cairnloop/web/brand_token_gate_test.exs`, `test/integration/dashboard_wiring_test.exs`

Use a DB-free ExUnit source/contract test. It should be safe in `mix ci.fast`; do not require Docker for the unit test. Keep full Docker behavior in the phase gate with `docker compose ... config --quiet` and `./bin/demo smoke`.

**DB-free source test module pattern** (`test/cairnloop/web/collateral_wiring_test.exs` lines 1-8):

```elixir
defmodule Cairnloop.Web.CollateralWiringTest do
  @moduledoc """
  Pure source, package, SVG, and raster guard for Phase 52 collateral wiring.

  The test reads static files only: no Repo, no Endpoint, no Phoenix server.
  """
  use ExUnit.Case, async: true
```

Copy the `use ExUnit.Case, async: true` style and explicit "static files only" posture.

**File-read assertion pattern** (`test/cairnloop/web/collateral_wiring_test.exs` lines 97-122):

```elixir
test "example app collateral copies approved assets and uses existing static paths" do
  assert File.read!("examples/cairnloop_example/priv/static/images/logo.svg") ==
           File.read!("logo/cairnloop-lockup-horizontal.svg"),
         "Expected example app logo.svg to be a byte-for-byte copy of the approved horizontal lockup"

  assert File.read!("examples/cairnloop_example/priv/static/favicon.ico") ==
           File.read!("logo/favicon.ico"),
         "Expected example app favicon.ico to be a byte-for-byte copy of the approved favicon"

  web_ex = File.read!("examples/cairnloop_example/lib/cairnloop_example_web.ex")
  endpoint = File.read!("examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex")

  assert web_ex =~ "def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)",
         "Expected CairnloopExampleWeb.static_paths/0 to keep the existing static path allowlist"

  assert endpoint =~ "only: CairnloopExampleWeb.static_paths()",
         "Expected Plug.Static to keep serving the existing static_paths/0 allowlist"
end
```

For Phase 54, adapt this shape to read `bin/demo` and `examples/cairnloop_example/compose.demo.yml`, then assert contract strings such as `docker compose -f "$COMPOSE_FILE"`, `compose port web "$CONTAINER_PORT"`, `CAIRNLOOP_WEB_PORT:-4100-4199`, `CAIRNLOOP_SMOKE_WEB_PORT`, `compose down -v --remove-orphans`, and `compose logs --tail=80 web`.

**Expected source-string list pattern** (`test/cairnloop/web/collateral_wiring_test.exs` lines 237-260):

```elixir
test "collateral E2E source proves browser rendering and asset fetches" do
  path = "examples/cairnloop_example/test/e2e/collateral_wiring_test.exs"
  assert File.exists?(path), "Expected #{path} to exist"

  source = File.read!(path)

  for expected <- [
        "defmodule CairnloopExampleWeb.CollateralWiringE2ETest",
        "use PhoenixTest.Playwright.Case",
        "@moduletag :e2e",
        ~s|visit("/")|,
        ~s(body .phx-connected),
        "getBoundingClientRect",
        "naturalWidth",
        "naturalHeight",
        "fetch(",
        "/images/logo.svg",
        "/favicon.ico",
        "/images/favicon.svg",
        "/images/cairnloop-og.png",
        "og:image:alt"
      ] do
    assert source =~ expected, "Expected collateral E2E source to include #{inspect(expected)}"
  end
end
```

Use this loop style for wrapper contract strings and help text strings. This keeps failures short and actionable.

**Path and line-number scan pattern** (`test/cairnloop/web/brand_token_gate_test.exs` lines 164-190):

```elixir
test "no hex-fallback strings remain in lib/cairnloop/web/ or examples/cairnloop_example/lib/cairnloop_example_web/live/ (BRAND-04, Phase 29 D-10 closure)" do
  files =
    Path.wildcard(Path.join(@web_dir, "**/*.ex")) ++
      Path.wildcard(Path.join(@example_live_dir, "**/*.ex"))

  refute files == [],
         "Expected to find .ex files in both #{@web_dir} and #{@example_live_dir}; got empty list - check path resolution"

  violations =
    for file <- files,
        {line, line_no} <- file |> File.read!() |> String.split("\n") |> Enum.with_index(1),
        Regex.match?(@hex_fallback_pattern, line) do
      {Path.basename(file), line_no, String.trim(line)}
    end

  assert violations == [],
         """
         BRAND-04 contract violated - hex fallbacks found in sealed render files.

         Violations:
         #{Enum.map_join(violations, "\n", fn {file, line_no, line} -> "  #{file}:#{line_no} - #{line}" end)}
         """
end
```

Adapt this if Phase 54 needs negative scans, for example: no `localhost:4000` in `bin/demo`, no `ports:` under the Compose `db:` block, no route drift between `print_urls` and `smoke_route`.

**Shell syntax check pattern** (`test/cairnloop/web/collateral_wiring_test.exs` lines 182-190):

```elixir
for path <- svg_paths do
  {xmllint_output, xmllint_exit} =
    System.cmd("xmllint", ["--noout", path], stderr_to_stdout: true)

  assert xmllint_exit == 0,
         "Expected #{path} to be XML well-formed; xmllint output:\n#{xmllint_output}"
```

For `bin/demo`, the safe adaptation is `System.cmd("bash", ["-n", "bin/demo"], stderr_to_stdout: true)`. Avoid `docker` in `mix ci.fast` source tests; Docker belongs in explicit phase verification.

**Route inventory assertion pattern** (`test/integration/dashboard_wiring_test.exs` lines 74-89):

```elixir
test "cairnloop_dashboard mounts the full operator surface" do
  by_path = handler_by_path()

  # Cockpit Home is the task-oriented landing; the inbox moved to <path>/inbox.
  assert by_path["/support"] == Cairnloop.Web.HomeLive
  assert by_path["/support/inbox"] == Cairnloop.Web.InboxLive
  assert by_path["/support/knowledge-base"] == Cairnloop.Web.KnowledgeBaseLive.Index
  assert by_path["/support/knowledge-base/gaps"] == Cairnloop.Web.KnowledgeBaseLive.Gaps

  assert by_path["/support/knowledge-base/suggestions"] ==
           Cairnloop.Web.KnowledgeBaseLive.SuggestionReview

  assert by_path["/support/knowledge-base/:id/edit"] == Cairnloop.Web.KnowledgeBaseLive.Editor
  assert by_path["/support/settings"] == Cairnloop.Web.SettingsLive
  assert by_path["/support/:id"] == Cairnloop.Web.ConversationLive
end
```

Use this as the source of truth for the wrapper route list. The wrapper smoke should check the route paths locked in Phase 54, not invent new route coverage.

---

### `examples/cairnloop_example/compose.demo.yml` (config, request-response)

**Analog:** `examples/cairnloop_example/compose.demo.yml`

The current Compose file is already the contract. Preserve its private DB and dynamic localhost web binding. Only edit if a wrapper-hardening need exposes a real config bug.

**Private database service pattern** (lines 1-18):

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

No `ports:` block belongs under `db`. Postgres must stay private to the Compose network.

**Web service env and dynamic localhost port pattern** (lines 19-44):

```yaml
web:
  build:
    context: ../..
    dockerfile: examples/cairnloop_example/Dockerfile.demo
    args:
      UID: ${LOCAL_UID:-1000}
      GID: ${LOCAL_GID:-1000}
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
```

Keep `PGHOST`/`PGPORT`/`PGUSER`/`PGPASSWORD`/`PGDATABASE`, `PORT`, and `PHX_BIND`. Do not switch the demo to `DATABASE_URL`. Keep `host_ip` explicit and the published port range dynamic.

**Healthcheck and named volume pattern** (lines 45-67):

```yaml
    volumes:
      - ../..:/workspace
      - demo_example_deps:/workspace/examples/cairnloop_example/deps
      - demo_example_build:/workspace/examples/cairnloop_example/_build
      - demo_static_assets:/workspace/examples/cairnloop_example/priv/static/assets
      - demo_mix:/home/app/.mix
      - demo_hex:/home/app/.hex
      - demo_rebar:/home/app/.cache/rebar3
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:4000/health >/dev/null"]
      interval: 5s
      timeout: 5s
      retries: 30
      start_period: 20s

volumes:
  demo_db_data:
  demo_example_deps:
  demo_example_build:
  demo_static_assets:
  demo_mix:
  demo_hex:
  demo_rebar:
```

The wrapper readiness should continue to hit the externally discovered `/health` URL, while Compose uses the internal `127.0.0.1:4000/health` service healthcheck.

---

### `examples/cairnloop_example/Dockerfile.demo` (config, batch)

**Analog:** `examples/cairnloop_example/Dockerfile.demo`

This file is a contract reference for the Docker-only adopter path. It is unlikely to need Phase 54 changes.

**Image and runtime dependency pattern** (lines 1-20):

```dockerfile
# syntax=docker/dockerfile:1.7

FROM hexpm/elixir:1.19.5-erlang-27.2.4-debian-trixie-20260623-slim

ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive

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

`curl` is already installed in the image for Compose healthchecks. The adopter wrapper should not introduce host Elixir or host Postgres prerequisites.

**Container user, workdir, and setup command pattern** (lines 33-40):

```dockerfile
USER app
WORKDIR /workspace/examples/cairnloop_example

RUN mix local.hex --force && mix local.rebar --force

EXPOSE 4000

CMD ["sh", "-lc", "mix setup && exec mix phx.server"]
```

Preserve `mix setup && exec mix phx.server`; Phase 53 verified that this owns migrations and seeds.

---

### `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` (route, request-response)

**Analog:** `examples/cairnloop_example/lib/cairnloop_example_web/router.ex`
**Route macro source:** `lib/cairnloop/router.ex`

The wrapper's URL and smoke route list should mirror these route contracts. Avoid changing router behavior for Phase 54 unless a smoke route is demonstrably wrong.

**Example app mount pattern** (`examples/cairnloop_example/lib/cairnloop_example_web/router.ex` lines 34-63):

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

scope "/", CairnloopExampleWeb do
  pipe_through :browser

  get "/", PageController, :home
  live "/chat", ChatLive
end

# Operations endpoints (OPS-01, OPS-02): GET /health and GET /metrics. Mounted
# outside the :browser pipeline so infrastructure can probe them without CSRF/session.
scope "/" do
  Cairnloop.Router.cairnloop_operations()
end
```

Keep `/health` outside the browser pipeline. The demo wrapper should wait on this route before printing URLs.

**Dashboard route inventory pattern** (`lib/cairnloop/router.ex` lines 102-135):

```elixir
defmacro cairnloop_dashboard(path, opts \\ []) do
  # Split Cairnloop's own options from the live_session pass-through options, validate ours,
  # and forward the rest unchanged. Done at expansion so a bad `:live_session_name` raises a
  # clear compile-time error instead of a confusing Phoenix failure.
  {cairnloop_opts, session_opts} = Keyword.split(opts, [:live_session_name])
  cairnloop_opts = NimbleOptions.validate!(cairnloop_opts, @dashboard_opts_schema)
  live_session_name = cairnloop_opts[:live_session_name]
  session_opts = put_dashboard_session(session_opts, path)

  quote do
    scope unquote(path), alias: false, as: false do
      import Phoenix.LiveView.Router, only: [live: 3, live: 4, live_session: 3]

      # Host apps should provide `host_user_id` in the live session payload so
      # dashboard surfaces can keep operator search tenant-scoped.
      live_session unquote(live_session_name), unquote(session_opts) do
        # Cockpit Home is the task-oriented landing; the inbox moves to /inbox so
        # an operator who lands on "/" is oriented, not dumped into a bare list.
        live("/", Cairnloop.Web.HomeLive, :index, as: :cairnloop_home)
        live("/inbox", Cairnloop.Web.InboxLive, :index, as: :cairnloop_inbox)
        live("/audit-log", Cairnloop.Web.AuditLogLive, :index, as: :cairnloop_audit_log)
        live("/knowledge-base", Cairnloop.Web.KnowledgeBaseLive.Index, :index)
        live("/knowledge-base/gaps", Cairnloop.Web.KnowledgeBaseLive.Gaps, :index)

        live(
          "/knowledge-base/suggestions",
          Cairnloop.Web.KnowledgeBaseLive.SuggestionReview,
          :index
        )

        live("/knowledge-base/:id/edit", Cairnloop.Web.KnowledgeBaseLive.Editor, :edit)
        live("/settings", Cairnloop.Web.SettingsLive, :index, as: :cairnloop_settings)
        live("/:id", Cairnloop.Web.ConversationLive, :show, as: :cairnloop_conversation)
      end
    end
  end
end
```

Use the concrete mounted routes for smoke coverage: `/support`, `/support/inbox`, `/support/knowledge-base`, `/support/knowledge-base/gaps`, `/support/knowledge-base/suggestions`, `/support/audit-log`, and `/support/settings`.

**Operations route pattern** (`lib/cairnloop/router.ex` lines 52-60):

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

The wrapper's readiness URL must remain `/health` unless this macro mount changes.

## Shared Patterns

### Wrapper Command Surface

**Source:** `bin/demo` lines 158-223
**Apply to:** `bin/demo`, `test/cairnloop/demo_wrapper_contract_test.exs`

Preserve `start|up`, `urls`, `logs`, `status|ps`, `stop`, `down`, `reset`, `smoke`, and `help|-h|--help`. Add source-test coverage that help advertises both `ps` and `status`.

### Compose-Scoped Cleanup

**Source:** `bin/demo` lines 130-139
**Apply to:** `bin/demo`, smoke verification

```bash
smoke_demo() (
  require_docker

  export CAIRNLOOP_COMPOSE_PROJECT="${CAIRNLOOP_COMPOSE_PROJECT}_smoke"
  export CAIRNLOOP_WEB_PORT="${CAIRNLOOP_SMOKE_WEB_PORT:-${CAIRNLOOP_WEB_PORT}}"

  trap 'compose down -v --remove-orphans >/dev/null 2>&1 || true' EXIT

  compose down -v --remove-orphans >/dev/null 2>&1 || true
```

Use only Compose-project-scoped teardown. Do not use `docker system prune`, global volume removal, or fixed smoke ports.

### Route-Based Readiness

**Source:** `bin/demo` lines 88-106 and `examples/cairnloop_example/compose.demo.yml` lines 53-58
**Apply to:** `bin/demo`, final smoke verification

```bash
wait_for_health() {
  local url attempts
  url="$(base_url)/health"
  attempts=120

  printf 'Waiting for %s' "$url"
  until curl -fsS "$url" >/dev/null 2>&1; do
```

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:4000/health >/dev/null"]
  interval: 5s
  timeout: 5s
  retries: 30
  start_period: 20s
```

Keep readiness tied to `/health`, not log text or arbitrary sleeps.

### Failure Diagnostics

**Source:** `bin/demo` lines 96-100 and 115-119
**Apply to:** `bin/demo`

```bash
if [[ "$attempts" -le 0 ]]; then
  echo
  echo "Demo did not become healthy. Recent web logs:" >&2
  compose logs --tail=80 web >&2 || true
  exit 1
fi
```

```bash
else
  echo "Smoke check failed for $url$route" >&2
  echo "Recent web logs:" >&2
  compose logs --tail=80 web >&2 || true
  exit 1
fi
```

Use this web-focused diagnostic style for health timeout, route failure, and compose-up failure. Include the failing command when the failing boundary is a command such as `compose up -d --build`.

### Verification Lanes

**Source:** `mix.exs` lines 112-119
**Apply to:** Phase verification and test placement

```elixir
# Fast CI lane: DB-free, locked deps, warnings-clean compile, and the complete headless
# ExUnit suite. DB-backed checks stay in `ci.integration`.
"ci.fast": [
  "deps.get --check-locked",
  "format --check-formatted",
  "compile --warnings-as-errors",
  "test --exclude integration --warnings-as-errors"
],
```

Keep the new source test DB-free so it can run in `mix ci.fast`. Phase close should still run:

```bash
mix ci.fast
docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet
./bin/demo smoke
```

## No Analog Found

None.

| File | Role | Data Flow | Reason |
|---|---|---|---|
| - | - | - | All Phase 54 target/contract files have exact or role-match analogs. |

## Metadata

**Analog search scope:** `bin/`, `examples/cairnloop_example/`, `lib/cairnloop/`, `test/`, `mix.exs`, `.planning/phases/53-demo-runtime-contract/`
**Files scanned:** 308 targeted files (`rg --files bin examples/cairnloop_example lib/cairnloop test mix.exs`), 449 repo files total
**Project instructions read:** `CLAUDE.md`, `AGENTS.md`; no project-local `.codex/skills/` or `.agents/skills/` directories were found
**Pattern extraction date:** 2026-06-28
