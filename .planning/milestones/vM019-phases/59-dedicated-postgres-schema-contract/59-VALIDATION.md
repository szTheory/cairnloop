---
phase: 59
slug: dedicated-postgres-schema-contract
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-30
---

# Phase 59 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Ecto SQL Sandbox for DB-backed integration; example app ExUnit/Phoenix tests |
| **Config file** | `mix.exs`, `config/test.exs`, `test/support/data_case.ex`; example `examples/cairnloop_example/config/test.exs` |
| **Quick run command** | `mix test test/cairnloop/schema_prefix_test.exs test/cairnloop/migrations_test.exs test/cairnloop/tasks/install_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.fast && mix ci.integration && cd examples/cairnloop_example && mix test` |
| **Estimated runtime** | ~60-180 seconds for focused files; DB and example lanes vary by Postgres availability |

---

## Sampling Rate

- **After every task commit:** Run the focused test file(s) for the touched prefix surface plus `mix compile --warnings-as-errors`.
- **After every plan wave:** Run `mix ci.fast`; add `mix ci.integration` for waves that touch migrations, DB object placement, runtime repo calls, or example setup.
- **Before `/gsd:verify-work`:** Run `mix ci.fast`, `mix ci.integration`, and `cd examples/cairnloop_example && mix test`.
- **Max feedback latency:** Prefer focused ExUnit files under 180 seconds before broader DB/example lanes.

---

## Per-Requirement Verification Map

| Requirement | Expected Behavior | Test Type | Automated Command | File Exists | Status |
|-------------|-------------------|-----------|-------------------|-------------|--------|
| DB-01 | Dedicated `cairnloop` schema contains Cairnloop support-domain tables after setup; stale same-name public tables do not satisfy the proof. | integration | `mix test.integration --only integration test/integration/schema_prefix_contract_test.exs` | no - Wave 0 | pending |
| DB-02 | Explicit public compatibility mode reads/writes public support tables and is documented as deliberate compatibility, not the default. | integration + source scan | `CAIRNLOOP_SCHEMA_PREFIX=public MIX_ENV=test mix do clean, compile --force --warnings-as-errors, test --include integration test/integration/public_schema_compatibility_test.exs --warnings-as-errors` | no - Wave 0 | pending |
| DB-03 | Library migrations qualify Cairnloop-owned tables, indexes, references, constraints, functions, triggers, and raw SQL without relying on `mix ecto.migrate --prefix`. | unit + integration catalog assertions | `mix test test/cairnloop/migrations_test.exs --warnings-as-errors` plus `mix test.integration --only integration test/integration/schema_prefix_contract_test.exs` | partial | pending |
| DB-04 | Rollback paths never issue `DROP EXTENSION vector`, including example-app migration sources. | source scan + rollback proof where practical | `mix test test/cairnloop/migrations_test.exs --warnings-as-errors` | partial | pending |
| DB-05 | Runtime facades, workers, preloads, `Ecto.Multi`, bulk operations, fragments, and health checks honor Cairnloop's configured prefix while Oban remains host-owned. | integration | `mix test.integration --only integration test/integration/schema_prefix_runtime_test.exs` | no - Wave 0 | pending |
| DB-06 | Dedicated-schema and explicit-public modes are both proven against real Postgres. | integration | `mix ci.integration` plus `CAIRNLOOP_SCHEMA_PREFIX=public MIX_ENV=test mix do clean, compile --force --warnings-as-errors, test --include integration test/integration/public_schema_compatibility_test.exs --warnings-as-errors` | partial infrastructure | pending |
| DB-07 | Example app defaults Cairnloop support-domain setup to `schema_prefix: "cairnloop"` and can still run its tests. | example integration/smoke | `cd examples/cairnloop_example && mix test` | partial | pending |

---

## Wave 0 Requirements

- [ ] `test/integration/schema_prefix_contract_test.exs` - proves dedicated schema object placement, catalog visibility, FK/index/trigger/function placement, and public collision isolation for DB-01/DB-03/DB-06.
- [ ] `test/integration/public_schema_compatibility_test.exs` - proves explicit public compatibility for DB-02/DB-06 under `CAIRNLOOP_SCHEMA_PREFIX=public MIX_ENV=test mix do clean, compile --force --warnings-as-errors, test --include integration test/integration/public_schema_compatibility_test.exs --warnings-as-errors`.
- [ ] `test/integration/schema_prefix_runtime_test.exs` - proves facade, worker, preload, `Ecto.Multi`, bulk, fragment, doctor/health, and Oban-boundary behavior for DB-05.
- [ ] Extend `test/cairnloop/migrations_test.exs` - cover unprefixed DDL helper drift, example/test-host migrations, and absence of `DROP EXTENSION vector`.
- [ ] Extend `test/cairnloop/tasks/install_test.exs` - assert installer-generated migrations/config copy explain the dedicated-schema default and do not imply `mix ecto.migrate --prefix` alone is sufficient.
- [ ] Add or extend example app setup tests - assert example config/migrations use `schema_prefix: "cairnloop"` and support tables land in the dedicated schema while Oban remains host-owned.

---

## Manual-Only Verifications

All Phase 59 product behavior should have automated proof. Manual review is limited to checking installer/example/docs copy for precise public-compatibility wording and confirming no guidance frames `--prefix` as the complete contract.

---

## Validation Sign-Off

- [x] All phase requirements have an automated verification target or Wave 0 dependency.
- [x] Sampling continuity avoids long stretches without focused automated feedback.
- [x] Wave 0 names missing DB-backed and source-scan files before behavior work proceeds.
- [x] No watch-mode flags are required.
- [x] Feedback latency target is under 180 seconds for focused checks.
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** pending execution
