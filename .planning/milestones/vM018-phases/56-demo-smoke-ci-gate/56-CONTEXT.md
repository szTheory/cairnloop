# Phase 56: Demo Smoke CI Gate - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 56 makes the Docker demo smoke path a CI-enforced adoption proof. The phase owns GitHub
Actions wiring and automated verification around the already-shipped `./bin/demo smoke` command:
manual runs, scheduled runs, relevant path-change runs, realistic timeout behavior, and no human
UAT checkpoint.

This phase does not own new wrapper behavior, a changed smoke route list, broad docs narrative work,
hosted demos, full browser walkthrough automation, screenshot refresh tooling, release publishing
state, or new Cairnloop product/UI behavior. Phase 53 owns the example runtime contract, Phase 54
owns the wrapper and route smoke behavior, and Phase 55 owns the Docker-first adopter docs.

</domain>

<decisions>
## Implementation Decisions

### CI Workflow Shape
- **D-01:** Use a separate `.github/workflows/demo-smoke.yml` workflow for the Docker demo smoke
  lane. Do not fold this into `release-please.yml`, `publish-hex`, or release mutation steps.
- **D-02:** The workflow should be runnable through `workflow_dispatch`, on a weekly schedule, on
  pushes to `main`/`master`, and on pull requests that touch relevant files. The current draft
  workflow already has manual/scheduled/push coverage; planners should add PR coverage if it is
  still missing.
- **D-03:** Keep the job deliberately small: `ubuntu-latest`, `permissions: contents: read`, a
  stable `demo-smoke` job/check name, Docker/Compose version preflight, and `./bin/demo smoke`.
  Preserve the repo's `ACTIONS_RUNNER_NODE_VERSION: "24"` convention for action compatibility.
- **D-04:** Keep the workflow separate from release publishing so demo drift fails loudly without
  mutating release state. Branch-protection requirements are external to the repo, but the workflow
  should expose a stable check that can be required later.

### Path Filters
- **D-05:** Path filters should cover all files that can break the demo path: `.dockerignore`,
  `bin/demo`, `examples/cairnloop_example/**`, `.github/workflows/demo-smoke.yml`, `README.md`,
  `guides/**`, root runtime/package files (`mix.exs`, `mix.lock`, `config/**`), and the core library
  paths the example app consumes through its local path dependency (`lib/**`, `priv/**`).
- **D-06:** Do not trigger the Docker smoke lane for planning-only artifacts such as
  `.planning/**`, unless a future workflow explicitly needs planning artifact validation.
- **D-07:** Treat `examples/cairnloop_example/**` as intentionally broad: it covers
  `compose.demo.yml`, `Dockerfile.demo`, example runtime config, seeds, README, tests, and static
  assets that can affect first-run demo behavior.

### Smoke Command Contract
- **D-08:** The CI job must run the canonical wrapper command, `./bin/demo smoke`. Do not duplicate
  the wrapper as raw `docker compose` commands in YAML; `bin/demo` remains the source of truth for
  isolated project naming, dynamic port selection, health wait, route list, diagnostics, and cleanup.
- **D-09:** Do not require OpenAI credentials, Hex publishing credentials, release tokens, or any
  other external secret for the smoke workflow. The smoke path must remain credential-free.
- **D-10:** Use a realistic bounded timeout. The existing draft uses `timeout-minutes: 25`, which is
  acceptable as the starting contract. Increase only if CI evidence shows a clean first-run Docker
  smoke regularly needs more time.
- **D-11:** Failure output should rely first on `./bin/demo smoke` naming the failing route/readiness
  URL and printing recent web logs. Artifact upload is optional, but it must not replace inline
  actionable logs.

### Automated Verification
- **D-12:** Add or extend a DB-free source contract test in the root `mix ci.fast` lane to pin the
  workflow contract: trigger set, relevant path filters, timeout, `contents: read`, and exact
  `./bin/demo smoke` command. This mirrors the existing `test/cairnloop/demo_wrapper_contract_test.exs`
  pattern and catches YAML drift without starting Docker.
- **D-13:** Final Phase 56 verification must include `mix ci.fast`, GitHub workflow source validation
  (via the contract test and/or YAML parsing), and `./bin/demo smoke` when Docker is available in the
  workspace. If the executor cannot run Docker locally, it must record the environmental blocker and
  still provide source-level workflow proof.
- **D-14:** No human UAT checkpoint belongs in this phase. If a planner decides browser-rendered
  behavior needs new proof, it must be automated through the existing example app E2E lane or another
  automated browser check, not owner verification.

### Existing Draft Handling
- **D-15:** At context time, `.github/workflows/demo-smoke.yml` and `.dockerignore` exist as
  working-tree draft files. Downstream agents should inspect and preserve useful work in those files,
  harden it to the decisions above, and avoid discarding unrelated user changes.

### Claude's Discretion
These decisions were auto-ratified under the repo decision policy in `CLAUDE.md`: research and decide
normal gray areas, escalating only very impactful irreversible calls. No such escalation was
identified for Phase 56.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Scope
- `.planning/ROADMAP.md` - Phase 56 goal, success criteria, guardrails, and neighboring phase
  boundaries.
- `.planning/REQUIREMENTS.md` - VER-03 and VER-04 are the locked Phase 56 requirements.
- `.planning/PROJECT.md` - vM018 posture: Docker/demo DX adoption proof only, no new product-surface
  work.
- `CLAUDE.md` - repo decision policy, build/test conventions, and GSD discuss instruction to
  auto-decide non-very-impactful gray areas.

### Prior Phase Contracts
- `.planning/phases/54-demo-wrapper-experience/54-CONTEXT.md` - locked wrapper command surface,
  route list, dynamic URL discovery, failure diagnostics, smoke isolation, and Phase 56 boundary.
- `.planning/phases/54-demo-wrapper-experience/54-VERIFICATION.md` - proof that wrapper commands,
  dynamic ports, route smoke, cleanup, and diagnostics passed.
- `.planning/phases/55-docker-first-adopter-docs/55-CONTEXT.md` - locked Docker-first docs boundary
  and Phase 56 CI-smoke handoff.
- `.planning/phases/55-docker-first-adopter-docs/55-VERIFICATION.md` - proof that adopter docs align
  to `./bin/demo`, printed URLs, optional OpenAI credentials, and smoke docs.
- `.planning/phases/53-demo-runtime-contract/53-PATTERNS.md` - reusable runtime patterns for
  example setup, Compose, Dockerfile, health route, seeds, and wrapper command names.
- `.planning/phases/53-demo-runtime-contract/53-VERIFICATION.md` - proof that runtime setup,
  `/health`, seeds, Compose config, and `./bin/demo smoke` passed.

### Workflow And Demo Code
- `.github/workflows/demo-smoke.yml` - draft/new dedicated Docker demo smoke workflow.
- `.github/workflows/ci.yml` - existing GitHub Actions conventions, `ACTIONS_RUNNER_NODE_VERSION`,
  CI job naming, and release-gate pattern to avoid conflating with demo smoke.
- `.github/workflows/release-please.yml` - release publishing workflow that Phase 56 must not mutate
  for demo smoke proof.
- `.dockerignore` - Docker build context exclusions that affect clean demo smoke behavior.
- `bin/demo` - canonical wrapper command, smoke route list, isolated Compose namespace, timeout/log
  diagnostics, health wait, and cleanup.
- `test/cairnloop/demo_wrapper_contract_test.exs` - DB-free source contract pattern to reuse for a
  workflow contract test.
- `examples/cairnloop_example/compose.demo.yml` - private pgvector DB, loopback web publishing,
  healthcheck, named volumes, and optional `OPENAI_API_KEY` environment.
- `examples/cairnloop_example/Dockerfile.demo` - Docker-owned Elixir runtime and `mix setup && exec
  mix phx.server` command.
- `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` - mounted demo index, chat,
  dashboard, and `/health` routes smoke ultimately protects.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.github/workflows/demo-smoke.yml`: Already sketches a separate workflow with
  `workflow_dispatch`, weekly schedule, push path filters, `timeout-minutes: 25`, Docker version
  preflight, and `./bin/demo smoke`. It appears as an untracked working-tree file at context time.
- `bin/demo`: Already provides the canonical smoke command with isolated Compose project naming,
  dynamic port fallback, container-backed `/health` and route checks, recent web logs on failure,
  and cleanup on exit.
- `test/cairnloop/demo_wrapper_contract_test.exs`: Provides a proven DB-free pattern for asserting
  shell/YAML/source contracts in `mix ci.fast`.
- `.github/workflows/ci.yml`: Shows current CI conventions: action permissions are minimized,
  `ACTIONS_RUNNER_NODE_VERSION` is pinned to 24, and release-gating is a separate aggregation job.
- `.dockerignore`: Draft context-exclusion file exists and should be considered part of Docker demo
  CI reliability because it changes what the demo image build sees.

### Established Patterns
- Demo smoke route coverage is intentionally HTTP-level and wrapper-owned, not a full browser E2E
  walkthrough.
- The example app dogfoods the root library via local path dependency, so core `lib/**` and `priv/**`
  changes can break the Docker demo even when example-app files do not change.
- CI source-contract tests should be DB-free and fast; Docker-dependent proof is explicit and
  targeted.
- The repo keeps release publishing in `release-please.yml`/`publish-hex`; demo smoke should not
  receive publishing permissions or release secrets.

### Integration Points
- The workflow connects to GitHub Actions triggers/path filters, Docker/Compose availability on
  `ubuntu-latest`, and `./bin/demo smoke`.
- The smoke command connects to `examples/cairnloop_example/compose.demo.yml`,
  `examples/cairnloop_example/Dockerfile.demo`, the example app route tree, and the root Cairnloop
  library code mounted into the demo container.
- Verification connects to `mix ci.fast` through a source contract test and to Docker through the
  local/CI execution of `./bin/demo smoke`.

</code_context>

<specifics>
## Specific Ideas

- If the existing draft workflow is still present, the most likely hardening gap is adding
  `pull_request` with the same relevant path filters as `push`.
- Prefer a small `DemoSmokeWorkflowContractTest` next to the wrapper contract test rather than a
  broad CI refactor.
- Keep CI copy terse: "Docker versions" then "Run Docker demo smoke" is enough because the wrapper
  owns diagnostics.

</specifics>

<deferred>
## Deferred Ideas

- Full browser walkthrough command - future DEMO-01.
- Screenshot refresh from Docker demo - future DEMO-02.
- Hosted public demo environment - future DEMO-03.
- Branch protection configuration requiring the `demo-smoke` check - repository/host setting outside
  this code phase.

</deferred>

---

*Phase: 56-Demo Smoke CI Gate*
*Context gathered: 2026-06-28*
