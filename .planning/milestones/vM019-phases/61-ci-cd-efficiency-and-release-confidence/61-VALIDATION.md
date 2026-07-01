---
phase: 61
slug: ci-cd-efficiency-and-release-confidence
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-30
---

# Phase 61 - Validation Strategy

Per-phase validation contract for CI/CD efficiency and release-confidence work.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit source-contract tests plus Mix CI aliases |
| **Config file** | `mix.exs`, `.github/workflows/*.yml` |
| **Quick run command** | `mix test test/cairnloop/demo_smoke_workflow_contract_test.exs test/cairnloop/ci_workflow_contract_test.exs test/cairnloop/release_workflow_contract_test.exs` |
| **Full suite command** | `mix ci.fast && mix ci.integration && mix ci.quality` |
| **Estimated runtime** | Quick: under 15s; full suite: environment dependent |

## Sampling Rate

- **After every task commit:** Run the quick workflow-contract test command when workflow/test files changed.
- **After every plan wave:** Run `mix ci.fast`; add `mix ci.integration` or `mix ci.quality` when the wave touches DB-backed, package, docs, or release-preflight behavior.
- **Before `/gsd:verify-work`:** `mix ci.fast`, `mix ci.integration`, and `mix ci.quality` must be green or documented as blocked by the known workspace Repo caveat.
- **Max feedback latency:** Keep the default task-level feedback loop under 60 seconds with DB-free source-contract tests.

## Per-Requirement Verification Map

| Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| CI-02 | T-61-01 | Current maintained action majors and official Node 24 posture are source-locked; stale transition variables are rejected. | source-contract | `mix test test/cairnloop/ci_workflow_contract_test.exs test/cairnloop/release_workflow_contract_test.exs` | No - Wave 0 creates | pending |
| CI-03 | T-61-02 | Workflow defaults remain read-only; only release-please gets write permissions; checkout credentials are not persisted. | source-contract | `mix test test/cairnloop/ci_workflow_contract_test.exs test/cairnloop/release_workflow_contract_test.exs` | No - Wave 0 creates | pending |
| CI-04 | T-61-03 | CI summaries expose bounded timing, cache, runtime, and failure evidence without secrets or support content. | source-contract plus CI run inspection | `mix test test/cairnloop/ci_workflow_contract_test.exs` | No - Wave 0 creates | pending |
| CI-05 | T-61-04 | Low-signal duplicate E2E/demo smoke work is path-gated without weakening the aggregate required gate. | source-contract | `mix test test/cairnloop/ci_workflow_contract_test.exs test/cairnloop/demo_smoke_workflow_contract_test.exs` | Partial - demo contract exists | pending |
| CI-06 | T-61-05 | Publish workflow verifies exact release SHA, Hex token preflight, dry run, package/docs checks, and post-publish proof before irreversible publish. | source-contract plus quality lane | `mix test test/cairnloop/release_workflow_contract_test.exs && mix ci.quality` | No - Wave 0 creates | pending |

## Wave 0 Requirements

- [ ] `test/cairnloop/ci_workflow_contract_test.exs` - DB-free source-contract coverage for CI workflow permissions, action majors, Node 24 posture, job topology, cache/timing evidence, E2E path-gate behavior, and aggregate gate semantics.
- [ ] `test/cairnloop/release_workflow_contract_test.exs` - DB-free source-contract coverage for trusted triggers, release-please write scope, publish job read-only posture, exact SHA checkout, Hex token preflight, dry run, package inspection, release preflight, and Hex/HexDocs verification.
- [ ] `test/cairnloop/demo_smoke_workflow_contract_test.exs` - update only for intentional demo-smoke path-filter or action-major changes.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live GitHub cache transfer time and job wall clock | CI-04 | Local source can assert summary collection, but not hosted-runner timing. | Inspect the next PR/main workflow summary and compare lane/cache timing before removing `_build` cache. |
| GitHub branch-protection required checks | CI-05, CI-06 | Private repository settings are outside local source control. | Confirm the aggregate gate remains the stable required check after workflow changes land. |
| Release publish from trusted refs | CI-06 | Real publishing is irreversible and should not be executed locally. | Review the release workflow source contract and rely on dry-run/package/docs checks before real publish. |

## Validation Sign-Off

- [x] All requirements have automated source-contract coverage or explicit manual-only justification.
- [x] Sampling continuity: no three consecutive implementation tasks should lack an automated verification command.
- [x] Wave 0 covers all missing workflow-contract test files.
- [x] No watch-mode flags.
- [x] Feedback latency target under 60 seconds for DB-free source-contract checks.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-06-30
