# Phase 53: Demo Runtime Contract - Research

**Researched:** 2026-06-28
**Domain:** Phoenix example-app runtime contract, Ecto migrations, Docker Compose readiness, deterministic demo seeds
**Confidence:** HIGH

<user_constraints>
## User Constraints

No Phase 53 `CONTEXT.md` exists; research scope is constrained by `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `CLAUDE.md`, and the required example-app files. [VERIFIED: init.phase-op] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md]

### Locked Scope

- Phase 53 goal: prove the example app can boot under Docker and manual local setup without config, migration, health, or seed drift. [VERIFIED: .planning/ROADMAP.md]
- Phase 53 requirements are RUNT-01, RUNT-02, RUNT-03, RUNT-04, and RUNT-05. [VERIFIED: .planning/REQUIREMENTS.md]
- Success requires host migrations before Cairnloop library migrations in Docker and manual workflows, local path dogfooding while docs keep the Hex dependency story, routable `/health`, quiet Chimeway/Cairnloop config, and Trailmark seed data loaded by setup with no extra fixture command. [VERIFIED: .planning/ROADMAP.md]
- Guardrails: keep changes inside example runtime/config/seeds or narrowly related docs; do not change sealed Cairnloop public contracts; preserve the DB-free headless posture unless a test explicitly belongs to the example app. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: CLAUDE.md]

### Out Of Scope

- Phase 54 owns wrapper UX polish, URL printing, logs/status/stop/reset commands, and smoke command ergonomics. [VERIFIED: .planning/ROADMAP.md]
- Phase 55 owns Docker-first adopter docs beyond narrow Phase 53 corrections. [VERIFIED: .planning/ROADMAP.md]
- Phase 56 owns CI workflow gating for Docker smoke. [VERIFIED: .planning/ROADMAP.md]
</user_constraints>

## Project Constraints (from AGENTS.md)

- Read `CLAUDE.md` first before project work. [VERIFIED: AGENTS.md]
- For UI work, read `docs/operator-ui-principles.md` before editing `lib/cairnloop/web/**` or `priv/static/cairnloop.css`; Phase 53 should avoid UI edits unless a narrow runtime test exposes one. [VERIFIED: AGENTS.md] [VERIFIED: CLAUDE.md]
- The shipped dashboard uses Cairnloop tokenized `.cl-*` / BEM CSS, not Tailwind; do not introduce adopter-facing dashboard UI drift while proving runtime setup. [VERIFIED: AGENTS.md]
- Builds must be warnings-clean with `mix compile --warnings-as-errors`. [VERIFIED: CLAUDE.md]
- Headless completion normally requires `mix ci.fast`; DB-backed, docs/package, or browser changes require the relevant lane (`mix ci.integration`, `mix ci.quality`, or `cd examples/cairnloop_example && mix test.e2e`). [VERIFIED: CLAUDE.md]
- `Cairnloop.Repo` may be unavailable in this workspace; prefer pure/headless tests where they fit, and mark genuine Postgres round-trip tests rather than weakening them. [VERIFIED: CLAUDE.md]
- Do not churn sealed Cairnloop public contracts for downstream demo setup; prefer additive example-app configuration and tests. [VERIFIED: CLAUDE.md]
- Current worktree is dirty in many source and planning files, including Phase 53-relevant example files; planner/executor must preserve unrelated user changes and stage only intended files. [VERIFIED: git status]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RUNT-01 | Example setup path runs host migrations before Cairnloop library migrations in Docker and manual local workflows. [VERIFIED: .planning/REQUIREMENTS.md] | Use two ordered `ecto.migrate` task phases with `Mix.Task.reenable("ecto.migrate")` between them; do not merge paths because Ecto sorts all paths globally by migration version. [VERIFIED: examples/cairnloop_example/mix.exs] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [CITED: https://hexdocs.pm/mix/Mix.Task.html] |
| RUNT-02 | Maintainer can dogfood local path dependency while adopter docs preserve Hex dependency usage. [VERIFIED: .planning/REQUIREMENTS.md] | Keep example `{:cairnloop, path: "../.."}` and docs `{:cairnloop, "~> 0.1.0"}`; Mix documents Hex as default and path deps as local recompiling deps. [VERIFIED: examples/cairnloop_example/mix.exs] [VERIFIED: README.md] [VERIFIED: guides/01-quickstart.md] [CITED: https://hexdocs.pm/mix/Mix.Tasks.Deps.html] |
| RUNT-03 | `/health` is routable and suitable for Compose readiness checks. [VERIFIED: .planning/REQUIREMENTS.md] | Example router mounts `Cairnloop.Router.cairnloop_operations()` outside the browser pipeline; `mix phx.routes` shows `* /health Cairnloop.Web.HealthPlug`; Compose web healthcheck curls `http://127.0.0.1:4000/health`. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex] [VERIFIED: mix phx.routes] [VERIFIED: examples/cairnloop_example/compose.demo.yml] |
| RUNT-04 | Demo boots without noisy missing-config failures from Chimeway, Cairnloop behaviours, endpoint binding, or database env differences. [VERIFIED: .planning/REQUIREMENTS.md] | Keep Chimeway.Repo configured in dev/test, preserve `PGHOST`/`PGPORT`/`PORT`/`PHX_BIND` parsing, and add or verify a harmless example notifier if the dashboard health tile must avoid degraded missing-notifier copy. [VERIFIED: examples/cairnloop_example/config/dev.exs] [VERIFIED: examples/cairnloop_example/config/test.exs] [VERIFIED: lib/cairnloop/web/home_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] |
| RUNT-05 | Seeded Trailmark data is available immediately after setup with no extra fixture command. [VERIFIED: .planning/REQUIREMENTS.md] | `mix setup` runs `ecto.setup`, `ecto.setup` runs `run priv/repo/seeds.exs`, Docker `CMD` runs `mix setup && exec mix phx.server`, and the seed script is idempotent and drains Oban. [VERIFIED: examples/cairnloop_example/mix.exs] [VERIFIED: examples/cairnloop_example/Dockerfile.demo] [VERIFIED: examples/cairnloop_example/priv/repo/seeds.exs] [CITED: https://hexdocs.pm/oban/Oban.html] |
</phase_requirements>

## Summary

Phase 53 should be planned as example-app runtime hardening, not library API expansion. [VERIFIED: .planning/ROADMAP.md] The current dirty worktree already contains several target-shape pieces: ordered example migration aliases, a local path dependency, `/health` through `cairnloop_operations/0`, Docker Compose healthchecks, Chimeway.Repo dev/test config, and deterministic Trailmark seeds. [VERIFIED: examples/cairnloop_example/mix.exs] [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex] [VERIFIED: examples/cairnloop_example/compose.demo.yml] [VERIFIED: examples/cairnloop_example/config/dev.exs] [VERIFIED: examples/cairnloop_example/config/test.exs] [VERIFIED: examples/cairnloop_example/priv/repo/seeds.exs]

The most important planning decision is to preserve the two-phase migration alias rather than "simplifying" to one `ecto.migrate --migrations-path A --migrations-path B` call. [VERIFIED: examples/cairnloop_example/mix.exs] Ecto supports multiple migration paths but sorts all migrations as one set, and the library migration `20260517010000_add_retrieval_corpus_support.exs` references `cairnloop_conversations` before the example host migration `20260525201622_create_cairnloop_tables.exs` would run under global timestamp sorting. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [VERIFIED: priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs] [VERIFIED: examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs]

**Primary recommendation:** plan small, example-scoped tasks that verify and tighten the existing runtime contract: keep host-then-library migration aliases, correct stale migration-order docs, keep path-dep dogfooding plus Hex docs, verify `/health` routing and Compose readiness, add an example-only no-op notifier if needed for a calm health tile, and run seed/runtime validation behind a Postgres-backed example lane plus Docker smoke. [VERIFIED: codebase grep] [CITED: https://docs.docker.com/compose/how-tos/startup-order/]

Research-time checks completed: `cd examples/cairnloop_example && mix compile --warnings-as-errors` passed; `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` passed; `mix phx.routes` showed `/health`, `/metrics`, `/support`, and `/chat`; `mix test --exclude requires_postgres --exclude e2e --seed 0` failed because no Postgres server answered on `localhost:5433`. [VERIFIED: command output]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Setup orchestration and migration order | Example app build/runtime (`mix.exs` aliases) | Database | Mix aliases own the order of host and library migrations before the app serves requests. [VERIFIED: examples/cairnloop_example/mix.exs] |
| Docker boot contract | Docker Compose + container command | Example app runtime | Compose waits for `db` health, then web runs `mix setup` before `mix phx.server`. [VERIFIED: examples/cairnloop_example/compose.demo.yml] [VERIFIED: examples/cairnloop_example/Dockerfile.demo] [CITED: https://docs.docker.com/compose/how-tos/startup-order/] |
| Manual local boot contract | Example app runtime config | Host Postgres | `config/dev.exs` reads `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`, `PORT`, and `PHX_BIND`. [VERIFIED: examples/cairnloop_example/config/dev.exs] |
| Health readiness route | Router / Plug layer | Docker Compose healthcheck | `cairnloop_operations/0` forwards `/health` to `Cairnloop.Web.HealthPlug`; Compose curls that path after setup/server start. [VERIFIED: lib/cairnloop/router.ex] [VERIFIED: lib/cairnloop/web/health_plug.ex] [VERIFIED: examples/cairnloop_example/compose.demo.yml] |
| Dependency dogfooding | Build/dependency config | Documentation | Example app uses local path dep; adopter docs show Hex dependency. [VERIFIED: examples/cairnloop_example/mix.exs] [VERIFIED: README.md] [VERIFIED: guides/01-quickstart.md] |
| Trailmark demo data | Database / seed script | Oban workers | Seed script inserts deterministic KB, conversations, gaps, suggestions, governance, outbound, and token data, then drains embedding jobs. [VERIFIED: examples/cairnloop_example/priv/repo/seeds.exs] |
| Behaviour-noise suppression | Application config | Example-only modules | Chimeway.Repo config suppresses boot noise; Cairnloop defaults cover automation/SLA, while notifier health needs explicit example config if a green health tile is required. [VERIFIED: examples/cairnloop_example/config/dev.exs] [VERIFIED: examples/cairnloop_example/config/test.exs] [VERIFIED: lib/cairnloop/default_automation_policy.ex] [VERIFIED: lib/cairnloop/default_sla_policy_provider.ex] [VERIFIED: lib/cairnloop/web/home_live.ex] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Elixir / Mix | Local `1.19.5`, Dockerfile image `hexpm/elixir:1.19.5-erlang-27.2.4-debian-trixie-20260623-slim` | Example app runtime and task aliases | Existing project runtime; no phase package change needed. [VERIFIED: elixir --version] [VERIFIED: mix --version] [VERIFIED: examples/cairnloop_example/Dockerfile.demo] |
| Phoenix | `1.8.8` in example deps | Router, endpoint, LiveView host app | Existing app framework and official router forwarding contract. [VERIFIED: mix deps] [CITED: https://hexdocs.pm/phoenix/Phoenix.Router.html] |
| Ecto SQL | `3.14.0` in example deps | Repo migrations and SQL adapter tasks | Official `mix ecto.migrate` task owns migration path behavior. [VERIFIED: mix deps] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] |
| Postgrex | `0.22.2` in example lock | PostgreSQL driver | Existing Ecto/Postgres adapter dependency. [VERIFIED: examples/cairnloop_example/mix.lock] |
| Oban | `2.23.0` in example deps | Background jobs and seed queue draining | Official `drain_queue/2` supports deterministic in-process seed/test draining. [VERIFIED: mix deps] [CITED: https://hexdocs.pm/oban/Oban.html] |
| pgvector | `0.3.1` in example deps; Compose DB image `pgvector/pgvector:pg16` | Vector extension/types for KB chunks | Existing project substrate for Knowledge Base embeddings. [VERIFIED: mix deps] [VERIFIED: examples/cairnloop_example/compose.demo.yml] |
| Chimeway | `1.0.0` in example deps | Transitive notification dependency whose Repo must boot quietly | Existing dependency; configure Repo but do not rely on Chimeway delivery for the demo without its migrations. [VERIFIED: mix deps] [VERIFIED: examples/cairnloop_example/config/dev.exs] [VERIFIED: examples/cairnloop_example/deps/chimeway/priv/repo/migrations] |
| Docker Compose | Local `v5.1.3` | Docker demo runtime | Compose `service_healthy` matches the intended DB-before-web contract. [VERIFIED: docker compose version] [CITED: https://docs.docker.com/compose/how-tos/startup-order/] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| PhoenixTest Playwright | `0.14.0` in example lock | Existing real-browser lane | Use only if a Phase 53 change affects rendered/browser behavior; otherwise prefer route and DB-backed runtime checks. [VERIFIED: examples/cairnloop_example/mix.lock] [VERIFIED: examples/cairnloop_example/AGENTS.md] |
| Bandit | `1.12.0` in example deps | Phoenix HTTP server | Existing endpoint adapter; health readiness flows through it in dev/Docker. [VERIFIED: mix deps] [VERIFIED: examples/cairnloop_example/config/config.exs] |
| curl | Local `8.7.1` | Compose/web health probe | Compose web healthcheck and wrapper smoke use curl. [VERIFIED: curl --version] [VERIFIED: examples/cairnloop_example/compose.demo.yml] [VERIFIED: bin/demo] |
| psql / pg_isready | Local `psql 14.17`; `localhost:5433` currently no response | Manual DB diagnostics | Use root Docker DB fallback before DB-backed example tests. [VERIFIED: psql --version] [VERIFIED: pg_isready] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Two explicit `ecto.migrate` phases | One `ecto.migrate` call with two `--migrations-path` values | Rejected for Phase 53 because Ecto globally sorts all paths and current library migrations include timestamps earlier than host-owned conversation table migrations. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [VERIFIED: priv/repo/migrations] |
| Example-only no-op notifier | `Cairnloop.Notifier.Chimeway` | Chimeway notifier routes through Chimeway persistence paths, while the example setup does not run Chimeway migrations; no-op notifier satisfies health/UI calm without external side effects. [VERIFIED: lib/cairnloop/notifier/chimeway.ex] [VERIFIED: examples/cairnloop_example/deps/chimeway/priv/repo/migrations] |
| Static `/health` plug | New example-specific health controller with DB checks | Avoid unless requirements change; Docker readiness is already sequenced by `mix setup` before server start, and sealed library operations should not be changed for demo setup. [VERIFIED: examples/cairnloop_example/Dockerfile.demo] [VERIFIED: lib/cairnloop/web/health_plug.ex] [VERIFIED: CLAUDE.md] |

**Installation:** no new packages should be installed for Phase 53. [VERIFIED: .planning/ROADMAP.md] Existing dependencies are already in `examples/cairnloop_example/mix.exs` and `mix.lock`. [VERIFIED: examples/cairnloop_example/mix.exs] [VERIFIED: examples/cairnloop_example/mix.lock]

**Version verification:** use `cd examples/cairnloop_example && mix deps | rg 'phoenix|ecto_sql|oban|chimeway|pgvector|bandit|postgrex'` before planning dependency-sensitive tasks. [VERIFIED: command output]

## Package Legitimacy Audit

Phase 53 should not install external packages; the package legitimacy gate is not required. [VERIFIED: .planning/ROADMAP.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none | - | - | - | - | - | No new package installs for this phase. [VERIFIED: research recommendation] |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: no package install planned]
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: no package install planned]

## Architecture Patterns

### System Architecture Diagram

```text
Manual path:
  developer shell
    -> cd examples/cairnloop_example
    -> mix setup
       -> deps.get
       -> ecto.create
       -> host migrations (examples/.../priv/repo/migrations)
       -> Mix.Task.reenable("ecto.migrate")
       -> Cairnloop library migrations (deps/cairnloop or ../../priv/repo/migrations)
       -> run priv/repo/seeds.exs
          -> KnowledgeBase facade inserts
          -> Governance/Automation facades for showcase states
          -> Oban.drain_queue(queue: :default, with_recursion: true)
    -> mix phx.server
    -> browser /support, /chat, /health

Docker path:
  ./bin/demo or docker compose up
    -> db service healthcheck: pg_isready
    -> web service starts after db service_healthy
    -> Dockerfile CMD: mix setup && exec mix phx.server
    -> web service healthcheck: curl /health
    -> wrapper/smoke checks routes after health
```

The manual path above is derived from `mix.exs`; the Docker path above is derived from `compose.demo.yml`, `Dockerfile.demo`, and `bin/demo`. [VERIFIED: examples/cairnloop_example/mix.exs] [VERIFIED: examples/cairnloop_example/compose.demo.yml] [VERIFIED: examples/cairnloop_example/Dockerfile.demo] [VERIFIED: bin/demo]

### Recommended Project Structure

```text
examples/cairnloop_example/
|-- mix.exs                         # setup/test aliases and local path dependency [VERIFIED: codebase grep]
|-- config/
|   |-- config.exs                  # Cairnloop repo/tools/context provider config [VERIFIED: codebase grep]
|   |-- dev.exs                     # manual/Docker dev DB, Chimeway, endpoint binding [VERIFIED: codebase grep]
|   |-- test.exs                    # sandbox DB, Chimeway, e2e endpoint [VERIFIED: codebase grep]
|   `-- runtime.exs                 # runtime endpoint/prod env only [VERIFIED: codebase grep]
|-- lib/cairnloop_example/
|   |-- demo_context_provider.ex    # configured ContextProvider [VERIFIED: codebase grep]
|   `-- demo_notifier.ex            # recommended example-only no-op Notifier if health must be green [VERIFIED: recommendation from codebase gap]
|-- lib/cairnloop_example_web/router.ex # /support, /chat, /health mounting [VERIFIED: codebase grep]
|-- priv/repo/migrations/           # host-owned migrations that must run first [VERIFIED: codebase grep]
|-- priv/repo/seeds.exs             # deterministic Trailmark seed [VERIFIED: codebase grep]
|-- compose.demo.yml                # Docker demo services/readiness [VERIFIED: codebase grep]
`-- Dockerfile.demo                 # container runtime command [VERIFIED: codebase grep]
```

### Pattern 1: Two-Phase Migration Alias

**What:** Run host migrations first with the default path, re-enable `ecto.migrate`, then run Cairnloop library migrations from the dependency/source tree. [VERIFIED: examples/cairnloop_example/mix.exs]
**When to use:** Use for both `mix setup` and example `mix test` aliases because the library migrations reference host-owned tables. [VERIFIED: priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs] [VERIFIED: priv/repo/migrations/20260524120000_add_conversation_id_to_tool_proposals.exs]
**Example:**

```elixir
# Source: examples/cairnloop_example/mix.exs
reenable_migrate = fn _ -> Mix.Task.reenable("ecto.migrate") end

"ecto.setup": [
  "ecto.create",
  "ecto.migrate",
  reenable_migrate,
  "ecto.migrate --migrations-path #{cairnloop_migrations}",
  "run priv/repo/seeds.exs"
]
```

**Why:** Ecto says multiple `--migrations-path` values are loaded and sorted as if they were one directory; Mix says tasks are one-shot unless re-enabled. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [CITED: https://hexdocs.pm/mix/Mix.Task.html]

### Pattern 2: Path Dependency For Dogfooding, Hex Dependency In Docs

**What:** Keep `{:cairnloop, path: "../.."}` in the example app, while README/Quickstart/adopter docs show `{:cairnloop, "~> 0.1.0"}`. [VERIFIED: examples/cairnloop_example/mix.exs] [VERIFIED: README.md] [VERIFIED: guides/01-quickstart.md]
**When to use:** Use the path dependency only in the repo example app so local library changes are exercised without publishing a Hex package. [VERIFIED: examples/cairnloop_example/mix.exs]
**Example:**

```elixir
# Source: examples/cairnloop_example/mix.exs
{:cairnloop, path: "../.."}
```

Mix documents both Hex and path dependency forms, and path dependencies are automatically recompiled by the parent project when they change. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Deps.html]

### Pattern 3: Operations Health Outside Browser Pipeline

**What:** Mount operations endpoints in a scope without `pipe_through :browser`. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex]
**When to use:** Use for infrastructure probes that should not need sessions, CSRF, layouts, or operator auth. [CITED: https://hexdocs.pm/phoenix/Phoenix.Router.html]
**Example:**

```elixir
# Source: examples/cairnloop_example/lib/cairnloop_example_web/router.ex
scope "/" do
  Cairnloop.Router.cairnloop_operations()
end
```

Phoenix invokes scope pipelines before forwarding, so keeping `/health` outside `:browser` preserves a clean probe path. [CITED: https://hexdocs.pm/phoenix/Phoenix.Router.html]

### Pattern 4: Runtime Env Split For Manual vs Docker

**What:** Manual dev defaults use `localhost:5433`; Docker overrides with `PGHOST=db`, `PGPORT=5432`, `PORT=4000`, and `PHX_BIND=0.0.0.0`. [VERIFIED: examples/cairnloop_example/config/dev.exs] [VERIFIED: examples/cairnloop_example/compose.demo.yml]
**When to use:** Use `PG*` env vars for dev/Docker; reserve `DATABASE_URL` for prod runtime config. [VERIFIED: examples/cairnloop_example/config/runtime.exs]
**Example:**

```elixir
# Source: examples/cairnloop_example/config/dev.exs
database_hostname = System.get_env("PGHOST") || "localhost"
database_port = String.to_integer(System.get_env("PGPORT") || "5433")
```

Compose default networking lets `web` reach `db` by service name. [CITED: https://docs.docker.com/compose/how-tos/networking/]

### Pattern 5: Deterministic Seed With Facades And Drain

**What:** Seed script uses natural keys, real Cairnloop facades, and `Oban.drain_queue(queue: :default, with_recursion: true)`. [VERIFIED: examples/cairnloop_example/priv/repo/seeds.exs]
**When to use:** Use when seeded data must be immediately clickable after `mix setup` or Docker boot. [VERIFIED: examples/cairnloop_example/mix.exs] [VERIFIED: examples/cairnloop_example/Dockerfile.demo]
**Example:**

```elixir
# Source: examples/cairnloop_example/priv/repo/seeds.exs
Oban.drain_queue(queue: :default, with_recursion: true)
```

Oban documents `drain_queue/2` as synchronous, current-process execution and `with_recursion` as repeated draining when jobs enqueue more jobs. [CITED: https://hexdocs.pm/oban/Oban.html]

### Pattern 6: Example-Only No-Op Notifier For Calm Health

**What:** Configure a harmless example notifier if the planner wants the Home/Settings health tile to avoid missing-notifier degraded copy. [VERIFIED: lib/cairnloop/web/home_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex]
**When to use:** Use in the example app only; do not change `Cairnloop.Notifier` or use Chimeway delivery unless Chimeway migrations/workflows are explicitly added. [VERIFIED: lib/cairnloop/notifier.ex] [VERIFIED: lib/cairnloop/notifier/chimeway.ex] [VERIFIED: examples/cairnloop_example/deps/chimeway/priv/repo/migrations]

```elixir
# Recommended example-app module; source basis: Cairnloop.Notifier behaviour.
defmodule CairnloopExample.DemoNotifier do
  @behaviour Cairnloop.Notifier

  @impl true
  def on_conversation_resolved(_conversation, _metadata), do: :ok

  @impl true
  def on_sla_breach(_conversation, _sla, _metadata), do: :ok

  @impl true
  def on_outbound_triggered(_message, _conversation), do: :ok
end

# config/config.exs or env-specific config
config :cairnloop, :notifier, CairnloopExample.DemoNotifier
```

### Anti-Patterns to Avoid

- **Merging host and library migration paths in one task:** Ecto sorts all paths globally, which breaks the required host-before-library order for this repo. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [VERIFIED: priv/repo/migrations] [VERIFIED: examples/cairnloop_example/priv/repo/migrations]
- **Calling `ecto.migrate` twice without re-enabling:** Mix returns `:noop` for already-invoked tasks unless re-enabled or rerun. [CITED: https://hexdocs.pm/mix/Mix.Task.html]
- **Changing Cairnloop library health or notifier contracts for demo setup:** Phase guardrails forbid sealed public contract churn. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: CLAUDE.md]
- **Using `Cairnloop.Notifier.Chimeway` to silence health without Chimeway migrations:** Chimeway has its own persistence migrations; example setup currently does not run them. [VERIFIED: lib/cairnloop/notifier/chimeway.ex] [VERIFIED: examples/cairnloop_example/deps/chimeway/priv/repo/migrations] [VERIFIED: examples/cairnloop_example/mix.exs]
- **Adding a separate fixture command for Trailmark data:** `mix setup` and Docker `CMD` already include `priv/repo/seeds.exs`; a separate fixture command violates RUNT-05. [VERIFIED: examples/cairnloop_example/mix.exs] [VERIFIED: examples/cairnloop_example/Dockerfile.demo]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Migration order | Custom SQL runner or timestamp renames | Existing Mix/Ecto aliases with `Mix.Task.reenable/1` | Ecto already tracks migrations; the needed fix is task ordering, not a new migrator. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [CITED: https://hexdocs.pm/mix/Mix.Task.html] |
| Health route | New demo controller or library contract change | `Cairnloop.Router.cairnloop_operations()` and `Cairnloop.Web.HealthPlug` | Existing macro already mounts `/health`; route verified in example app. [VERIFIED: lib/cairnloop/router.ex] [VERIFIED: mix phx.routes] |
| Docker readiness sequencing | Sleep loops inside app boot | Compose `depends_on: condition: service_healthy` plus web healthcheck | Compose officially supports dependency health gating. [CITED: https://docs.docker.com/compose/how-tos/startup-order/] |
| Seed job synchronization | Manual sleeps after seeding | `Oban.drain_queue(queue: :default, with_recursion: true)` | Oban provides synchronous queue draining for tests/seeds. [CITED: https://hexdocs.pm/oban/Oban.html] |
| Demo notifier behavior | Chimeway-backed delivery without Chimeway migrations | Example-only no-op notifier | Keeps dashboard health calm without introducing delivery side effects or schema needs. [VERIFIED: lib/cairnloop/web/settings_live.ex] [VERIFIED: examples/cairnloop_example/deps/chimeway/priv/repo/migrations] |
| Local package dogfooding | Publishing a temporary Hex version | Path dependency in example app | Mix supports path deps and recompiles them locally. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Deps.html] |

**Key insight:** Phase 53 should tighten orchestration and validation around existing platform primitives; custom substitutes increase drift from the adopter path the demo is supposed to prove. [VERIFIED: .planning/ROADMAP.md] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [CITED: https://docs.docker.com/compose/how-tos/startup-order/]

## Common Pitfalls

### Pitfall 1: Globally Sorted Migration Paths

**What goes wrong:** Library migrations can run before host-owned `cairnloop_conversations` exists. [VERIFIED: priv/repo/migrations/20260517010000_add_retrieval_corpus_support.exs] [VERIFIED: examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs]
**Why it happens:** Ecto sorts migrations from multiple `--migrations-path` values as one directory. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html]
**How to avoid:** Keep separate host then library migration task invocations. [VERIFIED: examples/cairnloop_example/mix.exs]
**Warning signs:** Troubleshooting docs still mention a merged-path example that conflicts with the current alias contract. [VERIFIED: guides/04-troubleshooting.md]

### Pitfall 2: Mix Task One-Shot Semantics

**What goes wrong:** The second `ecto.migrate` in an alias silently does nothing. [CITED: https://hexdocs.pm/mix/Mix.Task.html]
**Why it happens:** Mix tasks only run once per stack unless re-enabled or rerun. [CITED: https://hexdocs.pm/mix/Mix.Task.html]
**How to avoid:** Keep `reenable_migrate = fn _ -> Mix.Task.reenable("ecto.migrate") end` between migration phases. [VERIFIED: examples/cairnloop_example/mix.exs]
**Warning signs:** Library tables such as `cairnloop_articles`, `cairnloop_tool_proposals`, or `cairnloop_outbound_bulk_envelopes` are missing after `mix setup`. [VERIFIED: priv/repo/migrations]

### Pitfall 3: `DATABASE_URL` vs `PG*` Env Confusion

**What goes wrong:** Docker/manual dev configuration is debugged through the wrong env variable. [VERIFIED: examples/cairnloop_example/config/dev.exs] [VERIFIED: examples/cairnloop_example/config/runtime.exs]
**Why it happens:** `DATABASE_URL` is only required in prod runtime config, while dev/Docker use `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, and `PGDATABASE`. [VERIFIED: examples/cairnloop_example/config/dev.exs] [VERIFIED: examples/cairnloop_example/config/runtime.exs]
**How to avoid:** Keep Compose on `MIX_ENV=dev` with `PGHOST=db` and `PGPORT=5432`; keep manual docs centered on `PGPORT=5433` fallback. [VERIFIED: examples/cairnloop_example/compose.demo.yml] [VERIFIED: examples/cairnloop_example/README.md]
**Warning signs:** A developer sets only `DATABASE_URL` for `mix setup` in dev and still sees `localhost:5433` connection attempts. [VERIFIED: examples/cairnloop_example/config/dev.exs]

### Pitfall 4: Chimeway Repo Quieting Is Not Chimeway Delivery Setup

**What goes wrong:** A planner configures `Cairnloop.Notifier.Chimeway` and introduces missing Chimeway table failures. [VERIFIED: lib/cairnloop/notifier/chimeway.ex] [VERIFIED: examples/cairnloop_example/deps/chimeway/priv/repo/migrations]
**Why it happens:** Dev/test config gives Chimeway.Repo connection settings to suppress boot noise, but example migrations do not run Chimeway's own schema migrations. [VERIFIED: examples/cairnloop_example/config/dev.exs] [VERIFIED: examples/cairnloop_example/config/test.exs] [VERIFIED: examples/cairnloop_example/mix.exs]
**How to avoid:** Use an example-only no-op notifier if notifier health needs to read healthy. [VERIFIED: lib/cairnloop/web/home_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex]
**Warning signs:** Errors mention `chimeway_notifications`, `chimeway_deliveries`, or workflow tables. [VERIFIED: examples/cairnloop_example/deps/chimeway/priv/repo/migrations]

### Pitfall 5: Seeds Bypass The Facades

**What goes wrong:** KB chunks, review tasks, or governed-action audit rows are missing after setup. [VERIFIED: examples/cairnloop_example/priv/repo/seeds.exs]
**Why it happens:** Direct inserts skip `KnowledgeBase.publish_revision/1`, `KnowledgeAutomation.ensure_review_task_for_suggestion/2`, or Governance transitions. [VERIFIED: examples/cairnloop_example/priv/repo/seeds.exs]
**How to avoid:** Preserve facade calls and `Oban.drain_queue/2`. [VERIFIED: examples/cairnloop_example/priv/repo/seeds.exs] [CITED: https://hexdocs.pm/oban/Oban.html]
**Warning signs:** `/support/knowledge-base/suggestions` is empty, cmd+k has no chunks, or audit log lacks governed events after setup. [VERIFIED: examples/cairnloop_example/test/cairnloop_example/seeds_test.exs]

### Pitfall 6: DB-Backed Example Tests Fail Without Local Postgres

**What goes wrong:** Example `mix test` fails before assertions because the alias creates/migrates `CairnloopExample.Repo`. [VERIFIED: examples/cairnloop_example/mix.exs] [VERIFIED: command output]
**Why it happens:** No server answered `pg_isready -h localhost -p 5433 -U postgres` during research. [VERIFIED: pg_isready]
**How to avoid:** Start the root database-only Compose service with `PGPORT=5433 docker compose up -d db`, or run Docker demo smoke for the full container path. [VERIFIED: docker-compose.yml] [VERIFIED: bin/demo]
**Warning signs:** `DBConnection.ConnectionError tcp connect (localhost:5433): connection refused`. [VERIFIED: command output]

### Pitfall 7: Dirty Worktree Overwrite

**What goes wrong:** Planner/executor reverts or overwrites uncommitted user changes in example runtime files. [VERIFIED: git status]
**Why it happens:** Many Phase 53-like files are already modified or untracked. [VERIFIED: git status]
**How to avoid:** Start execution with `git diff -- examples/cairnloop_example ...` and preserve current contents unless the task explicitly changes them. [VERIFIED: git status]
**Warning signs:** A plan assumes files match `HEAD` instead of the current worktree. [VERIFIED: git status]

## Code Examples

### Ordered Migration Alias

```elixir
# Source: examples/cairnloop_example/mix.exs
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

### Health Route Mount

```elixir
# Source: examples/cairnloop_example/lib/cairnloop_example_web/router.ex
scope "/" do
  Cairnloop.Router.cairnloop_operations()
end
```

### Compose Readiness

```yaml
# Source: examples/cairnloop_example/compose.demo.yml
depends_on:
  db:
    condition: service_healthy
healthcheck:
  test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:4000/health >/dev/null"]
```

### Seed Contract Test Command

```bash
# Source: examples/cairnloop_example/test/cairnloop_example/seeds_test.exs + mix.exs
PGPORT=5433 docker compose up -d db
cd examples/cairnloop_example
mix test --only requires_postgres test/cairnloop_example/seeds_test.exs
```

### Docker Contract Check

```bash
# Source: examples/cairnloop_example/AGENTS.md + bin/demo
./bin/demo smoke
```

## State Of The Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Merged migration paths in troubleshooting docs | Two ordered migration task phases with `Mix.Task.reenable/1` | Current dirty worktree as of 2026-06-28 [VERIFIED: guides/04-troubleshooting.md] [VERIFIED: examples/cairnloop_example/mix.exs] | Planner should update stale docs or tests so adopter guidance matches runtime truth. [VERIFIED: codebase grep] |
| Manual-only example first run | Docker demo first-run path plus manual fallback | vM018 roadmap [VERIFIED: .planning/ROADMAP.md] | Phase 53 must prove both paths before wrapper/docs/CI polish. [VERIFIED: .planning/ROADMAP.md] |
| Missing notifier tolerated as no-op | Example should use no-op notifier if health surfaces need calm green state | Phase 53 recommendation from current health code [VERIFIED: lib/cairnloop/web/home_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex] | Avoids confusing demo health without introducing Chimeway delivery schema. [VERIFIED: lib/cairnloop/notifier/chimeway.ex] |
| Async seed embedding eventual consistency | Seed drains Oban queue before exit | Current seed script [VERIFIED: examples/cairnloop_example/priv/repo/seeds.exs] | KB search/chunks should be available immediately after setup. [CITED: https://hexdocs.pm/oban/Oban.html] |

**Deprecated/outdated:**
- Troubleshooting guide merged-path migration snippet is outdated for this repo because Ecto global sorting conflicts with the current host/library timestamp layout. [VERIFIED: guides/04-troubleshooting.md] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [VERIFIED: priv/repo/migrations] [VERIFIED: examples/cairnloop_example/priv/repo/migrations]

## Assumptions Log

All claims in this research were verified from required project files, command output, or cited official documentation. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [CITED: https://hexdocs.pm/mix/Mix.Task.html] [CITED: https://hexdocs.pm/oban/Oban.html] [CITED: https://docs.docker.com/compose/how-tos/startup-order/]

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| - | - | - | - |

## Open Questions (RESOLVED)

1. **Which dirty runtime changes are user-owned versus intended Phase 53 work?**
   Resolution: dirty runtime changes are handled as existing user/worktree changes. Executors must begin relevant tasks with `git diff -- <paths>` or equivalent current-file reads, preserve user edits, and make additive/narrow modifications only. [VERIFIED: git status]
   Rationale: many example runtime files, docs, `bin/demo`, and Docker files are already modified or untracked, so Phase 53 plans must not assume files match `HEAD` or revert existing work. [VERIFIED: git status]

2. **Should Phase 53 run full Docker smoke during planning/execution or leave it to Phase 54/56?**
   Resolution: Phase 53 final verification includes `./bin/demo smoke` or an explicit equivalent Docker Compose up/health/routes check because runtime contract proof belongs in Phase 53. [VERIFIED: examples/cairnloop_example/AGENTS.md] [VERIFIED: bin/demo] [VERIFIED: examples/cairnloop_example/compose.demo.yml]
   Scope boundary: wrapper UX polish remains Phase 54, broader Docker-first adopter docs remain Phase 55, and CI gating remains Phase 56. [VERIFIED: .planning/ROADMAP.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Docker CLI | Docker demo path | yes | `29.5.2` | - [VERIFIED: docker --version] |
| Docker daemon | Docker demo path | yes | Server `29.5.2` | - [VERIFIED: docker info] |
| Docker Compose | Docker demo path | yes | `v5.1.3` | - [VERIFIED: docker compose version] |
| Elixir | Manual local path | yes | `1.19.5` / OTP 28 | Docker demo for adopters without local Elixir. [VERIFIED: elixir --version] [VERIFIED: examples/cairnloop_example/README.md] |
| Mix | Manual local path | yes | `1.19.5` / OTP 28 | Docker demo. [VERIFIED: mix --version] |
| curl | Compose/web healthchecks | yes | `8.7.1` | Docker image installs curl for container healthcheck. [VERIFIED: curl --version] [VERIFIED: examples/cairnloop_example/Dockerfile.demo] |
| psql client | Manual DB diagnostics | yes | `14.17` | Use Docker DB healthcheck/logs. [VERIFIED: psql --version] |
| Postgres on `localhost:5433` | Manual example DB tests | no | no response | `PGPORT=5433 docker compose up -d db` from repo root. [VERIFIED: pg_isready] [VERIFIED: docker-compose.yml] |

**Missing dependencies with no fallback:** none for planning; local manual DB tests are blocked until Postgres/pgvector is started. [VERIFIED: environment audit]

**Missing dependencies with fallback:**
- Local Postgres on `localhost:5433` is unavailable; use the root Docker `db` service or the full demo Compose stack. [VERIFIED: pg_isready] [VERIFIED: docker-compose.yml] [VERIFIED: examples/cairnloop_example/compose.demo.yml]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit plus example-app PhoenixTest Playwright for `:e2e` browser lane. [VERIFIED: examples/cairnloop_example/test/test_helper.exs] [VERIFIED: examples/cairnloop_example/mix.exs] |
| Config file | `examples/cairnloop_example/config/test.exs`; `ExUnit.start(exclude: [:e2e])` in `test/test_helper.exs`. [VERIFIED: examples/cairnloop_example/config/test.exs] [VERIFIED: examples/cairnloop_example/test/test_helper.exs] |
| Quick run command | `cd examples/cairnloop_example && mix compile --warnings-as-errors` [VERIFIED: command output] |
| DB-backed seed command | `PGPORT=5433 docker compose up -d db && cd examples/cairnloop_example && mix test --only requires_postgres test/cairnloop_example/seeds_test.exs` [VERIFIED: docker-compose.yml] [VERIFIED: examples/cairnloop_example/test/cairnloop_example/seeds_test.exs] |
| Docker runtime command | `./bin/demo smoke` after runtime changes land. [VERIFIED: examples/cairnloop_example/AGENTS.md] [VERIFIED: bin/demo] |
| Full suite command | Root `mix ci.fast`, `mix ci.integration`, and `mix ci.quality` are required for Phase 53 final verification; DB/browser/Docker lanes apply based on changed files and runtime scope. [VERIFIED: CLAUDE.md] |

### Phase Requirements To Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| RUNT-01 | Host migrations run before library migrations. [VERIFIED: .planning/REQUIREMENTS.md] | integration / command | `cd examples/cairnloop_example && mix ecto.reset` with Postgres running; inspect successful library tables. [VERIFIED: examples/cairnloop_example/mix.exs] | Alias exists: yes. [VERIFIED: examples/cairnloop_example/mix.exs] |
| RUNT-02 | Example uses path dep; docs show Hex dep. [VERIFIED: .planning/REQUIREMENTS.md] | source/doc check | `rg -n '{:cairnloop, path:|{:cairnloop, "~>' examples/cairnloop_example/mix.exs README.md guides/01-quickstart.md examples/cairnloop_example/README.md` [VERIFIED: command strategy] | Files exist: yes. [VERIFIED: codebase grep] |
| RUNT-03 | `/health` route is mounted and Compose checks it. [VERIFIED: .planning/REQUIREMENTS.md] | route/config smoke | `cd examples/cairnloop_example && mix phx.routes | rg '/health'` and `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` [VERIFIED: command output] | Route exists: yes. [VERIFIED: mix phx.routes] |
| RUNT-04 | Missing Chimeway/Cairnloop behavior config does not create noisy failures. [VERIFIED: .planning/REQUIREMENTS.md] | compile + DB smoke | `cd examples/cairnloop_example && mix compile --warnings-as-errors`; with DB running, boot `mix phx.server` or Docker smoke and check logs. [VERIFIED: command output] | Partial config exists: yes; no-op notifier file is a likely Wave 0 gap. [VERIFIED: examples/cairnloop_example/config/dev.exs] [VERIFIED: lib/cairnloop/web/settings_live.ex] |
| RUNT-05 | Trailmark seed data loads via setup and is idempotent. [VERIFIED: .planning/REQUIREMENTS.md] | DB-backed ExUnit | `cd examples/cairnloop_example && mix test --only requires_postgres test/cairnloop_example/seeds_test.exs` with DB running. [VERIFIED: examples/cairnloop_example/test/cairnloop_example/seeds_test.exs] | Seed test exists: yes in dirty tree. [VERIFIED: codebase grep] |

### Sampling Rate

- **Per task commit:** `cd examples/cairnloop_example && mix compile --warnings-as-errors`; add `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` for Compose/Dockerfile edits. [VERIFIED: CLAUDE.md] [VERIFIED: command output]
- **Per wave merge:** run DB-backed seed/runtime command with root Postgres service running. [VERIFIED: examples/cairnloop_example/test/cairnloop_example/seeds_test.exs] [VERIFIED: docker-compose.yml]
- **Phase gate:** run `./bin/demo smoke` or an equivalent explicit Docker Compose up/health/routes check before `$gsd-verify-work`. [VERIFIED: examples/cairnloop_example/AGENTS.md] [VERIFIED: bin/demo]

### Wave 0 Gaps

- [ ] `examples/cairnloop_example/lib/cairnloop_example/demo_notifier.ex` - recommended if planner wants Home/Settings health to avoid degraded notifier copy without Chimeway migrations. [VERIFIED: lib/cairnloop/web/home_live.ex] [VERIFIED: lib/cairnloop/web/settings_live.ex]
- [ ] `guides/04-troubleshooting.md` migration-order section - update stale merged-path guidance to two explicit migration phases. [VERIFIED: guides/04-troubleshooting.md] [VERIFIED: examples/cairnloop_example/mix.exs]
- [ ] DB availability preflight - start `PGPORT=5433 docker compose up -d db` before example DB tests in this workspace. [VERIFIED: pg_isready] [VERIFIED: docker-compose.yml]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | No for `/health`; yes for dashboard remains existing browser/session pipeline. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex] | Keep `/health` outside browser auth and keep `/support` inside browser pipeline with `fetch_current_operator`. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex] |
| V3 Session Management | No for `/health`; yes for dashboard sessions. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex] | Do not put health under session/CSRF plugs; do not alter dashboard session MFA. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/operator_auth.ex] |
| V4 Access Control | Yes for operator surfaces; no sensitive data on `/health`. [VERIFIED: lib/cairnloop/web/health_plug.ex] | Preserve browser pipeline and dynamic `host_user_id` session for `/support`. [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/router.ex] [VERIFIED: examples/cairnloop_example/lib/cairnloop_example_web/operator_auth.ex] |
| V5 Input Validation | Yes | Keep `PHX_BIND` allowlist, integer parsing for ports, and string-literal context provider branches with no atom creation from input. [VERIFIED: examples/cairnloop_example/config/dev.exs] [VERIFIED: examples/cairnloop_example/config/runtime.exs] [VERIFIED: examples/cairnloop_example/lib/cairnloop_example/demo_context_provider.ex] |
| V6 Cryptography | Yes for session/editor handoff secrets | Dev/test use fixed local secrets; prod requires env secrets including `SECRET_KEY_BASE` and `CAIRNLOOP_HANDOFF_SECRET_KEY_BASE`. [VERIFIED: examples/cairnloop_example/config/dev.exs] [VERIFIED: examples/cairnloop_example/config/test.exs] [VERIFIED: examples/cairnloop_example/config/runtime.exs] |

### Known Threat Patterns For This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Publishing demo Postgres to host unintentionally | Information Disclosure / Tampering | Keep demo Compose DB private and only publish Phoenix UI on `127.0.0.1`; current `compose.demo.yml` has no DB `ports`. [VERIFIED: examples/cairnloop_example/compose.demo.yml] |
| Environment variable injection into bind IP | Tampering | Keep `PHX_BIND` allowlist to `127.0.0.1` or `0.0.0.0`; reject other values. [VERIFIED: examples/cairnloop_example/config/dev.exs] [VERIFIED: examples/cairnloop_example/config/runtime.exs] |
| Health endpoint leaks internals | Information Disclosure | Current `HealthPlug` returns only `{"status":"ok"}`. [VERIFIED: lib/cairnloop/web/health_plug.ex] |
| Seed rerun duplicate data | Integrity / Repudiation | Natural-key guards and idempotency test keep reruns stable. [VERIFIED: examples/cairnloop_example/priv/repo/seeds.exs] [VERIFIED: examples/cairnloop_example/test/cairnloop_example/seeds_test.exs] |
| Demo notifier sends real external notifications | Information Disclosure / Tampering | Use example-only no-op notifier; do not configure Chimeway delivery unless migrations/adapters are explicitly in scope. [VERIFIED: lib/cairnloop/notifier/chimeway.ex] [VERIFIED: examples/cairnloop_example/deps/chimeway/priv/repo/migrations] |

## Sources

### Primary (HIGH confidence)

- `CLAUDE.md` - decision policy, test lanes, sealed contract guardrails, DB caveat. [VERIFIED: codebase grep]
- `AGENTS.md` and `examples/cairnloop_example/AGENTS.md` - repo/example app constraints and demo validation commands. [VERIFIED: codebase grep]
- `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/ROADMAP.md` - Phase 53 scope, requirements, and guardrails. [VERIFIED: codebase grep]
- `examples/cairnloop_example/mix.exs` - dependency mode, setup/test aliases, migration ordering. [VERIFIED: codebase grep]
- `examples/cairnloop_example/config/*.exs` - DB/env/endpoint/Chimeway runtime config. [VERIFIED: codebase grep]
- `examples/cairnloop_example/compose.demo.yml`, `Dockerfile.demo`, `bin/demo` - Docker runtime contract and health smoke path. [VERIFIED: codebase grep]
- `examples/cairnloop_example/priv/repo/seeds.exs` and `test/cairnloop_example/seeds_test.exs` - Trailmark seed and DB-backed validation contract. [VERIFIED: codebase grep]
- `lib/cairnloop/router.ex`, `lib/cairnloop/web/health_plug.ex`, `lib/cairnloop/web/home_live.ex`, `lib/cairnloop/web/settings_live.ex` - health/operations and dashboard health behavior. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- Ecto SQL `mix ecto.migrate` docs - multiple migration paths and global sorting. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html]
- Mix.Task docs - task run/reenable one-shot semantics. [CITED: https://hexdocs.pm/mix/Mix.Task.html]
- Mix deps docs - Hex/path dependency forms and path dependency recompilation. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Deps.html]
- Phoenix.Router docs - `forward` and pipelines. [CITED: https://hexdocs.pm/phoenix/Phoenix.Router.html]
- Oban docs - `drain_queue/2` synchronous testing behavior and recursion option. [CITED: https://hexdocs.pm/oban/Oban.html]
- Docker Compose docs - `depends_on: condition: service_healthy` and service-name networking. [CITED: https://docs.docker.com/compose/how-tos/startup-order/] [CITED: https://docs.docker.com/compose/how-tos/networking/]

### Tertiary (LOW confidence)

- None. [VERIFIED: sources audit]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions verified from `mix deps`, `mix.lock`, Dockerfile, and local tool probes. [VERIFIED: command output] [VERIFIED: examples/cairnloop_example/mix.lock] [VERIFIED: examples/cairnloop_example/Dockerfile.demo]
- Architecture: HIGH - primary data flow comes from local `mix.exs`, config, router, Dockerfile, Compose, and seed files. [VERIFIED: codebase grep]
- Pitfalls: HIGH - migration-order and notifier/Chimeway pitfalls are grounded in current code and official docs. [VERIFIED: priv/repo/migrations] [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html]
- External docs: MEDIUM - fetched through web search/open against official docs, not Context7 MCP. [CITED: https://hexdocs.pm/ecto_sql/Mix.Tasks.Ecto.Migrate.html] [CITED: https://docs.docker.com/compose/how-tos/startup-order/]

**Research date:** 2026-06-28
**Valid until:** 2026-07-05 for Docker/Phoenix/Oban operational details; local code findings expire on the next relevant file edit. [VERIFIED: research date]
