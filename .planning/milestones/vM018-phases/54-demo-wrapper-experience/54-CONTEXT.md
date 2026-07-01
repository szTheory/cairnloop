# Phase 54: Demo Wrapper Experience - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 54 turns `./bin/demo` into the adopter-facing operational surface for the local Docker demo: start/up, URL reprint, logs, status, stop/down, reset/reseed, and local smoke verification. It must preserve the Phase 53 runtime contract and keep the demo usable from a fresh clone with Docker Compose v2 as the only local runtime prerequisite.

This phase does not own Docker-first narrative docs (Phase 55), CI workflow gating (Phase 56), hosted demos, browser walkthrough automation, or new Cairnloop product behavior.

</domain>

<decisions>
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

### Claude's Discretion
These decisions were auto-ratified under the repo decision policy in `CLAUDE.md`: research and decide normal gray areas, escalating only very impactful irreversible calls. No such escalation was identified for Phase 54.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Scope
- `.planning/ROADMAP.md` - Phase 54 goal, success criteria, guardrails, and neighboring phase boundaries.
- `.planning/REQUIREMENTS.md` - BOOT-01 through BOOT-04 and VER-01 through VER-02 are the locked Phase 54 requirements.
- `.planning/PROJECT.md` - vM018 milestone posture: adoption/DX hardening only, no new product-surface work.
- `CLAUDE.md` - repo decision policy and build/test conventions; especially the GSD discuss-phase instruction to auto-decide non-very-impactful gray areas.

### Runtime Contract From Phase 53
- `.planning/phases/53-demo-runtime-contract/53-PATTERNS.md` - reusable patterns for Compose, Dockerfile, health route, seeds, docs, and wrapper command names.
- `.planning/phases/53-demo-runtime-contract/53-VERIFICATION.md` - evidence that Phase 53 runtime setup, health, seeds, and existing `./bin/demo smoke` passed.

### Wrapper And Demo Code
- `bin/demo` - current wrapper command surface, dynamic URL discovery, health wait, smoke route list, and failure-log behavior.
- `examples/cairnloop_example/compose.demo.yml` - private pgvector DB, localhost web port publishing, healthcheck, named volumes, and environment contract.
- `examples/cairnloop_example/Dockerfile.demo` - Docker-only Elixir runtime path and `mix setup && exec mix phx.server` command.
- `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` - mounted demo index, chat, dashboard, and `/health` routes that the wrapper/smoke checks.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bin/demo`: Already provides most required commands and should be hardened in place rather than replaced.
- `examples/cairnloop_example/compose.demo.yml`: Already uses a private `db` service, dynamic localhost web port publishing, named volumes, and `/health` readiness.
- `examples/cairnloop_example/Dockerfile.demo`: Already proves fresh-clone Docker execution without local Elixir by installing Elixir tooling inside the image and running `mix setup`.
- `examples/cairnloop_example/lib/cairnloop_example_web/router.ex`: Provides the route inventory that smoke should treat as canonical for this phase.

### Established Patterns
- Phase 53 setup runs host migrations before Cairnloop library migrations, then seeds Trailmark data. Phase 54 must not weaken that by bypassing `mix setup`.
- Demo config uses `PGHOST`/`PGPORT`/`PGUSER`/`PGPASSWORD`/`PGDATABASE`, `PORT`, and `PHX_BIND` for dev/Docker. Do not switch the demo path to `DATABASE_URL`.
- Health readiness is route-based via `Cairnloop.Router.cairnloop_operations()` and Compose healthchecks, not log scraping.
- DB-backed or Docker-dependent checks should be explicit and targeted; the repo still expects `mix compile --warnings-as-errors` and `mix ci.fast` before declaring headless work done.

### Integration Points
- Wrapper changes connect through `bin/demo`, Compose project/environment variables, and `examples/cairnloop_example/compose.demo.yml`.
- Smoke route coverage connects to `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` and the dashboard macro-mounted routes under `/support`.
- Failure diagnostics connect to `docker compose logs --tail=80 web` today; planners may centralize this in a helper if it keeps output clearer.

</code_context>

<specifics>
## Specific Ideas

- Treat the wrapper as an adopter product surface: terse, calm, exact commands and URLs.
- Keep the route smoke deliberately smaller than browser E2E; Phase 56 owns CI gating and future expansion.
- Preserve environment overrides for maintainers (`CAIRNLOOP_WEB_PORT`, `CAIRNLOOP_SMOKE_WEB_PORT`, `CAIRNLOOP_BIND_HOST`, `CAIRNLOOP_COMPOSE_PROJECT`, `OPENAI_API_KEY`) while keeping first-run success credential-free.

</specifics>

<deferred>
## Deferred Ideas

- Full browser walkthrough command - deferred to future DEMO-01.
- Screenshot refresh from Docker demo - deferred to future DEMO-02.
- Hosted public demo environment - deferred to future DEMO-03.
- CI smoke workflow and path filters - Phase 56.
- Docker-first README/Quickstart/example README/troubleshooting narrative - Phase 55.

</deferred>

---

*Phase: 54-Demo Wrapper Experience*
*Context gathered: 2026-06-28*
