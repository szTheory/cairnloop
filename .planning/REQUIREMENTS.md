# Requirements: Cairnloop — Milestone vM014 Adoption Proof

**Defined:** 2026-05-27
**Core Value:** Deflect what can be safely deflected, draft and summarize what cannot, escalate risks cleanly, and expose support quality as an operator-grade health signal.

**Milestone goal:** A reasonable adopter clones cairnloop, runs `mix setup` in the example app, opens two browser tabs, walks the full Jobs-To-Be-Done lifecycle live, and the same path is locked into CI — closing the 15% adopter-surface gap that remains after vM013, with zero churn to sealed primitives.

**Sealed-contract scope guard:** All vM014 work is additive. `Cairnloop.Outbound.trigger/2`, `Cairnloop.Governance.propose/3`, MCP `tools/call`, three-layer at-most-once execution, `BulkEnvelope` envelope-boundary cap, and the approval state machine are byte-for-byte sealed. New behavior arrives only via new functions or optional opts.

**Canonical context for subagents:** `.planning/threads/vM014-adoption-proof-assessment.md` + `/Users/jon/.claude/plans/can-u-decide-this-greedy-balloon.md`.

## v1 Requirements

Requirements for the vM014 release. Each maps to exactly one roadmap phase.

### Realistic Demo Fixtures

- [x] **FIX-01**: `examples/cairnloop_example/priv/repo/seeds.exs` seeds 12–16 conversations spanning the full JTBD lifecycle (`:new`, `:open`, `:awaiting_customer`, `:resolved`) with realistic operator + customer messages and ContextProvider snippets — replaces the current 1-conversation lonely demo.
- [x] **FIX-02**: Seed at least 5 KB articles with multiple `KnowledgeBase.Revision` rows per article (including at least one `:deprecated` revision) and the live `ChunkRevision` Oban worker drives embeddings through pgvector — self-test of the M008 substrate, not a fixture shortcut.
- [x] **FIX-03**: Seed at least 3 `GapCandidate` rows with evidence linked to seeded conversations so the KB gap queue shows ranked, inspectable maintenance work on first boot.
- [x] **FIX-04**: Seed at least 1 `ArticleSuggestion` in `:ready_for_review` state with citation-backed `proposed_markdown` so `SuggestionReview` LiveView shows real work on first boot. (D-15 sealed-enum reconciliation: schema persists as `:ready`; satisfied empirically by `seeds_test.exs` test 3 — `:pending_review` ReviewTask companion present + suggestion row green.)

### Customer Chat Wired to Real Ingress

- [x] **CHAT-01**: `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex` mounts `Cairnloop.Channels.WidgetSocket` at its canonical socket path — the example endpoint is currently missing this mount entirely.
- [x] **CHAT-02**: `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` is rewritten from its current 51-LOC mock (`Process.send_after(self(), :bot_reply, 1000)`) to push customer messages through `WidgetChannel` and receive operator replies via PubSub — no mock bot reply path remains.
- [x] **CHAT-03**: A two-tab demo doc snippet (operator inbox + customer `/chat`) is added to the example app README showing the end-to-end customer→operator→customer round trip on the local dev server.

### Brand-Token CSS Extraction (D-10 Closure)

- [x] **BRAND-01**: The canonical `:root` brand tokens from `prompts/cairnloop.css` and `prompts/cairnloop.tokens.json` (~30 semantic + ~15 primitive tokens) are imported into `examples/cairnloop_example/assets/css/app.css` and the example app's Tailwind `@theme` block extends them — replaces the current 4-token + 6-raw-`--cl-*` placeholder.
- [x] **BRAND-02**: Inline `var(--cl-<token>, #<hex>)` fallback strings across `lib/cairnloop/web/inbox_live.ex` and `lib/cairnloop/web/conversation_live.ex` are dropped to bare `var(--cl-<token>)` form — Option B per the assessment thread; named-class migration (Option A) is explicitly out of scope.
- [x] **BRAND-03**: The 5 known `assert html =~ "var(--cl-primary, #A94F30)"` headless-token assertions in `test/cairnloop/web/inbox_live_test.exs`, `test/cairnloop/web/conversation_live_test.exs`, `test/integration/approval_footer_live_test.exs`, and `test/integration/tool_execution_outcome_live_test.exs` are re-pinned to the new hex-free form.
- [x] **BRAND-04**: A negative-grep gate enforces zero remaining hex-fallback strings: `grep -r 'var(--cl-[a-z-]*, #' lib/cairnloop/web/` returns nothing. Gate runs in the test lane so the contract holds across future edits.

### KB Editorial Polish

- [x] **KB-01**: A shared editorial nav shell renders consistently across all 4 KB routes (`KnowledgeBase.Index`, `KnowledgeBase.Editor`, `SuggestionReview`, KB gap surface) so operators don't context-switch between unrelated layouts mid-task.
- [x] **KB-02**: `KnowledgeBase.Index` shows an explicit "Create new article" affordance (button + route) — currently missing; operators cannot create from the Index.
- [x] **KB-03**: `KnowledgeBase.Editor` shows a "View source gap" sidebar when the article being edited was opened from a `GapCandidate` handoff, surfacing the originating evidence in-context.
- [x] **KB-04**: `SuggestionReview` "Open for manual edit" affordance uses calm, reason-forward copy (per `prompts/cairnloop_brand_book.md`) and never leaks raw Elixir terms or raw JSON to the operator.

### Security Threat Closure (T-10-09 + T-10-11)

- [x] **SEC-01**: `Cairnloop.KnowledgeAutomation.EditorHandoff.verify!/2` requires a `manual_edit_opened_at` timestamp marker on the handoff record before allowing Editor preload of `proposed_markdown` — closes T-10-09 (auditable handoff marker; simpler than HMAC).
- [x] **SEC-02**: `KnowledgeBase.Editor` preload of `proposed_markdown` requires the SEC-01 handoff marker, not a bare URL `suggestion_id` parameter — closes T-10-11 (no unauthenticated proposed-content disclosure).

### Golden-Path JTBD Smoke Test

- [x] **E2E-01**: `test/integration/golden_path_test.exs` (using `Phoenix.LiveViewTest`) covers the full JTBD round trip: seed customer message → operator inbox sees → ConversationLive + cmd+k search + citation chip → approve AI draft → tool proposal approve → `ToolExecutionWorker` `:success` → resolve → `Outbound.trigger/2` from sidebar → multi-select bulk recovery → `BulkEnvelope` row created + per-recipient `OutboundWorker` jobs enqueued.
- [x] **E2E-02**: `test/integration/widget_channel_test.exs` (using `Phoenix.ChannelTest`) covers the customer-ingress side: customer message join → push through `WidgetChannel` → PubSub broadcast → operator-side delivery — proves the CHAT-01/CHAT-02 wiring end-to-end.
- [x] **E2E-03**: Both new tests are registered in the `mix test.integration` lane (dockerized Postgres + pgvector) and run green in CI. No Wallaby. No PhoenixTest dep. No browser-driver flake.

### README + ExDoc Guides + JTBD Walkthrough

- [x] **DOC-01**: Root `README.md` leads with `mix cairnloop.install` (the shipped Igniter task at `lib/mix/tasks/cairnloop/install.ex`), not the current `{:cairnloop, "~> 0.1.0"}` snippet — the install path adopters should actually use is now the first one they see.
- [x] **DOC-02**: ExDoc `guides/` directory ships with four guides — `01-quickstart.md`, `02-jtbd-walkthrough.md` (with PNG screenshots captured from the Phase-27-seeded example), `03-host-integration.md` (`ContextProvider`, `Notifier`, `AutomationPolicy`, `SLAPolicyProvider`), `04-troubleshooting.md`.
- [x] **DOC-03**: `mix.exs` package config ships the `guides/` directory and ExDoc surfaces them in the docs navigation — `mix docs` renders the guides alongside the API reference.
- [ ] **DOC-04**: `CHANGELOG.md` carries a vM014 entry summarizing the adopter-surface improvements (realistic demo, JTBD smoke test, brand-token extraction, KB editorial polish, T-10-09/T-10-11 closure, guides).

## Future Requirements

Tracked for vM015 (Operator Polish + Maintenance Gates) and beyond. Not in this milestone's roadmap.

### Operator Polish (vM015)

- **SET-01**: Real `SettingsLive` covering MCP tokens, Notifier health, retrieval health, dark-mode toggle (currently 118-LOC SLA-policy CRUD only).
- **AUDIT-01**: Audit-log viewer LiveView over `Cairnloop.Auditor` events with filter/search.
- **OPS-01**: `/health` + `/metrics` HTTP endpoints for adopter ops integration.
- **AR-14-02**: Governed-actions rail pagination — defer until outbound + action volume warrants.

### Security Threat Closure — Domain Layer (vM015)

- **SEC-FUT-01**: T-10-10 closure in `knowledge_automation.ex` (domain layer).
- **SEC-FUT-02**: T-10-12 closure in `knowledge_automation.ex` (domain layer).
- **SEC-FUT-03**: T-10-13 closure in `knowledge_automation.ex` (domain layer).

### Documentation Expansion (vM015)

- **DOC-FUT-01**: ExDoc `05-mcp-clients.md` guide.
- **DOC-FUT-02**: ExDoc `06-extending.md` guide.
- **DOC-FUT-03**: Root `CONTRIBUTING.md`.
- **DOC-FUT-04**: `docs/architecture.md` for adopters needing deeper internals.

### v0.2.0 Release (vM015)

- **REL-FUT-01**: Tag-driven v0.2.0 release on `v*` push covering vM014 + vM015 surface area.

### Strategic Optionality (vM016+ — opt-in only when adopter pulls)

- **EPIC-13**: Privacy-First Local AI via Nx/Bumblebee — pluggable `Cairnloop.Intent` adapter (Req-based remote default, optional `Nx.Serving` local). Highest leverage of the three; build only if an adopter asks.
- **EPIC-12**: Advanced Routing & Team Collaboration — multi-operator skill routing, team queues, internal handoff. Medium leverage; Papercups taught "team routing didn't save us" — don't build speculatively.
- **EPIC-14**: Mobile SDK Surface — iOS/Android embedded widget. Lowest leverage; defer indefinitely.

## Out of Scope

Explicitly excluded from vM014. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Wallaby / Selenium browser-driven smoke tests | Chrome-in-CI flake is real; `Phoenix.LiveViewTest` + `Phoenix.ChannelTest` already drive the same paths against real Postgres + pgvector via the existing 9-test integration harness. |
| PhoenixTest as a new test dependency | Existing `Phoenix.LiveViewTest` proven across 9 integration tests is sufficient; new test dep adds maintenance burden without coverage gain. |
| Migrating brand-token inline styles to named CSS classes (Option A) | Bigger diff, churns sealed render code in `inbox_live.ex` / `conversation_live.ex`. Option B (drop the hex fallback) is the smaller, additive path. |
| T-10-10 / T-10-12 / T-10-13 closure in `knowledge_automation.ex` | Domain-layer threats living in a different file than the Phase 30 KB editorial polish bundle (T-10-09/T-10-11). Bundling forces a 7th phase. Defer to vM015. |
| Epic 12 Advanced Routing & Team Collaboration | Domain research + brand book both reject this as the next wedge; adoption proof comes first, routing only-if-pulled. vM016+ optionality. |
| New opts on sealed `Outbound.trigger/2` or `Governance.propose/3` | Sealed-contract + additive-opts invariant. New behavior arrives via new functions or new opt-in opts, never by signing existing sealed primitives. |
| Real `SettingsLive` overhaul (MCP tokens / Notifier health / retrieval health / dark mode) | Operator polish belongs in vM015 — outside the "adoption proof" framing of vM014. |
| `/health` + `/metrics` HTTP endpoints | Ops integration polish; vM015 maintenance gates. |
| AR-14-02 governed-actions rail pagination | Acceptable at current volume; revisit in vM015 once outbound + action volume grows. |
| Autonomous customer-visible replies based on retrieval confidence | Project-level out-of-scope — preserved from prior milestones. Approval-gated only. |
| Broad external MCP server surface open to untrusted public clients | Project-level out-of-scope — preserved from prior milestones. |

## Traceability

Which phases cover which requirements.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FIX-01 | Phase 27 | Complete |
| FIX-02 | Phase 27 | Complete |
| FIX-03 | Phase 27 | Complete |
| FIX-04 | Phase 27 | Complete |
| CHAT-01 | Phase 28 | Complete |
| CHAT-02 | Phase 28 | Complete |
| CHAT-03 | Phase 28 | Complete |
| BRAND-01 | Phase 29 | Complete |
| BRAND-02 | Phase 29 | Complete |
| BRAND-03 | Phase 29 | Complete |
| BRAND-04 | Phase 29 | Complete |
| KB-01 | Phase 30 | Complete |
| KB-02 | Phase 30 | Complete |
| KB-03 | Phase 30 | Complete |
| KB-04 | Phase 30 | Complete |
| SEC-01 | Phase 30 | Complete |
| SEC-02 | Phase 30 | Complete |
| E2E-01 | Phase 31 | ✅ Closed 2026-05-28 |
| E2E-02 | Phase 31 | ✅ Closed 2026-05-28 |
| E2E-03 | Phase 31 | ✅ Closed 2026-05-28 |
| DOC-01 | Phase 32 | Complete |
| DOC-02 | Phase 32 | Complete |
| DOC-03 | Phase 32 | Complete |
| DOC-04 | Phase 32.1 | Complete |

**Coverage:**

- v1 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-27 (milestone vM014 kickoff)*
*Last updated: 2026-05-29 — DOC-04 marked Complete (Phase 32.1 cleanup pass)*
ete per Phase 28–30 VERIFICATION.md evidence (vM014 milestone audit)*
