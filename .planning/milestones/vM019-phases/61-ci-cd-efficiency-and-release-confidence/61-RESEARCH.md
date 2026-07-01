# Phase 61: CI/CD Efficiency and Release Confidence - Research

**Researched:** 2026-06-30
**Domain:** GitHub Actions CI/CD, Hex release automation, source-contract validation
**Confidence:** HIGH for local workflow facts; MEDIUM for current GitHub-hosted action facts because they were verified from official GitHub/GitHub Docs/GitHub Blog sources during this session.

## Executive Summary

Cairnloop's CI/CD baseline is already structurally sound: the primary CI workflow has read-only default permissions, PR-only cancellation, explicit Elixir/OTP versions, a Node 24 transition opt-in, separated `fast`, `quality`, `integration`, `e2e`, and aggregate `release_gate` jobs, and checkout credential persistence disabled on each checkout. [VERIFIED: codebase `.github/workflows/ci.yml`] The demo smoke workflow is also read-only, delegates behavior to `./bin/demo smoke`, and has a DB-free source-contract test that prevents privileged release behavior from drifting into demo smoke. [VERIFIED: codebase `.github/workflows/demo-smoke.yml`; VERIFIED: codebase `test/cairnloop/demo_smoke_workflow_contract_test.exs`]

The main planning decision is not whether to rebuild CI. Do not. The planner should schedule small, verifiable changes: refresh first-party action majors to current official Node 24-capable majors, add DB-free workflow source-contract tests for `ci.yml` and `release-please.yml`, path-gate expensive E2E/demo smoke work without weakening the stable aggregate gate, add timing/cache/failure evidence to step summaries, and add a release-SHA preflight before irreversible Hex publish. [VERIFIED: codebase `.planning/phases/61-ci-cd-efficiency-and-release-confidence/61-CONTEXT.md`; VERIFIED: codebase `docs/ci-cd-audit.md`]

Primary recommendation: upgrade local first-party actions to current maintained majors where official release notes show no incompatibility (`actions/checkout@v7`, `actions/cache@v6`, `actions/upload-artifact@v7`; keep `actions/setup-node@v6` and `googleapis/release-please-action@v5`), preserve least-privilege permissions and `persist-credentials: false`, then lock the result with DB-free source-contract tests and release preflight. [VERIFIED: GitHub API; CITED: https://github.com/actions/checkout/releases; CITED: https://github.com/actions/cache/releases; CITED: https://github.com/actions/upload-artifact/releases; CITED: https://github.com/actions/setup-node/releases; CITED: https://github.com/googleapis/release-please-action/releases]

## Local Baseline

### Project Constraints

- `CLAUDE.md` requires warning-clean builds and `mix compile --warnings-as-errors`; it expects `mix ci.fast` before headless work is declared done, with `mix ci.integration`, `mix ci.quality`, or example E2E added for DB/docs/package/browser changes. [VERIFIED: codebase `CLAUDE.md`]
- `AGENTS.md` requires reading `CLAUDE.md` first and keeps UI work inside Cairnloop's `.cl-*` / BEM component system; Phase 61 is workflow/release work, so no operator UI files should be edited. [VERIFIED: codebase `AGENTS.md`]
- `.planning/config.json` does not explicitly disable Nyquist validation, so the plan should include validation architecture. [VERIFIED: codebase `.planning/config.json`]
- Phase 61 is scoped to CI/CD posture, Mix CI aliases, workflow drift tests, timing/cache/failure evidence, release publish preflight, and docs that explain those gates; product surface, runtime trust boundaries, DB prefix runtime behavior, and broad public docs cleanup are out of scope. [VERIFIED: codebase `61-CONTEXT.md`]

### Requirement Fit

| Requirement | Planning implication |
| --- | --- |
| CI-02 | Refresh and lock GitHub Actions runtime/action majors without stale variables. [VERIFIED: codebase `.planning/REQUIREMENTS.md`] |
| CI-03 | Preserve least-privilege token permissions and checkout credential opt-out. [VERIFIED: codebase `.planning/REQUIREMENTS.md`] |
| CI-04 | Add maintainer-visible timing, cache, slow-test, compile, and failure evidence. [VERIFIED: codebase `.planning/REQUIREMENTS.md`] |
| CI-05 | Demote low-signal duplicate E2E/demo smoke work while preserving release-relevant proof. [VERIFIED: codebase `.planning/REQUIREMENTS.md`] |
| CI-06 | Prove package/docs/dry-run readiness before publish and keep secrets away from untrusted PR code. [VERIFIED: codebase `.planning/REQUIREMENTS.md`] |

### Workflow Topology

- `ci.yml` triggers on `push` to `main`/`master`, `pull_request`, and `workflow_dispatch`; it sets workflow-level `permissions: contents: read`; it cancels in-progress runs only for PRs. [VERIFIED: codebase `.github/workflows/ci.yml`]
- `ci.yml` sets `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: "true"`, `ELIXIR_VERSION: "1.19.5"`, `OTP_VERSION: "27.2"`, and `MIX_CACHE_VERSION: "v1"`. [VERIFIED: codebase `.github/workflows/ci.yml`]
- `ci.yml` currently uses `actions/checkout@v6`, `actions/cache@v5`, `actions/setup-node@v6`, and `actions/upload-artifact@v6`; every checkout sets `persist-credentials: false`. [VERIFIED: codebase `.github/workflows/ci.yml`]
- The `release_gate` job currently requires `fast`, `integration`, `quality`, and `e2e` to return `success`; if E2E becomes path-gated, this gate must explicitly accept a deliberate skip while still failing failure or cancellation. [VERIFIED: codebase `.github/workflows/ci.yml`; VERIFIED: codebase `61-CONTEXT.md`]
- `demo-smoke.yml` runs on manual dispatch, weekly schedule, push, and PR path filters; its PR paths currently include broad `lib/**` and `priv/**`, which overlaps normal CI and E2E. [VERIFIED: codebase `.github/workflows/demo-smoke.yml`; VERIFIED: codebase `docs/ci-cd-audit.md`]
- `release-please.yml` triggers only on `push` to `main` and `workflow_dispatch`, defaults to `contents: read`, grants write permissions only to the `release-please` job, and keeps `publish-hex` at `contents: read`. [VERIFIED: codebase `.github/workflows/release-please.yml`]
- `publish-hex` currently checks out `needs.release-please.outputs.sha`, preflights `HEX_API_KEY`, runs `mix hex.publish --dry-run`, builds and inspects the package tarball, publishes, runs `mix hex.info`, and verifies docs with `mix hex.docs fetch`. [VERIFIED: codebase `.github/workflows/release-please.yml`]
- `publish-hex` does not yet run `mix ci.quality` or an equivalent compact release preflight on the checked-out release SHA before `mix hex.publish --yes`. [VERIFIED: codebase `.github/workflows/release-please.yml`; VERIFIED: codebase `docs/ci-cd-audit.md`]

### Mix and Test Baseline

- `mix.exs` defines `mix ci` as `ci.fast`, `ci.integration`, and `ci.quality`; `mix ci.full` adds example E2E; Docker demo smoke stays outside Mix CI as `./bin/demo smoke`. [VERIFIED: codebase `mix.exs`]
- `ci.fast` checks locked deps, formatting, warnings-as-errors compile, and DB-free ExUnit with `:integration` excluded. [VERIFIED: codebase `mix.exs`]
- `ci.integration` runs DB setup plus integration tests, and `ci.quality` runs unused-dep checks, warnings-as-errors compile, Credo strict, Hex build, docs warnings-as-errors, and dependency audit with documented temporary Hackney advisory ignores. [VERIFIED: codebase `mix.exs`]
- The Phase 57 local audit recorded DB-free tests at 5.42s wall, `--slowest 20` at 5.73s wall, forced test compile at 2.67s wall, and two known compile-connected xref cycles; live GitHub job timing and cache transfer data were not available. [VERIFIED: codebase `docs/ci-cd-audit.md`]
- The existing demo-smoke workflow contract test reads YAML source only, never starts Docker, Phoenix, Repo, browser tooling, or `./bin/demo smoke`, and asserts read-only permissions, Node 24 posture, checkout v6, `persist-credentials: false`, forbidden release state, and wrapper delegation. [VERIFIED: codebase `test/cairnloop/demo_smoke_workflow_contract_test.exs`]

### Local Environment Caveat

- The local shell probe found `node v22.14.0`, `npm 11.1.0`, Docker 29.5.2, GitHub CLI 2.95.0, jq 1.7.1, and git 2.41.0 available. [VERIFIED: local command]
- The local shell probe reported Erlang/OTP 28 while `.tool-versions` pins Erlang 27.2 and Elixir 1.19.5-otp-27; use the project version manager before treating local runtime timings as release evidence. [VERIFIED: local command; VERIFIED: codebase `.tool-versions`]

## External Primary Source Findings

### GitHub Actions Node 24 Transition

- GitHub's Node 20 deprecation changelog was published 2025-09-19 and updated on 2026-02-25 and 2026-05-19; it says Node 20 reaches EOL in April 2026 and GitHub plans to migrate actions to Node 24 in fall 2026. [CITED: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/]
- The same changelog identifies `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` as the official opt-in test knob and says Node 24 became the runner default beginning 2026-06-16; it identifies `ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION=true` as a temporary opt-out, not something Cairnloop should add. [CITED: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/]
- No official source found in this session supports `ACTIONS_RUNNER_NODE_VERSION` as the current transition knob for JavaScript actions, so contract tests should reject it. [VERIFIED: official-source search; CITED: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/]

### Current Action Majors and Runtime Facts

| Action | Local | Current official latest on 2026-06-30 | Runtime fact | Planning recommendation |
| --- | --- | --- | --- | --- |
| `actions/checkout` | v6 | v7.0.0, published 2026-06-18 | v6.0.3 and v7.0.0 action metadata use `node24`; v7 refuses common `pull_request_target` and `workflow_run` fork checkout pwn-request patterns. [VERIFIED: GitHub API; CITED: https://github.com/actions/checkout/releases; CITED: https://github.blog/changelog/2026-06-18-safer-pull_request_target-defaults-for-github-actions-checkout/] | Upgrade to v7 unless executor finds an official incompatibility. |
| `actions/setup-node` | v6 | v6.4.0, published 2026-04-20 | v6.4.0 action metadata uses `node24`; README documents npm cache, `cache-dependency-path`, and no `node_modules` caching. [VERIFIED: GitHub API; VERIFIED: raw GitHub `actions/setup-node/v6.4.0/action.yml`; CITED: https://github.com/actions/setup-node/releases] | Keep v6 and keep explicit `cache: npm` with the example lockfile path. |
| `actions/cache` | v5 | v6.1.0, published 2026-06-26 | v5.1.0 and v6.1.0 action metadata use `node24`; official README documents restore/save subactions and read-only cache-token behavior. [VERIFIED: GitHub API; VERIFIED: raw GitHub `actions/cache/v6.1.0/action.yml`; CITED: https://github.com/actions/cache/releases] | Upgrade to v6 and consider restore-only in PR jobs only if it stays simple. |
| `actions/upload-artifact` | v6 | v7.0.1, published 2026-04-10 | v6.0.0 and v7.0.1 action metadata use `node24`; README documents `retention-days`, `if-no-files-found`, hidden-file handling, and artifact digest output. [VERIFIED: GitHub API; VERIFIED: raw GitHub `actions/upload-artifact/v7.0.1/action.yml`; CITED: https://github.com/actions/upload-artifact/releases] | Upgrade to v7 and set short retention if Playwright artifacts remain. |
| `googleapis/release-please-action` | v5 | v5.0.0, published 2026-04-22 | v5.0.0 release notes identify the Node 24 upgrade as a breaking change; action metadata uses `node24`. [VERIFIED: GitHub API; VERIFIED: raw GitHub `googleapis/release-please-action/v5.0.0/action.yml`; CITED: https://github.com/googleapis/release-please-action/releases] | Keep v5. |

### Checkout Credentials and Least Privilege

- GitHub's secure-use reference recommends granting the minimum needed `GITHUB_TOKEN` permissions, setting the default token permission to read-only contents, and elevating only where required at the job level. [CITED: https://docs.github.com/en/actions/reference/security/secure-use]
- `actions/checkout` README documents that the auth token is persisted by default for authenticated git commands and that `persist-credentials: false` opts out; v6/v7 notes improve storage by placing persisted credentials under `$RUNNER_TEMP`, but that still means credentials exist unless opted out. [VERIFIED: raw GitHub `actions/checkout/v7.0.0/README.md`; VERIFIED: raw GitHub `actions/checkout/v6.0.3/README.md`]
- Keep `persist-credentials: false` on all Cairnloop checkouts and pass write tokens only to the action or command that needs them, as `release-please.yml` already does for release-please and `gh pr merge`. [VERIFIED: codebase `.github/workflows/release-please.yml`; CITED: https://docs.github.com/en/actions/reference/security/secure-use]

### Untrusted PRs, Cache Behavior, and Secrets

- GitHub's secure-use reference warns that `pull_request_target` and `workflow_run` with untrusted code checkout can expose repository write tokens, secrets, and privileged default-branch cache state. [CITED: https://docs.github.com/en/actions/reference/security/secure-use]
- GitHub's 2026-06-26 changelog says Actions now issues read-only cache tokens to the default branch for workflow events that can be triggered without write permissions when the workflow context and cache scope are from the shared default-branch SHA; restores continue but restricted writes warn and continue. [CITED: https://github.blog/changelog/2026-06-26-read-only-actions-cache-for-untrusted-triggers/]
- GitHub dependency caching docs state cache misses automatically create a cache after a successful job, default-branch caches are available to other branches, low-trust workflows can use `actions/cache/restore` for explicit restore-only behavior, and caches are not signed or verified. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching]
- Do not cache secrets, tokens, credentials, support content, or generated artifacts that could leak sensitive data; the official docs say anyone able to open a PR can read base-branch cache contents. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching]

## Recommended Planning Shape

### Plan 1: Action Runtime Refresh and Contract Tests

Scope this as a narrow workflow/test change. Update first-party action majors to the official current majors where no incompatibility is found, keep `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`, reject stale Node variables, and add DB-free tests:

- `test/cairnloop/ci_workflow_contract_test.exs` should assert triggers, read-only workflow permissions, PR cancellation only, Node 24 posture, action majors, checkout credential opt-out, job names, lane commands, cache summary lines, E2E artifact posture, and aggregate gate behavior. [VERIFIED: codebase `61-CONTEXT.md`; VERIFIED: codebase `test/cairnloop/demo_smoke_workflow_contract_test.exs`]
- `test/cairnloop/release_workflow_contract_test.exs` should assert trusted triggers only, read-only default permissions, job-scoped write permissions for release-please, `publish-hex` read-only permissions, checkout credential opt-out, exact SHA checkout, Hex token preflight, dry run, package tarball inspection, publish command, Hex info, HexDocs fetch, and the new release preflight. [VERIFIED: codebase `61-CONTEXT.md`; VERIFIED: codebase `.github/workflows/release-please.yml`]

### Plan 2: Evidence-Useful CI Summaries

Keep existing version/cache summaries, then add bounded timing evidence that does not expose secrets or support content:

- Total lane duration for `fast`, `quality`, `integration`, and `e2e`. [VERIFIED: codebase `61-CONTEXT.md`]
- Fast-lane slowest headless tests, preferably from a focused second command only if the extra run stays cheap; otherwise put slowest-test profiling in manual/scheduled diagnostics. [VERIFIED: codebase `docs/ci-cd-audit.md`]
- E2E phase timings for dependency install, Playwright install, setup/migrate, and browser tests. [VERIFIED: codebase `61-CONTEXT.md`]
- Cache-hit values plus enough context to identify `_build` cache value before removing it. [VERIFIED: codebase `docs/ci-cd-audit.md`; CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching]

### Plan 3: Gate Topology and Low-Signal Work

Preserve `fast`, `quality`, `integration`, and one stable aggregate gate as default PR/main release-trust checks. [VERIFIED: codebase `61-CONTEXT.md`] Path-gate E2E on PRs to example app, web/dashboard/static CSS/assets, E2E tests, package/browser workflow files, and other workflow-relevant changes; run E2E on `main` and manual dispatch. [VERIFIED: codebase `61-CONTEXT.md`; VERIFIED: codebase `docs/ci-cd-audit.md`]

Demote demo-smoke PR triggers away from broad `lib/**` and `priv/**` unless the planner identifies a demo-only risk not covered by normal CI or E2E; keep demo smoke for wrapper, Docker, example, adopter docs, schedule, manual dispatch, and release validation. [VERIFIED: codebase `61-CONTEXT.md`; VERIFIED: codebase `.github/workflows/demo-smoke.yml`]

### Plan 4: Release Publish Preflight

Add a pre-publish quality proof on the exact release SHA before `mix hex.publish --yes`. Prefer `mix ci.quality` because it already includes locked deps, unused-dep check, warnings-as-errors compile, Credo strict, Hex build, docs warnings-as-errors, and dependency audit. [VERIFIED: codebase `mix.exs`; VERIFIED: codebase `61-CONTEXT.md`]

If executor proves `mix ci.quality` duplicates too much work, create a small `ci.release` alias with the same release-relevant docs/package/audit guarantees; do not weaken the existing dry-run, tarball inspection, `mix hex.info`, or `mix hex.docs fetch` steps. [VERIFIED: codebase `.github/workflows/release-please.yml`; VERIFIED: codebase `docs/ci-cd-audit.md`]

### Plan 5: Artifact Usefulness

Make Playwright artifacts useful or delete the upload step. The current `e2e` job sets `PW_TRACE: "false"` while uploading `examples/cairnloop_example/traces/` on failure; either enable trace/screenshot capture with `retention-days: 3` or remove the artifact step until traces are intentionally generated. [VERIFIED: codebase `.github/workflows/ci.yml`; VERIFIED: codebase `61-CONTEXT.md`; CITED: https://github.com/actions/upload-artifact/releases]

## Implementation Risks and Mitigations

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Upgrading action majors silently changes behavior. | Checkout/cache/upload-artifact have newer current majors than local workflow pins. [VERIFIED: GitHub API; VERIFIED: codebase `.github/workflows/ci.yml`] | Change one workflow family at a time and lock action majors/runtime posture with DB-free contract tests. |
| Path-gating E2E breaks branch protection because skipped jobs are treated like failure. | `release_gate` currently requires `needs.e2e.result == "success"`. [VERIFIED: codebase `.github/workflows/ci.yml`] | Update aggregate gate logic to accept intentional skip but fail `failure`, `cancelled`, or unexpected missing states. |
| Removing `_build` caches prematurely makes CI slower. | Local forced compile is only 2.67s, but live GitHub cache restore/save time is unknown. [VERIFIED: codebase `docs/ci-cd-audit.md`] | Add timing/cache evidence first; remove `_build` caches only after real data shows low value. |
| Cache writes from untrusted contexts increase supply-chain surface. | GitHub warns caches are not signed or verified and low-trust cache writes can be restricted. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching; CITED: https://github.blog/changelog/2026-06-26-read-only-actions-cache-for-untrusted-triggers/] | Keep privileged PR triggers out, keep cache keys narrow, avoid secrets in cache paths, and consider restore-only for PR jobs if it stays readable. |
| Release publish relies on private branch-protection settings. | Branch-protection settings are not visible from local source. [VERIFIED: codebase `docs/ci-cd-audit.md`] | Add source-visible release-SHA preflight before publish and document branch protection as an assumption, not the only safety mechanism. |
| Release secrets leak to untrusted code. | `HEX_API_KEY` must never be reachable from PR code. [VERIFIED: codebase `61-CONTEXT.md`; CITED: https://docs.github.com/en/actions/reference/security/secure-use] | Keep release workflow on trusted `main`/manual contexts, avoid `pull_request_target`, and keep `publish-hex` gated on `release_created == 'true'`. |
| Workflow contract tests become brittle string snapshots. | Existing source-scan tests are useful when scoped to public/release contracts but can become stale if they over-pin formatting. [VERIFIED: codebase `docs/software-quality-evaluation.md`] | Assert security/topology/command contracts and simple path lists; avoid pinning incidental whitespace outside block extraction helpers. |
| Playwright artifacts upload empty or sensitive content. | Current trace upload likely empty with `PW_TRACE: "false"`; excessive artifacts can leak debugging data. [VERIFIED: codebase `.github/workflows/ci.yml`; VERIFIED: codebase `61-CONTEXT.md`] | Enable only failure-scoped traces/screenshots with short retention, or remove upload; never cache or upload secrets/support content. |

## Validation Architecture

### Validation Dimensions

| Dimension | What to prove | Suggested automated check |
| --- | --- | --- |
| Action runtime freshness | Maintained action majors and Node 24 posture are locked. | `mix test test/cairnloop/ci_workflow_contract_test.exs test/cairnloop/release_workflow_contract_test.exs` |
| Least privilege | Workflow defaults stay read-only; only `release-please` has write permissions; checkouts opt out of persisted credentials. | Source-contract assertions against `.github/workflows/*.yml` |
| Unsafe trigger absence | No `pull_request_target`, issue/comment release trigger, or untrusted PR code path gets release/write/package secrets. | Source-contract negative assertions |
| Gate topology | `fast`, `quality`, `integration`, and aggregate gate stay stable; optional E2E skip is accepted only when deliberate. | Source-contract assertions plus CI PR run inspection after merge |
| Cache/timing evidence | Step summaries expose versions, cache hits, lane durations, slowest headless tests or profile lane, and E2E phase timings. | Source-contract assertions for summary blocks; live CI run check |
| Release preflight | `publish-hex` proves checked-out release SHA with quality/package/docs/dry-run checks before publish. | Source-contract assertions plus `mix ci.quality` locally |
| Artifact usefulness | E2E either emits failure-only traces/screenshots with short retention or has no empty upload ritual. | Source-contract assertions and one induced/focused failure if feasible |
| Local reproducibility | Contributor commands stay aligned with workflow semantics. | `mix ci.fast`, `mix ci.integration`, `mix ci.quality`; update README/CONTRIBUTING only if semantics change |

### Concrete Commands for the Executor

Run these after workflow/test changes:

```bash
mix format --check-formatted
mix test test/cairnloop/demo_smoke_workflow_contract_test.exs
mix test test/cairnloop/ci_workflow_contract_test.exs test/cairnloop/release_workflow_contract_test.exs
mix ci.fast
mix ci.integration
mix ci.quality
```

Run these when the changed surface justifies them:

```bash
cd examples/cairnloop_example && mix test.e2e
./bin/demo smoke
mix test --exclude integration --slowest 20 --warnings-as-errors
MIX_ENV=test mix compile --force --profile time --warnings-as-errors
mix xref graph --format cycles --label compile-connected
```

Post-merge or PR validation should confirm `CI / fast`, `CI / quality`, `CI / integration`, and the aggregate gate pass; E2E and demo smoke should run only on intended paths or trusted main/manual contexts if path-gating is implemented. [VERIFIED: codebase `docs/ci-cd-audit.md`; VERIFIED: codebase `61-CONTEXT.md`]

### Wave 0 Test Gaps

- Add `test/cairnloop/ci_workflow_contract_test.exs` for CI workflow runtime, permissions, concurrency, action majors, cache evidence, E2E topology, and aggregate-gate behavior. [VERIFIED: codebase `61-CONTEXT.md`]
- Add `test/cairnloop/release_workflow_contract_test.exs` for release workflow trusted triggers, scoped permissions, release action version, publish gate, SHA checkout, preflight, dry-run, package inspection, and post-publish verification. [VERIFIED: codebase `61-CONTEXT.md`]
- Keep `test/cairnloop/demo_smoke_workflow_contract_test.exs` as the model and update it only if demo-smoke path filters/action majors intentionally change. [VERIFIED: codebase `test/cairnloop/demo_smoke_workflow_contract_test.exs`]

## Sources

### Local Sources

- `CLAUDE.md` - repo instructions, build/test conventions, decision policy. [VERIFIED: codebase]
- `AGENTS.md` - repo agent instructions. [VERIFIED: codebase]
- `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md` - vM019/Phase 61 scope and requirements. [VERIFIED: codebase]
- `.planning/phases/61-ci-cd-efficiency-and-release-confidence/61-CONTEXT.md` - locked decisions D-01 through D-18. [VERIFIED: codebase]
- `docs/ci-cd-audit.md` - local CI/CD audit, baseline timings, proposed pipeline, validation plan. [VERIFIED: codebase]
- `docs/software-quality-evaluation.md` - quality ranking and CI/CD risk context. [VERIFIED: codebase]
- `.github/workflows/ci.yml`, `.github/workflows/demo-smoke.yml`, `.github/workflows/release-please.yml`, `.github/dependabot.yml` - current workflow and Dependabot state. [VERIFIED: codebase]
- `mix.exs`, `README.md`, `CONTRIBUTING.md`, `test/cairnloop/demo_smoke_workflow_contract_test.exs` - local command split, contributor guidance, and source-contract test pattern. [VERIFIED: codebase]

### External Official Sources

- GitHub Actions Node 20 deprecation and Node 24 transition, published 2025-09-19 and updated 2026-02-25 / 2026-05-19: https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/ [CITED]
- Read-only Actions cache for untrusted triggers, published 2026-06-26: https://github.blog/changelog/2026-06-26-read-only-actions-cache-for-untrusted-triggers/ [CITED]
- Safer `pull_request_target` defaults for checkout, published 2026-06-18: https://github.blog/changelog/2026-06-18-safer-pull_request_target-defaults-for-github-actions-checkout/ [CITED]
- `actions/checkout` releases and raw `action.yml` / README for v6.0.3 and v7.0.0: https://github.com/actions/checkout/releases [CITED]
- `actions/setup-node` releases and raw v6.4.0 `action.yml` / README: https://github.com/actions/setup-node/releases [CITED]
- `actions/cache` releases and raw v5.1.0 / v6.1.0 action metadata: https://github.com/actions/cache/releases [CITED]
- `actions/upload-artifact` releases and raw v6.0.0 / v7.0.1 action metadata: https://github.com/actions/upload-artifact/releases [CITED]
- `googleapis/release-please-action` releases and raw v5.0.0 action metadata: https://github.com/googleapis/release-please-action/releases [CITED]
- GitHub Actions secure-use reference: https://docs.github.com/en/actions/reference/security/secure-use [CITED]
- GitHub dependency caching reference: https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching [CITED]

### Assumptions and Open Questions

- Branch protection settings and required checks were not inspectable from local source, so release preflight must not depend solely on those settings. [VERIFIED: codebase `docs/ci-cd-audit.md`]
- Live GitHub cache transfer duration, job wall-clock timing, E2E duration, and Docker smoke duration remain unknown until a workflow run records them. [VERIFIED: codebase `docs/ci-cd-audit.md`]
- Self-hosted runner support is out of scope unless Cairnloop starts targeting self-hosted runners; official action runner minimums should still be documented if action major upgrades mention them. [VERIFIED: codebase `61-CONTEXT.md`; CITED: https://github.com/actions/cache/releases]
