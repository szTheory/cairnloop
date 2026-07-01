---
milestone: vM018
milestone_name: Demo DX Adoption Proof
audited: 2026-06-28T23:31:17Z
status: tech_debt
audit_kind: final-milestone
scores:
  requirements: "17/17 satisfied"
  phases: "4/4 complete"
  phase_verifications: "4/4 present"
  integration: "17/17 checked; 0 blockers"
  flows: "8/8 checked; 0 blockers"
gaps:
  requirements: []
  integration: []
  flows: []
tech_debt:
  - phase: 55-docker-first-adopter-docs
    items:
      - "README.md first-run URL copy omits the Gaps and Suggestions routes from its high-level list even though the wrapper, Quickstart, example README, and Troubleshooting cover them."
  - phase: 53-demo-runtime-contract
    items:
      - "examples/cairnloop_example/mix.exs source comment still mentions stale Hex dependency '~> 0.1.0'; runtime dependency and adopter docs are correct."
  - phase: cross-phase-integration
    items:
      - "Demo index deep links rely on fresh-database insert order for /support/1 and /support/17..20; current seed order is stable for the Docker fresh-clone path, but future seed changes need a guard that those IDs resolve to the intended demo-01 and demo-17..20 conversations."
      - "/health is a static liveness probe. Startup ordering and smoke route checks prove the demo flow, but future consumers should not treat /health alone as database or dashboard readiness."
      - "./bin/demo smoke is intentionally HTTP route coverage rather than browser automation; JS-only regressions remain outside the smoke lane by design."
  - phase: 56-demo-smoke-ci-gate
    items:
      - "56-VALIDATION.md is still draft / nyquist_compliant:false despite 56-VERIFICATION.md passing the workflow contract, fast CI, Compose config, and Docker smoke evidence."
nyquist:
  overall: partial
  compliant_phases: ["53", "54", "55"]
  partial_phases: ["56"]
  missing_phases: []
notes:
  - "Installed gsd-tools exposes query handlers only; workflow hook discovery command 'loop render-hooks verify:post --raw' is unavailable in this workspace. Nyquist was scanned because validation artifacts are present and no disable switch exists in .planning/config.json."
  - "Integration checker returned passed: no cross-phase wiring gaps, no broken flows, and no requirements affected by gaps."
---

# vM018 Demo DX Adoption Proof - Milestone Audit

**Audited:** 2026-06-28T23:31:17Z
**Status:** `tech_debt`
**Verdict:** Ready to complete if the owner accepts minor copy/comment/process debt. No unsatisfied requirements, orphaned requirements, missing phase verifications, cross-phase blockers, or broken first-run flows were found.

## Executive Result

vM018 achieved its definition of done: the Docker-backed demo path is now a reliable first-run adoption proof.

- 17 of 17 milestone requirements are checked in `.planning/REQUIREMENTS.md`.
- 17 of 17 requirements are marked `Complete` in `.planning/ROADMAP.md` traceability.
- 4 of 4 active phases are complete and have `*-VERIFICATION.md`.
- Every requirement appears in phase verification coverage and in at least one `requirements-completed` summary frontmatter entry.
- The integration checker verified the wrapper, Compose, runtime, docs, and CI chain and found no broken flows.
- The remaining debt is non-blocking: small copy/comment cleanup, demo-index hardening, precise `/health` semantics, HTTP-smoke scope, and stale Phase 56 validation metadata.

The audit status is `tech_debt` rather than `passed` because the remaining cleanup is visible and cheap to close, but it does not undermine the milestone requirements.

## Audit Inputs

| Source | Result |
|---|---|
| `gsd-tools query init.milestone-op` | Current milestone: `vM018 Demo DX Adoption Proof`; 4 phases; 4 complete. |
| `gsd-tools query phases.list` | Scope: phases 53, 54, 55, and 56. |
| `.planning/REQUIREMENTS.md` | 17/17 vM018 requirements checked. |
| `.planning/ROADMAP.md` | 17/17 requirements mapped to phases and marked `Complete`. |
| Phase `*-VERIFICATION.md` files | 4/4 present and passed. |
| `gsd-tools query summary-extract` over phase summaries | 17/17 requirements listed in completed plan summaries. |
| Integration checker | Passed; 17/17 requirements checked; no gaps; no broken flows. |
| Phase `*-VALIDATION.md` files | 4/4 present; phases 53, 54, and 55 compliant; phase 56 partial. |

## Requirements Coverage

All vM018 requirements are satisfied. No orphaned requirements were found.

| Requirement | Phase | Traceability | Verification | Summary Frontmatter | Final Status |
|---|---:|---|---|---|---|
| BOOT-01 | 54 | checked / Complete | passed in `54-VERIFICATION.md` | listed in `54-01` and `54-03` summaries | satisfied |
| BOOT-02 | 54 | checked / Complete | passed in `54-VERIFICATION.md` | listed in `54-01` and `54-03` summaries | satisfied |
| BOOT-03 | 54 | checked / Complete | passed in `54-VERIFICATION.md` | listed in `54-01`, `54-02`, and `54-03` summaries | satisfied |
| BOOT-04 | 54 | checked / Complete | passed in `54-VERIFICATION.md` | listed in `54-01`, `54-02`, and `54-03` summaries | satisfied |
| RUNT-01 | 53 | checked / Complete | passed in `53-VERIFICATION.md` | listed in `53-01`, `53-04`, and `53-05` summaries | satisfied |
| RUNT-02 | 53 | checked / Complete | passed in `53-VERIFICATION.md` | listed in `53-01` and `53-05` summaries | satisfied |
| RUNT-03 | 53 | checked / Complete | passed in `53-VERIFICATION.md` | listed in `53-03` and `53-05` summaries | satisfied |
| RUNT-04 | 53 | checked / Complete | passed in `53-VERIFICATION.md` | listed in `53-02`, `53-03`, and `53-05` summaries | satisfied |
| RUNT-05 | 53 | checked / Complete | passed in `53-VERIFICATION.md` | listed in `53-01`, `53-04`, and `53-05` summaries | satisfied |
| DOC-01 | 55 | checked / Complete | passed in `55-VERIFICATION.md` | listed in `55-01` summary | satisfied |
| DOC-02 | 55 | checked / Complete | passed in `55-VERIFICATION.md` | listed in `55-02` summary | satisfied |
| DOC-03 | 55 | checked / Complete | passed in `55-VERIFICATION.md` | listed in `55-03` summary | satisfied |
| DOC-04 | 55 | checked / Complete | passed in `55-VERIFICATION.md` | listed in `55-01`, `55-02`, and `55-03` summaries | satisfied |
| VER-01 | 54 | checked / Complete | passed in `54-VERIFICATION.md` | listed in `54-01` and `54-03` summaries | satisfied |
| VER-02 | 54 | checked / Complete | passed in `54-VERIFICATION.md` | listed in `54-01`, `54-02`, and `54-03` summaries | satisfied |
| VER-03 | 56 | checked / Complete | passed in `56-VERIFICATION.md` | listed in `56-01` summary | satisfied |
| VER-04 | 56 | checked / Complete | passed in `56-VERIFICATION.md` | listed in `56-01` summary | satisfied |

## Phase Verification Roll-Up

| Phase | Verification Status | Requirements | Audit Status | Notes |
|---:|---|---|---|---|
| 53 | passed | RUNT-01..05 | pass | Runtime, migrations, health, config, seeds, CI lanes, integration, quality, Docker smoke, and validation metadata are green. |
| 54 | passed | BOOT-01..04, VER-01..02 | pass | Wrapper, dynamic/private Compose contract, URL discovery, smoke diagnostics, cleanup, and final smoke evidence passed. |
| 55 | passed | DOC-01..04 | pass | Docker-first docs, route/source scans, package/docs quality, Compose config, Docker smoke evidence, and validation metadata passed. |
| 56 | passed | VER-03..04 | pass with process debt | Dedicated read-only workflow, path filters, source contract, and Docker smoke passed. `56-VALIDATION.md` remains stale. |

## Cross-Phase Integration

The integration checker found no blockers and no broken flows.

| Integration | Status | Evidence |
|---|---|---|
| Phase 53 runtime feeds Phase 54 wrapper. | PASS | `bin/demo` points at `examples/cairnloop_example/compose.demo.yml`; Dockerfile runs `mix setup && exec mix phx.server`; wrapper waits for `/health`. |
| Compose contract supports first-run adoption. | PASS | Postgres has no host port; web publishes on loopback with dynamic/default range; wrapper discovers the actual published port. |
| Wrapper discovers and prints actual runtime URLs. | PASS | `bin/demo` reads `docker compose port web 4000`, waits on `/health`, then prints demo index, operator cockpit, inbox, chat, KB, gaps, suggestions, audit log, settings, and health. |
| Wrapper smoke list matches mounted routes. | PASS | `mix phx.routes` shows the locked route set; `bin/demo smoke` checks those routes. |
| Wrapper/docs/CI use one canonical smoke path. | PASS | Docs mirror wrapper commands and route list; `.github/workflows/demo-smoke.yml` runs exactly `./bin/demo smoke`. |
| Setup, migrations, and seeds feed dashboard reads. | PASS | Integration checker verified setup-to-seed-to-dashboard wiring and seeded content on the printed routes. |
| Phase 56 CI consumes Phase 54 smoke contract. | PASS | The workflow delegates to `./bin/demo smoke` instead of duplicating Compose or curl logic. |

## End-to-End Flows

| Flow | Status | Evidence |
|---|---|---|
| Fresh clone Docker demo. | PASS | Wrapper -> Compose -> private Postgres -> `mix setup` -> migrations/seeds -> Phoenix -> `/health` -> printed URLs -> locked route smoke. |
| Dynamic port and private database boundary. | PASS | Compose publishes web on localhost range and does not publish Postgres; wrapper falls back across occupied ports and discovers the runtime port. |
| Wrapper URL/status/log/reset surface to docs. | PASS | Help output and docs align on `urls`, `logs`, `status/ps`, `stop`, `down`, `reset`, `smoke`, dynamic URLs, and volume semantics. |
| Seeded Trailmark click-through readiness. | PASS with hardening debt | Seed suite, integration checker seeded-content run, and Docker smoke passed; exact demo-index hard-coded ID correspondence is not independently guarded. |
| `/health` boot gate. | PASS with semantics debt | Strong enough when combined with Docker setup ordering and smoke; by itself it is liveness, not DB/seed readiness. |
| Phase 56 CI workflow to canonical smoke. | PASS | `.github/workflows/demo-smoke.yml` runs exactly `./bin/demo smoke` and covers wrapper, example, docs, source, Docker context, and workflow path changes. |
| Automated verification posture. | PASS | Phase verification uses source tests, fast CI, Compose config, Docker smoke, and workflow/docs contract tests; no human UAT checkpoint is required. |
| Browser-rendered behavior. | PASS with scope note | Existing repo E2E coverage remains separate; new demo smoke intentionally covers HTTP routes, not browser JS. |

## Tech Debt

| Item | Severity | Affected Requirements | Evidence | Recommendation |
|---|---|---|---|---|
| README high-level route copy omits Gaps and Suggestions from the listed printed URLs. | low | BOOT-03, DOC-04 | `README.md:20` starts the list; `bin/demo`, Quickstart, example README, and Troubleshooting include the full locked list. | Update README copy when convenient. No closure phase required. |
| Example source comment mentions stale Hex dependency `~> 0.1.0`. | low | RUNT-02 | `examples/cairnloop_example/mix.exs:45`; actual path dependency and adopter docs use the correct current story. | Update the comment to reference the current Hex dependency or remove the version. |
| Demo index tour links rely on seed insert order for `/support/1` and `/support/17..20`. | low/integration | RUNT-05, VER-01, VER-04 | `page_controller.ex:7` documents the insert-order assumption and tour links hard-coded IDs at `page_controller.ex:31`, `:39`, `:47`, `:55`, `:63`, and `:71`. | Add a source or DB-backed guard that asserts those IDs resolve to `[demo-01]` and `[demo-17]..[demo-20]` subjects. |
| `/health` is static liveness, not DB/dashboard readiness. | low/integration | RUNT-03, VER-01 | `lib/cairnloop/web/health_plug.ex:15` returns static JSON; `lib/cairnloop/router.ex:37` currently calls it liveness/readiness. | Keep docs/copy precise, or add a separate readiness probe if future consumers need one. |
| Demo smoke is route-level HTTP, not browser automation. | low/scope | VER-01, VER-04 | Integration checker confirmed this is intentional and docs state the scope. | Keep as accepted scope, or add a future browser walkthrough requirement if adopter proof needs JS coverage. |
| Phase 56 validation metadata remains stale. | low/process | VER-03..04 | `56-VALIDATION.md` has `status: draft`, `nyquist_compliant:false`, and pending rows; `56-VERIFICATION.md` passed workflow contract, fast CI, Compose config, and Docker smoke. | Run `/gsd:validate-phase 56` or reconcile frontmatter during closeout. |

## Nyquist Coverage

Nyquist discovery was scanned because validation artifacts exist and `.planning/config.json` has no disable switch. The installed GSD CLI in this workspace does not expose `loop render-hooks verify:post --raw`, so hook rendering itself could not be queried.

| Phase | VALIDATION.md | `nyquist_compliant` | `wave_0_complete` | Classification | Action |
|---:|---|---|---|---|---|
| 53 | exists | true | true | COMPLIANT | none |
| 54 | exists | true | true | COMPLIANT | none |
| 55 | exists | true | true | COMPLIANT | none |
| 56 | exists | false | false | PARTIAL | `/gsd:validate-phase 56` |

The partial Phase 56 classification is planning-artifact debt, not a product failure: Phase 56 has a passing verification report and successful Docker smoke evidence.

## Requirement Fail Gate

No requirement is unsatisfied, partial, missing from verification, or orphaned. The audit fail gate does not trigger `gaps_found`.

## Decision

Milestone vM018 can be completed with accepted tech debt, or the cheap cleanup can be done first:

1. Fix the README printed-route list and the stale example `mix.exs` comment.
2. Add a guard for demo index deep-link IDs and keep `/health` documented as liveness unless a real readiness probe is added.
3. Run `/gsd:validate-phase 56` to reconcile Nyquist metadata.

No closure phase is required for product behavior. The Docker-first adoption proof is wired end to end.
