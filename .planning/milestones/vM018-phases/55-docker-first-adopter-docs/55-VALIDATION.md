---
phase: 55
slug: docker-first-adopter-docs
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-28
updated: 2026-06-28
---

# Phase 55 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit plus Mix aliases |
| **Config file** | `mix.exs` |
| **Quick run command** | `mix ci.fast` |
| **Full suite command** | `mix ci.quality` |
| **Estimated runtime** | ~120-300 seconds, excluding optional Docker smoke |

---

## Sampling Rate

- **After every task commit:** Run the narrowest relevant source assertion plus `mix ci.fast` when the touched docs affect package/docs output.
- **After every plan wave:** Run `mix ci.fast`; run `mix ci.quality` after docs/package-facing edits settle.
- **Before `/gsd:verify-work`:** `mix ci.fast` and `mix ci.quality` must be green. Run Docker smoke only if Docker is available and not already proven unavailable by environment output.
- **Max feedback latency:** 300 seconds for non-Docker gates; 600 seconds when `./bin/demo smoke` is included.

## Generated Automated Tests

- `test/cairnloop/docs/docker_first_docs_test.exs` - DB-free ExUnit source-scan coverage for DOC-01 through DOC-04:
  README and Quickstart Docker-first ordering, wrapper command vocabulary from `./bin/demo help`, dynamic Docker URL guidance, manual-local-only `localhost:4000`, troubleshooting taxonomy, optional `OPENAI_API_KEY` scope, and locked smoke route coverage.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 55-01-01 | 01 | 1 | DOC-01 | T-55-01 / misleading first-run path | Docker first-run docs do not mislead users into thinking host Elixir/Postgres are required for evaluation. | source/docs | `mix test test/cairnloop/docs/docker_first_docs_test.exs --warnings-as-errors`; `mix ci.fast`; `mix ci.quality` | yes | green |
| 55-01-02 | 01 | 1 | DOC-01, DOC-04 | T-55-02 / stale command vocabulary | Command names in README and Quickstart match `./bin/demo help`. | CLI/source | `./bin/demo help`; `mix test test/cairnloop/docs/docker_first_docs_test.exs --warnings-as-errors` | yes | green |
| 55-02-01 | 02 | 1 | DOC-02 | T-55-03 / hard-coded Docker URL | Example README sends Docker users to the printed base URL plus route path, with `localhost:4000` reserved for manual local Phoenix. | source | `mix test test/cairnloop/docs/docker_first_docs_test.exs --warnings-as-errors`; `rg -n "localhost:4000" examples/cairnloop_example/README.md` | yes | green |
| 55-02-02 | 02 | 1 | DOC-02, DOC-04 | T-55-04 / stale route names | Example README route names match Phase 54 route coverage and do not invent missing pages. | source/CLI | `./bin/demo help`; `mix test test/cairnloop/docs/docker_first_docs_test.exs --warnings-as-errors` | yes | green |
| 55-03-01 | 03 | 2 | DOC-03 | T-55-05 / unbounded troubleshooting | Troubleshooting is symptom-first and points to bounded wrapper diagnostics before raw Compose output. | source/docs | `mix test test/cairnloop/docs/docker_first_docs_test.exs --warnings-as-errors`; `rg -n 'Docker|Compose v2|port|healthy|reset|reseed|pgvector|OPENAI_API_KEY|./bin/demo logs|./bin/demo status|./bin/demo reset|./bin/demo smoke|/health' guides/04-troubleshooting.md` | yes | green |
| 55-03-02 | 03 | 2 | DOC-04 | T-55-06 / external-service prerequisite drift | Docs state `OPENAI_API_KEY` is optional for first-run boot, route smoke, and seeded click-through without implying production AI never needs configuration. | source/CLI | `./bin/demo help`; `mix test test/cairnloop/docs/docker_first_docs_test.exs --warnings-as-errors`; `timeout 300s ./bin/demo smoke` | yes | green |

---

## Wave 0 Requirements

- [x] `test/cairnloop/docs/docker_first_docs_test.exs` - DB-free ExUnit docs consistency test for the multi-file Docker-first docs surface.
- [x] The source scan asserts Docker-facing docs do not hard-code `localhost:4000` except in manual-local contexts.
- [x] The source scan asserts troubleshooting covers the locked Docker demo failure taxonomy from `55-CONTEXT.md`.
- [x] Every affected plan also recorded explicit `rg`/source assertion commands and final verification evidence.

---

## Manual-Only Verifications

All phase behaviors have automated or source-checkable verification. Human UAT is not required for Phase 55.

---

## Validation Audit 2026-06-28

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

Audit findings:

- DOC-01 through DOC-04 are covered by `test/cairnloop/docs/docker_first_docs_test.exs`, `./bin/demo help`, `mix ci.fast`, `mix ci.quality`, Docker Compose config validation, and the recorded Phase 55 Docker smoke evidence.
- The pre-existing validation map was stale after execution: task rows still said `pending` and `wave_0_complete` was `false` despite the generated source-scan test and verification summaries being complete.
- No new test files were required during this audit.
- The local `gsd-tools` install does not expose the documented `loop render-hooks verify:post` command; validation was treated as enabled because this phase already has `55-VALIDATION.md` and `nyquist_compliant: true`.

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or Wave 0 source-scan dependencies.
- [x] Sampling continuity: no three consecutive tasks without automated verification.
- [x] Wave 0 covers all missing recurring-drift references.
- [x] No watch-mode flags.
- [x] Feedback latency target documented and met by DB-free checks; Docker smoke remains a bounded phase gate.
- [x] `nyquist_compliant: true` set in frontmatter after audit confirms coverage.

**Approval:** approved 2026-06-28 after retroactive Nyquist audit
