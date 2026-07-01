---
phase: 60-installer-docs-upgrade-and-oss-trust
plan: "01"
subsystem: docs-testing
tags: [docs, installer, package, exdoc, security, source-scan, guardrails]
requires:
  - phase: 58-identity-ingress-and-side-effect-trust
    provides: Email/MCP ingress, doctor, liveness, and trust-docs truth
  - phase: 59-dedicated-postgres-schema-contract
    provides: Dedicated-schema default, explicit public compatibility, installer, and example-app prefix proof
provides:
  - DB-free install and upgrade docs source-scan guardrail
  - DB-free package, ExDoc, version, changelog, and guide-asset guardrail
  - DB-free public SECURITY.md policy guardrail
affects: [phase-60, docs-truth, installer, package, exdoc, security-policy]
tech-stack:
  added: []
  patterns:
    - ExUnit source scans read Markdown and source files with File.read!/1
    - Package/docs tests use git ls-files via System.cmd/3 instead of shell pipelines
key-files:
  created:
    - test/cairnloop/docs/install_upgrade_truth_test.exs
    - test/cairnloop/docs/package_docs_truth_test.exs
    - test/cairnloop/docs/security_policy_test.exs
    - .planning/phases/60-installer-docs-upgrade-and-oss-trust/60-01-SUMMARY.md
  modified: []
key-decisions:
  - "60-01 keeps Wave 0 guardrails red where current public docs/package drift is real; later Phase 60 plans own docs convergence."
  - "SECURITY.md already satisfies the public OSS policy shape and is pinned by a passing DB-free source scan."
patterns-established:
  - "Docs truth tests should fail on exact stale public instructions before public docs are rewritten."
  - "Guide asset references are validated from tracked Markdown without browser or ExDoc startup."
requirements-completed: [DOC-01, DOC-02, DOC-03, DOC-04, DOC-05, DOC-06]
requirements-addressed: [DOC-01, DOC-02, DOC-03, DOC-04, DOC-05, DOC-06]
duration: 10 min
completed: 2026-06-30
status: complete
---

# Phase 60 Plan 01: Docs Guardrail Tests Summary

**DB-free source-scan guardrails now pin installer, package, ExDoc, asset, changelog, and SECURITY.md truth before public docs are rewritten.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-06-30T19:06:25Z
- **Completed:** 2026-06-30T19:15:52Z
- **Tasks:** 3
- **Files modified:** 3 test files plus this summary

## Accomplishments

- Added `Cairnloop.Docs.InstallUpgradeTruthTest` for README, Quickstart, Host Integration, Troubleshooting, UPGRADING, example README, installer, and version truth.
- Added `Cairnloop.Docs.PackageDocsTruthTest` for package files, ExDoc extras/assets, version snippets, guide asset references, JTBD walkthrough asset target, and changelog compare anchor.
- Added `Cairnloop.Docs.SecurityPolicyTest` to keep `SECURITY.md` public-facing, private-reporting oriented, host-responsibility aware, and free of internal/compliance/SLA ceremony.

## Task Commits

1. **Task 1: Add install and upgrade truth source-scan tests** - `b8a1a6f` (test)
2. **Task 2: Add package, ExDoc, version, and asset truth source-scan tests** - `8dc982a` (test)
3. **Task 3: Add public security policy source-scan tests** - `f8f0fca` (test)

**Plan metadata:** this summary commit.

## Files Created/Modified

- `test/cairnloop/docs/install_upgrade_truth_test.exs` - DB-free installer/install/upgrade docs truth guardrail.
- `test/cairnloop/docs/package_docs_truth_test.exs` - DB-free package/ExDoc/version/asset/changelog truth guardrail.
- `test/cairnloop/docs/security_policy_test.exs` - DB-free public security policy guardrail.

## Verification

- `mix test test/cairnloop/docs/install_upgrade_truth_test.exs --warnings-as-errors` - expected red: 7 tests, 3 failures. Failures are current docs drift only: missing "When not to use Cairnloop"; stale `schema_prefix: nil` compatibility wording in README, Quickstart, and Troubleshooting; forbidden dependency migration `--prefix cairnloop` in README, Quickstart, and Troubleshooting.
- `mix test test/cairnloop/docs/package_docs_truth_test.exs --warnings-as-errors` - expected red: 7 tests, 3 failures. Failures are current package/docs drift only: `guides/02-jtbd-walkthrough.md` still references `assets/02-operator-inbox.png` instead of existing `assets/02b-operator-inbox.png`; Markdown asset scan reports the missing asset; `[Unreleased]` compare link is still anchored to an old release instead of `v0.5.1`.
- `mix test test/cairnloop/docs/security_policy_test.exs --warnings-as-errors` - pass: 4 tests, 0 failures.
- `mix test test/cairnloop/docs/install_upgrade_truth_test.exs test/cairnloop/docs/package_docs_truth_test.exs test/cairnloop/docs/security_policy_test.exs --warnings-as-errors` - expected red: 18 tests, 6 failures, matching the intended install/package docs drift above.
- `mix compile --warnings-as-errors` - pass.

## Decisions Made

- Kept this plan test-only. No public docs, package metadata, SECURITY, STATE, or ROADMAP files were changed.
- Treated the install/package failures as expected Wave 0 evidence because later Phase 60 plans own docs convergence.
- Kept SECURITY.md assertions modest and source-backed; the current policy passes without requiring ceremonial enterprise claims.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Task 1 initially had a brittle UPGRADING assertion for `Oban remains host-owned`; the source already contained the claim across a line wrap, so the test was narrowed before commit.
- Task 3 initially had line-wrap brittle assertions for `working exploit details` and `route authentication`; the test was narrowed before commit.
- The worktree had pre-existing unrelated dirty files, including `.planning/STATE.md`. They were left unstaged.

## Known Stubs

None. Stub scan hits were limited to intentional test assertions such as `assert missing == []`; no UI/data stub was introduced.

## Threat Flags

None. This plan added DB-free test files only; no new endpoint, auth path, runtime file access surface, or schema boundary was introduced.

## User Setup Required

None.

## Next Phase Readiness

Ready for 60-02 and 60-03 to turn the intended red guardrails green by rewriting public install/upgrade docs, retargeting the JTBD asset reference, and correcting package/changelog trust drift.

## Self-Check: PASSED

- Found all three created test files on disk.
- Found task commits `b8a1a6f`, `8dc982a`, and `f8f0fca` in git history.
- Verified `.planning/STATE.md` and `.planning/ROADMAP.md` were not edited or staged by this plan.

---
*Phase: 60-installer-docs-upgrade-and-oss-trust*
*Completed: 2026-06-30*
