# Requirements Archive: vM019 OSS Trust Baseline

**Archived:** 2026-07-01
**Status:** SHIPPED

For current requirements, see `.planning/REQUIREMENTS.md`.

---

# Requirements: vM019 OSS Trust Baseline

## Milestone Goal

Make Cairnloop adoption-ready as an OSS Phoenix/Ecto library by closing the quality dimensions most
likely to break trust: host-app compatibility, DB/schema hygiene, install/docs truth, CI/release
confidence, unsafe ingress defaults, and upgrade clarity.

This is not a product-surface milestone. Do not add advanced routing, local AI, mobile SDK, hosted
demo, or new operator workflows unless required to harden existing behavior.

## Active Requirements

### AUDIT - Evidence-Backed Quality Evaluation

- [x] **AUDIT-01**: Maintainer can read a repo-evidence-backed software-quality evaluation across the
  36 requested dimensions, ranked weakest-to-strongest with confidence, consequence, fix, and priority.

- [x] **AUDIT-02**: Evaluation explicitly identifies missing project-specific quality dimensions rather
  than forcing every generic category to matter equally.

- [x] **AUDIT-03**: Evaluation separates facts from assumptions and cites concrete files, commands, and
  external primary-source research where relevant.

### TRUST - Host-App Safety and Ingress Boundaries

- [x] **TRUST-01**: Customer/browser identity and operator identity are not conflated in runtime flows,
  persisted data, recovery actions, approvals, search, or audit context.

- [x] **TRUST-02**: Widget ingress has an explicit host-verification seam for customer/session tokens and
  fails closed when verification is not configured for production.

- [x] **TRUST-03**: Email webhook ingress does not ship with a literal default secret and documents the
  host's authentication responsibility clearly.

- [x] **TRUST-04**: MCP auth behavior matches docs and fails closed for token-required methods before
  exposing tool metadata or write surfaces.

- [x] **TRUST-05**: Logs and telemetry metadata exclude customer message bodies, secrets, raw payloads,
  and other high-risk support content unless explicitly opted into a diagnostic mode.

### OPS - Safe Defaults, Side Effects, and Observability

- [x] **OPS-01**: Optional Scrypath/external automation side effects are inert by default and require an
  explicit host opt-in.

- [x] **OPS-02**: When optional side effects are enabled, config errors are caught early enough for a host
  developer to fix them without production guesswork.

- [x] **OPS-03**: `/health` remains honest liveness, while readiness/doctor output documents DB, Oban,
  pgvector, notifier, and optional automation status without claiming more than it checks.

- [x] **OPS-04**: Production debugging has enough hooks - logs, telemetry docs, doctor output, and
  troubleshooting notes - to identify whether Cairnloop, host config, DB state, Oban, or an external
  dependency is failing.

### DB - Postgres Schema, Persistence Hygiene, and Upgrade Path

- [x] **DB-01**: New installs default Cairnloop support-domain tables to a dedicated Postgres schema
  prefix named `cairnloop`.

- [x] **DB-02**: Existing public-schema installs remain supported through an explicit compatibility
  config and documented migration/upgrade path.

- [x] **DB-03**: Library migrations qualify Cairnloop-owned objects, references, indexes, functions,
  triggers, and raw SQL safely without relying on `mix ecto.migrate --prefix`.

- [x] **DB-04**: Library migrations do not drop shared host extensions such as `vector` on rollback.
- [x] **DB-05**: Runtime Ecto reads/writes, preload paths, fragments, and structural health checks honor
  the configured Cairnloop prefix without redirecting arbitrary host-app schemas or Oban tables.

- [x] **DB-06**: Tests prove both dedicated-schema new installs and explicit public-schema compatibility.
- [x] **DB-07**: The example app uses the new dedicated schema default and documents how to switch to
  public only when a host intentionally chooses that compatibility mode.

### DOC - Adoption, Docs, Release, and Support Truth

- [x] **DOC-01**: README explains what problem Cairnloop solves, when to use it, when not to use it, and
  the fastest first success path without stale version/config claims.

- [x] **DOC-02**: Installer output and generated snippets match the current package version and complete
  setup contract, including repo config and ordered host/library migrations.

- [x] **DOC-03**: Quickstart, host integration, MCP, extending, troubleshooting, example README, ExDoc
  groups, and package guides match current code paths and public APIs.

- [x] **DOC-04**: `SECURITY.md` is a public security policy, not an internal phase artifact.
- [x] **DOC-05**: `UPGRADING.md` documents versioning, DB prefix migration choices, deprecations, rollback
  posture, and compatibility claims for Elixir/OTP/Phoenix/Ecto/Postgres.

- [x] **DOC-06**: Public package metadata, changelog, examples, and screenshots/assets do not contain
  stale paths, missing assets, or pre-v0.5 claims.

### CI - CI/CD Efficiency, Determinism, and Release Confidence

- [x] **CI-01**: CI workflow names, triggers, permissions, concurrency, caches, and required gate
  strategy are documented and aligned with the actual risk model.

- [x] **CI-02**: First-party GitHub Actions and runtime posture are current for the 2026 Node 24 action
  transition without using stale or fictional environment variables.

- [x] **CI-03**: CI uses least-privilege token permissions and does not persist checkout credentials in
  read-only jobs.

- [x] **CI-04**: Maintainers can see PR wall-clock bottlenecks, cache behavior, slowest tests, compile
  time, and failure modes without guessing.

- [x] **CI-05**: Demo smoke, E2E, integration, quality, and release jobs are kept only where they provide
  clear signal; low-value overlap is demoted or documented rather than silently wasting runner time.

- [x] **CI-06**: Release automation proves package metadata/docs/dry-run readiness before publishing and
  does not expose secrets to untrusted PR code.

## Future Requirements

- Multi-tenant tenant-specific Cairnloop prefixes beyond the single configured library prefix.
- Hosted SaaS demo or hosted dashboard.
- Advanced team routing, local AI, or mobile SDK work.
- Full UI redesign beyond trust/support fixes needed by this milestone.

## Out of Scope

- Breaking public function signatures that vM011-vM018 sealed.
- Moving Oban-owned tables into the Cairnloop schema by default.
- Replacing host-owned auth with a Cairnloop auth system.
- Adding enterprise governance process that does not reduce a concrete adoption, production, or
  maintainer risk in this repo.

## Traceability

| Requirement | Planned Phase | Status |
|---|---:|---|
| AUDIT-01 | 57 | Complete |
| AUDIT-02 | 57 | Complete |
| AUDIT-03 | 57 | Complete |
| TRUST-01 | 58 | Complete |
| TRUST-02 | 58 | Complete |
| TRUST-03 | 58 | Complete |
| TRUST-04 | 58 | Complete |
| TRUST-05 | 58 | Complete |
| OPS-01 | 58 | Complete |
| OPS-02 | 58 | Complete |
| OPS-03 | 58 | Complete |
| OPS-04 | 58 | Complete |
| DB-01 | 59 | Complete |
| DB-02 | 59 | Complete |
| DB-03 | 59 | Complete |
| DB-04 | 59 | Complete |
| DB-05 | 59 | Complete |
| DB-06 | 59 | Complete |
| DB-07 | 59 | Complete |
| DOC-01 | 60 | Complete |
| DOC-02 | 60 | Complete |
| DOC-03 | 60 | Complete |
| DOC-04 | 60 | Complete |
| DOC-05 | 60 | Complete |
| DOC-06 | 60 | Complete |
| CI-01 | 57 | Complete |
| CI-02 | 61 | Complete |
| CI-03 | 61 | Complete |
| CI-04 | 61 | Complete |
| CI-05 | 61 | Complete |
| CI-06 | 61 | Complete |
