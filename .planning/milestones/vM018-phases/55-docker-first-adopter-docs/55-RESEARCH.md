# Phase 55: Docker-First Adopter Docs - Research

**Researched:** 2026-06-28
**Domain:** adopter documentation alignment for Docker-first demo workflow
**Confidence:** HIGH for internal planning facts; all recommendations are grounded in locked Phase 55 context, current repo docs, wrapper/runtime source, and Phase 53/54 verification artifacts.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### First-Run Narrative
- **D-01:** Lead every adopter entry point with the Docker demo as the primary evaluation path.
  Root README and `guides/01-quickstart.md` should make `./bin/demo` the first command for someone
  trying Cairnloop from a fresh clone.
- **D-02:** Keep manual local setup, Igniter installation, host integration, and `mix phx.server`
  guidance, but position them after the Docker demo and label them as the manual or production host
  path. Do not present manual setup as equal-weight first-run evaluation guidance.
- **D-03:** Use calm adopter-facing copy. Explain outcomes in terms of "run the demo", "open the
  printed URL", "reset the seeded database", and "view logs"; avoid exposing implementation noise
  as the main story.

### URL And Command Truth
- **D-04:** Treat `./bin/demo` output and `./bin/demo help` as the command and URL source of truth.
  Documentation should not invent command names or route lists that drift from `bin/demo`.
- **D-05:** Docker docs must point users to the URL printed by `./bin/demo`, not hard-coded
  `localhost:4000`. The wrapper discovers the running Compose port and may choose a dynamic
  `4100-4199` localhost port by default.
- **D-06:** Keep `localhost:4000` only where the text is explicitly about the manual local Phoenix
  path (`mix setup && mix phx.server`). Example README sections such as Two-Tab Demo and Routing
  should be made Docker-aware by using "the printed base URL plus `/support` or `/chat`" before
  giving manual-local links.
- **D-07:** Document the wrapper command vocabulary from Phase 54: default `start`/`up`, `urls`,
  `logs`, `status`/`ps`, `stop`, `down`, `reset`, `smoke`, and `help`. Preserve the semantic
  distinction that `stop`/`down` keep volumes and `reset` removes volumes and reseeds.

### Troubleshooting Taxonomy
- **D-08:** Expand `guides/04-troubleshooting.md` with a Docker demo section before legacy
  installation issues. It should cover: Docker unavailable or not on `PATH`, Docker Compose v2
  missing, no available web port or fixed-port conflict, unhealthy stack, reset/reseed need,
  private pgvector Postgres versus manual Postgres confusion, and optional OpenAI credentials.
- **D-09:** Troubleshooting should point first to `./bin/demo logs`, `./bin/demo status`, `./bin/demo
  reset`, and the failing route or health URL. Keep diagnostics bounded and actionable; do not
  encourage users to dump long Compose output as the normal path.
- **D-10:** Make the Postgres split explicit: the Docker demo keeps pgvector private inside Compose
  and needs no host Postgres, while the manual local path needs Postgres 16+ with pgvector and uses
  the root `docker-compose.yml` database helper when desired.

### OpenAI And External Services
- **D-11:** State clearly that `OPENAI_API_KEY` is optional and not required for first-run success,
  route smoke, or clicking through the seeded demo. If present, it may improve semantic embedding
  behavior, but docs must not make external credentials part of the primary success path.
- **D-12:** Keep the credential-free claim scoped to local demo boot and route coverage. Do not imply
  production AI drafting or retrieval in a host app never needs provider configuration.

### Smoke Workflow Documentation
- **D-13:** Document `./bin/demo smoke` as a local, isolated smoke lane that boots its own Compose
  project, checks the main routes, emits failing route plus recent web logs on errors, and cleans up
  containers and volumes afterward.
- **D-14:** Keep smoke docs high-level. It is an HTTP route smoke, not a full browser E2E suite and
  not a replacement for Phase 56 CI workflow wiring.
- **D-15:** Where docs mention route coverage, align to the Phase 54 locked route list: `/`,
  `/support`, `/support/inbox`, `/chat`, `/support/knowledge-base`,
  `/support/knowledge-base/gaps`, `/support/knowledge-base/suggestions`, `/support/audit-log`, and
  `/support/settings`.

### Documentation Scope Control
- **D-16:** Update only the docs necessary for DOC-01 through DOC-04 plus small adjacent copy needed
  to remove contradictions. Do not turn this into a broad docs rewrite, new screenshots pass, new
  examples milestone, or versioning/release-process cleanup.
- **D-17:** If touched dependency snippets still show stale package versions, planners may correct
  them to the current repo version from `mix.exs` when doing so avoids adopter confusion, but this is
  opportunistic cleanup, not a new requirement.

### the agent's Discretion
These decisions were auto-ratified under the repo decision policy in `CLAUDE.md`: research and
decide normal gray areas, escalating only very impactful irreversible calls. No such escalation was
identified for Phase 55.

### Deferred Ideas (OUT OF SCOPE)
- CI smoke workflow and path filters - Phase 56.
- Full browser walkthrough command - future DEMO-01.
- Screenshot refresh from Docker demo - future DEMO-02.
- Hosted public demo environment - future DEMO-03.
</user_constraints>

## Project Constraints (from AGENTS.md)

- Root `AGENTS.md` requires agents to read `CLAUDE.md` first; this research did so. [VERIFIED: AGENTS.md; CLAUDE.md]
- UI work must also read `docs/operator-ui-principles.md` before editing `lib/cairnloop/web/**` or `priv/static/cairnloop.css`; Phase 55 should not edit those UI files. [VERIFIED: AGENTS.md; 55-CONTEXT.md]
- The shipped dashboard uses Cairnloop's tokenized `.cl-*` / BEM CSS system, not Tailwind; this docs phase should not introduce UI styling work. [VERIFIED: AGENTS.md]
- Example-app `AGENTS.md` adds that Docker demo docs must point users to the URL printed by `./bin/demo`; only manual local Phoenix boot assumes `http://localhost:4000`. [VERIFIED: examples/cairnloop_example/AGENTS.md]
- `CLAUDE.md` requires `mix ci.fast` for headless work and `mix ci.quality` for docs/package changes. [VERIFIED: CLAUDE.md]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOC-01 | Adopter sees the Docker demo as the first-run path in README and Quickstart, with manual local setup clearly secondary. | README and Quickstart already lead with `./bin/demo`; planning should tighten consistency, cross-links, command vocabulary, and stale dependency snippets only where touched. [VERIFIED: .planning/REQUIREMENTS.md; README.md; guides/01-quickstart.md; 55-CONTEXT.md] |
| DOC-02 | Adopter can follow the example README without relying on hard-coded Docker ports or stale route names. | Example README still hard-codes `http://localhost:4000/support` and `/chat` in Two-Tab Demo and Routing; planning should make Docker use the printed base URL first, manual local links second. [VERIFIED: .planning/REQUIREMENTS.md; examples/cairnloop_example/README.md; bin/demo] |
| DOC-03 | Adopter can resolve common demo failures from docs: Docker unavailable, Compose v2 missing, port conflict, unhealthy stack, reset/reseed need, and pgvector/manual Postgres confusion. | Troubleshooting currently starts with Igniter and legacy install issues; planning should add a Docker demo section before those issues and point to wrapper diagnostics. [VERIFIED: .planning/REQUIREMENTS.md; guides/04-troubleshooting.md; bin/demo; 55-CONTEXT.md] |
| DOC-04 | Maintainer can explain the smoke workflow and route coverage without requiring an OpenAI API key or external services. | `./bin/demo smoke` route list and isolation are locked by Phase 54; Compose passes `OPENAI_API_KEY` as optional empty default. [VERIFIED: .planning/REQUIREMENTS.md; bin/demo; examples/cairnloop_example/compose.demo.yml; 54-VERIFICATION.md] |
</phase_requirements>

## Research Summary

Phase 55 is a docs alignment phase over already-verified runtime and wrapper behavior; the planner should not create runtime, wrapper, CI, screenshot, or browser-walkthrough tasks. [VERIFIED: 55-CONTEXT.md; .planning/ROADMAP.md; 53-VERIFICATION.md; 54-VERIFICATION.md]

The first-run story should be: from a fresh clone, run `./bin/demo`; Docker Compose supplies Elixir plus private pgvector Postgres; the wrapper waits for `/health`; the adopter opens the printed URL; manual local setup remains secondary for direct example-app development or host integration. [VERIFIED: README.md; guides/01-quickstart.md; bin/demo; compose.demo.yml; Dockerfile.demo]

Primary recommendation: plan three narrow docs slices: README/Quickstart consistency, example README Docker-awareness, and Troubleshooting plus validation. [VERIFIED: 55-CONTEXT.md; current docs drift scan]

### Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| First-run narrative | Documentation / HexDocs | Demo wrapper | README and guides ship through ExDoc/package extras, while `./bin/demo` remains the command and URL source of truth. [VERIFIED: mix.exs; bin/demo] |
| Example-app entry from subdirectory | Documentation | Demo wrapper / router | `examples/cairnloop_example/README.md` must describe the actual routes mounted by the example router without hard-coding Docker ports. [VERIFIED: examples/cairnloop_example/README.md; router.ex; bin/demo] |
| Troubleshooting | Documentation | Wrapper diagnostics | Troubleshooting should route users to `logs`, `status`, `reset`, failing route URLs, and health checks exposed by the wrapper. [VERIFIED: guides/04-troubleshooting.md; bin/demo] |
| Smoke explanation | Documentation | Wrapper / Compose | Docs explain `./bin/demo smoke`; Phase 56 owns CI workflow wiring. [VERIFIED: bin/demo; .planning/ROADMAP.md; 55-CONTEXT.md] |

## Current Documentation Drift

- `README.md` already starts with "Try the live demo first" and uses `./bin/demo`, printed URLs, dynamic ports, `reset`, and `smoke`; remaining planning work is consistency, richer command vocabulary, troubleshooting link text, and opportunistic stale `{:cairnloop, "~> 0.1.0"}` correction if touched. [VERIFIED: README.md; mix.exs; 55-CONTEXT.md]
- `guides/01-quickstart.md` already has the strongest Docker-first flow, including `./bin/demo`, printed URLs, private Postgres, dynamic port range, `urls`, `logs`, `stop`, `reset`, `smoke`, fixed-port override, and manual prerequisites marked secondary. [VERIFIED: guides/01-quickstart.md]
- Quickstart drift: its command block omits `status`/`ps`, `down`, and `help`; its Docker troubleshooting subsection is brief; its final Troubleshooting link still frames the guide as install/migration/pgvector help rather than Docker demo failure recovery. [VERIFIED: guides/01-quickstart.md; bin/demo; 55-CONTEXT.md]
- `examples/cairnloop_example/README.md` is Docker-first at setup, but Two-Tab Demo still tells users to run `mix setup && mix phx.server` and hard-codes `http://localhost:4000/support` and `http://localhost:4000/chat`; Routing also hard-codes those links. [VERIFIED: examples/cairnloop_example/README.md]
- Example README command drift: it lists `urls`, `logs`, `stop`, `reset`, and `smoke`, but not `start`/`up`, `status`/`ps`, `down`, or `help`, and it does not explain stop/down/reset volume semantics. [VERIFIED: examples/cairnloop_example/README.md; bin/demo; 55-CONTEXT.md]
- `guides/04-troubleshooting.md` currently starts with Igniter prerequisites and legacy install/migration topics; it has no Docker demo section before those topics. [VERIFIED: guides/04-troubleshooting.md; 55-CONTEXT.md]
- Troubleshooting drift: it does not yet cover Docker missing, Compose v2 missing, no available web port or fixed-port conflict, unhealthy stack, wrapper `status`, wrapper `reset`, optional OpenAI credentials, or the private Docker Postgres versus manual Postgres split as first-run demo issues. [VERIFIED: guides/04-troubleshooting.md; bin/demo; compose.demo.yml; 55-CONTEXT.md]
- `mix.exs` ships README and `guides/01-quickstart.md` / `guides/04-troubleshooting.md` in package/docs extras, so those edits affect HexDocs and package quality gates, not only GitHub rendering. [VERIFIED: mix.exs]

## Wrapper/Runtime Facts to Preserve

- `./bin/demo` is the canonical adopter command surface; documented commands should match help: default `start`/`up`, `smoke`, `urls`, `logs`, `stop`, `down`, `reset`, `ps`/`status`, and `help`. [VERIFIED: bin/demo; 54-VERIFICATION.md]
- Docker URLs must come from the running Compose service via `docker compose port web 4000`; docs must not assume Docker runs on `localhost:4000`. [VERIFIED: bin/demo; 54-CONTEXT.md; 54-VERIFICATION.md]
- The wrapper default web port is `CAIRNLOOP_WEB_PORT=4100-4199` on `CAIRNLOOP_BIND_HOST=127.0.0.1`, with fixed-port override allowed through `CAIRNLOOP_WEB_PORT`. [VERIFIED: bin/demo; compose.demo.yml]
- Printed route coverage is `/`, `/support`, `/support/inbox`, `/chat`, `/support/knowledge-base`, `/support/knowledge-base/gaps`, `/support/knowledge-base/suggestions`, `/support/audit-log`, `/support/settings`, and `/health`. [VERIFIED: bin/demo; router.ex; 54-VERIFICATION.md]
- `stop` preserves named volumes; `down` removes containers/network while preserving volumes; `reset` runs `compose down -v --remove-orphans` and then rebuilds/reseeds through `start_demo`. [VERIFIED: bin/demo; 55-CONTEXT.md]
- `./bin/demo smoke` runs in an isolated Compose project namespace, checks the locked HTTP route list, emits the failing route plus recent web logs on failure, and cleans up containers and volumes on exit. [VERIFIED: bin/demo; 54-VERIFICATION.md]
- The Docker demo's `db` service uses `pgvector/pgvector:pg16` without host port publishing; the app connects to `db:5432` inside Compose. [VERIFIED: compose.demo.yml; 54-VERIFICATION.md]
- The Docker demo's `web` service publishes only Phoenix on loopback and waits on `/health`; `/health` is mounted outside the browser pipeline through `cairnloop_operations()`. [VERIFIED: compose.demo.yml; router.ex; 53-VERIFICATION.md]
- `Dockerfile.demo` owns the Elixir runtime and starts the app with `mix setup && exec mix phx.server`; docs should not suggest bypassing `mix setup` in Docker. [VERIFIED: Dockerfile.demo; 53-PATTERNS.md]
- `OPENAI_API_KEY` is optional in Compose via `${OPENAI_API_KEY:-}` and appears in wrapper help as optional semantic embeddings; docs should not make it a first-run prerequisite. [VERIFIED: compose.demo.yml; bin/demo; 55-CONTEXT.md]

## Recommended Planning Shape

| Plan | Scope | Key Edits | Verification |
|------|-------|-----------|--------------|
| 55-01 README + Quickstart consistency | Root README and `guides/01-quickstart.md` | Keep Docker demo first; add/align full wrapper vocabulary where useful; ensure manual/Igniter/local paths stay secondary; update touched stale `~> 0.1.0` snippets to current `0.5.1` only if needed to avoid adopter confusion. [VERIFIED: README.md; guides/01-quickstart.md; mix.exs; 55-CONTEXT.md] | Markdown review, targeted grep for Docker hard-coded localhost, `mix ci.fast`, `mix ci.quality`. [VERIFIED: CLAUDE.md; mix.exs] |
| 55-02 Example README Docker-aware flows | `examples/cairnloop_example/README.md` | Make Demo Index, Two-Tab Demo, and Routing use "printed base URL plus `/support` or `/chat`" for Docker before manual `localhost:4000` links; add command semantics for `status`/`ps`, `down`, `help`, reset/logs. [VERIFIED: examples/cairnloop_example/README.md; bin/demo; examples/cairnloop_example/AGENTS.md] | Targeted grep verifies `localhost:4000` remains only in manual-local context; optional `./bin/demo help`. [VERIFIED: bin/demo] |
| 55-03 Troubleshooting + smoke docs | `guides/04-troubleshooting.md` plus small cross-links | Add symptom-first Docker demo section before Igniter/manual issues; cover Docker missing, Compose v2 missing, port conflicts, unhealthy stack, reset/reseed, private Docker Postgres versus manual Postgres, optional OpenAI, and `./bin/demo smoke` route coverage. [VERIFIED: guides/04-troubleshooting.md; bin/demo; compose.demo.yml; 55-CONTEXT.md] | `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet`, `./bin/demo help`, `timeout 300s ./bin/demo smoke` if Docker remains available, `mix ci.fast`, `mix ci.quality`. [VERIFIED: local environment probe; CLAUDE.md; 53-VERIFICATION.md; 54-VERIFICATION.md] |

Do not hand-roll a second command reference, raw Compose recipe, Makefile path, or route table as the primary docs source; link narrative to `./bin/demo` and mirror only the stable vocabulary/route list already locked by Phase 54. [VERIFIED: 54-CONTEXT.md; bin/demo]

No external packages are required for this phase, so package legitimacy audit is not applicable. [VERIFIED: phase scope; current repo docs]

## Validation Architecture

Nyquist validation is enabled because `.planning/config.json` does not set `workflow.nyquist_validation` to `false`. [VERIFIED: .planning/config.json]

### Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Docker | Compose config and optional smoke validation | yes | Docker 29.5.2 | If Docker is unavailable during execution, still run docs/package gates and mark smoke as blocked with environment output. [VERIFIED: local environment probe] |
| Docker Compose | `./bin/demo`, Compose config, smoke validation | yes | Compose v5.1.3 | None for smoke; docs edits can still be reviewed without smoke. [VERIFIED: local environment probe; bin/demo] |
| Elixir/Mix | `mix ci.fast`, `mix ci.quality`, docs build | yes | Elixir 1.19.5 / Mix 1.19.5 | None. [VERIFIED: local environment probe; mix.exs] |

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit plus Mix aliases for `ci.fast` and `ci.quality`. [VERIFIED: mix.exs] |
| Existing docs/package gate | `mix ci.quality` runs compile, Credo, `mix hex.build`, and `mix docs --warnings-as-errors`. [VERIFIED: mix.exs] |
| Quick run command | `mix ci.fast`. [VERIFIED: CLAUDE.md; mix.exs] |
| Full docs/package command | `mix ci.quality`. [VERIFIED: CLAUDE.md; mix.exs] |
| Existing wrapper contract test | `test/cairnloop/demo_wrapper_contract_test.exs`. [VERIFIED: test file discovery; 54-VERIFICATION.md] |

### Phase Requirements to Validation Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| DOC-01 | README and Quickstart lead with Docker demo and keep manual setup secondary. | docs/package + targeted grep | `mix ci.fast && mix ci.quality`; targeted review of README and Quickstart ordering. [VERIFIED: CLAUDE.md; mix.exs] | Existing docs files yes; no dedicated docs consistency test yet. [VERIFIED: file scan] |
| DOC-02 | Example README avoids Docker hard-coded ports and stale route names. | targeted grep + docs review | `rg -n "localhost:4000" examples/cairnloop_example/README.md` should leave only manual-local contexts after edits. [VERIFIED: current drift scan] | Example README yes; no dedicated docs consistency test yet. [VERIFIED: file scan] |
| DOC-03 | Troubleshooting covers common Docker demo failure modes. | docs/package + checklist | `mix ci.quality`; review section headings for Docker missing, Compose v2 missing, port conflict, unhealthy stack, reset, Postgres split. [VERIFIED: 55-CONTEXT.md; guides/04-troubleshooting.md] | Troubleshooting guide yes. [VERIFIED: mix.exs; file scan] |
| DOC-04 | Smoke workflow and route coverage are explained without requiring OpenAI or external services. | wrapper smoke + docs/package | `./bin/demo help`; `timeout 300s ./bin/demo smoke` if Docker is available; `mix ci.quality`. [VERIFIED: bin/demo; local environment probe; 54-VERIFICATION.md] | Wrapper and docs files yes. [VERIFIED: file scan] |

### Wave 0 Gaps

- No dedicated docs consistency test currently guards "Docker docs must not hard-code `localhost:4000`"; planner can either add a small DB-free ExUnit source scan or require explicit `rg` checks in final verification. [VERIFIED: test file discovery; current drift scan]
- No dedicated docs consistency test currently compares smoke route mentions against `bin/demo`; planner should at least require `./bin/demo help` and `./bin/demo smoke` in final verification if the docs enumerate route coverage. [VERIFIED: test file discovery; bin/demo]

## Risks and Guardrails

- Do not modify `bin/demo`, `compose.demo.yml`, `Dockerfile.demo`, router routes, seeds, runtime config, or CI workflow as part of Phase 55 unless a docs statement is impossible to make true without surfacing a blocking contradiction; current evidence does not show such a blocker. [VERIFIED: 55-CONTEXT.md; 53-VERIFICATION.md; 54-VERIFICATION.md]
- Do not implement Phase 56 CI smoke workflow, path filters, or scheduled/manual workflow wiring in this phase. [VERIFIED: .planning/ROADMAP.md; 55-CONTEXT.md]
- Do not require host Elixir, host Postgres, pgvector, `mix setup`, or `mix phx.server` for the Docker first-run path. [VERIFIED: README.md; guides/01-quickstart.md; compose.demo.yml; Dockerfile.demo]
- Do not imply production AI drafting or retrieval works without provider configuration; credential-free claims must stay scoped to local demo boot, route smoke, and seeded click-through. [VERIFIED: 55-CONTEXT.md; compose.demo.yml; bin/demo]
- Do not encourage normal users to run raw `docker compose -f examples/...` commands as the main path; wrapper commands are the adopter-facing surface. [VERIFIED: 54-CONTEXT.md; bin/demo]
- Keep copy calm and outcome-focused; avoid leading with implementation noise such as container internals, raw Compose output, or Elixir stack traces. [VERIFIED: CLAUDE.md; 55-CONTEXT.md]
- Respect the dirty worktree: many unrelated files were modified or untracked before this research, so the executor must preserve unrelated changes and commit only scoped Phase 55 work. [VERIFIED: git status]

### Security Domain

This docs phase adds no authentication, session management, access control, cryptography, or data-validation code; security-sensitive planning is limited to avoiding misleading secret guidance and not encouraging users to paste long logs or credentials into normal troubleshooting. [VERIFIED: 55-CONTEXT.md; current scope]

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | No auth behavior changes. [VERIFIED: phase scope] |
| V3 Session Management | no | No session behavior changes. [VERIFIED: phase scope] |
| V4 Access Control | no | No route or policy behavior changes. [VERIFIED: phase scope] |
| V5 Input Validation | no code change | Keep docs bounded to wrapper commands and avoid instructing raw env/secret dumps. [VERIFIED: 55-CONTEXT.md] |
| V6 Cryptography | no | No cryptography behavior changes. [VERIFIED: phase scope] |

## Sources

Primary sources read and used:

- `.planning/phases/55-docker-first-adopter-docs/55-CONTEXT.md` - locked Phase 55 decisions, scope, boundaries, and deferred items.
- `.planning/REQUIREMENTS.md` - DOC-01 through DOC-04 requirement text.
- `.planning/ROADMAP.md` and `.planning/STATE.md` - vM018 phase boundaries and project state.
- `CLAUDE.md`, `AGENTS.md`, `examples/cairnloop_example/AGENTS.md` - project and nested constraints.
- `README.md`, `guides/01-quickstart.md`, `guides/04-troubleshooting.md`, `examples/cairnloop_example/README.md` - current docs drift.
- `mix.exs` - docs/package extras and validation aliases.
- `bin/demo`, `examples/cairnloop_example/compose.demo.yml`, `examples/cairnloop_example/Dockerfile.demo`, `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` - wrapper/runtime truth.
- `.planning/phases/53-demo-runtime-contract/53-PATTERNS.md`, `53-VERIFICATION.md`, `54-CONTEXT.md`, `54-VERIFICATION.md` - sealed runtime/wrapper patterns and proof.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| None | All planning recommendations are based on current repo files or locked phase artifacts read during this session. | All sections | None identified. |
