# CI/CD Audit

Audit date: 2026-07-01

Scope: final Phase 61 source-backed CI/CD topology for Cairnloop's GitHub Actions workflows,
local Mix lanes, release publish confidence, and maintainer evidence.

This document describes repository source. It does not claim live GitHub branch-protection settings,
cache hit rates, hosted-runner wall-clock timing, or release history that cannot be proven from local
files.

## Executive Summary

Cairnloop's CI/CD posture now has three source-backed properties:

1. **Current action/runtime posture.** Workflows use the official Node 24 opt-in
   `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: "true"` and reject stale/unsafe transition variables in
   DB-free source-contract tests. First-party actions are on current maintained majors where Phase 61
   found no incompatibility: `actions/checkout@v7`, `actions/cache@v6`,
   `actions/setup-node@v6`, and `actions/upload-artifact@v7`. `erlef/setup-beam@v1` and
   `googleapis/release-please-action@v5` remain the correct majors for this project.
2. **Least privilege and stable gates.** Workflow defaults are `contents: read`; every checkout uses
   `persist-credentials: false`; only the `release-please` job gets write permission; `publish-hex`
   remains read-only except for its Hex secret. Branch protection can continue to require one stable
   `CI / release_gate` check while E2E is path-gated behind source-controlled logic.
3. **Evidence before optimization.** CI summaries now expose lane timings, cache hits, compile
   profile output, slowest headless tests, split E2E setup/browser timings, failure-only Playwright
   artifacts, Docker smoke runtime facts, and release publish/preflight timings. `_build` caches were
   intentionally retained until hosted-runner evidence proves they are low value.

## Workflow Map

### `.github/workflows/ci.yml` - `CI`

Triggers: `push` to `main`/`master`, `pull_request`, and `workflow_dispatch`.

Defaults:

- `permissions: contents: read`
- PR-only cancellation with `${{ github.event_name == 'pull_request' }}`
- `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: "true"`
- Elixir `1.19.5`, OTP `27.2`, and `MIX_CACHE_VERSION`
- all checkouts use `persist-credentials: false`

Jobs:

| Job | Source-backed behavior |
| --- | --- |
| `changes` | Uses `actions/checkout@v7`, fetches `${{ github.event.pull_request.base.sha }}`, diffs `"$BASE_SHA"...HEAD`, and emits `e2e_required`. Non-PR trusted/manual runs set E2E required without diff ambiguity. |
| `fast` | Uses checkout v7, setup-beam v1, cache v6 for deps/build, records version/cache summary, runs a compile timing profile, runs `mix ci.fast`, records fast duration, and records `mix test --exclude integration --slowest 20`. |
| `quality` | Uses checkout v7, setup-beam v1, cache v6, records cache/runtime summary, runs and times `mix ci.quality`. |
| `integration` | Uses `pgvector/pgvector:pg16`, checkout v7, setup-beam v1, cache v6, records cache/runtime summary, runs and times `mix ci.integration`. |
| `e2e` | Depends on `changes` and runs only when `e2e_required == 'true'`. It uses setup-node v6 with npm cache, cache v6 for example Mix/build and Playwright browser cache, enables `PW_TRACE` and `PW_SCREENSHOT`, records separate Elixir deps, npm deps, Playwright install, setup/migrate/assets, and browser-test timings, then uploads failure-only traces/screenshots with `retention-days: 3` and `if-no-files-found: warn`. |
| `release_gate` | Always runs. Requires `fast`, `integration`, and `quality` success. E2E passes only when it succeeds, or when `e2e_required == 'false'` and the E2E job result is `skipped`; failure, cancellation, skipped-when-required, or unexpected values fail closed. |

PR E2E path gate:

- `examples/cairnloop_example/**`
- `lib/cairnloop/web/**`
- `priv/static/**`
- `test/cairnloop/web/**`
- `examples/cairnloop_example/test/**`
- `.github/workflows/ci.yml`
- `mix.exs`, `mix.lock`, `config/**`
- example Mix and asset lockfiles

### `.github/workflows/demo-smoke.yml` - `Demo smoke`

Triggers: `workflow_dispatch`, weekly schedule, and `push`/`pull_request` path filters for adoption
signals.

Path filters now target Docker/demo/example/docs/config/Mix changes:

- `.dockerignore`, `bin/demo`, `examples/cairnloop_example/**`
- `.github/workflows/demo-smoke.yml`
- `README.md`, `CONTRIBUTING.md`, `guides/**`
- `mix.exs`, `mix.lock`, `config/**`

Broad `lib/**` and `priv/**` triggers were removed. Those changes are covered more directly by
normal CI and PR E2E path gating.

The workflow remains read-only, uses `actions/checkout@v7` with `persist-credentials: false`, keeps
the Node 24 opt-in, delegates behavior to `./bin/demo smoke`, and writes bounded summary evidence for
Docker version, Docker Compose version, event, ref, and smoke duration.

### `.github/workflows/release-please.yml` - `release-please`

Triggers: `push` to `main` and `workflow_dispatch`; no PR or `pull_request_target` trigger exists.

Defaults:

- workflow permissions: `contents: read`
- release-please job permissions: `contents: write`, `pull-requests: write`
- publish job permissions: `contents: read`
- every checkout uses `persist-credentials: false`

Release PR automation:

- `actions/checkout@v7`
- `googleapis/release-please-action@v5`
- explicit token passed to release-please / `gh pr merge`, not persisted checkout credentials

Hex publish:

- gated on `needs.release-please.outputs.release_created == 'true'`
- checks out `needs.release-please.outputs.sha`
- setup-beam v1 and cache v6 for deps/build
- preflights `HEX_API_KEY` presence without printing it
- runs `mix deps.get --check-locked`
- runs `mix ci.quality` on the exact release SHA before dry run and publish
- runs `mix hex.publish --dry-run`
- builds and inspects the tarball for `lib`, `priv`, `guides`, `mix.exs`, `README.md`, `LICENSE`,
  and `CHANGELOG.md`
- runs irreversible `mix hex.publish --yes`
- verifies `mix hex.info`
- verifies docs with `mix hex.docs fetch`, then treats HexDocs CDN propagation as warning-only

The publish job writes bounded summary evidence for version, tag, release SHA, Elixir/OTP, cache
hits, quality preflight duration, dry-run duration, package inspection duration, publish duration,
Hex info duration, and HexDocs verification duration.

### `.github/dependabot.yml`

Dependabot checks GitHub Actions weekly with commit prefix `ci`, and also checks root/example Mix
deps plus example npm assets weekly. This keeps action major refreshes visible while source-contract
tests prevent silent posture drift.

## Local Mix Lanes

`mix.exs` keeps the intended local split:

- `mix ci.fast` - locked deps, formatting, warnings-as-errors compile, and DB-free headless ExUnit.
- `mix ci.integration` - DB setup plus integration tests.
- `mix ci.quality` - unused-dep check, warnings-as-errors compile, Credo strict, Hex build, docs
  warnings-as-errors, and dependency audit.
- `mix ci` - shells out to fast, integration, and quality so each lane keeps the right environment.
- `mix ci.full` - runs `mix ci`, then the example E2E lane.
- `./bin/demo smoke` - remains separate from default Mix CI as Docker adoption proof.

## Source-Contract Coverage

Phase 61 added or updated DB-free ExUnit source contracts:

- `test/cairnloop/ci_workflow_contract_test.exs`
- `test/cairnloop/release_workflow_contract_test.exs`
- `test/cairnloop/demo_smoke_workflow_contract_test.exs`

These tests assert workflow source only. They do not start Docker, Phoenix, Repo, browser tooling,
network release checks, or GitHub Actions.

Covered decisions:

- current action majors and official Node 24 posture
- absence of `ACTIONS_RUNNER_NODE_VERSION` and `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION`
- read-only workflow defaults and checkout credential opt-out
- absence of privileged untrusted PR release paths
- CI job topology and optional E2E aggregate gate semantics
- safe PR base-SHA fetch/diff for E2E path gating
- cache/timing/runtime/slow-test/artifact summary evidence
- demo-smoke path filters and wrapper delegation
- exact release SHA checkout, Hex token preflight, `mix ci.quality`, dry run, package inspection,
  publish, Hex info, and HexDocs fetch

## Verification Evidence

Phase 61 local checks run during execution:

- Workflow contracts: `mix test test/cairnloop/demo_smoke_workflow_contract_test.exs test/cairnloop/ci_workflow_contract_test.exs test/cairnloop/release_workflow_contract_test.exs --warnings-as-errors`
- Fast lane: `mix ci.fast`
- Quality lane: `mix ci.quality`

Observed caveat: local Hex auth was expired, and Mix printed a warning before continuing with public
dependency access. This did not block `mix ci.fast` or `mix ci.quality`.

## Open Assumptions and Next-Run Inspection

These remain outside local source control:

- Branch protection should require the stable aggregate `CI / release_gate` check.
- The next hosted PR/main runs should be inspected for cache restore/save duration and job wall-clock
  timing before removing `_build` caches.
- The next E2E failure should confirm trace/screenshot artifacts are non-empty and useful.
- Real Hex publish remains a trusted release workflow action, not a local verification command.

## Official Sources Checked

- GitHub Actions Node 20 deprecation / Node 24 transition:
  <https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/>
- Read-only Actions cache for untrusted triggers:
  <https://github.blog/changelog/2026-06-26-read-only-actions-cache-for-untrusted-triggers/>
- `actions/checkout` releases:
  <https://github.com/actions/checkout/releases>
- `actions/cache` releases:
  <https://github.com/actions/cache/releases>
- `actions/setup-node` releases:
  <https://github.com/actions/setup-node/releases>
- `actions/upload-artifact` releases:
  <https://github.com/actions/upload-artifact/releases>
- `googleapis/release-please-action` releases:
  <https://github.com/googleapis/release-please-action/releases>
- GitHub Actions secure-use reference:
  <https://docs.github.com/en/actions/reference/security/secure-use>
- GitHub dependency caching reference:
  <https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching>
