# Requirements Archive: vM018 Demo DX Adoption Proof

**Archived:** 2026-06-29
**Status:** SHIPPED

The live `.planning/REQUIREMENTS.md` is intentionally removed at milestone close. The next milestone
will create a fresh requirements file.

---

# Requirements: Cairnloop vM018 Demo DX Adoption Proof

**Defined:** 2026-06-27
**Core Value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.

## vM018 Requirements

Requirements for the Docker-first adoption proof milestone. Each maps to exactly one roadmap phase.

### Demo Bootstrap

- [x] **BOOT-01**: Adopter can run `./bin/demo` from a fresh clone with Docker Compose v2 as the only local runtime prerequisite.
- [x] **BOOT-02**: Adopter can start the demo without fixed host port conflicts because Phoenix publishes on localhost via a dynamic or configured port and Postgres stays private to Compose.
- [x] **BOOT-03**: Adopter can see the exact running URLs for the demo index, operator cockpit, inbox, customer chat, Knowledge Base, gaps, suggestions, audit log, settings, and health probe after the stack becomes healthy.
- [x] **BOOT-04**: Adopter can reprint URLs, follow logs, inspect status, stop/down the stack, and reset seeded volumes through the same demo wrapper.

### Example Runtime

- [x] **RUNT-01**: Adopter can rely on the example setup path to run host migrations before Cairnloop library migrations in both Docker and manual local workflows.
- [x] **RUNT-02**: Maintainer can dogfood the local path dependency in the example app while preserving adopter-facing guidance for Hex dependency usage.
- [x] **RUNT-03**: Adopter can rely on a routable `/health` probe that becomes healthy only after the app can serve the demo.
- [x] **RUNT-04**: Adopter can boot the demo without noisy missing-config failures from Chimeway, Cairnloop behaviours, endpoint binding, or database env differences.
- [x] **RUNT-05**: Adopter can click through the seeded Trailmark support lifecycle immediately after boot without running extra fixture commands.

### Adopter Documentation

- [x] **DOC-01**: Adopter sees the Docker demo as the first-run path in README and Quickstart, with manual local setup clearly secondary.
- [x] **DOC-02**: Adopter can follow the example README without relying on hard-coded Docker ports or stale route names.
- [x] **DOC-03**: Adopter can resolve common demo failures from docs: Docker unavailable, Compose v2 missing, port conflict, unhealthy stack, reset/reseed need, and pgvector/manual Postgres confusion.
- [x] **DOC-04**: Maintainer can explain the smoke workflow and route coverage without requiring an OpenAI API key or external services.

### Verification Gates

- [x] **VER-01**: Maintainer can run `./bin/demo smoke` to boot an isolated demo stack, check the main routes, and clean up containers and volumes afterward.
- [x] **VER-02**: Maintainer gets actionable failure output from the smoke command, including the failing route and recent web logs.
- [x] **VER-03**: CI runs the Docker demo smoke lane for changes that can break the demo wrapper, Compose/Dockerfile contract, example runtime, first-run docs, or the smoke workflow.
- [x] **VER-04**: Demo verification remains automated; no human UAT checkpoint is required for first-run, route, or browser-rendered behavior.

## Future Requirements

Deferred to a later adoption or marketing milestone.

### Demo Expansion

- **DEMO-01**: Adopter can run a full browser walkthrough against the Docker demo from a single command.
- **DEMO-02**: Maintainer can refresh guide screenshots directly from the Docker demo without separately booting the manual local path.
- **DEMO-03**: Public website visitors can try a hosted demo environment without cloning the repo.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Epic 12 advanced routing/team collaboration | Product-surface expansion; not needed to reduce first-run adoption friction. |
| Epic 13 local AI runtime | Separate architecture and dependency wedge; not required for Docker demo proof. |
| Epic 14 mobile SDK | Separate platform surface; unrelated to Phoenix example first-run DX. |
| Production deployment recipe | This milestone proves local adopter evaluation, not cloud hosting or release operations. |
| Requiring OpenAI API keys for demo success | The first-run path must work without external service credentials. |
| Human UAT for demo verification | Owner directive says rendered behavior should be gated by automated browser/smoke evidence. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

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

---
*Requirements defined: 2026-06-27*
*Last updated: 2026-06-28 after Phase 56 completion*
