# Phase 60: Installer, Docs, Upgrade, and OSS Trust - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-30
**Phase:** 60-Installer, Docs, Upgrade, and OSS Trust
**Areas discussed:** Adoption story and install truth, Upgrade/security trust posture, Package/docs verification guardrails

---

## Adoption Story and Install Truth

| Option | Description | Selected |
|--------|-------------|----------|
| Docker-first, then host install | Preserve the vM018 public path: `./bin/demo` first, then Igniter host-app install and manual fallback. | ✓ |
| Host-install first | Lead immediately with package install and treat Docker demo as secondary evaluation material. | |
| Broad rewrite | Reframe the README/guides from scratch as a marketing-oriented public site. | |

**User's choice:** Auto-decided per `CLAUDE.md`; no owner choice escalated.
**Notes:** The roadmap says Phase 60 makes the public adoption path truthful, current, skimmable,
and supportable. vM018 already locked Docker-first demo docs, while Phase 59 changed the install
and migration truth. The right move is targeted convergence, not a new docs concept.

---

## Upgrade and Security Trust Posture

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit trust boundaries | Document host-owned auth/Repo/Oban/secrets/monitoring, dedicated-schema default, public compatibility, and modest security support. | ✓ |
| Minimal caveats | Keep public docs short and leave upgrade/security details to source readers. | |
| Heavy compliance posture | Add broad enterprise/compliance/process claims beyond what the repository proves. | |

**User's choice:** Auto-decided per `CLAUDE.md`; no owner choice escalated.
**Notes:** Phase 57 ranked install/docs/release truth as a top adoption risk. `SECURITY.md` and
`UPGRADING.md` already exist and should be made accurate without overclaiming production,
compliance, multi-tenant, or hosted-service guarantees.

---

## Package and Docs Verification Guardrails

| Option | Description | Selected |
|--------|-------------|----------|
| Source-scanned docs truth | Reuse the existing DB-free docs/install/package source-scan pattern and run docs/package quality checks. | ✓ |
| Manual docs review only | Rely on maintainer review without tests for version, migration command, or package drift. | |
| DB/browser-heavy proof | Prove all docs claims with DB or browser tests even when source scans are enough. | |

**User's choice:** Auto-decided per `CLAUDE.md`; no owner choice escalated.
**Notes:** Existing tests already guard Docker-first docs, installer output, MCP/trust docs, runtime
contract docs, and package collateral. Phase 60 should extend that pattern for schema-prefix,
UPGRADING, SECURITY, package files, current version, and missing asset references.

---

## Claude's Discretion

- The normal GSD gray-area selection prompt was bypassed because this repository explicitly
  instructs GSD discuss-phase to auto-decide routine implementation calls and surface at most one
  genuinely very-impactful owner decision.
- No such owner-level decision was found. The scope and direction are already fixed by vM019
  requirements, Phase 57 audit evidence, Phase 58 trust-boundary context, and Phase 59
  dedicated-schema context.

## Deferred Ideas

- CI workflow optimization, action/runtime posture, path gating, timing evidence, and release-gate
  strategy belong to Phase 61.
- Hosted demo, marketing site, mobile SDK, local AI, advanced routing, enterprise compliance
  process, and full data-migration automation are outside Phase 60.
