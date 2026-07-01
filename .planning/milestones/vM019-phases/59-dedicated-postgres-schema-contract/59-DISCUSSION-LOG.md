# Phase 59: Dedicated Postgres Schema Contract - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-30
**Phase:** 59-Dedicated Postgres Schema Contract
**Areas discussed:** Prefix contract, Ecto schema/runtime access, Migration/raw SQL contract, Installer/example/tests

---

## Prefix Contract

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated schema default | New installs use `schema_prefix: "cairnloop"` for support-domain tables. | yes |
| Public by default | Preserve old public-schema behavior without explicit compatibility config. | no |
| Multi-prefix/tenant prefixes | Support multiple prefixes in one host app. | no |

**User's choice:** Auto-decided from locked vM019 state and `docs/postgres-schema-prefix.md`.
**Notes:** The project already locked `cairnloop` as the new default, public as explicit
compatibility, and single-prefix scope.

---

## Ecto Schema And Runtime Access

| Option | Description | Selected |
|--------|-------------|----------|
| Central helper plus schema defaults | Use `Cairnloop.SchemaPrefix` for raw SQL/helpers and schema prefixes for normal Ecto schema behavior. | yes |
| Repo opts only | Rely on `Repo.*(prefix: ...)` to redirect everything. | no |
| Runtime per-request switching | Switch support prefix dynamically per request or tenant. | no |

**User's choice:** Auto-decided under repo decision policy.
**Notes:** Ecto prefix precedence makes Repo opts alone too weak once schemas declare
`@schema_prefix`; public compatibility must be proven under the actual compile/config mode.

---

## Migration And Raw SQL Contract

| Option | Description | Selected |
|--------|-------------|----------|
| Source-qualified migrations | Qualify tables, indexes, FKs, functions, triggers, and raw SQL in migration code. | yes |
| CLI prefix shortcut | Tell adopters to rely on `mix ecto.migrate --prefix cairnloop`. | no |
| Search path contract | Use `SET search_path` as the primary correctness mechanism. | no |

**User's choice:** Auto-decided from carried project decisions.
**Notes:** `--prefix` may still exist as an Ecto migrator flag, but Phase 59 must not present it as
the solution. Prefix correctness belongs in Cairnloop source.

---

## Installer, Example, And Tests

| Option | Description | Selected |
|--------|-------------|----------|
| Example/test-host proof | Make example and integration host prove dedicated-schema new install behavior. | yes |
| Source-scan only | Guard strings without running Postgres placement tests. | no |
| Broad docs milestone | Expand all public docs in this phase. | no |

**User's choice:** Auto-decided from Phase 59/60 boundaries.
**Notes:** Phase 59 owns minimal installer/example/upgrading truth needed for the DB contract.
Phase 60 owns the broader public docs pass.

---

## Claude's Discretion

- No `AskUserQuestion` prompt was sent. `CLAUDE.md` explicitly instructs GSD discuss-phase to
  auto-decide ordinary gray areas and surface at most one genuinely very-impactful choice. No such
  unresolved owner-level choice remained after reading project state, Phase 57/58 contexts, and
  `docs/postgres-schema-prefix.md`.

## Deferred Ideas

- Multi-tenant or per-customer schema prefixes.
- Moving Oban into Cairnloop's schema.
- Broad public docs/package cleanup beyond the minimal DB-contract truth needed in Phase 59.
- CI/CD optimization beyond any narrow test command needed to prove this phase.
