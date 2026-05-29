---
phase: 32
slug: readme-exdoc-guides-jtbd-walkthrough
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-28
---

# Phase 32 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> This is a documentation phase — "tests" are render/build checks, not unit tests.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExDoc + Hex build tooling (no ExUnit tests apply to docs content) |
| **Config file** | `mix.exs` `docs:` and `package:` blocks |
| **Quick run command** | `mix docs` |
| **Full suite command** | `mix docs && mix hex.build` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix docs` (fast; no DB)
- **After every plan wave:** Run `mix docs && mix hex.build` + grep checks for DOC-01/DOC-04
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| DOC-01 | README | 1 | DOC-01 | — | N/A | manual/grep | `grep -n "mix cairnloop.install" README.md` | ✅ | ⬜ pending |
| DOC-02a | guides/01 | 1 | DOC-02 | — | N/A | smoke | `ls guides/01-quickstart.md` | ❌ W0 | ⬜ pending |
| DOC-02b | guides/02 | 1 | DOC-02 | — | N/A | smoke | `ls guides/02-jtbd-walkthrough.md` | ❌ W0 | ⬜ pending |
| DOC-02c | guides/03 | 1 | DOC-02 | — | N/A | smoke | `ls guides/03-host-integration.md` | ❌ W0 | ⬜ pending |
| DOC-02d | guides/04 | 1 | DOC-02 | — | N/A | smoke | `ls guides/04-troubleshooting.md` | ❌ W0 | ⬜ pending |
| DOC-03 | mix.exs | 1 | DOC-03 | — | N/A | build | `mix docs && mix hex.build` | ✅ | ⬜ pending |
| DOC-04 | CHANGELOG | 1 | DOC-04 | — | N/A | grep | `grep -n "Phase 32\|README rewritten" CHANGELOG.md` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `guides/` directory — created when the first guide is written; no framework install needed
- [ ] No automated content-correctness test for guide prose — correctness is by review against cited source files (inherent to a docs phase)

*Note: `mix compile --warnings-as-errors` (CLAUDE.md mandate) applies to the `mix.exs` edit — `mix.exs` must still compile cleanly. `mix test` is not required (no Elixir source changed).*

---

## Phase Gate Criteria

- `mix docs` clean (no warnings about missing extras/assets)
- `mix hex.build` lists all four guides in the tarball
- All four `guides/*.md` present on disk
- `README.md` leads with `mix cairnloop.install` (not bare deps block)
- `CHANGELOG.md` carries the vM014 `## [Unreleased]` entry

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| README section order correct | DOC-01 | Structure review needed | Read README top-to-bottom: badges → tagline → Installation (install cmd first) → Why Cairnloop → guides |
| Guide prose accuracy | DOC-02 | Content review | Verify guides cite correct routes (`/support`, `/support/:id`) not test routes (`/inbox`) |
| ExDoc sidebar "Guides" group visible | DOC-03 | Browser render | Run `mix docs`, open `doc/index.html`, verify "Guides" section in sidebar |
| CHANGELOG entry complete | DOC-04 | Content review | Read `## [Unreleased]` section for all 6 vM014 phase summaries |

---

## Security Notes

> Documentation-only phase — no ASVS threat surface (no auth, session, input handling, crypto, or new dependencies).
> `mix.exs` edit must still compile cleanly (`mix compile --warnings-as-errors`).
