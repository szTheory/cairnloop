# Cairnloop Project

## What This Is
An embedded, Phoenix-native customer support automation layer that turns support conversations into answers, product signals, knowledge-base improvements, safe governed actions, and durable support-triggered outbound follow-up — all inside the host app.

## Core Value
Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.

## Current Milestone: vM017 Brand Identity System, Token Evolution & HTML Brand Book

**Goal:** Turn the text-only brand seed (`prompts/cairnloop_brand_book.md`) into a real, crafted identity: a distinctive **logo system** (hand-authored SVG, owner picks from 4 directions incl. an integrated typemark), an **evolved core palette/type**, and a self-contained, professional **HTML brand book** checked into git — then wire the chosen mark into the real shipped surfaces. The payoff is OSS credibility on GitHub / HexDocs / a future landing page plus an implementation-ready, drift-free brand system.

**Target features (phases 46–52; decisions D-A/D-B/D-C + logo constraints ratified in the approved plan `~/.claude/plans/brand-book-pressure-test-abundant-dragonfly.md`):**
- **Brand fidelity audit + token consolidation** — pressure-test the text brand book against the shipped system; collapse the 3+ palette copies into one canonical source (`priv/static/cairnloop.css` `:root`) so evolution propagates cleanly; WCAG-AA contrast baseline.
- **Brand direction exploration (SELECTION GATE)** — 4 hand-authored logo directions (incl. a fully-integrated custom typemark), plus palette + type variants, on a local HTML "direction boards" page. Owner picks logo + palette + type.
- **Token evolution: lock & propagate (D-A)** — apply chosen palette/type to the canonical source, propagate to example-app `app.css` + `tokens.json`, prefer value-changes/additions over renames, re-verify (brand-token gate, golden-path, contrast, E2E).
- **Chosen-logo finalization** — full SVG asset family (lockups, mono/inverse, icon, optional tagline lockup), favicon (separately-authored small-size reduction), OG/social card; clearspace + min-size spec.
- **Brandbook scaffold + token derivation** — self-contained `brandbook/` skeleton with `tokens.css` *derived* (not forked) from the canonical CSS.
- **Full HTML brand book assembly** — all sections as live HTML (swatches, specimens, logo system + do/don't, light/dark), opens from `file://`, stands on its own.
- **Collateral wiring + QA sweep (D-B)** — replace example-app logo, update favicon + `og:image`, add README SVG header; SVG-validity/contrast/diff-hygiene/repo-size QA; rendered-behavior → gated E2E.

**Locked decisions:** **D-A** core palette + type are reopened/evolved (seed, not gospel) and propagated once with full re-verification; **D-B** the chosen logo is wired into README + example app + favicon + OG; **D-C** 4 hand-authored logo directions, one a mandatory integrated typemark. **Logo constraints:** no rectangular background cage (transparent/boundary-breaking default); logomark + logotype visually unified and close (not "icon left of text"); primary lockup has no subtitle (separate optional tagline lockup allowed); hand-authored SVG, not clipart. **Repo hygiene:** `brandbook/` self-contained, SVG-first, raster only for favicon/OG (≤~150KB), git-tracked but **out of the hex package** (`mix.exs` `files` unchanged).

> **vM016 Operator UI/UX Iteration is PARKED (54%, not shipped)** to sequence this brand work first — its
> Phase 45 screenshot regen must run against the *final* vM017 brand. Archived at
> `.planning/milestones/vM016-phases/`; resume steps in `.planning/milestones/vM016-PARKED.md`. The product
> remains "done enough for stated scope"; Epics 12/13/14 stay out of scope. This is a brand/identity +
> docs-collateral milestone — no product feature scope.

## Current State

**Latest shipped milestone: `vM015 Operator Polish + Maintenance Gates` on 2026-05-30. Since then, three releases shipped outside formal GSD milestone numbering — `v0.4.0` (operator UI rebuilt on a shipped design system: `priv/static/cairnloop.css` + `Cairnloop.Web.Components` + Cockpit Home/nav), `v0.5.0` (`Cairnloop.Automation.DraftGenerator` seam + Anthropic adapter — the draft path is no longer a pure mock), and `v0.5.1` (operator-identity auth fix + installer fix). Current published version: `cairnloop` v0.5.1 on Hex.pm. Active milestone: `vM016 Operator UI/UX Iteration` (phases 37+).**

**What is now true (cumulative through vM015):**
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

**Current milestone:** `vM016 Operator UI/UX Iteration` (phases 37–45) — an owner-pulled iteration/polish pass on the already-shipped operator dashboard (see "## Current Milestone" above and `.planning/vM016-UI-ITERATION-BRIEF.md`). Cairnloop remains "done enough for stated scope" at the product level; vM016 deepens adoption quality (consistency, IA threading, drift-proofing), not product scope. Epic 12/13/14 strategic optionality stays opt-in only.
- **Phase 37 — Component Primitives** complete (2026-06-03): the component library now has all eight iteration primitives (`cl_page`, `cl_hero`, de-polymorphized `cl_stat`, `cl_disclosure`, `cl_fact_list`, `cl_source_card`, `cl_status_cell`, `cl_switch`) plus layout tokens, inert utilities, and accessible `.cl-table-scroll` wrappers on all four operator tables — purely additive to `components.ex` + `cairnloop.css`, warnings-clean, 42 headless tests. Adoption (page-shell migration) begins Phase 38.
- **Phase 38 — Shared Page-Shell Migration** complete (2026-06-04): all eight operator screens (Home, Inbox, Audit Log, Settings, and KB index/editor/gaps/suggestion-review) now render their bodies through `<.cl_page width="wide">` nested in `<.cl_shell>` — bespoke per-screen header/width hand-rolling is gone (SHELL-01). A new pure/total `Cairnloop.Web.BreadcrumbPresenter` (no Repo, total over nil/non-binary input, last crumb omits `:href`, raw paths never used as labels) is wired into the editor `:breadcrumb` slot (origin-aware: conversation vs suggestions) and suggestion_review (static lane crumb, previously absent), closing the KB-from-conversation deep path (SHELL-02). Render-layer only — warnings-clean, 133 render tests green; full suite carries only the two documented baseline failures. Verified 11/11 code must-haves; two visual/real-time checks tracked in `38-HUMAN-UAT.md` (screenshot-pipeline consistency is owned by Phase 45).

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


### Active

**vM017 Brand Identity System, Token Evolution & HTML Brand Book** (REQ-IDs in `.planning/REQUIREMENTS.md`,
phases 46–52): brand fidelity audit + token consolidation, brand-direction exploration (logo/palette/type
selection gate), token evolution + propagation, chosen-logo finalization, brandbook scaffold + token
derivation, full HTML brand book assembly, collateral wiring + QA sweep.

**vM016 Operator UI/UX Iteration — PARKED at 54%** (phases 37–45; reqs in
`.planning/milestones/vM016-REQUIREMENTS.md`). Phases 37–43 complete; **phase 44 (motion) planned & ready**,
**phase 45 (seed + screenshot regen + verify) unplanned**. Resume after vM017 ships — see
`.planning/milestones/vM016-PARKED.md`.

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

## Context

**Codebase at vM015 close:** ~43k LOC Elixir / Phoenix / LiveView / Ecto / Oban / OpenInference telemetry / pgvector. Published as `cairnloop` v0.2.2 on Hex.pm. Releases flow through the release-please pipeline; the headless `mix test` suite + the DB-backed `integration` suite both gate `release_gate` in CI (integration suite greened in vM015). Baseline: `Automation.DraftTest` M005-drift failure remains documented/known.

**Tech stack:** Elixir, Phoenix LiveView, Ecto (PostgreSQL + pgvector), Oban, Chimeway, OpenInference telemetry, ExDoc, Hex.pm, release-please.

**Integration test harness:** `MIX_ENV=test mix test.integration` against dockerized Postgres; fast headless `mix test` remains DB-free. As of vM015 the integration suite is green and gated in `release_gate`.

**Known tech debt:**
- **Verification debt (vM015):** phases 33/34/35 shipped without `VERIFICATION.md`; Nyquist `*-VALIDATION.md` exists only for phase 36. Code is green in CI through v0.2.2 but GSD verification artifacts were never produced. Backfill via `/gsd-verify-work` if required.
- Centralize duplicated fail-closed search guards (pre-existing from vM009).
- **Process:** the milestone audit gate ran *after* the v0.2.0 release tag, so 3 broken features + 1 false CHANGELOG claim shipped as post-release defects (remediated in v0.2.1). Move audit/verification before the release tag.

**Closed since prior milestone:** all five vM010 `SECURITY.md` threats (T-10-09/11 in vM014; T-10-10/12/13 in vM015); AR-14-02 governed-actions rail pagination (vM015 TECH-01); D-10 brand-token CSS extraction (vM014).

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

**Post-done mode (vM016+)** is adoption + maintenance, not features. Watch for real adopter signals (open issues, hex.pm engaged downloads, MCP-client integrations). Cut v1.0.0 once at least one non-maintainer host runs cairnloop in production. The trap is shipping Epic 12/13/14 before they're asked for — wheel-spinning territory.

---
*Last updated: 2026-06-23 — started milestone **vM017 Brand Identity System, Token Evolution & HTML Brand Book** (phases 46–52) from the approved plan. Logo system (4 hand-authored SVG directions + owner selection gate), reopened/evolved core palette+type (D-A), self-contained HTML brand book in `brandbook/`, and chosen-logo wiring into README + example app + favicon + OG (D-B). **vM016 Operator UI/UX Iteration parked at 54%** (phases 37–43 done, 44 ready, 45 unplanned) to sequence the brand work first — its screenshot regen must run against the final vM017 brand; archived under `.planning/milestones/vM016-phases/`, resume via `.planning/milestones/vM016-PARKED.md`. Published release: `cairnloop` v0.5.1 on Hex.pm. Product remains "done enough for stated scope"; Epics 12/13/14 stay opt-in.*
