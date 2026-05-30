# Phase 27: Realistic Demo Fixtures — Research

**Researched:** 2026-05-27
**Domain:** Elixir/Ecto seed scripts + Oban worker drain + ContextProvider behaviour wiring (Phoenix example-app scope)
**Confidence:** HIGH

## Summary

Phase 27 is a pure fixture/configuration phase: rewrite `examples/cairnloop_example/priv/repo/seeds.exs` to populate a JTBD-spanning dashboard, ship a `CairnloopExample.DemoContextProvider`, and wire it via `:cairnloop, :context_provider`. The phase is additive — no library code is modified, no schemas are changed, no migrations are added. The only library-side surface this phase _drives_ is the `Cairnloop.KnowledgeBase` facade (which routes through the existing `ChunkRevision` Oban worker) and the existing `Cairnloop.ContextProvider` behaviour.

The substantive research effort uncovered three load-bearing facts the planner must internalize before slicing tasks:

1. **CONTEXT.md uses spec-language enum values that do not exist in the schema.** Specifically: `:ready_for_review` is spec language for the actual `:ready` enum value on `ArticleSuggestion.status`; `:new_article` is spec language for the actual `:article` enum value on `ArticleSuggestion.suggestion_type`; `:deprecated` is spec language for the actual `:archived` enum value on `Revision.state` (D-05 already mapped this; D-15 forgot to apply the same mapping to suggestion enums). The planner must consistently translate `:ready_for_review`→`:ready` and `:new_article`→`:article` in PLAN.md tasks. This is the **same** sealed-schema-vs-roadmap-language reconciliation that D-05 documents — but spread across all three enums, not just `Revision.state`.
2. **A seeded `ArticleSuggestion` alone will NOT render in `SuggestionReview`.** The LiveView reads from `ReviewTask` (preloading `:article_suggestion`), not `ArticleSuggestion` directly. The seed must also call `KnowledgeAutomation.ensure_review_task_for_suggestion/2` (or equivalent direct insert of `%ReviewTask{} + %ReviewTaskEvent{:task_created}`) after inserting the suggestion. FIX-04 is at risk if this is missed.
3. **The `MIX_ENV=test mix test.integration` harness CANNOT host a seed-smoke test for the example app**, because the library's integration harness runs against `Cairnloop.Repo` (test_host migrations) while `seeds.exs` runs against `CairnloopExample.Repo` (example app's own migrations + the library's migrations on top). They are two separate repos with separate sandbox modes. The smallest workable integration test path is to add a seed-smoke test inside `examples/cairnloop_example/test/` using `CairnloopExample.DataCase`. CONTEXT.md D-20 leaves this as planner judgment; **recommendation:** include it, since FIX-02's "embeddings flow through the live Oban worker" cannot be asserted from headless tests alone.

**Primary recommendation:** Plan five sequential builder functions in `seeds.exs` (`build_articles/0`, `build_conversations/1`, `build_gaps/1`, `build_suggestion_with_review_task/2`, `drain_embedding_pipeline/0`), all idempotent via `Repo.get_by` on natural keys; pair with a ~40-line `CairnloopExample.DemoContextProvider` and a one-line config wire; cover with a 2-case headless test for the provider + one integration test in the example app's own test suite asserting row counts + non-empty `cairnloop_chunks` table after drain.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Seed data insertion | Example app (`priv/repo/seeds.exs` script) | Library `KnowledgeBase` facade | The seed is example-app-owned; it _uses_ the library's facade as the documented integration path. |
| Article + Revision creation | Library facade (`KnowledgeBase.create_article` + `save_draft` + `publish_revision`) | — | `publish_revision/1` is the only path that enqueues `ChunkRevision` in the same Multi; bypassing it breaks FIX-02. |
| Embedding (chunk) generation | Library Oban worker (`Workers.ChunkRevision`) via `Embedder.ExternalApi` | — | Live worker is the M008 substrate self-test; the seed kicks it via `Oban.drain_queue/1` at end. |
| Conversation + Message creation | Example app seed via direct `Repo.insert` of `%Conversation{}` + `%Message{}` | — | No public facade exists for conversation/message creation; direct insert is the established pattern (matches `test/support/fixtures.ex`). |
| GapCandidate + Membership seeding | Example app seed via direct `Repo.insert` | — | D-13: the live `CandidateBuilder` is M010 substrate — running it here overcouples Phase 27 with Phase 31's surface. Direct insert is sufficient for the LiveView to render. |
| ArticleSuggestion + ReviewTask seeding | Example app seed via direct `Repo.insert` of `%ArticleSuggestion{}`, then `KnowledgeAutomation.ensure_review_task_for_suggestion/2` (or direct insert of `%ReviewTask{} + %ReviewTaskEvent{}`) | — | D-15 (no LLM call) plus the LiveView's actual data source (`ReviewTask`, not `ArticleSuggestion`). |
| ContextProvider implementation | Example app module (`CairnloopExample.DemoContextProvider`) | Library behaviour (`Cairnloop.ContextProvider`) | D-10/D-11: behaviour is library-owned; concrete impl is example-owned. |
| ContextProvider wiring | Example app `config/config.exs` via `config :cairnloop, :context_provider, …` | — | The configured-adapter pattern; the library reads this with `Application.get_env/3` at `conversation_live.ex:358`. |
| Test surface (headless) | Example app `test/cairnloop_example/demo_context_provider_test.exs` | — | Pure pattern-matched-return tests; no Repo; mirrors `test/cairnloop/context_provider_test.exs`. |
| Test surface (integration) | Example app `test/cairnloop_example/seeds_test.exs` using `CairnloopExample.DataCase` | — | Library `test.integration` harness cannot drive `CairnloopExample.Repo` (separate repo). |

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Seed structure & file layout
- **D-01:** Replace `examples/cairnloop_example/priv/repo/seeds.exs` body. Keep the file path stable (it is the `ecto.setup` alias target). Split the body into named private builder functions inside an anonymous module-style flow (`build_articles/0`, `build_conversations/1`, `build_gaps/1`, `build_suggestion/2`, `drain_embedding_pipeline/0`) so reviewers can read the seed at a glance. No separate seed module under `lib/` — the file remains a script, not a library module.
- **D-02:** **Idempotent seeds.** Re-running `mix run priv/repo/seeds.exs` against an already-seeded DB is a no-op. Achieve via natural-key lookups + `Repo.get_by` guards (e.g., article title, conversation subject prefix `"[demo-NN] …"`). No `on_conflict` magic — explicit `if existing, do: existing, else: insert!`. Reason: adopters re-run seeds, and `mix ecto.reset` is not the only path that hits them.

#### JTBD status semantics (sealed-schema reconciliation)
- **D-03:** Roadmap criterion lists `:new`, `:open`, `:awaiting_customer`, `:resolved` — but `Cairnloop.Conversation.status` enum is sealed at `[:open, :resolved, :archived]`. **JTBD state is derived, not stored.** Mapping:
  - **"new"** → `status: :open` + zero `:agent` messages → 4 seeded conversations.
  - **"open"** → `status: :open` + has `:agent` reply, last message from `:user` (customer follow-up) → 4 seeded conversations.
  - **"awaiting_customer"** → `status: :open` + has `:agent` reply, last message from `:agent` → 4 seeded conversations.
  - **"resolved"** → `status: :resolved` + `resolved_at` set + last message either `:agent` or `:system_outbound` → 4 seeded conversations.
  - Total: 16 conversations (top of the 12–16 band).
- **D-04:** No `:new` or `:awaiting_customer` enum value is to be added to `Conversation.status`. The planner must NOT propose a schema migration here — sealed contract.

#### Revision "deprecated" mapping (sealed-schema reconciliation)
- **D-05:** Spec says "at least one `:deprecated` revision". `KnowledgeBase.Revision.state` enum is sealed at `[:draft, :published, :archived]`. **Interpret "deprecated" as `:archived`** — the existing state for a superseded older version retired by a newer publish. One seeded article runs the version progression: v1 inserted as `:published`, then `:archived`, then v2 inserted and published. **No schema change.** Planner notes the naming-vs-schema mismatch in PLAN.md so it is not re-litigated.

#### Embedder behavior during seeding
- **D-06:** **No new embedder stub.** `Cairnloop.Embedder.ExternalApi.generate_embeddings/2` already fail-closes to 1536-dim zero-vector mocks when `OPENAI_API_KEY` is unset (the existing dev-safety branch at `lib/cairnloop/embedder/external_api.ex:13-21`). Adopters without keys still get a populated `cairnloop_chunks` table — embeddings collide as zero vectors, cmd+k returns lex order. That is acceptable for Phase 27 (FIX-02 success criterion is "embeddings flow through the live `ChunkRevision` Oban worker into pgvector", not "search is semantically meaningful"). Add a one-line comment in `seeds.exs`: `# Set OPENAI_API_KEY before mix setup for semantically ranked search; otherwise zero-vector embeddings are written.`
- **D-07:** Phase 27 does NOT upgrade the embedder mock to varied deterministic vectors. That is a Phase 31 (smoke-test stability) or vM015 concern.

#### M008 substrate self-test (Oban drain at end of seeds)
- **D-08:** At end of `seeds.exs`, synchronously drain the `:default` Oban queue with recursion enabled, so all `ChunkRevision` jobs enqueued by `KnowledgeBase.publish_revision/1` complete before the script exits and the adopter opens the inbox. Call shape: `Oban.drain_queue(queue: :default, with_recursion: true)`. This is what makes FIX-02 a substrate self-test rather than a fixture shortcut — the chunks land in `cairnloop_chunks` via the live worker, exactly as production publishing does.
- **D-09:** Use the library's facade for revision creation. Insert via `Cairnloop.KnowledgeBase.create_article/1` + `KnowledgeBase.save_draft/2` + `KnowledgeBase.publish_revision/1` — not direct `Repo.insert!` against `%Revision{}`. This routes through the same Multi that enqueues `ChunkRevision`. Direct Repo inserts are only used where no facade exists (e.g., `Cairnloop.Message`, `GapCandidate`).

#### ContextProvider snippets (FIX-01 requirement)
- **D-10:** Ship a new module `CairnloopExample.DemoContextProvider` at `examples/cairnloop_example/lib/cairnloop_example/demo_context_provider.ex`, implementing `Cairnloop.ContextProvider`. Returns a deterministic per-actor map keyed by `conversation.host_user_id` (e.g., `"demo_user_acme_billing"`, `"demo_user_globex_seats"`). Returned map matches the behaviour's documented shape: `{:ok, %{"User Details" => %{...}, "Active Plan" => %{...}, ...}}`. Fail-open to `{:ok, %{}}` for unknown actors (mirrors `DefaultContextProvider`).
- **D-11:** Wire the provider in `examples/cairnloop_example/config/config.exs` via `config :cairnloop, :context_provider, CairnloopExample.DemoContextProvider`. Additive — sealed config surface is the configured-adapter pattern the library already documents (`lib/cairnloop/web/conversation_live.ex:358`). Wire only in the example app, never in the library.
- **D-12:** Each demo actor returns plausible context (3–5 categorized sections — e.g. "User Details", "Active Plan", "Recent Charges", "Seats", "API Keys"). Tone follows `prompts/cairnloop_brand_book.md` §7.5 — calm, factual, no raw Elixir terms surfaced to operators.

#### GapCandidate seeding path
- **D-13:** Direct-insert 3+ `GapCandidate` rows + `GapCandidateMembership` rows. **Do NOT run the live `CandidateBuilder` from seeds.** Rationale: M008 substrate self-test (D-08) is the embedding pipeline; the M010 builder is exercised by Phase 31's golden-path smoke. Bringing M010 worker scheduling, scoring quirks, and `RetrievalGapEvent` seeding inside FIX-* would overcouple the phase. (User-ratified 2026-05-27.)
- **D-14:** Each seeded `GapCandidate`: stable `stable_key` (e.g. `"demo_gap_billing_export"`), `status: :open`, `candidate_type: :mixed`, scored in `0.4–0.8`, `first_seen_at`/`last_seen_at` distributed across the past 14 days, `evidence_count: 2..4`, `manual_case_count` and `weak_grounding_count` non-zero so the ranked maintenance queue renders varied score components. Each row gets 1–2 `GapCandidateMembership` rows with `source_type: :retrieval_gap_event` and `source_id` pointing at synthesized `RetrievalGapEvent` rows that reference seeded conversations.

#### ArticleSuggestion (ready-for-review) seeding path
- **D-15:** Direct-insert 1 `ArticleSuggestion` row with `status: :ready_for_review`, `suggestion_type: :new_article` (gap-driven path — no `article_id` / `base_revision_id` per `article_suggestion.ex:155`), `tenant_scope`/`host_user_id` set consistently with a seeded conversation, hand-authored `proposed_markdown` with `[1]`/`[2]` footnote anchors. **Do NOT enqueue `Workers.GenerateArticleSuggestion`** — it makes an LLM call; adopters running `mix setup` would either flake (no keys) or burn tokens. Phase 31's smoke exercises the live worker.
- **D-16:** Companion `ArticleSuggestionEvidence` rows (2 minimum) point at real seeded conversation messages plus 1 KB chunk from a seeded `:published` revision. `evidence_digest` is computed deterministically from the evidence row ids/contents (same algorithm `CandidateBuilder` uses; mirror its output shape). `generated_at` set; `dismissed_at` and `manual_edit_opened_at` left `nil`.

#### Demo product, voice, and content
- **D-17:** Demo product name: **"Trailmark"** — a generic dev-tools SaaS (CI runs, API keys, billing, team seats). Plain, low-stakes, recognizable to most adopters. Five KB articles (working titles):
  1. "Resetting your Trailmark API key" — deflectable, FAQ.
  2. "Updating your billing email" — deflectable.
  3. "Adding a team seat" — governed action path (proposes a `seat_invite` tool — though tool is not seeded in this phase).
  4. "Why a CI run was skipped" — diagnostic, links to gap signals.
  5. "Rotating an expired token" — short, deprecated v1 → published v2.
  Article 5 is the multi-revision article with one `:archived` revision.
- **D-18:** Conversation subjects + message bodies follow brand voice (`prompts/cairnloop_brand_book.md`): calm, fail-closed, reason-forward, honest. Never raw Elixir atoms / raw JSON in customer or operator copy. Internal-note bodies allowed to reference IDs/typed terms. Each conversation has 3–6 messages.
- **D-19:** Demo distribution across articles: at least one conversation per article matches its topic (so cmd+k against the article title yields a sensible match even with zero-vector embeddings via lex sort).

#### Test posture for this phase
- **D-20:** Phase 27 ships seeds + the new `DemoContextProvider`. **Headless tests** (no Repo) cover `DemoContextProvider.get_context/2` returns the documented shape for known + unknown actors. **Integration test (optional, planner judgment)** — if the existing `mix test.integration` harness can boot the example app's repo, a single test asserts `seeds.exs` runs cleanly, the resulting row counts hit the FIX-* thresholds, and the `cairnloop_chunks` table is non-empty after the Oban drain. Test live alongside library tests in `test/integration/example_seed_test.exs` so they share the dockerized Postgres harness.
- **D-21:** The seed script itself must be warnings-clean (`mix compile --warnings-as-errors` does not cover .exs scripts, but the planner is responsible for ensuring no obvious script warnings). All script code paths total / fail-closed.

### Claude's Discretion
- Per-conversation message timing distribution (timestamps), CSAT ratings on resolved conversations, exact `recipient_emails` choice for resolved-conversation outbound-eligibility, and the precise text bodies of all 16 conversations + 5 articles + 1 suggestion. The planner / executor decides these against the brand voice constraint (D-18).
- Whether seeded `RetrievalGapEvent` rows (referenced by `GapCandidateMembership.source_id` in D-14) are full rows or synthetic ids; planner picks the smallest path that keeps the gap-queue UI rendering inspectable evidence.
- Whether to add a per-article-title `stable_key` column-free natural key or just match on `title`.

### Deferred Ideas (OUT OF SCOPE)
- **Semantically-meaningful demo search (deterministic varied embeddings or local Bumblebee inference).** Belongs in Phase 31 or vM015 — Phase 27 accepts zero-vector mocks (D-07).
- **Running `Workers.GenerateArticleSuggestion` from seeds (live LLM path).** Out of scope for Phase 27 (D-15). Phase 31's golden-path smoke exercises this worker.
- **Running `CandidateBuilder` from seeds (M010 self-test).** Out of scope for Phase 27 (D-13). Phase 31 covers it.
- **Seeding `ToolProposal` rows (governed-action demo) and a fixture `seat_invite` Tool.** Not in FIX-01..FIX-04. May land in Phase 28 (chat ingress) or be its own future phase if adopter feedback warrants.
- **`SettingsLive` overhaul (MCP tokens / Notifier health / retrieval health / dark mode).** Already deferred to vM015 per `.planning/STATE.md`.
- **`/health` + `/metrics` HTTP endpoints.** vM015.
- **Wallaby / PhoenixTest dep.** Out of scope for vM014; not relevant to Phase 27 specifically.
- **AR-14-02: governed-actions rail pagination.** Pre-existing tech debt, unrelated to seeds.

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FIX-01 | Seed 12–16 conversations spanning JTBD lifecycle with ContextProvider snippets — replaces 1-conversation demo. | D-03 cohort mapping (4 × 4 = 16 seeded conversations) + D-10/D-11 (`CairnloopExample.DemoContextProvider` + `config :cairnloop, :context_provider, …`). Conversation router scope is `host_user_id: "demo_operator"` (`examples/cairnloop_example/lib/cairnloop_example_web/router.ex:20`); the **provider key** must be `conversation.host_user_id`, not the session id — the provider is called at `lib/cairnloop/web/conversation_live.ex:361` with `conversation.host_user_id` as the actor. |
| FIX-02 | Seed ≥5 KB articles each with multiple revisions including ≥1 `:deprecated` revision; live `ChunkRevision` Oban worker drives embeddings through pgvector. | D-05 (`:deprecated`→`:archived`), D-06 (zero-vector fallback already exists), D-08 (`Oban.drain_queue(queue: :default, with_recursion: true)`), D-09 (mandatory facade route through `KnowledgeBase.publish_revision/1`). MarkdownParser splits on `## h2` / `### h3` headings — article bodies must include headings or they collapse to a single chunk (see Pitfall 4). |
| FIX-03 | Seed ≥3 `GapCandidate` rows with evidence linked to seeded conversations; gap queue shows ranked inspectable maintenance work. | D-13 (direct insert, no `CandidateBuilder`), D-14 (scored 0.4–0.8 with varied component counts), `GapCandidateMembership.source_type: :retrieval_gap_event`. LiveView at `lib/cairnloop/web/knowledge_base_live/gaps.ex` reads via `KnowledgeAutomation.list_gap_candidates/1` (filters `status: :open` by default, orders by `score DESC, last_seen_at DESC`). Detail view loads memberships → either real `RetrievalGapEvent` rows or it shows "No retrieval evidence linked" — see Open Question 1. |
| FIX-04 | Seed ≥1 `ArticleSuggestion` in `:ready_for_review` with citation-backed `proposed_markdown`; `SuggestionReview` LiveView shows real work. | D-15/D-16 + **critical finding:** `SuggestionReview` mount reads `KnowledgeAutomation.list_review_tasks/1` then preloads `:article_suggestion`. A seeded `ArticleSuggestion` alone is invisible — the seed must also create a `ReviewTask` (either by calling `KnowledgeAutomation.ensure_review_task_for_suggestion/2` or directly inserting `%ReviewTask{status: :pending_review}` + `%ReviewTaskEvent{event_type: :task_created}`). |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

These directives carry the same authority as CONTEXT.md locked decisions; tasks must not contradict them.

| # | Directive | Source | Enforcement |
|---|-----------|--------|-------------|
| C-01 | Decisions are made for the owner — don't surface gray-area choices; research and decide. | CLAUDE.md "Decision policy" | Planner picks message bodies, CSAT distributions, recipient emails directly; doesn't gate on operator approval. |
| C-02 | Warnings-clean builds mandatory: `mix compile --warnings-as-errors` must pass. | CLAUDE.md "Build / test conventions" | Seed script and new module must be warnings-clean. `.exs` script warnings (unused vars, deprecated APIs) caught by code review since `--warnings-as-errors` does not run scripts. |
| C-03 | Run `mix test` before declaring done; report failures honestly. | CLAUDE.md "Build / test conventions" | New `DemoContextProvider` test runs in `mix test` (headless). Seed integration test runs in example app's `mix test` (DB-backed). Library `mix test.integration` is **not** the host for the example app seed test (see Critical Finding 3 in Summary). |
| C-04 | `Cairnloop.Repo` may be unavailable in workspace — prefer headless tests. | CLAUDE.md "Build / test conventions" | Provider test is pure (no Repo). Seed integration test uses `CairnloopExample.Repo`, which is gated by the dockerized Postgres harness in the example app. |
| C-05 | Durable Ecto records + events are workflow truth; `:telemetry` is observability only. | CLAUDE.md "Architecture posture" | Phase 27 only writes durable rows. No telemetry emission added. |
| C-06 | New reads through `Cairnloop.Governance` facade, not direct schema queries from web layer. | CLAUDE.md "Architecture posture" | Not applicable — Phase 27 writes nothing to the web layer; the only library reads it indirectly triggers are via existing LiveViews (`InboxLive`, `Gaps`, `SuggestionReview`, `ConversationLive`) which already route through facades. |
| C-07 | Seal completed phases — don't churn `publish_revision/3`, idempotency, co-commit. | CLAUDE.md "Architecture posture" | Phase 27 _consumes_ `publish_revision/1` as-is. No library file is edited. |
| C-08 | Operator copy: calm, fail-closed, reason-forward; never raw Elixir terms / raw JSON. | CLAUDE.md "Architecture posture" + brand book §5/§7.5 | All seeded message bodies, KB articles, suggestion `proposed_markdown`, and ContextProvider section keys/values go through brand-voice review. Internal-note bodies (D-18 carve-out) may reference IDs. |
| C-09 | Brand tokens over hardcoded hex (`var(--cl-primary, #A94F30)`). | CLAUDE.md "Architecture posture" | Not applicable — Phase 27 emits no CSS. Brand-token CSS extraction is Phase 29. |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Ecto.Changeset / `Repo.insert!` | 3.13 (`ecto_sql ~> 3.13`) | Insert seeded rows | Standard Elixir pattern; matches existing seed file. [VERIFIED: `examples/cairnloop_example/mix.exs:50`] |
| Oban | 2.17+ | `Oban.drain_queue/1` for synchronous in-process worker run | Library already configured with `queues: [default: 10]` in the example app (`config/config.exs:54-57`). [VERIFIED: `examples/cairnloop_example/mix.exs:45`, deps/oban/lib/oban.ex:920-928] |
| `Cairnloop.KnowledgeBase` facade | (library, host-owned) | `create_article/1`, `save_draft/2`, `publish_revision/1` — the only route that enqueues `ChunkRevision` | D-09. `publish_revision/1` Multi includes `Ecto.Multi.insert(:chunk_job, Workers.ChunkRevision.new(...))` — bypass = no embeddings = FIX-02 fail. [VERIFIED: `lib/cairnloop/knowledge_base.ex:71-86`] |
| `Cairnloop.ContextProvider` behaviour | (library, host-owned) | 1-callback behaviour (`get_context/2`); tagged-tuple return | 36 LOC behaviour module + 14 LOC default impl. The new provider is ~30–50 LOC of pattern-matched per-actor returns. [VERIFIED: `lib/cairnloop/context_provider.ex`, `lib/cairnloop/default_context_provider.ex`] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Cairnloop.KnowledgeAutomation.ensure_review_task_for_suggestion/2` | (library) | Creates the `ReviewTask` + `:task_created` event that `SuggestionReview` LiveView actually reads. | After inserting the `:ready` ArticleSuggestion. Required for FIX-04 to render. [VERIFIED: `lib/cairnloop/knowledge_automation.ex:116-159`] |
| `:crypto.hash(:sha256, …) \|> Base.encode16(case: :lower)` | stdlib | Compute `evidence_digest` deterministically | Match `CandidateBuilder`'s algorithm (D-16). See "Code Examples" below. [VERIFIED: `lib/cairnloop/knowledge_automation.ex:961-976`] |
| `Jason.encode!/1` | (transitively from Phoenix) | JSON serialize evidence rows for digest computation | Required for the digest to match `CandidateBuilder`'s output shape. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Oban.drain_queue/1` at end of seed | Synchronous in-line worker invocation (`ChunkRevision.perform(%Oban.Job{args: %{"revision_id" => id}})`) | Drain mirrors production execution path exactly (job lifecycle, telemetry, retry semantics); inline invocation skips the queue/job-record lifecycle which is part of what FIX-02 is asserting. D-08 mandates drain — keep it. |
| Direct `Repo.insert!(%Revision{state: :published})` | `KnowledgeBase.publish_revision/1` facade | Bypass = no Oban enqueue = no chunks = FIX-02 fail. D-09 mandates facade. |
| `Repo.insert_all/3` for bulk seed inserts | Per-row `Repo.insert!` with `Repo.get_by` idempotency guard | `insert_all` skips changesets — would silently bypass `Message.validate_template_id_for_outbound/1`. Per-row gives validation coverage and idempotency. |
| Calling `KnowledgeAutomation.suggest_article/1` to create the ArticleSuggestion | Direct `Repo.insert!` of `%ArticleSuggestion{}` | `suggest_article/1` enqueues `Workers.GenerateArticleSuggestion` which makes an LLM call (D-15 forbids). Direct insert is required. |

### Verified Package Versions

**Ecosystem:** Elixir/Hex. The phase installs no new dependencies — all needed libraries are already in `mix.exs` (verified `examples/cairnloop_example/mix.exs:42-69` and `mix.exs:84-102`).

Confirmed versions in tree:
- `oban` 2.17+ — `mix run` starts the application by default; `Oban.drain_queue/1` available. [VERIFIED: deps/oban/lib/oban.ex:920-928]
- `ecto_sql` 3.13 — `Repo.transaction/1`, `Repo.get_by/3`, `Repo.insert!/2`. [VERIFIED: present in example app's `mix.exs:50`]
- `jason` 1.2+ — needed for `evidence_digest` computation. [VERIFIED: example `mix.exs:67`]

## Package Legitimacy Audit

> No new external packages are installed by Phase 27 — the phase consumes already-present deps only. The legitimacy audit applies only to packages this phase _introduces_. Confirmed `examples/cairnloop_example/mix.exs` deps list will not change.

| Package | Registry | Disposition |
|---------|----------|-------------|
| _(none)_ | — | No new installs — Phase 27 is fixtures + config wiring + one new module. |

## Architecture Patterns

### System Architecture Diagram

```
                       ┌─────────────────────────────────────┐
                       │  mix setup (example app, dev env)   │
                       └────────────────┬────────────────────┘
                                        │
                                        ▼
                ┌──────────────────────────────────────────────┐
                │ mix run priv/repo/seeds.exs                  │
                │   (starts Application → Oban supervisor up)  │
                └────────────────┬─────────────────────────────┘
                                 │
        ┌────────────────────────┼───────────────────────────┐
        │                        │                           │
        ▼                        ▼                           ▼
┌──────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│ build_       │    │ build_              │    │ build_              │
│ articles/0   │    │ conversations/1     │    │ gaps/1              │
│              │    │                     │    │                     │
│ KB.create_   │    │ Repo.insert!        │    │ Repo.insert!        │
│ article/1    │    │   %Conversation{}   │    │   %GapCandidate{}   │
│ + save_      │    │   %Message{}        │    │   %GapCandidate     │
│ draft/2 +    │    │   (× 16 convs,      │    │    Membership{}     │
│ publish_     │    │    3–6 msgs each,   │    │   %RetrievalGap     │
│ revision/1   │    │    4×4 JTBD)        │    │    Event{} (opt)    │
│ (× 5 arts,   │    │                     │    │   (× 3+ gaps)       │
│  some w/     │    │ FIX-01              │    │                     │
│  v1→archived │    │                     │    │ FIX-03              │
│  →v2)        │    │                     │    │                     │
│              │    └─────────────────────┘    └─────────────────────┘
│ Each publish │
│ enqueues     │
│ ChunkRevision│
│ in same Multi│
│              │
│ FIX-02 (1/2) │
└──────┬───────┘
       │
       │  ┌──────────────────────────────────────────────────────────┐
       │  │ build_suggestion_with_review_task/2                      │
       │  │                                                          │
       │  │ Repo.insert! %ArticleSuggestion{                         │
       │  │   status: :ready, suggestion_type: :article,             │
       │  │   entrypoint_type: :gap_candidate, ...                   │
       │  │ }                                                        │
       │  │ → KnowledgeAutomation.ensure_review_task_for_suggestion  │
       │  │   (creates %ReviewTask{status: :pending_review}          │
       │  │    + %ReviewTaskEvent{event_type: :task_created})        │
       │  │                                                          │
       │  │ FIX-04                                                   │
       │  └──────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│ drain_embedding_pipeline/0                   │
│                                              │
│ Oban.drain_queue(queue: :default,            │
│                  with_recursion: true)       │
│   ↓                                          │
│ ChunkRevision.perform/1                      │
│   ↓                                          │
│ MarkdownParser.parse_sections/1 (h2/h3 split)│
│   ↓                                          │
│ Embedder.ExternalApi.generate_embeddings/2   │
│   (zero-vector fallback if no API key)       │
│   ↓                                          │
│ Multi: delete_all old chunks → insert_all    │
│ new chunks into cairnloop_chunks (pgvector)  │
│                                              │
│ FIX-02 (2/2 — embeddings actually flow)      │
└──────────────────────────────────────────────┘

Separately (config-time wire):
  config :cairnloop, :context_provider, CairnloopExample.DemoContextProvider
                                 │
                                 ▼
  ConversationLive (lib/cairnloop/web/conversation_live.ex:358)
   |> Application.get_env(:cairnloop, :context_provider, DefaultContextProvider)
   |> provider.get_context(conversation.host_user_id, [])
   |> render as categorized UI sections (FIX-01 ContextProvider snippets criterion)
```

### Recommended Project Structure
```
examples/cairnloop_example/
├── config/
│   └── config.exs                            # +1 line: config :cairnloop, :context_provider, ...
├── lib/
│   └── cairnloop_example/
│       └── demo_context_provider.ex          # NEW — ~30-50 LOC implementing Cairnloop.ContextProvider
├── priv/repo/
│   └── seeds.exs                             # REWRITE — replace 49-LOC body with ~250-400 LOC seed script
└── test/
    └── cairnloop_example/
        ├── demo_context_provider_test.exs    # NEW headless test (pure)
        └── seeds_test.exs                    # NEW integration test (DB) — RECOMMENDED, not strictly required by CONTEXT.md
```

### Pattern 1: Idempotent Seed Builder via `Repo.get_by`
**What:** Each insert is guarded by a `Repo.get_by` lookup on a natural key. Re-running `mix run priv/repo/seeds.exs` is a no-op.
**When to use:** Every direct-insert seed path (conversations, messages, gap candidates, suggestion). For articles, use the title; for conversations use the `subject` prefix `[demo-NN]`; for gap candidates use `stable_key`; for the suggestion use `stable_key`.
**Example:**
```elixir
# Source: pattern derived from D-02 + standard Phoenix idempotency idiom (no external citation needed)
defp get_or_insert_conversation!(attrs) do
  case CairnloopExample.Repo.get_by(Cairnloop.Conversation, subject: attrs.subject) do
    nil ->
      %Cairnloop.Conversation{}
      |> Cairnloop.Conversation.changeset(attrs)
      |> CairnloopExample.Repo.insert!()

    existing ->
      existing
  end
end
```

### Pattern 2: KB Facade Sequence for FIX-02 Substrate Self-Test
**What:** Drive articles + revisions through the canonical facade so `publish_revision/1`'s Multi enqueues `ChunkRevision`.
**When to use:** Every seeded article. Direct `Repo.insert!` of `%Revision{}` MUST NOT be used (it bypasses the Oban enqueue).
**Example:**
```elixir
# Source: lib/cairnloop/knowledge_base.ex:65-86 (verified)
{:ok, article} = Cairnloop.KnowledgeBase.create_article(%{
  title: "Resetting your Trailmark API key",
  status: :draft
})

{:ok, draft} = Cairnloop.KnowledgeBase.save_draft(article, %{
  content: "## Reset steps\n\n1. Open settings.\n2. Click 'Rotate key'.\n## Notes\n\nKeys expire after 90 days."
})

{:ok, _published} = Cairnloop.KnowledgeBase.publish_revision(draft)
# ↑ this enqueues %Cairnloop.KnowledgeBase.Workers.ChunkRevision{} in the same Multi
```

### Pattern 3: Multi-Revision Sequence (FIX-02 ":deprecated" criterion)
**What:** Article 5 ("Rotating an expired token") progresses v1 published → v1 archived → v2 published.
**When to use:** Once, on article 5 (D-05 + D-17).
**Example:**
```elixir
# Source: D-05 + Revision.changeset enforce_immutability rule (lib/cairnloop/knowledge_base/revision.ex:23-34)
# A published revision can be re-cast to :archived (content unchanged) — immutability only blocks content edits.
{:ok, article5} = Cairnloop.KnowledgeBase.create_article(%{title: "Rotating an expired token", status: :draft})
{:ok, draft_v1} = Cairnloop.KnowledgeBase.save_draft(article5, %{content: "## Old guidance\n\nRotate every 30 days."})
{:ok, published_v1} = Cairnloop.KnowledgeBase.publish_revision(draft_v1)

# Retire v1 to :archived. Note this does NOT go through publish_revision — we change state to :archived directly.
{:ok, _archived_v1} =
  published_v1
  |> Cairnloop.KnowledgeBase.Revision.changeset(%{state: :archived})
  |> CairnloopExample.Repo.update()

{:ok, draft_v2} = Cairnloop.KnowledgeBase.save_draft(article5, %{content: "## Current guidance\n\nRotate every 90 days."})
{:ok, _published_v2} = Cairnloop.KnowledgeBase.publish_revision(draft_v2)
```

### Pattern 4: ArticleSuggestion + ReviewTask Companion Insert (FIX-04)
**What:** A seeded `ArticleSuggestion` without an accompanying `ReviewTask` is invisible in `SuggestionReview`.
**When to use:** Once, for the single seeded suggestion.
**Example:**
```elixir
# Source: lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:8-23 (reads via list_review_tasks)
#         lib/cairnloop/knowledge_automation.ex:116-159 (ensure_review_task_for_suggestion)
{:ok, suggestion} =
  %Cairnloop.KnowledgeAutomation.ArticleSuggestion{}
  |> Cairnloop.KnowledgeAutomation.ArticleSuggestion.changeset(%{
    stable_key: "demo:article_suggestion:billing_export:v1",
    suggestion_type: :article,                                    # CONTEXT.md spec language ":new_article" → actual enum :article
    status: :ready,                                               # CONTEXT.md spec language ":ready_for_review" → actual enum :ready
    tenant_scope: :host_user_scoped,
    host_user_id: "demo_operator",
    entrypoint_type: :gap_candidate,
    entrypoint_id: gap_candidate.id,
    title: "Exporting Trailmark billing receipts",
    operator_summary: "Repeated customer requests for billing export have no canonical guidance.",
    proposed_markdown: """
    ## Exporting your billing receipts

    Trailmark stores monthly receipts under Settings → Billing → Receipts [1]. \
    Each receipt is downloadable as PDF; bulk export is available via the API key flow [2].
    """,
    evidence_snapshot: [
      %{
        source_type: :knowledge_base,
        trust_level: :canonical,
        title: "Resetting your Trailmark API key",
        excerpt: "...",
        citation_target: %{article_id: api_key_article.id, revision_id: published_rev.id, chunk_index: 0},
        metadata: %{destination: %{article_id: api_key_article.id, revision_id: published_rev.id}},
        match_reasons: ["matched billing intent"]
      },
      # … one more evidence row (D-16: ≥2 evidence rows)
    ],
    grounding_metadata: %{"status" => "strong"},
    evidence_digest: compute_evidence_digest(evidence_rows),
    generated_at: DateTime.utc_now()
  })
  |> CairnloopExample.Repo.insert()

# Without this, SuggestionReview shows an empty queue — the LiveView reads from ReviewTask, not ArticleSuggestion.
{:ok, _review_task} =
  Cairnloop.KnowledgeAutomation.ensure_review_task_for_suggestion(
    suggestion.id,
    tenant_scope: :host_user_scoped, host_user_id: "demo_operator", actor_id: "system"
  )
```

### Pattern 5: DemoContextProvider Pattern-Match Shape
**What:** Pure pattern-match-per-actor function; fail-open to `{:ok, %{}}` for unknown actors.
**When to use:** The one new module under `lib/cairnloop_example/`.
**Example:**
```elixir
# Source: lib/cairnloop/context_provider.ex (behaviour) + lib/cairnloop/default_context_provider.ex (default impl shape)
defmodule CairnloopExample.DemoContextProvider do
  @moduledoc """
  Demo `Cairnloop.ContextProvider` for the example app. Returns plausible per-actor
  context for the seed-populated demo conversations; fail-opens to `{:ok, %{}}` for
  unknown actors so the operator inbox degrades gracefully.
  """
  @behaviour Cairnloop.ContextProvider

  @impl true
  def get_context("demo_user_acme_billing", _opts) do
    {:ok,
     %{
       "User Details" => %{name: "Riya Acme", email: "riya@acme.example", joined: "2025-08-14"},
       "Active Plan" => %{tier: "Team", seats: 8, status: "past due"},
       "Recent Charges" => %{last_charge_at: "2026-05-12", last_amount: "$48.00", currency: "USD"}
     }}
  end

  def get_context("demo_user_globex_seats", _opts), do: {:ok, %{ ... }}
  # ... ~5–8 demo actor branches matching seeded conversations

  def get_context(_unknown_actor, _opts), do: {:ok, %{}}
end
```

### Anti-Patterns to Avoid
- **Don't `Repo.insert!(%Revision{})` directly.** Bypasses `publish_revision/1`'s Multi and skips Oban enqueue → FIX-02 silently fails (chunks table empty, no detectable error at seed-run time).
- **Don't seed `ArticleSuggestion` without a companion `ReviewTask`.** `SuggestionReview` LiveView shows "no tasks" — FIX-04 silently fails.
- **Don't use `on_conflict: :nothing` / `:replace_all` for idempotency.** D-02 explicitly mandates `Repo.get_by` guards (clearer at code review, no PG-specific behavior surprises).
- **Don't store JTBD state in the schema.** `Conversation.status` is sealed `[:open, :resolved, :archived]`; the four JTBD cohorts are derived from `status` + `messages` ordering (D-03/D-04).
- **Don't run `Workers.GenerateArticleSuggestion` from the seed.** Makes an LLM call; will flake without `OPENAI_API_KEY` and burn tokens with one (D-15).
- **Don't run `CandidateBuilder` from the seed.** M010 substrate self-test belongs to Phase 31 (D-13).
- **Don't surface raw Elixir atoms / raw JSON in customer or operator copy.** Brand book §5/§7.5. Internal-note bodies are the only carve-out (D-18).
- **Don't write articles without `## h2` or `### h3` headings.** `MarkdownParser.parse_sections/1` splits only on h2/h3 (`lib/cairnloop/knowledge_base/markdown_parser.ex:14-32`); a heading-less paragraph produces a single chunk per article, weakening the M008 substrate self-test signal.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Synchronous in-process Oban job execution | Custom `ChunkRevision.perform(%Oban.Job{args: …})` invocation in a `for revision <- revisions, do: …` loop | `Oban.drain_queue(queue: :default, with_recursion: true)` | Drain mirrors prod execution (Job lifecycle, telemetry spans, retry, failure counts). Returns `%{success: n, failure: n, snoozed: n, cancelled: n, discard: n}` map — usable for FIX-02 assertion. [VERIFIED: deps/oban/lib/oban.ex:920-928] |
| Evidence digest hashing | Custom hash function | `:crypto.hash(:sha256, Jason.encode!(evidence_list)) \|> Base.encode16(case: :lower)` matching the exact field order used in `KnowledgeAutomation.evidence_digest_for/1` | D-16 requires "same algorithm CandidateBuilder uses". See verified algorithm in Code Examples below. |
| Sealed enum extension | Migration to add `:new`, `:awaiting_customer` to `Conversation.status`, or `:ready_for_review` to `ArticleSuggestion.status`, or `:deprecated` to `Revision.state` | Map spec language to actual enum + derive cohorts from message ordering | Cascades across vM011/vM012/vM013 surfaces. D-04, D-05, and the implicit D-15 mapping. |
| ArticleSuggestion creation | Custom Multi/changeset wrapper | Direct `Repo.insert(ArticleSuggestion.changeset(%ArticleSuggestion{}, attrs))` mirroring test fixtures `test/cairnloop/knowledge_automation/article_suggestion_test.exs:1266-1338` | The schema does the validation. The only thing _not_ to use is `KnowledgeAutomation.suggest_article/1` (it enqueues LLM worker). |
| ReviewTask creation | Custom changeset | `KnowledgeAutomation.ensure_review_task_for_suggestion/2` | Already routes through `ReviewTask.changeset` + emits `%ReviewTaskEvent{event_type: :task_created}` event row that the LiveView reads. |
| Embedder mock | New `Cairnloop.Embedder.DemoMock` module | Existing `Cairnloop.Embedder.ExternalApi` zero-vector fallback when `OPENAI_API_KEY` is absent | D-06: no new embedder stub. The fallback at `lib/cairnloop/embedder/external_api.ex:13-21` is already correct. |
| ContextProvider default | New behaviour | Existing `Cairnloop.ContextProvider` behaviour | D-10: implement, don't replace. The behaviour is 36 LOC, 1 callback. |

**Key insight:** Phase 27 is fixture-shaped; every "should I build a helper?" answer is "no — call the existing facade exactly the way production does." The phase's value is _exercising_ the substrate, not bypassing it.

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | The existing 49-LOC `seeds.exs` inserts 1 conversation (`subject: "Demo Customer Request"`, `host_user_id: "demo_user"`), 1 message, 1 article (`title: "How to reset billing"`), 1 revision. Re-run-safe idempotency must accommodate these stale rows if a dev re-seeds. | Plan a `Repo.delete_all` or pre-flight cleanup step is **NOT** required — D-02's idempotency rule says re-run is a no-op; pre-existing demo rows that don't match the new natural keys remain (harmless). Document this in PLAN.md so the executor doesn't add a delete step. |
| Live service config | The example app's Oban supervisor (`{Oban, …}` at `application.ex:15`) is the only runtime service. No external service registration to update. | None — the seed runs in-process; no API patching. |
| OS-registered state | None — example app does not register OS-level tasks, services, or daemons. | None. |
| Secrets / env vars | `OPENAI_API_KEY` referenced by `Embedder.ExternalApi` (optional; zero-vector fallback when unset). No new env var introduced by Phase 27. | None — D-06 confirms unset is the documented adopter path. |
| Build artifacts / installed packages | None — Phase 27 adds no new deps and changes no build config (esbuild/tailwind/etc). | None. |

## Common Pitfalls

### Pitfall 1: SuggestionReview's hidden dependency on ReviewTask
**What goes wrong:** Seed inserts `%ArticleSuggestion{status: :ready, …}`, but `/support/knowledge-base/suggestions` shows an empty queue. FIX-04 silently fails — there is no error at seed-run time, only at `mix setup`-then-open-browser time.
**Why it happens:** `SuggestionReview.mount/3` calls `list_review_tasks(scope_filters, queue_filter)` (line 11) — it reads from `ReviewTask`, not `ArticleSuggestion`. The two tables are linked by `ReviewTask.article_suggestion_id`.
**How to avoid:** After the suggestion insert, call `KnowledgeAutomation.ensure_review_task_for_suggestion(suggestion.id, tenant_scope: …, host_user_id: …, actor_id: "system")`. This creates the `%ReviewTask{status: :pending_review}` plus the `%ReviewTaskEvent{event_type: :task_created}` row the LiveView's "Structured history" section also reads.
**Warning signs:** SuggestionReview's `<ul>` renders empty even though `Repo.aggregate(ArticleSuggestion, :count)` returns 1.

### Pitfall 2: CONTEXT.md uses spec language for enum values that don't exist
**What goes wrong:** Planner writes a task instructing `status: :ready_for_review` or `suggestion_type: :new_article`. `Ecto.Changeset.cast/3` rejects the value as not in the schema's enum list. Hard failure at `Repo.insert!` time.
**Why it happens:** The roadmap, REQUIREMENTS.md, and CONTEXT.md D-15 use the **spec-language** names. The schema enums (verified at `lib/cairnloop/knowledge_automation/article_suggestion.ex:7-9`) are `[:pending_generation, :ready, :failed, :dismissed]` for `status` and `[:article, :revision]` for `suggestion_type`. Same as `:deprecated`→`:archived` for `Revision.state` (D-05 already maps this for revisions; D-15 forgot to apply the same mapping to suggestions).
**How to avoid:** Planner _must_ translate in PLAN.md task language: write `:ready` (NOT `:ready_for_review`) and `:article` (NOT `:new_article`). Add a short table to PLAN.md mapping spec language → actual enum values for executor reference.
**Warning signs:** Changeset error `is invalid` on `status` or `suggestion_type` fields at seed run.

### Pitfall 3: host_user_id scoping mismatch
**What goes wrong:** Seeded `GapCandidate` / `ArticleSuggestion` / `ReviewTask` rows have `tenant_scope: :host_user_scoped, host_user_id: "demo_user_acme_billing"`, but the example app's router live_session scopes to `host_user_id: "demo_operator"` (`router.ex:20`). `apply_scope/2` filters them out — the queue is empty.
**Why it happens:** Two different "host_user_id" concepts collide:
- **Operator session** identity → the `session: %{"host_user_id" => "demo_operator"}` in `router.ex:20` → flows into `scope_filters/1` in every LiveView → filters scoped rows.
- **End-user (customer) identity** → `Conversation.host_user_id` → flows into `ContextProvider.get_context/2`.
The LiveViews scope by **operator** identity for tenant isolation. Seeded GapCandidates / ArticleSuggestions / ReviewTasks must all have `host_user_id: "demo_operator"` (matching the live_session) so the example app's operator sees them. Customer-identifying `host_user_id` values (`"demo_user_acme_billing"`) belong only on `Conversation.host_user_id`, where they drive the `ContextProvider`.
**How to avoid:** Use `host_user_id: "demo_operator"` for `GapCandidate.host_user_id`, `ArticleSuggestion.host_user_id`, `ReviewTask.host_user_id`. Use distinct per-customer ids (e.g., `"demo_user_acme_billing"`) on `Conversation.host_user_id`. Document both in PLAN.md.
**Warning signs:** Inbox shows all 16 conversations (correctly — there's no scope filter on `Chat.list_conversations`), but `/support/knowledge-base/gaps` and `/support/knowledge-base/suggestions` show empty queues even though rows exist in the DB.

### Pitfall 4: KB articles without h2/h3 produce a single chunk
**What goes wrong:** Article body is a long flat paragraph. `MarkdownParser.parse_sections/1` finds no h2/h3 — returns a single chunk (chunk_index: 0). FIX-02 technically passes (chunks > 0) but the M008 substrate self-test is weakly proven.
**Why it happens:** `MarkdownParser.extract_sections/1` (lib/cairnloop/knowledge_base/markdown_parser.ex:34-55) only splits on `{"h2", …}` and `{"h3", …}` AST nodes.
**How to avoid:** Write each article with at least 2–3 `## h2` headings (e.g., "Reset steps", "Notes", "When to contact support"). Yields multi-chunk embedding for each article.
**Warning signs:** `Repo.aggregate(Cairnloop.KnowledgeBase.Chunk, :count)` returns 5 (one per article) instead of ~15+ across 5 articles.

### Pitfall 5: example app's `cairnloop_messages` table lacks the `run_key` column
**What goes wrong:** Seed inserts `%Message{run_key: nil}` via `Message.changeset/2`. The changeset casts `:run_key`, but `nil` is the schema default — works. But if a seed accidentally sets `run_key: "something"`, Postgres rejects with `column "run_key" does not exist`.
**Why it happens:** `Cairnloop.Message` schema (lib/cairnloop/message.ex:9-12) defines `:run_key` as a field. The library test_host migrations add the column (`priv/test_host/migrations/20260525000001_add_run_key_to_messages.exs`). The example app's migrations (`examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs`) DO NOT add it.
**How to avoid:** Never set `:run_key` in seed inserts. The default `nil` (cast-but-unset) is safe because Ecto will not include unchanged-from-default `nil` values in the INSERT statement for fields the changeset didn't `put_change` on. Confirm by code review.
**Warning signs:** `Postgrex.Error … column "run_key" of relation "cairnloop_messages" does not exist`.

### Pitfall 6: `:system_outbound` messages require `metadata.template_id`
**What goes wrong:** Seeding a `:resolved` conversation's last message as `role: :system_outbound` without `metadata: %{"template_id" => "..."}` raises a changeset validation error (`Message.validate_template_id_for_outbound/1`).
**Why it happens:** The Phase 22 outbound contract requires `:system_outbound` messages to carry a template snapshot. The validation runs in `Message.changeset/2` (lib/cairnloop/message.ex:26-35).
**How to avoid:** When seeding `:system_outbound` messages, always set `metadata: %{"template_id" => "demo_resolve_confirm"}` (or similar). Alternative: use `role: :agent` for the "operator confirmation" closing message of resolved conversations, sidestepping the outbound template requirement entirely. Recommendation: use `:agent` for the resolution message in most of the 4 `:resolved` conversations; reserve `:system_outbound` for 1 conversation where the outbound-bubble visual is part of the demo (D-03's "last message either `:agent` or `:system_outbound`").
**Warning signs:** Changeset error `metadata: "template_id is required for outbound messages"`.

### Pitfall 7: Oban drain in test env is a no-op (`testing: :manual`)
**What goes wrong:** Integration test for `seeds.exs` runs under `MIX_ENV=test`; `seeds.exs` calls `Oban.drain_queue/1`. In test env (`examples/cairnloop_example/config/test.exs:2`), Oban is configured `testing: :manual` — jobs go to the table but the supervisor doesn't auto-run them. `drain_queue/1` still works (it explicitly runs available jobs from the table) but the call's return shape differs subtly from prod.
**Why it happens:** Standard Oban testing-mode behavior. `Oban.drain_queue/2` is exactly the API documented for testing this scenario — it bypasses the normal supervisor and runs jobs synchronously.
**How to avoid:** No change needed — `drain_queue/1` is the correct call for both dev (auto-running queue) and test (manual). But the integration test must assert against the returned `%{success: n, …}` map, not against background job execution timing.
**Warning signs:** Test asserts on background-execution side effects (e.g. `Process.sleep`) instead of synchronous drain return value.

### Pitfall 8: Seed runs Application.start automatically — Endpoint port collisions
**What goes wrong:** `mix run priv/repo/seeds.exs` starts the Application by default. In dev, this includes `CairnloopExampleWeb.Endpoint` on port 4000. If a `mix phx.server` is already running, the seed-run collides.
**Why it happens:** Default `mix run` starts the application; the Application children include the Endpoint.
**How to avoid:** Document in the seed file header that `mix setup` must not race with a running `mix phx.server`. Alternative: `mix run --no-start priv/repo/seeds.exs` — but then Oban supervisor isn't up either, breaking the drain. The drain requirement (D-08) makes `--no-start` non-viable. Recommendation: keep default `mix run` and document the constraint inline (one-line comment).
**Warning signs:** `{:error, {:already_started, _pid}}` at seed start; or `eaddrinuse` on port 4000.

## Code Examples

Verified patterns from the existing codebase:

### Evidence digest computation (FIX-04 / D-16)
```elixir
# Source: lib/cairnloop/knowledge_automation.ex:961-976 (verified)
defp compute_evidence_digest(evidence_snapshot) do
  evidence_snapshot
  |> Enum.map(fn evidence ->
    %{
      source_type: evidence.source_type,
      trust_level: evidence.trust_level,
      title: evidence.title,
      excerpt: evidence.excerpt,
      citation_target: evidence.citation_target,
      match_reasons: evidence.match_reasons
    }
  end)
  |> Jason.encode!()
  |> then(&:crypto.hash(:sha256, &1))
  |> Base.encode16(case: :lower)
end
```

The key field ordering: `source_type, trust_level, title, excerpt, citation_target, match_reasons` (note: NOT including `metadata` — `evidence_digest_for/1` deliberately excludes it; `serialize_evidence_snapshot/1` includes it but that's used for storage, not the digest).

### GapCandidate insert with membership rows (FIX-03)
```elixir
# Source: test/cairnloop/knowledge_automation/gap_candidate_test.exs:55-77 + lib schema (verified)
{:ok, gap} =
  %Cairnloop.KnowledgeAutomation.GapCandidate{}
  |> Cairnloop.KnowledgeAutomation.GapCandidate.changeset(%{
    stable_key: "demo_gap_billing_export",
    status: :open,
    candidate_type: :mixed,
    title: "Exporting billing receipts",
    seed_excerpt: "Adopters repeatedly ask how to download multi-month receipts.",
    tenant_scope: :host_user_scoped,
    host_user_id: "demo_operator",                                  # operator scope, NOT customer
    ui_surface: :conversation,
    first_seen_at: DateTime.add(DateTime.utc_now(), -14, :day),
    last_seen_at: DateTime.add(DateTime.utc_now(), -2, :day),
    evidence_count: 3,
    manual_case_count: 2,
    weak_grounding_count: 1,
    no_hit_count: 0,
    score: 0.65,                                                    # D-14: 0.4–0.8
    score_components: %{
      "manual_handling" => 0.4,
      "weak_grounding" => 0.15,
      "freshness_boost" => 0.1
    }
  })
  |> CairnloopExample.Repo.insert()

# Membership rows link the gap to RetrievalGapEvent rows (D-14) — see Open Question 1
# for the planner's call on whether to seed real RetrievalGapEvent rows or skip the membership.
```

### Oban drain call shape (D-08)
```elixir
# Source: deps/oban/lib/oban.ex:920-928 (verified)
%{success: success, failure: failure, snoozed: snoozed, cancelled: cancelled, discard: discard} =
  Oban.drain_queue(queue: :default, with_recursion: true)

if failure > 0 do
  IO.warn("Seed embedding pipeline drained with #{failure} failures. " <>
          "Inspect oban_jobs.errors for details.")
end
```

The returned map's `:success` count should equal the number of `publish_revision/1` calls (one per article = 5+ from D-17), since each call enqueues exactly one `ChunkRevision` job.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single lonely demo conversation (`subject: "Demo Customer Request"`, 1 message, 1 article) | JTBD-spanning fixture set: 16 conversations × 4 derived states, 5 articles × multi-revision, 3+ gaps, 1 suggestion | Phase 27 (this phase) | Adopters see a real-looking dashboard on first boot instead of a stub. Closes the FIX-* milestone goals. |
| `mix setup` produces an empty `cairnloop_chunks` table (no published revisions) | `mix setup` runs `Oban.drain_queue` at end of seeds, chunks land in pgvector via live worker | Phase 27 | M008 substrate self-tests on every `mix setup`. |
| No `:context_provider` configured (falls back to `DefaultContextProvider` returning `{:ok, %{}}`) | Example app wires `CairnloopExample.DemoContextProvider` that returns per-actor demo context | Phase 27 | Operator sees Zero-Config UI categorized sections for each demo customer. |

**Deprecated/outdated:**
- The current 49-LOC `seeds.exs` is being replaced wholesale, but the file path remains `examples/cairnloop_example/priv/repo/seeds.exs` (the `ecto.setup` alias target at `mix.exs:82` is unchanged).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The spec-language enum values `:ready_for_review` (in CONTEXT.md D-15) and `:new_article` (in CONTEXT.md D-15) should map to `:ready` and `:article` respectively, by analogy with D-05's `:deprecated`→`:archived` mapping. [ASSUMED — extrapolated from D-05 pattern + verified schema enum lists in `lib/cairnloop/knowledge_automation/article_suggestion.ex:7-9`] | Pitfall 2, Pattern 4, FIX-04 row of phase_requirements | If wrong (e.g., owner intends a schema change), the planner would task a non-existent migration. **Recommend planner asks owner to ratify this mapping in PLAN.md or surface it in plan-checker review** — same shape as D-05 ratification. |
| A2 | `host_user_id: "demo_operator"` is the correct scope for seeded `GapCandidate`/`ArticleSuggestion`/`ReviewTask` rows. [VERIFIED via `examples/cairnloop_example/lib/cairnloop_example_web/router.ex:20` showing `session: %{"host_user_id" => "demo_operator"}` and `lib/cairnloop/web/knowledge_base_live/gaps.ex:142-150` showing scope_filters derivation from that session] | Pitfall 3 | Low risk — verified by direct code reading. |
| A3 | Seeded `RetrievalGapEvent` rows are NOT required for FIX-03 to pass — the gap queue's "Retrieval evidence" subsection renders "No retrieval evidence linked." when memberships have no resolvable source rows. Planner discretion per CONTEXT.md Claude's Discretion item 2. [ASSUMED — based on `lib/cairnloop/web/knowledge_base_live/gaps.ex:100-113` showing the empty-state branch + `lib/cairnloop/knowledge_automation.ex:2169-2207` showing `hydrate_memberships/1` returns `[]` for unresolvable ids] | Open Question 1 | Low risk — even with empty evidence linking, the gap queue's main `<ul>` still renders (FIX-03 passes). But the demo is more compelling with at least 1 real `RetrievalGapEvent` row linked. **Recommendation:** seed 1 real `RetrievalGapEvent` per gap so the "Retrieval evidence" sub-section renders content. |
| A4 | The seed must NOT seed `cairnloop_resolved_case_evidences` rows — they exist for `manual_handling_evidence` linkage but are not required by FIX-03's "evidence linked to seeded conversations" criterion, since `GapCandidateMembership.source_type: :retrieval_gap_event` is sufficient. [ASSUMED — based on FIX-03 wording + D-14 explicitly recommending `:retrieval_gap_event`] | FIX-03 row of phase_requirements | Low risk. If owner wants the "Similar resolved cases" sub-section populated, planner can add per-gap `ResolvedCaseEvidence` seeding as a discretionary improvement. |
| A5 | The library `mix test.integration` harness cannot host the seed-smoke test because it runs against `Cairnloop.Repo` (test_host) not `CairnloopExample.Repo`. [VERIFIED via `mix.exs:64-67` (test.setup creates `Cairnloop.Repo` + `Chimeway.Repo`) and `examples/cairnloop_example/test/test_helper.exs:2` (uses `CairnloopExample.Repo` sandbox)] | Critical Finding 3 (Summary), Validation Architecture | Low risk — verified by reading both setups. CONTEXT.md D-20 anticipated this ("if the existing harness can boot the example app's repo") — answer is no, so the planner should add the integration test in the example app's own test suite. |
| A6 | `mix run priv/repo/seeds.exs` starts the application by default (Oban supervisor up). [VERIFIED via Mix docs + Oban installation guide] | Pattern 1, Pitfall 8 | Low risk. |

**Note for the planner:** All `[ASSUMED]` items above can be auto-decided per the CLAUDE.md "shift-left" policy except A1 — which has enough plausible "owner might want a schema change" surface that a one-line ratification in PLAN.md is worth the round trip.

## Open Questions

1. **Should the seed insert real `RetrievalGapEvent` rows so `GapCandidateMembership.source_id` resolves?**
   - What we know: `GapCandidateMembership.changeset/2` requires `source_id > 0` (positive integer) but does NOT enforce referential integrity to `cairnloop_retrieval_gap_events` (no `belongs_to` association; the FK isn't enforced at the schema level). `hydrate_memberships/1` queries `GapEvent` by id-in-list and returns `[]` if no rows match. The Gap LiveView's detail view shows "No retrieval evidence linked." in that branch.
   - What's unclear: Does the owner consider an empty "Retrieval evidence" sub-section acceptable for the demo? FIX-03's wording is "evidence linked to seeded conversations" — debatable whether that requires the LiveView to render evidence or merely whether the candidate _references_ evidence.
   - Recommendation: **Seed 1 real `RetrievalGapEvent` row per `GapCandidate`** (3 events total). They're inexpensive (one schema, no Multi, no worker) and make the demo render fully. Use `RetrievalGapEvent.changeset/2` with `surface: :search_modal, outcome_class: :empty_recall, reason: :no_canonical_results, query_fingerprint: <sha256>, sanitized_query_excerpt: "…"`. Reference `conversation_id` indirectly via `RetrievalGapEvent.attempted_evidence_snapshots` if needed (an embed, not an FK).

2. **Should the seed insert a `ResolvedCaseEvidence` row for the "Similar resolved cases" subsection?**
   - What we know: Without these rows, the gap detail's "Similar resolved cases" section renders "No repeated manual-handling evidence linked."
   - What's unclear: D-14 specifies `source_type: :retrieval_gap_event` for memberships — implying `manual_handling_case` isn't required.
   - Recommendation: **Skip for Phase 27.** The "Similar resolved cases" empty state is calm and reason-forward in its own right. Add this in a future phase if adopter feedback requests it.

3. **Should the seed-smoke integration test run against `CairnloopExample.Repo` (in the example app's test suite) or against `Cairnloop.Repo` (in the library's test.integration suite via test_host migrations)?**
   - What we know: The example app and library have separate repos with separate sandbox modes and separate config (Oban is `testing: :manual` in the example app's `MIX_ENV=test`).
   - What's unclear: CONTEXT.md D-20 explicitly invites the planner to pick.
   - Recommendation: **Add to `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` using `CairnloopExample.DataCase`.** Reasons: (1) the seed is example-app-owned; (2) the library's test.integration harness doesn't migrate `CairnloopExample.Repo`; (3) shipping the test in the example app proves the same path adopters walk works end-to-end.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | All Cairnloop code | ✓ (presumed; project repo) | `~> 1.19` per `mix.exs:8` | — |
| PostgreSQL 15+ with pgvector | `cairnloop_chunks` table; FIX-02 | Available via dockerized harness used by `mix test.integration` (port 5433); also available locally if adopter runs `mix setup` | Adopter's choice | None — FIX-02 fundamentally requires pgvector. Documented in example app README. |
| Oban (already a dep) | D-08 drain at end of seeds | ✓ — already in `examples/cairnloop_example/mix.exs:45` | `~> 2.17` | — |
| Jason (already a dep) | Evidence digest JSON encoding | ✓ — already in `examples/cairnloop_example/mix.exs:67` | `~> 1.2` | — |
| `OPENAI_API_KEY` env var | Real OpenAI embeddings | Optional | — | Zero-vector fallback in `ExternalApi.generate_embeddings/2` (D-06; lib:13-21). Seed comment will document the trade-off. |
| Docker (for `mix test.integration`'s Postgres harness) | The optional integration test | Adopter's machine | — | If Docker not available, the integration test can be skipped via `@tag :requires_docker` exclusion. The seed itself doesn't require Docker. |

**Missing dependencies with no fallback:** None — every required runtime is already in the dep tree.

**Missing dependencies with fallback:** `OPENAI_API_KEY` (zero-vector embeddings).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir stdlib) |
| Config files | `mix.exs` (library) + `examples/cairnloop_example/mix.exs` (example app) — each owns its own `test` alias |
| Quick run command (headless, library) | `mix test test/cairnloop/context_provider_test.exs` (this is the pattern; Phase 27's new headless test lives in the example app, see below) |
| Quick run command (headless, example app) | `cd examples/cairnloop_example && mix test test/cairnloop_example/demo_context_provider_test.exs` |
| Quick run command (integration, example app, DB-backed) | `cd examples/cairnloop_example && mix test test/cairnloop_example/seeds_test.exs` (requires Postgres on `localhost:5433` with `cairnloop_example_test` DB) |
| Full headless suite (library) | `mix test` |
| Full integration suite (library) | `mix test.integration` |
| Full suite (example app) | `cd examples/cairnloop_example && mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FIX-01 (seed conversations) | Seed produces 16 conversations across 4 JTBD-derived cohorts | integration (DB) | `cd examples/cairnloop_example && mix test test/cairnloop_example/seeds_test.exs` | ❌ Wave 0 — must be created |
| FIX-01 (ContextProvider snippets) | `DemoContextProvider.get_context/2` returns documented shape for known + unknown actors | unit (pure, headless) | `cd examples/cairnloop_example && mix test test/cairnloop_example/demo_context_provider_test.exs` | ❌ Wave 0 — must be created |
| FIX-02 (≥5 articles, multi-revision, ≥1 archived) | Seed produces ≥5 articles, ≥6 revisions, ≥1 with state `:archived` | integration (DB) | (same `seeds_test.exs` as above) | ❌ Wave 0 |
| FIX-02 (Oban-driven embeddings) | After `Oban.drain_queue/1`, `cairnloop_chunks` table is non-empty | integration (DB) | (same `seeds_test.exs`) | ❌ Wave 0 |
| FIX-03 (≥3 GapCandidates) | Seed produces ≥3 `GapCandidate` rows with `status: :open` and 1+ memberships each | integration (DB) | (same `seeds_test.exs`) | ❌ Wave 0 |
| FIX-04 (≥1 ArticleSuggestion `:ready` + ReviewTask) | Seed produces 1 `ArticleSuggestion` with `status: :ready`, with companion `ReviewTask{status: :pending_review}` and `:task_created` event | integration (DB) | (same `seeds_test.exs`) | ❌ Wave 0 |
| Brand voice (CLAUDE.md C-08) | Seeded text contains no raw Elixir atoms or raw JSON in customer/operator-visible copy | manual-only (executor self-review against `prompts/cairnloop_brand_book.md` §5.5/§7.5) | (no automated command — code review during executor's plan) | n/a |
| Warnings-clean seed script (D-21) | `.exs` script emits no compiler warnings | manual-only (executor must visually scan compile output) | `cd examples/cairnloop_example && mix run --no-start priv/repo/seeds.exs` (start-less compile-check; will fail on real DB ops but flags syntax/warning issues first) | n/a |
| Idempotency (D-02) | Running seeds twice is a no-op (no errors, no duplicate row counts) | integration (DB) | (extend `seeds_test.exs` with `for _ <- 1..2, do: Code.eval_file("priv/repo/seeds.exs")` then assert row count stability) | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `cd examples/cairnloop_example && mix test test/cairnloop_example/demo_context_provider_test.exs` (headless, < 1 sec)
- **Per wave merge:** `cd examples/cairnloop_example && mix test` (includes both the headless test and the seeds integration test, ~10–30 sec with Postgres available)
- **Phase gate:** Full suite green: `mix test` (library) + `mix test.integration` (library, with dockerized Postgres) + `cd examples/cairnloop_example && mix test`. Also: manual run of `cd examples/cairnloop_example && mix setup` (or `mix ecto.reset`) to confirm the dashboard renders correctly in a browser — this is the FIX-01..FIX-04 final-visual check that no automated test can fully replace.

### Wave 0 Gaps
- [ ] `examples/cairnloop_example/test/cairnloop_example/demo_context_provider_test.exs` — pure headless test for `DemoContextProvider.get_context/2` (covers FIX-01 ContextProvider snippets)
- [ ] `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` — DB-backed test running the seed and asserting row counts hit FIX-* thresholds (covers FIX-01, FIX-02, FIX-03, FIX-04 row-count + chunk-presence assertions)
- No additional framework install: ExUnit is already available; `CairnloopExample.DataCase` already exists at `examples/cairnloop_example/test/support/data_case.ex`
- The seeds integration test will need to programmatically run the seed script — use `Code.eval_file/1` or invoke each builder function directly. Recommendation: refactor `seeds.exs` so its body is a thin call to a module function (`CairnloopExample.SeedDemo.run/0` — defined in `test/support/` for `MIX_ENV=test` and re-defined inline in `seeds.exs` for dev), enabling testable seed logic without subprocess invocation. **OR (simpler):** call `Code.eval_file("priv/repo/seeds.exs")` from the test (works because the test owns the sandboxed DB connection).

## Security Domain

Phase 27 introduces no new authentication, session, or input surfaces — it's fixture data + a pattern-matched function. The only categories with relevance:

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth surfaces touched |
| V3 Session Management | no | No session surfaces touched |
| V4 Access Control | partial | Existing `tenant_scope`/`host_user_id` scope filtering (`apply_scope/2`) governs visibility of seeded rows. Phase 27 must seed `host_user_scoped` rows with `host_user_id: "demo_operator"` so the operator (logged in via `session: %{"host_user_id" => "demo_operator"}`) sees them. See Pitfall 3. |
| V5 Input Validation | yes (light) | `DemoContextProvider.get_context/2` accepts an arbitrary `actor_id :: String.t()` from a host system. It uses pattern matching (fail-open to `{:ok, %{}}` for unknown) — no string interpolation into queries, no eval, no atom creation. Safe by construction. |
| V6 Cryptography | yes (light) | `evidence_digest` uses `:crypto.hash(:sha256, …)` — Erlang's standard crypto module. Not used for authentication, only deterministic identity. No hand-rolled crypto. |
| V14 Configuration | yes | `config :cairnloop, :context_provider, CairnloopExample.DemoContextProvider` is example-app-only (correctly scoped). Library config should not change. |

### Known Threat Patterns for Elixir/Phoenix Seed Scripts

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Demo data leaking into production deploys | Information Disclosure | The seed is scoped to `examples/cairnloop_example/priv/repo/seeds.exs` — not in the published Hex package. The library's `package.files` in `mix.exs:17-25` doesn't include `examples/`. Verified safe. |
| ContextProvider returning sensitive host data over an unscoped actor lookup | Information Disclosure | `DemoContextProvider` only returns hard-coded literal data for known demo actors; fail-opens to `{:ok, %{}}` for unknown — no host-system query. Safe by construction. |
| Seed-time DB destruction (accidentally re-running `Repo.delete_all` against prod) | Tampering | D-02 idempotency uses `Repo.get_by` guards, NOT `delete_all`. Re-run is safe. |

## Sources

### Primary (HIGH confidence)
- `.planning/phases/27-realistic-demo-fixtures/27-CONTEXT.md` — 21 ratified decisions
- `.planning/REQUIREMENTS.md` lines 18–21 — FIX-01..FIX-04 acceptance language
- `.planning/ROADMAP.md` Phase 27 block — goal, success criteria, dependency-order rationale
- `.planning/PROJECT.md` — vM014 brief, architectural invariants
- `CLAUDE.md` — repo-level shift-left, build/test conventions
- `lib/cairnloop/knowledge_base.ex` — facade (`create_article/1`, `save_draft/2`, `publish_revision/1`)
- `lib/cairnloop/knowledge_base/workers/chunk_revision.ex` — the worker the M008 self-test drives
- `lib/cairnloop/knowledge_base/markdown_parser.ex` — h2/h3 chunk extraction
- `lib/cairnloop/embedder/external_api.ex` — zero-vector fallback (lines 13–21)
- `lib/cairnloop/context_provider.ex` + `lib/cairnloop/default_context_provider.ex` — behaviour + default impl
- `lib/cairnloop/conversation.ex`, `lib/cairnloop/message.ex`, `lib/cairnloop/knowledge_base/article.ex`, `lib/cairnloop/knowledge_base/revision.ex` — sealed enums (all verified by direct read)
- `lib/cairnloop/knowledge_automation/gap_candidate.ex`, `gap_candidate_membership.ex`, `article_suggestion.ex`, `article_suggestion_evidence.ex`, `review_task.ex` — schemas for direct-insert paths
- `lib/cairnloop/knowledge_automation.ex` — `evidence_digest_for/1` (lines 961–976), `ensure_review_task_for_suggestion/2` (lines 116–159), `list_gap_candidates/1` (line 40), `list_review_tasks/1` (line 80), `hydrate_memberships/1` (line 2169), `apply_scope/2` (line 1940), `reviewable_for_review_task?/1` (line 1380)
- `lib/cairnloop/web/knowledge_base_live/suggestion_review.ex` — verified `ReviewTask`-not-`ArticleSuggestion` data source
- `lib/cairnloop/web/knowledge_base_live/gaps.ex` — verified field rendering + empty-state copy
- `lib/cairnloop/web/conversation_live.ex` line 358 — verified ContextProvider lookup site
- `lib/cairnloop/web/inbox_live.ex` line 93 + `lib/cairnloop/chat.ex` line 10 — verified Chat.list_conversations is unscoped
- `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` line 20 — verified `session: %{"host_user_id" => "demo_operator"}`
- `examples/cairnloop_example/lib/cairnloop_example/application.ex` line 15 — verified Oban supervisor child
- `examples/cairnloop_example/config/config.exs` lines 54–61 — verified Oban + cairnloop config slot
- `examples/cairnloop_example/config/test.exs` line 2 — verified `testing: :manual`
- `examples/cairnloop_example/mix.exs` lines 80–94 — verified setup/test aliases
- `examples/cairnloop_example/priv/repo/migrations/20260525201622_create_cairnloop_tables.exs` — verified `cairnloop_messages` column set (no `run_key`)
- `deps/oban/lib/oban.ex` lines 840–928 — `drain_queue/1` contract
- `test/support/fixtures.ex` lines 12–88 — confirmed `Repo.insert!` direct pattern for conversations/messages
- `test/cairnloop/context_provider_test.exs` — pattern for the new headless test
- `test/cairnloop/knowledge_automation/article_suggestion_test.exs` lines 1266–1338 — verified `ArticleSuggestion` attrs shape

### Secondary (MEDIUM confidence)
- `prompts/cairnloop_brand_book.md` §5 (voice and tone), §5.5 (UX microcopy), §7.5 (accessibility / state-by-color) — operator copy constraints
- Mix docs (`mix run` starts app by default; `--no-start` flag) — verified via WebFetch

### Tertiary (LOW confidence)
- None — all critical claims verified against code or first-party docs.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every component verified against code in this tree
- Architecture (responsibility map + diagram + patterns): HIGH — derived from direct code reading
- Pitfalls: HIGH — all eight pitfalls are derivable from code-verified contracts (changeset validations, sealed enum lists, scope filter semantics)
- Validation Architecture: HIGH — example app's test infrastructure verified by direct read
- Security Domain: HIGH — no new auth/session/input surfaces; ASVS scope correctly narrow
- Assumption A1 (spec-language enum mapping): MEDIUM — extrapolated from D-05 pattern; recommend planner ratify in PLAN.md

**Research date:** 2026-05-27
**Valid until:** 2026-06-27 (30 days; phase scope is stable; the only thing that could invalidate this research is a library-side enum change to `ArticleSuggestion` / `Revision` / `Conversation`, which is sealed-contract-forbidden in vM014)
