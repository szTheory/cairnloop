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
# RUN_KEY COLUMN (formerly Pitfall 5)
# ----------------------------------------------------------------------------
# `Cairnloop.Message.run_key` IS available: migration 20260525201624 adds the
# column (it is host-owned — the library only declares the field). The executed
# governed-action showcase below relies on it, since `Cairnloop.Tools.InternalNote`
# writes a run_key for at-most-once idempotency.
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
  alias Cairnloop.KnowledgeAutomation.GapCandidate
  alias Cairnloop.KnowledgeAutomation.GapCandidateMembership
  alias Cairnloop.Retrieval.GapEvent

  # Showcase-state builders (JTBD stages 4/5/6/8) go through the real facades.
  alias Cairnloop.Automation
  alias Cairnloop.Governance
  alias Cairnloop.Workers.{ApprovalResumeWorker, ToolExecutionWorker}

  # --------------------------------------------------------------------------
  # Public entry point
  # --------------------------------------------------------------------------

  def run do
    IO.puts("Seeding Cairnloop example app demo data...")

    articles = build_articles()
    conversations = build_conversations(articles)
    showcase = build_showcase_states()
    gaps = build_gaps(conversations)
    {suggestion, _review_task} = build_suggestion(articles, conversations)

    drain_summary = drain_embedding_pipeline()

    emit_seed_summary(articles, conversations ++ showcase, gaps, suggestion, drain_summary)
    :ok
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
    api_key_article =
      get_or_insert!(Article, :title, %{
        title: "Resetting your Trailmark API key",
        status: :draft
      })

    unless Repo.one(
             from r in Revision,
               where: r.article_id == ^api_key_article.id and r.state == :published,
               limit: 1
           ) do
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
    billing_email_article =
      get_or_insert!(Article, :title, %{
        title: "Updating your billing email",
        status: :draft
      })

    unless Repo.one(
             from r in Revision,
               where: r.article_id == ^billing_email_article.id and r.state == :published,
               limit: 1
           ) do
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
    seat_article =
      get_or_insert!(Article, :title, %{
        title: "Adding a team seat",
        status: :draft
      })

    unless Repo.one(
             from r in Revision,
               where: r.article_id == ^seat_article.id and r.state == :published,
               limit: 1
           ) do
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
    ci_skipped_article =
      get_or_insert!(Article, :title, %{
        title: "Why a CI run was skipped",
        status: :draft
      })

    unless Repo.one(
             from r in Revision,
               where: r.article_id == ^ci_skipped_article.id and r.state == :published,
               limit: 1
           ) do
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
    token_rotation_article =
      get_or_insert!(Article, :title, %{
        title: "Rotating an expired token",
        status: :draft
      })

    archived_count =
      Repo.aggregate(
        from(r in Revision,
          where: r.article_id == ^token_rotation_article.id and r.state == :archived
        ),
        :count
      )

    v2_exists =
      Repo.one(
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

  # ---------------------------------------------------------------------------
  # JTBD cohort plan (D-03) — 4 cohorts × 4 conversations = 16 total
  #
  # JTBD state is DERIVED from status + message ordering; it is NOT stored.
  # Sealed Conversation.status enum is [:open, :resolved, :archived].
  #
  # Derivation rules:
  #   :new               -> status: :open  + 0 :agent messages
  #   :open              -> status: :open  + has :agent reply + last msg role :user
  #   :awaiting_customer -> status: :open  + has :agent reply + last msg role :agent
  #   :resolved          -> status: :resolved + resolved_at set + last msg :agent | :system_outbound
  #
  # Each conversation's subject is prefixed "[demo-NN]" for idempotency (D-02).
  # host_user_id MUST match one of the 5 demo customer ids from plan 27-02.
  # ---------------------------------------------------------------------------
  @demo_conversations [
    # cohort: :new  (status :open, no :agent reply; 4 rows)
    %{n: 1, cohort: :new, topic: :api_key, host_user_id: "demo_user_acme_billing"},
    %{n: 2, cohort: :new, topic: :billing_email, host_user_id: "demo_user_initech_billing"},
    %{n: 3, cohort: :new, topic: :seat, host_user_id: "demo_user_globex_seats"},
    %{n: 4, cohort: :new, topic: :ci_skipped, host_user_id: "demo_user_umbrella_ci"},
    # cohort: :open  (status :open, has :agent reply, last msg :user; 4 rows)
    %{n: 5, cohort: :open, topic: :api_key, host_user_id: "demo_user_hooli_tokens"},
    %{n: 6, cohort: :open, topic: :billing_email, host_user_id: "demo_user_acme_billing"},
    %{n: 7, cohort: :open, topic: :token_rotation, host_user_id: "demo_user_hooli_tokens"},
    %{n: 8, cohort: :open, topic: :ci_skipped, host_user_id: "demo_user_umbrella_ci"},
    # cohort: :awaiting_customer  (status :open, has :agent reply, last msg :agent; 4 rows)
    %{n: 9, cohort: :awaiting_customer, topic: :seat, host_user_id: "demo_user_globex_seats"},
    %{
      n: 10,
      cohort: :awaiting_customer,
      topic: :billing_email,
      host_user_id: "demo_user_initech_billing"
    },
    %{n: 11, cohort: :awaiting_customer, topic: :api_key, host_user_id: "demo_user_acme_billing"},
    %{
      n: 12,
      cohort: :awaiting_customer,
      topic: :ci_skipped,
      host_user_id: "demo_user_umbrella_ci"
    },
    # cohort: :resolved  (status :resolved, resolved_at set, last msg :agent or :system_outbound; 4 rows)
    # Rows 13/14/15 close with :agent (no template_id required).
    # Row 16 closes with :system_outbound + metadata.template_id = "demo_resolve_confirm" (Pitfall 6).
    %{
      n: 13,
      cohort: :resolved,
      topic: :api_key,
      host_user_id: "demo_user_hooli_tokens",
      csat_rating: :positive,
      closer: :agent
    },
    %{
      n: 14,
      cohort: :resolved,
      topic: :token_rotation,
      host_user_id: "demo_user_hooli_tokens",
      csat_rating: :positive,
      closer: :agent
    },
    %{
      n: 15,
      cohort: :resolved,
      topic: :seat,
      host_user_id: "demo_user_globex_seats",
      csat_rating: nil,
      closer: :agent
    },
    %{
      n: 16,
      cohort: :resolved,
      topic: :billing_email,
      host_user_id: "demo_user_initech_billing",
      csat_rating: :positive,
      closer: :system_outbound
    }
  ]

  # Builds 16 conversations across 4 JTBD cohorts (new / open / awaiting_customer / resolved).
  # Accepts the articles map from build_articles/0 for topic distribution (D-19).
  # Returns a list of inserted %Conversation{} rows so downstream builders can reference them.
  defp build_conversations(articles) do
    Enum.map(@demo_conversations, fn row -> seed_conversation_row(row, articles) end)
  end

  # Idempotent per-row conversation seeder.
  # Conversation matched on subject (natural key, "[demo-NN]" prefix — D-02).
  # Messages are only inserted when the conversation is newly created; re-runs skip them.
  defp seed_conversation_row(row, _articles) do
    subject =
      "[demo-#{String.pad_leading(Integer.to_string(row.n), 2, "0")}] " <>
        topic_subject(row.topic)

    attrs = conversation_attrs(row, subject)

    case Repo.get_by(Conversation, subject: subject) do
      nil ->
        conv =
          %Conversation{}
          |> Conversation.changeset(attrs)
          |> Repo.insert!()

        insert_messages_for_cohort(conv, row)
        conv

      existing ->
        existing
    end
  end

  # Brand-voice conversation subjects per topic atom (D-18 / D-17).
  defp topic_subject(:api_key), do: "Resetting my Trailmark API key"
  defp topic_subject(:billing_email), do: "Updating billing email after switching CFO"
  defp topic_subject(:seat), do: "Adding a teammate to our Trailmark account"
  defp topic_subject(:ci_skipped), do: "CI run skipped without explanation"
  defp topic_subject(:token_rotation), do: "Rotation reminder for expiring token"

  # Conversation attrs per cohort (D-03).
  # :resolved rows include resolved_at + optional csat_rating.
  # All other cohorts use status: :open with no resolved_at.
  defp conversation_attrs(%{cohort: :resolved} = row, subject) do
    base = %{
      status: :resolved,
      subject: subject,
      host_user_id: row.host_user_id,
      resolved_at: DateTime.add(DateTime.utc_now(), -row.n, :day)
    }

    case row.csat_rating do
      nil -> base
      rating -> Map.put(base, :csat_rating, rating)
    end
  end

  defp conversation_attrs(row, subject) do
    %{
      status: :open,
      subject: subject,
      host_user_id: row.host_user_id
    }
  end

  # Inserts 2–5 messages per conversation following each cohort's derivation rule.
  #
  # :new               -> 2 messages (user opening + user follow-up)
  # :open              -> 4 messages (user → agent → user → user; last must be :user)
  # :awaiting_customer -> 3 messages (user → user detail → agent; last must be :agent)
  # :resolved          -> 5 messages (user → agent → user → agent → closer)
  #                       If closer == :system_outbound, 5th message carries metadata.template_id.
  #
  # n=5 and n=13 also receive 1 :internal_note message after the first :agent reply (D-18).
  defp insert_messages_for_cohort(conv, row) do
    messages = build_message_list(row)

    Enum.each(messages, fn msg_attrs ->
      %Message{}
      |> Message.changeset(
        Map.merge(%{role: :user, metadata: %{}, conversation_id: conv.id}, msg_attrs)
      )
      |> Repo.insert!()
    end)
  end

  # Returns the ordered list of message attrs maps for each cohort.
  defp build_message_list(%{cohort: :new, topic: topic}) do
    [
      %{role: :user, content: opening_user(topic)},
      %{role: :user, content: followup_user(topic)}
    ]
  end

  defp build_message_list(%{cohort: :open, topic: topic, n: n}) do
    base = [
      %{role: :user, content: opening_user(topic)},
      %{role: :agent, content: agent_first_reply(topic)},
      %{role: :user, content: followup_user(topic)},
      %{role: :user, content: second_followup_user(topic)}
    ]

    # n=5: add :internal_note after first :agent reply (D-18 carve-out)
    if n == 5 do
      [
        hd(base),
        Enum.at(base, 1),
        %{role: :internal_note, content: internal_note(topic)} | tl(tl(base))
      ]
    else
      base
    end
  end

  defp build_message_list(%{cohort: :awaiting_customer, topic: topic}) do
    [
      %{role: :user, content: opening_user(topic)},
      %{role: :user, content: additional_detail_user(topic)},
      %{role: :agent, content: agent_response(topic)}
    ]
  end

  defp build_message_list(%{cohort: :resolved, topic: topic, n: n, closer: closer}) do
    closing_msg =
      if closer == :system_outbound do
        # Message.role enum is sealed at [:agent, :internal_note, :system, :user];
        # the spec-language ":system_outbound" is a closer-plan label (not persisted).
        # The metadata.template_id below is the Pitfall 6 marker the renderer reads.
        %{
          role: :system,
          content: "Your request has been resolved. We've sent a confirmation to your email.",
          metadata: %{"template_id" => "demo_resolve_confirm"}
        }
      else
        %{role: :agent, content: agent_closing(topic)}
      end

    base = [
      %{role: :user, content: opening_user(topic)},
      %{role: :agent, content: agent_first_reply(topic)},
      %{role: :user, content: followup_user(topic)},
      %{role: :agent, content: agent_solution(topic)},
      closing_msg
    ]

    # n=13: add :internal_note after first :agent reply (D-18 carve-out)
    if n == 13 do
      [
        hd(base),
        Enum.at(base, 1),
        %{role: :internal_note, content: internal_note(topic)} | tl(tl(base))
      ]
    else
      base
    end
  end

  # ---------------------------------------------------------------------------
  # Per-topic message body helpers (brand voice — D-18 / §5.5)
  # Customer messages: slightly informal, problem-stating.
  # Agent messages: calm, factual, reason-forward (brand book §5.5).
  # Internal-note bodies may reference IDs/typed terms (D-18 carve-out).
  # ---------------------------------------------------------------------------

  defp opening_user(:api_key) do
    "Hi — I need to reset my Trailmark API key. I accidentally committed it to a public " <>
      "repository and want to revoke it right away. What are the steps?"
  end

  defp opening_user(:billing_email) do
    "Hello, we just switched CFOs and the billing email on our account is still the old " <>
      "one. Invoices are going to the wrong person. Can you help me update it?"
  end

  defp opening_user(:seat) do
    "Hi, I'd like to add a new engineer to our Trailmark account. Her name is Sam and " <>
      "she starts on Monday. How do I send her an invitation?"
  end

  defp opening_user(:ci_skipped) do
    "Our CI run from this morning shows a 'skipped' status but we pushed real code changes. " <>
      "No error message, just 'skipped'. Is something wrong with our configuration?"
  end

  defp opening_user(:token_rotation) do
    "I got a notification that our integration token is expiring in 7 days. What's the " <>
      "process for rotating it without breaking our production pipeline?"
  end

  defp followup_user(:api_key) do
    "I tried going to Settings but I don't see a Revoke button for the key. " <>
      "Is there a permission I'm missing?"
  end

  defp followup_user(:billing_email) do
    "I've looked in the billing portal but I only see a read-only view of the current " <>
      "email. There doesn't seem to be an edit option. Am I looking in the right place?"
  end

  defp followup_user(:seat) do
    "I sent the invite but Sam said she hasn't received anything. It's been about an hour. " <>
      "Should I resend, or could it be caught in her spam filter?"
  end

  defp followup_user(:ci_skipped) do
    "I checked the run detail page and the skip reason says 'cached result reused', but " <>
      "I'm sure we haven't pushed this exact commit before. Is there a way to force a fresh run?"
  end

  defp followup_user(:token_rotation) do
    "Thanks — one follow-up: after I generate the new token, is there a grace period " <>
      "where both the old and new tokens are valid? I want to roll it out gradually."
  end

  defp second_followup_user(:api_key) do
    "Also, once I revoke the key, will any existing sessions using that key stop working " <>
      "immediately, or is there a delay?"
  end

  defp second_followup_user(:billing_email) do
    "Just to confirm — will the update also affect the contact on file for PO-matched " <>
      "invoices, or only the email delivery address?"
  end

  defp second_followup_user(:seat) do
    "One more thing — is there a seat limit on our current plan? I want to make sure we " <>
      "have room before I invite more people next week."
  end

  defp second_followup_user(:ci_skipped) do
    "We found that the trigger path patterns don't include our new service directory. " <>
      "Does updating the trigger config apply to already-running pipelines, or only new pushes?"
  end

  defp second_followup_user(:token_rotation) do
    "Also, should I notify our DevOps team before rotating, or is the rotation zero-downtime " <>
      "if we update the secret before the old token expires?"
  end

  defp additional_detail_user(:api_key) do
    "To add context: the key was pushed to our monorepo's main branch about 3 hours ago. " <>
      "We've already removed the commit from history, but the key was exposed for roughly 45 minutes."
  end

  defp additional_detail_user(:billing_email) do
    "For reference, the current email on file is marcus@acme-old.example. " <>
      "The new address should be finance@acme.example. Both are internal addresses."
  end

  defp additional_detail_user(:seat) do
    "Her email is sam.reyes@globex.example. She'll need the Engineer role with read access " <>
      "to all projects but no admin permissions."
  end

  defp additional_detail_user(:ci_skipped) do
    "Here's more detail: the skipped run ID is #4821. Our trigger config covers 'src/**' " <>
      "but the new service lives under 'services/payments/' which is apparently outside that pattern."
  end

  defp additional_detail_user(:token_rotation) do
    "The token in question is the Webhooks integration token, not the API key. " <>
      "It's used in three production services. We need to coordinate the rotation carefully."
  end

  defp agent_first_reply(:api_key) do
    "I can help you with that. To revoke your API key, go to **Settings > API Keys** in " <>
      "your Trailmark dashboard. Click **Revoke** next to the compromised key. The key is " <>
      "invalidated immediately — any requests using it will fail right away. Once revoked, " <>
      "click **Generate new key** and store the new key in your secrets manager. " <>
      "Let me know if you run into any trouble with those steps."
  end

  defp agent_first_reply(:billing_email) do
    "Happy to help. The billing email can be updated in **Settings > Billing**. Click " <>
      "**Edit** next to your current billing address, enter the new email, and confirm. " <>
      "Trailmark will send a verification link to the new address — the change takes effect " <>
      "once you click that link. Future invoices will go to the verified address. " <>
      "Is the new address ready to receive the verification email?"
  end

  defp agent_first_reply(:seat) do
    "To invite Sam, open **Settings > Team** and click **Invite a teammate**. Enter her " <>
      "work email and select the Engineer role. Trailmark will send her an invitation email " <>
      "with a link to accept. The seat is active once she accepts. If your account has a " <>
      "seat-approval policy, an admin may need to confirm before the email is sent. " <>
      "Let me know how it goes."
  end

  defp agent_first_reply(:ci_skipped) do
    "A 'skipped' status typically means Trailmark determined there was nothing new to run. " <>
      "The most common cause is that no changed paths matched your configured CI triggers. " <>
      "Open the run detail page for the skipped run and check the **Skip reason** field at " <>
      "the top. If it says 'no diffed paths matched configured triggers', the fix is to " <>
      "update your trigger path patterns under **Project > Settings > CI Triggers**. " <>
      "What does the skip reason show for your run?"
  end

  defp agent_first_reply(:token_rotation) do
    "Token rotation is straightforward. Go to **Settings > API Keys**, click **Revoke** " <>
      "on the expiring token, then select **Generate new key**. Update your integrations " <>
      "with the new token before revoking the old one — both are not valid simultaneously, " <>
      "so plan a brief maintenance window or update your secrets before the old token expires. " <>
      "Which integration are you rotating the token for?"
  end

  defp agent_response(:api_key) do
    "Given the 45-minute exposure window, I'd recommend revoking the key immediately and " <>
      "reviewing your activity log for any unexpected requests during that period. Go to " <>
      "**Settings > API Keys**, click **Revoke**, then check the audit log under " <>
      "**Settings > Audit**. Filter by the key's last 4 characters to see what was called. " <>
      "If you see any requests you don't recognize, please reach out so we can investigate further."
  end

  defp agent_response(:billing_email) do
    "I've updated the billing contact on our end to finance@acme.example. " <>
      "You should receive a verification email at that address within a few minutes. " <>
      "Once you click the link, the change will take effect for all future invoices. " <>
      "Past invoices remain accessible in the portal at the original address. " <>
      "Please confirm once you've verified the new email."
  end

  defp agent_response(:seat) do
    "I've checked your account — you're on the Team plan which includes up to 10 seats, " <>
      "and you currently have 4 active. The invitation for sam.reyes@globex.example has " <>
      "been queued. Please ask her to check her inbox, including the spam folder, for an " <>
      "email from noreply@trailmark.example. If she doesn't see it within 10 minutes, " <>
      "let me know and I can resend from our side."
  end

  defp agent_response(:ci_skipped) do
    "Your trigger config covers 'src/**' but run #4821 only touched 'services/payments/'. " <>
      "Since that path is outside your configured triggers, Trailmark correctly marked it " <>
      "as skipped rather than running a potentially irrelevant pipeline. To include your " <>
      "new service, add 'services/**' or 'services/payments/**' to your CI Triggers. " <>
      "Trigger updates apply to all future pushes — already-queued runs are not affected. " <>
      "Let me know if you'd like help reviewing your full trigger config."
  end

  defp agent_response(:token_rotation) do
    "For the Webhooks integration token, I recommend coordinating a brief maintenance window " <>
      "with your DevOps team. The rotation is not zero-downtime unless your services support " <>
      "dual-token mode. Update each service's secret before revoking the old token to minimize " <>
      "downtime. Once all three services are updated, revoke the old token in " <>
      "**Settings > API Keys**. If you'd like, I can flag this rotation in your account notes " <>
      "so our team can monitor for delivery errors in the 24 hours after the switch."
  end

  defp agent_solution(:api_key) do
    "Good news — I can see from the activity log that the key was only used by your own " <>
      "deploy scripts during that window. No unauthorized calls were made. Your new key is " <>
      "ready to use. I'd also recommend enabling IP allowlisting for API key usage under " <>
      "**Settings > Security** to reduce exposure risk for future keys."
  end

  defp agent_solution(:billing_email) do
    "The verification email has been resent to finance@acme.example. The previous link has " <>
      "been invalidated for security. Once you click the new link, the billing contact will " <>
      "be updated. Going forward, Trailmark sends a notification to the old address whenever " <>
      "the billing contact is changed, so your outgoing CFO will be informed automatically."
  end

  defp agent_solution(:seat) do
    "Sam's invitation has been resent. I've also checked your account's email delivery log " <>
      "and confirmed the first invitation reached our mail provider successfully — it may " <>
      "have been filtered by Globex's mail server. The new invitation uses a slightly " <>
      "different subject line that should improve deliverability. She should receive it " <>
      "within the next few minutes."
  end

  defp agent_solution(:ci_skipped) do
    "I've reviewed your trigger config and the 'services/payments/' path is not covered. " <>
      "Adding 'services/**' will cover all current and future service directories. " <>
      "To make the change: go to **Project > Settings > CI Triggers**, click **Edit**, " <>
      "add 'services/**' as a new path pattern, and save. The change takes effect on the " <>
      "next push. Would you like me to walk you through the config format?"
  end

  defp agent_solution(:token_rotation) do
    "Here's a step-by-step plan for your three services: (1) Generate the new token in " <>
      "**Settings > API Keys**. (2) Update Service A's secret, verify it's working. " <>
      "(3) Repeat for Services B and C. (4) Once all three are updated, revoke the old token. " <>
      "There is no grace period — the old token stops working immediately on revocation. " <>
      "Estimated downtime per service during the secret update is under 30 seconds for a " <>
      "rolling restart. Let me know once you're ready to begin."
  end

  defp agent_closing(:api_key) do
    "Your API key has been successfully rotated and the activity log shows no unauthorized " <>
      "usage. I've marked this ticket resolved. If you have any further questions about " <>
      "key security or access controls, feel free to reach out."
  end

  defp agent_closing(:billing_email) do
    "The billing email has been updated and verified. Future invoices will go to the new " <>
      "address. I've marked this request resolved. If the change doesn't appear on your " <>
      "next invoice, please let us know and we'll investigate."
  end

  defp agent_closing(:seat) do
    "Sam has accepted her invitation and her seat is now active. I've marked this ticket " <>
      "resolved. If you need to adjust her role or permissions later, you can do so from " <>
      "**Settings > Team** at any time."
  end

  defp agent_closing(:ci_skipped) do
    "Your trigger config has been updated to include 'services/**'. The next push to that " <>
      "path will run the full pipeline. I've marked this ticket resolved. " <>
      "Feel free to reach out if you see any unexpected skip behavior in future runs."
  end

  defp agent_closing(:token_rotation) do
    "Token rotation is complete and all three services are running on the new token. " <>
      "I've marked this ticket resolved. Your new token is valid for 90 days from today. " <>
      "We'll send a reminder 7 days before it expires."
  end

  # Internal-note bodies (D-18 carve-out — may reference IDs and typed terms).
  # Used in conversations n=5 (open, api_key) and n=13 (resolved, api_key).
  defp internal_note(:api_key) do
    "Flagged for security review: host_user_id=demo_user_hooli_tokens, key exposure ~45 min. " <>
      "Activity log checked — calls originated from deploy pipeline CIDRs only. " <>
      "No fraud signal. Marked as low-risk rotation."
  end

  defp internal_note(_topic) do
    "Internal: reviewed account history. No prior escalations. Standard handling applies."
  end

  # -------------------------------------------------------------------------
  # Gap spec data (D-14): 3 demo gaps distributed across the past 14 days.
  #
  # Constraints satisfied:
  #   - score in 0.4..0.8 (0.65, 0.55, 0.45)
  #   - evidence_count in 2..4
  #   - manual_case_count and weak_grounding_count non-zero across all 3
  #   - first_seen_at offset older (more negative) than last_seen_at offset
  #   - candidate_type: :mixed on all 3 (D-14)
  #   - host_user_id: "demo_operator" on all rows (Pitfall 3 — operator-scope)
  # -------------------------------------------------------------------------
  @demo_gaps [
    %{
      stable_key: "demo_gap_billing_export",
      title: "Exporting Trailmark billing receipts",
      seed_excerpt:
        "Adopters repeatedly ask how to download multi-month billing receipts; no canonical KB article exists yet.",
      sanitized_query: "export billing receipts past months",
      ui_surface: :conversation,
      first_seen_offset_d: -14,
      last_seen_offset_d: -2,
      evidence_count: 3,
      manual_case_count: 2,
      weak_grounding_count: 1,
      no_hit_count: 0,
      score: 0.65,
      score_components: %{
        "manual_handling" => 0.4,
        "weak_grounding" => 0.15,
        "freshness_boost" => 0.10
      }
    },
    %{
      stable_key: "demo_gap_ci_skip_diagnostics",
      title: "Diagnosing why a CI run was skipped",
      seed_excerpt:
        "CI-skip diagnostics surface intermittently; current article gives causes but not a step-by-step debug flow.",
      sanitized_query: "ci run skipped not triggered",
      ui_surface: :conversation,
      first_seen_offset_d: -10,
      last_seen_offset_d: -1,
      evidence_count: 4,
      manual_case_count: 1,
      weak_grounding_count: 2,
      no_hit_count: 1,
      score: 0.55,
      score_components: %{
        "manual_handling" => 0.2,
        "weak_grounding" => 0.3,
        "no_hit" => 0.05
      }
    },
    %{
      stable_key: "demo_gap_team_seat_governance",
      title: "Clarifying the seat-invite governed-action flow",
      seed_excerpt:
        "Operators need clearer guidance on when seat-invite proposals require approval vs auto-apply.",
      sanitized_query: "add team seat governed approval",
      ui_surface: :inbox,
      first_seen_offset_d: -7,
      last_seen_offset_d: -3,
      evidence_count: 2,
      manual_case_count: 2,
      weak_grounding_count: 1,
      no_hit_count: 0,
      score: 0.45,
      score_components: %{
        "manual_handling" => 0.4,
        "weak_grounding" => 0.05
      }
    }
  ]

  # Builds 3+ GapCandidates with memberships and RetrievalGapEvent back-references.
  #
  # Strategy (D-13 / RESEARCH Open Question 1):
  #   - Direct Schema.changeset + Repo.insert! only — M010 builder path is NOT used.
  #   - 1 real RetrievalGapEvent seeded per GapCandidate so the gap-queue detail view
  #     renders evidence rather than the empty-state copy.
  #   - 1 GapCandidateMembership per gap linking to its seeded RetrievalGapEvent.
  #   - All host_user_id values are "demo_operator" (Pitfall 3 — operator-scope).
  #
  # Returns list of inserted %GapCandidate{} rows (plan 27-06 uses the first
  # element as the ArticleSuggestion's entrypoint_id — demo_gap_billing_export
  # whose title aligns with the FIX-04 demo suggestion content).
  defp build_gaps(_conversations) do
    Enum.map(@demo_gaps, fn spec -> seed_gap_with_evidence(spec) end)
  end

  # Per-spec idempotent gap seeder.
  # GapCandidate keyed on :stable_key (natural key — D-02).
  # RetrievalGapEvent keyed on :query_fingerprint (sha256 of stable_key — deterministic + 64 chars).
  # GapCandidateMembership is no-op on re-run via Repo.get_by before insert.
  defp seed_gap_with_evidence(spec) do
    now = DateTime.utc_now()

    gap_attrs = %{
      stable_key: spec.stable_key,
      status: :open,
      candidate_type: :mixed,
      title: spec.title,
      seed_excerpt: spec.seed_excerpt,
      tenant_scope: :host_user_scoped,
      # operator-scope (Pitfall 3 — must NOT be a demo_user_* customer id)
      host_user_id: "demo_operator",
      ui_surface: spec.ui_surface,
      first_seen_at: DateTime.add(now, spec.first_seen_offset_d, :day),
      last_seen_at: DateTime.add(now, spec.last_seen_offset_d, :day),
      evidence_count: spec.evidence_count,
      manual_case_count: spec.manual_case_count,
      weak_grounding_count: spec.weak_grounding_count,
      no_hit_count: spec.no_hit_count,
      score: spec.score,
      score_components: spec.score_components
    }

    gap = get_or_insert!(GapCandidate, :stable_key, gap_attrs)

    # Seed exactly 1 RetrievalGapEvent per gap (RESEARCH Open Question 1 recommendation:
    # seed real GapEvent rows so the gap-queue detail view renders evidence).
    event = get_or_insert_gap_event!(spec, now)
    _membership = upsert_membership!(gap, event)

    gap
  end

  # Inserts a RetrievalGapEvent idempotently, keyed on query_fingerprint.
  # query_fingerprint is sha256 hex of "demo:gap_event:<stable_key>" — guaranteed 64 hex chars
  # (T-27-14 mitigation).
  # host_user_id is "demo_operator" — same operator-scope as the GapCandidate (Pitfall 3).
  defp get_or_insert_gap_event!(spec, now) do
    fingerprint =
      :crypto.hash(:sha256, "demo:gap_event:" <> spec.stable_key)
      |> Base.encode16(case: :lower)

    attrs = %{
      occurred_at: DateTime.add(now, spec.last_seen_offset_d, :day),
      surface: :search_modal,
      outcome_class: :empty_recall,
      reason: :no_canonical_results,
      # operator-scope (Pitfall 3)
      host_user_id: "demo_operator",
      tenant_scope: :host_user_scoped,
      ui_surface: spec.ui_surface,
      query_fingerprint: fingerprint,
      sanitized_query_excerpt: spec.sanitized_query,
      canonical_hit_count: 0,
      assistive_hit_count: 0,
      clarification_attempts: 0
    }

    case Repo.get_by(GapEvent, query_fingerprint: fingerprint) do
      nil ->
        %GapEvent{}
        |> GapEvent.changeset(attrs)
        |> Repo.insert!()

      existing ->
        existing
    end
  end

  # Inserts a GapCandidateMembership linking a gap to a GapEvent.
  # Idempotent: Repo.get_by before insert; unique constraint on (gap_candidate_id,
  # source_type, source_id) catches any regression (T-27-15 mitigation).
  defp upsert_membership!(gap, event) do
    attrs = %{
      gap_candidate_id: gap.id,
      source_type: :retrieval_gap_event,
      source_id: event.id
    }

    case Repo.get_by(GapCandidateMembership,
           gap_candidate_id: gap.id,
           source_type: :retrieval_gap_event,
           source_id: event.id
         ) do
      nil ->
        %GapCandidateMembership{}
        |> GapCandidateMembership.changeset(attrs)
        |> Repo.insert!()

      existing ->
        existing
    end
  end

  # Stable identity key for the seeded suggestion (idempotency — D-02).
  @demo_suggestion_stable_key "demo:article_suggestion:billing_export:v1"

  # Builds 1 ArticleSuggestion with:
  #   - status: :ready       (sealed enum — spec language :ready_for_review)
  #   - suggestion_type: :article  (sealed enum — spec language :new_article)
  #   - entrypoint_type: :gap_candidate targeting demo_gap_billing_export
  #   - tenant_scope: :host_user_scoped + host_user_id: "demo_operator" (Pitfall 3 — operator-scope)
  #   - 2 KB-chunk-grounded ArticleSuggestionEvidence rows (D-16 minimum)
  #     Both rows cite the api_key article's published revision (chunk_index 0 and 1).
  #     validate_citation_target requires article_id/revision_id/chunk_index on every row.
  #     validate_metadata_destination requires metadata.destination map on every row.
  #   - deterministic evidence_digest matching the production algorithm (D-16 / RESEARCH §evidence_digest_for)
  #   - hand-authored proposed_markdown with [1]/[2] footnote anchors (D-15)
  #
  # After the suggestion insert, KnowledgeAutomation.ensure_review_task_for_suggestion/2 is
  # called so a ReviewTask + :task_created ReviewTaskEvent are created (Critical Finding 2 /
  # Pitfall 1 — without this, SuggestionReview LiveView shows an empty queue for FIX-04).
  #
  # _conversations arg is underscore-prefixed: evidence rows are exclusively KB-chunk-grounded.
  # Conversation context surfaces in the demo via plan 27-04's seeded conversations; the schema
  # has no direct ArticleSuggestion→Conversation anchor field, and validate_citation_target
  # requires article_id/revision_id/chunk_index on every evidence row — conversation-only
  # citation_targets are fundamentally incompatible with that validator.
  #
  # Returns {%ArticleSuggestion{}, %ReviewTask{}}.
  defp build_suggestion(articles, _conversations) do
    import Ecto.Query

    # Look up the entrypoint gap (first @demo_gaps spec — demo_gap_billing_export)
    gap = Repo.get_by!(GapCandidate, stable_key: "demo_gap_billing_export")

    # Look up the canonical article whose chunks provide the KB-grounded evidence
    api_key_article = Map.fetch!(articles, :api_key)

    # Look up the api_key article's published revision (chunk_index 0 and 1 are guaranteed
    # to exist because the article body has ≥2 ## h2 sections — Pitfall 4 mitigation from plan 27-03)
    api_key_revision =
      Repo.one!(
        from r in Revision,
          where: r.article_id == ^api_key_article.id and r.state == :published,
          limit: 1
      )

    # -------------------------------------------------------------------------
    # 2 KB-chunk-grounded evidence rows (D-16: ≥2 rows required)
    #
    # Both rows are source_type: :knowledge_base, trust_level: :canonical (sealed enums
    # verified at ArticleSuggestionEvidence lines 7-8).
    #
    # validate_citation_target REQUIRES: article_id, revision_id, chunk_index.
    # validate_metadata_destination REQUIRES: metadata.destination as a map.
    #
    # Both rows reference DISTINCT chunks of api_key_article's published revision:
    #   Row 1 → chunk_index: 0  (## Reset steps section — API key revoke flow)
    #   Row 2 → chunk_index: 1  (## When to contact support section — audit-log adjacency
    #                             + bulk-export pathway that anchors the [2] footnote)
    # -------------------------------------------------------------------------
    evidence_row_1 = %{
      source_type: :knowledge_base,
      trust_level: :canonical,
      title: api_key_article.title,
      excerpt:
        "Trailmark API keys are reset under Settings → API Keys; the reset flow surfaces the same audit log that backs billing-receipt traceability.",
      citation_target: %{
        article_id: api_key_article.id,
        revision_id: api_key_revision.id,
        chunk_index: 0
      },
      metadata: %{
        destination: %{
          article_id: api_key_article.id,
          revision_id: api_key_revision.id
        },
        origin: "demo_seed"
      },
      match_reasons: [
        "matched canonical API-key reset adjacency",
        "shares audit-log surface with billing receipts"
      ]
    }

    evidence_row_2 = %{
      source_type: :knowledge_base,
      trust_level: :canonical,
      title: api_key_article.title,
      excerpt:
        "Multi-month bulk export of receipts is available via the API-key-authenticated export endpoint; CFO/billing-email changes do not invalidate prior receipts.",
      citation_target: %{
        article_id: api_key_article.id,
        revision_id: api_key_revision.id,
        chunk_index: 1
      },
      metadata: %{
        destination: %{
          article_id: api_key_article.id,
          revision_id: api_key_revision.id
        },
        origin: "demo_seed"
      },
      match_reasons: [
        "matched canonical API-key bulk-export pathway"
      ]
    }

    evidence_snapshot = [evidence_row_1, evidence_row_2]

    # -------------------------------------------------------------------------
    # Proposed markdown with [1]/[2] footnote anchors (D-15)
    # Brand voice: calm, fail-closed, reason-forward (§5.5).
    # -------------------------------------------------------------------------
    proposed_markdown = """
    ## Exporting your billing receipts

    Trailmark stores monthly receipts under Settings → Billing → Receipts [1].
    Each receipt is downloadable as a PDF; multi-month bulk export is available via the API-key authenticated export flow [2].

    ## When to contact support

    If a receipt is missing or shows the wrong billing email, contact support with the receipt date and your account email.
    """

    # -------------------------------------------------------------------------
    # Suggestion attrs
    # NOTE: article_id and base_revision_id are intentionally NOT set.
    # validate_anchor_rules rejects them for {:article, :gap_candidate} pairs
    # (ArticleSuggestion lines 144-148). The article reference lives exclusively
    # on the evidence rows' citation_target + metadata.destination.
    # -------------------------------------------------------------------------
    suggestion_attrs = %{
      stable_key: @demo_suggestion_stable_key,
      # sealed enum — spec language :new_article maps to :article (Sealed-enum reconciliation table)
      suggestion_type: :article,
      # sealed enum — spec language :ready_for_review maps to :ready
      status: :ready,
      tenant_scope: :host_user_scoped,
      # operator-scope (Pitfall 3 — must match router.ex live_session host_user_id "demo_operator")
      host_user_id: "demo_operator",
      entrypoint_type: :gap_candidate,
      entrypoint_id: gap.id,
      title: "Exporting Trailmark billing receipts",
      operator_summary:
        "Repeated customer requests for a billing-export flow surfaced through the demo_gap_billing_export gap. Hand-authored draft grounded in the canonical API-key article's published revision.",
      proposed_markdown: proposed_markdown,
      # non-empty map required by validate_grounding_metadata/1
      grounding_metadata: %{"status" => "strong", "evidence_count" => length(evidence_snapshot)},
      evidence_snapshot: evidence_snapshot,
      evidence_digest: compute_evidence_digest(evidence_snapshot),
      generated_at: DateTime.utc_now()
    }

    # -------------------------------------------------------------------------
    # Idempotent insert (manual get_by keyed on stable_key — embeds_many is cast
    # at insert time so the generic get_or_insert!/3 helper is not used here)
    # -------------------------------------------------------------------------
    suggestion =
      case Repo.get_by(ArticleSuggestion, stable_key: @demo_suggestion_stable_key) do
        nil ->
          %ArticleSuggestion{}
          |> ArticleSuggestion.changeset(suggestion_attrs)
          |> Repo.insert!()

        existing ->
          existing
      end

    # -------------------------------------------------------------------------
    # Companion ReviewTask via the library facade (Critical Finding 2 / Pitfall 1)
    #
    # SuggestionReview LiveView reads list_review_tasks/1 (NOT list_article_suggestions/1).
    # Without this call, the suggestion is invisible in /support/knowledge-base/suggestions.
    #
    # Only :actor_id is read from opts — tenant_scope and host_user_id are sourced
    # from the loaded suggestion automatically (lib/cairnloop/knowledge_automation.ex:137-138).
    # Do NOT pass :tenant_scope or :host_user_id here.
    #
    # ensure_review_task_for_suggestion/2 is idempotent (returns existing active task
    # if one is already linked — lib/cairnloop/knowledge_automation.ex:128-129).
    # -------------------------------------------------------------------------
    {:ok, review_task} =
      KnowledgeAutomation.ensure_review_task_for_suggestion(
        suggestion.id,
        actor_id: "system"
      )

    {suggestion, review_task}
  end

  # ---------------------------------------------------------------------------
  # Evidence digest helper — mirrors production algorithm at
  # lib/cairnloop/knowledge_automation.ex:961-976 verbatim.
  #
  # Field order is LOAD-BEARING: [source_type, trust_level, title, excerpt,
  # citation_target, match_reasons]. :metadata is deliberately EXCLUDED.
  # Future CandidateBuilder re-computation must match this hash (D-16 / T-27-19).
  # ---------------------------------------------------------------------------
  defp compute_evidence_digest(evidence_snapshot) do
    evidence_snapshot
    |> Enum.map(fn e ->
      %{
        source_type: e.source_type,
        trust_level: e.trust_level,
        title: e.title,
        excerpt: e.excerpt,
        citation_target: e.citation_target,
        match_reasons: e.match_reasons
      }
    end)
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  # Synchronously drains the :default Oban queue after all builders complete.
  # This is the M008 substrate self-test — ChunkRevision jobs enqueued by
  # KnowledgeBase.publish_revision/1 write chunks to pgvector via the live worker.
  # Returns the drain result map so the caller can include counts in the summary.
  defp drain_embedding_pipeline do
    IO.puts("Draining embedding pipeline (Oban :default queue)...")

    %{success: success, failure: failure} =
      result =
      Oban.drain_queue(queue: :default, with_recursion: true)

    if failure > 0 do
      IO.warn(
        "Seed embedding pipeline drained with #{failure} failures. " <>
          "Inspect oban_jobs.errors for details."
      )
    end

    IO.puts("Drained #{success} embedding job(s).")
    result
  end

  # Prints a single adopter-facing summary line summarising what was seeded.
  # Gives concrete evidence of what `mix setup` produced (T-27-22 mitigation).
  defp emit_seed_summary(articles, conversations, gaps, suggestion, drain_summary) do
    article_count = map_size(articles)
    conversation_count = length(conversations)
    gap_count = length(gaps)
    suggestion_count = if suggestion, do: 1, else: 0
    drained = drain_summary.success
    failures = drain_summary.failure

    IO.puts(
      "Seeded #{conversation_count} conversation(s), #{article_count} article(s), " <>
        "#{gap_count} gap candidate(s), #{suggestion_count} article suggestion(s); " <>
        "drained #{drained} embedding job(s) (#{failures} failure(s))."
    )
  end

  # --------------------------------------------------------------------------
  # Showcase states — frozen JTBD end-states for the click-around tour + screenshots
  # --------------------------------------------------------------------------
  # The cohort conversations above (demo-01..16) carry messages but no governance
  # artifacts, so JTBD stages 4/5/6/8 have nothing to render. These four dedicated
  # conversations (demo-17..20) are each pre-positioned in one end-state, reached
  # through the REAL facades (Automation.create_draft, Governance.propose/
  # request_approval/approve, the execution workers, a durable :system_outbound
  # message) so the demo + captured screenshots show truthful state, and the audit
  # log + governance rail populate from genuine ToolActionEvents.
  #
  # Idempotency (D-02): keyed on the "[demo-NN]" subject; all side effects run only
  # when the conversation is first created, exactly like insert_messages_for_cohort/2.
  # Determinism: governance enqueue is a no-op (enqueue_fn) and the resume/execution
  # workers are performed synchronously here, so re-running the seed never double-writes
  # and never depends on async Oban timing.

  @internal_note_ref Atom.to_string(Cairnloop.Tools.InternalNote)
  @showcase_operator "demo_operator"

  defp build_showcase_states do
    [
      showcase_draft_pending(),
      showcase_action_pending(),
      showcase_action_executed(),
      showcase_outbound_pending()
    ]
  end

  # Stage 4 — a pending AI draft awaiting operator approval.
  defp showcase_draft_pending do
    new_showcase_conversation(
      n: 17,
      subject: "Refund for a double charge this month",
      host_user_id: "demo_user_acme_billing",
      messages: [
        %{
          role: :user,
          content: "Hi — it looks like I was charged twice for the Team plan this month."
        },
        %{
          role: :user,
          content: "Could you refund the duplicate charge? It's the card ending 4242."
        }
      ],
      after_fn: fn conv ->
        {:ok, _draft} =
          Automation.create_draft(conv.id, %{
            proposal_type: :reply,
            customer_reply:
              "Thanks for flagging this, Riya. I can see two identical $48.00 charges dated " <>
                "2026-05-12 — the second is a duplicate. I've started a refund for it now; it " <>
                "should land back on the card ending 4242 within 5–10 business days. I'll keep " <>
                "this ticket open until you confirm it arrives.",
            status: :pending
          })

        :ok
      end
    )
  end

  # Stage 5 — a governed action proposed and waiting in the approval lane.
  defp showcase_action_pending do
    new_showcase_conversation(
      n: 18,
      subject: "CI pipeline stuck — needs an internal escalation note",
      host_user_id: "demo_user_umbrella_ci",
      messages: [
        %{role: :user, content: "Our CI has skipped three runs in a row and I can't tell why."},
        %{
          role: :user,
          content: "This is blocking a hotfix deploy — can someone take a closer look?"
        }
      ],
      after_fn: fn conv ->
        {:ok, proposal} =
          Governance.propose(@internal_note_ref, @showcase_operator, %{
            conversation_id: to_string(conv.id),
            scopes: [],
            tool_params: %{
              conversation_id: to_string(conv.id),
              content:
                "Escalating to platform on-call: 3 consecutive skipped runs for umbrella, " <>
                  "last at 2026-05-25T18:22Z. Suspected stuck runner, not a customer config issue."
            }
          })

        {:ok, _approval} = Governance.request_approval(proposal, enqueue_fn: &noop_enqueue/1)
        :ok
      end
    )
  end

  # Stage 6 — a governed action that has been approved and executed (:executed).
  defp showcase_action_executed do
    new_showcase_conversation(
      n: 19,
      subject: "Team seat invite approved and applied",
      host_user_id: "demo_user_globex_seats",
      messages: [
        %{role: :user, content: "Please add my teammate Dana to our Globex account."},
        %{
          role: :agent,
          content:
            "Happy to help. Adding a seat is a governed action, so it goes through approval first."
        }
      ],
      after_fn: fn conv ->
        {:ok, proposal} =
          Governance.propose(@internal_note_ref, @showcase_operator, %{
            conversation_id: to_string(conv.id),
            scopes: [],
            tool_params: %{
              conversation_id: to_string(conv.id),
              content:
                "Seat invite for dana@globex.example approved under the team-seat policy; recorded for audit."
            }
          })

        {:ok, approval} = Governance.request_approval(proposal, enqueue_fn: &noop_enqueue/1)

        {:ok, _approved} =
          Governance.approve(approval.id, @showcase_operator, enqueue_fn: &noop_enqueue/1)

        # Drive the resume + execution chain synchronously (mirrors the golden-path test) so the
        # action lands in :executed deterministically, independent of async Oban draining.
        :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})

        :ok =
          ToolExecutionWorker.perform(%Oban.Job{
            attempt: 1,
            max_attempts: 3,
            args: %{"approval_id" => approval.id}
          })

        :ok
      end
    )
  end

  # Stage 8 — a resolved conversation with a durable outbound recovery follow-up pending delivery.
  defp showcase_outbound_pending do
    new_showcase_conversation(
      n: 20,
      subject: "Following up after your token rotation",
      host_user_id: "demo_user_hooli_tokens",
      status: :resolved,
      resolved_at: DateTime.add(DateTime.utc_now(), -2, :day),
      csat_rating: :positive,
      messages: [
        %{role: :user, content: "My API token was expiring — what's the safe way to rotate it?"},
        %{
          role: :agent,
          content:
            "Rotate from Settings > API Keys: generate the new key, update integrations, then revoke the old one."
        },
        %{role: :user, content: "Done — new key is live and everything still works. Thanks!"},
        %{
          role: :agent,
          content: "Great. I've marked this resolved; your new token is valid for 90 days."
        },
        %{
          role: :system_outbound,
          content:
            "Just checking in — your new Trailmark API token has been active for a week with no " <>
              "errors on our side. Reply here if anything looks off and we'll jump back in.",
          metadata: %{"template_id" => "demo_recovery_v1", "status" => "pending"}
        }
      ],
      after_fn: fn _conv -> :ok end
    )
  end

  # Idempotent showcase-conversation seeder. Conversation matched on the "[demo-NN]" subject
  # (natural key — D-02). Messages + after_fn side effects run ONLY on first creation.
  defp new_showcase_conversation(opts) do
    n = Keyword.fetch!(opts, :n)

    subject =
      "[demo-#{String.pad_leading(Integer.to_string(n), 2, "0")}] " <>
        Keyword.fetch!(opts, :subject)

    conv_attrs =
      %{
        status: Keyword.get(opts, :status, :open),
        subject: subject,
        host_user_id: Keyword.fetch!(opts, :host_user_id)
      }
      |> maybe_put(:resolved_at, Keyword.get(opts, :resolved_at))
      |> maybe_put(:csat_rating, Keyword.get(opts, :csat_rating))

    case Repo.get_by(Conversation, subject: subject) do
      nil ->
        conv =
          %Conversation{}
          |> Conversation.changeset(conv_attrs)
          |> Repo.insert!()

        Enum.each(Keyword.get(opts, :messages, []), fn msg_attrs ->
          %Message{}
          |> Message.changeset(
            Map.merge(%{role: :user, metadata: %{}, conversation_id: conv.id}, msg_attrs)
          )
          |> Repo.insert!()
        end)

        after_fn = Keyword.get(opts, :after_fn, fn _ -> :ok end)
        after_fn.(conv)
        conv

      existing ->
        existing
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp noop_enqueue(_job), do: :ok

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
