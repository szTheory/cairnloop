---
phase: 54
slug: demo-wrapper-experience
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-28
updated: 2026-06-28
---

# Phase 54 - Validation Strategy

Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit through root `mix ci.fast`, plus shell and Docker Compose commands for wrapper behavior |
| **Config file** | Root `mix.exs`; example app `examples/cairnloop_example/mix.exs`; Compose file `examples/cairnloop_example/compose.demo.yml` |
| **Quick run command** | `bash -n bin/demo && ./bin/demo help && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet` |
| **Full suite command** | `mix ci.fast && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet && ./bin/demo smoke` |
| **Estimated runtime** | ~30s for quick checks; Docker smoke runtime depends on image/cache state |

## Sampling Rate

- **After every wrapper task commit:** Run `bash -n bin/demo && ./bin/demo help`.
- **After contract-test tasks:** Run `mix test test/cairnloop/demo_wrapper_contract_test.exs`.
- **After every plan wave:** Run `mix ci.fast && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet`.
- **Before `/gsd:verify-work`:** Run `mix ci.fast && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet && ./bin/demo smoke`.
- **Max feedback latency:** Keep DB-free checks under 60 seconds; Docker smoke may exceed that only because it builds/boots the demo stack.

## Generated Automated Tests

- `test/cairnloop/demo_wrapper_contract_test.exs` - DB-free source-contract coverage for BOOT-01 through BOOT-04 and VER-01 through VER-02:
  wrapper shell syntax/help, command aliases, printed route block, Compose-derived browser URLs, private Postgres networking, dynamic loopback web publishing, isolated smoke cleanup, locked smoke routes, port fallback, container-backed route checks, and bounded failure diagnostics.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 54-W0-01 | 01 | 0 | BOOT-01, BOOT-02, BOOT-03, BOOT-04, VER-01, VER-02 | T-54-01 / T-54-02 / T-54-03 | DB remains private; web binds localhost; wrapper cleanup stays Compose-project scoped | source/contract | `mix test test/cairnloop/demo_wrapper_contract_test.exs` | yes | green |
| 54-W1-01 | 02 | 1 | BOOT-03, BOOT-04, VER-02 | T-54-04 / T-54-05 | URLs come from `docker compose port web 4000`; failures include route/readiness URL and recent web logs | shell/source | `bash -n bin/demo && ./bin/demo help && mix test test/cairnloop/demo_wrapper_contract_test.exs` | yes | green |
| 54-W2-01 | 03 | 2 | BOOT-01, BOOT-02, BOOT-03, BOOT-04, VER-01, VER-02 | T-54-01 / T-54-02 / T-54-03 / T-54-04 / T-54-05 | Compose stack starts without host Elixir/Postgres, avoids DB host ports, prints discovered URLs, and smoke cleans up isolated stack | full smoke | `mix ci.fast && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet && ./bin/demo smoke` | yes | green |

## Wave 0 Requirements

- [x] `test/cairnloop/demo_wrapper_contract_test.exs` - DB-free source/contract assertions for command aliases/help, route block labels, no hard-coded `localhost:4000`, dynamic port discovery through `docker compose port web 4000`, no `db` host `ports`, web `host_ip: 127.0.0.1`, and smoke cleanup strings.
- [x] No framework install; use existing ExUnit, Bash, Docker Compose, and curl.
- [x] Keep Docker smoke out of ordinary unit tests; reserve `./bin/demo smoke` for wave/phase verification.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Browser inspection of visual dashboard layout | None in Phase 54 | Explicitly deferred; smoke is route-level HTTP, not browser E2E | Do not add browser walkthrough verification in this phase |

## Validation Audit 2026-06-28

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Audit findings:

- BOOT-01 through BOOT-04 and VER-01 through VER-02 are covered by `test/cairnloop/demo_wrapper_contract_test.exs`, the focused wrapper gate, Compose config validation, and the recorded Phase 54 Docker smoke evidence.
- The pre-existing validation map was stale after execution: task rows still said `pending` and `wave_0_complete` was `false` despite the generated test and verification summaries being complete.
- No new test files were required during this audit.

## Validation Sign-Off

- [x] All tasks have automated verify commands or Wave 0 dependencies.
- [x] Sampling continuity: no three consecutive tasks without automated verification.
- [x] Wave 0 covers source/contract proof for each Phase 54 requirement.
- [x] No watch-mode flags.
- [x] Feedback latency is acceptable for the command class being run.
- [x] `nyquist_compliant: true` set in frontmatter after the final plan/check loop confirms coverage.

**Approval:** approved 2026-06-28 after plan-checker PASS
