# Phase 56: Demo Smoke CI Gate - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-06-28
**Phase:** 56-Demo Smoke CI Gate
**Areas discussed:** CI workflow shape, Path filters, Smoke command contract, Automated verification,
Existing draft handling

---

## CI Workflow Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Separate demo-smoke workflow | Keep the Docker demo proof in `.github/workflows/demo-smoke.yml`, separate from release publishing. | x |
| Fold into main CI release gate | Add the smoke proof into the existing `ci.yml` aggregate gate. | |
| Fold into release publishing | Run demo smoke from `release-please.yml` or `publish-hex`. | |

**User's choice:** Auto-ratified under `CLAUDE.md` decision policy.
**Notes:** Separate workflow matches the roadmap guardrail: fail demo drift loudly without mutating
release state.

---

## Path Filters

| Option | Description | Selected |
|--------|-------------|----------|
| Narrow example-only filters | Trigger on `bin/demo`, example app, docs, and workflow changes only. | |
| Runtime-aware filters | Also include root runtime/package/source paths consumed by the example app path dependency. | x |
| Run on every source change | Omit path filters and run Docker smoke for all pushes and PRs. | |

**User's choice:** Auto-ratified under `CLAUDE.md` decision policy.
**Notes:** Runtime-aware filters best match VER-03 without making planning-only artifacts trigger a
Docker build.

---

## Smoke Command Contract

| Option | Description | Selected |
|--------|-------------|----------|
| Run `./bin/demo smoke` | Keep the wrapper as source of truth for isolated Compose scope, route checks, logs, and cleanup. | x |
| Duplicate Compose commands in YAML | Reimplement smoke steps directly in GitHub Actions. | |
| Add a new Mix task | Create a second command surface for CI smoke. | |

**User's choice:** Auto-ratified under `CLAUDE.md` decision policy.
**Notes:** Prior phases locked `./bin/demo` as the adopter-facing operational surface.

---

## Automated Verification

| Option | Description | Selected |
|--------|-------------|----------|
| Source contract plus Docker smoke | Pin workflow YAML with DB-free tests and run `./bin/demo smoke` where Docker is available. | x |
| Docker smoke only | Rely on GitHub Actions execution without local source drift tests. | |
| Human UAT checkpoint | Ask the owner to verify demo behavior manually. | |

**User's choice:** Auto-ratified under `CLAUDE.md` decision policy.
**Notes:** VER-04 and the repo's verification policy require automated proof and no human UAT.

---

## Existing Draft Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve and harden draft files | Inspect current working-tree `.github/workflows/demo-smoke.yml` and `.dockerignore`, keeping useful work. | x |
| Replace from scratch | Delete the draft workflow and rewrite the lane without considering current contents. | |
| Treat draft as shipped truth | Assume the untracked workflow already satisfies the phase without review. | |

**User's choice:** Auto-ratified under `CLAUDE.md` decision policy.
**Notes:** The working tree is dirty and includes relevant untracked files; downstream agents must
not discard unrelated user changes.

---

## Claude's Discretion

- Normal CI choices were decided by Claude under the project policy to avoid asking the owner to
  choose between reversible implementation details.
- No very-impactful irreversible product, trust, or governance decision was found.

## Deferred Ideas

- Full browser walkthrough command - future DEMO-01.
- Screenshot refresh from Docker demo - future DEMO-02.
- Hosted public demo environment - future DEMO-03.
- Branch protection configuration requiring the `demo-smoke` check - repository/host setting outside
  this code phase.
