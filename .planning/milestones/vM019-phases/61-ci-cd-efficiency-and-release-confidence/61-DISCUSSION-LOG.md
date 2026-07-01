# Phase 61: CI/CD Efficiency and Release Confidence - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-06-30
**Phase:** 61-CI/CD Efficiency and Release Confidence
**Areas discussed:** Action runtime, Gate topology, Timing and caches, Release confidence, Artifacts and guardrails

---

## Action Runtime

| Option | Description | Selected |
|--------|-------------|----------|
| Keep local audit majors unchanged | Treat the 2026-06-29 audit as the final source of action versions. | |
| Refresh from primary sources and lock tests | Re-check GitHub action release/changelog sources during implementation, update current maintained majors, and pin the chosen posture in source-contract tests. | ✓ |
| Defer all action version work | Only document that versions may need future refresh. | |

**User's choice:** Claude auto-selected per `CLAUDE.md` decision policy.
**Notes:** Current action/runtime facts are time-sensitive. Primary-source refresh is required before planning/execution.

---

## Gate Topology

| Option | Description | Selected |
|--------|-------------|----------|
| Keep all jobs unconditional | Keep fast, quality, integration, E2E, and demo smoke broad on every PR. | |
| Stable core gate plus path-gated expensive jobs | Keep fast/quality/integration always required, path-gate E2E and Docker smoke where they provide signal, and make the aggregate gate handle skipped optional jobs. | ✓ |
| Aggressively remove expensive jobs | Drop browser/Docker proof from PR and release flows. | |

**User's choice:** Claude auto-selected per `CLAUDE.md` decision policy.
**Notes:** This preserves release trust while reducing low-signal runner time.

---

## Timing and Caches

| Option | Description | Selected |
|--------|-------------|----------|
| Remove `_build` caches now | Use the local 2.7s compile baseline as enough proof to drop build caches immediately. | |
| Add timing evidence first | Publish lane timing, cache hits, slowest tests, and E2E phase timing before removing caches. | ✓ |
| Keep all caches permanently | Preserve current cache complexity regardless of evidence. | |

**User's choice:** Claude auto-selected per `CLAUDE.md` decision policy.
**Notes:** The project values evidence-backed CI changes; no blind cache removal.

---

## Release Confidence

| Option | Description | Selected |
|--------|-------------|----------|
| Trust branch protection only | Assume release PR auto-merge proves the release SHA already passed required CI. | |
| Add publish preflight | Run `mix ci.quality` or an equivalent compact release preflight on the exact release SHA before `mix hex.publish --yes`. | ✓ |
| Disable automated publishing | Keep release PRs but make Hex publish fully manual. | |

**User's choice:** Claude auto-selected per `CLAUDE.md` decision policy.
**Notes:** Branch protection settings are not visible from local source. A release preflight is cheap compared with a bad Hex publish.

---

## Artifacts and Guardrails

| Option | Description | Selected |
|--------|-------------|----------|
| Keep empty trace upload | Leave `PW_TRACE=false` while uploading traces on failure. | |
| Make artifacts useful | Enable trace/screenshot capture with short retention, or remove the upload if overhead is too high. | ✓ |
| Add broad artifact collection | Upload large logs/artifacts from every job. | |

**User's choice:** Claude auto-selected per `CLAUDE.md` decision policy.
**Notes:** Failure evidence should be bounded and useful; empty artifact steps do not help maintainers.

---

## Claude's Discretion

- No owner question was escalated. The repo instruction says GSD discuss-phase should decide ordinary
  trust-sensitive implementation calls and surface only genuinely expensive or irreversible choices.
- The selected decisions are reversible workflow/test/doc changes that align with the roadmap and
  prior audit evidence.

## Deferred Ideas

- Full SHA pinning of all actions with automated SHA update management.
- Self-hosted runner support beyond documenting official runner minimums.
- Live branch-protection or organization-level Actions policy inspection from private GitHub settings.
