# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0](https://github.com/szTheory/cairnloop/compare/v0.4.0...v0.5.0) (2026-06-03)


### Features

* **automation:** swappable draft-generator seam + Anthropic adapter ([6632b4e](https://github.com/szTheory/cairnloop/commit/6632b4e87fafba912d03f55617301a9ae6540c0c))
* **automation:** swappable draft-generator seam + Anthropic adapter ([ea9bf96](https://github.com/szTheory/cairnloop/commit/ea9bf968cc8ddc3f5cacc90c1b396f84ee2463b8))

## [0.4.0](https://github.com/szTheory/cairnloop/compare/v0.3.0...v0.4.0) (2026-06-03)


### Features

* **ui:** add Cockpit Home + persistent nav shell (IA orientation layer) ([fa24f9d](https://github.com/szTheory/cairnloop/commit/fa24f9d69cc792f16fc2b5875ecdaeccf4d3d13c))
* **ui:** design-system + IA elevation for the operator UI ([ebed003](https://github.com/szTheory/cairnloop/commit/ebed003a29798f4f39aec7f1ed18d3d7c70ed41b))
* **ui:** finish Conversation Workspace rail on the design system (Pass 6) ([d680ca4](https://github.com/szTheory/cairnloop/commit/d680ca4dd27cc22e50996c0980f1afeb07bab4da))
* **ui:** rebuild Audit Log on the design system (Pass 3, screen 2) ([517da98](https://github.com/szTheory/cairnloop/commit/517da9854b1046d941db1efca33e36dee8d2058b))
* **ui:** rebuild Conversation Workspace on the design system (Pass 3) ([8b4c362](https://github.com/szTheory/cairnloop/commit/8b4c362affb6e195881a1aafd9bcc3129c76c459))
* **ui:** rebuild Settings on the design system (Pass 3, screen 1) ([71ad202](https://github.com/szTheory/cairnloop/commit/71ad20218eeb32f46f26adba7a9d0068c43e86ce))
* **ui:** rebuild the Knowledge Base cluster on the design system (Pass 3) ([f543de4](https://github.com/szTheory/cairnloop/commit/f543de4a6bf8acc5a24924602e1ae962bb76f4bd))
* **ui:** rebuild the operator Inbox on the design system (Pass 3) ([e40dc55](https://github.com/szTheory/cairnloop/commit/e40dc5596e0f23130de2fb21c8fd986183f9ccf4))
* **ui:** ship cairnloop.css design system + shared component library ([0c96516](https://github.com/szTheory/cairnloop/commit/0c96516ec6b68b2c9521a153a838d4e7d261505a))


### Bug Fixes

* **ui:** green the integration gate — restore bare brand tokens ([eb73bb2](https://github.com/szTheory/cairnloop/commit/eb73bb2057d0bd867498dabf4a8542741e39ad0c))

## [0.3.0](https://github.com/szTheory/cairnloop/compare/v0.2.3...v0.3.0) (2026-05-30)


### Features

* add mix cairnloop.doctor wiring diagnostic ([24e71f9](https://github.com/szTheory/cairnloop/commit/24e71f9268124f2547d0ddc7b7ea62829047319e))
* **installer:** print router/auditor/doctor next steps after install ([bcacf69](https://github.com/szTheory/cairnloop/commit/bcacf69482c284b397689996eeac9243e2bdf396))
* mix cairnloop.doctor + validated router opts + installer next-steps (Tier 2 DX) ([7f559c2](https://github.com/szTheory/cairnloop/commit/7f559c2c2837c2d25a1f92499243ed2169f5d96b))
* **router:** validated, self-documenting macro options + live_session name ([5524e82](https://github.com/szTheory/cairnloop/commit/5524e82eb3afe2b163a044e50659cbe3c1d03510))

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
