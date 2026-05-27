---
phase: 27-realistic-demo-fixtures
verified: 2026-05-27T17:18:57Z
status: human_needed
score: 4/4 must-haves verified (technical); 1 manual visual confirmation pending
overrides_applied: 0
re_verification:
  previous_status: none
  previous_score: n/a
  gaps_closed: []
  gaps_remaining: []
  regressions: []
requirements_coverage:
  - id: FIX-01
    source_plans: [27-01, 27-02, 27-04]
    status: SATISFIED (pending visual)
    evidence: |
      seeds.exs @demo_conversations defines exactly 16 rows across 4 JTBD cohorts
      (lines 352-403); CairnloopExample.DemoContextProvider implements
      Cairnloop.ContextProvider for the 5 demo customer host_user_ids referenced
      by those conversations; config.exs:62 wires :cairnloop, :context_provider,
      CairnloopExample.DemoContextProvider; conversation_live.ex:358 reads that
      key. Flip to Done after the manual mix-setup browser sweep confirms the
      inbox renders the 16 rows and ContextProvider snippets surface.
  - id: FIX-02
    source_plans: [27-01, 27-03, 27-07]
    status: SATISFIED (pending visual)
    evidence: |
      seeds.exs build_articles/0 inserts 5 Trailmark articles via the
      KnowledgeBase facade (save_draft/publish_revision); article 5
      ("Rotating an expired token") runs v1-published -> v1-archived -> v2-published
      yielding >=1 :archived revision (D-05 mapping of spec ':deprecated').
      drain_embedding_pipeline/0 calls
      Oban.drain_queue(queue: :default, with_recursion: true) at end-of-script,
      synchronously running the ChunkRevision worker so cairnloop_chunks is
      populated via the live M008 substrate path (FIX-02 substrate self-test).
      Test seeds_test.exs Test 2 asserts chunks > 0 after drain. Flip to Done
      after the manual mix-setup sweep confirms KB Index renders 5 articles
      with a multi-revision tab.
  - id: FIX-03
    source_plans: [27-05]
    status: SATISFIED (pending visual)
    evidence: |
      seeds.exs @demo_gaps defines exactly 3 GapCandidate specs
      (demo_gap_billing_export, demo_gap_ci_skip_diagnostics,
      demo_gap_team_seat_governance) with status :open, candidate_type :mixed,
      scores in 0.45-0.65 (within 0.4-0.8 band), evidence_count 2..4,
      manual_case_count + weak_grounding_count non-zero, first_seen/last_seen
      distributed across past 14 days, and host_user_id "demo_operator"
      (Pitfall 3 operator-scope). Each gap is paired with 1 seeded
      RetrievalGapEvent + 1 GapCandidateMembership pointing at it. Flip to Done
      after the manual mix-setup sweep confirms /support/knowledge-base/gaps
      renders 3 inspectable gaps.
  - id: FIX-04
    source_plans: [27-06]
    status: SATISFIED (pending visual)
    evidence: |
      seeds.exs build_suggestion/2 inserts exactly 1 ArticleSuggestion with
      status :ready (D-15 sealed-enum mapping of spec :ready_for_review),
      suggestion_type :article (mapping of spec :new_article),
      entrypoint_type :gap_candidate pointing at demo_gap_billing_export,
      host_user_id "demo_operator" (Pitfall 3 operator-scope), brand-voiced
      proposed_markdown with [1]/[2] anchors, and 2 ArticleSuggestionEvidence
      rows whose citation_target references a real published revision of the
      api_key article (chunk_index 0 and 1). Critically,
      KnowledgeAutomation.ensure_review_task_for_suggestion/2 is invoked
      after the insert, creating the companion ReviewTask that
      SuggestionReview LiveView actually queries (Critical Finding 2 /
      Pitfall 1 honored). Flip to Done after the manual mix-setup sweep
      confirms /support/knowledge-base/suggestions renders the suggestion.
roadmap_truths_status:
  - "SC1: 12-16 conversations across 4 JTBD cohorts with ContextProvider snippets — VERIFIED structurally; awaiting visual confirmation"
  - "SC2: >=5 KB articles, multiple revisions including >=1 :deprecated, live ChunkRevision -> pgvector self-test — VERIFIED structurally; awaiting visual confirmation"
  - "SC3: >=3 GapCandidates with evidence in the ranked maintenance queue — VERIFIED structurally; awaiting visual confirmation"
  - "SC4: >=1 ArticleSuggestion :ready_for_review with citation-backed proposed_markdown in SuggestionReview — VERIFIED structurally; awaiting visual confirmation"
gaps: []
deferred: []
human_verification:
  - test: "Adopter-visible dashboard on first boot"
    expected: |
      After `cd examples/cairnloop_example && mix setup` (or `mix ecto.reset`)
      + `mix phx.server` + opening `/support`, the operator sees:
        - inbox with 12+ conversations distributed across :new / :open /
          :awaiting_customer / :resolved cohorts (4 each, 16 total) with
          ContextProvider snippets rendering customer details for each of the
          5 demo customer identities;
        - KB Index showing 5 articles, including a multi-revision tab on
          "Rotating an expired token" with a :archived v1 + :published v2;
        - cmd+k search returning lex-ordered hits for article titles
          (zero-vector mode without OPENAI_API_KEY);
        - /support/knowledge-base/gaps showing 3 inspectable gap candidates
          with scored evidence snippets;
        - /support/knowledge-base/suggestions showing 1 :ready_for_review
          ArticleSuggestion with citation chips for [1]/[2].
    why_human: |
      This is the FIX-01..FIX-04 acceptance check the ROADMAP success criteria
      were written for. Each row count is automated; the dashboard rendering,
      brand-voice tone of customer/operator copy, and visual coherence are
      editorial and not deterministically testable. CLAUDE.md baseline
      REPO-UNAVAILABLE on this workstation also blocks executing the
      DB-backed seeds_test.exs locally — the developer needs to run the
      manual sweep after the next time they boot Postgres on localhost:5433
      (or pull from CI where the integration test is green).
  - test: "Brand voice on seeded copy (subjects + message bodies + article paragraphs + suggestion proposed_markdown)"
    expected: |
      Every seeded subject, customer message, operator reply, internal note,
      article paragraph, and the proposed_markdown for the seeded suggestion
      reads as calm, fail-closed, reason-forward, and honest (per
      prompts/cairnloop_brand_book.md sections 5.5 and 7.5). No raw Elixir
      atoms or raw JSON surface in any operator- or customer-facing string.
    why_human: |
      Tone-of-voice is editorial; no automated check can pin it. The
      executor reported self-reviewing each body against the brand book, but
      a fresh human read is the final validation. Spot-check at least 3
      conversations per cohort + all 5 articles + the 1 suggestion.
overrides: []
---

# Phase 27: Realistic Demo Fixtures — Verification Report

**Phase Goal (ROADMAP.md):** An adopter who runs `mix setup` in the example app
lands in a populated dashboard that already exercises every Jobs-To-Be-Done
state — the example self-tests the M008 retrieval substrate on first boot
rather than greeting them with one lonely conversation.

**Verified:** 2026-05-27T17:18:57Z
**Status:** human_needed (technical must-haves verified; visual UI sweep + brand-voice spot-check require a human)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth (from ROADMAP success criteria + FIX-01..FIX-04) | Status | Evidence |
|---|--------------------------------------------------------|--------|----------|
| 1 | seeds.exs produces 12–16 conversations distributed across `:new`, `:open`, `:awaiting_customer`, `:resolved` cohorts with realistic operator + customer messages and ContextProvider snippets, replacing the previous 1-conversation lonely demo (FIX-01, SC1) | VERIFIED (structural) — pending visual | `priv/repo/seeds.exs:352-403` `@demo_conversations` enumerates exactly 16 rows: 4 each across the 4 cohorts (cohort key set on every row). `seed_conversation_row/2` (line 415) inserts each idempotently with subject prefix `"[demo-NN] …"`. `build_message_list/1` (lines 485-542) generates 2–5 messages per cohort with cohort-correct role ordering — `:new` ends in `:user` with zero `:agent` messages, `:open` ends in `:user` after an `:agent` reply, `:awaiting_customer` ends in `:agent`, `:resolved` carries `resolved_at` + closes with `:agent` or `:system_outbound`. The `n=16` resolved conversation closes via `:system_outbound` carrying `metadata.template_id: "demo_resolve_confirm"` (Pitfall 6 honored, line 521). `host_user_id` values across the 16 rows are the 5 demo identities the `DemoContextProvider` knows about, so `Application.get_env(:cairnloop, :context_provider, …)` lookup in `lib/cairnloop/web/conversation_live.ex:358` resolves to a real per-actor map. |
| 2 | KB Index shows ≥5 articles, each with multiple revisions including ≥1 `:deprecated` revision, and embeddings flow through the live `ChunkRevision` Oban worker into pgvector (M008 substrate self-test) (FIX-02, SC2) | VERIFIED (structural) — pending visual | `build_articles/0` (`priv/repo/seeds.exs:119-335`) inserts the 5 Trailmark articles ("Resetting your Trailmark API key", "Updating your billing email", "Adding a team seat", "Why a CI run was skipped", "Rotating an expired token") via the `KnowledgeBase.save_draft/2` + `KnowledgeBase.publish_revision/1` facade — the only path that enqueues `ChunkRevision` in the same Multi (D-09 honored). Article 5 runs `v1 -> :published -> :archived` then `v2 -> :published` (lines 295-323), so >=1 archived revision exists (D-05 mapping of spec `:deprecated`). `drain_embedding_pipeline/0` (lines 1219-1234) synchronously calls `Oban.drain_queue(queue: :default, with_recursion: true)` after all builders run — this is what makes FIX-02 a substrate self-test rather than a fixture shortcut. The example app's `:default` Oban queue is configured at `config/config.exs:54-57`. Without `OPENAI_API_KEY`, `Embedder.ExternalApi.generate_embeddings/2` returns 1536-dim zero vectors (D-06), still populating `cairnloop_chunks` via the live worker. |
| 3 | KB gap queue shows ≥3 `GapCandidate` rows with evidence linked to seeded conversations, inspectable in the ranked maintenance queue (FIX-03, SC3) | VERIFIED (structural) — pending visual | `@demo_gaps` (`priv/repo/seeds.exs:826-886`) defines exactly 3 specs (`demo_gap_billing_export`, `demo_gap_ci_skip_diagnostics`, `demo_gap_team_seat_governance`). `seed_gap_with_evidence/1` (line 908) inserts each `GapCandidate` with `status: :open`, `candidate_type: :mixed`, scores in 0.45–0.65 (D-14 band 0.4–0.8), evidence_count 2..4, manual_case_count and weak_grounding_count both non-zero, and `host_user_id: "demo_operator"` (Pitfall 3 operator-scope). Each is paired with 1 seeded `RetrievalGapEvent` (`get_or_insert_gap_event!/2`, line 945) keyed on a deterministic sha256 fingerprint, and 1 `GapCandidateMembership` (`upsert_membership!/2`, line 980) linking the gap to the event with `source_type: :retrieval_gap_event`. Conversation linkage is topical (each gap's `sanitized_query_excerpt` aligns with a seeded conversation cohort topic per D-19) rather than via a hard FK — `GapCandidate.evidence_count` and `score_components` carry the inspectable detail the gap-queue LiveView renders. |
| 4 | `SuggestionReview` LiveView shows ≥1 `ArticleSuggestion` in `:ready_for_review` state with citation-backed `proposed_markdown` (FIX-04, SC4) | VERIFIED (structural) — pending visual | `build_suggestion/2` (`priv/repo/seeds.exs:1028-1188`) inserts exactly 1 `%ArticleSuggestion{}` with `status: :ready` (sealed-enum mapping of spec `:ready_for_review` per D-15 + PATTERNS table), `suggestion_type: :article` (mapping of spec `:new_article`), `entrypoint_type: :gap_candidate` pointing at the real seeded `demo_gap_billing_export` row, `tenant_scope: :host_user_scoped`, `host_user_id: "demo_operator"` (Pitfall 3), brand-voiced `proposed_markdown` containing both `[1]` and `[2]` footnote anchors (line 1116), and 2 `ArticleSuggestionEvidence` rows in `evidence_snapshot` whose `citation_target` references a real `:published` revision of the api_key article (`chunk_index: 0` and `chunk_index: 1`). `evidence_digest` is computed deterministically (line 1149, `compute_evidence_digest/1` mirrors the production algorithm). **Critically**, `KnowledgeAutomation.ensure_review_task_for_suggestion/2` is invoked at line 1182 after the suggestion insert — this creates the companion `ReviewTask` that the `SuggestionReview` LiveView actually queries (`list_review_tasks/1`, not `list_article_suggestions/1`); RESEARCH §Critical Finding 2 / Pitfall 1 is honored. |

**Score:** 4/4 truths verified structurally. All 4 success criteria additionally carry a final visual / brand-voice gate that no automated check can replace.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `examples/cairnloop_example/priv/repo/seeds.exs` | Replaces the 49-LOC lonely demo with a JTBD-spanning fixture set: 5 builders + idempotency helper + Oban drain | VERIFIED | 1272-line single-module script (`CairnloopExample.SeedRun`); all 5 builders present (`build_articles/0`, `build_conversations/1`, `build_gaps/1`, `build_suggestion/2`, `drain_embedding_pipeline/0`); `get_or_insert!/3` helper at line 1258; sealed-enum reconciliation table in header at lines 41-52; final `CairnloopExample.SeedRun.run()` invocation at line 1271. |
| `examples/cairnloop_example/lib/cairnloop_example/demo_context_provider.ex` | `Cairnloop.ContextProvider` impl returning per-actor maps for the 5 demo customer ids; fail-open `{:ok, %{}}` for unknown | VERIFIED | 136-line module; `@behaviour Cairnloop.ContextProvider`; 5 pattern-matched clauses (acme_billing, globex_seats, initech_billing, umbrella_ci, hooli_tokens) each returning 3 categorized sections with string keys; catch-all `get_context(_actor_id, _opts)` returns `{:ok, %{}}` (line 132). No DB queries, no atom-from-input creation. |
| `examples/cairnloop_example/config/config.exs` | Wires `:cairnloop, :context_provider, CairnloopExample.DemoContextProvider` | VERIFIED | Line 62 adds `context_provider: CairnloopExample.DemoContextProvider` inside the existing `config :cairnloop, …` keyword list block (no duplicate-key collision). |
| `examples/cairnloop_example/test/cairnloop_example/demo_context_provider_test.exs` | Headless test asserting documented shape for known + unknown actors | VERIFIED | 58-line ExUnit test file with `async: true`, 5 known actors enumerated, 5 test cases covering shape, 2+ sections per actor, fail-open for unknown, string section keys, simple-term values. Pure (no Repo). Note: cannot be invoked locally because the example app's `mix test` alias requires `ecto.create` against the unavailable Postgres — the test code itself is correct. |
| `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` | DB-backed integration test pinning FIX-01..FIX-04 row counts + Oban drain + idempotency | VERIFIED (structurally; cannot execute) | 203-line `CairnloopExample.DataCase`-based test, `async: false`, `@moduletag :requires_postgres`. 4 test cases: row counts (FIX-01..FIX-04 thresholds), Oban drain populates chunks, ReviewTask companion exists with `:pending_review`, idempotency (counts stable across 2 runs). Tagged for the `mix test --exclude requires_postgres` skip gate. Cannot run here per CLAUDE.md REPO-UNAVAILABLE caveat. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `priv/repo/seeds.exs` (`KnowledgeBase` facade calls) | `Workers.ChunkRevision` Oban worker | `KnowledgeBase.publish_revision/1` enqueues `ChunkRevision` in the same Multi; `Oban.drain_queue/1` in `drain_embedding_pipeline/0` executes it synchronously | WIRED | `build_articles/0` calls `KnowledgeBase.publish_revision/1` once per article (5 articles + 1 v2 republish on article 5 = ≥6 enqueues); `drain_embedding_pipeline/0` (line 1219) executes them via `Oban.drain_queue(queue: :default, with_recursion: true)`. Library facade at `lib/cairnloop/knowledge_base.ex` confirmed to use the Multi-enqueue pattern. |
| `priv/repo/seeds.exs` (`build_suggestion/2`) | `SuggestionReview` LiveView (`list_review_tasks/1`) | `KnowledgeAutomation.ensure_review_task_for_suggestion/2` inserts the companion `ReviewTask + ReviewTaskEvent` so the LiveView's reader returns the row | WIRED | Line 1181-1185 — called with `actor_id: "system"`; tenant_scope/host_user_id read from the loaded suggestion automatically; idempotent on re-run. seeds_test.exs Test 3 (line 139-163) asserts the ReviewTask exists with `status: :pending_review` for the seeded suggestion's `stable_key`. |
| `config :cairnloop, :context_provider, CairnloopExample.DemoContextProvider` (config.exs:62) | `Cairnloop.ContextProvider`-using inbox renderer | `Application.get_env(:cairnloop, :context_provider, Cairnloop.DefaultContextProvider)` at `lib/cairnloop/web/conversation_live.ex:358` | WIRED | Adapter pattern; the library reads the configured provider at render time and invokes `get_context/2` per conversation actor. 5 seeded conversations' `host_user_id` values map to 5 known clauses in `DemoContextProvider`; remaining conversations also use the same 5 ids (re-used across cohorts so all 16 conversations hit a known provider clause). |
| `priv/repo/seeds.exs` (`build_gaps/1`) | `KnowledgeBase.Gaps` LiveView | Direct `Repo.insert!` of `GapCandidate + GapCandidateMembership + RetrievalGapEvent` rows that the LiveView reads via its own scoped query | WIRED | D-13 (direct-insert path, not `CandidateBuilder`) honored; rows carry `host_user_id: "demo_operator"` to match the operator-scope the LiveView filters on (Pitfall 3). |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `seeds.exs::build_articles/0` | `articles` map (5 articles) | direct `Repo.insert!` + `KnowledgeBase.save_draft/2` + `KnowledgeBase.publish_revision/1` (real Multi inserts) | Yes — populates `cairnloop_articles`, `cairnloop_revisions`, enqueues `ChunkRevision` jobs, ultimately writes `cairnloop_chunks` on drain | FLOWING |
| `seeds.exs::build_conversations/1` | 16 `%Conversation{}` rows + 48–58 `%Message{}` rows | direct `Repo.insert!` via `Conversation.changeset/2` and `Message.changeset/2` | Yes — populates `cairnloop_conversations` + `cairnloop_messages` with realistic bodies | FLOWING |
| `seeds.exs::build_gaps/1` | 3 `%GapCandidate{}` + 3 `%RetrievalGapEvent{}` + 3 `%GapCandidateMembership{}` rows | direct `Repo.insert!` via per-schema changesets | Yes — populates the 3 gap tables; gap-queue LiveView's operator-scope filter matches `host_user_id: "demo_operator"` | FLOWING |
| `seeds.exs::build_suggestion/2` | 1 `%ArticleSuggestion{}` + 1 `%ReviewTask{}` (via facade) | direct `Repo.insert!` for the suggestion + `KnowledgeAutomation.ensure_review_task_for_suggestion/2` for the ReviewTask | Yes — the suggestion has `status: :ready`, 2 evidence rows with real `citation_target` to a real `:published` revision; the ReviewTask is `status: :pending_review` and is what `SuggestionReview` LiveView queries | FLOWING |
| `DemoContextProvider.get_context/2` | per-actor `ctx` map | hardcoded literals matched on `host_user_id` string | Yes — 3 sections per known actor with plausible string/integer values; `{:ok, %{}}` for unknown | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Example app compiles warnings-clean (D-21 + CLAUDE.md mandate) | `cd examples/cairnloop_example && mix compile --warnings-as-errors` | exit 0 (no warnings, no errors) | PASS |
| Seed script body is syntactically valid (would-compile check) | implicit — `mix compile --warnings-as-errors` exit 0 also requires the lib path to compile cleanly; the script itself only fails on runtime Repo access | covered by the compile check; `seeds.exs` is loaded by `Code.eval_file/1` in tests + by `mix run` in `ecto.setup` | PASS |
| Headless DemoContextProvider test passes in isolation | `cd examples/cairnloop_example && mix test test/cairnloop_example/demo_context_provider_test.exs` | Cannot execute — example app's `mix test` alias requires `ecto.create` against Postgres on `localhost:5433` which is unavailable (CLAUDE.md REPO-UNAVAILABLE baseline). The test code itself is structurally correct, pure (no Repo), and `async: true`. | SKIP (REPO-UNAVAILABLE) — route to human |
| DB-backed seeds integration test (FIX-01..FIX-04 row counts + Oban drain + idempotency) | `cd examples/cairnloop_example && mix test test/cairnloop_example/seeds_test.exs` | Cannot execute (same REPO-UNAVAILABLE caveat). Test is tagged `:requires_postgres` to gate this exact case. | SKIP (REPO-UNAVAILABLE) — route to human |
| `mix setup` end-to-end on a real DB | `cd examples/cairnloop_example && mix setup` | Cannot execute (REPO-UNAVAILABLE) | SKIP — route to human |

### Probe Execution

No phase-declared probes (`scripts/*/tests/probe-*.sh`) exist in this repository; this is an Elixir project that uses ExUnit + dialyzer rather than shell probes. Per phase 27 plans, the substitute is `mix compile --warnings-as-errors` + the two ExUnit test files. The compile probe ran and passed (exit 0).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| FIX-01 | 27-01, 27-02, 27-04, 27-08 | 12–16 conversations across `:new`/`:open`/`:awaiting_customer`/`:resolved` with operator+customer messages and ContextProvider snippets | SATISFIED (structurally; awaits visual) | See Truth 1 + DemoContextProvider artifact rows. After visual confirmation, REQUIREMENTS.md FIX-01 row can flip from Pending to Done. |
| FIX-02 | 27-01, 27-03, 27-07, 27-08 | ≥5 articles with multiple revisions (≥1 :deprecated/:archived); live ChunkRevision -> pgvector | SATISFIED (structurally; awaits visual) | See Truth 2 + key-link wiring. Flip Pending -> Done after visual confirmation. |
| FIX-03 | 27-05, 27-08 | ≥3 GapCandidate rows with evidence in ranked maintenance queue | SATISFIED (structurally; awaits visual) | See Truth 3 + `@demo_gaps` triple. Flip Pending -> Done after visual confirmation. |
| FIX-04 | 27-06, 27-08 | ≥1 ArticleSuggestion in :ready_for_review with citation-backed proposed_markdown | SATISFIED (structurally; awaits visual) | See Truth 4 + ReviewTask companion. Flip Pending -> Done after visual confirmation. |

No orphaned requirements: REQUIREMENTS.md lines 119-122 map FIX-01..FIX-04 to Phase 27 only; every ID is claimed by a plan frontmatter in this phase.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `examples/cairnloop_example/priv/repo/seeds.exs` | 1190-1213 | `compute_evidence_digest` comment claims "field order is LOAD-BEARING" but Elixir map literal field order has no effect on JSON output (maps iterate in Erlang term order, so keys emit alphabetically). | Info (already flagged in 27-REVIEW.md as WR-02) | Comment is misleading; behavior happens to be correct because both seed and production paths use the same field set and atom keys. No functional impact, but a future drift in `citation_target` key shape could break digest stability silently. Resolution carried in 27-REVIEW.md WR-02 follow-up. |
| `examples/cairnloop_example/priv/repo/seeds.exs` | 419-432 | `seed_conversation_row/2` keys on `subject` alone; a partially-inserted conversation (row exists, messages absent due to a crash mid-run) would silently re-skip on next run. | Warning (27-REVIEW.md WR-01) | Foot-gun for adopters who hit a transient DB blip mid-seed. The promised contract is "no-op on re-run" not "self-heal partial state," so this is technically within contract. Carried in 27-REVIEW.md WR-01. |
| `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` | 49-78 | FIX-01 row-count test does not assert the per-cohort derivation invariants — a regression collapsing `:new` into `:open` would pass. | Warning (27-REVIEW.md WR-03) | Test is correct for its current scope; the gap is coverage breadth, not a bug. The structural correctness of the seed (verified by reading `@demo_conversations`) does enforce the 4-cohort distribution today. |
| `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` | 82-89 | FIX-02 test does not pin per-article published-revision count, and the global `≥1 :archived` assertion does not pin the archived revision to article 5. | Warning (27-REVIEW.md WR-04) | Coverage gap. The seed itself does enforce these via `build_articles/0` structure. |
| `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` | 91-111 | FIX-03/FIX-04 tests do not verify operator-scope `host_user_id: "demo_operator"` on seeded gaps/suggestion. | Warning (27-REVIEW.md WR-05) | Coverage gap. The seed code itself does hardcode `"demo_operator"` for these rows. |
| `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` | 168-201 | D-02 idempotency test asserts only row counts, not content stability across runs. | Warning (27-REVIEW.md WR-06) | Coverage gap. |

All 6 warnings were previously surfaced in `27-REVIEW.md` (status: `issues_found`, 0 blockers, 6 warnings, 4 info). They are quality / coverage concerns, not BLOCKERs — every gap they identify is structurally enforced by the seed code itself today; they would only let a future regression slip past CI. The 27-REVIEW.md catalogue is preserved as carried tech debt; none block this phase's goal achievement.

### Human Verification Required

#### 1. Adopter-visible dashboard on first boot

**Test:** `cd examples/cairnloop_example && mix setup` (or `mix ecto.reset`) followed by `mix phx.server`, then open `/support` in a browser.

**Expected:**
- Operator inbox renders 12+ conversations distributed across `:new` / `:open` / `:awaiting_customer` / `:resolved` (4 each, 16 total). Cohort distribution is visually distinguishable.
- ContextProvider snippets render for each of the 5 demo customer identities (Riya/Mateo/Sora/Priya/Jonas) — `User Details` + `Active Plan` + persona-specific third section.
- KB Index at `/support/knowledge-base` shows 5 articles, including a multi-revision tab on "Rotating an expired token" with a `:archived` v1 + `:published` v2 visible.
- cmd+k search returns lex-ordered hits for article titles (zero-vector mode without `OPENAI_API_KEY`).
- `/support/knowledge-base/gaps` shows 3 inspectable gap candidates with scored evidence.
- `/support/knowledge-base/suggestions` shows 1 `:ready_for_review` ArticleSuggestion with `[1]` and `[2]` citation chips.

**Why human:** The ROADMAP success criteria are about dashboard rendering, not just row counts. Visual coherence, navigation flow, and the JTBD-cohort feel are editorial and not deterministically testable. CLAUDE.md baseline also blocks executing the DB-backed integration test on this workstation — the developer (or CI) needs to run the manual sweep after the next time Postgres on `localhost:5433` is available.

#### 2. Brand voice on seeded copy

**Test:** Open `examples/cairnloop_example/priv/repo/seeds.exs` and spot-check the message-body / article-body / proposed-markdown helpers: `opening_user/1`, `followup_user/1`, `agent_first_reply/1`, `agent_response/1`, `agent_solution/1`, `agent_closing/1`, `internal_note/1`, the 5 article body strings (lines 131-323), and `proposed_markdown` (line 1113).

**Expected:** Each body reads as calm, fail-closed, reason-forward, and honest per `prompts/cairnloop_brand_book.md` §5.5 + §7.5. No raw Elixir atoms or raw JSON surface in any operator- or customer-facing string. Internal-note bodies may reference IDs/typed terms (D-18 carve-out).

**Why human:** Tone-of-voice is editorial; no automated check pins it. The executor reported self-reviewing each body, but a fresh human read is the final validation. Spot-check at least 3 conversations per cohort + all 5 articles + the 1 suggestion.

### Gaps Summary

No blocking gaps found. All 4 ROADMAP success criteria (mapped to FIX-01..FIX-04) are structurally satisfied by the codebase:

- **FIX-01 (16 conversations × 4 JTBD cohorts + ContextProvider snippets)** — `@demo_conversations` enumerates the 16 rows by cohort; `DemoContextProvider` is wired via `config.exs` and matches the 5 demo `host_user_id` values seeded onto those conversations.
- **FIX-02 (≥5 articles, ≥1 archived revision, live Oban-driven embedding pipeline)** — `build_articles/0` ships 5 articles via the `KnowledgeBase` facade (the path that enqueues `ChunkRevision`); article 5 has a `v1 -> :archived` step; `drain_embedding_pipeline/0` calls `Oban.drain_queue(queue: :default, with_recursion: true)` at end-of-script.
- **FIX-03 (≥3 GapCandidates with evidence)** — `@demo_gaps` ships 3 specs; each one inserts `GapCandidate + RetrievalGapEvent + GapCandidateMembership` with the D-14 score/evidence-count attributes and the Pitfall 3 operator-scope `host_user_id: "demo_operator"`.
- **FIX-04 (≥1 :ready_for_review ArticleSuggestion with citation-backed proposed_markdown)** — `build_suggestion/2` inserts 1 `:ready` suggestion (sealed-enum mapping) with 2 KB-chunk-grounded evidence rows; `ensure_review_task_for_suggestion/2` creates the companion `ReviewTask` the `SuggestionReview` LiveView queries (Critical Finding 2 / Pitfall 1 honored).

The remaining items are the **human verification** above (visual dashboard sweep + brand-voice spot-check) and the **6 warnings** carried forward from `27-REVIEW.md` (coverage / comment-quality concerns; no blockers).

### Re-verification Notes

This is the initial verification for phase 27. No prior `27-VERIFICATION.md` existed.

### Status Recommendation

**Status:** `human_needed`

All technical must-haves verified by reading the codebase against the ROADMAP success criteria + FIX-01..FIX-04 acceptance language. The structural correctness of `seeds.exs`, `DemoContextProvider`, `config.exs`, and both test files is fully in place. Two human items remain before this phase is unconditionally done:

1. **Visual dashboard sweep** (post-`mix setup` browser check across inbox + KB index + gaps + suggestions) — REPO-UNAVAILABLE blocks doing this locally; this must run when a developer or CI lane has Postgres available.
2. **Brand-voice spot-check** of the seeded copy — editorial review.

The `REQUIREMENTS.md` FIX-01..FIX-04 entries should remain `Pending` until the visual sweep confirms — flipping to `Done` purely on automated checks would skip the success-criteria-as-rendered acceptance.

---

*Verified: 2026-05-27T17:18:57Z*
*Verifier: Claude (gsd-verifier)*
