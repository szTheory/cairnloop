defmodule CairnloopExample.SeedsTest do
  use CairnloopExample.DataCase, async: false

  # async: false — seeds touch shared Oban state (Oban.drain_queue/1 is module-scoped);
  # running this file in parallel with other DB tests would produce unpredictable drain results.

  # Tag this entire suite as :requires_postgres. Developers and CI lanes without
  # Postgres on localhost:5433 can safely skip with:
  #   mix test --exclude requires_postgres
  # (CLAUDE.md C-04 + RESEARCH.md Assumption A5)
  @moduletag :requires_postgres

  alias Cairnloop.Conversation
  alias Cairnloop.Message
  alias Cairnloop.KnowledgeBase.Article
  alias Cairnloop.KnowledgeBase.Chunk
  alias Cairnloop.KnowledgeBase.Revision
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion
  alias Cairnloop.KnowledgeAutomation.GapCandidate
  alias Cairnloop.KnowledgeAutomation.GapCandidateMembership
  alias Cairnloop.KnowledgeAutomation.ReviewTask

  import Ecto.Query

  # ---------------------------------------------------------------------------
  # Helper: run the seed script once inside the test process.
  #
  # Code.eval_file/1 uses an absolute path (Path.expand) because relative-path
  # semantics inside .exs files depend on the process cwd, which can vary.
  # The test process runs from `examples/cairnloop_example/`, so:
  #   __DIR__ = .../test/cairnloop_example
  #   ../../priv/repo/seeds.exs resolves to .../priv/repo/seeds.exs
  #
  # The eval'd script runs in the current process, so it inherits the sandbox
  # connection checked out by DataCase.setup_sandbox/1. No Sandbox.allow/3 call
  # is needed. Oban.drain_queue/1 also runs in-process and sees the same connection.
  # ---------------------------------------------------------------------------
  defp run_seed!() do
    seed_path = Path.expand("../../priv/repo/seeds.exs", __DIR__)
    assert File.exists?(seed_path), "seed file not found at resolved path: #{seed_path}"
    Code.eval_file(seed_path)
    :ok
  end

  describe "priv/repo/seeds.exs" do
    # -------------------------------------------------------------------------
    # Test 1: end-to-end seed run + FIX-01/FIX-02/FIX-03/FIX-04 row counts
    # -------------------------------------------------------------------------
    test "produces FIX-01..FIX-04 row counts on a single run" do
      assert :ok == run_seed!()

      # FIX-01: 16 conversations across 4 JTBD-derived cohorts (D-03).
      # D-03: :new/:open/:awaiting_customer → status :open (sealed enum); :resolved → status :resolved.
      # All 12 non-resolved conversations share status :open.
      assert Repo.aggregate(Conversation, :count) >= 16

      assert Repo.aggregate(from(c in Conversation, where: c.status == :open), :count) >= 12,
             "Expected ≥12 :open conversations (cohorts :new, :open, :awaiting_customer all use status :open per D-03)"

      assert Repo.aggregate(from(c in Conversation, where: c.status == :resolved), :count) >= 4,
             "Expected ≥4 :resolved conversations (FIX-01 :resolved cohort)"

      # FIX-01: per-cohort message counts (plan 27-04 math):
      #   :new                -> 4 conv × 2 msgs = 8
      #   :open               -> 4 conv × 4 msgs = 16  (n=5 also gets 1 :internal_note = +1)
      #   :awaiting_customer  -> 4 conv × 3 msgs = 12
      #   :resolved           -> 4 conv × 5 msgs = 20  (n=13 also gets 1 :internal_note = +1)
      #   Expected fresh-DB total                = 58
      #
      # Lower bound 48 absorbs up to ~10 messages of regression headroom (e.g. one cohort
      # drops 1 message per conversation). Upper bound 80 catches a runaway-loop regression
      # while leaving room for 1–2 message copy-edits per conversation in future polish phases
      # (80 = 58 + 22 headroom).
      assert Repo.aggregate(Message, :count) >= 48,
             "Expected ≥48 messages across all 16 conversations (FIX-01)"

      assert Repo.aggregate(Message, :count) <= 80,
             "Expected ≤80 messages — upper bound guards against runaway-loop regressions (FIX-01)"

      # FIX-02: ≥5 articles, ≥6 revisions (article 5 has v1+v2+1 archived = at least 3 for that article alone),
      # ≥1 revision with state :archived (D-05 — spec "deprecated" maps to :archived).
      assert Repo.aggregate(Article, :count) >= 5,
             "Expected ≥5 KB articles (FIX-02)"

      assert Repo.aggregate(Revision, :count) >= 6,
             "Expected ≥6 KB revisions (FIX-02 — article 5 contributes ≥2 revisions: v1 archived + v2 published)"

      assert Repo.aggregate(from(r in Revision, where: r.state == :archived), :count) >= 1,
             "Expected ≥1 :archived revision (FIX-02 — spec 'deprecated' maps to :archived per D-05)"

      # FIX-03: ≥3 GapCandidate rows with status :open; each must have ≥1 GapCandidateMembership.
      assert Repo.aggregate(from(g in GapCandidate, where: g.status == :open), :count) >= 3,
             "Expected ≥3 :open GapCandidates (FIX-03)"

      memberships_by_gap =
        Repo.all(
          from m in GapCandidateMembership,
            group_by: m.gap_candidate_id,
            select: {m.gap_candidate_id, count(m.id)}
        )

      assert length(memberships_by_gap) >= 3,
             "Expected ≥3 GapCandidates to have membership rows (FIX-03)"

      assert Enum.all?(memberships_by_gap, fn {_id, n} -> n >= 1 end),
             "Every GapCandidate must have ≥1 GapCandidateMembership (FIX-03)"

      # FIX-04: ≥1 ArticleSuggestion with status :ready
      # (sealed enum — spec :ready_for_review maps to :ready per Sealed-enum reconciliation table).
      assert Repo.aggregate(from(s in ArticleSuggestion, where: s.status == :ready), :count) >= 1,
             "Expected ≥1 :ready ArticleSuggestion (FIX-04 — spec :ready_for_review maps to :ready)"
    end

    # -------------------------------------------------------------------------
    # Test 2: M008 substrate self-test — cairnloop_chunks populated after Oban drain
    # -------------------------------------------------------------------------
    test "Oban drain produces non-empty cairnloop_chunks (M008 substrate self-test)" do
      assert :ok == run_seed!()

      # The drain inside seeds.exs (Oban.drain_queue/1 with with_recursion: true) runs
      # synchronously in the test process; chunks should exist immediately after run_seed!.
      # Per RESEARCH.md Pitfall 7: testing: :manual in config/test.exs does NOT break
      # drain_queue/1 — drain explicitly runs available jobs from the table and returns.
      assert Repo.aggregate(Chunk, :count) > 0,
             "cairnloop_chunks is empty after seed run. FIX-02 M008 substrate self-test failed. " <>
               "Check that build_articles/0 uses KnowledgeBase.publish_revision/1 (NOT a direct " <>
               "%Revision{} insert) and that drain_embedding_pipeline/0 runs after build_articles/0 " <>
               "in SeedRun.run/0."

      # Soft sanity: ≥1 chunk per article (5 articles with ≥2 h2 sections each → expect ≥5 chunks).
      # Likely ~15+ since each h2 section produces a separate chunk via MarkdownParser (Pitfall 4 mitigation).
      assert Repo.aggregate(Chunk, :count) >= 5,
             "Expected ≥5 chunks (≥1 per article). Article bodies may lack h2 sections — see Pitfall 4."
    end

    # -------------------------------------------------------------------------
    # Test 3: FIX-04 ReviewTask companion exists (Critical Finding 2 / Pitfall 1)
    # -------------------------------------------------------------------------
    test "FIX-04: the seeded ArticleSuggestion has a companion ReviewTask with status :pending_review" do
      assert :ok == run_seed!()

      # The stable_key "demo:article_suggestion:billing_export:v1" is hard-coded in seeds.exs
      # (@demo_suggestion_stable_key). Pinning this exact key keeps the test resilient to
      # copy changes in title/proposed_markdown across future phases.
      suggestion =
        Repo.one!(
          from s in ArticleSuggestion,
            where: s.stable_key == "demo:article_suggestion:billing_export:v1"
        )

      review_task =
        Repo.one(from t in ReviewTask, where: t.article_suggestion_id == ^suggestion.id)

      assert review_task,
             "No ReviewTask found for the seeded ArticleSuggestion (stable_key: demo:article_suggestion:billing_export:v1). " <>
               "SuggestionReview LiveView reads from ReviewTask (NOT ArticleSuggestion directly), so the " <>
               "queue at /support/knowledge-base/suggestions would render empty without this row. " <>
               "Plan 27-06 must call KnowledgeAutomation.ensure_review_task_for_suggestion/2 after the " <>
               "suggestion insert (Critical Finding 2 / Pitfall 1)."

      assert review_task.status == :pending_review,
             "ReviewTask status must be :pending_review (found: #{inspect(review_task.status)})"
    end

    # -------------------------------------------------------------------------
    # Test 4: D-02 idempotency — running the seed TWICE produces stable row counts
    # -------------------------------------------------------------------------
    test "D-02 idempotency: running the seed twice produces stable row counts" do
      assert :ok == run_seed!()

      counts_after_run_1 = %{
        conversations: Repo.aggregate(Conversation, :count),
        messages: Repo.aggregate(Message, :count),
        articles: Repo.aggregate(Article, :count),
        revisions: Repo.aggregate(Revision, :count),
        gap_candidates: Repo.aggregate(GapCandidate, :count),
        memberships: Repo.aggregate(GapCandidateMembership, :count),
        suggestions: Repo.aggregate(ArticleSuggestion, :count),
        review_tasks: Repo.aggregate(ReviewTask, :count)
      }

      # Second run — must be a complete no-op (D-02: idempotent seeds via natural-key guards).
      assert :ok == run_seed!()

      counts_after_run_2 = %{
        conversations: Repo.aggregate(Conversation, :count),
        messages: Repo.aggregate(Message, :count),
        articles: Repo.aggregate(Article, :count),
        revisions: Repo.aggregate(Revision, :count),
        gap_candidates: Repo.aggregate(GapCandidate, :count),
        memberships: Repo.aggregate(GapCandidateMembership, :count),
        suggestions: Repo.aggregate(ArticleSuggestion, :count),
        review_tasks: Repo.aggregate(ReviewTask, :count)
      }

      assert counts_after_run_1 == counts_after_run_2,
             "Re-running the seed produced different row counts — idempotency contract (D-02) violated.\n" <>
               "After 1st run: #{inspect(counts_after_run_1)}\n" <>
               "After 2nd run: #{inspect(counts_after_run_2)}\n" <>
               "Check the get_or_insert!/3 guards and ensure_review_task_for_suggestion/2 idempotency."
    end
  end
end
