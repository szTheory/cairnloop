# Phase 27: Realistic Demo Fixtures - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-27
**Phase:** 27-Realistic Demo Fixtures
**Areas discussed:** JTBD-status semantics, "deprecated" revision mapping, embedder behavior during seeds, ContextProvider snippets, idempotency, M008 substrate self-test (Oban drain), GapCandidate seeding path, ArticleSuggestion seeding path, demo product/voice, ContextProvider config touchpoint

**Mode:** Shift-left advisor flow. USER-PROFILE = `opinionated` / `minimal_decisive`; CLAUDE.md directs "decide-for-me; escalate only VERY impactful". All gray areas decided up-front with brief rationale and presented as a single decisions block. One explicit user-veto checkpoint on the only call (D-13) that could plausibly be argued either way.

---

## D1 — JTBD status semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Add `:new` / `:awaiting_customer` to `Conversation.status` enum | Honors roadmap-language literally but breaks sealed-contract invariant; cascading impact on shipped LiveViews + tests | |
| Derive JTBD state from `(status, resolved_at, last-message-role)` | Sealed schema preserved; 4 cohorts × 4 conversations = 16 | ✓ |

**Selected:** Derive JTBD state. **Notes:** Sealed-contract invariant in `PROJECT.md` and `STATE.md` makes schema churn untenable. The roadmap's `:new`/`:awaiting_customer` language describes lifecycle, not literal column values.

---

## D2 — "Deprecated" revision mapping

| Option | Description | Selected |
|--------|-------------|----------|
| Add `:deprecated` to `Revision.state` enum | Schema churn on a sealed enum used by `EditorHandoff.verify!/2` + integration tests | |
| Map "deprecated" → `:archived` (existing enum value) | Zero schema change; `:archived` is the documented state for superseded revisions | ✓ |

**Selected:** Map to `:archived`. **Notes:** Naming mismatch flagged in CONTEXT.md so the planner does not re-litigate it.

---

## D3 — Embedder behavior during `mix setup`

| Option | Description | Selected |
|--------|-------------|----------|
| Build a new deterministic embedder stub for example app | New module + config wiring; deferred-decisions surface | |
| Use existing zero-vector fallback in `ExternalApi.generate_embeddings/2` | Already shipped; adopters without `OPENAI_API_KEY` get a populated DB | ✓ |

**Selected:** Existing zero-vector fallback. **Notes:** FIX-02 success criterion is "embeddings flow through the live `ChunkRevision` Oban worker into pgvector" — that's about the *pipeline*, not the *vector quality*. Phase 31 / vM015 owns search-quality.

---

## D4 — ContextProvider snippets

| Option | Description | Selected |
|--------|-------------|----------|
| Add `CairnloopExample.DemoContextProvider` + wire in `config.exs` | One small module + one config line; matches the library's configured-adapter pattern | ✓ |
| Stash snippets in message metadata so default empty provider still renders | Bypasses the documented behaviour; opaque to adopters reading the example | |

**Selected:** Demo provider + config wire. **Notes:** Adopters land in a populated inbox AND see how to wire their own provider, matching FIX-01 success criterion intent.

---

## D5 — Seed rerun safety / idempotency

| Option | Description | Selected |
|--------|-------------|----------|
| One-shot (Phoenix default; relies on `ecto.reset`) | Re-running seeds against existing data raises unique-constraint errors | |
| Idempotent via natural-key `Repo.get_by` guards | Re-running is a no-op; adopters re-run seeds in practice | ✓ |

**Selected:** Idempotent natural-key guards. **Notes:** Explicit `if existing, do: existing, else: insert!` over `on_conflict` magic — readable in seeds.exs.

---

## D6 — Oban drain at end of seeds (M008 substrate self-test)

| Option | Description | Selected |
|--------|-------------|----------|
| Enqueue + exit (Oban processes async) | Adopters open the inbox before chunks land; cmd+k empty on first paint | |
| `Oban.drain_queue(queue: :default, with_recursion: true)` at end of seeds.exs | Synchronous; first-boot UI fully populated | ✓ |

**Selected:** Drain queue. **Notes:** Assessment thread explicitly names this the M008 substrate self-test.

---

## D7 — GapCandidate seeding path (explicit user-veto checkpoint)

| Option | Description | Selected |
|--------|-------------|----------|
| Direct-insert GapCandidate + GapCandidateMembership rows | M008 substrate self-test stays the embedding pipeline; Phase 31 covers M010 builder; smallest seed footprint | ✓ |
| Run live `CandidateBuilder` against seeded `RetrievalGapEvent` rows | Honest M010 self-test; brings M010 worker scheduling + scoring quirks inside FIX-* and adds seed-shape complexity | |
| Approve full decision set as-is | Take D7 = direct-insert; proceed to CONTEXT.md | |

**Selected:** Direct insert (user-ratified 2026-05-27 via AskUserQuestion). **Notes:** This was the only decision presented for explicit veto — others are auto-decided under shift-left.

---

## D8 — ArticleSuggestion seeding path

| Option | Description | Selected |
|--------|-------------|----------|
| Direct-insert `:ready_for_review` row + hand-authored citation-backed `proposed_markdown` | No LLM call; adopters without API keys still get a real suggestion to review | ✓ |
| Enqueue `Workers.GenerateArticleSuggestion` | Real LLM call required on first `mix setup`; flakes or burns tokens | |

**Selected:** Direct insert. **Notes:** `evidence_digest` computed deterministically to mirror live-worker output shape.

---

## D9 — Demo product / voice

| Option | Description | Selected |
|--------|-------------|----------|
| "Trailmark" generic dev-tools SaaS (CI / API keys / billing / seats) | Recognizable problem domain; easy to write 16 plausible conversations + 5 KB articles | ✓ |
| Generic "Customer Support Demo" with placeholder language | Bland; adopters bounce off the lonely-demo feeling the phase exists to fix | |

**Selected:** Trailmark. **Notes:** Brand voice from `prompts/cairnloop_brand_book.md` §7.5 applies to every message body.

---

## D10 — `config :cairnloop, :context_provider, ...` in example config

| Option | Description | Selected |
|--------|-------------|----------|
| Add the line in `examples/cairnloop_example/config/config.exs` | Additive; honors configured-adapter pattern the library already documents | ✓ |
| Skip the config wire and let `DefaultContextProvider` continue | Breaks FIX-01 "ContextProvider snippets" criterion | |

**Selected:** Add the line.

---

## Claude's Discretion

The following are explicitly delegated to the planner / executor against the brand-voice constraint:

- Per-conversation message timing distribution (timestamps), CSAT ratings on `:resolved` conversations.
- `recipient_emails` choice for outbound-eligible `:resolved` conversations.
- Exact body text for all 16 conversations, 5 articles, and the 1 article suggestion.
- Whether seeded `RetrievalGapEvent` rows referenced by `GapCandidateMembership.source_id` are full rows or synthetic ids; planner picks the smallest path that keeps the gap-queue UI rendering inspectable evidence.
- Whether to use a per-article natural-key column or just unique titles for idempotency lookups.

## Deferred Ideas

- Semantically-meaningful demo search (deterministic varied embeddings or local Bumblebee inference) — Phase 31 / vM015.
- Running `Workers.GenerateArticleSuggestion` live in seeds (LLM key/cost surface) — Phase 31 golden-path smoke.
- Running `CandidateBuilder` from seeds (M010 self-test) — Phase 31 golden-path smoke.
- Seeding `ToolProposal` rows + a fixture `seat_invite` Tool — possibly Phase 28 or a later phase if adopters pull.
- `SettingsLive` overhaul, `/health`, `/metrics`, AR-14-02 pagination — vM015 (already deferred at milestone planning).
