# Roadmap: Cairnloop

## Milestones

- ✅ **vM009 Retrieval-First Support Answers & Search Ops** — Phases 1–8 (shipped 2026-05-21)
- ✅ **vM010 KB AI Maintenance** — Phases 9–12 (shipped 2026-05-23)
- ✅ **vM011 AI Tool Governance & MCP Integration** — Phases 13–17 (shipped 2026-05-25)
- ✅ **vM012 Public Release & MCP Write Surface** — Phases 18–21 (shipped 2026-05-26)
- ✅ **vM013 Support-Triggered Outbound Lifecycle** — Phases 22–26 (shipped 2026-05-27)
- 🚧 **vM014 Adoption Proof** — Phases 27–32 (active, kicked off 2026-05-27)

## Current Milestone: vM014 Adoption Proof

**Goal:** A reasonable adopter clones cairnloop, runs `mix setup` in the example app, opens two browser tabs, walks the full Jobs-To-Be-Done lifecycle live, and the same path is locked into CI — closing the 15% adopter-surface gap that remains after vM013, with zero churn to sealed primitives.

**Scope guard:** All work additive. `Cairnloop.Outbound.trigger/2`, `Cairnloop.Governance.propose/3`, MCP `tools/call`, three-layer at-most-once execution, `BulkEnvelope` envelope-boundary cap (`max_batch_size = 25`), and the approval state machine are byte-for-byte sealed. New behavior arrives only via new functions or optional opts.

**Canonical context:** `.planning/threads/vM014-adoption-proof-assessment.md` + `/Users/jon/.claude/plans/can-u-decide-this-greedy-balloon.md`.

### Phases

- [x] **Phase 27: Realistic Demo Fixtures** — Replace the lonely 1-conversation seed with a JTBD-spanning fixture set that exercises the M008 substrate end-to-end. (completed 2026-05-27)
- [x] **Phase 28: Customer `/chat` Wired to Real Ingress** — Replace the 51-LOC mock chat with a real `WidgetChannel` round trip so the two-tab demo proves the customer→operator path. (completed 2026-05-27)
- [x] **Phase 29: Brand-Token CSS Extraction (D-10 Closure)** — Land the canonical brand tokens in the example app, drop the inline hex fallbacks, and re-pin the headless-token test contract behind a negative-grep gate. (completed 2026-05-28)
- [ ] **Phase 30: KB Editorial Polish + T-10-09 / T-10-11 Closure** — Tighten the KB editorial nav, add the missing affordances, calm the `SuggestionReview` copy, and close the two `editor.ex` / `suggestion_review.ex`-shaped SECURITY threats with an auditable handoff marker.
- [ ] **Phase 31: Golden-Path JTBD Smoke Test** — Lock the full JTBD round trip and the new customer-ingress wiring into the `mix test.integration` lane (no Wallaby, no PhoenixTest dep).
- [ ] **Phase 32: README + ExDoc Guides + JTBD Walkthrough** — Make the front door match the shipped install path; ship four ExDoc guides + CHANGELOG entry so adopters can self-serve.

### Why this order

The phases form an additive dependency chain dictated by the adopter-experience need, not arbitrary technical layering:

1. **Phase 27 (fixtures) lands first** because every later phase consumes its data: the `/chat` two-tab demo (28) needs realistic conversations, the brand-token re-pin (29) needs rendered pages to verify against, the KB editorial polish (30) needs articles/revisions/gaps/suggestions to render through, the golden-path smoke (31) seeds from the same lifecycle the fixtures define, and the JTBD walkthrough PNG screenshots (32) come from the Phase-27-seeded example.
2. **Phase 28 (chat ingress)** lands second because the golden-path smoke (31) and the JTBD walkthrough (32) both depend on the customer-ingress path actually working — the existing mock would let the smoke test pass against a fiction.
3. **Phase 29 (brand tokens)** lands before the editorial polish (30) so the new KB nav shell renders against the canonical `:root` block instead of inheriting the 4-token placeholder; re-pinning the 5 headless-token assertions also stabilizes the test contract before Phase 30 touches the same files.
4. **Phase 30 (KB polish + SEC)** bundles the two `editor.ex` / `suggestion_review.ex`-shaped threats because they touch the same files as the editorial polish work — splitting would force a 7th phase. The domain-layer threats (T-10-10/T-10-12/T-10-13) graduate to vM015.
5. **Phase 31 (smoke test)** lands second-to-last because it locks the substrate of all prior phases into CI; running it before Phase 30 would either over-spec or under-spec the editorial paths.
6. **Phase 32 (docs)** lands last because it captures screenshots from the now-real seeded example, references the now-locked golden path, and announces the now-shipped surface in CHANGELOG.

### Phase Details

#### Phase 27: Realistic Demo Fixtures

**Goal:** An adopter who runs `mix setup` in the example app lands in a populated dashboard that already exercises every Jobs-To-Be-Done state — the example self-tests the M008 retrieval substrate on first boot rather than greeting them with one lonely conversation.
**Depends on:** Nothing (foundation phase for vM014).
**Requirements:** FIX-01, FIX-02, FIX-03, FIX-04.
**Success Criteria** (what must be TRUE):

  1. Operator opens example app after `mix setup` and the inbox shows 12–16 conversations spanning `:new`, `:open`, `:awaiting_customer`, and `:resolved` with realistic operator + customer messages and ContextProvider snippets — not the previous 1-conversation lonely demo.
  2. KB Index shows at least 5 articles, and each article has multiple `KnowledgeBase.Revision` rows including at least one `:deprecated` revision; embeddings flow through the live `ChunkRevision` Oban worker into pgvector (self-test of the M008 substrate, not a fixture shortcut).
  3. KB gap queue shows at least 3 `GapCandidate` rows on first boot, each with evidence linked to seeded conversations and inspectable in the ranked maintenance queue.
  4. `SuggestionReview` LiveView shows at least 1 `ArticleSuggestion` in `:ready_for_review` state with citation-backed `proposed_markdown` — real review work available immediately, no manual setup.

**Plans:** 8/8 plans complete

  - [x] 27-01-PLAN.md — Skeleton seeds.exs rewrite: builder shells + idempotency helper + Oban drain wiring + sealed-enum reconciliation table in header.
  - [x] 27-02-PLAN.md — `CairnloopExample.DemoContextProvider` module + headless test + config.exs wire (FIX-01 ContextProvider snippets; runs parallel to 27-01 in Wave 1).
  - [x] 27-03-PLAN.md — `build_articles/0`: 5 articles via KnowledgeBase facade + article-5 multi-revision progression v1→archived→v2 (FIX-02 articles).
  - [x] 27-04-PLAN.md — `build_conversations/1`: 16 conversations × 4 JTBD-derived cohorts with 3–6 messages each, brand-voice bodies (FIX-01 conversations).
  - [x] 27-05-PLAN.md — `build_gaps/1`: 3 GapCandidates + RetrievalGapEvents + memberships, all operator-scoped (FIX-03).
  - [x] 27-06-PLAN.md — `build_suggestion/2`: 1 ArticleSuggestion :ready + 2 evidence rows + companion ReviewTask via `ensure_review_task_for_suggestion/2` (FIX-04).
  - [x] 27-07-PLAN.md — Final wiring of `SeedRun.run/0` orchestrator + adopter-facing IO summary (FIX-02 substrate self-test driven by drain).
  - [x] 27-08-PLAN.md — Integration test `seeds_test.exs` pinning FIX-01..FIX-04 row counts + Oban drain non-empty chunks + idempotency (tagged `:requires_postgres`).

**UI hint:** yes

#### Phase 28: Customer `/chat` Wired to Real Ingress

**Goal:** The two-tab demo (operator inbox + customer `/chat`) proves a real customer→operator→customer round trip through the host-owned channel layer, replacing the mock `Process.send_after` bot reply with the same `WidgetChannel` path adopters will use.
**Depends on:** Phase 27 (needs realistic conversations + operators for the round trip to be meaningful).
**Requirements:** CHAT-01, CHAT-02, CHAT-03.
**Success Criteria** (what must be TRUE):

  1. `examples/cairnloop_example/lib/cairnloop_example_web/endpoint.ex` mounts `Cairnloop.Channels.WidgetSocket` at its canonical socket path; the example endpoint is no longer missing the socket mount.
  2. Customer types a message in `/chat`, it pushes through `WidgetChannel`, lands in an operator-side inbox conversation, and operator's reply broadcasts back into the customer's `/chat` LiveView via PubSub — no mock `Process.send_after(self(), :bot_reply, 1000)` path remains anywhere in `chat_live.ex`.
  3. Example app README documents the two-tab demo (operator inbox + customer `/chat`) with the exact local-dev commands an adopter needs to reproduce the round trip.

**Plans:** 3/3 plans complete

  - [x] 28-01-PLAN.md — Chat-facade foundation: add `create_customer_conversation/1` + `ingest_widget_message/2`, additive `reply_to_conversation/4` post-commit broadcast (OQ-1), `ConversationLive` + `InboxLive` PubSub handle_info clauses, and `Cairnloop.PubSub` started in the example app supervisor (Pitfall 1).
  - [x] 28-02-PLAN.md — Channel + worker rewire: `WidgetChannel.join("widget:lobby", ...)` creates the conversation via the new facade, `handle_in("new_message", ...)` reads conversation_id from `socket.assigns` (T-M001 input-trust mitigation), `ProcessMessage` rewritten with unique-option header + multi-clause `perform/1` preserving the EmailWebhookPlug stub (Pitfall 2 / OQ-2).
  - [x] 28-03-PLAN.md — Endpoint mount + ChatLive rewrite + README: `/widget` socket mount on the example endpoint, full `chat_live.ex` rewrite with colocated `WidgetChat` JS hook + UI-SPEC compliance + role-dedup handle_info (Pitfall 7), additive `Cairnloop.Chat.get_message/1` read facade, README §Two-Tab Demo block verbatim from UI-SPEC §3.

**UI hint:** yes

#### Phase 29: Brand-Token CSS Extraction (D-10 Closure)

**Goal:** The canonical brand tokens become the single source of truth for the example app and library render surfaces; inline hex fallbacks disappear; a gate prevents regression. D-10 (deferred at vM013 close) is closed via Option B (drop the fallback), not Option A (named CSS classes).
**Depends on:** Phase 28 (the brand application is most observable once realistic seeded UI is rendering with the new ingress path).
**Requirements:** BRAND-01, BRAND-02, BRAND-03, BRAND-04.
**Success Criteria** (what must be TRUE):

  1. `examples/cairnloop_example/assets/css/app.css` imports the canonical `:root` block from `prompts/cairnloop.css` (~30 semantic + ~15 primitive tokens) and the Tailwind `@theme` block extends them — replacing the previous 4-token + 6-raw-`--cl-*` placeholder.
  2. Operator views `InboxLive` and `ConversationLive` in the example app and sees brand-correct rendering driven entirely by `var(--cl-<token>)` references; no inline `var(--cl-<token>, #<hex>)` fallback strings remain in `lib/cairnloop/web/inbox_live.ex` or `lib/cairnloop/web/conversation_live.ex`.
  3. The 5 known `assert html =~ "var(--cl-primary, #A94F30)"` headless-token assertions across `test/cairnloop/web/inbox_live_test.exs`, `test/cairnloop/web/conversation_live_test.exs`, `test/integration/approval_footer_live_test.exs`, and `test/integration/tool_execution_outcome_live_test.exs` are re-pinned to the hex-free form and pass on `mix test`.
  4. A negative-grep gate runs in the test lane and fails the build if `grep -r 'var(--cl-[a-z-]*, #' lib/cairnloop/web/` returns anything — the contract holds across future edits.

**Plans:** 3/3 plans complete

  - [x] 29-01-PLAN.md — BRAND-01: land canonical `:root` + `@theme` + dark overrides + `--cl-on-primary` alias in `examples/cairnloop_example/assets/css/app.css` (verbatim from `prompts/cairnloop.css`; replaces the 4-token stub).
  - [x] 29-02-PLAN.md — BRAND-02 + BRAND-04: drop hex fallbacks across 4 sealed render files (`inbox_live.ex` + `conversation_live.ex` + `search_modal_component.ex` + example app `chat_live.ex`), rename `--cl-error` → `--cl-danger` in `chat_live.ex`, refresh `inbox_live.ex` moduledoc, land negative-grep gate test `test/cairnloop/web/brand_token_gate_test.exs`.
  - [x] 29-03-PLAN.md — BRAND-03: re-pin all 6 hex-fallback assertions across 3 integration test files (`approval_footer_live_test.exs` + `tool_execution_outcome_live_test.exs` + `bulk_recovery_live_test.exs`) to bare `var(--cl-<token>)` form with closing-paren strictness.

**UI hint:** yes

#### Phase 30: KB Editorial Polish + T-10-09 / T-10-11 Closure

**Goal:** The four KB routes feel like one coherent editorial surface, operators can create / inspect / review without context-switching between unrelated layouts, calm reason-forward copy holds across affordances, and two of the five outstanding vM010 SECURITY threats close via an auditable handoff marker — without churning the sealed render code structure.
**Depends on:** Phase 29 (the editorial nav shell + sidebar render against the canonical brand tokens rather than inheriting placeholder styles).
**Requirements:** KB-01, KB-02, KB-03, KB-04, SEC-01, SEC-02.
**Success Criteria** (what must be TRUE):

  1. Operator navigates between `KnowledgeBase.Index`, `KnowledgeBase.Editor`, `SuggestionReview`, and the KB gap surface and sees a single shared editorial nav shell — no mid-task context-switch between unrelated layouts.
  2. Operator on `KnowledgeBase.Index` can click an explicit "Create new article" button (with a real route) and reach the Editor for a fresh article; the affordance was missing previously.
  3. When `KnowledgeBase.Editor` is opened via a `GapCandidate` handoff, a "View source gap" sidebar surfaces the originating evidence in-context; "Open for manual edit" on `SuggestionReview` uses calm, reason-forward copy per `prompts/cairnloop_brand_book.md` and never leaks raw Elixir terms or raw JSON to the operator.
  4. `Cairnloop.KnowledgeAutomation.EditorHandoff.verify!/2` requires a `manual_edit_opened_at` timestamp marker on the handoff record; `KnowledgeBase.Editor` refuses to preload `proposed_markdown` from a bare URL `suggestion_id` parameter — only via the handoff marker (closes T-10-09 + T-10-11; T-10-10 / T-10-12 / T-10-13 remain deferred to vM015 per assessment thread).

**Plans:** TBD
**UI hint:** yes

#### Phase 31: Golden-Path JTBD Smoke Test

**Goal:** The full JTBD round trip is locked into CI against real Postgres + pgvector via the existing integration harness — adopters who run the suite get a green light on the same path the two-tab demo walks. No browser-driver flake; no new test dependency.
**Depends on:** Phase 30 (golden path traverses the editorial polish + the SEC-01/SEC-02 handoff marker added in Phase 30, plus the Phase 27 fixtures, the Phase 28 ingress wiring, and the Phase 29 brand-token contract).
**Requirements:** E2E-01, E2E-02, E2E-03.
**Success Criteria** (what must be TRUE):

  1. `test/integration/golden_path_test.exs` (using `Phoenix.LiveViewTest`) drives the full JTBD round trip — seed customer message → operator inbox sees → ConversationLive + cmd+k search + citation chip → approve AI draft → tool proposal approve → `ToolExecutionWorker` `:success` → resolve → `Outbound.trigger/2` from sidebar → multi-select bulk recovery → `BulkEnvelope` row created + per-recipient `OutboundWorker` jobs enqueued — and passes against real Postgres + pgvector.
  2. `test/integration/widget_channel_test.exs` (using `Phoenix.ChannelTest`) drives the customer-ingress side: customer message join → push through `WidgetChannel` → PubSub broadcast → operator-side delivery — proving the CHAT-01/CHAT-02 wiring end-to-end.
  3. Both new tests are registered in the `mix test.integration` lane (dockerized Postgres + pgvector) and run green in CI on every push — no Wallaby, no PhoenixTest dep, no browser-driver flake.

**Plans:** TBD

#### Phase 32: README + ExDoc Guides + JTBD Walkthrough

**Goal:** The library's front door matches the shipped install path, and adopters have four task-shaped guides plus screenshots of the now-real seeded example so they can self-serve from clone to first integration without reading source.
**Depends on:** Phase 31 (the JTBD walkthrough cites the locked-in golden path; screenshots come from the Phase-27-seeded example).
**Requirements:** DOC-01, DOC-02, DOC-03, DOC-04.
**Success Criteria** (what must be TRUE):

  1. Root `README.md` leads with `mix cairnloop.install` (the shipped Igniter task at `lib/mix/tasks/cairnloop/install.ex`), not the previous `{:cairnloop, "~> 0.1.0"}` snippet — the install path adopters should actually use is the first one they see.
  2. ExDoc `guides/` directory ships four guides: `01-quickstart.md`, `02-jtbd-walkthrough.md` (with PNG screenshots captured from the Phase-27-seeded example), `03-host-integration.md` (`ContextProvider`, `Notifier`, `AutomationPolicy`, `SLAPolicyProvider`), and `04-troubleshooting.md`.
  3. `mix.exs` package config ships the `guides/` directory and `mix docs` surfaces them in the docs navigation alongside the API reference — the guides are visible on Hex.pm after the next release, not local-only.
  4. `CHANGELOG.md` carries a vM014 entry summarizing the adopter-surface improvements (realistic demo, JTBD smoke test, brand-token extraction, KB editorial polish, T-10-09/T-10-11 closure, guides).

**Plans:** TBD
**UI hint:** yes

## Phases (Prior Milestones)

<details>
<summary>✅ vM013 Support-Triggered Outbound Lifecycle (Phases 22–26) — SHIPPED 2026-05-27</summary>

- [x] Phase 22: Outbound Foundation & Persistence (1/1 plan) — completed 2026-05-26
- [x] Phase 23: Delivery & Scheduling Engine (1/1 plan) — completed 2026-05-26
- [x] Phase 24: Individual Outbound UI (1/1 plan) — completed 2026-05-26
- [x] Phase 25: Bulk Selection & Fan-out (3/3 plans) — completed 2026-05-27
- [x] Phase 26: Observability & Polish (3/3 plans) — completed 2026-05-27

Archive: `.planning/milestones/vM013-ROADMAP.md`

</details>

<details>
<summary>✅ vM012 Public Release & MCP Write Surface (Phases 18–21) — SHIPPED 2026-05-26</summary>

- [x] Phase 18: Release Gate & Hex.pm Publish (3/3 plans) — completed 2026-05-25
- [x] Phase 19: Example Phoenix App (1/1 plan) — completed 2026-05-26
- [x] Phase 20: MCP OAuth Seam (2/2 plans) — completed 2026-05-26
- [x] Phase 21: MCP Write Tools (1/1 plan) — completed 2026-05-26

Archive: `.planning/milestones/vM012-ROADMAP.md`

</details>

<details>
<summary>✅ vM011 AI Tool Governance & MCP Integration (Phases 13–17) — SHIPPED 2026-05-25</summary>

- [x] Phase 13: Governed Tool Contract & Proposal Records (3/3 plans) — completed 2026-05-24
- [x] Phase 14: Operator Timeline & Preview Surface (4/4 plans) — completed 2026-05-24
- [x] Phase 15: Approval State Machine & Oban Resume (5/5 plans) — completed 2026-05-25
- [x] Phase 16: First Approved Write Path & Telemetry (3/3 plans) — completed 2026-05-25
- [x] Phase 17: Optional Evidence Lane & Read-Only MCP Seam (2/2 plans) — completed 2026-05-25

Archive: `.planning/milestones/vM011-ROADMAP.md`

</details>

<details>
<summary>✅ vM010 KB AI Maintenance (Phases 9–12) — SHIPPED 2026-05-23</summary>

- [x] Phase 9: Gap Candidate Discovery (3/3 plans) — completed 2026-05-22
- [x] Phase 10: Citation-Backed Draft Suggestions (4/4 plans) — completed 2026-05-22
- [x] Phase 11: Review-Gated KB Updates (4/4 plans) — completed 2026-05-23
- [x] Phase 12: In-Thread Quick Fix & Ops Closure (4/4 plans) — completed 2026-05-23

Archive: `.planning/milestones/vM010-ROADMAP.md`

</details>

<details>
<summary>✅ vM009 Retrieval-First Support Answers & Search Ops (Phases 1–8) — SHIPPED 2026-05-21</summary>

Archive: `.planning/milestones/vM009-ROADMAP.md`

</details>

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 27. Realistic Demo Fixtures | vM014 | 8/8 | Complete    | 2026-05-27 |
| 28. Customer `/chat` Wired to Real Ingress | vM014 | 3/3 | Complete    | 2026-05-27 |
| 29. Brand-Token CSS Extraction (D-10 Closure) | vM014 | 3/3 | Complete    | 2026-05-28 |
| 30. KB Editorial Polish + T-10-09 / T-10-11 Closure | vM014 | 0/0 | Not started | — |
| 31. Golden-Path JTBD Smoke Test | vM014 | 0/0 | Not started | — |
| 32. README + ExDoc Guides + JTBD Walkthrough | vM014 | 0/0 | Not started | — |
| 22. Outbound Foundation & Persistence | vM013 | 1/1 | Complete | 2026-05-26 |
| 23. Delivery & Scheduling Engine | vM013 | 1/1 | Complete | 2026-05-26 |
| 24. Individual Outbound UI | vM013 | 1/1 | Complete | 2026-05-26 |
| 25. Bulk Selection & Fan-out | vM013 | 3/3 | Complete | 2026-05-27 |
| 26. Observability & Polish | vM013 | 3/3 | Complete | 2026-05-27 |
| 18. Release Gate & Hex.pm Publish | vM012 | 3/3 | Complete | 2026-05-25 |
| 19. Example Phoenix App | vM012 | 1/1 | Complete | 2026-05-26 |
| 20. MCP OAuth Seam | vM012 | 2/2 | Complete | 2026-05-26 |
| 21. MCP Write Tools | vM012 | 1/1 | Complete | 2026-05-26 |
| 13. Governed Tool Contract & Proposal Records | vM011 | 3/3 | Complete | 2026-05-24 |
| 14. Operator Timeline & Preview Surface | vM011 | 4/4 | Complete | 2026-05-24 |
| 15. Approval State Machine & Oban Resume | vM011 | 5/5 | Complete | 2026-05-25 |
| 16. First Approved Write Path & Telemetry | vM011 | 3/3 | Complete | 2026-05-25 |
| 17. Optional Evidence Lane & Read-Only MCP Seam | vM011 | 2/2 | Complete | 2026-05-25 |

---

_For current project status, see `.planning/STATE.md`_
_vM014 roadmap formalized: 2026-05-27 from `.planning/threads/vM014-adoption-proof-assessment.md`_
_Phase 28 plans created: 2026-05-27 — 3 plans, 3 waves (sequential dependency chain: data facade → channel+worker rewire → endpoint+ChatLive+README)_
_Phase 29 plans created: 2026-05-27 — 3 plans, 3 waves (sequential dependency chain: land tokens in app.css → drop hex fallbacks + gate test → re-pin integration test assertions)_
