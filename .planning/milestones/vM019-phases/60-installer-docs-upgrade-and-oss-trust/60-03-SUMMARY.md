---
phase: 60-installer-docs-upgrade-and-oss-trust
plan: "03"
subsystem: docs-package-security
tags: [docs, package, exdoc, changelog, security, guide-assets, source-scan]
requires:
  - phase: 60-installer-docs-upgrade-and-oss-trust
    provides: "60-01 DB-free docs/package/security source-scan guardrails"
provides:
  - "JTBD walkthrough asset reference corrected to tracked operator inbox screenshot"
  - "mix.exs package files, ExDoc extras, guide assets, and quality aliases aligned with public docs"
  - "CHANGELOG Unreleased entry and compare anchor aligned to v0.5.1"
  - "SECURITY.md public OSS vulnerability reporting policy with route/auth exposure detail"
affects: [phase-60, docs-truth, package, exdoc, security-policy, changelog]
tech-stack:
  added: []
  patterns:
    - "Source-scan tests prove package, ExDoc, changelog, guide-asset, and security policy truth"
    - "Guide assets stay outside package[:files] and are routed through ExDoc assets"
key-files:
  created:
    - .planning/phases/60-installer-docs-upgrade-and-oss-trust/60-03-SUMMARY.md
  modified:
    - guides/02-jtbd-walkthrough.md
    - SECURITY.md
    - CHANGELOG.md
    - mix.exs
    - test/cairnloop/docs/security_policy_test.exs
    - test/cairnloop/web/collateral_wiring_test.exs
key-decisions:
  - "Use the existing guides/assets/02b-operator-inbox.png screenshot instead of adding or regenerating guide assets."
  - "Keep mix.exs as the source of truth for package files, ExDoc extras/assets, and docs/package quality aliases."
  - "Keep SECURITY.md concise and public-facing; no internal phase artifact, compliance claims, or guaranteed response SLA."
patterns-established:
  - "Security policy source scans should include route/auth exposure as a required vulnerability report detail."
requirements-completed: [DOC-03, DOC-04, DOC-06]
requirements-addressed: [DOC-03, DOC-04, DOC-06]
duration: 4 min
completed: 2026-06-30
status: complete
---

# Phase 60 Plan 03: Package Docs and Security Policy Summary

**Package metadata, ExDoc assets, changelog trust links, JTBD guide assets, and SECURITY.md now match the current public v0.5.1 docs surface.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-06-30T19:20:32Z
- **Completed:** 2026-06-30T19:24:02Z
- **Tasks:** 3
- **Files modified:** 6 plus this summary

## Accomplishments

- Retargeted the JTBD walkthrough operator inbox screenshot from the missing `assets/02-operator-inbox.png` to tracked `assets/02b-operator-inbox.png`.
- Updated CHANGELOG with an Unreleased docs/package/security trust note and moved the Unreleased compare anchor from `v0.2.0` to `v0.5.1`.
- Aligned `mix.exs` package files and ExDoc extras/assets with the public docs set, and updated the collateral package allowlist guardrail.
- Replaced the internal SECURITY verification artifact with a concise public OSS security policy.
- Tightened the security policy source scan to require route/auth exposure details in vulnerability reports.

## Task Commits

1. **Task 1: Fix JTBD walkthrough asset truth** - `e6b18c7` (docs)
2. **Task 2: Align mix.exs package/ExDoc surface and changelog trust metadata** - `dbf4ead` (docs)
3. **Task 3 RED: Add security route exposure guardrail** - `5ad4a5d` (test)
4. **Task 3 GREEN: Polish SECURITY.md as a public OSS policy** - `0f6dd29` (docs)

**Plan metadata:** this summary commit.

## Files Created/Modified

- `guides/02-jtbd-walkthrough.md` - Uses the existing `assets/02b-operator-inbox.png` operator inbox screenshot.
- `CHANGELOG.md` - Adds an Unreleased trust note and current `v0.5.1...HEAD` compare link.
- `mix.exs` - Ships public docs/guides through package files and ExDoc extras/assets; exposes `ci.fast`, `ci.integration`, and `ci.quality` aliases.
- `test/cairnloop/web/collateral_wiring_test.exs` - Mirrors the explicit public docs package allowlist and keeps `guides/assets` out of package files.
- `test/cairnloop/docs/security_policy_test.exs` - Adds the route/auth exposure reporting assertion.
- `SECURITY.md` - Public vulnerability reporting policy with supported-version posture, private reporting, host responsibilities, sensitive areas, and bounded response posture.

## Verification

- `mix test test/cairnloop/docs/package_docs_truth_test.exs --warnings-as-errors` - pass, 7 tests, 0 failures.
- `mix test test/cairnloop/docs/security_policy_test.exs --warnings-as-errors` - pass, 4 tests, 0 failures.
- `mix test test/cairnloop/docs/package_docs_truth_test.exs test/cairnloop/web/collateral_wiring_test.exs --warnings-as-errors` - pass, 16 tests, 0 failures.
- `mix test test/cairnloop/docs/package_docs_truth_test.exs test/cairnloop/docs/security_policy_test.exs test/cairnloop/web/collateral_wiring_test.exs --warnings-as-errors` - pass, 20 tests, 0 failures.
- Task 3 RED check: `mix test test/cairnloop/docs/security_policy_test.exs --warnings-as-errors` failed as expected before the SECURITY.md update because `route/auth exposure` was missing.

Per plan instructions, `mix ci.quality` was not run in this Wave 1 plan; Plan 60-04 owns the final post-Wave quality gates.

## Decisions Made

- Used the existing 02b screenshot rather than adding image generation, screenshot capture tooling, or a new asset file.
- Treated `mix.exs` as authoritative for package files and ExDoc public docs rather than duplicating a separate package manifest.
- Kept SECURITY.md focused on practical OSS reporting and host responsibilities, without enterprise process language.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Corrected CHANGELOG during Task 1 package guardrail**
- **Found during:** Task 1 (Fix JTBD walkthrough asset truth)
- **Issue:** The required `package_docs_truth_test` command failed on both the missing guide asset and the stale CHANGELOG Unreleased compare anchor. Task 2 listed the changelog action, but Task 1's acceptance gate required the whole package docs test to pass before continuing.
- **Fix:** Updated the guide asset reference and the CHANGELOG Unreleased entry/compare anchor in the Task 1 commit.
- **Files modified:** `guides/02-jtbd-walkthrough.md`, `CHANGELOG.md`
- **Verification:** `mix test test/cairnloop/docs/package_docs_truth_test.exs --warnings-as-errors`
- **Committed in:** `e6b18c7`

---

**Total deviations:** 1 auto-fixed (Rule 3: 1).
**Impact on plan:** No scope expansion; the changelog was already plan-owned and required for the shared package docs guardrail.

## Issues Encountered

- The worktree had extensive pre-existing dirty files. Only plan-owned files were staged and committed.
- Another executor committed `acb88f6` for Plan 60-02 while this plan was running. The interleaved commit was left intact and is not counted as a 60-03 task commit.
- `.planning/STATE.md` remained dirty from shared orchestration context. It was not modified, staged, or committed by this plan per the execution-mode instruction.

## Known Stubs

None. Stub scan hits were intentional empty-list assertions inside source-scan tests, not UI/data stubs.

## Threat Flags

None. This plan changed public docs, package metadata, changelog metadata, and DB-free source scans only; it introduced no new endpoint, runtime auth path, schema boundary, or network/file-access surface.

## User Setup Required

None.

## Next Phase Readiness

Ready for Plan 60-04 to run the final post-Wave package/docs quality gates after Plan 60-02 finishes converging the install and upgrade docs.

## Self-Check: PASSED

- Found all modified plan files and this summary on disk.
- Found task commits `e6b18c7`, `dbf4ead`, `5ad4a5d`, and `0f6dd29` in git history.
- Verified the three required plan-level focused commands are green.
- Verified `.planning/STATE.md` and `.planning/ROADMAP.md` were not staged by this plan.

---
*Phase: 60-installer-docs-upgrade-and-oss-trust*
*Completed: 2026-06-30*
