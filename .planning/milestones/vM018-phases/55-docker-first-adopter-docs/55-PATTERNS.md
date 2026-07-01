# Phase 55: Docker-First Adopter Docs - Pattern Map

**Mapped:** 2026-06-28
**Files analyzed:** 5 likely new/modified implementation files
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `README.md` | documentation | file-I/O / ExDoc render | `README.md` + `mix.exs` | exact |
| `guides/01-quickstart.md` | documentation | file-I/O / ExDoc render | `guides/01-quickstart.md` + `bin/demo` | exact |
| `examples/cairnloop_example/README.md` | documentation | file-I/O / adopter walkthrough | `guides/01-quickstart.md` + `examples/cairnloop_example/README.md` | role-match |
| `guides/04-troubleshooting.md` | documentation | file-I/O / symptom remediation | `guides/04-troubleshooting.md` + `guides/01-quickstart.md` | exact |
| `test/cairnloop/docs/docker_first_docs_test.exs` | test | file-I/O / source-scan | `test/cairnloop/demo_wrapper_contract_test.exs` + `test/cairnloop/web/collateral_wiring_test.exs` | role-match |

Reference-only files that should not be modified in Phase 55: `bin/demo`, `mix.exs`, `examples/cairnloop_example/compose.demo.yml`, `examples/cairnloop_example/Dockerfile.demo`, and `examples/cairnloop_example/lib/cairnloop_example_web/router.ex`.

## Pattern Assignments

### `README.md` (documentation, file-I/O / ExDoc render)

**Analog:** `README.md`

**Docker-first opening pattern** (`README.md` lines 11-27):
````markdown
### Try the live demo first

From a fresh clone, the fastest way to see Cairnloop working is the Docker demo:

```bash
./bin/demo
```

The command starts the example Phoenix app, a private pgvector Postgres container, migrations, and
the realistic Trailmark seed data. Start with the demo index URL printed by `./bin/demo`; it also
prints the exact local URLs to click: the demo index,
operator cockpit, inbox, customer chat, knowledge base, audit log, settings, and health probe.
````

**Port and smoke wording pattern** (`README.md` lines 24-27):
```markdown
The demo publishes only the Phoenix UI on `127.0.0.1` and uses a dynamic port range by default, so
it can run alongside other local Dockerized UI demos without fighting over `4000`, `5432`, or
`5433`. Use `./bin/demo reset` when you want a clean reseeded database, and `./bin/demo smoke` to
boot an isolated stack and verify the main demo routes end to end.
```

**Secondary install path pattern** (`README.md` lines 29-43):
````markdown
### Install in your app

The fastest way to install Cairnloop is with the Igniter installer. First, add Igniter to your
dependencies if it is not already present, then run:

```bash
mix deps.get
mix cairnloop.install
```
````

**ExDoc/package source-of-truth pattern** (`mix.exs` lines 22-61):
```elixir
package: [
  name: "cairnloop",
  files: ~w(
      lib
      priv
      mix.exs
      README.md
      LICENSE
      CHANGELOG.md
      guides/01-quickstart.md
      guides/02-jtbd-walkthrough.md
      guides/03-host-integration.md
      guides/04-troubleshooting.md
      guides/05-mcp-clients.md
      guides/06-extending.md
      guides/07-auth-and-operator-identity.md
    ),
  ...
],
docs: [
  main: "readme",
  extras: [
    {"guides/01-quickstart.md", title: "Quickstart"},
    ...
    {"guides/04-troubleshooting.md", title: "Troubleshooting"},
    ...
    "README.md",
    "CHANGELOG.md"
  ],
  groups_for_extras: [
    Guides: ~r/^guides\//
  ],
```

**Planner notes:**
- Keep README's first-run command as `./bin/demo`, not `mix setup`, raw `docker compose`, or a hard-coded URL.
- If touching dependency snippets, use current repo version from `mix.exs` line 7 (`version: "0.5.1"`) instead of preserving stale `~> 0.1.0`.
- Update the Troubleshooting guide link copy at `README.md` lines 92-93 so Docker demo failure recovery is part of the description, not only legacy install/migration help.

---

### `guides/01-quickstart.md` (documentation, file-I/O / ExDoc render)

**Analog:** `guides/01-quickstart.md`

**Fastest-path section pattern** (`guides/01-quickstart.md` lines 6-27):
````markdown
## Fastest path: Docker demo

If your goal is to click around the operator UI and understand the product, start here:

```bash
./bin/demo
```

That single command starts a private pgvector Postgres container, builds the example Phoenix app,
runs migrations, loads the realistic Trailmark seed data, waits for `/health`, and prints the URLs
you need next. Start with the demo index URL printed by `./bin/demo`:

- demo index (`/`)
- operator cockpit (`/support`)
- inbox (`/support/inbox`)
- customer chat (`/chat`)
- knowledge base, gaps, suggestions, audit log, settings, and health probe
````

**Manual prerequisites are secondary** (`guides/01-quickstart.md` lines 52-68):
```markdown
## Prerequisites

- **Elixir 1.15+ / OTP 26+**
- **Postgres 16+** with the `pgvector` extension installed

You only need these prerequisites for the manual local workflow below. The Docker demo carries its
own Elixir runtime and pgvector Postgres.
```

**Manual boot pattern** (`guides/01-quickstart.md` lines 208-229):
````markdown
## Manual boot

The commands below are for the example app when you want to run Elixir directly on your machine.
Switch into it first, then set up the database and start the server:

```bash
cd examples/cairnloop_example
mix setup
mix phx.server
```
````

**Command vocabulary source** (`bin/demo` lines 240-261):
```bash
Usage: ./bin/demo [command]

Commands:
  start, up    Build/start the Docker demo and print clickable URLs (default)
  smoke        Boot an isolated stack, check the main demo routes, then clean up
  urls         Print URLs for the running demo
  logs         Follow web and db logs
  stop         Stop containers and preserve named volumes
  down         Remove containers/network and preserve named volumes
  reset        Remove containers/network/volumes, then rebuild and reseed
  ps, status   Show Compose service status
  help         Show this help

Environment:
  CAIRNLOOP_WEB_PORT=4100-4199       Localhost port range, or a fixed port
  CAIRNLOOP_SMOKE_WEB_PORT=<range>   Optional port/range for ./bin/demo smoke
  CAIRNLOOP_BIND_HOST=127.0.0.1      Host interface for the browser-facing port
  CAIRNLOOP_COMPOSE_PROJECT=<name>   Compose project namespace
  OPENAI_API_KEY=<key>               Optional semantic embeddings in seeded data
```

**Planner notes:**
- Expand the current useful command block (`guides/01-quickstart.md` lines 29-37) only to the locked wrapper vocabulary above.
- Keep `localhost:4000` only in manual local Phoenix context (`guides/01-quickstart.md` lines 219-222).
- Update the final Troubleshooting link (`guides/01-quickstart.md` lines 258-259) to include Docker demo failure modes.

---

### `examples/cairnloop_example/README.md` (documentation, file-I/O / adopter walkthrough)

**Analog:** `examples/cairnloop_example/README.md` plus `guides/01-quickstart.md`

**Current Docker setup pattern to preserve** (`examples/cairnloop_example/README.md` lines 19-42):
````markdown
### Docker demo

From the repository root:

```bash
./bin/demo
```

The command builds the example app, starts a private pgvector Postgres service, runs migrations,
loads the realistic Trailmark seed data, waits for the health probe, and prints the exact URLs to
open.
````

**Nested app rule** (`examples/cairnloop_example/AGENTS.md` lines 16-21):
```markdown
- Use `mix test.e2e` for the example app's browser lane. Use `./bin/demo smoke` from the repo root
  when validating Docker adoption flow.
- If local browser tests collide on `4002`, rerun with `PHX_TEST_PORT=<free-port> mix test.e2e`;
  CI keeps the default `4002`.
- Docker demo docs must point users to the URL printed by `./bin/demo`; only manual local Phoenix
  boot assumes `http://localhost:4000`.
```

**Printed URL truth** (`bin/demo` lines 82-106):
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
```

**Route source** (`examples/cairnloop_example/lib/cairnloop_example_web/router.ex` lines 42-57):
```elixir
Cairnloop.Router.cairnloop_dashboard("/support",
  session: {CairnloopExampleWeb.OperatorAuth, :cairnloop_session, []},
  on_mount:
    if(Application.compile_env(:cairnloop_example, :sql_sandbox),
      do: [CairnloopExampleWeb.LiveAcceptance],
      else: []
    )
)
...
get "/", PageController, :home
live "/chat", ChatLive
```

**Anti-patterns to replace** (`examples/cairnloop_example/README.md` lines 73-79 and 133-134):
```markdown
Open two browser tabs after running `mix setup && mix phx.server` in the
`examples/cairnloop_example/` directory.

- **Tab 1 - Operator inbox:** http://localhost:4000/support
- **Tab 2 - Customer chat:** http://localhost:4000/chat
```

```markdown
Visit [`localhost:4000/support`](http://localhost:4000/support) to view the Operator interface.
Visit [`localhost:4000/chat`](http://localhost:4000/chat) to interact with the mock customer ChatLive view.
```

**Planner notes:**
- Rewrite Two-Tab Demo and Routing with Docker first: "open the printed base URL and append `/support`" and "append `/chat`".
- Keep manual-local `localhost:4000` as a secondary sentence explicitly tied to `mix setup && mix phx.server`.
- Replace "mock customer ChatLive view" wording with real customer chat / real ingress wording from `examples/cairnloop_example/README.md` lines 115-116.

---

### `guides/04-troubleshooting.md` (documentation, file-I/O / symptom remediation)

**Analog:** `guides/04-troubleshooting.md`

**Existing troubleshooting style** (`guides/04-troubleshooting.md` lines 6-15):
```markdown
## `mix cairnloop.install` Prerequisites

**Symptom:** Running `mix cairnloop.install` fails immediately or has no effect.

**Cause:** Cairnloop's installer is an [Igniter](https://hexdocs.pm/igniter) task
(`use Igniter.Mix.Task`). If Igniter is not present in your app's deps, Mix cannot
load the task.

**Fix:** Add `{:igniter, "~> 0.5"}` to your `mix.exs` deps and run `mix deps.get`
before running the installer.
```

**Current pgvector/manual-local style** (`guides/04-troubleshooting.md` lines 77-109):
```markdown
## pgvector: Missing Postgres Extension

**Symptom:** Migrations or Knowledge Base embedding operations fail with an error
referencing an unknown type `vector`, such as:

...

**Cause:** Cairnloop's Knowledge Base requires Postgres 16+ with the `pgvector` extension
installed. The `vector` column type (used for embedding storage) is provided by `pgvector`
and must be present in the database before the relevant migrations run.
```

**Docker troubleshooting seed** (`guides/01-quickstart.md` lines 231-244):
```markdown
## Docker troubleshooting

**Another project is already using the port.** Run `./bin/demo` normally and use the printed URL.
The default Docker path chooses from `4100-4199`. For a fixed port, set `CAIRNLOOP_WEB_PORT`.

**You want to inspect Postgres from the host.** The demo does not publish Postgres by default. Use
`./bin/demo logs` first; if you need `psql`, add a temporary Compose override rather than changing
the default demo path.

**You want a clean demo state.** Use `./bin/demo reset`. `./bin/demo stop` and `./bin/demo down`
preserve named volumes so repeat launches stay fast.
```

**Wrapper failure messages to mirror** (`bin/demo` lines 26-35):
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

**Bounded diagnostics pattern** (`bin/demo` lines 109-129):
```bash
recent_web_logs() {
  echo "Recent web logs:" >&2
  compose logs --tail=80 web >&2 || true
}

fail_with_web_logs() {
  local message
  message="$1"
  echo "$message" >&2
  recent_web_logs
  exit 1
}
```

**Port fallback and no-port wording source** (`bin/demo` lines 132-164):
```bash
compose_up_with_port_fallback() {
  ...
  if [[ "$original_port" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    ...
      if [[ "$output" != *"address already in use"* &&
        "$output" != *"port is already allocated"* &&
        "$output" != *"ports are not available"* ]]; then
        fail_with_web_logs "Compose command failed while ${description}: docker compose -f \"$COMPOSE_FILE\" up -d --build"
      fi
    ...
    fail_with_web_logs "No available localhost port found for CAIRNLOOP_WEB_PORT=$original_port while ${description}."
  else
    run_compose_or_explain "$description" up -d --build
  fi
}
```

**Private Postgres and optional OpenAI truth** (`examples/cairnloop_example/compose.demo.yml` lines 4-18 and 29-44):
```yaml
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
...
web:
  environment:
    PGHOST: db
    PGPORT: "5432"
    ...
    OPENAI_API_KEY: ${OPENAI_API_KEY:-}
  ports:
    - name: web
      target: 4000
      published: "${CAIRNLOOP_WEB_PORT:-4100-4199}"
      host_ip: "${CAIRNLOOP_BIND_HOST:-127.0.0.1}"
```

**Planner notes:**
- Add a Docker demo troubleshooting section before the current installer/manual sections.
- Use symptom-first headings from `55-CONTEXT.md`: Docker missing, Compose v2 missing, no available port/fixed-port conflict, unhealthy stack, reset/reseed, Postgres split, optional OpenAI key, and smoke route failures.
- Point users to `./bin/demo logs`, `./bin/demo status`, `./bin/demo reset`, the failing route URL, and `/health` before raw Compose internals.

---

### `test/cairnloop/docs/docker_first_docs_test.exs` (test, file-I/O / source-scan)

**Analog:** `test/cairnloop/demo_wrapper_contract_test.exs`

**Module and DB-free contract pattern** (`test/cairnloop/demo_wrapper_contract_test.exs` lines 1-12):
```elixir
defmodule Cairnloop.DemoWrapperContractTest do
  @moduledoc """
  DB-free source contract for the Docker demo wrapper.

  The test reads wrapper and Compose source only. It never starts Docker,
  Phoenix, Repo, browser tooling, or `./bin/demo smoke`.
  """

  use ExUnit.Case, async: true

  @wrapper_path "bin/demo"
  @compose_path "examples/cairnloop_example/compose.demo.yml"
```

**Locked route attribute pattern** (`test/cairnloop/demo_wrapper_contract_test.exs` lines 14-37):
```elixir
@url_routes [
  {"Demo index:", "/"},
  {"Operator cockpit:", "/support"},
  {"Inbox:", "/support/inbox"},
  {"Customer chat:", "/chat"},
  {"Knowledge Base:", "/support/knowledge-base"},
  {"Gaps:", "/support/knowledge-base/gaps"},
  {"Suggestions:", "/support/knowledge-base/suggestions"},
  {"Audit log:", "/support/audit-log"},
  {"Settings:", "/support/settings"},
  {"Health:", "/health"}
]

@smoke_routes ~w(
  /
  /support
  /support/inbox
  /chat
  /support/knowledge-base
  /support/knowledge-base/gaps
  /support/knowledge-base/suggestions
  /support/audit-log
  /support/settings
)
```

**Wrapper help/source assertion pattern** (`test/cairnloop/demo_wrapper_contract_test.exs` lines 39-62):
```elixir
test "wrapper shell syntax and command surface stay canonical" do
  {bash_output, bash_exit} = System.cmd("bash", ["-n", @wrapper_path], stderr_to_stdout: true)
  assert bash_exit == 0, "Expected #{@wrapper_path} to pass bash -n:\n#{bash_output}"

  source = wrapper_source()
  help = help_output()

  for expected <- [
        "start|up)",
        "urls)",
        "logs)",
        "stop)",
        "down)",
        "reset)",
        "smoke)",
        "ps|status)",
        "help|-h|--help)"
      ] do
    assert_contains(source, expected)
  end

  assert_contains(help, "ps")
  assert_contains(help, "status")
end
```

**No hard-coded Docker URL pattern** (`test/cairnloop/demo_wrapper_contract_test.exs` lines 75-85):
```elixir
test "browser URLs are discovered from Compose instead of assuming port 4000" do
  source = wrapper_source()

  assert_contains(source, ~s(compose port web "$CONTAINER_PORT"))

  refute source =~ "localhost:4000",
         "Expected #{@wrapper_path} not to print Docker demo browser URLs with localhost:4000"

  refute source =~ "127.0.0.1:4000",
         "Expected #{@wrapper_path} not to print Docker demo browser URLs with 127.0.0.1:4000"
end
```

**Source helper pattern** (`test/cairnloop/demo_wrapper_contract_test.exs` lines 156-167):
```elixir
defp wrapper_source, do: File.read!(@wrapper_path)
defp compose_source, do: File.read!(@compose_path)

defp help_output do
  {output, exit} = System.cmd("bash", [@wrapper_path, "help"], stderr_to_stdout: true)
  assert exit == 0, "Expected ./bin/demo help to exit 0:\n#{output}"
  output
end

defp assert_contains(source, expected) do
  assert source =~ expected, "Expected source to include #{inspect(expected)}"
end
```

**Docs/package source-scan pattern** (`test/cairnloop/web/collateral_wiring_test.exs` lines 1-7 and 263-280):
```elixir
defmodule Cairnloop.Web.CollateralWiringTest do
  @moduledoc """
  Pure source, package, SVG, and raster guard for Phase 52 collateral wiring.

  The test reads static files only: no Repo, no Endpoint, no Phoenix server.
  """
  use ExUnit.Case, async: true
```

```elixir
test "Hex package files allowlist keeps brand collateral unshipped" do
  mix_exs = File.read!("mix.exs")
  expected = Enum.join(@package_files, " ")

  assert mix_exs =~ ~r/files:\s*~w\([^)]*guides\/01-quickstart\.md[^)]*\)/,
         "Expected mix.exs package files allowlist to remain files: ~w(#{expected})"

  [_, files] = Regex.run(~r/files:\s*~w\(([^)]*)\)/, mix_exs)
  package_files = String.split(files)

  assert package_files == @package_files,
         "Expected package files #{inspect(@package_files)}, got #{inspect(package_files)}"
```

**Violation reporting pattern** (`test/cairnloop/web/brand_token_gate_test.exs` lines 164-188):
```elixir
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
```

**Suggested assertions for this phase:**
- Read `README.md`, `guides/01-quickstart.md`, `guides/04-troubleshooting.md`, and `examples/cairnloop_example/README.md` with `File.read!/1`.
- Assert Docker-facing sections use `./bin/demo`, printed URL wording, and locked command names from `./bin/demo help`.
- Assert hard-coded `localhost:4000` remains only in manual-local contexts in `examples/cairnloop_example/README.md` and `guides/01-quickstart.md`.
- Assert troubleshooting contains Docker missing, Compose v2 missing, port conflict, unhealthy stack, reset/reseed, Postgres split, optional OpenAI key, `./bin/demo logs`, `./bin/demo status`, and `./bin/demo reset`.
- Keep this test DB-free and `async: true`; do not start Docker, Phoenix, Repo, Playwright, or `./bin/demo smoke`.

## Shared Patterns

### Wrapper Command Truth

**Source:** `bin/demo` lines 240-261
**Apply to:** README, Quickstart, example README, Troubleshooting, and docs source-scan tests

Use the exact command vocabulary:
```text
start/up, smoke, urls, logs, stop, down, reset, ps/status, help
```

Preserve the volume semantics from `bin/demo` lines 281-292:
```bash
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
```

### URL And Route Truth

**Source:** `bin/demo` lines 82-106 and 210-238
**Apply to:** All route mentions and smoke workflow docs

Printed routes include `/`, `/support`, `/support/inbox`, `/chat`, `/support/knowledge-base`, `/support/knowledge-base/gaps`, `/support/knowledge-base/suggestions`, `/support/audit-log`, `/support/settings`, and `/health`.

Smoke route checks intentionally exclude `/health` from the route list after health readiness:
```bash
smoke_route "$url" "/"
smoke_route "$url" "/support"
smoke_route "$url" "/support/inbox"
smoke_route "$url" "/chat"
smoke_route "$url" "/support/knowledge-base"
smoke_route "$url" "/support/knowledge-base/gaps"
smoke_route "$url" "/support/knowledge-base/suggestions"
smoke_route "$url" "/support/audit-log"
smoke_route "$url" "/support/settings"
```

### Docker Runtime Boundary

**Source:** `examples/cairnloop_example/Dockerfile.demo` lines 33-40 and `compose.demo.yml` lines 4-18, 29-44
**Apply to:** README, Quickstart, example README, Troubleshooting

```dockerfile
USER app
WORKDIR /workspace/examples/cairnloop_example

RUN mix local.hex --force && mix local.rebar --force

EXPOSE 4000

CMD ["sh", "-lc", "mix setup && exec mix phx.server"]
```

Docs should say Docker owns Elixir runtime and private pgvector Postgres for first run. Do not suggest bypassing `mix setup` inside Docker.

### ExDoc And Package Gate

**Source:** `mix.exs` lines 46-61 and 124-130
**Apply to:** README and all `guides/*.md` changes

```elixir
docs: [
  main: "readme",
  extras: [
    {"guides/01-quickstart.md", title: "Quickstart"},
    ...
    {"guides/04-troubleshooting.md", title: "Troubleshooting"},
    ...
    "README.md",
    "CHANGELOG.md"
  ],
  groups_for_extras: [
    Guides: ~r/^guides\//
  ],
```

```elixir
"ci.quality": [
  "deps.get --check-locked",
  "deps.unlock --check-unused",
  "compile --warnings-as-errors",
  "credo --strict",
  "cmd mix hex.build",
  "docs --warnings-as-errors",
```

Planner verification should include `mix ci.fast` and `mix ci.quality` for docs/package-facing edits.

### DB-Free Source-Scan Tests

**Source:** `test/cairnloop/demo_wrapper_contract_test.exs` lines 1-12 and `test/cairnloop/web/responsive_markup_test.exs` lines 15-24
**Apply to:** `test/cairnloop/docs/docker_first_docs_test.exs` if added

```elixir
use ExUnit.Case, async: true
```

```elixir
This test is DB-free (pure File.read! source scan).
# REPO-UNAVAILABLE: no assertions require a Postgres round-trip.

Source-scan is the deliberate approach...
```

Avoid Repo, Endpoint, browser tooling, Docker boot, and long-running smoke commands in the ExUnit source-scan test.

## No Analog Found

All likely Phase 55 implementation files have adequate analogs. There is no existing `test/cairnloop/docs/` directory, but DB-free file source-scan patterns are established in `test/cairnloop/demo_wrapper_contract_test.exs`, `test/cairnloop/web/collateral_wiring_test.exs`, `test/cairnloop/web/responsive_markup_test.exs`, and `test/cairnloop/web/brand_token_gate_test.exs`.

## Metadata

**Analog search scope:** `README.md`, `guides/`, `examples/cairnloop_example/`, `mix.exs`, `bin/demo`, `test/cairnloop/**/*_test.exs`, `examples/cairnloop_example/compose.demo.yml`, `examples/cairnloop_example/Dockerfile.demo`, and example router source.

**Files scanned/read:** 20 primary files plus targeted `rg` scans over `test/`, `.planning/`, `guides/`, `examples/`, `lib/`, `README.md`, and `mix.exs`.

**Pattern extraction date:** 2026-06-28
