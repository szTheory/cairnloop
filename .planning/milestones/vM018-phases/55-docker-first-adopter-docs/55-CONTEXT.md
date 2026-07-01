# Phase 55: Docker-First Adopter Docs - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 55 aligns the adopter-facing documentation around the verified Docker demo path. The root
README, Quickstart, example README, and Troubleshooting guide must tell one consistent story: a
fresh clone starts with `./bin/demo`, Docker Compose owns Elixir and pgvector Postgres, the wrapper
prints the browser URLs, and manual local setup is clearly secondary.

This phase does not own new demo runtime behavior, new wrapper commands, CI workflow wiring, hosted
demos, browser walkthrough automation, screenshot refresh tooling, or new Cairnloop product
surfaces. Phase 53 owns the example runtime contract, Phase 54 owns the wrapper behavior, and Phase
56 owns CI smoke gating.

</domain>

<decisions>
## Implementation Decisions

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

### Claude's Discretion
These decisions were auto-ratified under the repo decision policy in `CLAUDE.md`: research and
decide normal gray areas, escalating only very impactful irreversible calls. No such escalation was
identified for Phase 55.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Scope
- `.planning/ROADMAP.md` - Phase 55 goal, success criteria, guardrails, and Phase 56 boundary.
- `.planning/REQUIREMENTS.md` - DOC-01 through DOC-04 are the locked Phase 55 requirements; VER-03
  and VER-04 remain Phase 56.
- `.planning/PROJECT.md` - vM018 posture: Docker/demo DX adoption proof only, no new product-surface
  work.
- `CLAUDE.md` - repo decision policy, build/test conventions, docs/package quality expectations, and
  GSD discuss instruction to auto-decide non-very-impactful gray areas.

### Prior Phase Contracts
- `.planning/phases/54-demo-wrapper-experience/54-CONTEXT.md` - locked wrapper command surface,
  dynamic URL discovery, failure diagnostics, smoke route list, and deferred Phase 55/56 boundaries.
- `.planning/phases/54-demo-wrapper-experience/54-VERIFICATION.md` - proof that wrapper commands,
  dynamic ports, route smoke, and diagnostics passed.
- `.planning/phases/53-demo-runtime-contract/53-PATTERNS.md` - reusable docs/runtime patterns for
  example setup, Compose, Dockerfile, health route, seeds, and wrapper command names.
- `.planning/phases/53-demo-runtime-contract/53-VERIFICATION.md` - proof that runtime setup,
  `/health`, seeds, Compose config, `mix ci.fast`, `mix ci.integration`, `mix ci.quality`, and
  `./bin/demo smoke` passed in Phase 53.

### Docs To Align
- `README.md` - root adopter entry point and HexDocs README source.
- `guides/01-quickstart.md` - primary Quickstart extra shipped in HexDocs.
- `guides/04-troubleshooting.md` - troubleshooting extra shipped in HexDocs; needs Docker-first
  failure coverage.
- `examples/cairnloop_example/README.md` - example-app README with Docker/manual setup, demo index,
  two-tab demo, screenshots, and routing notes.
- `mix.exs` - docs extras/package file list; confirms README and guides are shipped in docs/package
  and current package version is `0.5.1`.

### Runtime And Wrapper Truth
- `bin/demo` - canonical command names, help text, URL printing, dynamic port range, health wait,
  route smoke, and diagnostics.
- `examples/cairnloop_example/compose.demo.yml` - private pgvector DB, loopback web publishing,
  `OPENAI_API_KEY` optional env, healthcheck, named volumes.
- `examples/cairnloop_example/Dockerfile.demo` - Docker-owned Elixir runtime and `mix setup && exec
  mix phx.server` command.
- `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` - mounted demo index, chat,
  dashboard, and `/health` routes that docs should name.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bin/demo`: Already prints all required URLs, documents command names, validates Docker/Compose,
  waits for `/health`, handles dynamic port fallback, and provides bounded web logs on failures.
- `README.md`: Already starts with a Docker demo section, but should be checked for consistency with
  Quickstart, Troubleshooting, current package version, and Phase 54 command semantics.
- `guides/01-quickstart.md`: Already has a strong Docker-first section and useful command block;
  planners should tighten links into Troubleshooting and keep manual setup secondary.
- `examples/cairnloop_example/README.md`: Already documents Docker first, but still has manual-only
  hard-coded `localhost:4000` examples in the Demo Index, Two-Tab Demo, and Routing sections.
- `guides/04-troubleshooting.md`: Current content is mostly legacy installer, migration, pgvector,
  mount config, Oban, and EditorHandoff issues; it needs the Docker demo failure modes from
  DOC-03.

### Established Patterns
- Phase 53 setup runs host migrations before Cairnloop library migrations and then seeds Trailmark
  data through `mix setup`; docs must not suggest bypassing that in the Docker path.
- Phase 54 established that `./bin/demo` is the single adopter-facing operational surface. Docs
  should reference it rather than raw `docker compose -f examples/...` commands except as advanced
  context.
- Docker Postgres is private to Compose and should not be documented as a host `localhost:5432` or
  `5433` service. Manual local setup is the only path that needs host Postgres or the root
  database-only Compose helper.
- The wrapper normalizes Compose port output and prints browser-safe URLs. Docs should not assume
  fixed host ports for Docker.
- `mix ci.quality` builds docs with warnings as errors. Docs changes should be planned with that
  quality lane, plus `mix ci.fast` as the repo baseline.

### Integration Points
- README and guides are included in package/docs extras through `mix.exs`; docs changes affect
  HexDocs output, not only GitHub.
- Example README lives under `examples/cairnloop_example/` and is adopter-facing for users who enter
  through the example app directory.
- Troubleshooting should cross-link from Quickstart and example README instead of duplicating long
  operational recipes everywhere.

</code_context>

<specifics>
## Specific Ideas

- Make a short "When to use which path" split: Docker demo for evaluation, manual local setup for
  developing the example app directly, Igniter/Host Integration for embedding Cairnloop in a real
  host application.
- In Docker docs, use wording like "open the printed Demo index URL" and "append `/support` or
  `/chat` to the printed base URL" instead of hard-coded `localhost:4000`.
- In Troubleshooting, prefer symptom-driven headings that mirror adopter failures: "Docker is not
  installed", "Docker Compose v2 is missing", "No port was available", "The stack never became
  healthy", "I need a clean database", "Do I need local Postgres or pgvector?", "Do I need an OpenAI
  key?"
- Keep `./bin/demo smoke` described as maintenance proof and local confidence check; Phase 56 will
  decide the GitHub Actions trigger/filter contract.

</specifics>

<deferred>
## Deferred Ideas

- CI smoke workflow and path filters - Phase 56.
- Full browser walkthrough command - future DEMO-01.
- Screenshot refresh from Docker demo - future DEMO-02.
- Hosted public demo environment - future DEMO-03.

</deferred>

---

*Phase: 55-Docker-First Adopter Docs*
*Context gathered: 2026-06-28*
