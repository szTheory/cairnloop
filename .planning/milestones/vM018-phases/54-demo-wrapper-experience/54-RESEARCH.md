# Phase 54: Demo Wrapper Experience - Research

**Researched:** 2026-06-28
**Domain:** Docker Compose demo wrapper, Bash operational UX, Phoenix example readiness, HTTP smoke verification
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

The following locked decisions, discretion note, and deferred ideas are copied from `.planning/phases/54-demo-wrapper-experience/54-CONTEXT.md`; treat them as binding planning constraints. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]

### Locked Decisions

## Implementation Decisions

### Wrapper Command Surface
- **D-01:** Keep `./bin/demo` as the single canonical entry point. Do not add a competing Makefile, npm script, Mix task, or manual Compose recipe as the primary adopter path.
- **D-02:** Preserve the command vocabulary already present in `bin/demo`: default `start`/`up`, `urls`, `logs`, `status`/`ps`, `stop`, `down`, `reset`, `smoke`, and `help`. Planning may harden behavior, messages, or edge cases, but should not rename commands without a compatibility alias.
- **D-03:** Command semantics stay operationally simple: `stop` preserves named volumes, `down` removes containers/network while preserving volumes, and `reset` removes volumes then rebuilds/reseeds through `start_demo`.

### Ports And URL Discovery
- **D-04:** Keep Postgres private to Compose. The demo wrapper must not publish the database port to the host.
- **D-05:** Keep Phoenix published on localhost through the Compose `web` port mapping. Default to the current `CAIRNLOOP_WEB_PORT=4100-4199` range, with a fixed port still allowed through the same environment variable.
- **D-06:** All printed links must be discovered from the running stack via `docker compose port web 4000`; never assume `localhost:4000`. Normalize wildcard bind addresses such as `0.0.0.0` or `::` to a browser-usable localhost address.
- **D-07:** `./bin/demo urls` must print the same route block as a successful start and should fail closed with an actionable message when the web service is not running.

### Readiness And Smoke
- **D-08:** `start` and `smoke` must wait for the real `/health` endpoint before printing URLs or checking routes. Keep readiness tied to the Phase 53 operations route, not to log text or arbitrary sleeps.
- **D-09:** `./bin/demo smoke` remains a high-signal HTTP smoke, not a full browser E2E suite. It should check the main adopter routes currently in the wrapper: `/`, `/support`, `/support/inbox`, `/chat`, `/support/knowledge-base`, `/support/knowledge-base/gaps`, `/support/knowledge-base/suggestions`, `/support/audit-log`, and `/support/settings`.
- **D-10:** Smoke must run in an isolated Compose project namespace derived from the normal project name, clean up containers and volumes on exit, and avoid disturbing the ordinary developer demo stack.
- **D-11:** `CAIRNLOOP_SMOKE_WEB_PORT` may override smoke port allocation; otherwise smoke inherits the normal `CAIRNLOOP_WEB_PORT` range. Do not introduce fixed smoke ports by default.

### Failure Diagnostics
- **D-12:** Failure output should be calm and actionable: include the failing route or readiness URL, recent web logs, and the command that failed when available. Do not dump raw JSON, stack traces, or long Compose output unless it is the only useful diagnostic.
- **D-13:** If health never passes, print recent web logs before exiting nonzero. If an individual smoke route fails, print the full failing URL and recent web logs before exiting nonzero.
- **D-14:** Keep logs accessible through `./bin/demo logs` for both `web` and `db`; failure diagnostics can stay web-focused unless the failure occurs before the web service exists.

### Verification Boundary
- **D-15:** Phase 54 should add or preserve automated proof for wrapper behavior using shell/source checks and Docker smoke where practical. Browser-rendered geometry or user walkthrough automation belongs outside this phase unless already covered by the existing route smoke.
- **D-16:** Verification should continue to run `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` and `./bin/demo smoke` before close. Keep `mix ci.fast` as the baseline repo lane and add DB/integration lanes only if implementation touches runtime/config/seeds beyond the wrapper contract.

### the agent's Discretion

### Claude's Discretion
These decisions were auto-ratified under the repo decision policy in `CLAUDE.md`: research and decide normal gray areas, escalating only very impactful irreversible calls. No such escalation was identified for Phase 54.

### Deferred Ideas (OUT OF SCOPE)

## Deferred Ideas

- Full browser walkthrough command - deferred to future DEMO-01.
- Screenshot refresh from Docker demo - deferred to future DEMO-02.
- Hosted public demo environment - deferred to future DEMO-03.
- CI smoke workflow and path filters - Phase 56.
- Docker-first README/Quickstart/example README/troubleshooting narrative - Phase 55.
</user_constraints>

## Project Constraints (from AGENTS.md)

- Read `CLAUDE.md` first before project work. [VERIFIED: AGENTS.md]
- For UI work, read `docs/operator-ui-principles.md` before editing `lib/cairnloop/web/**` or `priv/static/cairnloop.css`; Phase 54 is wrapper/Compose work and should not edit dashboard UI. [VERIFIED: AGENTS.md] [VERIFIED: CLAUDE.md]
- Cairnloop's shipped dashboard uses tokenized `.cl-*` / BEM CSS, not Tailwind; avoid adopter-facing UI drift while changing the demo wrapper. [VERIFIED: AGENTS.md]
- The repo owner wants normal gray-area decisions researched and made by agents; escalate only very impactful, expensive, or irreversible calls. [VERIFIED: CLAUDE.md]
- Builds must be warnings-clean with `mix compile --warnings-as-errors`. [VERIFIED: CLAUDE.md]
- Run `mix ci.fast` before declaring headless work done; add `mix ci.integration`, `mix ci.quality`, or example E2E only when the touched files require those lanes. [VERIFIED: CLAUDE.md]
- `Cairnloop.Repo` may be unavailable in this workspace; preserve DB-free headless tests where possible and isolate Docker/Postgres checks. [VERIFIED: CLAUDE.md]
- Do not churn sealed Cairnloop public contracts for demo-wrapper behavior; keep changes in `bin/demo`, `examples/cairnloop_example/compose.demo.yml`, and narrow verification files unless a real runtime dependency requires more. [VERIFIED: CLAUDE.md] [VERIFIED: .planning/STATE.md]
- Current worktree is dirty, including unrelated source/UI files and untracked Phase 53/54 demo artifacts; planner/executor must preserve unrelated user changes and stage only intended files. [VERIFIED: git status]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BOOT-01 | Adopter can run `./bin/demo` from a fresh clone with Docker Compose v2 as the only local runtime prerequisite. [VERIFIED: .planning/REQUIREMENTS.md] | Keep `bin/demo` rooted at repo top, call `docker compose -f examples/cairnloop_example/compose.demo.yml`, and rely on `Dockerfile.demo` to install/run Elixir inside the container; do not introduce local Elixir/Postgres prerequisites. [VERIFIED: bin/demo] [VERIFIED: examples/cairnloop_example/Dockerfile.demo] |
| BOOT-02 | Adopter can start the demo without fixed host port conflicts because Phoenix publishes on localhost via a dynamic or configured port and Postgres stays private to Compose. [VERIFIED: .planning/REQUIREMENTS.md] | Compose config resolves `web` only to `host_ip: 127.0.0.1`, `published: 4100-4199`, `target: 4000`; `db` has no host `ports` entry. [VERIFIED: docker compose config] [VERIFIED: examples/cairnloop_example/compose.demo.yml] [CITED: https://docs.docker.com/reference/compose-file/services/#ports] |
| BOOT-03 | Adopter can see the exact running URLs for the demo index, operator cockpit, inbox, customer chat, Knowledge Base, gaps, suggestions, audit log, settings, and health probe after the stack becomes healthy. [VERIFIED: .planning/REQUIREMENTS.md] | Use `docker compose port web 4000` after `/health` passes; current wrapper prints the full route block and normalizes wildcard bind addresses. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/port/] |
| BOOT-04 | Adopter can reprint URLs, follow logs, inspect status, stop/down the stack, and reset seeded volumes through the same demo wrapper. [VERIFIED: .planning/REQUIREMENTS.md] | Preserve `urls`, `logs`, `status`/`ps`, `stop`, `down`, `reset`, and `help`; current help omits the word `status` even though the alias works, so planning should fix help copy. [VERIFIED: bin/demo] |
| VER-01 | Maintainer can run `./bin/demo smoke` to boot an isolated demo stack, check the main routes, and clean up containers and volumes afterward. [VERIFIED: .planning/REQUIREMENTS.md] | Current `smoke_demo` appends `_smoke` to the project name, sets an EXIT trap with `compose down -v --remove-orphans`, waits for `/health`, and checks the locked route list. [VERIFIED: bin/demo] [CITED: https://www.gnu.org/software/bash/manual/bash.html] |
| VER-02 | Maintainer gets actionable failure output from the smoke command, including the failing route and recent web logs. [VERIFIED: .planning/REQUIREMENTS.md] | Current route and health failures print recent web logs; planning should centralize diagnostics so compose-up failures also name the failed command and print useful logs/status when containers exist. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/logs/] |
</phase_requirements>

## Summary

Phase 54 should harden the existing wrapper in place rather than replacing it. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md] The current `bin/demo` already implements the important shape: repo-root execution, Compose v2 plugin command form, deterministic project naming, dynamic localhost web port range, private DB service, `docker compose port web 4000` URL discovery, `/health` readiness, isolated smoke namespace, route-level HTTP smoke, and cleanup through `down -v`. [VERIFIED: bin/demo] [VERIFIED: examples/cairnloop_example/compose.demo.yml] [VERIFIED: docker compose config]

The planning focus should be edge hardening and proof, not new product behavior. [VERIFIED: .planning/ROADMAP.md] Concrete gaps: `./bin/demo help` lists `ps` but not the `status` alias; compose-up failures exit through `set -e` before the wrapper can print its calm diagnostics; `wait_for_health` assumes a `docker compose port` result is immediately available; and VER-02 needs automated/source proof that failure paths include the failed route/readiness URL plus recent web logs. [VERIFIED: bin/demo] [VERIFIED: bash -n bin/demo] [VERIFIED: ./bin/demo help]

**Primary recommendation:** plan a small Bash/Compose hardening slice: preserve the current command surface, add shared diagnostic helpers, make `status` visible in help, make health waiting resilient to delayed port discovery, keep smoke isolated and self-cleaning, add DB-free source/contract tests for wrapper/Compose invariants, and keep final verification to `mix ci.fast`, `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet`, and `./bin/demo smoke` unless runtime/config/seeds are touched. [VERIFIED: CLAUDE.md] [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]

Research-time checks completed: `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` passed; resolved config showed no DB host port and web published on `127.0.0.1` with `4100-4199`; `bash -n bin/demo` passed; `./bin/demo help` succeeded; Docker Engine `29.5.2`, Docker Compose `v5.1.3`, GNU Bash `5.2.37`, curl `8.7.1`, and Mix `1.19.5` are available locally. [VERIFIED: command output]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Demo command surface | Shell wrapper | Docker Compose | `./bin/demo` owns adopter-facing commands and translates them to Compose operations. [VERIFIED: bin/demo] |
| Service orchestration | Docker Compose | Docker Engine | Compose owns project naming, service lifecycle, named volumes, network, build, healthchecks, and port publishing. [VERIFIED: examples/cairnloop_example/compose.demo.yml] [CITED: https://docs.docker.com/compose/how-tos/project-name/] |
| Phoenix runtime | Containerized example app | Dockerfile | The container installs/runs Elixir dependencies and starts Phoenix with `mix setup && exec mix phx.server`, avoiding host Elixir/Postgres. [VERIFIED: examples/cairnloop_example/Dockerfile.demo] |
| Database persistence | Compose named volume | Postgres container | `demo_db_data` persists seeded Postgres state across `stop` and `down`, while `reset` removes volumes. [VERIFIED: examples/cairnloop_example/compose.demo.yml] [CITED: https://docs.docker.com/reference/cli/docker/compose/down/] |
| Public URL discovery | Docker Compose CLI | Shell URL formatter | `docker compose port web 4000` is the authoritative source for the assigned host port. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/port/] |
| Readiness | Phoenix `/health` route | Compose healthcheck | The example router mounts `cairnloop_operations()` outside the browser pipeline; wrapper checks `/health` before URL/route success. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex] [VERIFIED: lib/cairnloop/router.ex] |
| Smoke verification | Shell wrapper | HTTP endpoints | `smoke` should stay a fast HTTP route check, not a browser walkthrough or CI workflow expansion. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| `bin/demo` Bash wrapper | Existing script, `#!/usr/bin/env bash` | Single adopter-facing operational entry point | Locked by Phase 54 context; keeps all demo operations discoverable from repo root. [VERIFIED: bin/demo] [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md] |
| GNU Bash | Local `5.2.37` | Shell functions, strict mode, EXIT trap cleanup | Existing wrapper language; Bash manual defines `set -euo pipefail` and EXIT trap behavior used by smoke cleanup. [VERIFIED: bash --version] [CITED: https://www.gnu.org/software/bash/manual/bash.html] |
| Docker CLI / Engine | Local Engine `29.5.2` | Container build/run backend | Required local runtime substrate for the Docker demo. [VERIFIED: docker --version] [VERIFIED: docker info] |
| Docker Compose plugin command | Local `docker compose version v5.1.3` | Compose v2-style orchestration command | Requirement is the `docker compose` plugin command form, not legacy `docker-compose`; do not hard-parse a `v2.*` version prefix because the local plugin reports `v5.1.3`. [VERIFIED: docker compose version] [VERIFIED: .planning/REQUIREMENTS.md] |
| Compose file `compose.demo.yml` | Existing | Private Postgres, web build, healthchecks, localhost port range, named volumes | Current config satisfies the Phase 53 runtime contract and Phase 54 port/privacy requirements. [VERIFIED: examples/cairnloop_example/compose.demo.yml] [VERIFIED: docker compose config] |
| Dockerfile `Dockerfile.demo` | Existing image `hexpm/elixir:1.19.5-erlang-27.2.4-debian-trixie-20260623-slim` | Containerized Elixir/Phoenix runtime | Keeps `./bin/demo` free of local Elixir and local Postgres requirements. [VERIFIED: examples/cairnloop_example/Dockerfile.demo] |
| curl | Local `8.7.1`; installed in demo image | Host health polling and route smoke | Official curl options support quiet success and nonzero HTTP failure handling. [VERIFIED: curl --version] [VERIFIED: examples/cairnloop_example/Dockerfile.demo] [CITED: https://curl.se/docs/manpage.html] |
| Phoenix example `/health` | Existing route through `Cairnloop.Router.cairnloop_operations()` | Readiness endpoint | Phase 53 verified this as the route-based readiness contract. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex] [VERIFIED: .planning/phases/53-demo-runtime-contract/53-VERIFICATION.md] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Mix / Elixir | Local Mix `1.19.5` | Repo verification lanes | Use for `mix ci.fast` and optional example/runtime tests; do not make it an adopter prerequisite for `./bin/demo`. [VERIFIED: mix --version] [VERIFIED: CLAUDE.md] |
| Root ExUnit | Existing `mix ci.fast` alias | DB-free source/contract tests | Add wrapper/Compose source tests here because this phase needs headless proof without requiring Docker for every unit run. [VERIFIED: mix.exs] |
| `docker compose config` | Compose CLI command | Resolve/validate Compose model | Use as the structured validation path for YAML instead of ad hoc parsing when checking published ports and private DB. [VERIFIED: docker compose config] [CITED: https://docs.docker.com/compose/gettingstarted/] |
| `docker compose logs --tail` | Compose CLI command | Recent web/db diagnostics | Use in failure helpers and keep `./bin/demo logs` as the fuller manual diagnostic. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/logs/] |
| `docker compose ps` | Compose CLI command | Status display | Use for `status`/`ps`; it lists project containers, statuses, and published ports. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/ps/] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Existing `./bin/demo` | Makefile, npm script, Mix task, README commands | Rejected by locked D-01; another primary path would split adopter behavior and docs. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md] |
| Compose port range plus `docker compose port` | Manual random-port allocator in Bash | Compose already supports published ranges and exposes actual bindings; a custom allocator adds races and global port ownership. [CITED: https://docs.docker.com/reference/compose-file/services/#ports] [CITED: https://docs.docker.com/reference/cli/docker/compose/port/] |
| Route-based HTTP smoke | Browser E2E walkthrough | Rejected by D-09 and guardrails; browser walkthrough is deferred to DEMO-01. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md] |
| `docker compose up --wait` as sole readiness | Existing explicit `/health` loop | `--wait` can be useful, but the wrapper still needs Cairnloop-specific URL printing and recent web logs on timeout. [CITED: https://docs.docker.com/reference/cli/docker/compose/up/] [VERIFIED: bin/demo] |
| `docker compose down` for reset | `docker system prune` or global volume prune | Rejected by guardrails; reset should only remove this Compose project's volumes. [VERIFIED: .planning/ROADMAP.md] [CITED: https://docs.docker.com/reference/cli/docker/compose/down/] |

**Installation:**

No external packages should be installed for Phase 54. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]

```bash
# No npm/pip/cargo/mix package install is recommended for this phase.
```

**Version verification:** Before implementation, confirm local tool availability with:

```bash
docker --version
docker compose version
bash --version | head -1
curl --version | head -1
mix --version | head -4
docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet
```

The researched local versions were Docker Engine `29.5.2`, Docker Compose `v5.1.3`, GNU Bash `5.2.37`, curl `8.7.1`, and Mix `1.19.5`. [VERIFIED: command output]

## Package Legitimacy Audit

Phase 54 should not install external packages, so the package legitimacy gate is not required. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none | - | - | - | - | - | No package install planned. [VERIFIED: research recommendation] |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: no package install planned]
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: no package install planned]

## Architecture Patterns

### System Architecture Diagram

```text
Adopter shell at repo root
  -> ./bin/demo [start|up|urls|logs|status|ps|stop|down|reset|smoke|help]
     -> require_docker()
        -> docker command exists
        -> docker compose command exists
     -> compose() wrapper
        -> docker compose -f examples/cairnloop_example/compose.demo.yml ...

start/up:
  -> docker compose up -d --build
     -> db service: private pgvector Postgres + named volume
        -> healthcheck: pg_isready inside Compose network
     -> web service: Dockerfile.demo + bind mount source + named caches
        -> command: mix setup && exec mix phx.server
        -> healthcheck: curl http://127.0.0.1:4000/health
  -> wait_for_health()
     -> discover endpoint with docker compose port web 4000
     -> curl discovered_base_url/health
     -> on timeout: print recent web logs
  -> print_urls()
     -> print route block using discovered base URL

urls:
  -> discover endpoint from running web service
  -> print same route block as start

smoke:
  -> derive isolated project: ${normal_project}_smoke
  -> optional smoke port: CAIRNLOOP_SMOKE_WEB_PORT or normal range
  -> trap EXIT: docker compose down -v --remove-orphans
  -> clean prior smoke project
  -> up -d --build
  -> wait_for_health()
  -> curl locked route list
  -> on route failure: print failing URL and recent web logs
  -> exit -> cleanup smoke containers and volumes

stop/down/reset/logs/status:
  -> Compose lifecycle commands scoped to CAIRNLOOP_COMPOSE_PROJECT
```

### Recommended Project Structure

```text
bin/
|-- demo                                  # canonical wrapper surface [VERIFIED: bin/demo]

examples/cairnloop_example/
|-- compose.demo.yml                      # demo services, ports, volumes, healthchecks [VERIFIED: examples/cairnloop_example/compose.demo.yml]
|-- Dockerfile.demo                       # Docker-only Elixir runtime path [VERIFIED: examples/cairnloop_example/Dockerfile.demo]
`-- lib/cairnloop_example_web/router.ex   # /, /chat, /support, /health route source [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex]

test/cairnloop/
`-- demo_wrapper_contract_test.exs        # recommended Wave 0 DB-free source/contract tests [VERIFIED: recommended gap]
```

### Pattern 1: Compose-Scoped Wrapper Function

**What:** Keep all Docker calls behind a `compose()` helper that always uses the demo Compose file and the exported project name. [VERIFIED: bin/demo]
**When to use:** Every subcommand should use this helper so cleanup, URL discovery, logs, and status all target the same project. [VERIFIED: bin/demo]
**Example:**

```bash
# Source: bin/demo
compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}
```

### Pattern 2: Authoritative Port Discovery

**What:** Discover the browser base URL from `docker compose port web 4000`, not from defaults or environment variables. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/port/]
**When to use:** `start`, `urls`, readiness, and smoke route checks. [VERIFIED: bin/demo]
**Example:**

```bash
# Source: bin/demo
web_endpoint() {
  compose port web "$CONTAINER_PORT" 2>/dev/null | tail -n 1
}
```

**Planner note:** make delayed/no endpoint handling context-aware: `urls` should fail closed immediately, while `start`/`smoke` can retry briefly and then print logs/status. [VERIFIED: bin/demo]

### Pattern 3: Localhost-Only Dynamic Web Port

**What:** Publish only the Phoenix web port, bind it to `127.0.0.1`, and let Compose choose from the configured range. [VERIFIED: examples/cairnloop_example/compose.demo.yml]
**When to use:** Default demo and smoke stacks. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]
**Example:**

```yaml
# Source: examples/cairnloop_example/compose.demo.yml
ports:
  - name: web
    target: 4000
    published: "${CAIRNLOOP_WEB_PORT:-4100-4199}"
    host_ip: "${CAIRNLOOP_BIND_HOST:-127.0.0.1}"
    protocol: tcp
```

Docker documents that publishing without a localhost address can expose ports beyond the host; keep `host_ip` explicit. [CITED: https://docs.docker.com/engine/network/port-publishing/]

### Pattern 4: Route-Based Readiness

**What:** Wait on the real `/health` URL before printing URLs or checking route smoke. [VERIFIED: bin/demo]
**When to use:** `start` and `smoke`; do not replace with log scraping or arbitrary sleeps. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]
**Example:**

```bash
# Source: bin/demo
until curl -fsS "$url" >/dev/null 2>&1; do
  attempts=$((attempts - 1))
  # ...
done
```

Compose startup docs confirm `service_healthy` is the readiness mechanism for dependencies, but the wrapper still needs the Phoenix app's own `/health` route for adopter URLs. [CITED: https://docs.docker.com/compose/how-tos/startup-order/] [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex]

### Pattern 5: Isolated Smoke With EXIT Cleanup

**What:** Run smoke in a derived Compose project and always remove that smoke project's volumes on exit. [VERIFIED: bin/demo]
**When to use:** `./bin/demo smoke`, including local and future CI invocations. [VERIFIED: .planning/REQUIREMENTS.md]
**Example:**

```bash
# Source: bin/demo
export CAIRNLOOP_COMPOSE_PROJECT="${CAIRNLOOP_COMPOSE_PROJECT}_smoke"
trap 'compose down -v --remove-orphans >/dev/null 2>&1 || true' EXIT
```

GNU Bash documents that EXIT traps run before shell termination, and Compose `down -v` removes named volumes for the project. [CITED: https://www.gnu.org/software/bash/manual/bash.html] [CITED: https://docs.docker.com/reference/cli/docker/compose/down/]

### Anti-Patterns to Avoid

- **Parsing a literal `v2.*` Compose version:** the requirement means the `docker compose` plugin command, while the local plugin reports `v5.1.3`; parse command availability, not a v2 prefix. [VERIFIED: docker compose version] [VERIFIED: .planning/REQUIREMENTS.md]
- **Publishing Postgres to the host:** violates BOOT-02 and D-04; use Compose service DNS `db:5432` only inside the stack. [VERIFIED: examples/cairnloop_example/compose.demo.yml] [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]
- **Assuming `localhost:4000`:** violates dynamic port discovery and breaks when Compose assigns from `4100-4199`. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/port/]
- **Using `docker system prune` or global volume cleanup:** violates guardrails and can destroy unrelated Docker state. [VERIFIED: .planning/ROADMAP.md]
- **Turning smoke into browser E2E:** explicitly out of scope; keep HTTP route checks and defer walkthrough automation. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]
- **Letting `set -e` own user-facing failures:** command failures before custom handlers can skip diagnostics; wrap important Compose calls when D-12 requires command/log output. [VERIFIED: bin/demo] [CITED: https://www.gnu.org/software/bash/manual/bash.html]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Port allocation | Bash random-port scanner or `lsof` loop | Compose `published: "4100-4199"` plus `docker compose port web 4000` | Compose owns binding and reports the real assignment without races. [CITED: https://docs.docker.com/reference/compose-file/services/#ports] |
| Project isolation | Manual container/network names | Compose project name via `CAIRNLOOP_COMPOSE_PROJECT` | Compose scopes containers, networks, and volumes by project name. [CITED: https://docs.docker.com/compose/how-tos/project-name/] |
| Volume reset | `docker volume rm` globs or global prune | `docker compose down -v --remove-orphans` | Keeps reset scoped to the demo project. [CITED: https://docs.docker.com/reference/cli/docker/compose/down/] |
| Readiness | Sleeps, log regexes, or checking only container running state | `/health` over discovered browser URL | Compose docs distinguish running from ready; Phase 53 made `/health` the contract. [CITED: https://docs.docker.com/compose/how-tos/startup-order/] [VERIFIED: .planning/phases/53-demo-runtime-contract/53-VERIFICATION.md] |
| Smoke route inventory | Browser automation framework or page geometry assertions | `curl -fsSL` route checks | Locked high-signal HTTP smoke; full walkthrough belongs to DEMO-01. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md] |
| Compose YAML validation | Custom YAML parser or regex-only validation | `docker compose config --quiet` and focused source tests | Compose produces the resolved model and catches invalid schema/interpolation. [CITED: https://docs.docker.com/compose/gettingstarted/] |

**Key insight:** The wrapper should productize Compose, not reimplement Compose. [VERIFIED: research synthesis] Let Compose own project scoping, port binding, service lifecycle, logs, status, and volume semantics; let the wrapper own calm command vocabulary, exact URL presentation, readiness loops, and failure copy. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/]

## Common Pitfalls

### Pitfall 1: Hard-Coding The Browser Port

**What goes wrong:** URLs point to `localhost:4000` or the configured range start, not the actual published port. [VERIFIED: .planning/REQUIREMENTS.md]
**Why it happens:** Developers confuse container `PORT=4000` with host port publishing. [VERIFIED: examples/cairnloop_example/compose.demo.yml]
**How to avoid:** Always derive the browser URL from `docker compose port web 4000`. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/port/]
**Warning signs:** `rg -n 'localhost:4000|127.0.0.1:4000' bin/demo README.md guides examples/cairnloop_example/README.md` shows adopter-facing Docker URLs. [VERIFIED: recommended check]

### Pitfall 2: Accidentally Exposing Postgres

**What goes wrong:** A `ports:` mapping on `db` makes the demo DB reachable from the host and can collide with local Postgres. [VERIFIED: .planning/REQUIREMENTS.md]
**Why it happens:** Manual local development often maps Postgres, but this demo uses private Compose networking. [VERIFIED: docker-compose.yml] [VERIFIED: examples/cairnloop_example/compose.demo.yml]
**How to avoid:** Keep `db` without `ports`; verify with `docker compose -f examples/cairnloop_example/compose.demo.yml config`. [VERIFIED: docker compose config]
**Warning signs:** Resolved config includes `db.ports` or `5432:5432`. [VERIFIED: recommended check]

### Pitfall 3: Treating Compose Running As Application Ready

**What goes wrong:** URLs print while `mix setup` or Phoenix boot is still in progress. [VERIFIED: examples/cairnloop_example/Dockerfile.demo]
**Why it happens:** Compose can start containers before app-level readiness is true; official docs call out this running-vs-ready distinction. [CITED: https://docs.docker.com/compose/how-tos/startup-order/]
**How to avoid:** Keep the wrapper's `/health` loop and web-log timeout diagnostics. [VERIFIED: bin/demo]
**Warning signs:** URLs print before `curl "$url/health"` succeeds, or wrapper uses `sleep`/log text. [VERIFIED: recommended check]

### Pitfall 4: Smoke Disturbs The Normal Demo Stack

**What goes wrong:** A maintainer runs `smoke` and loses their current seeded demo data. [VERIFIED: .planning/REQUIREMENTS.md]
**Why it happens:** Smoke reuses the normal Compose project or normal volumes. [VERIFIED: bin/demo]
**How to avoid:** Preserve the `_smoke` project suffix, isolated port override, and `down -v` EXIT trap. [VERIFIED: bin/demo]
**Warning signs:** `smoke_demo` no longer changes `CAIRNLOOP_COMPOSE_PROJECT` before cleanup/start. [VERIFIED: recommended check]

### Pitfall 5: Failure Output Is Either Too Sparse Or Too Noisy

**What goes wrong:** Maintainers get only an exit code, or adopters get a long raw Compose dump. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]
**Why it happens:** `set -e` exits before custom handlers, or diagnostics are bolted onto every command. [VERIFIED: bin/demo]
**How to avoid:** Add small helpers such as `recent_web_logs`, `fail_with_web_logs`, and `run_compose_or_explain`; use them at compose-up, health timeout, and route-failure boundaries. [VERIFIED: research synthesis from bin/demo]
**Warning signs:** `compose up -d --build` is a bare command in a function where D-12 requires command output on failure. [VERIFIED: bin/demo]

### Pitfall 6: Command Help Drifts From Supported Aliases

**What goes wrong:** `status` works but help only advertises `ps`, making BOOT-04 less discoverable. [VERIFIED: bin/demo]
**Why it happens:** Case aliases and usage text are updated separately. [VERIFIED: bin/demo]
**How to avoid:** Keep the command list in one source of truth where practical, or at least add a source test that asserts every alias appears in help. [VERIFIED: recommended test gap]
**Warning signs:** `./bin/demo help` omits `status` while the case branch includes `ps|status`. [VERIFIED: ./bin/demo help] [VERIFIED: bin/demo]

## Code Examples

Verified patterns from current code and official docs:

### Private DB, Dynamic Local Web Port

```yaml
# Source: examples/cairnloop_example/compose.demo.yml
services:
  db:
    image: pgvector/pgvector:pg16
    volumes:
      - demo_db_data:/var/lib/postgresql/data

  web:
    depends_on:
      db:
        condition: service_healthy
    ports:
      - name: web
        target: 4000
        published: "${CAIRNLOOP_WEB_PORT:-4100-4199}"
        host_ip: "${CAIRNLOOP_BIND_HOST:-127.0.0.1}"
        protocol: tcp
```

Compose long-form ports support `target`, `published`, `host_ip`, `protocol`, and a human-readable `name`; a published range lets Compose choose an available host port. [CITED: https://docs.docker.com/reference/compose-file/services/#ports]

### Exact URL Discovery

```bash
# Source: bin/demo
web_endpoint() {
  compose port web "$CONTAINER_PORT" 2>/dev/null | tail -n 1
}

base_url() {
  local endpoint host port
  endpoint="$(web_endpoint)"
  # parse host/port, normalize 0.0.0.0 or :: to 127.0.0.1
}
```

`docker compose port SERVICE PRIVATE_PORT` prints the public port binding for a service private port. [CITED: https://docs.docker.com/reference/cli/docker/compose/port/]

### Health-Gated Route Smoke

```bash
# Source: bin/demo
wait_for_health
url="$(base_url)"
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

The route list matches D-09 and the example router/dashboard macro surface. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md] [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex] [VERIFIED: lib/cairnloop/router.ex]

### Status And Lifecycle Mapping

```bash
# Source: bin/demo
stop)  compose stop ;;
down)  compose down --remove-orphans ;;
reset) compose down -v --remove-orphans; start_demo ;;
ps|status) compose ps ;;
```

Compose docs define `stop` as stopping without removal, `down` as removing containers/networks by default, and `down -v` as removing named volumes declared by the project. [CITED: https://docs.docker.com/reference/cli/docker/compose/stop/] [CITED: https://docs.docker.com/reference/cli/docker/compose/down/]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Legacy `docker-compose` binary | `docker compose` plugin command | Compose v2 era; current Docker docs use `docker compose` | Wrapper should require the subcommand and not add legacy fallback complexity. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/] |
| Fixed host port `4000:4000` | Long-form localhost port range with discovered actual URL | Phase 53/54 runtime contract | Avoids fixed Phoenix port collisions while keeping browser access local. [VERIFIED: examples/cairnloop_example/compose.demo.yml] |
| Host-published local DB | Private Compose DB service with service DNS `db` | Phase 53/54 runtime contract | Avoids local Postgres conflicts and host DB exposure. [VERIFIED: docker compose config] |
| Sleep/log readiness | `/health` readiness plus Compose healthchecks | Phase 53 runtime contract | Keeps smoke tied to routable app readiness. [VERIFIED: .planning/phases/53-demo-runtime-contract/53-VERIFICATION.md] |
| Manual browser walkthrough as smoke | HTTP route smoke | Phase 54 locked decision | Keeps smoke stable and fast; browser walkthrough remains deferred. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md] |

**Deprecated/outdated:**

- `docker-compose` as the primary command: use `docker compose`; current wrapper already does. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/]
- Hard-coded Docker demo URLs such as `http://localhost:4000`: use wrapper-discovered URLs. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: bin/demo]
- Publishing `db` ports in the demo Compose file: keep Postgres private. [VERIFIED: examples/cairnloop_example/compose.demo.yml] [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| - | No `[ASSUMED]` claims. | All sections | All substantive recommendations are verified from repo files, command output, phase context, or cited official docs. |

## Open Questions (RESOLVED)

1. **RESOLVED: No blocking open questions; Wave 0 source-test shape is planner discretion.**
   - What we know: Phase 54 decisions lock wrapper behavior, route list, smoke scope, and verification boundary. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]
   - What's unclear: The exact shape of the Wave 0 source test is planner discretion. [VERIFIED: research synthesis]
   - Recommendation: Add one DB-free ExUnit source/contract test for `bin/demo` and Compose invariants, then use Docker smoke as the behavioral gate. [VERIFIED: recommended validation architecture]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Docker CLI / daemon | `./bin/demo`, Compose smoke | yes | Engine `29.5.2` | Missing Docker blocks Phase 54 final smoke. [VERIFIED: docker --version] [VERIFIED: docker info] |
| Docker Compose plugin command | All wrapper operations | yes | `v5.1.3` | None; requirement is Docker Compose plugin command. [VERIFIED: docker compose version] |
| GNU Bash | `bin/demo` | yes | `5.2.37` | `/usr/bin/env bash` may find another Bash on other hosts; keep script portable within Bash. [VERIFIED: bash --version] [VERIFIED: bin/demo] |
| curl | Host readiness/smoke checks | yes | `8.7.1` | Planner may add a clear `require_curl` message, but should not introduce local Elixir/Postgres. [VERIFIED: curl --version] [VERIFIED: bin/demo] |
| Mix / Elixir | Repo verification lanes only | yes | Mix `1.19.5` | Not required for adopters running `./bin/demo`; Dockerfile owns demo runtime. [VERIFIED: mix --version] [VERIFIED: examples/cairnloop_example/Dockerfile.demo] |
| Local Postgres | Not required by Phase 54 wrapper | not required | - | Compose `db` service is the demo DB. [VERIFIED: examples/cairnloop_example/compose.demo.yml] |

**Missing dependencies with no fallback:**
- None in this environment. [VERIFIED: command output]

**Missing dependencies with fallback:**
- None. [VERIFIED: command output]

## Validation Architecture

`workflow.nyquist_validation` is absent from `.planning/config.json`, so treat validation as enabled. [VERIFIED: .planning/config.json]

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit through root `mix ci.fast`, plus shell/Docker commands for wrapper behavior. [VERIFIED: mix.exs] |
| Config file | Root `mix.exs` aliases; example app `mix.exs` for optional E2E/runtime lanes. [VERIFIED: mix.exs] [VERIFIED: examples/cairnloop_example/mix.exs] |
| Quick run command | `bash -n bin/demo && ./bin/demo help && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` [VERIFIED: command output] |
| Full suite command | `mix ci.fast && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet && ./bin/demo smoke` [VERIFIED: CLAUDE.md] [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| BOOT-01 | `./bin/demo` runs from repo root and uses Docker Compose, not local Elixir/Postgres. [VERIFIED: .planning/REQUIREMENTS.md] | source + smoke | `bash -n bin/demo && ./bin/demo help && ./bin/demo smoke` | Partial: `bin/demo` yes; source test `test/cairnloop/demo_wrapper_contract_test.exs` needed in Wave 0. |
| BOOT-02 | Postgres stays private; Phoenix web uses localhost dynamic/configured port. [VERIFIED: .planning/REQUIREMENTS.md] | compose config + source | `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` plus source assertions on resolved config/no db ports | Partial: Compose file yes; test file Wave 0. |
| BOOT-03 | Start/urls print exact route block from discovered running port after health. [VERIFIED: .planning/REQUIREMENTS.md] | Docker integration + source | Start stack with isolated project, capture `./bin/demo` and `./bin/demo urls`, assert route labels and discovered port, then `./bin/demo down` | Partial: wrapper exists; capture test/harness Wave 0 or final verification. |
| BOOT-04 | Wrapper exposes URLs, logs, status/ps, stop, down, reset, help. [VERIFIED: .planning/REQUIREMENTS.md] | source + help smoke | `./bin/demo help`; source test asserts case aliases and help text include `status`/`ps` | Partial: alias exists but help omits `status`. |
| VER-01 | `./bin/demo smoke` boots isolated stack, checks locked routes, cleans volumes. [VERIFIED: .planning/REQUIREMENTS.md] | Docker smoke | `./bin/demo smoke` | Yes: wrapper command exists; final run required. |
| VER-02 | Smoke failures include failing URL/readiness URL and recent web logs. [VERIFIED: .planning/REQUIREMENTS.md] | source + controlled failure where practical | Source test for diagnostic helpers and failure strings; optional controlled bad route only if planner adds a test-only route-list seam without exposing adopter complexity | Gap: no dedicated automated proof yet. |

### Sampling Rate

- **Per task commit:** `bash -n bin/demo && ./bin/demo help` for wrapper edits; add focused `mix test test/cairnloop/demo_wrapper_contract_test.exs` after Wave 0. [VERIFIED: recommended validation architecture]
- **Per wave merge:** `mix ci.fast && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet`. [VERIFIED: CLAUDE.md] [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]
- **Phase gate:** `mix ci.fast && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet && ./bin/demo smoke`. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md]

### Wave 0 Gaps

- [ ] `test/cairnloop/demo_wrapper_contract_test.exs` - DB-free source/contract assertions for command aliases/help, route block, no hard-coded `localhost:4000`, dynamic port discovery helper, private DB/no db `ports`, web `host_ip`, and smoke cleanup strings. [VERIFIED: recommended validation architecture]
- [ ] Optional final-verification harness notes - document exact isolated start/urls/down capture if the planner wants direct BOOT-03 output proof in addition to smoke. [VERIFIED: recommended validation architecture]
- [ ] Framework install: none; use existing ExUnit and shell commands. [VERIFIED: mix.exs]

## Security Domain

`security_enforcement` is not set to `false` in `.planning/config.json`, so security review is enabled. [VERIFIED: .planning/config.json]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Phase does not add auth; `/support` uses existing example dashboard/session behavior. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex] |
| V3 Session Management | no | Phase does not change sessions/cookies. [VERIFIED: phase scope] |
| V4 Access Control | no | Phase does not change operator authorization or dashboard mounts. [VERIFIED: phase scope] |
| V5 Input Validation | yes | Validate command names through explicit `case`; quote env-derived values; constrain route list to literals; use Compose config for YAML validation. [VERIFIED: bin/demo] |
| V6 Cryptography | no | Phase does not introduce cryptography or secret storage. [VERIFIED: phase scope] |
| V9 Communications | yes | Bind published web port to localhost and keep DB private to Compose. [VERIFIED: examples/cairnloop_example/compose.demo.yml] [CITED: https://docs.docker.com/engine/network/port-publishing/] |
| V12 Files and Resources | yes | Cleanup must be Compose-project scoped; avoid global Docker prune/socket side effects. [VERIFIED: .planning/ROADMAP.md] |

### Known Threat Patterns for Demo Wrapper Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Host DB exposure through Compose `ports` | Information disclosure | Keep `db` private; assert no `db.ports` in resolved Compose config. [VERIFIED: docker compose config] |
| Web service bound to all interfaces | Information disclosure | Keep `host_ip: 127.0.0.1` by default; normalize wildcard output only for browser URLs, not as a binding recommendation. [VERIFIED: examples/cairnloop_example/compose.demo.yml] [CITED: https://docs.docker.com/engine/network/port-publishing/] |
| Project-name collision causing cleanup of another stack | Tampering / denial of service | Keep deterministic repo-root hash in normal project and `_smoke` suffix for smoke; never use global prune. [VERIFIED: bin/demo] |
| Shell injection through route or command strings | Tampering | Use literal route array/list and explicit `case`; quote variables in curl/compose calls. [VERIFIED: bin/demo] |
| Secret leakage in failure logs | Information disclosure | Keep diagnostics focused on recent web logs and failing route; avoid raw env dumps, Docker inspect JSON, or verbose curl traces. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-CONTEXT.md] |
| Docker socket overreach | Elevation of privilege | Use normal Compose commands only; avoid direct Docker socket mounting/API calls and global system prune. [VERIFIED: .planning/ROADMAP.md] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/54-demo-wrapper-experience/54-CONTEXT.md` - locked decisions, discretion, deferred scope. [VERIFIED: file read]
- `.planning/REQUIREMENTS.md` - BOOT-01 through BOOT-04 and VER-01 through VER-02. [VERIFIED: file read]
- `.planning/STATE.md`, `.planning/PROJECT.md`, `.planning/ROADMAP.md` - milestone posture and carried constraints. [VERIFIED: file read]
- `AGENTS.md` and `CLAUDE.md` - project instructions, build/test conventions, decision policy. [VERIFIED: file read]
- `bin/demo` - current command surface, URL discovery, health wait, smoke route checks, cleanup, help. [VERIFIED: codebase read]
- `examples/cairnloop_example/compose.demo.yml` and resolved `docker compose config` - private DB, web port range, host IP, volumes, healthchecks. [VERIFIED: command output]
- `examples/cairnloop_example/Dockerfile.demo` - Docker-only Elixir runtime command. [VERIFIED: codebase read]
- `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` and `lib/cairnloop/router.ex` - demo routes and operations endpoints. [VERIFIED: codebase read]
- `.planning/phases/53-demo-runtime-contract/53-VERIFICATION.md` - prior Docker smoke and runtime contract evidence. [VERIFIED: file read]

### Secondary (MEDIUM confidence)

- `https://docs.docker.com/reference/cli/docker/compose/port/` - `docker compose port` behavior. [CITED: official docs]
- `https://docs.docker.com/reference/compose-file/services/#ports` - Compose `ports` long syntax and published ranges. [CITED: official docs]
- `https://docs.docker.com/compose/how-tos/project-name/` - project-name isolation and precedence. [CITED: official docs]
- `https://docs.docker.com/compose/how-tos/environment-variables/envvars/#compose_project_name` - `COMPOSE_PROJECT_NAME` precedence. [CITED: official docs]
- `https://docs.docker.com/compose/how-tos/startup-order/` - `depends_on` and `service_healthy` readiness. [CITED: official docs]
- `https://docs.docker.com/reference/cli/docker/compose/up/` - `up --build`, `--detach`, `--wait`. [CITED: official docs]
- `https://docs.docker.com/reference/cli/docker/compose/down/` - container/network/volume teardown semantics. [CITED: official docs]
- `https://docs.docker.com/reference/cli/docker/compose/stop/` - stop semantics. [CITED: official docs]
- `https://docs.docker.com/reference/cli/docker/compose/logs/` - follow/tail log options. [CITED: official docs]
- `https://docs.docker.com/reference/cli/docker/compose/ps/` - status output. [CITED: official docs]
- `https://docs.docker.com/engine/network/port-publishing/` - localhost binding and exposure warning. [CITED: official docs]
- `https://www.gnu.org/software/bash/manual/bash.html` - Bash strict mode/trap behavior. [CITED: official docs]
- `https://curl.se/docs/manpage.html` - curl `--fail`, `--silent`, `--show-error`, `--location`. [CITED: official docs]

### Tertiary (LOW confidence)

- None. [VERIFIED: sources list]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new packages; stack is existing code plus locally verified Docker/Bash/curl/Mix versions and official Docker docs. [VERIFIED: command output]
- Architecture: HIGH - wrapper, Compose file, Dockerfile, routes, and Phase 53 verification were read directly. [VERIFIED: codebase read]
- Pitfalls: HIGH - each pitfall is tied to current code, locked context, resolved Compose config, or official docs. [VERIFIED: bin/demo] [VERIFIED: docker compose config] [CITED: https://docs.docker.com/]
- Validation: MEDIUM - final Docker smoke was not rerun during research, but Phase 53 verification recorded a passing `./bin/demo smoke`, and local Compose config/shell syntax checks passed. [VERIFIED: .planning/phases/53-demo-runtime-contract/53-VERIFICATION.md] [VERIFIED: command output]

**Research date:** 2026-06-28
**Valid until:** 2026-07-28
