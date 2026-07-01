# Roadmap: Cairnloop

## Milestones

- ACTIVE **vM019 OSS Trust Baseline** - Phases 57-61 (started 2026-06-29)
- SHIPPED **vM018 Demo DX Adoption Proof** - Phases 53-56 (shipped 2026-06-29; archived in `.planning/milestones/vM018-*`)
- SHIPPED **vM017 Brand Identity System, Token Evolution & HTML Brand Book** - Phases 46-52 (shipped 2026-06-26; archived in `.planning/milestones/vM017-*`)
- SHIPPED **vM016 Operator UI/UX Iteration** - Phases 37-45 (shipped 2026-06-26; archived in `.planning/milestones/vM016-*`)
- SHIPPED **vM015 Operator Polish + Maintenance Gates** - Phases 33-36 (shipped 2026-05-30, v0.2.0-v0.2.2)
- SHIPPED **vM014 Adoption Proof** - Phases 27-32.1 (shipped 2026-05-29)
- SHIPPED **vM013 Support-Triggered Outbound Lifecycle** - Phases 22-26 (shipped 2026-05-27)
- SHIPPED **vM012 Public Release & MCP Write Surface** - Phases 18-21 (shipped 2026-05-26)
- SHIPPED **vM011 AI Tool Governance & MCP Integration** - Phases 13-17 (shipped 2026-05-25)
- SHIPPED **vM003-vM010** - foundational milestones (archived)

> Current published package remains `cairnloop` v0.5.1 on Hex.pm. Product scope remains
> "done enough for stated scope"; vM018 was an adopter-first DX hardening milestone, not a new
> support automation feature milestone.

## Current Planning State

vM019 OSS Trust Baseline is active. The milestone hardens Cairnloop as an OSS Phoenix/Ecto
library: evidence-backed quality evaluation, safer host-app boundaries, dedicated Postgres schema
defaults, adoption/docs truth, CI/CD efficiency, and release/upgrade confidence.

## Active Milestone: vM019 OSS Trust Baseline

### Phase 57: Evidence and Trust Audit

**Goal:** Produce the blunt, evidence-backed quality evaluation and implementation baseline before
making invasive changes.

**Requirements:** AUDIT-01, AUDIT-02, AUDIT-03, CI-01

**Success criteria:**

1. `docs/software-quality-evaluation.md` ranks all requested dimensions weakest-to-strongest with
   repo evidence, confidence, consequence, highest-leverage fix, and priority.

2. `docs/ci-cd-audit.md` maps workflows, triggers, bottlenecks, cache posture, action/runtime
   posture, and concrete CI recommendations.

3. `docs/postgres-schema-prefix.md` records the prefix decision, Ecto/Postgres research, migration
   footguns, upgrade path, and example-app impact.

4. The audit identifies which quality concerns are must-fix, should-fix-before-1.0, nice-later, or
   not worth doing yet.

### Phase 58: Identity, Ingress, and Side-Effect Trust

**Goal:** Make Cairnloop fail closed around customer/operator identity, inbound auth, sensitive logs,
telemetry metadata, and optional side effects.

**Requirements:** TRUST-01, TRUST-02, TRUST-03, TRUST-04, TRUST-05, OPS-01, OPS-02, OPS-03, OPS-04

**Plans:** 7/7 plans complete

Plans:

**Wave 1**

- [x] 58-01-PLAN.md — Add customer_ref persistence, installer/test-host/example migration parity, and additive upgrade guidance.
- [x] 58-04-PLAN.md — Fail closed email webhook and MCP ingress before parsing, tool metadata, or write surfaces.
- [x] 58-05-PLAN.md — Keep optional Scrypath side effects inert unless enabled with ready config.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 58-02-PLAN.md — Add explicit widget verifier seam, fail-closed socket connect, and customer_ref widget join routing.
- [x] 58-03-PLAN.md — Use dashboard session operator identity for ConversationLive actions and fail closed when missing.
- [x] 58-06-PLAN.md — Bound conversation telemetry and default logs to exclude support content and unsafe metadata.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 58-07-PLAN.md — Keep /health liveness-only and move readiness/trust truth to doctor and targeted docs.

**Success criteria:**

1. Customer/browser identity is no longer reused as operator identity for recovery, resolve,
   approvals, search, or audit actions.

2. Widget, email webhook, and MCP ingress have explicit host-auth seams and production-safe defaults.
3. Optional external/Scrypath automation does not enqueue work unless the host opts in.
4. Logs, telemetry, doctor output, and troubleshooting docs expose operational state without leaking
   support content or secrets.

### Phase 59: Dedicated Postgres Schema Contract

**Goal:** Default new Cairnloop installs to a dedicated `cairnloop` Postgres schema while preserving
an explicit public-schema compatibility path for existing users.

**Requirements:** DB-01, DB-02, DB-03, DB-04, DB-05, DB-06, DB-07

**Plans:** 10 plans

Plans:

**Wave 1**

- [x] 59-01-PLAN.md - Establish prefix helper/config semantics and DB-backed contract tests.

**Wave 2**

- [x] 59-02-PLAN.md - Qualify library migrations and migration drift tests.
- [x] 59-03-PLAN.md - Prefix Chat, KnowledgeBase, and MCP runtime facades.

**Wave 3** *(blocked on Wave 2 plan-family dependencies)*

- [x] 59-08-PLAN.md - Qualify governance, MCP, and outbound library migrations.
- [x] 59-09-PLAN.md - Prefix retrieval SQL, providers, and bulk indexing workers.

**Wave 4** *(blocked on Wave 3 where files are shared)*

- [x] 59-04-PLAN.md - Prefix governance/outbound runtime paths and doctor diagnostics.
- [x] 59-05-PLAN.md - Align installer, upgrade note, and integration test-host migrations.

**Wave 5** *(blocked on Wave 4 where files are shared)*

- [x] 59-06-PLAN.md - Make the example app prove the dedicated schema default.
- [x] 59-10-PLAN.md - Prefix automation, gap recording, and worker persistence.

**Wave 6**

- [x] 59-07-PLAN.md - Run clean DB, integration, fast, and example verification gates.

**Success criteria:**

1. Runtime schemas, migrations, raw SQL, structural checks, and installer-generated substrate honor a
   configured Cairnloop prefix without redirecting unrelated host tables or Oban.

2. New installs use `cairnloop` by default; public-schema installs require explicit config and docs.
3. Migration rollback does not drop shared extensions such as `vector`.
4. Tests prove dedicated-schema and public-schema compatibility, including example-app setup.

### Phase 60: Installer, Docs, Upgrade, and OSS Trust

**Goal:** Make the public adoption path truthful, current, skimmable, and supportable.

**Requirements:** DOC-01, DOC-02, DOC-03, DOC-04, DOC-05, DOC-06

**Success criteria:**

1. README and guides explain the problem, when to use/not use Cairnloop, install/config/migration
   steps, first useful example, troubleshooting, compatibility, and production notes.

2. Installer output, generated deps/config/migration instructions, ExDoc, MCP/extending guides, and
   example docs match live code and current package version.

3. `SECURITY.md`, `UPGRADING.md`, CHANGELOG/package metadata, and public trust signals are suitable
   for a real OSS library without corporate ceremony.

### Phase 61: CI/CD Efficiency and Release Confidence

**Goal:** Keep CI fast, deterministic, least-privilege, and useful while preserving release trust.

**Requirements:** CI-02, CI-03, CI-04, CI-05, CI-06

**Success criteria:**

1. GitHub Actions use current first-party action majors or pinned/maintained third-party actions,
   least-privilege permissions, safe concurrency, and clear job names.

2. PR/main/demo/release paths are documented with bottleneck/timing evidence and do not waste runner
   time on low-signal duplicate checks.

3. CI exposes enough timing/cache/test evidence for maintainers to optimize from facts.
4. Release automation verifies package/docs/dry-run readiness before publishing from trusted refs.

## Shipped Phase Summaries

<details>
<summary>SHIPPED vM018 Demo DX Adoption Proof (Phases 53-56) - 2026-06-29</summary>

- [x] **Phase 53: Demo Runtime Contract** - Docker/manual setup contract, ordered migrations, health route, quiet runtime config, and setup-owned Trailmark seeds.
- [x] **Phase 54: Demo Wrapper Experience** - Canonical `./bin/demo` wrapper with dynamic/private Compose contract, URL discovery, logs/status/stop/down/reset/help commands, isolated smoke, and bounded diagnostics.
- [x] **Phase 55: Docker-First Adopter Docs** - README, Quickstart, example README, and Troubleshooting aligned around `./bin/demo`, printed URLs, optional OpenAI first-run scope, and source-scan docs tests.
- [x] **Phase 56: Demo Smoke CI Gate** - Dedicated read-only GitHub Actions workflow running `./bin/demo smoke` on manual, scheduled, push, and pull request triggers for demo-relevant paths.

Full archive:

- `.planning/milestones/vM018-ROADMAP.md`
- `.planning/milestones/vM018-REQUIREMENTS.md`
- `.planning/milestones/vM018-MILESTONE-AUDIT.md`
- `.planning/milestones/vM018-phases/`

Audit result: `tech_debt`; 17/17 requirements satisfied, 0 requirement gaps, 0 integration blockers,
0 broken first-run flows. Accepted low-severity debt is tracked in the audit archive.

</details>

<details>
<summary>SHIPPED vM016-vM017 current-brand/operator milestones - 2026-06-26</summary>

- **vM017 Brand Identity System, Token Evolution & HTML Brand Book** delivered the C3.6 logo family, refined tokens, offline HTML brand book, README/example-app collateral wiring, package-boundary proof, and gated browser/package/SVG/raster QA.
- **vM016 Operator UI/UX Iteration** delivered shared page primitives, queue-first Home IA, shell breadcrumbs, progressive rail disclosure, cross-screen threading, responsive cockpit behavior, CSS-only motion, final-brand demo fixtures, screenshot proof, and release-gate verification.

Full archives:

- `.planning/milestones/vM017-ROADMAP.md`
- `.planning/milestones/vM017-REQUIREMENTS.md`
- `.planning/milestones/vM017-MILESTONE-AUDIT.md`
- `.planning/milestones/vM017-phases/`
- `.planning/milestones/vM016-ROADMAP.md`
- `.planning/milestones/vM016-REQUIREMENTS.md`
- `.planning/milestones/vM016-MILESTONE-AUDIT.md`
- `.planning/milestones/vM016-phases/`

</details>

<details>
<summary>SHIPPED vM003-vM015 - archived</summary>

Earlier milestone roadmaps are archived under `.planning/milestones/`. See `.planning/MILESTONES.md`
for shipped summaries and `.planning/PROJECT.md` for cumulative product state.

</details>

## Requirement Coverage

Active requirements are in `.planning/REQUIREMENTS.md`. vM019 maps 31 active requirements across
Phases 57-61. vM018 requirements were archived at `.planning/milestones/vM018-REQUIREMENTS.md` with
17/17 requirements complete.

## Next Step

Plan Phase 58: Identity, Ingress, and Side-Effect Trust.
