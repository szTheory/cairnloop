# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.3](https://github.com/szTheory/cairnloop/compare/v0.2.2...v0.2.3) (2026-05-30)


### Bug Fixes

* **router:** cairnloop_dashboard/2 compile break + verify-before-publish hardening ([21699d5](https://github.com/szTheory/cairnloop/commit/21699d5a057e1333ea167d484cb4aabd3b6e9fdd))
* **router:** cairnloop_dashboard/2 failed to compile for adopters ([dc0784f](https://github.com/szTheory/cairnloop/commit/dc0784f40419cefd766f687697ae1304e2b54802))

## [0.2.2](https://github.com/szTheory/cairnloop/compare/v0.2.1...v0.2.2) (2026-05-30)


### Bug Fixes

* **governance:** preserve approver as decided_by through execute co-commit ([607eaa5](https://github.com/szTheory/cairnloop/commit/607eaa550bb15f55c3aeee5828cc9a7d2123e156))
* **integration:** green the DB-backed integration CI suite ([9d4fedd](https://github.com/szTheory/cairnloop/commit/9d4feddf69e36036ca108488c23caa5def70599d))
* **web:** humanize audit-log action-filter options — no raw atom leak ([a6eb451](https://github.com/szTheory/cairnloop/commit/a6eb4511d80621e7aa03597de8c5fe22c04d44fa))

## [0.2.1](https://github.com/szTheory/cairnloop/compare/v0.2.0...v0.2.1) (2026-05-30)


### Bug Fixes

* **0.2.1:** repair AUDIT-01 audit log + OPS endpoints; adopt release-please ([bb74b1a](https://github.com/szTheory/cairnloop/commit/bb74b1af1dcd89573d070d0c3bb20eacb3cfe4e3))
* **0.2.1:** repair AUDIT-01 audit log + OPS health/metrics mounting ([62b7989](https://github.com/szTheory/cairnloop/commit/62b7989b00bd6f1f82b3c5abc1ebbf81026a795a))

## [Unreleased]

## [0.2.0] - 2026-05-29

### Added

- Security domain closure: `Cairnloop.KnowledgeAutomation` strictly rejects spoofed,
  already-published, and caller-supplied-grounding inputs — suggestions reuse only non-published
  targets, gap-candidate grounding derives exclusively from hydrated evidence, and stale-gate
  inputs load only from repo-backed `GapEvent` rows (Phase 33, SEC-01/02/03)
- Operator Settings Surface: `SettingsLive` gains real MCP token management (CRUD, masking,
  validation), Notifier and retrieval health indicators, and a persisted dark-mode toggle
  (Phase 34, SET-01/02/03/04)
- Audit & operations support: operator Audit Log view and governed-actions rail pagination
  (Phase 35, AUDIT-01, TECH-01)
- HTTP `/health` and `/metrics` endpoints via `Cairnloop.Web.HealthPlug` and
  `Cairnloop.Web.MetricsPlug` (Phase 35, OPS-01, OPS-02)
- Documentation: `guides/05-mcp-clients.md`, `guides/06-extending.md`, root `CONTRIBUTING.md`,
  and `docs/architecture.md` (Phase 36, DOC-01/02/03/04)
- Realistic demo fixtures: 12–16 seeded conversations spanning all JTBD states, 5 KB articles with revisions, 3 GapCandidates, 1 ArticleSuggestion ready for review (Phase 27)
- Customer `/chat` widget wired to real ingress via `Cairnloop.Channels.WidgetSocket` + `WidgetChannel`; two-tab demo (Phase 28)
- Brand-token CSS extraction: `prompts/cairnloop.css` `:root` block in example app; `var(--cl-token)` without hex fallback; negative-grep gate (Phase 29, D-10 closure)
- KB editorial polish: shared nav shell across 4 KB routes, "Create new article" affordance, gap-evidence sidebar in Editor, calm copy on SuggestionReview handoff (Phase 30)
- T-10-09 and T-10-11 closure: `EditorHandoff` double-layer gate (DB `manual_edit_opened_at` timestamp + signed token assertion) prevents preloading `proposed_markdown` without deliberate handoff (Phase 30)
- Golden-path JTBD smoke test in CI: `golden_path_test.exs` (E2E-01) + `widget_channel_test.exs` (E2E-02) under `mix test.integration` (Phase 31)
- README rewritten as an Igniter-first front door; four ExDoc guides (quickstart, JTBD walkthrough, host integration, troubleshooting) published to HexDocs (Phase 32)

## [0.1.0] - 2026-05-25

### Added
- Host-owned hybrid retrieval corpus (pgvector + PG full-text) via `Cairnloop.Retrieval`
- Operator search with trust, recency, and citation cues
- Citation-backed grounded drafting with clarification and escalation states
- Durable gap-event storage and ranked KB gaps dashboard
- AI-prepared KB draft/revision suggestions with stale-revision gating and citation validation
- Review-gated KB update workflow: approve, reject, defer, publish — with append-only task event history
- In-thread quick-fix KB maintenance launched from live support conversations
- Host-owned governed-action contract: compile-time `use Cairnloop.Tool` with risk tiers and deny-by-default `authorize/2`
- Durable `ToolProposal` + `ToolActionEvent` records with Stripe-style idempotency
- Approval state machine with Oban-backed resume, expiry, and deferral paths
- Three-layer at-most-once execution: Oban unique + terminal guard + SHA-256 per-attempt run key
- Bounded `[:cairnloop, :retrieval, …]` and `Cairnloop.Governance.Telemetry` event namespaces
- Read-only MCP seam (`tools/list`, `initialize`) via optional `Cairnloop.Web.MCP.Router` Plug

[Unreleased]: https://github.com/szTheory/cairnloop/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/szTheory/cairnloop/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/szTheory/cairnloop/releases/tag/v0.1.0
