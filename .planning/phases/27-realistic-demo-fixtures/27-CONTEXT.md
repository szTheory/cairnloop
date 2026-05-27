# Phase 27: Realistic Demo Fixtures - Context

**Gathered:** 2026-05-27
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace `examples/cairnloop_example/priv/repo/seeds.exs` (currently 49 LOC / 1 conversation / 1 article — a lonely demo) with a JTBD-spanning fixture set that exercises the M008 retrieval substrate end-to-end on first `mix setup`. After this phase, an adopter who runs `mix setup` in the example app lands in a populated dashboard with 16 conversations across the full Jobs-To-Be-Done lifecycle, 5 KB articles with multiple revisions (including one archived), 3+ inspectable GapCandidates with evidence, and at least 1 ArticleSuggestion `:ready_for_review` — and the embeddings reach pgvector via the live `Cairnloop.KnowledgeBase.Workers.ChunkRevision` Oban worker (not a fixture shortcut).

**Strict scope guard (vM014):** Additive only. No churn to sealed primitives (`Cairnloop.Outbound.trigger/2`, `Cairnloop.Governance.propose/3`, MCP `tools/call`, three-layer at-most-once execution, `BulkEnvelope` cap, approval state machine, Conversation/Revision/Article schemas). Roadmap-language gray areas (status enum mismatches, "deprecated" naming) are resolved by mapping to existing sealed enums, never by changing schemas.

</domain>

<decisions>
## Implementation Decisions

### Seed structure & file layout
- **D-01:** Replace `examples/cairnloop_example/priv/repo/seeds.exs` body. Keep the file path stable (it is the `ecto.setup` alias target). Split the body into named private builder functions inside an anonymous module-style flow (`build_articles/0`, `build_conversations/1`, `build_gaps/1`, `build_suggestion/2`, `drain_embedding_pipeline/0`) so reviewers can read the seed at a glance. No separate seed module under `lib/` — the file remains a script, not a library module.
- **D-02:** **Idempotent seeds.** Re-running `mix run priv/repo/seeds.exs` against an already-seeded DB is a no-op. Achieve via natural-key lookups + `Repo.get_by` guards (e.g., article title, conversation subject prefix `"[demo-NN] …"`). No `on_conflict` magic — explicit `if existing, do: existing, else: insert!`. Reason: adopters re-run seeds, and `mix ecto.reset` is not the only path that hits them.

### JTBD status semantics (sealed-schema reconciliation)
- **D-03:** Roadmap criterion lists `:new`, `:open`, `:awaiting_customer`, `:resolved` — but `Cairnloop.Conversation.status` enum is sealed at `[:open, :resolved, :archived]`. **JTBD state is derived, not stored.** Mapping:
  - **"new"** → `status: :open` + zero `:agent` messages → 4 seeded conversations.
  - **"open"** → `status: :open` + has `:agent` reply, last message from `:user` (customer follow-up) → 4 seeded conversations.
  - **"awaiting_customer"** → `status: :open` + has `:agent` reply, last message from `:agent` → 4 seeded conversations.
  - **"resolved"** → `status: :resolved` + `resolved_at` set + last message either `:agent` or `:system_outbound` → 4 seeded conversations.
  - Total: 16 conversations (top of the 12–16 band).
- **D-04:** No `:new` or `:awaiting_customer` enum value is to be added to `Conversation.status`. The planner must NOT propose a schema migration here — sealed contract.

### Revision "deprecated" mapping (sealed-schema reconciliation)
- **D-05:** Spec says "at least one `:deprecated` revision". `KnowledgeBase.Revision.state` enum is sealed at `[:draft, :published, :archived]`. **Interpret "deprecated" as `:archived`** — the existing state for a superseded older version retired by a newer publish. One seeded article runs the version progression: v1 inserted as `:published`, then `:archived`, then v2 inserted and published. **No schema change.** Planner notes the naming-vs-schema mismatch in PLAN.md so it is not re-litigated.

### Embedder behavior during seeding
- **D-06:** **No new embedder stub.** `Cairnloop.Embedder.ExternalApi.generate_embeddings/2` already fail-closes to 1536-dim zero-vector mocks when `OPENAI_API_KEY` is unset (the existing dev-safety branch at `lib/cairnloop/embedder/external_api.ex:13-21`). Adopters without keys still get a populated `cairnloop_chunks` table — embeddings collide as zero vectors, cmd+k returns lex order. That is acceptable for Phase 27 (FIX-02 success criterion is "embeddings flow through the live `ChunkRevision` Oban worker into pgvector", not "search is semantically meaningful"). Add a one-line comment in `seeds.exs`: `# Set OPENAI_API_KEY before mix setup for semantically ranked search; otherwise zero-vector embeddings are written.`
- **D-07:** Phase 27 does NOT upgrade the embedder mock to varied deterministic vectors. That is a Phase 31 (smoke-test stability) or vM015 concern.

### M008 substrate self-test (Oban drain at end of seeds)
- **D-08:** At end of `seeds.exs`, synchronously drain the `:default` Oban queue with recursion enabled, so all `ChunkRevision` jobs enqueued by `KnowledgeBase.publish_revision/1` complete before the script exits and the adopter opens the inbox. Call shape: `Oban.drain_queue(queue: :default, with_recursion: true)`. This is what makes FIX-02 a substrate self-test rather than a fixture shortcut — the chunks land in `cairnloop_chunks` via the live worker, exactly as production publishing does.
- **D-09:** Use the library's facade for revision creation. Insert via `Cairnloop.KnowledgeBase.create_article/1` + `KnowledgeBase.save_draft/2` + `KnowledgeBase.publish_revision/1` — not direct `Repo.insert!` against `%Revision{}`. This routes through the same Multi that enqueues `ChunkRevision`. Direct Repo inserts are only used where no facade exists (e.g., `Cairnloop.Message`, `GapCandidate`).

### ContextProvider snippets (FIX-01 requirement)
- **D-10:** Ship a new module `CairnloopExample.DemoContextProvider` at `examples/cairnloop_example/lib/cairnloop_example/demo_context_provider.ex`, implementing `Cairnloop.ContextProvider`. Returns a deterministic per-actor map keyed by `conversation.host_user_id` (e.g., `"demo_user_acme_billing"`, `"demo_user_globex_seats"`). Returned map matches the behaviour's documented shape: `{:ok, %{"User Details" => %{...}, "Active Plan" => %{...}, ...}}`. Fail-open to `{:ok, %{}}` for unknown actors (mirrors `DefaultContextProvider`).
- **D-11:** Wire the provider in `examples/cairnloop_example/config/config.exs` via `config :cairnloop, :context_provider, CairnloopExample.DemoContextProvider`. Additive — sealed config surface is the configured-adapter pattern the library already documents (`lib/cairnloop/web/conversation_live.ex:358`). Wire only in the example app, never in the library.
- **D-12:** Each demo actor returns plausible context (3–5 categorized sections — e.g. "User Details", "Active Plan", "Recent Charges", "Seats", "API Keys"). Tone follows `prompts/cairnloop_brand_book.md` §7.5 — calm, factual, no raw Elixir terms surfaced to operators.

### GapCandidate seeding path
- **D-13:** Direct-insert 3+ `GapCandidate` rows + `GapCandidateMembership` rows. **Do NOT run the live `CandidateBuilder` from seeds.** Rationale: M008 substrate self-test (D-08) is the embedding pipeline; the M010 builder is exercised by Phase 31's golden-path smoke. Bringing M010 worker scheduling, scoring quirks, and `RetrievalGapEvent` seeding inside FIX-* would overcouple the phase. (User-ratified 2026-05-27.)
- **D-14:** Each seeded `GapCandidate`: stable `stable_key` (e.g. `"demo_gap_billing_export"`), `status: :open`, `candidate_type: :mixed`, scored in `0.4–0.8`, `first_seen_at`/`last_seen_at` distributed across the past 14 days, `evidence_count: 2..4`, `manual_case_count` and `weak_grounding_count` non-zero so the ranked maintenance queue renders varied score components. Each row gets 1–2 `GapCandidateMembership` rows with `source_type: :retrieval_gap_event` and `source_id` pointing at synthesized `RetrievalGapEvent` rows that reference seeded conversations.

### ArticleSuggestion (ready-for-review) seeding path
- **D-15:** Direct-insert 1 `ArticleSuggestion` row with `status: :ready_for_review`, `suggestion_type: :new_article` (gap-driven path — no `article_id` / `base_revision_id` per `article_suggestion.ex:155`), `tenant_scope`/`host_user_id` set consistently with a seeded conversation, hand-authored `proposed_markdown` with `[1]`/`[2]` footnote anchors. **Do NOT enqueue `Workers.GenerateArticleSuggestion`** — it makes an LLM call; adopters running `mix setup` would either flake (no keys) or burn tokens. Phase 31's smoke exercises the live worker.
- **D-16:** Companion `ArticleSuggestionEvidence` rows (2 minimum) point at real seeded conversation messages plus 1 KB chunk from a seeded `:published` revision. `evidence_digest` is computed deterministically from the evidence row ids/contents (same algorithm `CandidateBuilder` uses; mirror its output shape). `generated_at` set; `dismissed_at` and `manual_edit_opened_at` left `nil`.

### Demo product, voice, and content
- **D-17:** Demo product name: **"Trailmark"** — a generic dev-tools SaaS (CI runs, API keys, billing, team seats). Plain, low-stakes, recognizable to most adopters. Five KB articles (working titles):
  1. "Resetting your Trailmark API key" — deflectable, FAQ.
  2. "Updating your billing email" — deflectable.
  3. "Adding a team seat" — governed action path (proposes a `seat_invite` tool — though tool is not seeded in this phase).
  4. "Why a CI run was skipped" — diagnostic, links to gap signals.
  5. "Rotating an expired token" — short, deprecated v1 → published v2.
  Article 5 is the multi-revision article with one `:archived` revision.
- **D-18:** Conversation subjects + message bodies follow brand voice (`prompts/cairnloop_brand_book.md`): calm, fail-closed, reason-forward, honest. Never raw Elixir atoms / raw JSON in customer or operator copy. Internal-note bodies allowed to reference IDs/typed terms. Each conversation has 3–6 messages.
- **D-19:** Demo distribution across articles: at least one conversation per article matches its topic (so cmd+k against the article title yields a sensible match even with zero-vector embeddings via lex sort).

### Test posture for this phase
- **D-20:** Phase 27 ships seeds + the new `DemoContextProvider`. **Headless tests** (no Repo) cover `DemoContextProvider.get_context/2` returns the documented shape for known + unknown actors. **Integration test (optional, planner judgment)** — if the existing `mix test.integration` harness can boot the example app's repo, a single test asserts `seeds.exs` runs cleanly, the resulting row counts hit the FIX-* thresholds, and the `cairnloop_chunks` table is non-empty after the Oban drain. Test live alongside library tests in `test/integration/example_seed_test.exs` so they share the dockerized Postgres harness.
- **D-21:** The seed script itself must be warnings-clean (`mix compile --warnings-as-errors` does not cover .exs scripts, but the planner is responsible for ensuring no obvious script warnings). All script code paths total / fail-closed.

### Claude's Discretion
- Per-conversation message timing distribution (timestamps), CSAT ratings on resolved conversations, exact `recipient_emails` choice for resolved-conversation outbound-eligibility, and the precise text bodies of all 16 conversations + 5 articles + 1 suggestion. The planner / executor decides these against the brand voice constraint (D-18).
- Whether seeded `RetrievalGapEvent` rows (referenced by `GapCandidateMembership.source_id` in D-14) are full rows or synthetic ids; planner picks the smallest path that keeps the gap-queue UI rendering inspectable evidence.
- Whether to add a per-article-title `stable_key` column-free natural key or just match on `title`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & milestone-level context
- `.planning/PROJECT.md` — vM014 brief, architectural invariants (sealed-contract + additive-opts, snapshot-at-decision, fail-closed envelope-boundary cap, three-layer at-most-once, Governance-facade reads from web).
- `.planning/REQUIREMENTS.md` lines 18–21 — FIX-01..FIX-04 acceptance language.
- `.planning/ROADMAP.md` "Phase 27" block — goal, success criteria, dependency-order rationale.
- `.planning/STATE.md` — carried decisions, deferred items, vM014 test-harness + D-10 + SEC-split rulings.
- `.planning/threads/vM014-adoption-proof-assessment.md` — canonical assessment thread; close this thread when Phase 27 PLAN.md cites it.
- `/Users/jon/.claude/plans/can-u-decide-this-greedy-balloon.md` — multi-phase planning doc referenced by ROADMAP.md.

### Library architecture & voice
- `prompts/cairnloop_brand_book.md` — brand voice, copy register, §7.5 (never raw Elixir terms; calm/fail-closed/reason-forward). Applies to all seeded message bodies and ContextProvider section names.
- `prompts/elixir-lib-customer-support-automation-deep-research.md` — host-owned architecture posture.
- `CLAUDE.md` — repo-level shift-left, build/test conventions, warnings-clean mandate.

### Library code (substrate the seeds drive)
- `lib/cairnloop/knowledge_base.ex` — facade: `create_article/1`, `save_draft/2`, `publish_revision/1` (this is what enqueues `ChunkRevision`). Use these.
- `lib/cairnloop/knowledge_base/workers/chunk_revision.ex` — the worker the M008 self-test drives.
- `lib/cairnloop/embedder/external_api.ex` lines 13–21 — the zero-vector fallback that adopters without `OPENAI_API_KEY` hit.
- `lib/cairnloop/context_provider.ex` + `lib/cairnloop/default_context_provider.ex` — behaviour the new `CairnloopExample.DemoContextProvider` implements.
- `lib/cairnloop/conversation.ex` — sealed `status` enum `[:open, :resolved, :archived]`.
- `lib/cairnloop/message.ex` — sealed `role` enum `[:user, :agent, :system, :internal_note, :system_outbound]`.
- `lib/cairnloop/knowledge_base/article.ex` — sealed `status` enum `[:draft, :published, :archived]`.
- `lib/cairnloop/knowledge_base/revision.ex` — sealed `state` enum `[:draft, :published, :archived]`; "deprecated" in spec maps to `:archived`.
- `lib/cairnloop/knowledge_automation/gap_candidate.ex` — schema for direct-insert path (D-13/D-14).
- `lib/cairnloop/knowledge_automation/gap_candidate_membership.ex` — membership schema; `source_type` enum.
- `lib/cairnloop/knowledge_automation/article_suggestion.ex` — schema for direct-insert path (D-15/D-16); validation requires gap-driven path has `article_id`/`base_revision_id` blank.
- `lib/cairnloop/knowledge_automation/article_suggestion_evidence.ex` — companion evidence rows.
- `lib/cairnloop/retrieval/gap_event.ex` — `RetrievalGapEvent` schema (for D-14 membership source rows).

### Example app touchpoints
- `examples/cairnloop_example/priv/repo/seeds.exs` — the file Phase 27 rewrites.
- `examples/cairnloop_example/config/config.exs` lines 59–61 — where `config :cairnloop, :context_provider, ...` is added (D-11).
- `examples/cairnloop_example/mix.exs` lines 80–83 — `setup` / `ecto.setup` aliases (the path adopters take). Phase 27 must not change these.
- `examples/cairnloop_example/lib/cairnloop_example/` — destination for `demo_context_provider.ex` (D-10).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Cairnloop.KnowledgeBase.create_article/1` + `save_draft/2` + `publish_revision/1`** — the canonical facade for inserting articles + revisions. `publish_revision/1` is what enqueues `ChunkRevision`. Use it in seeds (D-09); do not bypass with raw `Repo.insert!` on `%Revision{}` — that would skip the Oban enqueue and fail the M008 self-test.
- **`Cairnloop.Embedder.ExternalApi`** — already has a dev-safe fallback for missing `OPENAI_API_KEY` (1536-dim zero vectors). No new mock needed (D-06).
- **`Oban.drain_queue/1`** — standard Oban facility; the seed-end drain call (D-08) uses this directly. The example app's Oban is configured at `examples/cairnloop_example/config/config.exs:54-57` with `queues: [default: 10]`; that is the queue to drain.
- **`Cairnloop.ContextProvider` behaviour** (`lib/cairnloop/context_provider.ex`) — 1 callback (`get_context/2`), tagged-tuple return. `DefaultContextProvider` is 13 LOC. The demo provider is a ~30–50 LOC module of pattern-matched per-actor returns.

### Established Patterns
- **Configured-adapter pattern.** `:cairnloop, :repo`, `:cairnloop, :tools`, `:cairnloop, :embedder` (already pluggable), `:cairnloop, :context_provider`, `:cairnloop, :automation_policy`, `:cairnloop, :notifier`, `:cairnloop, :sla_policy_provider`, `:cairnloop, :knowledge_automation` — all swap via `Application.get_env/3` lookups in the library. Adding `:context_provider` in the example app is additive.
- **Sealed enums are load-bearing.** `Conversation.status`, `Revision.state`, `Article.status`, `Message.role` are all referenced from LiveViews, tests, and the integration harness. Schema migrations here would cascade across vM011/vM012/vM013-shipped surfaces. JTBD states must be derived (D-03), not stored.
- **Headless-first tests.** `Cairnloop.Repo` is unavailable in many CI/dev contexts. The new `DemoContextProvider` test is pure (input → output map; no DB). Integration test for the seed-run lives in the existing dockerized harness (`MIX_ENV=test mix test.integration`), not in the headless `mix test` lane.
- **Idempotent fixtures via natural keys.** Pre-existing test factories use `Repo.get_by` guards before inserting, not `on_conflict`. Seeds follow the same pattern (D-02).
- **`publish_revision/1` does a full Multi.** Inserting a revision via Multi + enqueuing `ChunkRevision` in the same transaction is the production-shipping pattern (`lib/cairnloop/knowledge_base.ex:71-86`). Mirror it; never split the insert and the enqueue across seed phases.

### Integration Points
- **`seeds.exs` → `KnowledgeBase` facade → `ChunkRevision` worker → `Embedder.ExternalApi` → `pgvector` chunks table.** This is the M008 substrate self-test path; FIX-02 is the criterion that validates it runs end-to-end on first boot.
- **`config :cairnloop, :context_provider, ...` → `ConversationLive` → operator inbox snippet rendering** (`lib/cairnloop/web/conversation_live.ex:358`). FIX-01's "ContextProvider snippets" criterion is satisfied by adding the example provider + wiring it in `config.exs`.
- **`GapCandidate` direct inserts → `KnowledgeBaseLive.Gaps` LiveView** — gap queue read path; FIX-03 success criterion. Inspectable via the existing route at `/support/knowledge-base/gaps` (mounted in the example router).
- **`ArticleSuggestion` direct insert → `KnowledgeBaseLive.SuggestionReview`** — mounted at `/support/knowledge-base/suggestions`. FIX-04 success criterion. Reviewer must NOT need to wait for the LLM worker.

</code_context>

<specifics>
## Specific Ideas

- **Product name: "Trailmark"** — generic dev-tools SaaS persona for the example. Recognizable problem domain (CI runs, API keys, billing, team seats). Cheap to write convincing 16-conversation × 5-article surface area.
- **Article-5 multi-revision sequence**: "Rotating an expired token" — v1 published with a now-incorrect 30-day rotation guidance, then `:archived` when v2 is published with a 90-day correction. This is the deprecated-revision proof (FIX-02 success criterion).
- **JTBD cohort distribution: 4 conversations × 4 derived states = 16.** Top of the 12–16 band. Each cohort visually distinct in the inbox.
- **Stable seed identifiers**: conversation subjects prefixed `[demo-NN]` for fast natural-key lookups; article titles unique + stable.
- **Comment in seeds.exs** explaining: (a) idempotency contract (D-02), (b) `OPENAI_API_KEY` for ranked search (D-06), (c) Oban drain at end (D-08), (d) that "deprecated" in spec maps to `:archived` here (D-05).

</specifics>

<deferred>
## Deferred Ideas

- **Semantically-meaningful demo search (deterministic varied embeddings or local Bumblebee inference).** Belongs in Phase 31 or vM015 — Phase 27 accepts zero-vector mocks (D-07).
- **Running `Workers.GenerateArticleSuggestion` from seeds (live LLM path).** Out of scope for Phase 27 (D-15). Phase 31's golden-path smoke exercises this worker.
- **Running `CandidateBuilder` from seeds (M010 self-test).** Out of scope for Phase 27 (D-13). Phase 31 covers it.
- **Seeding `ToolProposal` rows (governed-action demo) and a fixture `seat_invite` Tool.** Not in FIX-01..FIX-04. May land in Phase 28 (chat ingress) or be its own future phase if adopter feedback warrants.
- **`SettingsLive` overhaul (MCP tokens / Notifier health / retrieval health / dark mode).** Already deferred to vM015 per `.planning/STATE.md`.
- **`/health` + `/metrics` HTTP endpoints.** vM015.
- **Wallaby / PhoenixTest dep.** Out of scope for vM014; not relevant to Phase 27 specifically.
- **AR-14-02: governed-actions rail pagination.** Pre-existing tech debt, unrelated to seeds.

</deferred>

---

*Phase: 27-Realistic Demo Fixtures*
*Context gathered: 2026-05-27*
