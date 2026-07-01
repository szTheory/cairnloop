---
phase: 53
slug: demo-runtime-contract
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-28
updated: 2026-06-28
---

# Phase 53 - Validation Strategy

> Retroactive Nyquist validation audit for the demo runtime contract.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Root ExUnit DB-free source-contract checks, example-app ExUnit DB-backed seed checks, Docker Compose smoke for first-run runtime proof. |
| **Config file** | Root `mix.exs`; example app `examples/cairnloop_example/mix.exs`; `examples/cairnloop_example/config/*.exs`; `examples/cairnloop_example/compose.demo.yml`. |
| **Quick run command** | `mix test test/cairnloop/demo_runtime_contract_test.exs` |
| **Full suite command** | `mix ci.fast`, `mix ci.integration`, `mix ci.quality`, `PGPORT=5433 docker compose up -d db && cd examples/cairnloop_example && mix test --only requires_postgres test/cairnloop_example/seeds_test.exs`, and `./bin/demo smoke`. |
| **Estimated runtime** | Source-contract test: <1s after compile; full CI lanes and Docker smoke depend on deps/image cache. |

---

## Sampling Rate

- **After every runtime-contract source/doc task:** Run `mix test test/cairnloop/demo_runtime_contract_test.exs`.
- **After setup or seed changes:** Also run `PGPORT=5433 docker compose up -d db && cd examples/cairnloop_example && mix test --only requires_postgres test/cairnloop_example/seeds_test.exs`.
- **After Compose/Dockerfile changes:** Run `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet`; use `./bin/demo smoke` before phase verification.
- **Before `/gsd:verify-work`:** Run `mix ci.fast`, `mix ci.integration`, `mix ci.quality`, the DB-backed seed suite, and `./bin/demo smoke` when Docker is available.
- **Max feedback latency:** Source-contract feedback should stay under one task; Docker smoke is reserved for wave/phase verification.

---

## Generated Automated Tests

- `test/cairnloop/demo_runtime_contract_test.exs` - DB-free source-contract coverage for RUNT-01 through RUNT-05:
  setup alias ordering, Hex-vs-path dependency split, quiet runtime config, health/Compose readiness, Docker command shape, docs drift, setup-owned Trailmark seeds, and DB-backed seed-test presence.

Existing supporting coverage reused by this audit:

- `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` - DB-backed Trailmark seed readiness, chunks, review tasks, governed showcase states, MCP tokens, and idempotent reruns.
- `test/cairnloop/router_operations_test.exs`, `test/cairnloop/web/health_plug_test.exs`, and `test/cairnloop/web/health_metrics_route_test.exs` - operations macro and liveness plug behavior.
- `test/cairnloop/demo_wrapper_contract_test.exs` and `test/cairnloop/docs/docker_first_docs_test.exs` - later guardrails that continue to protect the Phase 53 Compose/docs surface.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 53-01-01 | 01, 05 | 1, 3 | RUNT-01 | T-53-01 | Host migrations run before Cairnloop library migrations; no merged migration path. | source + DB-backed command | `mix test test/cairnloop/demo_runtime_contract_test.exs`; `PGPORT=5433 docker compose up -d db && cd examples/cairnloop_example && mix ecto.reset` | yes | green |
| 53-01-02 | 01, 05 | 1, 3 | RUNT-02 | - | Example dogfoods local path dependency while adopter docs retain current Hex dependency guidance. | source/docs | `mix test test/cairnloop/demo_runtime_contract_test.exs`; `mix ci.quality` docs build | yes | green |
| 53-01-03 | 03, 05 | 1, 3 | RUNT-03 | T-53-02 | `/health` stays outside browser/session pipeline and returns non-sensitive liveness JSON; Compose readiness probes it. | source/route/compose | `mix test test/cairnloop/demo_runtime_contract_test.exs`; `cd examples/cairnloop_example && mix phx.routes \| rg '/health'`; `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` | yes | green |
| 53-01-04 | 02, 03, 05 | 1, 3 | RUNT-04 | T-53-03 / T-53-CHIMEWAY | Demo boot avoids missing Chimeway/Cairnloop notifier/config noise and keeps endpoint/database env bounded. | source/compile/runtime | `mix test test/cairnloop/demo_runtime_contract_test.exs`; `cd examples/cairnloop_example && mix compile --warnings-as-errors`; `./bin/demo smoke` | yes | green |
| 53-01-05 | 01, 04, 05 | 1, 2, 3 | RUNT-05 | T-53-04 | Trailmark seed data is loaded by setup, idempotent, and ready without a separate fixture command. | source + DB-backed ExUnit | `mix test test/cairnloop/demo_runtime_contract_test.exs`; `PGPORT=5433 docker compose up -d db && cd examples/cairnloop_example && mix test --only requires_postgres test/cairnloop_example/seeds_test.exs` | yes | green |

---

## Wave 0 Requirements

- [x] Add a DB-free source-contract test that covers every Phase 53 RUNT requirement.
- [x] Keep Docker and DB boot out of ordinary unit tests; reserve DB/Docker checks for focused lanes and phase verification.
- [x] Preserve current Hex dependency version in docs instead of pinning validation to stale `~> 0.1.0` copy.
- [x] Keep `/health` source coverage and Docker smoke as separate layers: source drift catches fast, smoke proves first-run runtime behavior.

---

## Manual-Only Verifications

All Phase 53 requirements now have automated or source-checkable verification. Manual browser click-through is optional UAT, not required for Nyquist compliance; the phase already has automated Docker route smoke evidence through `./bin/demo smoke`.

---

## Validation Audit 2026-06-28

| Metric | Count |
|--------|-------|
| Gaps found | 5 |
| Resolved | 5 |
| Escalated | 0 |

Resolved gap summary:

- RUNT-01: Added persistent source-contract coverage for setup alias migration order and seed ownership.
- RUNT-02: Added version-aware docs/source coverage for Hex dependency guidance vs repo-local path dependency dogfooding.
- RUNT-03: Added source-contract coverage for operations scope, private Compose DB, and `/health` readiness.
- RUNT-04: Added source-contract coverage for no-op notifier, bounded `PHX_BIND`, Chimeway repo quieting, and prod-only `DATABASE_URL`.
- RUNT-05: Added source-contract coverage that the DB-backed `:requires_postgres` seed suite exists and asserts idempotency.

## Validation Sign-Off

- [x] All tasks have automated verify commands or clear DB/Docker prerequisites.
- [x] Sampling continuity: no runtime/Docker/seed task lands without compile, source-contract, or targeted smoke feedback.
- [x] Wave 0 covers recurring drift risks with `test/cairnloop/demo_runtime_contract_test.exs`.
- [x] No watch-mode flags in verification commands.
- [x] Feedback latency remains under one task for source drift; DB/Docker checks are scoped to focused lanes.
- [x] `nyquist_compliant: true` set in frontmatter after audit proves the map is complete.

**Approval:** approved 2026-06-28 after retroactive Nyquist audit
