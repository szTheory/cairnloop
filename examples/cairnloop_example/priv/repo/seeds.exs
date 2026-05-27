# ============================================================================
# Cairnloop Example App — Demo Seed Script
# ============================================================================
#
# Run via:
#   cd examples/cairnloop_example && mix run priv/repo/seeds.exs
#   (or automatically via `mix setup` / `mix ecto.setup`)
#
# Wrapped in a module so private helpers can be defp'd; not added to lib/ — this remains a script.
#
# ----------------------------------------------------------------------------
# IDEMPOTENCY CONTRACT (D-02)
# ----------------------------------------------------------------------------
# Re-running this script against an already-seeded DB is a no-op. Every insert
# is guarded by `Repo.get_by` on a natural key. No `on_conflict` magic.
#
# ----------------------------------------------------------------------------
# OPENAI_API_KEY NOTE (D-06)
# ----------------------------------------------------------------------------
# Set `OPENAI_API_KEY` before `mix setup` for semantically ranked search;
# otherwise zero-vector embeddings are written via the existing dev-safety
# fallback in `Cairnloop.Embedder.ExternalApi`.
#
# ----------------------------------------------------------------------------
# END-OF-SCRIPT OBAN DRAIN (D-08)
# ----------------------------------------------------------------------------
# After all builders run, `Oban.drain_queue(queue: :default, with_recursion: true)`
# synchronously executes every enqueued `ChunkRevision` job so the M008 substrate
# self-test completes before this script exits.
#
# ----------------------------------------------------------------------------
# FACADE RULE (D-09)
# ----------------------------------------------------------------------------
# Articles + revisions go ONLY through `Cairnloop.KnowledgeBase.create_article/1`,
# `save_draft/2`, `publish_revision/1`. Bypassing the facade with a direct
# `%Revision{}` insert skips the Multi that enqueues `ChunkRevision` and
# silently breaks FIX-02.
#
# ----------------------------------------------------------------------------
# SEALED-ENUM RECONCILIATION TABLE (D-04, D-05, A1)
# ----------------------------------------------------------------------------
# Spec language in CONTEXT.md / roadmap maps to actual schema enum values as
# follows — do NOT propose schema migrations to add the spec-language values;
# they are sealed-contract forbidden in vM014.
#
#  Spec language (roadmap / CONTEXT)          | Actual schema enum / derived state        | Schema location
#  -------------------------------------------|-------------------------------------------|--------------------------------------------
#  :new (Conversation JTBD)                   | derived: status: :open + 0 :agent msgs    | lib/cairnloop/conversation.ex:6
#  :awaiting_customer (Conversation JTBD)     | derived: status: :open + last msg :agent  | lib/cairnloop/conversation.ex:6
#  :deprecated (Revision)                     | state: :archived                          | lib/cairnloop/knowledge_base/revision.ex
#  :ready_for_review (ArticleSuggestion)      | status: :ready                            | lib/cairnloop/knowledge_automation/article_suggestion.ex:7
#  :new_article (ArticleSuggestion type)      | suggestion_type: :article                 | lib/cairnloop/knowledge_automation/article_suggestion.ex:8
#
# ----------------------------------------------------------------------------
# CONCURRENCY CAVEAT (Pitfall 8)
# ----------------------------------------------------------------------------
# `mix run` starts the Application by default (Oban supervisor up — required by
# the drain). Do not run this script while `mix phx.server` holds port 4000.
#
# ----------------------------------------------------------------------------
# SCHEMA MIGRATION CAVEAT (Pitfall 5)
# ----------------------------------------------------------------------------
# Never set `Cairnloop.Message.run_key` to a non-nil value — the example app's
# migration does not add the column.
#
# ============================================================================

defmodule CairnloopExample.SeedRun do
  alias CairnloopExample.Repo

  alias Cairnloop.Conversation
  alias Cairnloop.Message
  alias Cairnloop.KnowledgeBase
  alias Cairnloop.KnowledgeBase.Article
  alias Cairnloop.KnowledgeBase.Revision
  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestionEvidence
  alias Cairnloop.KnowledgeAutomation.GapCandidate
  alias Cairnloop.KnowledgeAutomation.GapCandidateMembership
  alias Cairnloop.Retrieval.GapEvent

  # --------------------------------------------------------------------------
  # Public entry point
  # --------------------------------------------------------------------------

  def run do
    articles = build_articles()
    conversations = build_conversations(articles)
    _gaps = build_gaps(conversations)
    {_sugg, _task} = build_suggestion(articles, conversations)
    drain_embedding_pipeline()
  end

  # --------------------------------------------------------------------------
  # Builder functions (D-01 names — do not rename)
  # --------------------------------------------------------------------------

  # Builds 5 Trailmark KB articles with multiple revisions (including one :archived).
  # Returns %{api_key: %Article{}, billing_email: %Article{}, seat: %Article{},
  #           ci_skipped: %Article{}, token_rotation: %Article{}}
  # for downstream builders.
  # TODO: filled by 27-03-PLAN.md (FIX-02 articles + revisions)
  defp build_articles do
    %{}
  end

  # Builds 16 conversations across 4 JTBD cohorts (new / open / awaiting_customer / resolved).
  # Accepts the articles map from build_articles/0 for topic distribution (D-19).
  # Returns a list of inserted %Conversation{} rows so downstream builders can reference them.
  # TODO: filled by 27-04-PLAN.md (FIX-01 16 conversations × 4 JTBD cohorts)
  defp build_conversations(_articles) do
    []
  end

  # Builds 3+ GapCandidates with memberships and RetrievalGapEvent back-references.
  # Accepts the conversations list from build_conversations/1 for membership source_id wiring.
  # Returns list of inserted %GapCandidate{} rows.
  # TODO: filled by 27-05-PLAN.md (FIX-03 ≥3 GapCandidates + memberships + RetrievalGapEvent)
  defp build_gaps(_conversations) do
    []
  end

  # Builds 1 ArticleSuggestion with status :ready (spec: :ready_for_review) + evidence rows
  # + a ReviewTask so SuggestionReview LiveView renders without waiting for the LLM worker.
  # Returns {%ArticleSuggestion{}, %ReviewTask{}}.
  # (nil, nil at skeleton stage — the real plan returns real structs)
  # TODO: filled by 27-06-PLAN.md (FIX-04 1 ArticleSuggestion :ready + evidence + ReviewTask)
  defp build_suggestion(_articles, _conversations) do
    {nil, nil}
  end

  # Synchronously drains the :default Oban queue after all builders complete.
  # This is the M008 substrate self-test — ChunkRevision jobs enqueued by
  # KnowledgeBase.publish_revision/1 write chunks to pgvector via the live worker.
  defp drain_embedding_pipeline do
    %{success: success, failure: failure, snoozed: _, cancelled: _, discard: _} =
      Oban.drain_queue(queue: :default, with_recursion: true)

    if failure > 0 do
      IO.warn(
        "Seed embedding pipeline drained with #{failure} failures. " <>
          "Inspect oban_jobs.errors for details."
      )
    end

    IO.puts("Drained #{success} embedding jobs.")
  end

  # --------------------------------------------------------------------------
  # Idempotency helper (D-02)
  # --------------------------------------------------------------------------
  # Usage: get_or_insert!(SchemaModule, :natural_key_field, %{natural_key_field: "value", ...})
  # Raises clearly if `natural_key_field` is absent from attrs (Map.fetch! semantics).
  defp get_or_insert!(schema_module, natural_key_field, attrs) do
    case Repo.get_by(schema_module, [{natural_key_field, Map.fetch!(attrs, natural_key_field)}]) do
      nil ->
        struct(schema_module)
        |> schema_module.changeset(attrs)
        |> Repo.insert!()

      existing ->
        existing
    end
  end
end

CairnloopExample.SeedRun.run()
