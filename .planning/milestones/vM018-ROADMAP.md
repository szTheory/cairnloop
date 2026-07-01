# Milestone vM018: Demo DX Adoption Proof

**Status:** SHIPPED 2026-06-29
**Phases:** 53-56
**Total Plans:** 12
**Audit:** `tech_debt`; 17/17 requirements satisfied, 0 requirement gaps, 0 integration blockers, 0 broken flows.

---

# Roadmap: Cairnloop vM018 Demo DX Adoption Proof

**Milestone goal:** Make the Docker-backed demo path the reliable first-run adoption proof: a fresh clone can run Cairnloop without local Elixir or Postgres, click through the seeded support workflow, and trust CI to catch demo drift.

**Phase numbering:** Continuing from vM017, which ended at Phase 52.

## Milestones

- SHIPPED **vM018 Demo DX Adoption Proof** - Phases 53-56 (shipped 2026-06-29; archived in `.planning/milestones/vM018-*`)
- SHIPPED **vM016 Operator UI/UX Iteration** - Phases 37-45 (shipped 2026-06-26; archived in `.planning/milestones/vM016-*`)
- SHIPPED **vM017 Brand Identity System, Token Evolution & HTML Brand Book** - Phases 46-52 (shipped 2026-06-26; archived in `.planning/milestones/vM017-*`)
- SHIPPED **vM015 Operator Polish + Maintenance Gates** - Phases 33-36 (shipped 2026-05-30, v0.2.0-v0.2.2)
- SHIPPED **vM014 Adoption Proof** - Phases 27-32.1 (shipped 2026-05-29)
- SHIPPED **vM013 Support-Triggered Outbound Lifecycle** - Phases 22-26 (shipped 2026-05-27)
- SHIPPED **vM012 Public Release & MCP Write Surface** - Phases 18-21 (shipped 2026-05-26)
- SHIPPED **vM011 AI Tool Governance & MCP Integration** - Phases 13-17 (shipped 2026-05-25)
- SHIPPED **vM003-vM010** - foundational milestones (archived)

> Current published package remains `cairnloop` v0.5.1 on Hex.pm. Product scope remains
> "done enough for stated scope"; vM018 is an adopter-first DX hardening milestone, not a new
> support automation feature milestone.

## Phase Overview

| Phase | Name | Goal | Requirements |
|-------|------|------|--------------|
| 53 | 5/5 | Complete    | 2026-06-28 |
| 54 | 3/3 | Complete    | 2026-06-28 |
| 55 | 3/3 | Complete    | 2026-06-28 |
| 56 | 1/1 | Complete    | 2026-06-28 |

## Phase Details

### Phase 53: Demo Runtime Contract

**Goal:** Prove the example app runtime contract before polishing wrapper UX: database env, endpoint binding, migration order, health, Chimeway/Cairnloop config, and seeded Trailmark data all work in the intended Docker/manual paths.

**Requirements:** RUNT-01, RUNT-02, RUNT-03, RUNT-04, RUNT-05

**Success criteria:**

1. Docker and manual local setup both run host migrations before Cairnloop library migrations.
2. The example app can dogfood the local path dependency while docs retain the Hex dependency story for adopters.
3. `/health` is routable and suitable for Compose readiness checks.
4. Development/test/Docker config avoids noisy missing Chimeway or Cairnloop behaviour failures.
5. Seeded Trailmark data is available immediately after setup with no extra fixture command.

**Guardrails:**

- Keep changes inside example runtime/config/seeds or narrowly related docs.
- Do not change sealed Cairnloop public contracts to satisfy demo setup.
- Preserve the current DB-free headless test posture unless a test explicitly belongs to the example app.

### Phase 54: Demo Wrapper Experience

**Goal:** Make `./bin/demo` the adopter-facing operational surface for the local demo.

**Requirements:** BOOT-01, BOOT-02, BOOT-03, BOOT-04, VER-01, VER-02

**Plans:** 3/3 plans complete

Plans:
**Wave 1**

- [x] 54-01-PLAN.md — Create Wave 0 DB-free wrapper/Compose contract tests.
- [x] 54-02-PLAN.md — Harden `bin/demo` URL discovery, help, readiness, and diagnostics.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 54-03-PLAN.md — Run final `mix ci.fast`, Compose config, and isolated Docker smoke gates.

**Success criteria:**

1. `./bin/demo` starts from the repository root with Docker Compose v2 and no local Elixir/Postgres requirement.
2. The default Compose contract avoids host Postgres exposure and avoids fixed Phoenix port collisions.
3. The wrapper prints exact URLs discovered from the running Compose stack after health passes.
4. Wrapper subcommands cover URLs, logs, status, stop, down, reset, help, and smoke.
5. `./bin/demo smoke` boots an isolated stack, checks main routes, cleans up, and prints recent web logs on failure.

**Guardrails:**

- Avoid global port ownership and Docker socket side effects beyond normal Compose use.
- Keep route checks high-signal and stable; do not turn smoke into a full browser E2E suite.

### Phase 55: Docker-First Adopter Docs

**Goal:** Make the first-run story consistent anywhere an adopter enters the repo or HexDocs.

**Requirements:** DOC-01, DOC-02, DOC-03, DOC-04

**Success criteria:**

1. Root README and Quickstart lead with Docker demo before manual local setup.
2. Example README documents the wrapper commands, printed URLs, dynamic ports, and reset/log flows.
3. Troubleshooting covers Docker unavailable, Compose v2 missing, unhealthy stack, port conflicts, reset/reseed, and pgvector/manual Postgres confusion.
4. Docs clearly state that OpenAI credentials are optional and not needed for first-run success.
5. Docs point Docker users to the URL printed by `./bin/demo`, not hard-coded `localhost:4000`.

**Guardrails:**

- Keep copy adopter-facing and calm; do not leak raw Elixir terms to non-operator docs.
- Do not present manual setup as the primary success path for evaluation.

### Phase 56: Demo Smoke CI Gate

**Goal:** Ensure demo drift is caught automatically for relevant changes.

**Requirements:** VER-03, VER-04

**Success criteria:**

1. CI has a Docker demo smoke workflow runnable manually, on schedule, and on relevant path changes.
2. The workflow runs `./bin/demo smoke` against a clean checkout and enforces a realistic timeout.
3. Path filters include demo wrapper, Compose/Dockerfile, example app, first-run docs, and the workflow itself.
4. The verification plan requires automated smoke/browser evidence and no human UAT checkpoint.

**Guardrails:**

- Keep smoke separate from release publishing so demo proof can fail loudly without mutating release state.
- Do not require external secrets for CI smoke.

## Requirement Coverage

| Requirement | Phase | Status |
|-------------|-------|--------|
| BOOT-01 | Phase 54 | Complete |
| BOOT-02 | Phase 54 | Complete |
| BOOT-03 | Phase 54 | Complete |
| BOOT-04 | Phase 54 | Complete |
| RUNT-01 | Phase 53 | Complete |
| RUNT-02 | Phase 53 | Complete |
| RUNT-03 | Phase 53 | Complete |
| RUNT-04 | Phase 53 | Complete |
| RUNT-05 | Phase 53 | Complete |
| DOC-01 | Phase 55 | Complete |
| DOC-02 | Phase 55 | Complete |
| DOC-03 | Phase 55 | Complete |
| DOC-04 | Phase 55 | Complete |
| VER-01 | Phase 54 | Complete |
| VER-02 | Phase 54 | Complete |
| VER-03 | Phase 56 | Complete |
| VER-04 | Phase 56 | Complete |

**Coverage:**

- vM018 requirements: 17 total
- Mapped to phases: 17
- Unmapped: 0

## Research Decision

Skipped. vM018 is an adopter/DX hardening milestone over the existing Phoenix example app and demo substrate, not a new product or domain feature. Local project context, shipped architectural invariants, and the existing example app files are sufficient.

## Completion

vM018 shipped on 2026-06-29. Current planning state lives in `.planning/ROADMAP.md`; phase execution
history is archived under `.planning/milestones/vM018-phases/`.
