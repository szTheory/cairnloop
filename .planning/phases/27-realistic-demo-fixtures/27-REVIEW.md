---
phase: 27-realistic-demo-fixtures
reviewed: 2026-05-27T17:14:01Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - examples/cairnloop_example/config/config.exs
  - examples/cairnloop_example/lib/cairnloop_example/demo_context_provider.ex
  - examples/cairnloop_example/priv/repo/seeds.exs
  - examples/cairnloop_example/test/cairnloop_example/demo_context_provider_test.exs
  - examples/cairnloop_example/test/cairnloop_example/seeds_test.exs
findings:
  critical: 0
  warning: 6
  info: 4
  total: 10
status: issues_found
---

# Phase 27: Code Review Report

**Reviewed:** 2026-05-27T17:14:01Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Phase 27 ships realistic demo fixtures: an idempotent `seeds.exs` building 5 KB articles
(article 5 with a v1→archived→v2 progression for FIX-02), 16 conversations across 4
JTBD-derived cohorts, 3 gap candidates with seeded evidence, 1 article suggestion +
ReviewTask companion, plus a `DemoContextProvider` covering 5 demo identities and a
DB-backed `seeds_test.exs` pinning FIX-01..FIX-04 row-count thresholds.

The sealed-contract reconciliation (D-03 status enum, D-04/D-05 revision states, D-09
facade rules, D-13 direct-schema gap inserts, D-16 evidence requirements) is structurally
correct. `Conversation.status` is never set outside `[:open, :resolved, :archived]`;
`ArticleSuggestion.status: :ready` and `suggestion_type: :article` are correctly mapped
from the spec's `:ready_for_review` / `:new_article` language; `Message.run_key` is
nowhere set (Pitfall 5 honored); the lone `:system_outbound` closer at n=16 carries
`metadata.template_id: "demo_resolve_confirm"` (Pitfall 6 honored); the `DemoContextProvider`
catch-all `{:ok, %{}}` matches the documented fail-open behaviour contract.

**No blockers found.** The findings below are quality concerns: the test suite has
several coverage gaps around the FIX-01..FIX-04 / D-02 claims that would let real
regressions slip past CI; the `compute_evidence_digest` reproducibility comment is
misleading; the partial-failure idempotency story has an unflagged hole; and the seed
contains a small amount of dead-code-style scaffolding.

## Warnings

### WR-01: Conversation idempotency guard cannot self-heal a partially-inserted seed

**File:** `examples/cairnloop_example/priv/repo/seeds.exs:419-432`
**Issue:** `seed_conversation_row/2` keys conversation existence on `subject` alone. If a
previous seed run inserted the `Conversation` row but crashed before inserting any of
its messages (e.g. one of the 16 inserts hit a transient DB error, killed by `mix run`
SIGINT, or an Oban-related disconnect mid-stream), the next run sees the existing
conversation and skips `insert_messages_for_cohort/2` entirely. The test suite's
`Message :count >= 48` guard then passes only if the partial state happens to clear the
threshold — which it almost certainly will not for a single-conversation crash mid-run,
but more importantly, the partially-seeded conversation is now silently un-fixable except
by manual DB intervention. The contract comment at lines 12-15 promises "Re-running this
script against an already-seeded DB is a no-op" but does NOT promise self-healing, so
this is technically within contract — but it is a real foot-gun for adopters who run
`mix setup` once, see an Oban warning, and re-run.
**Fix:** Either (a) wrap the conversation + messages insert in a single `Ecto.Multi` so
the conversation row only appears when all its messages also succeed, or (b) augment the
guard to inspect message count for the existing conversation and backfill if zero:
```elixir
case Repo.get_by(Conversation, subject: subject) do
  nil ->
    conv = %Conversation{} |> Conversation.changeset(attrs) |> Repo.insert!()
    insert_messages_for_cohort(conv, row)
    conv

  existing ->
    msg_count = Repo.aggregate(
      from(m in Message, where: m.conversation_id == ^existing.id), :count
    )
    if msg_count == 0, do: insert_messages_for_cohort(existing, row)
    existing
end
```
Option (a) is structurally cleaner; option (b) is the minimum-risk patch.

### WR-02: `compute_evidence_digest` field-order comment is misleading; reproducibility depends on Erlang map-iteration order

**File:** `examples/cairnloop_example/priv/repo/seeds.exs:1190-1213`
**Issue:** The comment at lines 1190-1197 calls the field order
`[source_type, trust_level, title, excerpt, citation_target, match_reasons]`
"LOAD-BEARING" — but the field order in the source-literal `%{...}` map has **no effect**
on the JSON output. Elixir maps stored under flatmap representation (≤32 keys) iterate
in Erlang term order, so `Jason.encode!` actually emits keys alphabetically
(`citation_target, excerpt, match_reasons, source_type, title, trust_level`). The
seed-side and the production `evidence_digest_for/1` at
`lib/cairnloop/knowledge_automation.ex:961-976` both build atom-keyed maps with the
**same field set**, so today's digests match because both sides hit the same canonical
order — not because of the literal field order.

A second, subtler reproducibility hazard: `citation_target` is `%{article_id: ...,
revision_id: ..., chunk_index: 0}` (atom keys) at seed time, but a `field :citation_target,
:map` after JSONB round-trip is **string-keyed**. For the current 3-key shape both atom
and string sort orders coincide alphabetically, so JSON output matches. Add a fourth key
whose atom-name vs string-codepoint order differ (e.g. an atom that sorts before another
atom but its string form sorts after, or vice versa for non-ASCII characters), and the
digests will silently diverge between seed-time and any post-reload re-computation. The
phase-27 plan explicitly carries this forward for CandidateBuilder re-computation
(D-16 / T-27-19) — so the contract is real, but the comment misrepresents what protects
it.
**Fix:** Replace the misleading "field order is LOAD-BEARING" comment with the actual
invariants: (1) same field set on both sides, (2) atom keys on both sides (or canonicalize
to string keys explicitly), (3) `citation_target` must contain identically-typed keys.
Better yet, canonicalize: convert maps to a sorted-key string-key form before JSON-encoding
on both seed and production paths. Minimum patch:
```elixir
defp compute_evidence_digest(evidence_snapshot) do
  evidence_snapshot
  |> Enum.map(fn e ->
    # Mirror evidence_digest_for/1 EXACTLY — field set, not literal order
    %{
      source_type: e.source_type,
      trust_level: e.trust_level,
      title: e.title,
      excerpt: e.excerpt,
      # stringify citation_target keys for stability across atom/string-key drift
      citation_target: stringify_keys(e.citation_target),
      match_reasons: e.match_reasons
    }
  end)
  |> Jason.encode!()
  |> then(&:crypto.hash(:sha256, &1))
  |> Base.encode16(case: :lower)
end
```
…and replicate the canonicalization on the production side. If that change is too broad
for this phase, at minimum delete the load-bearing-field-order claim and add a regression
test that seeds the suggestion, reloads it, and asserts `evidence_digest ==
evidence_digest_for(reloaded.evidence_snapshot)`.

### WR-03: FIX-01 test does not verify 4-cohort JTBD distribution — single-cohort regression passes

**File:** `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs:49-78`
**Issue:** The test asserts `≥16 conversations`, `≥12 :open`, `≥4 :resolved`, and
`Message :count` in `[48, 80]`. It does NOT assert the per-cohort derivation invariants
documented at `seeds.exs:343-350`:
- `:new` cohort: status `:open` + **zero** `:agent` messages
- `:open` cohort: status `:open` + ≥1 `:agent` message + last message role `:user`
- `:awaiting_customer` cohort: status `:open` + ≥1 `:agent` message + last message role `:agent`
- `:resolved` cohort: `resolved_at` set + last message `:agent` or `:system_outbound`

A regression that, for example, makes all 12 `:open` conversations carry one `:agent`
reply (collapsing `:new` into `:open`) would pass every existing assertion while
breaking the JTBD demo story — operators would see no `:new` cohort in the inbox. The
demo's whole point is the 4-cohort distribution; the test should pin it.
**Fix:** Add cohort-derivation assertions:
```elixir
# Derived :new cohort = :open status + 0 :agent messages, expect ≥4
new_cohort_count =
  Repo.aggregate(
    from(c in Conversation,
      where: c.status == :open and
        c.id not in subquery(
          from(m in Message, where: m.role == :agent, select: m.conversation_id, distinct: true)
        )
    ),
    :count
  )
assert new_cohort_count >= 4, "Expected ≥4 derived :new conversations"

# Verify one :system_outbound message exists with a template_id (Pitfall 6)
sys_outbound =
  Repo.one(from m in Message,
    where: m.role == :system_outbound,
    limit: 1
  )
assert sys_outbound, "Expected ≥1 :system_outbound closing message (n=16)"
assert sys_outbound.metadata["template_id"] == "demo_resolve_confirm",
       "system_outbound message must carry metadata.template_id (Pitfall 6)"

# Verify internal_note rows exist (D-18 carve-out at n=5, n=13)
assert Repo.aggregate(from(m in Message, where: m.role == :internal_note), :count) >= 2,
       "Expected ≥2 :internal_note messages (D-18 carve-out at n=5 and n=13)"
```

### WR-04: FIX-02 test does not pin published-revision count per article — drafts-only regression passes

**File:** `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs:82-89`
**Issue:** The test asserts `≥5 articles`, `≥6 revisions`, and `≥1 :archived revision`.
It does NOT assert each article has ≥1 `:published` revision. A regression where
`KnowledgeBase.publish_revision/1` were swapped for `save_draft/2` only (or where the
`unless Repo.one(from r in Revision, where: ... :published, ...)` guard inverted) would
leave articles with only draft revisions, breaking M008 chunk generation for them.
The `cairnloop_chunks` self-test at lines 117-134 would catch the article-5 case (because
unchunked drafts produce no chunks), but `:count >= 5` is a low bar — only one article
needs to publish to clear it.

Also, the seed comment at seeds.exs:269 promises "≥1 :archived revision exists" for
**article 5 specifically** (the only article with the v1→archive→v2 progression). The
test's `≥1 :archived` is global — it doesn't pin the archived revision to article 5,
so a regression that archives a different article's revision (e.g. accidentally
archiving an api-key article instead of token_rotation) would still pass.
**Fix:** Tighten the FIX-02 assertions:
```elixir
# Every article must have ≥1 :published revision
articles_with_published =
  Repo.all(
    from a in Article,
      join: r in Revision, on: r.article_id == a.id,
      where: r.state == :published,
      distinct: a.id,
      select: a.id
  )
assert length(articles_with_published) >= 5,
       "Expected every article to have ≥1 :published revision (FIX-02 M008 substrate)"

# Article 5 specifically must have both :archived and :published revisions (D-05)
token_article = Repo.get_by!(Article, title: "Rotating an expired token")
assert Repo.aggregate(
         from(r in Revision,
           where: r.article_id == ^token_article.id and r.state == :archived
         ),
         :count
       ) >= 1, "Token-rotation article must have ≥1 :archived revision (D-05)"
```

### WR-05: FIX-03 / FIX-04 tests don't verify operator-scope (Pitfall 3)

**File:** `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs:91-111`
**Issue:** Plans 27-05 (gaps) and 27-06 (suggestion) explicitly call out Pitfall 3 —
gap candidates, gap events, gap memberships, and the article suggestion must use
`host_user_id: "demo_operator"`, **not** one of the five `demo_user_*` customer ids,
because operator-scope rows are queried by the operator inbox using a different scope
than customer conversations. A regression that copies a customer id into the gap
seeder (because they share the same string-typed `host_user_id` field) would not be
caught by the existing test — `:count` and membership assertions don't filter on
`host_user_id`.
**Fix:** Add scope assertions:
```elixir
# All GapCandidates must be operator-scoped (Pitfall 3)
gap_scope_violations =
  Repo.aggregate(
    from(g in GapCandidate, where: g.host_user_id != "demo_operator"),
    :count
  )
assert gap_scope_violations == 0,
       "All seeded GapCandidates must use host_user_id 'demo_operator' (Pitfall 3 — operator-scope)"

# Same for the seeded ArticleSuggestion
suggestion = Repo.one!(
  from s in ArticleSuggestion,
    where: s.stable_key == "demo:article_suggestion:billing_export:v1"
)
assert suggestion.host_user_id == "demo_operator",
       "Seeded ArticleSuggestion must use host_user_id 'demo_operator' (Pitfall 3)"
assert suggestion.tenant_scope == :host_user_scoped
assert length(suggestion.evidence_snapshot) >= 2,
       "Seeded ArticleSuggestion must have ≥2 evidence rows (D-16)"
assert is_binary(suggestion.evidence_digest) and
         byte_size(suggestion.evidence_digest) == 64,
       "evidence_digest must be a 64-char hex sha256 (D-16)"
```

### WR-06: D-02 idempotency test asserts row counts only — does not catch content drift on re-run

**File:** `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs:168-201`
**Issue:** The idempotency test captures `Repo.aggregate(_, :count)` for 8 tables before
and after the second run and asserts equality. This catches duplicate inserts but
**misses content mutation** — if `KnowledgeAutomation.ensure_review_task_for_suggestion/2`
on re-run silently updated an existing row's `updated_at` or `status`, or if a future
maintenance edit re-computed `evidence_digest` from a freshly-reloaded snapshot (see
WR-02), the row counts would be unchanged but the contract "re-running is a no-op"
would be violated. The seed's contract at lines 12-15 says "Re-running this script
against an already-seeded DB is a no-op" — but a no-op contract that only counts rows
will let `UPDATE` regressions through.
**Fix:** Snapshot at least the primary-key + `updated_at` + key content fields for
representative rows and compare:
```elixir
# Snapshot the seeded suggestion fully
fetch_suggestion = fn ->
  Repo.one!(
    from s in ArticleSuggestion,
      where: s.stable_key == "demo:article_suggestion:billing_export:v1",
      select: %{
        id: s.id,
        evidence_digest: s.evidence_digest,
        proposed_markdown: s.proposed_markdown,
        updated_at: s.updated_at
      }
  )
end

s1 = fetch_suggestion.()
assert :ok == run_seed!()
s2 = fetch_suggestion.()

assert s1 == s2,
       "Re-running the seed mutated the existing ArticleSuggestion. " <>
         "D-02 promises a true no-op, not just stable row counts.\n" <>
         "Before: #{inspect(s1)}\nAfter:  #{inspect(s2)}"
```
Apply the same shape to one representative `Conversation` (subject + status) and one
`Revision` (state + content prefix). The current count-only check is a necessary but
not sufficient idempotency probe.

## Info

### IN-01: Misleading facade-rule comment for `Article` inserts

**File:** `examples/cairnloop_example/priv/repo/seeds.exs:113-118`
**Issue:** The comment claims "Each article is created via the KnowledgeBase facade
(D-09): `get_or_insert!(Article, :title, ...)` for the article row." This is incorrect:
`get_or_insert!/3` (defined at lines 1258-1268) is a **local** helper that builds a
changeset and calls `Repo.insert!` directly — it bypasses
`Cairnloop.KnowledgeBase.create_article/1`. The seed's `publish_revision/1` calls
**are** through the facade (which is the load-bearing one because it enqueues the
`ChunkRevision` Multi), so behaviour is correct, but the comment overstates compliance.
**Fix:** Clarify the comment:
```
# Each article is created with a direct Article.changeset + Repo.insert! via the local
# get_or_insert!/3 idempotency helper. KnowledgeBase.create_article/1 is intentionally
# NOT used because it has no built-in idempotency guard, and bypassing it for the
# article row is safe — create_article/1 carries no side-effects beyond the insert.
# The load-bearing facade calls (D-09) are save_draft/2 + publish_revision/1, which the
# seed DOES use; publish_revision/1 is what enqueues the ChunkRevision Oban Multi (FIX-02).
```

### IN-02: Dead conditional in `emit_seed_summary/5`

**File:** `examples/cairnloop_example/priv/repo/seeds.exs:1242`
**Issue:** `suggestion_count = if suggestion, do: 1, else: 0` — `build_suggestion/2`
unconditionally returns `{%ArticleSuggestion{}, %ReviewTask{}}` (lines 1187 + 1182's
pattern-match would crash on `:error`), so `suggestion` is never nil/false. The `else: 0`
branch is unreachable.
**Fix:** Simplify to `suggestion_count = 1` or, if defensive coding is preferred,
restructure so the function actually handles a nil return rather than pattern-asserting
it earlier.

### IN-03: DemoContextProvider test does not verify inner-map keys are atoms (or are stable terms)

**File:** `examples/cairnloop_example/test/cairnloop_example/demo_context_provider_test.exs:46-56`
**Issue:** The test asserts (a) top-level section keys are strings and (b) inner-map
**values** are simple terms — but it does NOT assert anything about inner-map **keys**.
The provider currently uses atom keys (`:tier`, `:seats`, `:status`, etc.) for
inner-map keys, which is fine as long as whatever consumes this map (e.g. operator-inbox
rendering) accepts atom keys. If a future refactor swaps inner-map keys to strings (or
vice versa), the test won't catch the regression even though the rendering layer might
break.

Additionally, the iteration `for {section, inner_map} <- ctx, is_map(inner_map), {_key,
value} <- inner_map` **silently skips** any section whose value is not a map — meaning
a regression that put an atom **as a top-level section value** (rather than nested in
an inner map) would pass `assert Enum.all?(Map.keys(ctx), &is_binary/1)` (keys are still
strings) and would pass this test (because the non-map section is skipped). The test
description claims "no Elixir atoms in values" — but it only checks atoms in inner-map
values, not top-level section values.
**Fix:** Decide whether inner-map keys are part of the contract (likely yes) and pin
the contract; also widen the atom-leakage check to top-level section values:
```elixir
test "no atoms leak into any value position (top-level or nested)" do
  for actor <- @known_actors do
    {:ok, ctx} = DemoContextProvider.get_context(actor, [])

    check = fn val, _self ->
      cond do
        is_atom(val) and val not in [nil, true, false] ->
          flunk("Atom #{inspect(val)} surfaced in DemoContextProvider for #{inspect(actor)}")
        is_map(val) ->
          Enum.each(val, fn {_k, v} -> check.(v, check) end)
        is_list(val) ->
          Enum.each(val, fn v -> check.(v, check) end)
        true -> :ok
      end
    end

    Enum.each(ctx, fn {_section, value} -> check.(value, check) end)
  end
end
```

### IN-04: `seeds.exs` lacks a smoke-test against the OPENAI_API_KEY-absent fallback path

**File:** `examples/cairnloop_example/priv/repo/seeds.exs:18-22`
**Issue:** The header comment promises that without `OPENAI_API_KEY` set, "zero-vector
embeddings are written via the existing dev-safety fallback in
`Cairnloop.Embedder.ExternalApi`." The seeds_test does not exercise this branch — it
does not assert that the seed completes when `OPENAI_API_KEY` is absent, and the Oban
drain assertion at seeds_test.exs:124 (`Repo.aggregate(Chunk, :count) > 0`) only
verifies chunks exist, not that they have non-zero vectors. This is an Info-level
finding because the production embedder is out of scope for this phase, but adopters
running `mix setup` without an API key are the precise audience the demo targets — a
regression in the zero-vector fallback (e.g. embedder raising instead of returning
zeros) would leave the demo's M008 self-test broken.
**Fix:** Add a focused test that unsets `OPENAI_API_KEY`, runs the seed, and asserts
chunks are present (already done) **plus** at least one chunk has the expected
zero-vector signature. If that's too coupled to the Embedder internals, at minimum
document in the seed comment that the test suite does not exercise this code path so
future maintainers know to spot-check `mix setup` from a clean shell.

---

_Reviewed: 2026-05-27T17:14:01Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
