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

  # v2 marker for article 5 idempotency check (D-05 / Plan 27-03)
  @v2_marker "Rotate every 90 days"

  # Builds 5 Trailmark KB articles with multiple revisions (including one :archived).
  # Returns %{api_key: %Article{}, billing_email: %Article{}, seat: %Article{},
  #           ci_skipped: %Article{}, token_rotation: %Article{}}
  # for downstream builders.
  #
  # Each article is created via the KnowledgeBase facade (D-09):
  #   get_or_insert!(Article, :title, ...) for the article row,
  #   KnowledgeBase.save_draft/2 + KnowledgeBase.publish_revision/1 for each revision.
  # publish_revision/1 is the load-bearing call that enqueues ChunkRevision into Oban (FIX-02).
  # Idempotency: each article checks for an existing published revision before publishing (D-02).
  # Article 5 runs a v1-published → v1-archived → v2-published progression (D-05).
  defp build_articles do
    import Ecto.Query

    # -------------------------------------------------------------------------
    # Article 1: Resetting your Trailmark API key
    # -------------------------------------------------------------------------
    api_key_article = get_or_insert!(Article, :title, %{
      title: "Resetting your Trailmark API key",
      status: :draft
    })

    unless Repo.one(from r in Revision, where: r.article_id == ^api_key_article.id and r.state == :published, limit: 1) do
      body = """
      ## Reset steps

      To reset your API key, navigate to **Settings > API Keys** in your Trailmark dashboard.
      Click **Revoke** next to the key you want to retire, then select **Generate new key**.
      Copy the new key and update any integrations that used the previous one.

      ## When to contact support

      If the revoke button is unavailable, or you suspect your key was compromised before
      you could revoke it, contact support immediately. Include the approximate time of the
      suspected exposure so we can check your activity log.

      ## Notes

      Trailmark API keys are single-use secrets: they are shown once at generation time and
      cannot be retrieved again. Store your key in a secrets manager, not in source control.
      """

      {:ok, draft} = KnowledgeBase.save_draft(api_key_article, %{content: body})
      {:ok, _published} = KnowledgeBase.publish_revision(draft)
    end

    api_key_article = Repo.get!(Article, api_key_article.id)

    # -------------------------------------------------------------------------
    # Article 2: Updating your billing email
    # -------------------------------------------------------------------------
    billing_email_article = get_or_insert!(Article, :title, %{
      title: "Updating your billing email",
      status: :draft
    })

    unless Repo.one(from r in Revision, where: r.article_id == ^billing_email_article.id and r.state == :published, limit: 1) do
      body = """
      ## Update your billing email

      Go to **Settings > Billing** and click **Edit** next to your current billing address.
      Enter the new email address and confirm. Trailmark will send a verification link to
      the new address before the change takes effect.

      ## What happens to invoices

      Invoices already sent to your old address remain accessible in the billing portal.
      Future invoices — and any payment failure notifications — will go to the new verified
      address. The change takes effect as soon as you click the verification link.
      """

      {:ok, draft} = KnowledgeBase.save_draft(billing_email_article, %{content: body})
      {:ok, _published} = KnowledgeBase.publish_revision(draft)
    end

    billing_email_article = Repo.get!(Article, billing_email_article.id)

    # -------------------------------------------------------------------------
    # Article 3: Adding a team seat
    # -------------------------------------------------------------------------
    seat_article = get_or_insert!(Article, :title, %{
      title: "Adding a team seat",
      status: :draft
    })

    unless Repo.one(from r in Revision, where: r.article_id == ^seat_article.id and r.state == :published, limit: 1) do
      body = """
      ## Invite a teammate

      Open **Settings > Team** and click **Invite a teammate**. Enter the person's work
      email address and choose their role. Trailmark sends an invitation email; the seat
      is active once they accept.

      ## When approval is required

      On accounts with seat-approval policies, an owner or admin must confirm the
      invitation before it is sent. If your invitation is pending approval you will see
      a "Waiting for approval" status in the Team panel. Reach out to your account owner
      if the approval is taking longer than expected.

      ## Removing a seat

      To remove a teammate, click **…** next to their name in the Team panel and choose
      **Remove member**. Their access is revoked immediately. Any data they created
      remains in the account.
      """

      {:ok, draft} = KnowledgeBase.save_draft(seat_article, %{content: body})
      {:ok, _published} = KnowledgeBase.publish_revision(draft)
    end

    seat_article = Repo.get!(Article, seat_article.id)

    # -------------------------------------------------------------------------
    # Article 4: Why a CI run was skipped
    # -------------------------------------------------------------------------
    ci_skipped_article = get_or_insert!(Article, :title, %{
      title: "Why a CI run was skipped",
      status: :draft
    })

    unless Repo.one(from r in Revision, where: r.article_id == ^ci_skipped_article.id and r.state == :published, limit: 1) do
      body = """
      ## Why this happens

      Trailmark skips a CI run when it determines no relevant files changed relative to the
      base commit, or when a prior run on the same commit SHA already has a final result.
      This is normal behaviour and does not indicate an error.

      ## How to investigate

      Open the run detail page and check the **Skip reason** field at the top. Common
      reasons include: "no diffed paths matched configured triggers", "cached result
      reused", and "manual skip requested". If the reason is unexpected, check your
      trigger configuration under **Project > Settings > CI Triggers**.

      ## Common causes

      - A push contained only documentation or comment changes not covered by your trigger
        path patterns.
      - A previous run on the same commit SHA already succeeded; Trailmark reuses its
        result to avoid duplicate billing.
      - A team member used the API to mark the run skipped for a hotfix deploy.
      """

      {:ok, draft} = KnowledgeBase.save_draft(ci_skipped_article, %{content: body})
      {:ok, _published} = KnowledgeBase.publish_revision(draft)
    end

    ci_skipped_article = Repo.get!(Article, ci_skipped_article.id)

    # -------------------------------------------------------------------------
    # Article 5: Rotating an expired token (multi-revision progression D-05)
    # v1 published → v1 archived → v2 published (≥1 :archived revision for FIX-02)
    # Idempotency: skip entire progression if v2 marker found in a :published revision
    #              AND at least one :archived revision exists.
    # -------------------------------------------------------------------------
    token_rotation_article = get_or_insert!(Article, :title, %{
      title: "Rotating an expired token",
      status: :draft
    })

    archived_count = Repo.aggregate(
      from(r in Revision, where: r.article_id == ^token_rotation_article.id and r.state == :archived),
      :count
    )

    v2_exists = Repo.one(
      from r in Revision,
        where:
          r.article_id == ^token_rotation_article.id and
          r.state == :published and
          like(r.content, ^"%#{@v2_marker}%"),
        limit: 1
    )

    unless archived_count >= 1 and v2_exists do
      v1_body = """
      ## Old guidance

      Rotate every 30 days.

      ## Notes

      This guidance is being updated; see the latest article for the current rotation window.
      """

      {:ok, draft_v1} = KnowledgeBase.save_draft(token_rotation_article, %{content: v1_body})
      {:ok, published_v1} = KnowledgeBase.publish_revision(draft_v1)

      # Archive v1: state-only transition — Revision.changeset only blocks content edits
      # on already-published rows, not state-only transitions.
      published_v1
      |> Revision.changeset(%{state: :archived})
      |> Repo.update!()

      v2_body = """
      ## Current guidance

      #{@v2_marker}.

      ## Why this changed

      90-day rotation balances security with operational stability. Shorter rotation windows
      created unnecessary friction without a proportional security benefit for most Trailmark
      use cases.

      ## How to rotate

      Go to **Settings > API Keys**, click **Revoke** on the token you want to retire, then
      select **Generate new key**. Update your integrations with the new token before the
      old one expires.
      """

      {:ok, draft_v2} = KnowledgeBase.save_draft(token_rotation_article, %{content: v2_body})
      {:ok, _published_v2} = KnowledgeBase.publish_revision(draft_v2)
    end

    token_rotation_article = Repo.get!(Article, token_rotation_article.id)

    %{
      api_key: api_key_article,
      billing_email: billing_email_article,
      seat: seat_article,
      ci_skipped: ci_skipped_article,
      token_rotation: token_rotation_article
    }
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
