# Roadmap: Cairnloop

## Milestones

- SHIPPED **vM019 OSS Trust Baseline** - Phases 57-61 (shipped 2026-07-01; archived in `.planning/milestones/vM019-*`)
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
> "done enough for stated scope"; vM019 was an OSS trust/adoption hardening milestone, not a new
> support automation feature milestone.

## Current Planning State

No milestone is active. vM019 OSS Trust Baseline shipped on 2026-07-01 and is archived. Start the
next milestone with `/gsd-new-milestone` so fresh requirements can be defined before new phase work.

## Active Milestone

None. The next milestone has not been defined.

## Shipped Phase Summaries

<details>
<summary>SHIPPED vM019 OSS Trust Baseline (Phases 57-61) - 2026-07-01</summary>

- [x] **Phase 57: Evidence and Trust Audit** - Evidence-backed 36-dimension quality evaluation, CI/CD topology audit, Postgres schema-prefix contract, and local baseline evidence.
- [x] **Phase 58: Identity, Ingress, and Side-Effect Trust** - Customer/operator identity separation, widget verifier seam, email/MCP fail-closed auth, inert optional side effects, bounded logs/telemetry, liveness-only `/health`, and doctor trust diagnostics.
- [x] **Phase 59: Dedicated Postgres Schema Contract** - Dedicated `cairnloop` schema default, explicit public compatibility, qualified migrations/runtime paths, safe vector rollback, Oban host ownership, installer/test-host parity, and example-app proof.
- [x] **Phase 60: Installer, Docs, Upgrade, and OSS Trust** - README, Quickstart, Host Integration, Troubleshooting, MCP, Extending, Auth/Operator Identity, SECURITY, UPGRADING, CHANGELOG, ExDoc/package metadata, and docs source-scan guardrails brought current.
- [x] **Phase 61: CI/CD Efficiency and Release Confidence** - Current action/runtime posture, least-privilege workflows, path-gated expensive checks, bounded maintainer evidence, source-contract tests, and exact-SHA Hex release preflight.

Full archive:

- `.planning/milestones/vM019-ROADMAP.md`
- `.planning/milestones/vM019-REQUIREMENTS.md`
- `.planning/milestones/vM019-MILESTONE-AUDIT.md`
- `.planning/milestones/vM019-phases/`

Audit result: `tech_debt`; 31/31 requirements implementation-satisfied, 0 requirement gaps, 0
integration blockers, 0 broken flows. Accepted debt is planning-artifact and hosted-runner
observation cleanup tracked in the audit archive.

</details>

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

No active requirements file is present after vM019 close. vM019 requirements were archived at
`.planning/milestones/vM019-REQUIREMENTS.md` with 31/31 requirements complete.

## Next Step

Start the next milestone with `/gsd-new-milestone`.
