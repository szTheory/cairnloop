---
phase: 56
slug: demo-smoke-ci-gate
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-28
---

# Phase 56 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit via Mix 1.19.5 |
| **Config file** | `mix.exs` aliases and `test/test_helper.exs` |
| **Quick run command** | `mix test test/cairnloop/demo_smoke_workflow_contract_test.exs --warnings-as-errors` |
| **Full suite command** | `mix ci.fast` |
| **Estimated runtime** | ~60-180 seconds for fast suite; Docker smoke is environment-dependent |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/cairnloop/demo_smoke_workflow_contract_test.exs --warnings-as-errors` once the contract test exists.
- **After every plan wave:** Run `mix ci.fast`.
- **Before `/gsd:verify-work`:** Run `mix ci.fast`, `docker compose -f examples/cairnloop_example/compose.demo.yml config --quiet`, and `./bin/demo smoke` when Docker is available.
- **Max feedback latency:** 3 minutes for source-level checks; Docker smoke may exceed this and is still required when available.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 56-TBD-01 | TBD | TBD | VER-03 | T-56-01 | Workflow triggers only on credential-free demo-relevant path changes and exposes a stable read-only `demo-smoke` job. | source contract | `mix test test/cairnloop/demo_smoke_workflow_contract_test.exs --warnings-as-errors` | No, W0 | pending |
| 56-TBD-02 | TBD | TBD | VER-03 | T-56-02 | Workflow runs the canonical `./bin/demo smoke` wrapper with a bounded timeout instead of duplicating raw Compose commands. | source contract + smoke | `mix ci.fast` and `./bin/demo smoke` | Workflow draft exists; source contract missing | pending |
| 56-TBD-03 | TBD | TBD | VER-04 | T-56-03 | Verification remains fully automated and does not create a human UAT checkpoint for smoke, route, or browser-rendered behavior. | process/source gate | `mix ci.fast`; no `HUMAN-UAT.md` or manual checkpoint for Phase 56 | No Phase 56 verification artifact yet | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `test/cairnloop/demo_smoke_workflow_contract_test.exs` - DB-free source contract test covering Phase 56 trigger, path filter, permission, timeout, and command guarantees.
- [ ] No new framework install is needed; ExUnit already covers the repo's source-contract testing pattern.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None | VER-03, VER-04 | All phase behaviors must have automated source, CI, Docker, or browser evidence. | Do not add human UAT checkpoints. If Docker is unavailable locally, record the environment blocker and provide source-level workflow proof. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing references
- [ ] No watch-mode flags
- [ ] Feedback latency < 3 minutes for source-level checks
- [ ] `nyquist_compliant: true` set in frontmatter after Wave 0 test exists and automated checks are green

**Approval:** pending
