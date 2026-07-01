---
phase: 54-demo-wrapper-experience
verified: 2026-06-28T18:36:28Z
status: passed
score: "6/6 must-haves verified"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 54: Demo Wrapper Experience Verification Report

**Phase Goal:** Make `./bin/demo` the adopter-facing operational surface for the local demo.
**Verified:** 2026-06-28T18:36:28Z
**Status:** passed
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | BOOT-01: `./bin/demo` runs from the repository root with Docker Compose v2 as the only local runtime prerequisite. | VERIFIED | [bin/demo](/Users/jon/projects/cairnloop/bin/demo:4) resolves `ROOT` from the script path and [bin/demo](/Users/jon/projects/cairnloop/bin/demo:26) checks only Docker/Compose before lifecycle commands. [Dockerfile.demo](/Users/jon/projects/cairnloop/examples/cairnloop_example/Dockerfile.demo:3) supplies Elixir inside the image and [Dockerfile.demo](/Users/jon/projects/cairnloop/examples/cairnloop_example/Dockerfile.demo:40) runs `mix setup && exec mix phx.server`. Verifier-run `./bin/demo smoke` passed. |
| 2 | BOOT-02: the default Compose contract keeps Postgres private and avoids fixed Phoenix port collisions. | VERIFIED | [compose.demo.yml](/Users/jon/projects/cairnloop/examples/cairnloop_example/compose.demo.yml:4) defines `db` with no host `ports` block; [compose.demo.yml](/Users/jon/projects/cairnloop/examples/cairnloop_example/compose.demo.yml:39) publishes only `web` on `host_ip: ${CAIRNLOOP_BIND_HOST:-127.0.0.1}` with `published: ${CAIRNLOOP_WEB_PORT:-4100-4199}`. [bin/demo](/Users/jon/projects/cairnloop/bin/demo:132) retries occupied ports across a configured range. Verifier-run Compose config passed. |
| 3 | BOOT-03: the wrapper prints exact URLs discovered from the running Compose stack after health passes. | VERIFIED | [bin/demo](/Users/jon/projects/cairnloop/bin/demo:37) reads `docker compose port web "$CONTAINER_PORT"`, [bin/demo](/Users/jon/projects/cairnloop/bin/demo:67) waits for the published endpoint, [bin/demo](/Users/jon/projects/cairnloop/bin/demo:173) waits for `/health`, and [bin/demo](/Users/jon/projects/cairnloop/bin/demo:82) prints the required route block including index, cockpit, inbox, chat, KB, gaps, suggestions, audit log, settings, and health. |
| 4 | BOOT-04: wrapper subcommands cover URLs, logs, status, stop, down, reset, help, smoke, and aliases. | VERIFIED | [bin/demo](/Users/jon/projects/cairnloop/bin/demo:240) documents `start/up`, `smoke`, `urls`, `logs`, `stop`, `down`, `reset`, `ps/status`, and `help`; [bin/demo](/Users/jon/projects/cairnloop/bin/demo:266) wires those commands in the case statement. Verifier-run `./bin/demo help` and `./bin/demo status` passed. |
| 5 | VER-01: `./bin/demo smoke` boots an isolated stack, checks main routes, and cleans up containers and volumes afterward. | VERIFIED | [bin/demo](/Users/jon/projects/cairnloop/bin/demo:210) runs smoke in a subshell, [bin/demo](/Users/jon/projects/cairnloop/bin/demo:216) appends `_smoke_${smoke_id}` to the Compose project, [bin/demo](/Users/jon/projects/cairnloop/bin/demo:219) traps `compose down -v --remove-orphans`, and [bin/demo](/Users/jon/projects/cairnloop/bin/demo:227) checks the locked route list. Verifier-run smoke passed all routes and cleanup checks found no smoke containers, volumes, or networks. |
| 6 | VER-02: smoke failures produce actionable output with the failing route/command and recent web logs. | VERIFIED | [bin/demo](/Users/jon/projects/cairnloop/bin/demo:109) prints bounded recent web logs, [bin/demo](/Users/jon/projects/cairnloop/bin/demo:122) names failed Compose command boundaries, [bin/demo](/Users/jon/projects/cairnloop/bin/demo:173) names health timeout URLs, and [bin/demo](/Users/jon/projects/cairnloop/bin/demo:191) names failed smoke route URLs. [demo_wrapper_contract_test.exs](/Users/jon/projects/cairnloop/test/cairnloop/demo_wrapper_contract_test.exs:121) pins these diagnostics. |

**Score:** 6/6 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `bin/demo` | Adopter-facing wrapper | VERIFIED | 305 lines; substantive Bash implementation; `bash -n`, `help`, `status`, and `smoke` passed. |
| `test/cairnloop/demo_wrapper_contract_test.exs` | DB-free wrapper/Compose contract test | VERIFIED | 190 lines; 7 focused ExUnit tests passed; reads wrapper and Compose source directly. |
| `examples/cairnloop_example/compose.demo.yml` | Private DB and dynamic localhost web Compose contract | VERIFIED | Compose config passed; DB has no host ports; web uses dynamic loopback port mapping. |
| `examples/cairnloop_example/Dockerfile.demo` | Docker-owned Elixir runtime path | VERIFIED | Installs runtime/build dependencies in the image and runs `mix setup && exec mix phx.server`. |
| `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` | Mounted route inventory for smoke | VERIFIED | Mounts `cairnloop_dashboard("/support")`, `/`, `/chat`, and operations endpoints. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `bin/demo` | `examples/cairnloop_example/compose.demo.yml` | `COMPOSE_FILE` plus `compose()` helper | VERIFIED | [bin/demo](/Users/jon/projects/cairnloop/bin/demo:5) points at the demo Compose file; [bin/demo](/Users/jon/projects/cairnloop/bin/demo:22) runs `docker compose -f "$COMPOSE_FILE"`. |
| `bin/demo` | running Compose stack | `compose port web 4000` | VERIFIED | [bin/demo](/Users/jon/projects/cairnloop/bin/demo:37) discovers the runtime endpoint instead of assuming `localhost:4000`. |
| `bin/demo` | mounted demo routes | smoke route list | VERIFIED | Smoke routes in [bin/demo](/Users/jon/projects/cairnloop/bin/demo:227) match `/`, `/support`, `/support/inbox`, `/chat`, KB, audit log, and settings routes mounted by the example router and Cairnloop dashboard macro. |
| `test/cairnloop/demo_wrapper_contract_test.exs` | `bin/demo` and `compose.demo.yml` | `File.read!/1` assertions plus `bash -n` and `help` execution | VERIFIED | Focused test command passed with 7 tests, 0 failures. |
| `mix ci.fast` | wrapper contract test | default DB-free test suite | VERIFIED | Root [mix.exs](/Users/jon/projects/cairnloop/mix.exs:114) runs `test --exclude integration --warnings-as-errors`, which includes `test/cairnloop/demo_wrapper_contract_test.exs`. Executor-provided post-review evidence reported `mix ci.fast` green. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `bin/demo` | `endpoint` | `compose port web "$CONTAINER_PORT"` | Yes - read from the running Compose service | FLOWING |
| `bin/demo` | printed `url` | `url_from_endpoint` normalizes Compose host/port, then `print_urls` renders route block | Yes - verifier smoke discovered `http://127.0.0.1:4100` | FLOWING |
| `bin/demo` | smoke route checks | literal route list passed to `web_get`, which runs curl inside the web container | Yes - verifier smoke checked all locked routes successfully | FLOWING |
| `compose.demo.yml` | published web port | `CAIRNLOOP_WEB_PORT` default/range or override | Yes - Compose config accepts the range and smoke bound a live localhost port | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Shell syntax, help, contract test, Compose config, status | `bash -n bin/demo && ./bin/demo help && mix test test/cairnloop/demo_wrapper_contract_test.exs && docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet && ./bin/demo status` | Help printed all commands; 7 tests, 0 failures; Compose config passed; status exited 0. | PASS |
| Isolated Docker smoke | `timeout 300s ./bin/demo smoke` | Built/started unique `cairnloop_demo_561284970_smoke_93002` stack, waited for `http://127.0.0.1:4100/health`, checked `/`, `/support`, `/support/inbox`, `/chat`, `/support/knowledge-base`, `/support/knowledge-base/gaps`, `/support/knowledge-base/suggestions`, `/support/audit-log`, `/support/settings`, and printed `Docker demo smoke passed.` | PASS |
| Smoke cleanup | `docker ps/volume/network ls --filter name=cairnloop_demo_561284970_smoke_93002` | No containers, volumes, or networks remained after smoke exit trap. | PASS |

### Probe Execution

| Probe | Command | Result | Status |
|---|---|---|---|
| None declared or discovered | `find scripts -path '*/tests/probe-*.sh' -type f` | No phase probes found. | SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|---|---|---|---|---|
| BOOT-01 | 54-01, 54-03 | Fresh-clone adopter can run `./bin/demo` with Docker Compose v2 only. | SATISFIED | Wrapper checks only Docker/Compose locally; Dockerfile owns Elixir runtime; verifier smoke passed from repo root. |
| BOOT-02 | 54-01, 54-03 | Demo starts without fixed host port conflicts; Postgres stays private. | SATISFIED | Compose DB has no host ports; web uses loopback range; wrapper has port fallback; Compose config and smoke passed. |
| BOOT-03 | 54-01, 54-02, 54-03 | Adopter can see exact running URLs for all required demo surfaces and health. | SATISFIED | `print_urls` route block covers all labels and derives base URL from Compose port output after health. |
| BOOT-04 | 54-01, 54-02, 54-03 | Same wrapper covers URLs, logs, status, stop/down, reset, help. | SATISFIED | Help and case statement include all required commands and aliases; verifier `help` and `status` passed. |
| VER-01 | 54-01, 54-03 | Maintainer can run isolated smoke that checks main routes and cleans up. | SATISFIED | Verifier-run `./bin/demo smoke` passed; cleanup checks found no smoke resources. |
| VER-02 | 54-01, 54-02, 54-03 | Smoke failure output includes failing route and recent web logs. | SATISFIED | Source and contract test verify Compose, health, and route failure boundaries call bounded web-log diagnostics. Executor evidence included a real compose-up failure diagnostic during a port collision. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| None | - | No unreferenced TODO/FIXME/XXX/TBD, placeholders, global Docker prune, or stub implementations found in Phase 54 files. | - | - |

### Human Verification Required

None. The Phase 54 surface is covered by source contract tests, focused wrapper checks, Compose config validation, and verifier-run Docker smoke. Docs and CI smoke workflow remain explicitly assigned to Phases 55 and 56, not Phase 54.

### Gaps Summary

No blocking gaps found. Phase 54 achieves the adopter-facing wrapper goal: `./bin/demo` is the canonical operational surface for start/up, URL discovery, logs, status, stop/down/reset, help, and isolated smoke verification.

---

_Verified: 2026-06-28T18:36:28Z_
_Verifier: the agent (gsd-verifier)_
