# Cairnloop Project

## What This Is
An embedded, Phoenix-native customer support automation layer that turns support conversations into answers, product signals, knowledge-base improvements, safe governed actions, and durable support-triggered outbound follow-up — all inside the host app.

## Core Value
Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.

## Current Focus

No milestone is active. vM019 OSS Trust Baseline shipped on 2026-07-01; the next step is to define
fresh requirements for the next adopter-pulled maintenance or product milestone.

## Next Milestone Goals

- Start with `/gsd-new-milestone` so requirements are defined from current adopter signals before
  any new phase work starts.
- Before opening a substantial new milestone, run a pre-milestone repo hygiene pass: clean local
  worktrees, triage GitHub PRs, verify main CI, review `[Unreleased]`, and confirm GSD is between
  milestones. Do not publish Hex.pm unless explicitly chosen for that pass.
- Inspect live GitHub Actions branch protection, hosted-runner timing/cache behavior, and release
  artifacts after the next PR/main/release run.
- Keep Epic 12 advanced routing, Epic 13 local AI, Epic 14 mobile SDK, and hosted-demo work out of
  scope unless a real adopter pulls them.

## Current State

**Latest shipped milestone: `vM019 OSS Trust Baseline` on 2026-07-01. Current published version remains `cairnloop` v0.5.1 on Hex.pm; vM019 did not cut a Hex release because it hardened trust boundaries, schema defaults, docs, and CI/release confidence rather than publishing a package release.**

**What is now true (cumulative through vM019 close):**
- Cairnloop has a host-owned hybrid retrieval layer over published Knowledge Base content and resolved support evidence (vM008–vM009).
- Operators have a retrieval-backed `cmd+k` search flow with explicit source, recency, trust, and citation cues (vM009).
- Durable gap signals project into a ranked KB maintenance queue with inspectable evidence and stable candidate identity (vM010).
- AI-prepared article and revision suggestions are citation-backed, inspectable, and fail closed when evidence or grounding is insufficient (vM010).
- KB review runs through durable review tasks with explicit approve, reject, defer, publish, and reindex follow-through states (vM010).
- Operators can launch maintenance directly from conversation context without creating a second workflow surface (vM010).
- Cairnloop has a host-owned governed-tool contract (`use Cairnloop.Tool`) with compile-time validation, risk tiers, approval modes, and durable `ToolProposal` + append-only `ToolActionEvent` records (vM011).
- Governed action proposals fail closed on unsupported tools, missing input, invalid scope, or denied policy — never execute inline (vM011).
- Operators see humanized in-thread governed action cards with snapshotted trust facts, risk/approval-mode chips, and a hybrid preview surface (vM011).
- Risky actions move through a durable `ToolApproval` state machine (approve / reject / defer / expiry / resume) with one-active-lane invariant and append-only decision history (vM011).
- First narrow approved write path is proven: `ToolExecutionWorker` with three-layer at-most-once idempotency (Oban unique + terminal guard + SHA-256 per-attempt run key) and bounded telemetry (vM011).
- An optional OpenInference-conformant evidence lane and read-only MCP seam (`tools/list` + `initialize`) exist as additive adapters (vM011).
- Cairnloop is publicly consumable: published as `cairnloop` v0.1.0 on Hex.pm via automated CI on `v*` tag push (MIT-licensed); ExDoc with semantic module groups; runnable example Phoenix host app at `examples/cairnloop_example` (vM012).
- MCP write surface is open: `tools/call` routes through `Cairnloop.Governance.propose/3` with Ecto-backed OAuth Bearer auth (SHA-256 hashed tokens) and RFC 9728 metadata at the well-known endpoint — never inline `run/3` (vM012).
- Cairnloop has a sealed support-triggered outbound lane: `Cairnloop.Outbound.trigger/2` (single-conversation) + `bulk_trigger/2` (multi-conversation fan-out with `BulkEnvelope` audit row, `max_batch_size = 25` cap, Oban `unique:` at-most-once delivery), `system_outbound` messages appended to the `Conversation` timeline, `OutboundWorker` durably routing through `Cairnloop.Notifier` (Chimeway-backed) (vM013).
- Operators see distinct outbound timeline bubbles with Pending/Sent/Failed chips in `ConversationLive`, can trigger resolved-only recovery from the sidebar, and can multi-select resolved conversations in `InboxLive` for bulk fan-out via a `<.focus_wrap>` confirmation modal with snapshotted body + first-5 recipient sample + fail-closed refusal banner for oversized cohorts (vM013).
- Outbound observability is OpenInference-conformant: `Cairnloop.Outbound.Telemetry.Traces` on the disjoint `[:cairnloop, :outbound, :trace, …]` namespace; bounded-metrics spans on every terminal arm of `OutboundWorker.perform/1`, `trigger/2`, and `bulk_trigger/2`; narrow `Cairnloop.Governance` audit READ facade (`list_recent_bulk_outbound_envelopes/1`, `get_bulk_outbound_envelope/1`) (vM013).
- Cairnloop includes realistic seeded fixtures covering the full JTBD lifecycle (conversations, KB articles, gaps, suggestions) and an integration test harness that proves the golden path against real Postgres (vM014).
- The embedded `/chat` channel uses the real `WidgetChannel` ingress path, enabling a live two-tab local demo (vM014).
- Brand-token CSS extraction is complete, providing a canonical `:root` contract with no inline hex fallbacks in the core render files (vM014).
- The Knowledge Base features a unified editorial nav shell, missing creation affordances added, and auditable handoff markers for security closures (vM014).
- Comprehensive ExDoc guides (Quickstart, JTBD Walkthrough, Host Integration, Troubleshooting) are shipped and integrated directly into the Hex docs (vM014).
- The remaining vM010 domain-layer security debt is closed: `Cairnloop.KnowledgeAutomation` unconditionally rejects spoofed, already-published, and caller-supplied-grounding inputs (T-10-10/12/13), pinned with regression tests (vM015).
- Operators have a real `SettingsLive` cockpit: MCP token CRUD (masking, validation, raw shown once), Notifier reachability, retrieval health (pgvector index + Oban failed jobs), and a persisted dark-mode toggle (vM015).
- Adopters and operators have operability surfaces: `Cairnloop.Web.AuditLogLive` (`/audit-log`), `/health` (`HealthPlug`) and `/metrics` (`MetricsPlug`, Prometheus via optional `telemetry_metrics_prometheus_core`) mountable via `cairnloop_operations/1`, `Auditor.list_events/1`, and governed-actions rail pagination (vM015).
- Adopters have MCP-client and extension guides (`guides/05-mcp-clients.md`, `guides/06-extending.md`), `CONTRIBUTING.md`, and `docs/architecture.md` (vM015).
- The repo ships releases through the canonical szTheory **release-please** pipeline (`fix:`/`feat:` commit on `main` → bot PR → auto-tag + `publish-hex`), gated on a now-green DB-backed integration suite in `release_gate` (vM015).
- Cairnloop has a final brand foundation: C3.6 crowning-loop logo family, refined canonical tokens and derivatives, favicon/OG assets, offline brand book, and wired README/example-app collateral with package-boundary proof (vM017).
- The operator/admin cockpit now has shared page primitives, queue-first Home IA, shell-wide breadcrumbs, progressive rail disclosure, cross-screen threading, mobile-first responsive behavior, CSS-only motion, final-brand demo fixtures, light/dark screenshot evidence, and full release-gate verification (vM016).
- The example app runtime contract is hardened for Docker and manual local setup: ordered host-before-library migrations, local path dependency dogfooding with Hex docs, `/health` readiness, quiet notifier/Chimeway/env config, setup-owned Trailmark seeds, DB-backed seed idempotency, and Docker smoke all passed (vM018 Phase 53).
- The canonical `./bin/demo` wrapper is now the adopter-facing operational surface: start/up, discovered URL printing, logs, status/ps, stop/down/reset, help, isolated smoke, bounded diagnostics, automatic localhost port fallback, and container-backed route checks all passed Phase 54 verification.
- The adopter docs now tell one Docker-first story across README, Quickstart, the example README, and Troubleshooting: `./bin/demo` comes first, Docker users follow printed URLs, manual local setup is secondary, OpenAI credentials are optional for first-run/smoke/seeded click-through, and a DB-free docs source-scan test guards the story (vM018 Phase 55).
- CI now proves the Docker demo path with a dedicated read-only `Demo smoke` workflow: manual, weekly, push, and pull-request triggers cover demo-relevant files, `./bin/demo smoke` remains the canonical runner-owned command, a DB-free ExUnit source contract pins workflow drift, and full Docker smoke verification passed locally (vM018 Phase 56).
- Cairnloop has an evidence-backed OSS trust baseline: 36-dimension software-quality evaluation, CI/CD topology/runtime audit, Postgres schema-prefix implementation contract, and local DB-free timing/compile/xref evidence (vM019 Phase 57).
- Host-app trust boundaries are now safer by default: customer/browser identity persists as `customer_ref`, operator actions require dashboard session identity, widget/email/MCP ingress fail closed before sensitive work, optional Scrypath side effects are inert by default, logs/telemetry are bounded, `/health` is liveness-only, and doctor owns readiness/trust diagnostics (vM019 Phase 58).
- New Cairnloop installs default support-domain persistence to the dedicated `cairnloop` Postgres schema while explicit `public` compatibility, qualified migrations/runtime paths, safe vector rollback, Oban host ownership, integration proof, and example-app setup are preserved (vM019 Phase 59).
- The public adoption path is now source-backed for installer, upgrade, package, ExDoc, security, MCP, extending, and auth/operator-identity guidance: fresh host installs use `mix igniter.install cairnloop`, package/docs assets build through `mix ci.quality`, `SECURITY.md` is a public OSS policy, and DB-free source scans pin DOC-01 through DOC-06 (vM019 Phase 60).
- CI/release posture is source-guarded: current action/runtime choices, least-privilege workflow defaults, path-gated expensive checks, maintainer timing/cache summaries, workflow source-contract tests, and exact-SHA Hex publish preflight are in place (vM019 Phase 61).

**Active milestone:** none. vM019, vM018, vM017, and vM016 are archived under `.planning/milestones/`.

## Architectural Invariants

These patterns have proven across vM011/vM012/vM013 close audits and are now project-level invariants. New milestones MUST honor them; subagents MUST NOT re-litigate them.

1. **Sealed-contract + additive-opts.** Once a public function ships (e.g. `Cairnloop.Outbound.trigger/2`, `Cairnloop.Governance.propose/3`, MCP `tools/call`), its signature is sealed byte-for-byte. New behavior arrives only via new functions (e.g. `bulk_trigger/2`) or optional opts (e.g. `:bulk_envelope_id`). Negative-grep gate enforces no public-signature churn.
2. **Snapshot-at-decision.** Trust facts (template body, cohort recipient list, governance risk tier, approval-surface prose) snapshot at the point of operator decision and never re-read at render time. Shared across `BulkEnvelope`, `ToolProposal` snapshotted columns, and any future decision-surface schema. Interpretive display prose is a separate category (best-effort live behind total fallback).
3. **Fail-closed envelope-boundary cap.** Hard caps (e.g. `Cairnloop.Outbound.max_batch_size = 25`, `@bulk_envelope_hard_cap 500` on the audit READ facade) enforced at the envelope function boundary, never at any single caller (LiveView, MCP, console, future tools). Defense-in-depth.
4. **Three-layer at-most-once for any new durable write action.** Oban `unique:` keys + terminal guard on the worker + SHA-256 per-attempt run key. Proven in `ToolExecutionWorker` (vM011) and `OutboundWorker` (vM013). Standard pattern — do not re-debate.
5. **Governance-facade reads from the web layer.** Web LiveViews and channels never run direct `Cairnloop.Repo` queries against domain tables; all reads route through narrow `Cairnloop.Governance.<purpose>_<read>/1` functions (e.g. `list_eligible_conversation_ids_for_bulk_recovery/1`, `preview_bulk_recovery_cohort/1`, `list_recent_bulk_outbound_envelopes/1`). D-14 negative-grep gate pins it.

## Requirements

### Validated
- ✓ Multi-Channel Ingress Engine — vM001
- ✓ AI Triage, Drafting, & Governance — vM002
- ✓ Deep Context Enrichment — vM003
- ✓ Customer Voice Activation — vM004
- ✓ Durable Auditing & SRE Observability — vM005
- ✓ Omnichannel SLA Escalation — vM006
- ✓ Semantic Search UI Foundations — vM007
- ✓ Knowledge Base Engine — vM008
- ✓ Retrieval-First Support Answers & Search Ops — vM009
- ✓ KB AI Maintenance — vM010
- ✓ Governed tool contract with risk tiers, approval modes, idempotency, and fail-closed proposal pipeline — vM011 (TOOL-01 through TOOL-04)
- ✓ Durable in-thread operator action timeline with humanized preview cards and snapshotted trust facts — vM011 (FLOW-01, FLOW-02)
- ✓ Approval state machine (approve/reject/defer/expiry/resume) with append-only decision history and Oban re-validate-before-execute resume — vM011 (FLOW-03, APRV-01 through APRV-04)
- ✓ First narrow approved write path with three-layer at-most-once idempotency and bounded telemetry — vM011 (ACT-01, OBS-01, OBS-02)
- ✓ Optional read-only MCP seam over governed-tool contract — vM011 (MCP-01)
- ✓ CI passes on main; CHANGELOG covers v0.1.0; semver tag pushed; package + docs live on Hex.pm — vM012 (REL-01 through REL-06)
- ✓ Example Phoenix host app boots end-to-end via `mix setup` and documents the integration — vM012 (DEMO-01 through DEMO-04)
- ✓ MCP OAuth Bearer seam with SHA-256 hashed tokens and RFC 9728 metadata — vM012 (MCP-02, MCP-03)
- ✓ MCP write surface routed through `Governance.propose/3` with `proposal_id` + idempotency-key reuse — vM012 (ACT-02, ACT-03)
- ✓ `Cairnloop.Outbound` facade for programmatic support lifecycle triggers — vM013 (OUT-01)
- ✓ `system_outbound` message type with `template_id` metadata and immutable `Conversation` linkage — vM013 (OUT-02, OUT-05)
- ✓ Durable Oban scheduling + Chimeway routing for outbound delivery with persisted status transitions — vM013 (OUT-03, OUT-04)
- ✓ Distinct outbound timeline rendering with delivery status chips in `ConversationLive` — vM013 (UI-01, UI-02)
- ✓ Bulk selection + bulk fan-out trigger workflow with cohort preview, batch cap, and at-most-once Oban semantics — vM013 (BULK-01, BULK-02, BULK-03, UI-03)
- ✓ OpenInference-conformant outbound telemetry + bulk audit READ facade with auditor metadata shape regression — vM013 (OBS-01, OBS-02)
- ✓ Realistic seeded fixtures spanning JTBD lifecycle — vM014 (FIX-01..FIX-04)
- ✓ Customer `/chat` wired to real `WidgetChannel` ingress — vM014 (CHAT-01..CHAT-03)
- ✓ D-10 brand-token CSS extraction and negative-grep gate — vM014 (BRAND-01..BRAND-04)
- ✓ Shared editorial nav shell and security closures — vM014 (KB-01..KB-04, SEC-01..SEC-02)
- ✓ Golden-path JTBD smoke test + WidgetChannel test in `mix test.integration` — vM014 (E2E-01..E2E-03)
- ✓ ExDoc `guides/` (quickstart, JTBD walkthrough, etc.) and README update — vM014 (DOC-01..DOC-04)
- ✓ Domain-layer security closure for KnowledgeAutomation (T-10-10/12/13) — vM015 (SEC-01..SEC-03)
- ✓ Operator Settings cockpit: MCP token CRUD, Notifier + retrieval health, dark mode — vM015 (SET-01..SET-04)
- ✓ Audit Log surface, `/health` + `/metrics` endpoints, governed-actions rail pagination — vM015 (AUDIT-01, OPS-01, OPS-02, TECH-01)
- ✓ MCP-client + extension guides, CONTRIBUTING.md, architecture doc, v0.2.x release — vM015 (DOC-01..DOC-04, REL-01, REL-02)
- ✓ Brand fidelity audit + canonical token-source designation + WCAG-AA contrast baseline — vM017 Phase 46 (FIDELITY-01..FIDELITY-03)
- ✓ Brand direction selection gate: local direction board, C3.6 crowning-loop cairn, Refined palette, current Atkinson/Fraunces/Martian type stack, and downstream handoff evidence — vM017 Phase 47 (LOGO-01..LOGO-03, TOKEN-01)
- ✓ Token evolution lock and propagation: Refined tokens applied to canonical `:root`, derivatives synchronized, contrast baseline re-verified, and full unit/integration/E2E gates green — vM017 Phase 48 (TOKEN-02..TOKEN-04)
- ✓ Chosen logo finalization: optimized SVG lockups, favicon/OG assets, usage rules, and rejected-direction cleanup — vM017 Phase 49 (LOGO-04..LOGO-06)
- ✓ Brandbook scaffold and token derivation: self-contained `brandbook/` scaffold and derived token artifacts — vM017 Phase 50 (BOOK-01..BOOK-02)
- ✓ Full HTML brand book assembly: live HTML logo/token/voice/motion guidance with local file verification — vM017 Phase 51 (BOOK-03..BOOK-05)
- ✓ Collateral wiring and QA sweep: README logo header, example-app logo/favicon/OG wiring, gated Playwright E2E, SVG/raster/package/diff evidence — vM017 Phase 52 (WIRE-01..WIRE-03, HYGIENE-01..HYGIENE-03)
- ✓ Operator UI primitive foundation and shared page shell: `cl_page`, `cl_hero`, numeric `cl_stat`, native disclosure, fact/source/status/switch primitives, table scrollers, and KB breadcrumbs — vM016 Phases 37-38 (UIC-01..05, SHELL-01..02)
- ✓ Queue-first Home and brand-token drift remediation: resolved-filter recovery, scoped counts, calmer secondary band, render-file token cleanup, and hardened brand-token gates — vM016 Phases 39-40 (HOME-01..05, DRIFT-01..02, GATE-01..02)
- ✓ Operator flow threading and responsive cockpit: safety-pinned rail disclosure, density controls, next-in-queue, audit/KB links, mobile-first breakpoints, tap-target proof, and bulk-bar geometry guard — vM016 Phases 41-43 (RAIL-01..03, THREAD-01..03, RESP-01..02)
- ✓ Restrained operator motion layer: CSS-only hero count entrance, evidence-rail reveal, status-chip cross-fade, inbox list stagger, reusable `cl_flash` toast, and reduced-motion E2E proof — vM016 Phase 44 (MOTION-01..MOTION-02)
- ✓ Final-brand seed, screenshots, visual acceptance, and release-gate verification: enriched demo state, light/dark screenshot matrix, 36-row visual ledger, root tests, integration, `mix check`, E2E, and screenshot capture — vM016 Phase 45 (SEED-01, VERIFY-01..02)
- ✓ Example app runtime hardened for Docker and manual local setup without weakening sealed Cairnloop contracts — vM018 Phase 53 (RUNT-01..RUNT-05)
- ✓ Demo wrapper experience: canonical `./bin/demo` operational surface with dynamic/private Compose contract, discovered URLs, status/log/reset/help commands, isolated smoke, automatic port fallback, bounded diagnostics, clean code review, and full Docker smoke verification — vM018 Phase 54 (BOOT-01..BOOT-04, VER-01..VER-02)
- ✓ Docker-first adopter docs: README, Quickstart, example README, and Troubleshooting align around `./bin/demo`, printed URLs, dynamic ports, reset/log/smoke flows, optional OpenAI first-run scope, and DB-free docs drift tests — vM018 Phase 55 (DOC-01..DOC-04)
- ✓ Demo smoke CI gate: dedicated read-only workflow runs `./bin/demo smoke` for demo-relevant push/PR/manual/scheduled changes, with DB-free workflow drift tests and full Docker smoke verification — vM018 Phase 56 (VER-03..VER-04)
- ✓ OSS trust baseline audit: 36-dimension software-quality evaluation, CI/CD topology/runtime audit, Postgres schema-prefix implementation contract, and local DB-free timing/compile/xref evidence — vM019 Phase 57 (AUDIT-01..03, CI-01)
- ✓ Identity, ingress, and side-effect trust: customer/operator separation, widget verifier seam, email/MCP fail-closed auth, inert optional Scrypath side effects, bounded logs/telemetry, liveness-only `/health`, and doctor trust diagnostics — vM019 Phase 58 (TRUST-01..05, OPS-01..04)
- ✓ Dedicated Postgres schema contract: new installs default to `schema_prefix: "cairnloop"` while explicit public compatibility, qualified migrations/runtime paths, safe vector rollback, Oban host ownership, integration proof, and example-app setup are preserved — vM019 Phase 59 (DB-01..DB-07)
- ✓ Installer/docs/upgrade/package/security trust: README, Quickstart, Host Integration, Troubleshooting, MCP, Extending, Auth/Operator Identity, SECURITY, UPGRADING, CHANGELOG, ExDoc/package metadata, and source-scan guardrails are current and green — vM019 Phase 60 (DOC-01..DOC-06)
- ✓ CI/CD efficiency and release confidence: current action/runtime posture, least-privilege workflows, path-gated expensive checks, bounded maintainer evidence, source-contract tests, and exact-SHA Hex release preflight — vM019 Phase 61 (CI-02..CI-06)


### Active

None currently. Define fresh active requirements with `/gsd-new-milestone`.

### Out of Scope
- Marketing/newsletter drip campaigns
- In-browser rich text template editing
- SMS or WhatsApp delivery as part of the outbound lane (host can add via Chimeway)
- Broad external MCP server surface open to untrusted third-party public clients
- High-risk financial or destructive mutations as the first governed-action path
- Autonomous customer-visible replies or side effects based only on retrieval confidence

## Key Decisions

| Decision | Milestone | Outcome |
|----------|-----------|---------|
| Workflow truth in Phoenix/Ecto/Oban; LiveView reflects state, never owns execution | vM011 | ✓ Good — consistently delivered across vM011, vM012, and vM013 |
| Sequence: contract → timeline → approvals → narrow write → optional MCP seam | vM011 | ✓ Good — late phases were additive without reopening earlier work |
| Hybrid preview: snapshot trust facts at propose time; interpretive prose best-effort live behind total fallback | vM011 | ✓ Good — D15-14 discharged cleanly in Phase 15 |
| Three-layer at-most-once execution: Oban unique + terminal guard + SHA-256 per-attempt run key | vM011 | ✓ Good — DB-backed proof added to integration harness; pattern reused for vM013 outbound delivery |
| DB-backed integration test harness added (docker-compose + pgvector + DataCase/ConnCase) | vM011 | ✓ Good — shifted 4 former Manual-Only items to automated proof in vM011; same harness proved Phase 25 in vM013 |
| MCP as read-only edge adapter, not internal execution model | vM011 | ✓ Good — additive, zero core truth changes |
| Automated initial Hex.pm publish via CI; tag-driven release on `v*` push | vM012 | ✓ Good — v0.1.0 published cleanly; pattern reusable for all future releases |
| MCP `tools/call` routes through `Governance.propose/3` with `origin: :mcp` | vM012 | ✓ Good — preserves vM011's three-layer at-most-once idempotency; integration tests pin behavior against real pgvector |
| Treat support outbound as `system_outbound` messages appended to the thread, not a separate CRM lane | vM013 | ✓ Good — preserves operator context continuity |
| Sealed `Outbound.trigger/2`; new `bulk_trigger/2` envelope for fan-out, not a redefined `trigger` | vM013 | ✓ Good — Phase 24 callers untouched; Phase 25 added strictly additively |
| `BulkEnvelope` records `:submitted` + `:refused_cap_exceeded` lanes on the same table | vM013 | ✓ Good — OBS-02 sees both lanes from one query; Phase 26 audit READ facade landed cleanly |
| Hard fail-closed at `max_batch_size = 25` enforced at the envelope boundary, not only in InboxLive | vM013 | ✓ Good — defense-in-depth; cap applies regardless of caller (LiveView, MCP, console, future tools) |
| Oban `unique:` keys `(conversation_id, template_id, bulk_envelope_id)` for at-most-once delivery — `nil` envelope id for single-conversation callers | vM013 | ✓ Good — Phase 24 + Phase 25 callers share the same dedup lane |
| Cohort eligibility reads from the web layer go through narrow `Cairnloop.Governance` facade; D-14 negative-grep gate pins this | vM013 | ✓ Good — no direct `Conversation \|> where(...)` queries in `InboxLive`; gate held through close |
| OpenInference traces emitted alongside (never replacing) sealed bounded-metrics spans; disjoint 4-segment namespace | vM013 | ✓ Good — mirrors vM011 Phase 17 pattern verbatim; zero churn to existing telemetry |
| Adopt canonical szTheory release-please pipeline; releases via `fix:`/`feat:` commit on `main` → bot PR → auto-tag + publish-hex | vM015 | ✓ Good — made the v0.2.0→0.2.1→0.2.2 remediation arc near-zero marginal cost |
| Run `/gsd-audit-milestone` against live source (not phase summaries) as the milestone gate | vM015 | ⚠️ Revisit — caught 3 broken features + a false CHANGELOG claim, but only *after* v0.2.0 shipped; move the gate before the release tag |
| Close KnowledgeAutomation security threats by pinning with regression tests rather than refactoring already-correct domain code | vM015 | ✓ Good — honored "seal completed phases"; zero churn to sealed paths |
| Gate hex releases on a green DB-backed integration suite in `release_gate` (after greening it) | vM015 | ✓ Good — turned a chronically-red suite into a release gate |
| Treat host-app compatibility/adoption trust as the weakest vM019 quality dimension | vM019 | ✓ Good — kept the milestone focused on production library behavior instead of new product surface |
| Default new Cairnloop support-domain tables to the dedicated `cairnloop` Postgres schema; keep `public` explicit compatibility | vM019 | ✓ Good — DB-backed dedicated and public proofs passed, and docs/installer now match the contract |
| Do not rely on `mix ecto.migrate --prefix` for Cairnloop migrations | vM019 | ✓ Good — migrations/runtime helpers qualify Cairnloop-owned objects without redirecting host schema_migrations or Oban |
| Keep optional Scrypath/external side effects inert unless explicitly enabled and ready | vM019 | ✓ Good — disabled/misconfigured paths do not enqueue or issue HTTP, and doctor/docs report posture |
| Treat docs, installer output, package metadata, SECURITY, UPGRADING, and ExDoc as quality-gated surfaces | vM019 | ✓ Good — DB-free source scans and `mix ci.quality` pin public truth |
| Make CI changes evidence-backed before removing expensive checks or caches | vM019 | ✓ Good — workflows now emit timing/cache/failure evidence; live hosted-runner observations remain explicit next-run checks |

## Context

**Codebase at current close:** Elixir / Phoenix / LiveView / Ecto / Oban / OpenInference telemetry / pgvector. Published as `cairnloop` v0.5.1 on Hex.pm. Releases flow through the release-please pipeline; vM018 adds Docker-first demo smoke proof on top of the existing headless, integration, quality, and example E2E lanes.

**Tech stack:** Elixir, Phoenix LiveView, Ecto (PostgreSQL + pgvector), Oban, Chimeway, OpenInference telemetry, ExDoc, Hex.pm, release-please.

**Integration test harness:** `MIX_ENV=test mix test.integration` against dockerized Postgres; fast headless `mix test` remains DB-free. As of vM015 the integration suite is green and gated in `release_gate`.

**Known tech debt:**
- Centralize duplicated fail-closed search guards (pre-existing from vM009).
- **Process:** keep the milestone audit gate before release/tag closeout. vM016 corrected this by running the audit and stale-artifact cleanup before archive/tag.

**Closed since prior milestone:** vM019 OSS trust baseline: evidence-backed quality audit, host identity/ingress/side-effect safety, dedicated-schema default with explicit public compatibility, truthful public adoption/docs/upgrade surface, and CI/release confidence guardrails.

**Current milestone focus:** none. Next milestone requirements should be defined from current adopter
signals before any new phase work starts.

## Previous Milestone Briefs

<details>
<summary>Archived vM015 brief</summary>

### vM015 Operator Polish + Maintenance Gates

**Goal:** Close the operator-facing rough edges and remaining vM010 security debt to bring the
library to "done enough for stated scope" — a real operator settings + audit surface, production
`/health` + `/metrics` endpoints, final domain-layer security closure, expanded guides, and the
v0.2.0 package release.

**Shipped 2026-05-30 — all 17 v1 requirements satisfied across Phases 33–36.** Released as
`cairnloop` v0.2.0 → v0.2.1 → v0.2.2 on Hex.pm. A same-day milestone audit caught three broken
Phase-35 features (AUDIT-01 no-op stub; OPS-01/02 unrouted plugs) and a missing `[0.2.0]`
CHANGELOG (REL-01); all four remediated in v0.2.1, integration-suite green + governance fix in
v0.2.2. Repo migrated to the release-please pipeline. See `milestones/vM015-ROADMAP.md` and
`milestones/vM015-MILESTONE-AUDIT.md`.

</details>

<details>
<summary>Archived vM014 brief</summary>

### vM014 Adoption Proof

**Goal:** A reasonable adopter clones cairnloop, runs `mix setup` in the example app, opens two browser tabs, walks the full Jobs-To-Be-Done lifecycle live, and the same path is locked into CI — closing the 15% adopter-surface gap that remains after vM013, with zero churn to sealed primitives.

**Target features (6 phases, 27–32; additive-only):**
- **FIX — Realistic demo fixtures.** 12–16 conversations spanning all JTBD states; 5+ KB articles with multiple revisions (one deprecated); 3+ GapCandidates with evidence; 1 ArticleSuggestion `:ready_for_review`. Embeddings drive through the live `ChunkRevision` Oban worker (self-test of M008 substrate).
- **CHAT — Customer `/chat` wired to real ingress.** Mount `Cairnloop.Channels.WidgetSocket` in the example endpoint; Phoenix Channel JS hook; rewrite `chat_live.ex` to push through `WidgetChannel` and receive operator replies via PubSub; two-tab demo doc snippet.
- **BRAND — D-10 brand-token CSS extraction.** Copy `prompts/cairnloop.css` `:root` block into example app + extend `@theme`. Drop the inline hex fallback (`var(--cl-token, #hex)` → `var(--cl-token)`). Re-pin 5 headless-token assertions to hex-free form. Add negative-grep gate.
- **KB + SEC — Editorial polish + T-10-09/T-10-11 closure.** Shared editorial nav shell across 4 KB routes; "Create new article" affordance in Index; "View source gap" sidebar in Editor; calm copy on `SuggestionReview` "Open for manual edit". `EditorHandoff.verify!/2` requires `manual_edit_opened_at` timestamp marker; Editor preload of `proposed_markdown` requires that handoff marker.
- **E2E — Golden-path JTBD smoke test in CI.** `test/integration/golden_path_test.exs` using `Phoenix.LiveViewTest` covers seed customer message → operator inbox → ConversationLive + cmd+k search + citation chip → approve AI draft → tool proposal approve → ToolExecutionWorker `:success` → resolve → `Outbound.trigger/2` → multi-select bulk recovery → `BulkEnvelope` row + per-recipient OutboundWorker jobs. Plus `widget_channel_test.exs` via `Phoenix.ChannelTest`. NOT Wallaby. NOT PhoenixTest dep.
- **DOC — README + ExDoc guides + JTBD walkthrough.** README leads with `mix cairnloop.install`. Four guides under `guides/`: quickstart, JTBD walkthrough with PNG screenshots from the Phase-27-seeded example, host integration, troubleshooting. `mix.exs` package ships `guides/`. CHANGELOG vM014 entry.

**Carried decisions for this milestone (informational; full list in `.planning/STATE.md`):**
- Test harness: `Phoenix.LiveViewTest` + `Phoenix.ChannelTest` only — NOT Wallaby, NOT PhoenixTest dep.
- D-10 closure: drop the hex fallback (Option B) — NOT migrate to named CSS classes (Option A).
- Security split: T-10-09 + T-10-11 bundle with Phase 30 (same files); T-10-10 + T-10-12 + T-10-13 defer to vM015 (domain layer).

**Shipped 2026-05-29 — all 24 v1 requirements satisfied across Phases 27-32.1.**

</details>

<details>
<summary>Archived vM013 brief</summary>

### vM013 Support-Triggered Outbound Lifecycle

**Goal:** Enable support-led outbound follow-ups that stay attached to the conversation timeline,
route durably through Oban + Chimeway, and remain visible to operators as part of the shared
support truth.

**Target features:**
- Core outbound facade + persistence — `Cairnloop.Outbound`, `system_outbound` messages, immutable conversation linkage.
- Durable delivery engine — Oban-backed scheduling plus Chimeway routing and persisted status transitions.
- Individual outbound UI — distinct outbound timeline cards plus a resolved-only manual "Send Recovery Follow-up" action.
- Bulk fan-out workflow — multi-select inbox targeting with confirmation preview and batch-size safety rails.
- Observability + audit polish — outbound OI telemetry, bulk audit READ facade, and final UI polish.

**Shipped 2026-05-27 — all 13 v1 requirements satisfied across Phases 22-26.**

</details>

<details>
<summary>Archived vM012 brief</summary>

### vM012 Public Release & MCP Write Surface

**Goal:** Package Cairnloop for public consumption and open the first MCP write surface that
preserves the vM011 trust model.

**Shipped 2026-05-26 — all 14 v1 requirements satisfied across Phases 18–21.**

</details>

<details>
<summary>Archived vM011 brief</summary>

### vM011 AI Tool Governance & MCP Integration

**Goal:** Extend the M009-M010 trust model with a host-owned governed-action lane.

**Shipped 2026-05-25 — all 15 v1 requirements satisfied across Phases 13–17.**

</details>

<details>
<summary>Archived vM010 brief</summary>

### vM010 KB AI Maintenance

**Goal:** Turn retrieval misses, weak grounding, and repeated manual handling into a safe
Knowledge Base maintenance workflow.

**Shipped 2026-05-23.**

</details>

<details>
<summary>Archived vM009 brief</summary>

### vM009 Retrieval-First Support Answers & Search Ops

**Goal:** Turn the Knowledge Base substrate into visible operator and AI value through grounded
retrieval, trustworthy search, and measurable answer quality.

**Shipped 2026-05-21.**

</details>

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition**:
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

## Diminishing-Returns Posture

**Cairnloop hits "done enough for stated scope" at the close of vM015.** Stated scope = host-owned Phoenix-native customer-support automation library (deflect / draft / summarize / escalate / outbound recovery + KB substrate + governed actions + MCP seam + operator-grade health signal). After vM015 the library covers Help Scout's "AI quality is downstream of grounded retrieval" lesson, Plain's "API-first + embedded" lesson, Pylon's "runbook-shaped HITL" lesson, and Papercups' "embedded is the defensible wedge" lesson — no obvious sixth lesson remains without leaving stated scope.

**Post-done mode (future milestones)** is adoption + maintenance, not features. Watch for real adopter signals (open issues, hex.pm engaged downloads, MCP-client integrations). Cut v1.0.0 once at least one non-maintainer host runs cairnloop in production. The trap is shipping Epic 12/13/14 before they're asked for — wheel-spinning territory.

---
*Last updated: 2026-07-01 after vM019 OSS Trust Baseline close. Published release remains `cairnloop` v0.5.1 on Hex.pm. Product remains "done enough for stated scope"; future expansion stays adopter-pulled.*
