---
phase: 56-demo-smoke-ci-gate
verified: 2026-06-28T21:54:40Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
---

# Phase 56: Demo Smoke CI Gate Verification Report

**Phase Goal:** Ensure demo drift is caught automatically for relevant changes.
**Verified:** 2026-06-28T21:54:40Z
**Status:** passed

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Docker demo smoke has its own read-only GitHub Actions workflow and does not mutate release state. | VERIFIED | `.github/workflows/demo-smoke.yml` is a dedicated workflow with `permissions: contents: read` and no release/secrets tokens; enforced by `Cairnloop.DemoSmokeWorkflowContractTest`. |
| 2 | Workflow runs by workflow_dispatch, weekly schedule, main/master push, and pull_request with the exact demo-relevant path list and no `.planning/**` path filter. | VERIFIED | Workflow lines 3-35 contain all events and symmetric path lists; test lines 27-45 assert the trigger/path contract and reject `.planning/**`. |
| 3 | The demo-smoke job uses ubuntu-latest, contents: read, ACTIONS_RUNNER_NODE_VERSION: "24", Docker/Compose preflight, timeout-minutes: 25, and exact `run: ./bin/demo smoke` with no secrets. | VERIFIED | Workflow lines 37-63 contain the permission, env, job, timeout, Docker preflight, and wrapper command; test lines 47-89 assert required and forbidden tokens. |
| 4 | `mix ci.fast` includes a DB-free source contract test for workflow drift and final verification is automated without a human UAT checkpoint. | VERIFIED | `test/cairnloop/demo_smoke_workflow_contract_test.exs` uses `ExUnit.Case, async: true` and `File.read!/1`; `mix ci.fast` passed with 1 doctest, 1074 tests, and 0 failures. |
| 5 | Existing draft `.github/workflows/demo-smoke.yml` and `.dockerignore` work is inspected, preserved where useful, and hardened in place. | VERIFIED | The draft workflow's schedule, push branches, read-only permission, timeout, Docker preflight, and wrapper command were preserved; `.dockerignore` was tracked with generated-artifact exclusions and no broad source/docs exclusions. |

**Score:** 5/5 truths verified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.github/workflows/demo-smoke.yml` | Dedicated Demo smoke workflow with job id/name `demo-smoke` | EXISTS + SUBSTANTIVE | Workflow lines 1-63 define the workflow, triggers, read-only permission, Docker preflight, and exact smoke command. |
| `.dockerignore` | Tracked Docker build-context exclusions retaining demo source inputs | EXISTS + SUBSTANTIVE | Lines 1-19 exclude generated/local artifacts while leaving `bin/`, `config/`, `lib/`, `priv/`, docs, and example source available. |
| `test/cairnloop/demo_smoke_workflow_contract_test.exs` | DB-free ExUnit source contract | EXISTS + SUBSTANTIVE | Lines 1-153 define `Cairnloop.DemoSmokeWorkflowContractTest`, source-only assertions, exact path filters, and forbidden-token checks. |

**Artifacts:** 3/3 verified.

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `.github/workflows/demo-smoke.yml` | `bin/demo` | Workflow delegates smoke behavior to wrapper | WIRED | Workflow line 63 runs exactly `./bin/demo smoke`. |
| `test/cairnloop/demo_smoke_workflow_contract_test.exs` | `.github/workflows/demo-smoke.yml` | `File.read!` source contract | WIRED | Test line 11 pins `@workflow_path`; line 91 reads the workflow source. |
| `.github/workflows/demo-smoke.yml` | `examples/cairnloop_example/compose.demo.yml` | `bin/demo smoke` invokes the existing Compose demo stack | WIRED | `./bin/demo smoke` passed locally against the Compose stack and locked route list. |

**Wiring:** 3/3 connections verified.

## Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| VER-03: CI runs the Docker demo smoke lane for changes that can break the demo wrapper, Compose/Dockerfile contract, example runtime, first-run docs, or the smoke workflow. | SATISFIED | - |
| VER-04: Demo verification remains automated; no human UAT checkpoint is required for first-run, route, or browser-rendered behavior. | SATISFIED | - |

**Coverage:** 2/2 requirements satisfied.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| - | - | None | - | - |

**Anti-patterns:** 0 found.

## Human Verification Required

None - all verifiable items were checked programmatically.

## Gaps Summary

**No gaps found.** Phase goal achieved. Ready to proceed.

## Verification Metadata

**Verification approach:** Goal-backward from Phase 56 goal and PLAN.md must-haves.
**Must-haves source:** `.planning/phases/56-demo-smoke-ci-gate/56-01-PLAN.md` frontmatter.
**Automated checks:** 5 passed, 0 failed.
**Human checks required:** 0.
**Total verification time:** 2 min.

Automated checks run:

- `mix test test/cairnloop/demo_smoke_workflow_contract_test.exs --warnings-as-errors` - passed, 3 tests, 0 failures.
- `mix ci.fast` - passed, 1 doctest and 1074 tests, 0 failures.
- `mix compile --warnings-as-errors` - passed.
- `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` - passed.
- `./bin/demo smoke` - passed all locked route checks.

---
*Verified: 2026-06-28T21:54:40Z*
*Verifier: Codex inline verifier*
