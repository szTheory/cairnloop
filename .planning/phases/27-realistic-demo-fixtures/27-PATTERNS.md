# Phase 27: Realistic Demo Fixtures — Pattern Map

**Mapped:** 2026-05-27
**Files analyzed:** 5 (2 created modules + 1 rewritten script + 1 config edit + 2 created tests = 5 distinct deliverables, 4 reviewed analogs)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `examples/cairnloop_example/lib/cairnloop_example/demo_context_provider.ex` | behaviour-impl (pure) | request-response (pattern match) | `lib/cairnloop/default_context_provider.ex` | exact (same behaviour, fail-open shape) |
| `examples/cairnloop_example/test/cairnloop_example/demo_context_provider_test.exs` | test (headless / pure) | request-response | `test/cairnloop/context_provider_test.exs` | exact (same behaviour-under-test) |
| `examples/cairnloop_example/priv/repo/seeds.exs` | script (idempotent seed) | batch insert + facade call + Oban drain | (composite) `test/support/fixtures.ex` (direct-insert idiom) + `lib/cairnloop/knowledge_base.ex` (facade) + research-verified `Oban.drain_queue/1` shape | role-match (no existing analog is itself a seed; pattern is assembled from production+test idioms) |
| `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` | test (DB integration) | request-response → assert | `examples/cairnloop_example/test/cairnloop_example_web/controllers/page_controller_test.exs` (DB-backed example-app test wiring) + `test/cairnloop/knowledge_automation/gap_candidate_test.exs` (assertion style) | role-match (no seed-smoke analog exists; assemble from example-app DB-test wiring + library assertion style) |
| `examples/cairnloop_example/config/config.exs` | config (additive line) | n/a | the file itself, lines 59–61 — current `config :cairnloop, …` block | exact (one-line additive extension of an established block) |

---

## Pattern Assignments

### `examples/cairnloop_example/lib/cairnloop_example/demo_context_provider.ex` (behaviour-impl, request-response)

**Analog:** `lib/cairnloop/default_context_provider.ex` (entire file, 13 LOC)

**Shape to mimic** (lines 1–13):
```elixir
defmodule Cairnloop.DefaultContextProvider do
  @moduledoc """
  Default implementation of Cairnloop.ContextProvider.
  Returns an empty context `{:ok, %{}}` for any input to ensure a safe default.
  """

  @behaviour Cairnloop.ContextProvider

  @impl true
  def get_context(_actor_id, _opts \\ []) do
    {:ok, %{}}
  end
end
```

**Behaviour contract** (`lib/cairnloop/context_provider.ex:14-35`):
```elixir
  ## Examples of Returned Context

      {:ok, %{
        "User Details" => %{name: "Alice", lifetime_value: "$450"},
        "Active Plan" => %{tier: "Pro", status: "past_due"}
      }}

  @callback get_context(actor_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
```

**What the executor mimics:**
- Module attribute `@behaviour Cairnloop.ContextProvider` and `@impl true` on each clause (matches D-10).
- `{:ok, %{}}` fail-open default clause at the bottom (final catch-all for unknown actors).
- String section keys (`"User Details"`, `"Active Plan"`, …) and atom-keyed inner maps (matches the docstring example shape).
- The module-level `@moduledoc` follows the brand voice — calm, factual; no raw Elixir terms in the user-facing prose (D-12, brand book §7.5).

**What the executor deliberately does NOT copy:**
- The single-clause body. The demo provider needs 5–8 per-actor clauses keyed on `conversation.host_user_id` strings (e.g., `"demo_user_acme_billing"`, `"demo_user_globex_seats"`) — see D-10 / D-12.
- The default `\\ []` syntax in the head: with multiple clauses you must declare defaults in a separate `def get_context(actor_id, opts \\ [])` header or drop the default and always pass `[]`. The library default impl gets away with `\\ []` because it has one clause. The demo provider will have many clauses, so put the default on a function header (or omit it — callers in `conversation_live.ex:361` already pass an explicit `opts` list).
- Do NOT raise on unknown actors — the behaviour doc at lines 21–24 mandates tagged-tuple fail-open ("UI can degrade gracefully").

---

### `examples/cairnloop_example/test/cairnloop_example/demo_context_provider_test.exs` (test, headless / pure)

**Analog:** `test/cairnloop/context_provider_test.exs` (entire file, 14 LOC)

**Shape to mimic** (lines 1–14):
```elixir
defmodule Cairnloop.ContextProviderTest do
  use ExUnit.Case, async: true

  alias Cairnloop.DefaultContextProvider

  describe "DefaultContextProvider" do
    test "get_context/2 returns {:ok, %{}} for any actor_id" do
      actor_id = "user_123"
      opts = []

      assert {:ok, %{}} == DefaultContextProvider.get_context(actor_id, opts)
    end
  end
end
```

**What the executor mimics:**
- `use ExUnit.Case, async: true` (no Repo → safe to parallelize; matches D-20 "headless tests").
- Single `describe` block named after the module-under-test.
- Direct `assert {:ok, expected_map} == Module.get_context(actor_id, [])` shape — no helpers, no fixtures.
- No `alias` to `CairnloopExample.DataCase` (this test must NOT touch the Repo; that path is reserved for `seeds_test.exs`).

**What the executor deliberately does NOT copy:**
- The single-test minimalism. The demo provider needs at least:
  1. One test per known demo actor confirming the returned map has the expected top-level keys (e.g., `"User Details"`, `"Active Plan"`).
  2. One test confirming `{:ok, %{}}` fail-open for an unknown actor id (e.g., `"random_unknown_user"`).
  3. One test confirming all returned section keys are strings (brand voice §7.5 — no atom-keys leaking to the UI) and all values are nested maps of simple terms (strings/integers/booleans/dates) — matches the docstring contract in `context_provider.ex:9-12`.
- Do NOT use `CairnloopExample.DataCase` — this would force a sandbox checkout that the headless lane should not need.

---

### `examples/cairnloop_example/priv/repo/seeds.exs` (script, batch insert + facade call + Oban drain)

**Analog (composite — no single seed exists in this tree):**
- **Direct-insert idiom:** `test/support/fixtures.ex` lines 12–88
- **KB facade sequence:** `lib/cairnloop/knowledge_base.ex` lines 39–86
- **Oban drain shape:** research-verified call from `deps/oban/lib/oban.ex:920–928` (see RESEARCH.md §Code Examples)
- **Idempotency idiom:** D-02 derived (no existing analog uses `Repo.get_by` for seed guards; the pattern is shown in RESEARCH.md Pattern 1)

**Direct-insert pattern** (`test/support/fixtures.ex:12-26`, conversation_fixture):
```elixir
  def conversation_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    {:ok, conversation} =
      %Conversation{}
      |> Conversation.changeset(
        Map.merge(
          %{status: :open, subject: "Integration conversation", host_user_id: "test_operator"},
          attrs
        )
      )
      |> Repo.insert()

    conversation
  end
```

**Direct-insert pattern with role+content+metadata** (`test/support/fixtures.ex:72-88`, message_fixture):
```elixir
  def message_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    defaults = %{
      content: "Test internal note",
      role: :internal_note,
      run_key: nil,
      metadata: %{}
    }

    {:ok, message} =
      %Message{}
      |> Message.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    message
  end
```

**KB facade sequence** (`lib/cairnloop/knowledge_base.ex:65-86`):
```elixir
  def create_article(attrs) do
    %Article{}
    |> Article.changeset(attrs)
    |> repo().insert()
  end

  def publish_revision(revision) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:revision, Revision.changeset(revision, %{state: :published}))
    |> Ecto.Multi.update(:article, fn %{revision: rev} ->
      Article.changeset(repo().get!(Article, rev.article_id), %{status: :published})
    end)
    |> Ecto.Multi.insert(
      :chunk_job,
      Cairnloop.KnowledgeBase.Workers.ChunkRevision.new(%{revision_id: revision.id})
    )
    |> repo().transaction()
    |> case do
      {:ok, %{revision: published_revision}} -> {:ok, published_revision}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end
```

Note line 79: `publish_revision/1`'s Multi includes `Ecto.Multi.insert(:chunk_job, Workers.ChunkRevision.new(...))`. This is the load-bearing line for FIX-02 — bypassing the facade skips this enqueue and the M008 substrate self-test silently fails.

**Idempotency-guard pattern** (D-02; pattern from RESEARCH.md Pattern 1, no existing analog):
```elixir
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

**Oban drain shape** (research-verified, `deps/oban/lib/oban.ex:920-928`):
```elixir
%{success: success, failure: failure, snoozed: _, cancelled: _, discard: _} =
  Oban.drain_queue(queue: :default, with_recursion: true)

if failure > 0 do
  IO.warn("Seed embedding pipeline drained with #{failure} failures. " <>
          "Inspect oban_jobs.errors for details.")
end
```

**Embedder fallback that adopters hit when `OPENAI_API_KEY` is unset** (`lib/cairnloop/embedder/external_api.ex:9-21`) — read-only reference, NOT a thing to copy; the seed simply documents this behavior in a comment:
```elixir
  def generate_embeddings(chunks, _opts \\ []) do
    api_key = System.get_env("OPENAI_API_KEY")

    if is_nil(api_key) or api_key == "" do
      # Return mock embeddings for development safety if no API key
      mock_embeddings =
        Enum.map(chunks, fn _chunk ->
          # Default OpenAI dimension size
          List.duplicate(0.0, 1536)
        end)
      …
```

**What the executor mimics:**
- Direct `%Schema{} |> Schema.changeset(attrs) |> Repo.insert!()` — never `Ecto.Changeset.change/2` (the existing 49-LOC `seeds.exs` uses `Ecto.Changeset.change/2`, which BYPASSES schema validations; the executor must switch to the changeset-then-insert idiom from `fixtures.ex` so `Message.validate_template_id_for_outbound/1` and friends actually run — see Pitfall 6 in RESEARCH.md).
- `Map.merge(defaults, attrs)` for default-override per row (so each builder function exposes clean override semantics).
- KB articles + revisions: ONLY through `Cairnloop.KnowledgeBase.create_article/1` + `save_draft/2` + `publish_revision/1`. Never `Repo.insert!(%Revision{})` — that skips the Oban enqueue (D-09).
- Wrap each insert path in a `get_or_insert_*!` helper that does `Repo.get_by` first (D-02 idempotency).
- End with `Oban.drain_queue(queue: :default, with_recursion: true)` and log a warning if `failure > 0` (D-08).
- Builder names match D-01 exactly: `build_articles/0`, `build_conversations/1`, `build_gaps/1`, `build_suggestion/2` (RESEARCH.md recommends renaming to `build_suggestion_with_review_task/2` — planner's call), `drain_embedding_pipeline/0`.
- For `:resolved` conversations whose closing message is `role: :system_outbound`, always include `metadata: %{"template_id" => "demo_resolve_confirm"}` (Pitfall 6) — or simply use `role: :agent` for the closing message (RESEARCH.md recommendation).
- For the seeded `ArticleSuggestion`, follow up immediately with `KnowledgeAutomation.ensure_review_task_for_suggestion(suggestion.id, …)` — without this the `SuggestionReview` LiveView shows an empty queue (Critical Finding 2 / Pitfall 1).

**What the executor deliberately does NOT copy:**
- The existing `seeds.exs`'s `Ecto.Changeset.change(%Schema{}, attrs)` style — it bypasses validations. Switch to `Schema.changeset(%Schema{}, attrs)`.
- The existing `seeds.exs`'s direct `%Revision{}` insert (line 41–49) — that's exactly the FIX-02-breaking anti-pattern. Use the facade.
- `Repo.insert_all/3` — bypasses changesets (RESEARCH.md "Alternatives Considered" rejects this).
- `on_conflict: :nothing` / `:replace_all` — D-02 mandates explicit `Repo.get_by` guards.
- Synchronous in-line `ChunkRevision.perform(%Oban.Job{…})` invocation — RESEARCH.md "Don't Hand-Roll" rejects this in favor of `drain_queue/1` (preserves job lifecycle, telemetry, return shape).
- Do NOT call `KnowledgeAutomation.suggest_article/1` to create the suggestion — it enqueues `Workers.GenerateArticleSuggestion` which makes an LLM call (D-15). Direct `Repo.insert` of `%ArticleSuggestion{}` only.
- Do NOT run `CandidateBuilder` (D-13) or `Workers.GenerateArticleSuggestion` (D-15) from the seeds.
- Do NOT set `Cairnloop.Message.run_key` to anything but `nil` — the example app's migration does not add the column (Pitfall 5).

**Pattern divergences the planner must call out in PLAN.md:**
1. **CONTEXT.md vs schema enum names:** D-15 says `status: :ready_for_review` and `suggestion_type: :new_article`; the actual schema enums are `:ready` and `:article` (verified `lib/cairnloop/knowledge_automation/article_suggestion.ex:7-9`). The planner MUST add a spec-language→actual-enum mapping table to PLAN.md (same shape as D-05's `:deprecated`→`:archived` ratification). See RESEARCH.md Pitfall 2 and Assumption A1.
2. **`host_user_id` is overloaded:** seeded `GapCandidate`/`ArticleSuggestion`/`ReviewTask` rows must use `host_user_id: "demo_operator"` (matches `router.ex:20`'s live_session); seeded `Conversation.host_user_id` uses customer-identifying values like `"demo_user_acme_billing"` (drives `ContextProvider`). Mixing these collapses the gap queue / suggestion queue (Pitfall 3).
3. **Articles need `## h2` / `### h3` headings** or `MarkdownParser` produces only 1 chunk per article (Pitfall 4). Each of the 5 articles should have ≥2–3 h2 sections.
4. **`Ecto.Changeset.change/2` vs `Schema.changeset/2`:** the existing seed file uses `change/2` (which skips validations). The new seed must use `Schema.changeset/2` (which runs validations like `validate_template_id_for_outbound/1`). This is a silent behavior change worth a one-liner in PLAN.md so the executor doesn't accidentally copy the old idiom.

---

### `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` (test, DB integration)

**Analog (composite — no single existing analog):**
- **Example-app DB-test wiring:** `examples/cairnloop_example/test/cairnloop_example_web/controllers/page_controller_test.exs` (the only existing example-app test file, but it uses `ConnCase`, not `DataCase`).
- **DB sandbox + assertion style:** `examples/cairnloop_example/test/support/data_case.ex` (the test case template the new test must use) + library `test/cairnloop/knowledge_automation/gap_candidate_test.exs` (changeset/assertion style).

**Test case template to use** (`examples/cairnloop_example/test/support/data_case.ex:19-41`):
```elixir
  using do
    quote do
      alias CairnloopExample.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import CairnloopExample.DataCase
    end
  end

  setup tags do
    CairnloopExample.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(CairnloopExample.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end
```

**Test-helper sandbox mode** (`examples/cairnloop_example/test/test_helper.exs:1-2`):
```elixir
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(CairnloopExample.Repo, :manual)
```

**Assertion style example** (`test/cairnloop/knowledge_automation/gap_candidate_test.exs:55-77`):
```elixir
  test "gap candidate changeset accepts stable identity, freshness, counts, and score metadata" do
    changeset =
      GapCandidate.changeset(%GapCandidate{}, %{
        stable_key: String.duplicate("abc12345", 2),
        status: :open,
        candidate_type: :mixed,
        title: "Billing export",
        seed_excerpt: "billing export",
        tenant_scope: :host_user_scoped,
        host_user_id: "user-1",
        ui_surface: :conversation,
        first_seen_at: ~U[2026-05-20 10:00:00Z],
        last_seen_at: ~U[2026-05-21 10:00:00Z],
        evidence_count: 4,
        manual_case_count: 2,
        weak_grounding_count: 1,
        no_hit_count: 1,
        score: 8.5,
        score_components: %{"manual_handling" => 5.0}
      })

    assert changeset.valid?
  end
```

**What the executor mimics:**
- `use CairnloopExample.DataCase, async: false` (seeds touch shared Oban state; not safe to parallelize).
- `setup_sandbox(tags)` from the `DataCase.using` block gives a checked-out sandbox connection.
- Run the seed via `Code.eval_file("priv/repo/seeds.exs")` (RESEARCH.md Wave 0 Gaps, simpler than refactoring seed into a module).
- After eval, assert with `Repo.aggregate(Cairnloop.Conversation, :count)` / `Repo.aggregate(Cairnloop.KnowledgeBase.Chunk, :count)` etc. against the FIX-* thresholds (`>= 16` conversations, `>= 5` articles, `>= 6` revisions with `>= 1` `:archived`, `>= 3` gap candidates, `>= 1` `:ready` suggestion with companion `ReviewTask{status: :pending_review}`, `cairnloop_chunks` non-empty after drain).
- Add an idempotency test: `for _ <- 1..2, do: Code.eval_file("priv/repo/seeds.exs")` then assert row counts equal post-first-run counts (D-02).

**What the executor deliberately does NOT copy:**
- The `MockRepo` pattern from `gap_candidate_test.exs:7-33` — that's a headless library trick for when `Cairnloop.Repo` is unavailable. The example-app integration test has a real `CairnloopExample.Repo` available via the sandbox, so it can (and must) use real inserts.
- `async: true` — the seed script flips Oban queue state and shared application env; serial-only.
- `ConnCase` (used by `page_controller_test.exs`) — this test makes no HTTP calls; `DataCase` is the right base.
- `Process.sleep`/polling — Oban runs `testing: :manual` under `MIX_ENV=test` (`examples/cairnloop_example/config/test.exs:2`); the seed's call to `Oban.drain_queue/1` runs jobs synchronously and returns the result map. Assert against the return value, not background timing (Pitfall 7).

**Pattern divergences the planner must call out:**
1. **`Cairnloop.Repo` is unavailable** — the test must use `CairnloopExample.Repo` for all queries (verified `test_helper.exs:2`). The library facade `Cairnloop.KnowledgeBase` reads from `Application.fetch_env!(:cairnloop, :repo)` which is wired to `CairnloopExample.Repo` in `config.exs:60`. Calls into the facade from the test "just work" — but raw `Repo.aggregate(...)` calls in the test body must say `CairnloopExample.Repo.aggregate(...)`.
2. **Sandbox ownership and `Code.eval_file/1`:** the eval'd seed script runs in the test process, so it inherits the sandboxed connection automatically. No need for `Sandbox.allow/3` calls. But because the script's `Oban.drain_queue/1` call also runs synchronously in-process, the Oban worker callbacks also see the same sandbox connection — this is exactly what makes the integration test viable.
3. **`mix test.integration` cannot host this** — RESEARCH.md Critical Finding 3 + Assumption A5: the library's `test.integration` setup wires `Cairnloop.Repo` (test_host), not `CairnloopExample.Repo`. The test MUST live at `examples/cairnloop_example/test/cairnloop_example/seeds_test.exs` and run under `cd examples/cairnloop_example && mix test`.

---

### `examples/cairnloop_example/config/config.exs` (config, additive line)

**Analog:** the file itself, lines 59–61 — the existing `config :cairnloop, …` block.

**Pattern to mimic** (`examples/cairnloop_example/config/config.exs:59-61`):
```elixir
config :cairnloop,
  repo: CairnloopExample.Repo,
  tools: [Cairnloop.Tools.InternalNote]
```

**What the executor mimics:**
- Extend the existing `config :cairnloop, …` block with one key: `context_provider: CairnloopExample.DemoContextProvider`. Result:
```elixir
config :cairnloop,
  repo: CairnloopExample.Repo,
  tools: [Cairnloop.Tools.InternalNote],
  context_provider: CairnloopExample.DemoContextProvider
```
- Configured-adapter pattern (matches every other `:cairnloop, :<adapter>` slot the library exposes — `:repo`, `:tools`, `:embedder`, `:automation_policy`, …).

**What the executor deliberately does NOT copy:**
- Do NOT add a second `config :cairnloop, :context_provider, …` line — extend the existing keyword list block to keep the file scannable and avoid duplicate-key warnings on config merge.
- Do NOT wire the provider in any library-side config — D-11 mandates example-app-only. The library's tests rely on `DefaultContextProvider` falling through via `Application.get_env(:cairnloop, :context_provider, DefaultContextProvider)` at `conversation_live.ex:358`.
- Do NOT add the wire to `examples/cairnloop_example/config/test.exs` separately — `config.exs` is loaded first and `test.exs` is loaded last (line 65 import); the dev/prod/test all inherit the wire from `config.exs`.

---

## Shared Patterns

### Idempotent natural-key seed guards (D-02)

**Source:** D-02 + RESEARCH.md Pattern 1 (no existing analog in the codebase — this is a new pattern Phase 27 introduces; documented because it applies to every direct-insert call in the new `seeds.exs`).

**Apply to:** Every direct-insert in `seeds.exs`: conversations, messages, articles, gap candidates, memberships, retrieval gap events (if seeded), article suggestion, review task.

```elixir
defp get_or_insert!(schema, natural_key_field, attrs, repo \\ CairnloopExample.Repo) do
  case repo.get_by(schema, [{natural_key_field, Map.fetch!(attrs, natural_key_field)}]) do
    nil ->
      schema.__struct__()
      |> schema.changeset(attrs)
      |> repo.insert!()

    existing ->
      existing
  end
end
```

Natural keys per schema:
- `Conversation` → `:subject` (with `[demo-NN]` prefix per D-02 + RESEARCH.md "Specific Ideas")
- `Article` → `:title`
- `GapCandidate` → `:stable_key`
- `ArticleSuggestion` → `:stable_key`
- `Message` → no clean natural key; idempotency handled by skipping message insert if its conversation already exists (the `Repo.get_by` on `Conversation.subject` short-circuits the whole conversation+messages block).
- `ReviewTask` → use `KnowledgeAutomation.ensure_review_task_for_suggestion/2` which is itself idempotent (returns existing active task per `lib/cairnloop/knowledge_automation.ex:128-129`).

### Operator/brand voice in seeded copy (C-08 / D-12 / D-18)

**Source:** `prompts/cairnloop_brand_book.md` §5 / §7.5 (canonical authority — no existing source-code analog because every seeded string is new prose).

**Apply to:** All conversation subjects, all message bodies (customer + agent + outbound), all article titles + bodies, the article suggestion `title`/`operator_summary`/`proposed_markdown`, and every value in the `DemoContextProvider` returned maps.

Voice rules to apply:
- Calm, fail-closed, reason-forward, honest.
- No raw Elixir atoms (`:open`, `:ready`, `:archived`) in customer or operator copy.
- No raw JSON.
- State by label, never by color alone.
- Internal-note message bodies (`role: :internal_note`) are the only carve-out — they may reference IDs and typed terms (D-18).

### Sealed-enum reconciliation (D-04, D-05, A1)

**Source:** D-04/D-05 + Pitfall 2.

**Apply to:** Every seed insert that uses an enum field.

Spec language → actual enum mapping (the planner must include this table verbatim in PLAN.md):

| Spec language (CONTEXT.md / roadmap) | Actual schema enum | Schema location |
|--------------------------------------|--------------------|-----------------|
| `:new` (Conversation JTBD) | derived: `status: :open` + 0 `:agent` msgs | `lib/cairnloop/conversation.ex:6` |
| `:awaiting_customer` (Conversation JTBD) | derived: `status: :open` + last msg `role: :agent` | `lib/cairnloop/conversation.ex:6` |
| `:deprecated` (Revision) | `state: :archived` | `lib/cairnloop/knowledge_base/revision.ex:8` |
| `:ready_for_review` (ArticleSuggestion) | `status: :ready` | `lib/cairnloop/knowledge_automation/article_suggestion.ex:7` |
| `:new_article` (ArticleSuggestion) | `suggestion_type: :article` | `lib/cairnloop/knowledge_automation/article_suggestion.ex:8` |

### Evidence-digest computation (D-16)

**Source:** `lib/cairnloop/knowledge_automation.ex:961-976` (`evidence_digest_for/1`, the production algorithm).

**Apply to:** The single seeded `ArticleSuggestion`'s `evidence_digest` field — must match the production algorithm or the suggestion will appear "out of sync" if `CandidateBuilder` ever re-computes the digest in a future phase.

```elixir
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

Field order (`source_type, trust_level, title, excerpt, citation_target, match_reasons`) is load-bearing — `metadata` is deliberately excluded from the digest (it's included in `serialize_evidence_snapshot/1` for storage, but NOT in the digest). The seed must inline this helper (it's a private function in `KnowledgeAutomation`).

---

## No Analog Found

The following pattern has no in-tree analog and the planner should treat RESEARCH.md as the authoritative source:

| File / pattern | Reason no analog exists |
|----------------|-------------------------|
| The full `seeds.exs` rewrite as an idempotent fixture script | No existing seed in the repo demonstrates `Repo.get_by`-guarded idempotency, multi-revision article progression, or end-of-script `Oban.drain_queue/1`. The pattern is assembled from production code (`KnowledgeBase` facade), test fixtures (`test/support/fixtures.ex` direct-insert idiom), and Oban's library documentation. RESEARCH.md Patterns 1–5 (lines 281–420) capture the assembled pattern. |
| The DB-backed seeds-smoke test pattern | No existing test in `examples/cairnloop_example/test/` uses `DataCase` (only `ConnCase` for the page controller). The pattern is assembled from `DataCase`'s own definition + library-side changeset assertion style. |

---

## Metadata

**Analog search scope:**
- `lib/cairnloop/context_provider.ex` and `lib/cairnloop/default_context_provider.ex` (behaviour + default impl)
- `lib/cairnloop/knowledge_base.ex` (facade)
- `lib/cairnloop/knowledge_automation.ex` (focused reads at lines 100–180 and 958–976)
- `lib/cairnloop/embedder/external_api.ex` (zero-vector fallback)
- `lib/cairnloop/conversation.ex`, `lib/cairnloop/message.ex`, `lib/cairnloop/knowledge_base/article.ex`, `lib/cairnloop/knowledge_base/revision.ex` (sealed enums)
- `lib/cairnloop/knowledge_automation/{gap_candidate,gap_candidate_membership,article_suggestion,article_suggestion_evidence}.ex` (direct-insert schemas)
- `lib/cairnloop/retrieval/gap_event.ex` (optional `RetrievalGapEvent` seed)
- `test/cairnloop/context_provider_test.exs` (headless test template)
- `test/cairnloop/knowledge_automation/{gap_candidate_test.exs, article_suggestion_test.exs:1260-1338}` (changeset + attrs shape)
- `test/support/fixtures.ex` (direct-insert idiom)
- `examples/cairnloop_example/priv/repo/seeds.exs` (the file being rewritten — current state for delta clarity)
- `examples/cairnloop_example/config/config.exs` (the file being extended)
- `examples/cairnloop_example/lib/cairnloop_example_web/router.ex` (operator scope verification)
- `examples/cairnloop_example/test/test_helper.exs` + `test/support/data_case.ex` + `test/cairnloop_example_web/controllers/page_controller_test.exs` (example-app test wiring)

**Files scanned:** 19

**Pattern extraction date:** 2026-05-27
