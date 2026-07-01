# Phase 54: Demo Wrapper Experience - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-06-28
**Phase:** 54-Demo Wrapper Experience
**Areas discussed:** Wrapper command surface, ports and URL discovery, readiness and smoke, failure diagnostics, verification boundary

---

## Wrapper Command Surface

| Option | Description | Selected |
|--------|-------------|----------|
| Harden `./bin/demo` in place | Preserve the existing single entry point and command names while improving behavior and diagnostics. | yes |
| Add a parallel wrapper | Introduce Makefile/npm/Mix aliases around Compose. | |
| Redesign command vocabulary | Rename commands and treat compatibility as secondary. | |

**User's choice:** Auto-ratified by repo policy.
**Notes:** `CLAUDE.md` says normal gray areas should be researched and decided without asking the owner. The existing wrapper already matches the roadmap command set, so replacement would add drift.

---

## Ports And URL Discovery

| Option | Description | Selected |
|--------|-------------|----------|
| Dynamic localhost web port with private DB | Keep Postgres private and discover Phoenix URLs from `docker compose port web 4000`. | yes |
| Fixed localhost Phoenix port | Simpler to explain, but violates the no fixed-port-collision requirement. | |
| Publish DB to host | Easier manual DB inspection, but broadens local surface and violates the Phase 54 guardrail. | |

**User's choice:** Auto-ratified by repo policy.
**Notes:** This directly satisfies BOOT-02 and BOOT-03 while preserving Phase 53 Compose behavior.

---

## Readiness And Smoke

| Option | Description | Selected |
|--------|-------------|----------|
| `/health`-gated HTTP smoke | Wait for real health, then curl the main demo routes. | yes |
| Browser E2E walkthrough | Higher fidelity, but explicitly out of scope for this phase. | |
| Log/sleep-based readiness | Flaky and disconnected from the routed readiness probe. | |

**User's choice:** Auto-ratified by repo policy.
**Notes:** Phase 54 should keep smoke high-signal and stable; Phase 56 owns CI integration and future smoke workflow gating.

---

## Failure Diagnostics

| Option | Description | Selected |
|--------|-------------|----------|
| Calm route-specific diagnostics | Print the failing readiness URL or route plus recent web logs. | yes |
| Raw Compose/log dump | More data, but noisier and less adopter-facing. | |
| Minimal exit code only | Fast, but fails VER-02 actionable diagnostics. | |

**User's choice:** Auto-ratified by repo policy.
**Notes:** Diagnostics should be useful to adopters without leaking long internal noise. Recent web logs are the minimum; DB logs remain available through `./bin/demo logs`.

---

## Verification Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Wrapper/source checks plus Docker smoke | Verify command behavior and route reachability without turning this into browser automation. | yes |
| Full release-gate stack by default | Strong but too broad unless runtime/config/seeds change. | |
| Manual UAT checkpoint | Explicitly rejected by vM018 verification posture. | |

**User's choice:** Auto-ratified by repo policy.
**Notes:** Use `docker compose ... config --quiet`, `./bin/demo smoke`, and repo compile/fast checks as the core proof. Add broader lanes only if files touched warrant them.

---

## Claude's Discretion

- No owner escalation was required. The phase contains operational wrapper decisions that are cheap to revise and already constrained by ROADMAP.md, REQUIREMENTS.md, Phase 53 evidence, and `CLAUDE.md`.

## Deferred Ideas

- Full browser walkthrough command - future DEMO-01.
- Screenshot refresh from Docker demo - future DEMO-02.
- Hosted public demo - future DEMO-03.
- Docker-first docs narrative - Phase 55.
- CI smoke workflow/path filters - Phase 56.
