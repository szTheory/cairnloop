# Milestone vM012: Public Release & MCP Write Surface

**Status:** ✅ SHIPPED 2026-05-26
**Phases:** 18–21
**Total Plans:** 7

## Overview

vM012 packaged the host-owned governance substrate built in vM011 for public consumption and
opened the first MCP write surface. The milestone shipped the v0.1.0 Hex.pm release with
automated CI publishing, a runnable example Phoenix app exercising the dashboard, an
Ecto-backed OAuth Bearer seam for remote MCP clients, and a `tools/call` adapter that routes
write-capable tool invocations through the existing `Cairnloop.Governance.propose/3` pipeline —
preserving the fail-closed, proposal-first contract from vM011.

## Phases

### Phase 18: Release Gate & Hex.pm Publish

**Goal**: Package Cairnloop for public consumption on Hex.pm with automated CI publishing.
**Depends on**: Phase 17 (vM011)
**Plans**: 3 plans

Plans:

- [x] 18-01-PLAN.md — Configure package metadata, MIT license, and CHANGELOG for Hex.pm publish.
- [x] 18-02-PLAN.md — Hex.pm publish gate validation (CI-automated initial publish).
- [x] 18-03-PLAN.md — Automated CI release workflow on `v*` tag push.

**Details:**

- MIT-licensed under szTheory; ExDoc configured with semantic module groups.
- v0.1.0 published to Hex.pm via `.github/workflows/release.yml` (HEX_API_KEY in GitHub Secrets).
- Tag-driven release: any `v*` tag push automatically publishes both package and documentation.

**Delivered:**
- `LICENSE` (MIT), `CHANGELOG.md` (Keep-a-Changelog v0.1.0 entry), `mix.exs` package metadata.
- `.github/workflows/release.yml` GitHub Actions workflow for automated publish.
- v0.1.0 tagged and live on hex.pm.

---

### Phase 19: Example Phoenix App

**Goal**: Show host integrators how to consume Cairnloop end-to-end inside a real Phoenix app.
**Depends on**: Phase 18
**Plans**: 1 plan

Plans:

- [x] 19-01-PLAN.md — Generate example app, wire deps + migrations + seeds, mount dashboard, add mock customer chat.

**Details:**

- `examples/cairnloop_example` boots with `mix setup`: pgvector extension + host + library migrations + seed data.
- Dashboard mounted at `/support`; mock customer chat (`ChatLive`) at `/chat`.
- Brand CSS tokens injected into `assets/css/app.css`.
- README documents setup, configurations, integrations, and routing.

**Delivered:**
- Runnable demonstrator host app with seeded `Conversation`, `Message`, `Article`, `Revision`.
- Documented `cairnloop_dashboard` macro caveat (manual route expansion in 0.1.0 due to upstream `live/3` import gap).
- Host-app `Oban` + `cairnloop` integration patterns shown in working code.

---

### Phase 20: MCP OAuth Seam

**Goal**: Add Ecto-backed OAuth Bearer token lifecycle for remote MCP clients with RFC 9728 metadata.
**Depends on**: Phase 19
**Plans**: 2 plans

Plans:

- [x] 20-01-PLAN.md — `cairnloop_mcp_tokens` migration + `Cairnloop.MCP.Token` schema + `Cairnloop.MCP` context (`issue_token/1`, `validate_token/1`, `revoke_token/1`) with SHA-256 hashing.
- [x] 20-02-PLAN.md — `AuthPlug` (Bearer extract + validate) + `WellKnownPlug` (RFC 9728 metadata) + Router 401 guard on `tools/call` + protocol version bump to `2025-11-05`.

**Details:**

- Tokens stored as SHA-256 hashes; raw token returned once at issue and never persisted.
- `:crypto.strong_rand_bytes(32)` for token generation.
- `AuthPlug` assigns `mcp_token` to `conn` without halting (Router decides 401 per method).
- `WellKnownPlug` serves application-env-configured RFC 9728 metadata.

**Delivered:**
- `lib/cairnloop/mcp.ex`, `lib/cairnloop/mcp/token.ex`, OAuth-style `cairnloop_mcp_tokens` table.
- `Cairnloop.Web.MCP.AuthPlug` + `WellKnownPlug` + Router auth gate.
- Protocol version aligned with MCP `2025-11-05`.

---

### Phase 21: MCP Write Tools

**Goal**: Route MCP `tools/call` invocations through `Governance.propose/3` so writes participate
in the existing approval-gated execution lane — never inline `run/3`.
**Depends on**: Phase 20
**Plans**: 1 plan

Plans:

- [x] 21-01-PLAN.md — `tools/call` handler in `Cairnloop.Web.MCP.Router`; JSON-RPC 2.0 result mapping; idempotency; integration tests against real pgvector.

**Details:**

- `handle_method(_, "tools/call", _, _)` calls `Cairnloop.Governance.propose/3` with `origin: :mcp`, `mcp_token_id`, `tool_params`.
- Governance outcomes mapped to JSON-RPC: `{:ok, proposal}` → success with `proposal.id` + status; `:unsupported` → `-32601`; `:needs_input` → `-32602` with changeset errors; other `:blocked` → success with `isError: true` + reason; `:error` → `-32603`.
- `actor_id` strictly prefixed `mcp_token:` for audit traceability; no atoms dynamically generated from user input.

**Delivered:**
- MCP write surface that respects vM011's proposal-first contract — no synchronous execution.
- Integration tests (`mix test --include integration test/cairnloop/web/mcp/router_test.exs`) pass against real pgvector (9 tests, 100%).
- HTTP 200 preserved for JSON-RPC error envelopes (auth-failure remains a real 401).

---

## Milestone Summary

**Key Decisions:**

- Automated initial Hex.pm publish via CI (no manual `mix hex.publish` step) — `HEX_API_KEY` already in GitHub Secrets.
- MIT license under szTheory copyright.
- Example app uses port 5433 to share the project's pgvector docker-compose instance.
- Tokens stored as SHA-256 hashes; raw token shown once at issue.
- MCP write surface routes through `Governance.propose/3` — never inline `run/3`, preserving vM011's three-layer at-most-once idempotency.
- `actor_id` for MCP-originated proposals is prefixed `mcp_token:<id>` to keep audit reconstruction unambiguous.

**Issues Addressed:**

- Previously, no clean way for hosts to consume Cairnloop without vendoring.
- vM011's MCP seam was read-only (`tools/list` + `initialize`); vM012 opens the safe write path.
- Phoenix 1.7 `heroicons` dependency caveat resolved (reverted to GitHub v2.1.1 in example).
- `cairnloop_dashboard` macro `live/3` import gap documented; manual route expansion shown as workaround.

**Issues Deferred:**

- Broader external MCP server surface open to untrusted third-party public clients.
- High-risk financial or destructive mutations as the first governed-action path.
- Library-side fix for the `cairnloop_dashboard` macro `live/3` import — host expansion works for 0.1.0.

**Technical Debt Incurred:**

- Root `SECURITY.md` still carries 5 open threats (T-10-09..T-10-13) — pre-existing vM010 debt, untouched by vM012.
- AR-14-02: governed-actions rail has no pagination — re-evaluate as MCP write volume grows.
- vM012 was originally "closed" only by docs-flipping ROADMAP + STATE without producing the archive files; backfilled on 2026-05-27 during the vM013 close to restore archive hygiene.

---

_For current project status, see .planning/ROADMAP.md_
_Archived (backfilled): 2026-05-27_
