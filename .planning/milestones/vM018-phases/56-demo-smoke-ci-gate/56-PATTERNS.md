# Phase 56: demo-smoke-ci-gate - Pattern Map

**Mapped:** 2026-06-28
**Files analyzed:** 3
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.github/workflows/demo-smoke.yml` | config | event-driven batch | `.github/workflows/ci.yml` | exact |
| `.dockerignore` | config | file-I/O | `.gitignore` | role-match |
| `test/cairnloop/demo_smoke_workflow_contract_test.exs` | test | transform/source-scan | `test/cairnloop/demo_wrapper_contract_test.exs` | exact |

## Pattern Assignments

### `.github/workflows/demo-smoke.yml` (config, event-driven batch)

**Analog:** `.github/workflows/ci.yml`

**Current draft to preserve:** `.github/workflows/demo-smoke.yml`

**Existing draft trigger/job pattern** (`.github/workflows/demo-smoke.yml` lines 1-17):
```yaml
name: Demo smoke

on:
  workflow_dispatch:
  schedule:
    - cron: "23 10 * * 1"
  push:
    branches:
      - main
      - master
    paths:
      - ".dockerignore"
      - "bin/demo"
      - "examples/cairnloop_example/**"
      - "guides/**"
      - "README.md"
      - ".github/workflows/demo-smoke.yml"
```

**CI permissions/concurrency/env pattern** (`.github/workflows/ci.yml` lines 11-21):
```yaml
permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

# Opt into Node.js 24 for all actions (actions/checkout, actions/cache, etc.).
# GitHub forces this default on June 2, 2026; opting in early avoids surprise breakage.
env:
  ACTIONS_RUNNER_NODE_VERSION: "24"
```

**Small job pattern to copy** (`.github/workflows/demo-smoke.yml` lines 19-45):
```yaml
permissions:
  contents: read

concurrency:
  group: demo-smoke-${{ github.ref }}
  cancel-in-progress: false

env:
  ACTIONS_RUNNER_NODE_VERSION: "24"

jobs:
  demo-smoke:
    name: demo-smoke
    runs-on: ubuntu-latest
    timeout-minutes: 25

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Docker versions
        run: |
          docker version
          docker compose version

      - name: Run Docker demo smoke
        run: ./bin/demo smoke
```

**Release boundary anti-pattern** (`.github/workflows/release-please.yml` lines 21-43):
```yaml
jobs:
  release-please:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      version: ${{ steps.release.outputs.version }}
      tag_name: ${{ steps.release.outputs.tag_name }}
      sha: ${{ steps.release.outputs.sha }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Release Please
        id: release
        uses: googleapis/release-please-action@v4
        with:
          token: ${{ secrets.RP_PAT || secrets.RELEASE_PLEASE_TOKEN || github.token }}
```

Apply this as a negative pattern: keep demo smoke in the separate read-only workflow. Do not copy release permissions, release outputs, publish jobs, or `secrets.*` references.

**Required hardening for planner:**
- Add `pull_request:` coverage with the same relevant `paths` as `push`.
- Expand both path-filter lists to include `.dockerignore`, `bin/demo`, `examples/cairnloop_example/**`, `.github/workflows/demo-smoke.yml`, `README.md`, `guides/**`, `mix.exs`, `mix.lock`, `config/**`, `lib/**`, and `priv/**`.
- Keep `permissions: contents: read`, `ACTIONS_RUNNER_NODE_VERSION: "24"`, job id/name `demo-smoke`, `timeout-minutes: 25`, Docker version preflight, and exact `run: ./bin/demo smoke`.
- Do not add release secrets, publish permissions, artifact upload as the primary diagnostic path, or raw `docker compose` smoke logic.

---

### `.dockerignore` (config, file-I/O)

**Analog:** `.gitignore`

**Current draft to preserve:** `.dockerignore`

**Ignore-file style pattern** (`.gitignore` lines 1-33):
```gitignore
# The directory Mix will write compiled artifacts to.
/_build/

# If you run "mix test --cover", coverage assets end up here.
/cover/

# The directory Mix downloads your dependencies sources to.
/deps/

# Where third-party dependencies like ExDoc output generated docs.
/doc/

# Temporary files, for example, from tests.
/tmp/

# If the VM crashes, it generates a dump, let's ignore it too.
erl_crash.dump

# Also ignore archive artifacts (built via "mix archive.build").
*.ez

# Ignore package tarball (built via "mix hex.build").
cairnloop-*.tar

# macOS Finder metadata.
.DS_Store

# GSD scratch files (transient planning I/O).
.gsd_*


# Local Claude Code agent state (not part of the library)
.claude/
```

**Current Docker ignore draft** (`.dockerignore` lines 1-19):
```dockerignore
.git
.DS_Store
erl_crash.dump

_build
deps
doc
cover
tmp

.planning/research/.cache
.claude

examples/cairnloop_example/_build
examples/cairnloop_example/deps
examples/cairnloop_example/assets/node_modules
examples/cairnloop_example/priv/static/assets

cairnloop-*.tar
```

**Docker build context dependency** (`examples/cairnloop_example/compose.demo.yml` lines 19-25):
```yaml
  web:
    build:
      context: ../..
      dockerfile: examples/cairnloop_example/Dockerfile.demo
      args:
        UID: ${LOCAL_UID:-1000}
        GID: ${LOCAL_GID:-1000}
```

**Runtime bind/cache volume pattern** (`examples/cairnloop_example/compose.demo.yml` lines 45-52):
```yaml
    volumes:
      - ../..:/workspace
      - demo_example_deps:/workspace/examples/cairnloop_example/deps
      - demo_example_build:/workspace/examples/cairnloop_example/_build
      - demo_static_assets:/workspace/examples/cairnloop_example/priv/static/assets
      - demo_mix:/home/app/.mix
      - demo_hex:/home/app/.hex
      - demo_rebar:/home/app/.cache/rebar3
```

**Dockerfile context expectation** (`examples/cairnloop_example/Dockerfile.demo` lines 33-40):
```dockerfile
USER app
WORKDIR /workspace/examples/cairnloop_example

RUN mix local.hex --force && mix local.rebar --force

EXPOSE 4000

CMD ["sh", "-lc", "mix setup && exec mix phx.server"]
```

**Required hardening for planner:**
- Preserve useful draft exclusions that keep build context small: `.git`, generated Mix artifacts, docs output, coverage, temp files, example `_build`/`deps`, example Node modules, generated static assets, and package tarballs.
- Keep source and runtime inputs available in Docker context: root `lib/**`, `priv/**`, `mix.exs`, `mix.lock`, `config/**`, `README.md`, `guides/**`, `bin/demo`, `examples/cairnloop_example/**`, and the demo Docker/Compose files.
- Do not exclude broad planning directories unless deliberately verified. The current draft excludes only `.planning/research/.cache`; Phase 56 path filters should still avoid triggering on `.planning/**`.

---

### `test/cairnloop/demo_smoke_workflow_contract_test.exs` (test, transform/source-scan)

**Analog:** `test/cairnloop/demo_wrapper_contract_test.exs`

**Module/header pattern** (`test/cairnloop/demo_wrapper_contract_test.exs` lines 1-13):
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

**Source contract assertion pattern** (`test/cairnloop/demo_wrapper_contract_test.exs` lines 39-62):
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

**Exact source readers/helper pattern** (`test/cairnloop/demo_wrapper_contract_test.exs` lines 156-167):
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

**Ordering helper pattern** (`test/cairnloop/demo_wrapper_contract_test.exs` lines 169-189):
```elixir
defp assert_ordered_route_block(source) do
  positions =
    Enum.map(@smoke_routes, fn route ->
      needle = ~s(smoke_route "$url" "#{route}")

      case :binary.match(source, needle) do
        {position, _length} -> position
        :nomatch -> flunk("Expected smoke route list to include #{inspect(needle)}")
      end
    end)

  assert positions == Enum.sort(positions),
         "Expected smoke routes to remain in the locked Phase 54 order"
end

defp db_service_block(compose) do
  case Regex.run(~r/\n  db:\n(?<block>.*?)(?=\n  web:\n)/s, compose, capture: ["block"]) do
    [block] -> block
    nil -> flunk("Expected #{inspect(@compose_path)} to contain a db service before web")
  end
end
```

**Docs source-scan helper pattern** (`test/cairnloop/docs/docker_first_docs_test.exs` lines 176-193):
```elixir
defp assert_contains(source, expected) do
  assert source =~ expected, "Expected source to include #{inspect(expected)}"
end

defp assert_order(source, first, second, label) do
  first_position = position!(source, first, label)
  second_position = position!(source, second, label)

  assert first_position < second_position,
         "Expected #{inspect(first)} to appear before #{inspect(second)} in #{label}"
end

defp position!(source, needle, label) do
  case :binary.match(source, needle) do
    {position, _length} -> position
    :nomatch -> flunk("Expected #{label} to include #{inspect(needle)}")
  end
end
```

**CI-fast inclusion pattern** (`mix.exs` lines 112-119):
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

**Required hardening for planner:**
- Use `defmodule Cairnloop.DemoSmokeWorkflowContractTest`.
- Keep the test DB-free and async: only `File.read!/1` source scans and string/order assertions.
- Pin workflow source to `.github/workflows/demo-smoke.yml`.
- Assert trigger set: `workflow_dispatch`, `schedule`, `push`, and `pull_request`.
- Assert both `push` and `pull_request` contain every D-05 path filter.
- Assert `permissions:\n  contents: read`, `ACTIONS_RUNNER_NODE_VERSION: "24"`, stable `demo-smoke` job/check name, `runs-on: ubuntu-latest`, `timeout-minutes: 25`, Docker version preflight, and exact `run: ./bin/demo smoke`.
- Refute forbidden workflow drift: `pull_request_target`, `contents: write`, `secrets.`, `HEX_API_KEY`, `RELEASE_PLEASE`, raw `docker compose up`, raw `curl` route smoke, and `.planning/**` path filters.

## Shared Patterns

### Read-Only GitHub Actions Security

**Source:** `.github/workflows/ci.yml` lines 11-21 and `.github/workflows/release-please.yml` lines 21-43

**Apply to:** `.github/workflows/demo-smoke.yml`, `test/cairnloop/demo_smoke_workflow_contract_test.exs`

```yaml
permissions:
  contents: read

env:
  ACTIONS_RUNNER_NODE_VERSION: "24"
```

Do not copy release workflow permissions or secrets into the smoke workflow.

### Wrapper-Owned Smoke Behavior

**Source:** `bin/demo` lines 210-237

**Apply to:** `.github/workflows/demo-smoke.yml`, `test/cairnloop/demo_smoke_workflow_contract_test.exs`

```bash
smoke_demo() (
  local smoke_id

  require_docker

  smoke_id="${BASHPID:-$$}"
  export CAIRNLOOP_COMPOSE_PROJECT="${CAIRNLOOP_COMPOSE_PROJECT}_smoke_${smoke_id}"
  export CAIRNLOOP_WEB_PORT="${CAIRNLOOP_SMOKE_WEB_PORT:-${CAIRNLOOP_WEB_PORT}}"

  trap 'compose down -v --remove-orphans >/dev/null 2>&1 || true' EXIT

  compose_up_with_port_fallback "starting the smoke stack"
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

The workflow must call `./bin/demo smoke`; do not duplicate this route list or lifecycle in YAML.

### Inline Failure Diagnostics

**Source:** `bin/demo` lines 109-130 and lines 191-200

**Apply to:** `.github/workflows/demo-smoke.yml`, `test/cairnloop/demo_smoke_workflow_contract_test.exs`

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

run_compose_or_explain() {
  local description
  description="$1"
  shift

  if ! compose "$@"; then
    fail_with_web_logs "Compose command failed while ${description}: docker compose -f \"$COMPOSE_FILE\" $*"
  fi
}
```

```bash
smoke_route() {
  local url route
  url="$1"
  route="$2"

  if web_get "$route"; then
    printf 'ok  %s\n' "$route"
  else
    fail_with_web_logs "Smoke check failed for $url$route"
  fi
}
```

Artifact upload is optional only as a secondary aid; inline wrapper diagnostics remain the primary failure output.

### DB-Free Contract Tests

**Source:** `test/cairnloop/demo_wrapper_contract_test.exs` lines 1-13 and `mix.exs` lines 112-119

**Apply to:** `test/cairnloop/demo_smoke_workflow_contract_test.exs`

Use `ExUnit.Case, async: true`, `File.read!/1`, local helper assertions, and no Docker/Phoenix/Repo/browser startup.

## No Analog Found

All expected files have usable analogs in the codebase. `.dockerignore` has only a role-match analog (`.gitignore`) plus Docker runtime context files; planners should treat its current untracked draft as user work to preserve.

## Metadata

**Analog search scope:** `.github/workflows`, `test/cairnloop`, `bin`, `examples/cairnloop_example`, root ignore/config files, `mix.exs`
**Files scanned:** 196 via `rg --files` in relevant roots, plus focused workflow/test/runtime reads
**Pattern extraction date:** 2026-06-28
