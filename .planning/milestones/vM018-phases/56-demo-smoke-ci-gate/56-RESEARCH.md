# Phase 56: Demo Smoke CI Gate - Research

**Researched:** 2026-06-28
**Domain:** GitHub Actions CI, Docker Compose demo smoke, ExUnit source-contract testing
**Confidence:** HIGH

## User Constraints (from CONTEXT.md)

Source: `.planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md` [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]

### Locked Decisions

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

### the agent's Discretion

### Claude's Discretion
These decisions were auto-ratified under the repo decision policy in `CLAUDE.md`: research and decide
normal gray areas, escalating only very impactful irreversible calls. No such escalation was
identified for Phase 56.

### Deferred Ideas (OUT OF SCOPE)

## Deferred Ideas

- Full browser walkthrough command - future DEMO-01.
- Screenshot refresh from Docker demo - future DEMO-02.
- Hosted public demo environment - future DEMO-03.
- Branch protection configuration requiring the `demo-smoke` check - repository/host setting outside
  this code phase.

## Project Constraints (from AGENTS.md)

- Read `CLAUDE.md` before project work; this research did so. [VERIFIED: AGENTS.md] [VERIFIED: CLAUDE.md]
- For UI work, also read `docs/operator-ui-principles.md` before editing `lib/cairnloop/web/**` or `priv/static/cairnloop.css`; Phase 56 is CI/test workflow work and does not require UI edits. [VERIFIED: AGENTS.md] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
- Shipped dashboard UI uses tokenized `.cl-*` / BEM CSS, not Tailwind; Phase 56 should not touch adopter-facing UI. [VERIFIED: AGENTS.md] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
- Warnings-clean builds are mandatory, and headless work must run `mix ci.fast` before completion. [VERIFIED: CLAUDE.md]
- Docker adoption validation should use `./bin/demo smoke` from the repository root. [VERIFIED: examples/cairnloop_example/AGENTS.md] [VERIFIED: bin/demo]
- Browser-rendered behavior must be verified by automated E2E, never human UAT; Phase 56 should not plan a human verification checkpoint. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
- No project-local skills were found under `.claude/skills/` or `.agents/skills/`. [VERIFIED: find .claude/skills .agents/skills -maxdepth 2 -name SKILL.md]

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VER-03 | CI runs the Docker demo smoke lane for changes that can break the demo wrapper, Compose/Dockerfile contract, example runtime, first-run docs, or the smoke workflow. [VERIFIED: .planning/REQUIREMENTS.md] | Use the dedicated `.github/workflows/demo-smoke.yml` workflow, add `pull_request`, and align `push` and `pull_request` `paths` with D-05. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax] |
| VER-04 | Demo verification remains automated; no human UAT checkpoint is required for first-run, route, or browser-rendered behavior. [VERIFIED: .planning/REQUIREMENTS.md] | Add a DB-free workflow contract test in `mix ci.fast` and require `./bin/demo smoke`; if rendered browser behavior is newly claimed, use the existing example E2E lane, not owner UAT. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [VERIFIED: test/cairnloop/demo_wrapper_contract_test.exs] [VERIFIED: .planning/STATE.md] |

## Summary

Phase 56 should harden the existing draft workflow rather than create a new CI shape. The draft `.github/workflows/demo-smoke.yml` already has `workflow_dispatch`, weekly `schedule`, `push` on `main`/`master`, `permissions: contents: read`, `ACTIONS_RUNNER_NODE_VERSION: "24"`, a stable `demo-smoke` job name, `timeout-minutes: 25`, Docker/Compose version preflight, and `./bin/demo smoke`. [VERIFIED: .github/workflows/demo-smoke.yml] The missing implementation pieces are `pull_request` coverage and the D-05 path filters for `mix.exs`, `mix.lock`, `config/**`, `lib/**`, and `priv/**`. [VERIFIED: .github/workflows/demo-smoke.yml] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]

The right verification pattern is an ExUnit source-contract test in the root `mix ci.fast` lane. Existing tests already use DB-free source scans for the demo wrapper and Docker-first docs, reading files with `File.read!/1`, checking exact command/path contracts, and avoiding Docker, Repo, Phoenix, or browser startup. [VERIFIED: test/cairnloop/demo_wrapper_contract_test.exs] [VERIFIED: test/cairnloop/docs/docker_first_docs_test.exs] This keeps workflow drift cheap to catch while reserving the actual Docker proof for `./bin/demo smoke`. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [VERIFIED: bin/demo]

**Primary recommendation:** Update `.github/workflows/demo-smoke.yml` in place, add `test/cairnloop/demo_smoke_workflow_contract_test.exs`, then verify with `mix ci.fast`, `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet`, and `./bin/demo smoke` when Docker is available. [VERIFIED: .github/workflows/demo-smoke.yml] [VERIFIED: mix.exs] [VERIFIED: examples/cairnloop_example/compose.demo.yml] [VERIFIED: bin/demo]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Triggering demo smoke on relevant changes | CI Orchestration | Source contract test | GitHub Actions owns event triggers and path filters; ExUnit pins the workflow source so future edits cannot silently drift. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax] [VERIFIED: test/cairnloop/demo_wrapper_contract_test.exs] |
| Running the demo smoke behavior | Script / Wrapper | Docker / Example runtime | `./bin/demo smoke` owns Compose project isolation, dynamic port selection, health wait, route checks, diagnostics, and cleanup. [VERIFIED: bin/demo] |
| Building and serving the example demo | Docker / Example runtime | Phoenix example app | Compose builds `examples/cairnloop_example/Dockerfile.demo`, keeps Postgres private, publishes Phoenix on loopback, and health-checks `/health`. [VERIFIED: examples/cairnloop_example/compose.demo.yml] [VERIFIED: examples/cairnloop_example/Dockerfile.demo] |
| Preventing release-state mutation | CI Orchestration | Release workflow boundary | Demo smoke belongs in a separate read-only workflow; release publishing remains in `release-please.yml` with write/publish permissions and secrets. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [VERIFIED: .github/workflows/release-please.yml] |
| Proving no human UAT checkpoint | Verification planning | Example E2E only if needed | Existing project policy requires automated browser evidence for rendered behavior and forbids human UAT checkpoints for this phase. [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |

## Standard Stack

### Core

| Library / Platform | Version | Purpose | Why Standard |
|--------------------|---------|---------|--------------|
| GitHub Actions workflow YAML | Current GitHub workflow syntax docs as of 2026-06-28 | Define `.github/workflows/demo-smoke.yml` events, permissions, concurrency, runner, timeout, and steps. | The repo already uses GitHub Actions for `ci.yml` and `release-please.yml`, and GitHub documents workflow files in `.github/workflows`. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: .github/workflows/release-please.yml] [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax] |
| `actions/checkout` | `v4` | Check out repository source before running `./bin/demo smoke`. | Existing repo workflows use `actions/checkout@v4`, and the demo smoke draft already uses it. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: .github/workflows/demo-smoke.yml] |
| GitHub-hosted `ubuntu-latest` runner | Current runner image maps to Ubuntu 24.04 in official runner-images docs; local runner not applicable | Run Docker/Compose smoke in CI. | The draft and repo workflows already use `ubuntu-latest`; official runner image docs list Docker client/server and Docker Compose on Ubuntu 24.04. [VERIFIED: .github/workflows/demo-smoke.yml] [VERIFIED: .github/workflows/ci.yml] [CITED: https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md] |
| Docker Compose CLI | Local: Docker 29.5.2, Compose v5.1.3; current GitHub Ubuntu 24.04 image docs list Docker Compose 2.38.2 and Docker 28.0.4 | Build/start the example demo stack through `bin/demo`. | `bin/demo` calls `docker compose`, and Docker CLI reference documents the current `docker compose` command family. [VERIFIED: docker --version] [VERIFIED: docker compose version] [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/] |
| Elixir / Mix / ExUnit | Local: Elixir 1.19.5, Mix 1.19.5; CI fast job pins Elixir 1.19.5 and OTP 27.2 | Run the DB-free workflow contract test in `mix ci.fast`. | The repo's fast CI lane is `mix ci.fast`, and existing source-contract tests are ExUnit tests under `test/cairnloop`. [VERIFIED: mix --version] [VERIFIED: .github/workflows/ci.yml] [VERIFIED: mix.exs] |
| `./bin/demo smoke` | Project wrapper command | Canonical smoke entry point for Docker demo proof. | The wrapper owns Docker prerequisites, Compose file selection, isolation, route checks, diagnostics, and cleanup; context forbids duplicating raw Compose commands in workflow YAML. [VERIFIED: bin/demo] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `docker compose config --quiet` | Local Compose v5.1.3 | Source/config sanity check for Compose syntax before full smoke. | Use during phase verification and troubleshooting; prior phases used this as a fast Compose contract proof. [VERIFIED: docker compose version] [VERIFIED: .planning/phases/53-demo-runtime-contract/53-VERIFICATION.md] [VERIFIED: .planning/phases/55-docker-first-adopter-docs/55-VERIFICATION.md] |
| Example app E2E lane | Existing `mix test.e2e` | Automated browser proof if the planner adds any rendered-browser claim. | Use only if Phase 56 changes or claims browser-rendered behavior; otherwise `./bin/demo smoke` is the route-level proof. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: .planning/STATE.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Dedicated `demo-smoke.yml` workflow | Fold smoke into `ci.yml` or `release-please.yml` | Rejected by locked decisions because demo proof must fail loudly without mutating release state. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |
| `./bin/demo smoke` in YAML | Inline raw `docker compose` steps | Rejected because the wrapper is the source of truth for isolation, ports, diagnostics, and cleanup. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [VERIFIED: bin/demo] |
| Source-contract test | Add a YAML parser dependency only for this test | Not recommended because the repo already uses DB-free source contract tests and Phase 56 does not need a new external package. [VERIFIED: test/cairnloop/demo_wrapper_contract_test.exs] [VERIFIED: mix.exs] |
| Human UAT checkpoint | Owner manual verification | Rejected by requirements and project policy; automation is required for smoke/browser evidence. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/STATE.md] |

**Installation:**

```bash
# No external package install is recommended for Phase 56.
```

**Version verification:** Docker, Docker Compose, Elixir, Mix, GitHub CLI, Node, and npm were probed locally; Docker and Compose are available locally, and GitHub's current Ubuntu 24.04 runner image docs list Docker/Compose in the runner image. [VERIFIED: docker --version] [VERIFIED: docker compose version] [VERIFIED: elixir --version] [VERIFIED: mix --version] [CITED: https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md]

## Package Legitimacy Audit

No new external packages are recommended or required for this phase, so the package-legitimacy gate is not applicable. [VERIFIED: mix.exs] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| None | N/A | N/A | N/A | N/A | N/A | No install |

**Packages removed due to [SLOP] verdict:** none. [VERIFIED: mix.exs]
**Packages flagged as suspicious [SUS]:** none. [VERIFIED: mix.exs]

## Architecture Patterns

### System Architecture Diagram

```text
Developer push/PR/manual/schedule
  -> GitHub Actions event matcher
      -> path filters for demo-relevant files
          -> demo-smoke job on ubuntu-latest
              -> checkout clean repository
              -> print docker version + docker compose version
              -> ./bin/demo smoke
                  -> Docker Compose builds example app image
                  -> private pgvector db becomes healthy
                  -> web publishes dynamic localhost port
                  -> wrapper waits for /health
                  -> wrapper checks locked HTTP routes
                  -> wrapper prints route/readiness failure plus web logs on failure
                  -> wrapper removes smoke containers/volumes on exit
```

This data flow reflects the existing wrapper and Compose contract. [VERIFIED: bin/demo] [VERIFIED: examples/cairnloop_example/compose.demo.yml]

### Recommended Project Structure

```text
.github/workflows/
  demo-smoke.yml                         # dedicated Docker demo smoke workflow
test/cairnloop/
  demo_smoke_workflow_contract_test.exs  # DB-free workflow source contract test
bin/
  demo                                   # existing canonical smoke wrapper
examples/cairnloop_example/
  compose.demo.yml                       # existing Docker demo stack
  Dockerfile.demo                        # existing Docker-owned Elixir runtime
```

The only expected new test file is `test/cairnloop/demo_smoke_workflow_contract_test.exs`; the workflow file already exists as a draft in the working tree. [VERIFIED: git status --short] [VERIFIED: .github/workflows/demo-smoke.yml]

### Pattern 1: Dedicated Workflow With Symmetric Push/PR Filters

**What:** Configure `workflow_dispatch`, `schedule`, `push`, and `pull_request` in the dedicated workflow, and repeat the same path filters under `push` and `pull_request`. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax]

**When to use:** Use this for Phase 56 because GitHub requires filters to be configured per event when multiple events are present. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax]

**Example:**

```yaml
# Source: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md and GitHub workflow syntax docs
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
      - ".github/workflows/demo-smoke.yml"
      - "README.md"
      - "guides/**"
      - "mix.exs"
      - "mix.lock"
      - "config/**"
      - "lib/**"
      - "priv/**"
  pull_request:
    paths:
      - ".dockerignore"
      - "bin/demo"
      - "examples/cairnloop_example/**"
      - ".github/workflows/demo-smoke.yml"
      - "README.md"
      - "guides/**"
      - "mix.exs"
      - "mix.lock"
      - "config/**"
      - "lib/**"
      - "priv/**"
```

### Pattern 2: Small Read-Only Smoke Job

**What:** Keep one `demo-smoke` job with read-only repository contents, Docker version preflight, explicit timeout, and one wrapper command. [VERIFIED: .github/workflows/demo-smoke.yml] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]

**When to use:** Use this whenever CI proof should fail loudly but must not publish, tag, upload releases, or require secrets. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [VERIFIED: .github/workflows/release-please.yml]

**Example:**

```yaml
# Source: .github/workflows/demo-smoke.yml
permissions:
  contents: read

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

### Pattern 3: DB-Free Workflow Source Contract Test

**What:** Add an ExUnit test that reads `.github/workflows/demo-smoke.yml` and asserts the locked trigger set, path filters, permissions, job name, timeout, preflight, and exact `./bin/demo smoke` command. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [VERIFIED: test/cairnloop/demo_wrapper_contract_test.exs]

**When to use:** Use this because `mix ci.fast` includes DB-free ExUnit tests and is mandatory before completing headless work. [VERIFIED: mix.exs] [VERIFIED: CLAUDE.md]

**Example:**

```elixir
# Source: test/cairnloop/demo_wrapper_contract_test.exs pattern
defmodule Cairnloop.DemoSmokeWorkflowContractTest do
  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/demo-smoke.yml"
  @path_filters ~w(
    .dockerignore
    bin/demo
    examples/cairnloop_example/**
    .github/workflows/demo-smoke.yml
    README.md
    guides/**
    mix.exs
    mix.lock
    config/**
    lib/**
    priv/**
  )

  test "demo smoke workflow keeps locked triggers and command" do
    source = File.read!(@workflow_path)

    for expected <- [
          "workflow_dispatch:",
          "schedule:",
          "push:",
          "pull_request:",
          "permissions:\n  contents: read",
          "name: demo-smoke",
          "timeout-minutes: 25",
          "docker compose version",
          "run: ./bin/demo smoke"
        ] do
      assert source =~ expected
    end

    for path <- @path_filters do
      assert source =~ ~s("#{path}") or source =~ ~s(- #{path})
    end
  end
end
```

### Anti-Patterns to Avoid

- **Duplicating smoke logic in workflow YAML:** This bypasses wrapper-owned dynamic ports, route list, cleanup, and diagnostics. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [VERIFIED: bin/demo]
- **Putting demo smoke into release publishing:** Release workflows use write permissions and publish secrets; demo smoke must be read-only and credential-free. [VERIFIED: .github/workflows/release-please.yml] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
- **Leaving PR coverage out:** VER-03 requires CI to run for demo-relevant changes, and the current draft lacks `pull_request`. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .github/workflows/demo-smoke.yml]
- **Underscoping path filters:** The current draft omits root runtime/package paths and core library paths consumed by the example app's local dependency. [VERIFIED: .github/workflows/demo-smoke.yml] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
- **Adding human UAT:** Phase 56 explicitly requires automated evidence and no human UAT checkpoint. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/STATE.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Demo lifecycle and smoke routing | Raw Compose lifecycle and curl route list in YAML | `./bin/demo smoke` | Wrapper already owns Compose file selection, isolation, dynamic port fallback, `/health` wait, route list, logs, and cleanup. [VERIFIED: bin/demo] |
| Workflow drift detection | Manual review checklist only | DB-free ExUnit contract test in `mix ci.fast` | Existing repo pattern catches source drift automatically without Docker or DB. [VERIFIED: test/cairnloop/demo_wrapper_contract_test.exs] [VERIFIED: mix.exs] |
| Release/demo separation | A shared release gate that publishes or mutates release state | Dedicated read-only `demo-smoke.yml` | Release workflow uses release tokens, `contents: write`, `pull-requests: write`, and Hex publish; smoke must not. [VERIFIED: .github/workflows/release-please.yml] |
| Browser proof | Owner UAT checkpoint | Existing example E2E lane if new browser-rendered behavior is claimed | Project policy says rendered behavior is gated E2E, not human verification. [VERIFIED: .planning/STATE.md] [VERIFIED: .github/workflows/ci.yml] |

**Key insight:** The risky part is not writing a large workflow; it is preserving a narrow CI contract that delegates real behavior to the already-verified wrapper while pinning trigger/path semantics in fast tests. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-VERIFICATION.md] [VERIFIED: test/cairnloop/demo_wrapper_contract_test.exs]

## Common Pitfalls

### Pitfall 1: PR Path Filters Missing

**What goes wrong:** Pushes to `main` run demo smoke, but PRs that change demo-breaking files do not. [VERIFIED: .github/workflows/demo-smoke.yml]
**Why it happens:** GitHub event filters must be configured per event in multi-event workflows. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax]
**How to avoid:** Add a `pull_request` event with the same path list used by `push`. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
**Warning signs:** Contract test can find `push:` paths but no `pull_request:` block. [VERIFIED: test/cairnloop/demo_wrapper_contract_test.exs]

### Pitfall 2: Path Filters Miss Local Dependency Breakage

**What goes wrong:** Changes under `lib/**`, `priv/**`, `mix.exs`, `mix.lock`, or `config/**` can break the example app through its local path dependency without triggering demo smoke. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [VERIFIED: examples/cairnloop_example/mix.exs]
**Why it happens:** The example app consumes the root library locally, so demo breakage is not confined to `examples/cairnloop_example/**`. [VERIFIED: examples/cairnloop_example/mix.exs]
**How to avoid:** Use D-05 path filters exactly and keep `.planning/**` out. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
**Warning signs:** Workflow source lacks `lib/**`, `priv/**`, `mix.exs`, `mix.lock`, or `config/**`. [VERIFIED: .github/workflows/demo-smoke.yml]

### Pitfall 3: Raw Compose in YAML Drifts From Wrapper Behavior

**What goes wrong:** CI may test a different stack shape, port behavior, or route list than adopters run locally. [VERIFIED: bin/demo] [VERIFIED: examples/cairnloop_example/compose.demo.yml]
**Why it happens:** The wrapper centralizes behavior that is easy to partially copy and then forget. [VERIFIED: bin/demo]
**How to avoid:** Keep workflow step exactly `run: ./bin/demo smoke`; put all smoke behavior changes in the wrapper phase, not CI YAML. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
**Warning signs:** Workflow contains `docker compose up`, `curl`, or explicit route paths outside the wrapper. [VERIFIED: bin/demo]

### Pitfall 4: Overprivileged or Secret-Dependent PR Smoke

**What goes wrong:** A PR-triggered workflow can expose credentials or mutate repository/release state. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows] [VERIFIED: .github/workflows/release-please.yml]
**Why it happens:** Release workflow permissions and secrets are inappropriate for untrusted PR code. [VERIFIED: .github/workflows/release-please.yml]
**How to avoid:** Use `pull_request`, not `pull_request_target`; keep `permissions: contents: read`; do not reference `secrets.*`. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
**Warning signs:** Workflow references release tokens, Hex credentials, `contents: write`, or `pull_request_target`. [VERIFIED: .github/workflows/release-please.yml]

### Pitfall 5: Timeout Defaults Hide Hung Smoke

**What goes wrong:** A broken Docker build or health wait can consume GitHub's default job timeout instead of failing within the demo contract. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax]
**Why it happens:** GitHub's job timeout default is much larger than Phase 56 needs. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax]
**How to avoid:** Keep `timeout-minutes: 25` unless CI evidence proves a clean smoke needs more. [VERIFIED: .github/workflows/demo-smoke.yml] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
**Warning signs:** Workflow lacks `timeout-minutes` or sets it near the platform default. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax]

## Code Examples

Verified patterns from official and project sources:

### Workflow Trigger Contract

```yaml
# Source: GitHub workflow syntax docs and Phase 56 CONTEXT.md
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
      - ".github/workflows/demo-smoke.yml"
      - "README.md"
      - "guides/**"
      - "mix.exs"
      - "mix.lock"
      - "config/**"
      - "lib/**"
      - "priv/**"
  pull_request:
    paths:
      - ".dockerignore"
      - "bin/demo"
      - "examples/cairnloop_example/**"
      - ".github/workflows/demo-smoke.yml"
      - "README.md"
      - "guides/**"
      - "mix.exs"
      - "mix.lock"
      - "config/**"
      - "lib/**"
      - "priv/**"
```

### Contract Test Shape

```elixir
# Source: test/cairnloop/demo_wrapper_contract_test.exs
defp assert_contains(source, expected) do
  assert source =~ expected, "Expected source to include #{inspect(expected)}"
end

defp position!(source, needle, label) do
  case :binary.match(source, needle) do
    {position, _length} -> position
    :nomatch -> flunk("Expected #{label} to include #{inspect(needle)}")
  end
end
```

### Final Verification Gate

```bash
# Source: Phase 56 context and prior demo verification pattern
mix ci.fast
docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet
./bin/demo smoke
```

These commands match the context requirement for source validation plus Docker smoke when Docker is available. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [VERIFIED: .planning/phases/55-docker-first-adopter-docs/55-VERIFICATION.md]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual demo proof | `./bin/demo smoke` with isolated stack, route checks, logs, and cleanup | Phase 54, verified 2026-06-28 | CI can delegate to a real maintained wrapper instead of custom YAML smoke logic. [VERIFIED: .planning/phases/54-demo-wrapper-experience/54-VERIFICATION.md] |
| Docs-only smoke description | Docker-first docs plus source-scan tests | Phase 55, verified 2026-06-28 | CI path filters must include docs because first-run guidance affects adopter behavior. [VERIFIED: .planning/phases/55-docker-first-adopter-docs/55-VERIFICATION.md] |
| `docker-compose` binary assumption | `docker compose` plugin command | Current wrapper and Docker CLI reference | Wrapper checks Compose v2 and uses the current Docker CLI command family. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/] |
| Human browser/UAT checkpoints | Automated smoke or E2E evidence | Project decision carried in STATE.md | Phase 56 verification must not add a human UAT task. [VERIFIED: .planning/STATE.md] |
| Release pipeline as catch-all gate | Separate read-only demo smoke workflow | Phase 56 locked decision | Demo proof can fail without publishing, tagging, or using release secrets. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |

**Deprecated/outdated:**
- `docker-compose` command spelling should not be introduced; the project wrapper uses `docker compose`, and Docker documents `docker compose` as the CLI command family. [VERIFIED: bin/demo] [CITED: https://docs.docker.com/reference/cli/docker/compose/]
- Human UAT checkpoints for rendered behavior are deprecated by project policy; use automated E2E if browser proof is needed. [VERIFIED: .planning/STATE.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| None | All actionable claims in this research are backed by project source, phase context, command probes, or official docs. | All sections | N/A |

## Open Questions (RESOLVED)

1. **Should branch protection require `demo-smoke` later?**
   - What we know: Branch protection is explicitly outside this code phase, but the workflow should expose a stable `demo-smoke` check name. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
   - What's unclear: Repository settings are not represented in the working tree. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
   - Recommendation: Do not plan a repo-settings task; keep the check name stable for a future owner-side requirement. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
   - RESOLVED: Branch protection remains outside Phase 56; the plan only preserves the stable `demo-smoke` check name for future repository settings. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-01-PLAN.md]

2. **Should the 25-minute timeout change?**
   - What we know: The draft uses 25 minutes, and context accepts that as the starting contract. [VERIFIED: .github/workflows/demo-smoke.yml] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
   - What's unclear: Clean GitHub-hosted first-run Docker smoke duration is not yet measured for this new workflow. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
   - Recommendation: Keep 25 minutes unless CI evidence shows clean runs regularly need more. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
   - RESOLVED: Keep `timeout-minutes: 25` as the Phase 56 contract; future CI timing evidence can justify a later adjustment. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-01-PLAN.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Docker CLI | Local `./bin/demo smoke` verification | Yes | 29.5.2 | If unavailable, record blocker and provide source-level workflow proof. [VERIFIED: docker --version] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |
| Docker Compose | Wrapper and Compose config checks | Yes | v5.1.3 | If unavailable, run `mix ci.fast` and source-contract proof only. [VERIFIED: docker compose version] [VERIFIED: bin/demo] |
| Docker daemon | Local smoke execution | Yes | 29.5.2 | If unavailable, skip local smoke with explicit blocker. [VERIFIED: docker info --format '{{.ServerVersion}}'] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |
| Elixir / Mix | `mix ci.fast` and ExUnit contract test | Yes | Elixir 1.19.5 / Mix 1.19.5 | None needed for local test authoring. [VERIFIED: elixir --version] [VERIFIED: mix --version] |
| GitHub Actions | CI workflow execution | Repository-hosted service | Current docs as of 2026-06-28 | Local source-contract test plus manual GitHub run after merge. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax] |
| GitHub-hosted Ubuntu runner Docker tooling | CI smoke job | Expected on current Ubuntu 24.04 image | Runner image docs list Docker Compose 2.38.2 and Docker 28.0.4 | Workflow preflights `docker version` and `docker compose version`. [CITED: https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md] [VERIFIED: .github/workflows/demo-smoke.yml] |
| GitHub CLI `gh` | Optional manual inspection only | Yes | 2.95.0 | Not required for implementation. [VERIFIED: gh --version] |

**Missing dependencies with no fallback:**
- None found locally. [VERIFIED: docker --version] [VERIFIED: docker compose version] [VERIFIED: mix --version]

**Missing dependencies with fallback:**
- None found locally. [VERIFIED: docker --version] [VERIFIED: docker compose version] [VERIFIED: mix --version]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix 1.19.5. [VERIFIED: mix --version] |
| Config file | `mix.exs` aliases and `test/test_helper.exs`. [VERIFIED: mix.exs] [VERIFIED: test/test_helper.exs] |
| Quick run command | `mix test test/cairnloop/demo_smoke_workflow_contract_test.exs --warnings-as-errors` after the test exists. [VERIFIED: mix.exs] |
| Full suite command | `mix ci.fast`. [VERIFIED: mix.exs] [VERIFIED: CLAUDE.md] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| VER-03 | Workflow runs for manual, schedule, push, and PR triggers with D-05 path filters. [VERIFIED: .planning/REQUIREMENTS.md] | Source contract | `mix test test/cairnloop/demo_smoke_workflow_contract_test.exs --warnings-as-errors` | No, Wave 0 gap. [VERIFIED: rg --files test/cairnloop] |
| VER-03 | Workflow executes `./bin/demo smoke` on a clean checkout with bounded timeout. [VERIFIED: .planning/REQUIREMENTS.md] | Source contract + smoke | `mix ci.fast` and `./bin/demo smoke` | Workflow exists; contract test missing. [VERIFIED: .github/workflows/demo-smoke.yml] |
| VER-04 | Verification remains automated and has no human UAT checkpoint. [VERIFIED: .planning/REQUIREMENTS.md] | Source/process gate | `mix ci.fast`; no `HUMAN-UAT.md` creation for this phase | No Phase 56 verification artifact yet. [VERIFIED: node /Users/jon/.codex/gsd-core/bin/gsd-tools.cjs query init.phase-op 56] |

### Sampling Rate

- **Per task commit:** Run `mix test test/cairnloop/demo_smoke_workflow_contract_test.exs --warnings-as-errors` once the contract test exists. [VERIFIED: mix.exs]
- **Per wave merge:** Run `mix ci.fast`. [VERIFIED: CLAUDE.md] [VERIFIED: mix.exs]
- **Phase gate:** Run `mix ci.fast`, `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet`, and `./bin/demo smoke`; if Docker is unavailable, record the environment blocker and include source-level workflow proof. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [VERIFIED: .planning/phases/55-docker-first-adopter-docs/55-VERIFICATION.md]

### Wave 0 Gaps

- [ ] `test/cairnloop/demo_smoke_workflow_contract_test.exs` - covers VER-03 and VER-04 workflow contract. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
- [ ] No new framework install is needed; ExUnit already covers the pattern. [VERIFIED: mix.exs] [VERIFIED: test/cairnloop/demo_wrapper_contract_test.exs]

## Security Domain

Security enforcement is enabled by default because `.planning/config.json` does not explicitly set `security_enforcement: false`. [VERIFIED: .planning/config.json]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | No | No user authentication is implemented in this CI-only phase. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |
| V3 Session Management | No | No web session behavior changes. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |
| V4 Access Control | Yes | Use `permissions: contents: read`; do not reference release secrets or write permissions. [VERIFIED: .github/workflows/demo-smoke.yml] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |
| V5 Input Validation | Yes | Treat workflow event/path filters as the boundary: only demo-relevant paths should trigger Docker smoke; `.planning/**` should not. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |
| V6 Cryptography | No | No cryptographic implementation or secret generation is introduced. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |

### Known Threat Patterns for GitHub Actions Docker Smoke

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Overprivileged PR workflow | Elevation of privilege | Use `pull_request` with read-only contents permission; avoid `pull_request_target`, `contents: write`, and `secrets.*`. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |
| Release mutation from smoke failure/success | Tampering | Keep smoke in `.github/workflows/demo-smoke.yml`, separate from `release-please.yml` and `publish-hex`. [VERIFIED: .github/workflows/release-please.yml] [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] |
| Secret exposure in Docker build logs | Information disclosure | Do not require or pass OpenAI, Hex, release, or external service secrets to the smoke workflow. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [VERIFIED: examples/cairnloop_example/compose.demo.yml] |
| Runner image Docker/Compose drift | Denial of service | Preflight `docker version` and `docker compose version`; rely on wrapper diagnostics and contract tests. [VERIFIED: .github/workflows/demo-smoke.yml] [CITED: https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md] |
| Unbounded hung smoke | Denial of service | Keep explicit `timeout-minutes: 25`; wrapper has bounded waits and emits recent logs. [VERIFIED: .github/workflows/demo-smoke.yml] [VERIFIED: bin/demo] [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md` - locked decisions, path filters, smoke command contract, verification boundary. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md]
- `.planning/REQUIREMENTS.md` - VER-03 and VER-04. [VERIFIED: .planning/REQUIREMENTS.md]
- `.planning/STATE.md` - no-human-UAT automation policy and current milestone state. [VERIFIED: .planning/STATE.md]
- `CLAUDE.md` and `AGENTS.md` - repo constraints and build/test policy. [VERIFIED: CLAUDE.md] [VERIFIED: AGENTS.md]
- `.github/workflows/demo-smoke.yml` - existing draft workflow and current hardening gaps. [VERIFIED: .github/workflows/demo-smoke.yml]
- `bin/demo` - canonical smoke wrapper behavior. [VERIFIED: bin/demo]
- `test/cairnloop/demo_wrapper_contract_test.exs` and `test/cairnloop/docs/docker_first_docs_test.exs` - DB-free source-contract patterns. [VERIFIED: test/cairnloop/demo_wrapper_contract_test.exs] [VERIFIED: test/cairnloop/docs/docker_first_docs_test.exs]
- `examples/cairnloop_example/compose.demo.yml` and `examples/cairnloop_example/Dockerfile.demo` - Docker demo runtime contract. [VERIFIED: examples/cairnloop_example/compose.demo.yml] [VERIFIED: examples/cairnloop_example/Dockerfile.demo]

### Secondary (MEDIUM confidence)

- GitHub Actions workflow syntax docs - events, filters, permissions, concurrency, and timeout syntax. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax]
- GitHub Actions events docs - pull request defaults and fork/secret behavior. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows]
- GitHub-hosted runners reference - standard runner model. [CITED: https://docs.github.com/en/actions/reference/runners/github-hosted-runners]
- Official `actions/runner-images` Ubuntu 24.04 included software list - current Docker/Compose availability on the runner image. [CITED: https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md]
- Docker CLI `docker compose` reference - Compose command family. [CITED: https://docs.docker.com/reference/cli/docker/compose/]

### Tertiary (LOW confidence)

- None. [VERIFIED: research process]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - no new packages; stack is the existing GitHub Actions, Docker, Bash, Mix, and ExUnit substrate. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: bin/demo] [VERIFIED: mix.exs]
- Architecture: HIGH - phase boundary and ownership are locked by context and existing code. [VERIFIED: .planning/phases/56-demo-smoke-ci-gate/56-CONTEXT.md] [VERIFIED: bin/demo]
- Pitfalls: MEDIUM - GitHub event/path behavior is cited from official docs, but runner image tooling can change quickly. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax] [CITED: https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md]

**Research date:** 2026-06-28
**Valid until:** 2026-07-05 for runner-image/tooling details; 2026-07-28 for project-local architecture unless Phase 56 files change.
