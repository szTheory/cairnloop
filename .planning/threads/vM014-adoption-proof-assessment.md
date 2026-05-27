# Thread: vM014 Adoption-Proof Assessment

**Opened:** 2026-05-27 (post-vM013 close)
**Status:** Open — informs vM014 planning (`/gsd-new-milestone vM014`)
**Audience:** subagents starting Phase 27 (gsd-roadmapper, gsd-project-researcher, gsd-pattern-mapper, executors)

## TL;DR

- Cairnloop is **~85% done for stated scope.** Library substance is real (42.4k LOC, 74 test files, 9 Postgres+pgvector integration tests, all major surfaces shipped through vM013).
- Remaining 15% is **adopter-surface concentrated**, not feature-breadth. Specifically: lonely demo seed, brand book unapplied, no JTBD smoke test, README leads with the wrong install path, 5 vM010 SECURITY threats still open.
- **vM014 should be a single "Adoption Proof" milestone, NOT Epic 12 (routing/teams).** Strategic optionality (Epic 12/13/14) is genuinely optional — build only when an adopter pulls.
- **vM015 closes the polish + maintenance tail.** vM015 close = "done enough for stated scope"; diminishing-returns line.

## Verified-from-repo evidence (not doc-skim)

### What's strongly real

- `Cairnloop.Governance` facade (1,176 LOC) — compile-time risk-tier validation, full propose/approve/reject/defer/expire/list_events, three-layer at-most-once idempotency (Oban unique + terminal guard + SHA-256 per-attempt run key) in `ToolExecutionWorker`.
- `Cairnloop.Outbound` (453 LOC) + `BulkEnvelope` schema + `max_batch_size=25` cap + Oban `unique:` keys; OpenInference traces on disjoint `[:cairnloop, :outbound, :trace, …]` 4-segment namespace.
- KB schemas (Article/Revision/Chunk) + pgvector embeddings + `ResolvedCaseChunk` + `GapRecorder` + `GapCandidateBuilder` + `Retrieval.Ranker`; 6 KB-related migrations.
- MCP read+write seam: `tools/list` + `initialize` + `tools/call` → `Governance.propose/3` with Ecto-backed OAuth Bearer (SHA-256 hashed in `cairnloop_mcp_tokens`) + RFC 9728 well-known metadata.
- `KnowledgeBaseLive.Editor` is **shipped at 264 LOC** with full review-task handoff + `EditorHandoff` verifier + publish lane (the initial audit underestimated this — it is real, not a placeholder).
- `SuggestionReview` LiveView is wired and mounted in the example router (`/support/knowledge-base/suggestions`).
- 9 integration tests against dockerized Postgres+pgvector via `mix test.integration`; cover approval flow, tool execution outcomes, bulk recovery, JSONB roundtrip, partial unique index.
- `cmd+k` `SearchModalComponent` is shipped with `phx-key="k"` listener — undersold in README, not absent.

### What's thin or unfinished (adopter surface)

- `examples/cairnloop_example/priv/repo/seeds.exs` — **49 lines, ONE conversation, ONE article.** Lonely demo. Adopters land in a desert.
- `examples/cairnloop_example/lib/cairnloop_example_web/live/chat_live.ex` — **51 LOC of pure mock.** `Process.send_after(self(), :bot_reply, 1000)`. NOT wired to `Cairnloop.Channels.WidgetChannel`. The example's `endpoint.ex` doesn't even mount `WidgetSocket`.
- `examples/cairnloop_example/assets/css/app.css` — only **4** brand tokens via Tailwind `@theme` (basalt, trailpaper, warm-stone, primary) plus 6 raw `--cl-*` CSS vars. The canonical ~30 semantic + ~15 primitive tokens authored in `prompts/cairnloop.css` and `prompts/cairnloop.tokens.json` are **unused**. D-10 (brand-token CSS extraction) explicitly deferred at vM013 close.
- **5 known `assert html =~ "var(--cl-primary, #A94F30)"` headless-token assertions** across `test/cairnloop/web/inbox_live_test.exs`, `conversation_live_test.exs`, `test/integration/approval_footer_live_test.exs`, `test/integration/tool_execution_outcome_live_test.exs` — these are the headless-test contract for vM013 D-10 deferral. Phase 29 must re-pin them.
- **Zero browser-driven or LiveView-end-to-end golden-path tests.** Integration tests assert DB-state transitions, not operator clickthroughs across the full JTBD.
- `README.md` leads with `{:cairnloop, "~> 0.1.0"}` even though `mix cairnloop.install` Igniter task is shipped at `lib/mix/tasks/cairnloop/install.ex`.
- ExDoc has no `guides/` directory; `mix.exs` package config doesn't ship one.
- 5 open SECURITY threats T-10-09..T-10-13 from vM010. T-10-09/T-10-11 live in `editor.ex` + `suggestion_review.ex` (bundle with KB polish). T-10-10/T-10-12/T-10-13 live in `knowledge_automation.ex` domain layer (defer to vM015).
- AR-14-02 governed-actions rail pagination, real `SettingsLive` (currently 118-LOC SLA-policy CRUD only) — defer to vM015.

## vM014 Scoped Decision

**Goal:** A reasonable adopter clones, runs `mix setup` in the example, opens two browser tabs, walks the JTBD live, and the same path is locked into CI.

**Six phases (27–32), additive-only, zero churn to sealed primitives:**

1. **Phase 27 — Realistic Demo Fixtures (FIX-01..FIX-04).** 12–16 conversations spanning all JTBD states; 5+ KB articles with multiple revisions including one deprecated; 3+ GapCandidates with evidence; 1 ArticleSuggestion `:ready_for_review`. Drive embeddings through the live `ChunkRevision` Oban worker (self-test of M008 substrate).
2. **Phase 28 — Customer `/chat` Wired to Real Ingress (CHAT-01..CHAT-03).** Mount `Cairnloop.Channels.WidgetSocket` in example endpoint; Phoenix Channel JS hook in `app.js`; rewrite `chat_live.ex` to push through WidgetChannel + receive operator replies via PubSub; two-tab demo doc snippet.
3. **Phase 29 — Brand-Token CSS Extraction / D-10 closure (BRAND-01..BRAND-04).** Copy `prompts/cairnloop.css` `:root` block into example app + extend `@theme` block. **Drop the hex fallback (Option B)** in inline `var(--cl-token, #hex)` strings across `inbox_live.ex` + `conversation_live.ex`. Re-pin the 5 headless-token assertions to hex-free form. Add negative-grep gate: `grep -r 'var(--cl-[a-z-]*, #' lib/cairnloop/web/` returns zero.
4. **Phase 30 — KB Editorial Polish + T-10-09 / T-10-11 closure (KB-01..KB-04, SEC-01..SEC-02).** Shared editorial nav shell across 4 KB routes; "Create new article" affordance in `Index`; "View source gap" sidebar in `Editor`; calm copy on `SuggestionReview` "Open for manual edit". **SEC-01:** `EditorHandoff.verify!/2` requires a `manual_edit_opened_at` timestamp marker (auditable; simpler than HMAC). **SEC-02:** Editor preload of `proposed_markdown` requires SEC-01's handoff marker, not bare URL `suggestion_id`.
5. **Phase 31 — Golden-Path JTBD Smoke Test (E2E-01..E2E-03).** Single `test/integration/golden_path_test.exs` using `Phoenix.LiveViewTest` covers: seed customer message → operator inbox sees → ConversationLive + cmd+k search + citation chip → approve AI draft → tool proposal approve → ToolExecutionWorker `:success` → resolve → `Outbound.trigger/2` from sidebar → multi-select bulk recovery → `BulkEnvelope` row + per-recipient OutboundWorker jobs. Plus `test/integration/widget_channel_test.exs` (`Phoenix.ChannelTest`). Both registered in `mix test.integration`. **NOT Wallaby. NOT PhoenixTest dep.**
6. **Phase 32 — README + ExDoc guides + JTBD Walkthrough (DOC-01..DOC-04).** README leads with `mix cairnloop.install`. Four guides under `guides/`: quickstart, JTBD walkthrough with PNG screenshots from the Phase-27-seeded example, host integration (`ContextProvider`/`Notifier`/`AutomationPolicy`/`SLAPolicyProvider`), troubleshooting. `mix.exs` package ships `guides/`. CHANGELOG vM014 entry.

## Decided trade-offs (low-impact; flag in PLAN.md for cheap veto)

1. **Test harness:** `Phoenix.LiveViewTest` + `Phoenix.ChannelTest` only. NOT Wallaby (avoids Selenium/Chrome-in-CI flake), NOT PhoenixTest (no new test dep). Already proven across 9 existing integration tests against real Postgres+pgvector.
2. **Brand-token migration:** Drop the hex fallback (Option B) — smallest diff, no churn on inline render code structure. NOT migrate to named CSS classes (Option A — bigger diff, churns sealed render code).
3. **Security threat split:** T-10-09 + T-10-11 bundle with Phase 30 (same files). T-10-10 + T-10-12 + T-10-13 defer to vM015 (domain layer, different file).

## vM015 outline (Operator Polish + Maintenance Gates)

4–5 phases: real `SettingsLive` (MCP tokens + Notifier health + retrieval health + dark mode); audit-log viewer LiveView over `Auditor` events; `/health` + `/metrics` HTTP endpoints; close T-10-10/T-10-12/T-10-13; AR-14-02 pagination; expand ExDoc guides (`05-mcp-clients.md`, `06-extending.md`); `CONTRIBUTING.md` + `docs/architecture.md`; CHANGELOG + v0.2.0 release. Sealed-contract impact: zero.

## vM016+ — Strategic Optionality (DO NOT pre-build)

Ranked by adopter leverage:

1. **Epic 13 — Privacy-First Local AI (Nx/Bumblebee).** Highest leverage. Pluggable `Cairnloop.Intent` adapter (`Req`-based remote default, optional `Nx.Serving` local). Build only if adopter asks.
2. **Epic 12 — Advanced Routing & Team Collaboration.** Medium leverage; opt-in only. Papercups taught "team routing didn't save us." Don't build speculatively.
3. **Epic 14 — Mobile SDK Surface.** Lowest leverage. Defer indefinitely.

## Diminishing-Returns Verdict

**Cairnloop hits "done enough for stated scope" at the close of vM015.** Post-done = adoption + maintenance, not features. Cut v1.0.0 once at least one non-maintainer host runs cairnloop in production. The trap is shipping Epic 12/13/14 before they're asked for — wheel-spinning territory.

## Cross-refs

- Plan file: `/Users/jon/.claude/plans/can-u-decide-this-greedy-balloon.md`
- Brand book: `prompts/cairnloop_brand_book.md`
- Brand tokens (source material for Phase 29 BRAND-01): `prompts/cairnloop.css`, `prompts/cairnloop.tokens.json`
- Domain research: `prompts/elixir-lib-customer-support-automation-deep-research.md`
- JTBD doc: `docs/cairnloop-jtbd-and-user-flows.md` (mine for Phase 32 DOC-02 walkthrough)
- Strategic arc (now outdated; this thread supersedes the M014 = routing/teams call): `.planning/MILESTONE-ARC.md`
- Prior assessment thread for comparison: `.planning/threads/vM012-assessment.md`

## Footguns surfaced for Phase 27+

1. **Don't add Wallaby.** Tempting because "real browser." `Phoenix.LiveViewTest` already drives `live/2` + `render_click/2` + `render_submit/2` against real Postgres+pgvector. Chrome-in-CI flake is real.
2. **Don't migrate inline styles to named CSS classes in Phase 29.** That's Option A — bigger diff, churns sealed render code. Drop the hex fallback (Option B) only.
3. **Don't bundle T-10-10/T-10-12/T-10-13 into Phase 30.** Domain-layer threats; bundling forces a 7th phase. They graduate to vM015.
4. **Don't add Epic 12 routing into vM014.** Domain research + brand book both reject this as the next wedge. Adoption proof first, routing only-if-pulled.
5. **Don't sign new `Cairnloop.Outbound` / `Governance.propose/3` opts in vM014.** Sealed-contract + additive-opts pattern says new behavior via new functions or optional opts only. Stay additive.
6. **D-10 brand-token CSS extraction must re-pin the headless test contract.** 5 tests assert the inline `var(--cl-primary, #A94F30)` form. Phase 29 re-pins them to hex-free form + adds a negative-grep gate.

## When this thread closes

- **Closes after Phase 27 plan ratifies the fixtures + carries-this-thread-as-research-input.** Mark `status: closed` here when `vM014-phases/27-*/CONTEXT.md` cites this file in its ratification notes.
- Until then, treat this thread as the canonical context window for subagents — read it before re-deriving the assessment.
