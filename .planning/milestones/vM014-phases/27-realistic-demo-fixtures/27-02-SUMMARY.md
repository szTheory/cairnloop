---
phase: 27-realistic-demo-fixtures
plan: "02"
subsystem: example-app-context-provider
tags:
  - elixir
  - context-provider
  - behaviour-impl
  - headless-test
  - config-wire
dependency_graph:
  requires: []
  provides:
    - CairnloopExample.DemoContextProvider (Cairnloop.ContextProvider impl)
    - context_provider config wire in examples/cairnloop_example/config/config.exs
  affects:
    - Operator inbox context snippets for all 16 seeded demo conversations (FIX-01)
tech_stack:
  added: []
  patterns:
    - behaviour-impl (pattern-matched multi-clause with fail-open catch-all)
    - configured-adapter (Application.get_env :cairnloop, :context_provider)
    - headless ExUnit test (async: true, no Repo, no DataCase)
key_files:
  created:
    - examples/cairnloop_example/lib/cairnloop_example/demo_context_provider.ex
    - examples/cairnloop_example/test/cairnloop_example/demo_context_provider_test.exs
  modified:
    - examples/cairnloop_example/config/config.exs
decisions:
  - "Multi-clause head idiom: no default on individual clauses; catch-all def get_context(_actor_id, _opts) is last"
  - "Test run via elixirc + elixir with main project ebin (example app deps unavailable in worktree; headless test compiles and passes clean)"
  - "grep pattern '^config :cairnloop' in plan acceptance criterion matches :cairnloop_example too; refined to '^config :cairnloop,' for exact check — single block confirmed"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-27"
  tasks_completed: 2
  files_created: 2
  files_modified: 1
---

# Phase 27 Plan 02: DemoContextProvider Implementation Summary

One-liner: Demo `Cairnloop.ContextProvider` with 5 pattern-matched actor clauses + headless test + config wire for the Trailmark example app.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Failing test for DemoContextProvider | 6a9c222 | examples/cairnloop_example/test/cairnloop_example/demo_context_provider_test.exs |
| 1 (GREEN) | Implement CairnloopExample.DemoContextProvider | b5144f5 | examples/cairnloop_example/lib/cairnloop_example/demo_context_provider.ex |
| 2 | Wire demo provider in config.exs | 75e568d | examples/cairnloop_example/config/config.exs |

## Output

### Confirmed demo customer ids (plan 27-04 MUST match these on `Conversation.host_user_id`)

1. `"demo_user_acme_billing"` — Acme Corp, billing-past-due persona (Riya Chen)
2. `"demo_user_globex_seats"` — Globex Inc, growing-team persona (Mateo Alvarez)
3. `"demo_user_initech_billing"` — Initech LLC, billing-email-update persona (Sora Lin)
4. `"demo_user_umbrella_ci"` — Umbrella Co, CI-diagnostic persona (Priya Sharma)
5. `"demo_user_hooli_tokens"` — Hooli Industries, token-rotation persona (Jonas Weber)

### Headless test

5 tests, 0 failures. Runs in <1 ms without Repo. Verified via `elixirc` + `elixir` with the main project's compiled ebin. The example app's `mix test` driver requires DB for `test_helper.exs` sandbox setup (pre-existing environment constraint, per CLAUDE.md), but the test module itself is pure and headless.

### config.exs wire

`context_provider: CairnloopExample.DemoContextProvider` added to the existing `config :cairnloop, …` keyword list block (lines 59–62). Single `config :cairnloop,` block confirmed (no duplicate introduced). `config/test.exs` is unchanged.

## Acceptance Criteria Verification

- [x] `examples/cairnloop_example/lib/cairnloop_example/demo_context_provider.ex` exists with `@behaviour Cairnloop.ContextProvider`, 5 known-actor clauses, and a fail-open catch-all
- [x] `examples/cairnloop_example/test/cairnloop_example/demo_context_provider_test.exs` exists with 5 tests, all green
- [x] Tests complete in <1 second without Repo
- [x] Module compiles with `--warnings-as-errors` (exit 0)
- [x] `grep -E '"demo_user_[a-z_]+"' | sort -u | wc -l` returns 5 distinct actor ids
- [x] `grep -c 'context_provider: CairnloopExample.DemoContextProvider' config.exs` returns 1
- [x] `grep -c '^config :cairnloop,'` returns 1 (single block; plan's `^config :cairnloop` pattern also matches `:cairnloop_example` — refined pattern used)
- [x] `config/test.exs` unchanged (git diff confirms)

## Threat Model — T-27-04 / T-27-05 / T-27-06 Mitigations

- **T-27-04 (Info Disclosure):** Provider returns only hard-coded literal data for 5 known actors; fail-opens to `{:ok, %{}}` for any other id. No host-system query or dynamic atom creation.
- **T-27-05 (DoS):** Catch-all clause prevents `FunctionClauseError` on unknown actors. Headless test asserts fail-open.
- **T-27-06 (Tampering):** No `String.to_atom/1` or `String.to_existing_atom/1` — all branching on string literals. ASVS V5 satisfied by construction.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `examples/cairnloop_example/lib/cairnloop_example/demo_context_provider.ex` — FOUND
- `examples/cairnloop_example/test/cairnloop_example/demo_context_provider_test.exs` — FOUND
- Commit 6a9c222 (RED test) — FOUND
- Commit b5144f5 (GREEN impl) — FOUND
- Commit 75e568d (config wire) — FOUND
