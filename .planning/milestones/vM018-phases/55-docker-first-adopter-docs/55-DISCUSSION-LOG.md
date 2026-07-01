# Phase 55: Docker-First Adopter Docs - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-06-28
**Phase:** 55-Docker-First Adopter Docs
**Areas discussed:** First-run narrative, URL and command truth, Troubleshooting taxonomy, Manual setup boundary, Smoke workflow documentation

---

## First-Run Narrative

| Option | Description | Selected |
|--------|-------------|----------|
| Docker first | Make `./bin/demo` the primary fresh-clone evaluation path everywhere. | yes |
| Manual first | Keep Elixir/Postgres setup as the initial path. | |
| Split equally | Present Docker and manual setup as equal first-run paths. | |

**User's choice:** Auto-ratified by repo decision policy.
**Notes:** `CLAUDE.md` instructs GSD discuss-phase to auto-decide ordinary gray areas and escalate at most one very-impactful call. Phase 55 is documentation alignment over an already verified wrapper/runtime contract, so no owner escalation was needed.

---

## URL And Command Truth

| Option | Description | Selected |
|--------|-------------|----------|
| Use wrapper output | Treat `./bin/demo` output and help text as canonical for commands and URLs. | yes |
| Document fixed localhost defaults | Tell Docker users to open hard-coded `localhost:4000`. | |
| Duplicate Compose details | Document raw Compose commands as the main path. | |

**User's choice:** Auto-ratified by repo decision policy.
**Notes:** Phase 54 locked dynamic URL discovery and command semantics. Docker docs should use printed URLs; `localhost:4000` belongs only to the manual local Phoenix path.

---

## Troubleshooting Taxonomy

| Option | Description | Selected |
|--------|-------------|----------|
| Docker-first taxonomy | Lead troubleshooting with Docker demo failures, then legacy install/setup issues. | yes |
| Append scattered notes | Add short Docker notes inside the existing legacy sections. | |
| Keep legacy-first | Leave troubleshooting ordered around installer and migration issues. | |

**User's choice:** Auto-ratified by repo decision policy.
**Notes:** DOC-03 explicitly names Docker unavailable, Compose v2 missing, port conflict, unhealthy stack, reset/reseed, and pgvector/manual Postgres confusion.

---

## Manual Setup Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Manual-only localhost | Keep `localhost:4000` only for `mix phx.server` manual local setup. | yes |
| No localhost references | Remove all `localhost:4000` docs even from manual examples. | |
| Hard-code for both paths | Use `localhost:4000` for Docker and manual paths. | |

**User's choice:** Auto-ratified by repo decision policy.
**Notes:** This keeps manual docs usable without violating the Docker-first dynamic-port contract.

---

## Smoke Workflow Documentation

| Option | Description | Selected |
|--------|-------------|----------|
| Document local smoke | Explain `./bin/demo smoke` as isolated, credential-free route smoke. | yes |
| Design CI workflow now | Add Phase 56 path filters and workflow details in this phase. | |
| Omit smoke details | Leave smoke undocumented until CI exists. | |

**User's choice:** Auto-ratified by repo decision policy.
**Notes:** DOC-04 asks maintainers to understand the smoke workflow without an OpenAI API key or external services. CI smoke remains Phase 56.

---

## Claude's Discretion

- No interactive user questions were asked because repo policy says the owner wants normal gray-area
  decisions made for them.
- No very-impactful irreversible decision was identified.
- Opportunistic package-version cleanup is allowed only when touched snippets would otherwise confuse
  adopters; it is not a new requirement.

## Deferred Ideas

- CI smoke workflow and path filters - Phase 56.
- Full browser walkthrough command - future DEMO-01.
- Screenshot refresh from Docker demo - future DEMO-02.
- Hosted public demo environment - future DEMO-03.
