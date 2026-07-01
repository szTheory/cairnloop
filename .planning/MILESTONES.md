# Milestones

## vM019 OSS Trust Baseline (Shipped: 2026-07-01)

**Delivered:** OSS trust hardening for Cairnloop as a respectful Phoenix/Ecto library: safer host boundaries, dedicated-schema persistence, truthful adoption docs, and source-backed CI/release confidence.

**Phases completed:** 5 phases (57-61), 27 plans, 69 tasks
**Audit:** tech debt accepted; 31/31 requirements implementation-satisfied, 0 requirement gaps, 0 integration blockers, 0 broken flows (`.planning/milestones/vM019-MILESTONE-AUDIT.md`)
**Archive:** `.planning/milestones/vM019-ROADMAP.md`, `.planning/milestones/vM019-REQUIREMENTS.md`, `.planning/milestones/vM019-phases/`

**Key accomplishments:**

- Produced a blunt evidence-backed OSS quality baseline and used it to drive host-boundary, schema, docs, and CI work instead of generic checklist polish.
- Separated customer/browser identity from operator identity across runtime persistence, widget ingress, dashboard actions, governance, recovery, search, and audit context.
- Made widget, email webhook, MCP JSON-RPC, optional Scrypath side effects, logs, telemetry, `/health`, and doctor output fail closed or report trust posture honestly.
- Defaulted new Cairnloop support-domain persistence to the dedicated `cairnloop` Postgres schema while preserving explicit `public` compatibility and keeping Oban host-owned.
- Updated installer output, README, Quickstart, Host Integration, Troubleshooting, MCP, Extending, Auth/Operator Identity, SECURITY, UPGRADING, CHANGELOG, ExDoc, package metadata, and example docs to match live code.
- Refreshed CI/release posture with current action/runtime choices, least-privilege workflow defaults, path-gated expensive checks, source-contract tests, bounded timing/cache evidence, and exact-SHA Hex publish preflight.

**Known accepted debt at close:** stale planning artifacts were reconciled during closeout; Phase 59 has final verification evidence in `59-07-SUMMARY.md` rather than a standalone `59-VERIFICATION.md`; validation frontmatter remains draft for phases 58-61; Phase 57 has no validation artifact; live GitHub branch protection and hosted-runner timing/cache value are next-run inspection items.

**What's next:** start a fresh milestone with `/gsd-new-milestone`; keep advanced product-surface epics adopter-pulled.

---

## vM018 Demo DX Adoption Proof (Shipped: 2026-06-29)

**Delivered:** Docker-first first-run proof for adopters: `./bin/demo` boots a private pgvector-backed example stack, prints real runtime URLs, proves seeded Trailmark surfaces, and gives CI a dedicated demo smoke gate.

**Phases completed:** 4 phases (53-56), 12 plans, 26 tasks
**Audit:** tech debt accepted; 17/17 requirements satisfied, 0 requirement gaps, 0 integration blockers, 0 broken flows (`.planning/milestones/vM018-MILESTONE-AUDIT.md`)
**Archive:** `.planning/milestones/vM018-ROADMAP.md`, `.planning/milestones/vM018-REQUIREMENTS.md`, `.planning/milestones/vM018-phases/`

**Key accomplishments:**

- Hardened the example runtime contract for Docker and manual local setup: local path dogfooding, ordered host-before-library migrations, setup-owned Trailmark seeds, quiet notifier/Chimeway/env config, and routable `/health`.
- Added the canonical adopter-facing `./bin/demo` wrapper with start/up, URL discovery, logs, status/ps, stop/down/reset, help, isolated smoke, automatic localhost port fallback, and bounded failure diagnostics.
- Kept the Docker demo Compose contract adopter-safe: private Postgres, dynamic or configured loopback Phoenix port, setup-before-server boot, and container-backed route checks.
- Rewrote README, Quickstart, example README, and Troubleshooting around the Docker-first path, printed URLs, optional OpenAI first-run scope, reset/log/smoke flows, and manual setup as secondary.
- Added DB-free source-scan tests for docs/wrapper/workflow drift plus a dedicated read-only `Demo smoke` GitHub Actions workflow that runs `./bin/demo smoke` for demo-relevant changes.
- Verified the stack with fast CI, quality gates, Compose config, DB-backed seed checks, integration evidence, and multiple local Docker smoke runs over the locked route list.

**Known accepted debt at close:** README high-level route copy omission; stale example `mix.exs` comment; demo-index hard-coded seed IDs need a future guard; `/health` remains liveness, not full DB readiness; smoke is HTTP route coverage, not browser automation; Phase 56 validation metadata is stale despite passing verification.

**Git range:** `a2e53df` -> `606ee06`
**Stats:** 68 commits; 70 files changed; 12,204 insertions and 164 deletions in the milestone range.

**What's next:** define the next adoption or maintenance milestone with `/gsd-new-milestone`; keep product-surface epics adopter-pulled.

---

## vM016 Operator UI/UX Iteration (Shipped: 2026-06-26)

**Phases completed:** 9 phases, 36 plans, 44 tasks
**Audit:** passed (`.planning/milestones/vM016-MILESTONE-AUDIT.md`)
**Archive:** `.planning/milestones/vM016-ROADMAP.md`, `.planning/milestones/vM016-REQUIREMENTS.md`, `.planning/milestones/vM016-phases/`

**Key accomplishments:**

- Built the shared operator UI primitive layer: `cl_page`, `cl_hero`, numeric-only `cl_stat`, native `cl_disclosure`, fact/source/status/switch primitives, layout tokens, inert utilities, and accessible table scrollers.
- Migrated Home, Inbox, Audit Log, Settings, and Knowledge Base screens through the shared page shell, including origin-aware KB breadcrumbs.
- Reworked the operator flow around a queue-first Home, resolved-filter recovery, safety-pinned rail disclosure, density controls, next-in-queue navigation, audit subject links, governed-action audit links, and KB-origin threading.
- Removed render-file color drift and hardened the brand-token gate against inline hex, raw color functions, and helper-returned render colors.
- Normalized the cockpit responsive layer around mobile-first breakpoints, browser-gated tap-target/bulk-bar geometry, CSS-only operator motion, and live reduced-motion proof.
- Seeded the final-brand demo state, regenerated light/dark screenshots, recorded a 36-row visual acceptance ledger, and closed the milestone with root tests, integration, `mix check`, E2E, screenshot capture, and milestone audit all green.

---

## vM017 Brand Identity System, Token Evolution & HTML Brand Book (Shipped: 2026-06-26)

**Phases completed:** 7 phases, 15 plans, 38 tasks

**Key accomplishments:**

- WCAG-AA contrast baseline (every fg/bg pairing × both themes, 3 real failures + 12 likely-exempt border failures flagged) and a per-token drift ledger (15 primitives all CLEAN, shadow-raised VALUE DRIFT + 5 semantic COVERAGE GAPs in app.css) establishing priv/static/cairnloop.css :root as the single canonical source
- Self-contained file:// direction board with four hand-authored SVG directions, locked C3.6 selection, and Refined/current-type preview evidence
- Locked C3.6 / Refined / current-type selection recorded with source, browser, Mix, and scope-guard evidence
- Refined palette tokens are applied canonically and mirrored to the example app plus prompt-token JSON, with a pure ExUnit verifier guarding drift, token renames, and Phase 46 contrast rows.
- Refined-token contrast evidence is captured against Phase 46 rows, and TOKEN-04 is complete with focused token, compile, full unit, integration, E2E, and forbidden-collateral scope gates green.
- C3.6 crowning-loop cairn production SVG family with path-authored wordmark, subtitle-free primary lockup, first-class mono/reverse variants, and separate tagline lockup.
- Simplified C3.6 favicon and 1200x630 OG/social card assets with ImageMagick raster exports under a 32KB committed raster footprint.
- Diagram-ready logo usage rules plus rejected-contest cleanup and final SVG/raster hygiene gates for the Phase 49 asset family.
- Offline static brandbook scaffold with deterministic token mirrors, provenance docs, and source/browser/package gates.
- Deterministic static brandbook assembly with DB-free source, package, status-label, and logo-download guards
- Complete offline HTML brand book with token-rendered sections, logo guidance, local theme toggle, and responsive CSS
- File-url Playwright proof for the standalone brand book plus final source/browser gate alignment
- README logo wiring plus DB-free collateral source guard for SVG, raster, and package hygiene
- Approved logo, favicon, and OG collateral wired into the Phoenix example app with Playwright browser proof
- Full automated collateral QA sweep with package boundary, contrast, raster, SVG, E2E, and diff-scope evidence

---

## vM015 — Operator Polish + Maintenance Gates (Shipped: 2026-05-30)

**Released as:** `cairnloop` v0.2.0 → v0.2.1 → v0.2.2 on Hex.pm (release-please pipeline)

**Phases completed:** 4 phases (33–36), 6 plans

**Key accomplishments:**

- **Security domain closure (Phase 33, SEC-01/02/03):** pinned (with new regression tests) that `Cairnloop.KnowledgeAutomation` already enforced T-10-10/12/13 at the domain layer — new-article suggestions reuse only non-published authoring targets, gap-candidate grounding derives exclusively from hydrated evidence (caller-supplied grounding overwritten + stripped), stale-gate inputs load only from repo-backed `GapEvent` rows plus fresh canonical grounding. No production logic change; the gap was missing tests.
- **Operator Settings cockpit (Phase 34, SET-01/02/03/04):** `SettingsLive` gained real MCP token CRUD (masking, validation, raw token shown once at creation), Notifier reachability indicators, retrieval health (pgvector index status + Oban failed-queue jobs via `Cairnloop.Retrieval`), and a persisted inline dark-mode toggle with no JS hook.
- **Audit & operations support (Phase 35, AUDIT-01/OPS-01/OPS-02/TECH-01):** `Cairnloop.Web.AuditLogLive` at `/audit-log`; `Cairnloop.Web.HealthPlug` (`/health`) + `Cairnloop.Web.MetricsPlug` (`/metrics`, Prometheus via optional `telemetry_metrics_prometheus_core`); `Cairnloop.Auditor` behaviour extended with `list_events/1`; governed-actions rail pagination via `Governance.list_proposals_for_conversation/2` `:limit` + `load_more_actions`.
- **Documentation & release (Phase 36, DOC-01..04/REL-01/REL-02):** `guides/05-mcp-clients.md`, `guides/06-extending.md`, root `CONTRIBUTING.md`, `docs/architecture.md`; milestone release cut and published.
- **Release-please pipeline adopted:** repo migrated to the canonical szTheory pipeline (`release-please-config.json`, `.github/workflows/release-please.yml`, `release_gate` in `ci.yml`). Future releases are a `fix:`/`feat:` commit on `main` → bot PR → auto-tag + `publish-hex`.
- **Integration CI suite greened + gated:** the DB-backed integration suite (red since before v0.2.0, 3 clusters) was fixed and added to `release_gate` — shipped as v0.2.2.

**Release arc (audit-driven remediation):** v0.2.0 shipped first, but the same-day milestone audit (`milestones/vM015-MILESTONE-AUDIT.md`) found AUDIT-01 (no-op stub audit log), OPS-01/02 (plugs mounted in no router), and REL-01 (missing `## [0.2.0]` CHANGELOG, falsely claimed done). All four remediated and republished as **v0.2.1**. Integration-suite fixes + governance `decided_by` preservation shipped as **v0.2.2**.

**Stats:**

- Phases: 4 (33–36) · Plans: 6
- Hex releases: v0.2.0 (2026-05-29) → v0.2.1 (2026-05-30) → v0.2.2 (2026-05-30)
- Git: includes PRs #2 (remediation), #4 (workflow cleanup), #5 (state reconcile), #6 (integration suite green), #7 (release-please 0.2.2)

**Known deferred items at close:** verification debt — phases 33/34/35 shipped without `VERIFICATION.md`; Nyquist `*-VALIDATION.md` exists only for phase 36 (code is green in CI through v0.2.2). Backfill via `/gsd-verify-work` if required. Pre-existing vM014 open artifacts (phases 27/28 verification, 27/31 UAT) acknowledged as deferred — see STATE.md Deferred Items.

> **Diminishing-returns line reached.** Cairnloop hits "done enough for stated scope" at vM015 close. vM016+ is adoption + maintenance, not features (Epics 12/13/14 stay out of scope until an adopter pulls).

---

## vM014 — Adoption Proof (Shipped: 2026-05-29)

*(Record reconstructed after the fact at vM015 close — vM014 was archived without a MILESTONES.md
entry, a "lightweight-close" gap. Dates/counts from `milestones/vM014-ROADMAP.md` + phase summaries.)*

**Phases completed:** 7 phases (27–32, +32.1 close-gap), 25 plans

**Goal:** A reasonable adopter clones cairnloop, runs `mix setup` in the example app, opens two
browser tabs, walks the full Jobs-To-Be-Done lifecycle live, and the same path is locked into CI —
closing the adopter-surface gap remaining after vM013, with zero churn to sealed primitives.

**Key accomplishments:**

- **Realistic demo fixtures (Phase 27, FIX-01..04):** JTBD-spanning seed set (12–16 conversations across all states, 5 KB articles with revisions, GapCandidates with evidence, an ArticleSuggestion ready for review) driving embeddings through the live `ChunkRevision` Oban worker — the example self-tests the M008 retrieval substrate on first boot.
- **Customer `/chat` wired to real ingress (Phase 28, CHAT-01..03):** replaced the mock chat with a real `Cairnloop.Channels.WidgetSocket` + `WidgetChannel` round trip; two-tab operator↔customer demo.
- **Brand-token CSS extraction / D-10 closure (Phase 29, BRAND-01..04):** canonical `:root` brand tokens in the example app, inline hex fallbacks dropped (`var(--cl-token)`), headless-token assertions re-pinned behind a negative-grep gate.
- **KB editorial polish + T-10-09/T-10-11 closure (Phase 30, KB-01..04, SEC-01..02):** shared editorial nav shell across 4 KB routes, "Create new article" affordance, gap-evidence sidebar, calm SuggestionReview copy, and an `EditorHandoff` double-layer gate (DB `manual_edit_opened_at` marker) closing the two `editor.ex`/`suggestion_review.ex`-shaped threats.
- **Golden-path JTBD smoke test in CI (Phase 31, E2E-01..03):** `golden_path_test.exs` + `widget_channel_test.exs` under `mix test.integration` (Phoenix.LiveViewTest/ChannelTest — no Wallaby, no PhoenixTest dep).
- **README + ExDoc guides + JTBD walkthrough (Phase 32, DOC-01..04):** README as an Igniter-first front door; four guides (quickstart, JTBD walkthrough, host integration, troubleshooting) wired to HexDocs; CHANGELOG `[Unreleased]` populated.

**Known open artifacts at close (accepted, not backfilled):** phase 27 & 31 HUMAN-UAT pending
scenarios; phase 28 & 30 VERIFICATION human_needed. Per the SATD decision rule, archived per-phase
analysis is documented-and-accepted rather than reconstructed (see STATE.md Deferred Items).

**Stats:**

- Phases: 7 (27–32 + 32.1) · Plans: 25 · v1 requirements: 24 (all satisfied)
- Timeline: 2026-05-27 → 2026-05-29

---

## vM013 Support-Triggered Outbound Lifecycle (Shipped: 2026-05-27)

**Phases completed:** 2 phases, 6 plans, 15 tasks

**Key accomplishments:**

- Cairnloop.Outbound.BulkEnvelope schema + cairnloop_outbound_bulk_envelopes migration + two narrow Cairnloop.Governance cohort-eligibility reads (list_eligible_conversation_ids_for_bulk_recovery/1, preview_bulk_recovery_cohort/1) so InboxLive (plan 03) can show a fail-closed bulk-recovery confirmation modal without ever running a direct Ecto query from the web layer (D-14).
- Cairnloop.Outbound.bulk_trigger/2 + private build_trigger_multi/2 shared helper + additive :bulk_envelope_id opt on the sealed trigger/2 + Oban unique: dedup keys on OutboundWorker, all landed without churning the Phase 22/23 sealed primitive. InboxLive (plan 03) can now call a single envelope function that enforces the D-09 cap, snapshots the rendered template body on a durable BulkEnvelope row, and fans out per-recipient deliveries under one Ecto.Multi with at-most-once Oban semantics (D-11).
- InboxLive becomes a checkbox-driven multi-select cockpit: `@selected_ids :: MapSet.t/0`, a sticky bottom bulk-action bar with the brand-primary `Send recovery follow-up to N` button, a `<.focus_wrap>` confirmation modal that snapshots the rendered template body at confirm-open time, a calm fail-closed refusal banner (icon + danger token + reason-forward copy) for oversized cohorts, and a submit handler that calls `Cairnloop.Outbound.bulk_trigger/2` and surfaces per-outcome calm flash copy without ever leaking a raw Elixir term to the operator.
- OpenInference trace lane + delivery-side bounded metrics for the outbound domain, mirroring Phase 17 verbatim — new `Cairnloop.Outbound.Telemetry.Traces` module on the disjoint `[:cairnloop, :outbound, :trace, …]` 4-segment namespace, delivery telemetry on all four arms of `OutboundWorker.perform/1`, and OI emissions wired alongside (never replacing) the sealed `:telemetry.span/3` blocks in `Outbound.trigger/2`, `bulk_trigger_submit/6`, and `bulk_trigger_refused/6` (all three refusal arms).
- Narrow `Cairnloop.Governance` audit READ facade for the Phase 25 `BulkEnvelope` substrate — two new functions (`list_recent_bulk_outbound_envelopes/1` + `get_bulk_outbound_envelope/1`) appended after `preview_bulk_recovery_cohort/1`, both routed through `repo().all/1` / `repo().get/2` per D-14 (zero direct `Cairnloop.Repo` references), guarded by the `@bulk_envelope_hard_cap 500` `ArgumentError` rail (T-26-06 DoS mitigation), accepting an optional `:status` enum filter (`:submitted | :refused_cap_exceeded | :all`) — plus a D-05 regression block in `outbound_test.exs` that pins the EXACT auditor metadata key set on both `:outbound_trigger` and `:bulk_outbound_trigger` lanes via `Enum.sort()`-equality + negative `refute Map.has_key?` for PII-rich extras (T-26-07 mitigation).
- Pure template-patch polish pass on `InboxLive` and `ConversationLive` — closes the Phase 26 roadmap success criterion 3 ("tightens empty/error states and outbound affordance polish") by adding (a) the calm "No conversations yet." empty-state paragraph under `<h1>Inbox</h1>`, (b) the top-right × close button affordance inside the bulk-confirm dialog (aria-label="Close", 44px tap target, muted-color glyph anchored by `position: relative` on the dialog, placed as the FIRST child of the dialog so `<.focus_wrap>` lands focus there on modal-open per Pitfall 6), and (c) the calm reason-forward subhead "Delivery did not complete. Try again from the Outbound recovery card." below the failed-delivery chip on `:system_outbound` messages with `metadata["status"] == "failed"` — additive only, sealed chip + `outbound_recovery_card/1` + `outbound_status_label/1` byte-for-byte unchanged per Pitfall 7. D-10 (brand-token CSS extraction) explicitly deferred — the inline `var(--cl-<token>, <hex>)` strings are the headless-test contract.

---

## vM012 — Public Release & MCP Write Surface

**Shipped:** 2026-05-26 (archive backfilled 2026-05-27)

**Key accomplishments:**

- Packaged Cairnloop for public consumption: MIT license, `CHANGELOG.md` (Keep-a-Changelog), `mix.exs` package metadata, and ExDoc with semantic module groups — published as `cairnloop` v0.1.0 on Hex.pm via automated `.github/workflows/release.yml` (HEX_API_KEY in GitHub Secrets; any `v*` tag push publishes package + docs).
- Shipped a runnable example host: `examples/cairnloop_example` boots with `mix setup` (pgvector + host + library migrations + seed data), mounts the dashboard at `/support`, and exposes a mock customer `ChatLive` at `/chat` — with documented `cairnloop_dashboard` macro caveat workaround for 0.1.0.
- Added an Ecto-backed OAuth Bearer seam for remote MCP clients: `cairnloop_mcp_tokens` table with SHA-256 hashing, `Cairnloop.MCP` context (`issue_token` / `validate_token` / `revoke_token`), `AuthPlug` + `WellKnownPlug` (RFC 9728), and protocol version aligned to `2025-11-05`.
- Opened the first MCP write surface without compromising vM011's trust model: `tools/call` routes through `Cairnloop.Governance.propose/3` with `origin: :mcp`, `mcp_token_id`, and `tool_params`; JSON-RPC outcomes mapped to standard codes; idempotency-key reuse returns the same proposal; integration tests pass against real pgvector.

**Stats:**

- Phases: 4 (18–21)
- Plans: 7
- Timeline: 2026-05-25 → 2026-05-26 (~1.5 days)
- Git commits: 19 (`84d9a95` → `6cc87d8`)
- Known deferred items at close: 2 (broad external MCP public surface; high-risk financial/destructive mutations as first governed action — both intentionally out of scope) plus the archive-hygiene gap (this entry backfilled on 2026-05-27 during vM013 close).

---

## vM011 — AI Tool Governance & MCP Integration

**Shipped:** 2026-05-25

**Key accomplishments:**

- Established a host-owned compile-time-validated governed-tool contract (`use Cairnloop.Tool`) with durable `ToolProposal` + append-only `ToolActionEvent` records; proposals are fail-closed on unsupported tools, missing input, invalid scope, or denied policy — never execute inline.
- Built a humanized in-thread operator timeline with hybrid preview cards (snapshotted trust facts + best-effort live prose fallback); raw Elixir terms and color-alone state kept off the operator surface.
- Added a durable `ToolApproval` state machine (approve / reject / defer / expiry / resume) with one-active-lane invariant; resume re-validates via a new Oban job before execution — never inline `run/3`.
- Shipped the first narrow approved write path: `ToolExecutionWorker` (sole `run/3` caller) with three-layer at-most-once idempotency (Oban unique + terminal guard + SHA-256 per-attempt run key) and bounded telemetry.
- Added an optional OpenInference-conformant evidence lane (`Cairnloop.Governance.Telemetry.Traces`, 7 call sites across governance + workers) with payload-content exclusion and zero Scoria dependency.
- Delivered a read-only MCP seam (`Cairnloop.Web.MCP.Router` + `ToolProjector`): `tools/list` + `initialize` only, `-32601` for all write methods — core approval and execution truth unchanged.

**Stats:**

- Phases: 5 (13–17)
- Plans: 17
- Timeline: 2026-05-23 → 2026-05-25 (3 days)
- Git commits: 146
- Codebase at close: ~15,389 LOC Elixir
- Known deferred items at close: 2 (root SECURITY.md carries 5 pre-existing open threats from vM010; AR-14-02 governed-actions rail lacks pagination)

## vM010 - KB AI Maintenance

**Shipped:** 2026-05-23

**Key accomplishments:**

- Turned retrieval no-hits, weak grounding, and repeated manual handling into a ranked, inspectable
  KB gap queue.

- Shipped citation-backed draft article and revision suggestions that fail closed when evidence or
  grounding is insufficient.

- Added a durable review-task workflow with explicit approve, reject, defer, and publish
  boundaries separate from suggestion truth.

- Unified KB maintenance inside `/knowledge-base/suggestions`, including visible history and
  publish or reindex follow-through.

- Let operators launch KB maintenance directly from conversation context while preserving
  shell/manual fallback inside the shared review lane.

- Added bounded maintenance telemetry for gap creation, suggestion outcomes, review decisions,
  publish, and reindex events.

**Stats:**

- Phases: 4
- Plans: 15
- Tasks: 16
- Timeline: 2026-05-21 -> 2026-05-23
- Git range: `1c8b2ca` -> `42613c8`
- Code delta at close: 253 files changed, 37599 insertions, 316 deletions
- Known deferred items at close: 2 technical debt items (split Phase 10/12 closure artifacts
  across planning layouts; unrelated `Chimeway.Repo` boot noise during focused tests)

## vM009 - Retrieval-First Support Answers & Search Ops

**Shipped:** 2026-05-21

**Key accomplishments:**

- Built a host-owned hybrid retrieval corpus over published Knowledge Base content and resolved
  support evidence.

- Shipped a retrieval-backed `cmd+k` operator search flow with source, trust, recency, and
  citation cues.

- Grounded AI drafts in explicit retrieval evidence with visible clarification and escalation
  states.

- Added bounded retrieval telemetry and durable gap-event storage so future KB maintenance work can
  start from real miss signals.

- Closed the remaining operator-search scope blocker and backfilled milestone verification so all
  nine requirements are traced as verified.

**Stats:**

- Phases: 8
- Plans: 14
- Timeline: 2026-05-17 -> 2026-05-21
- Git range: `2adb75d` -> working tree closeout
- Code delta at close: 30 files changed, 3230 insertions, 181 deletions
- Known deferred items at close: 2 technical debt items (repo-backed realism lanes blocked in this
  workspace; duplicated search-surface guard lists)

## vM006 - Omnichannel SLA Escalation (Chimeway)

**Shipped:** 2026-05-15

**Key accomplishments:**

- Implemented SLA Countdown Engine via Oban for durably tracking conversation SLA timers.
- Defined `Cairnloop.Notifier` behaviour for omnichannel notification delivery.
- Integrated Chimeway to dispatch actionable SLA breach notifications securely and safely without hardcoding external integrations.
- Exposed configuration for host applications to route SLA breach messages to Slack, PagerDuty, or Email.

**Stats:**

- Phases: 2
- Plans: 2

## vM005 - Durable Auditing & SRE Observability

**Shipped:** 2026-05-13

**Key accomplishments:**

- Integrated `Cairnloop.Auditor` behavior for immutable audit logging of critical operator actions.
- Integrated with Parapet to surface Service Level Indicators (SLIs) via Telemetry without cardinality explosions.
- Scaffolded SLO alerts and diagnostic runbooks via Igniter for enterprise compliance.

**Stats:**

- Phases: 3
- Plans: 2

## vM004 - Customer Voice Activation

**Shipped:** 2026-05-12

**Key accomplishments:**

- Implemented core telemetry pipeline for conversation resolution (`[:cairnloop, :conversation, :resolved]`).
- Added robust host extensibility and documentation for reacting to resolution events.
- Created durable Customer Satisfaction (CSAT) data models and storage.
- Integrated frictionless CSAT rating capture into the widget channel with related telemetry emission.

**Stats:**

- Phases: 2
- Plans: 2

## vM003 - Deep Context Enrichment

**Shipped:** 2024-05-11

**Key accomplishments:**

- Implemented robust `Cairnloop.ContextProvider` behaviour for zero API sync.
- Built a dynamic evidence rail and context pane UI in `ConversationLive`.
- Created Extensibility Components & Actions (`Cairnloop.Tool`) for custom action injection.

**Stats:**

- Phases: 3
- Plans: 3
- Lines of code: 1037 insertions, 123 deletions
