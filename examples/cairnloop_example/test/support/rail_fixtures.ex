defmodule CairnloopExample.RailFixtures do
  @moduledoc """
  Test fixtures for the evidence-rail browser E2E suite.

  Builds a conversation carrying a single PENDING governed action so `/support/:id` renders the
  full rail: the three Tier-2 `<details data-tier="2">` disclosure groups (Inputs & scope /
  History / Policy explanation), the Tier-3 "Identifiers & trace" group, and the Tier-1 safety
  quartet + Approve/Reject/Defer footer. Mirrors the seed `showcase_action_pending/0` exactly,
  but runs inside the caller's Ecto sandbox transaction (no committed seed dependency).

  Also provides fixtures for Phase 42 thread-navigation E2E tests (plan 06):
    - `resolved_conversation_with_next_open/0` — THREAD-01 (Next in queue)
    - `conversation_with_audit_event/0` — THREAD-02 (audit-log subject link)
    - `article_with_origin_conversation/0` — THREAD-03b (KB editor origin crumb)
  """
  alias CairnloopExample.Repo
  alias Cairnloop.{Conversation, Governance, Message}
  alias Cairnloop.KnowledgeBase.Article
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion

  @internal_note_ref Atom.to_string(Cairnloop.Tools.InternalNote)
  @operator "demo_operator"

  @doc """
  Inserts a conversation + two user messages + a pending internal-note governed action.
  Returns `%{conv_id: id, proposal_id: id}`.
  """
  def pending_governed_action_conversation(attrs \\ %{}) do
    conv =
      %Conversation{}
      |> Conversation.changeset(
        Map.merge(
          %{
            status: :open,
            subject: "[e2e] CI pipeline stuck — needs an internal escalation note",
            host_user_id: "e2e_operator"
          },
          attrs
        )
      )
      |> Repo.insert!()

    for content <- [
          "Our CI has skipped three runs in a row and I can't tell why.",
          "This is blocking a hotfix deploy — can someone take a closer look?"
        ] do
      %Message{}
      |> Message.changeset(%{
        role: :user,
        metadata: %{},
        conversation_id: conv.id,
        content: content
      })
      |> Repo.insert!()
    end

    {:ok, proposal} =
      Governance.propose(@internal_note_ref, @operator, %{
        conversation_id: to_string(conv.id),
        scopes: [],
        tool_params: %{
          conversation_id: to_string(conv.id),
          content: "Escalating to platform on-call: 3 consecutive skipped runs for umbrella."
        }
      })

    {:ok, _approval} = Governance.request_approval(proposal, enqueue_fn: fn _ -> :ok end)

    %{conv_id: conv.id, proposal_id: proposal.id}
  end

  @doc """
  Inserts a resolved conversation + one open conversation.
  Returns `%{resolved_id: id, next_open_id: id}`.

  Used by THREAD-01 E2E: visit the resolved conversation, click "Next in queue →", assert
  landing on the open conversation.  The resolved conversation is created directly via
  `Conversation.changeset/2` (status: :resolved) rather than through `Chat.resolve_conversation/2`
  to avoid the Oban worker side-effects not needed in E2E fixtures.
  """
  def resolved_conversation_with_next_open do
    resolved_conv =
      %Conversation{}
      |> Conversation.changeset(%{
        status: :resolved,
        subject: "[e2e-thread01] Resolved — has a next-open successor",
        host_user_id: "e2e_operator"
      })
      |> Repo.insert!()

    open_conv =
      %Conversation{}
      |> Conversation.changeset(%{
        status: :open,
        subject: "[e2e-thread01] Open — this is the next in queue",
        host_user_id: "e2e_operator"
      })
      |> Repo.insert!()

    # Seed at least one user message so ConversationLive renders its content region.
    %Message{}
    |> Message.changeset(%{
      role: :user,
      metadata: %{},
      conversation_id: resolved_conv.id,
      content: "This conversation has been resolved — follow-up via next in queue."
    })
    |> Repo.insert!()

    %Message{}
    |> Message.changeset(%{
      role: :user,
      metadata: %{},
      conversation_id: open_conv.id,
      content: "Still open and waiting for a response."
    })
    |> Repo.insert!()

    %{resolved_id: resolved_conv.id, next_open_id: open_conv.id}
  end

  @doc """
  Inserts `count` resolved conversations (default 25) so the Inbox at `/support/inbox` renders a
  scrollable list of selectable rows. Returns the inserted ids (newest-first is irrelevant here).

  Used by the RESP-02 inbox-geometry E2E (the automated replacement for the 43-03 human-verify
  checkpoint): only `status: :resolved` rows render a `.cl-checkbox`, and 25 rows comfortably
  overflow a 720px-tall viewport so the sticky bulk-bar's last-row clearance is exercised under a
  real scroll. Inserted directly via `Conversation.changeset/2` (no Oban/`Chat.resolve_conversation`
  side-effects). The inbox does not scope by `host_user_id`, so the value here is cosmetic.
  """
  def resolved_inbox_rows(count \\ 25) do
    for n <- 1..count do
      %Conversation{}
      |> Conversation.changeset(%{
        status: :resolved,
        subject: "[e2e-resp02] Resolved row #{n} — eligible for recovery follow-up",
        host_user_id: "e2e_operator"
      })
      |> Repo.insert!()
      |> Map.fetch!(:id)
    end
  end

  @doc """
  Inserts a conversation with a pending governed action, producing an audit-log event with a
  subject conversation link.  Returns `%{conv_id: id, proposal_id: id}`.

  Alias of `pending_governed_action_conversation/0` for semantic clarity in THREAD-02 E2E
  tests: `propose/3` co-commits a `:proposal_created` ToolActionEvent that appears on
  `/support/audit-log`, and `tool_proposal.conversation_id` is the FK the subject-href
  presenter resolves into the "View conversation" link.
  """
  def conversation_with_audit_event do
    pending_governed_action_conversation()
  end

  @doc """
  Inserts an Article + a resolved Conversation + an ArticleSuggestion row that links them.

  The suggestion has `entrypoint_type: :conversation_quick_fix`, `entrypoint_id: conv.id`
  (the originating conversation id), and `article_id: article.id`.

  `KnowledgeAutomation.originating_conversation_id/2` queries
  `where s.article_id == ^article_id and s.entrypoint_type == :conversation_quick_fix`,
  so both fields must be set.  In the production flow the article is created during review-task
  approval (`approval_article_id/3`) and the suggestion's `article_id` is back-filled via an
  Ecto update; here we replicate that end-state directly to keep the fixture minimal.

  NOTE: The suggestion row is inserted via `Ecto.Changeset.change/2` (bypassing the creation
  changeset's `validate_anchor_rules/1`, which prohibits `article_id` for new article
  suggestions) to reproduce the AFTER-APPROVAL state.  This is intentional: the test proves
  the editor breadcrumb render path; it does not test the suggestion creation path.

  Returns `%{article_id: id, conv_id: id}`.
  """
  def article_with_origin_conversation do
    conv =
      %Conversation{}
      |> Conversation.changeset(%{
        status: :open,
        subject: "[e2e-thread03b] Conversation that originated a KB article",
        host_user_id: "e2e_operator"
      })
      |> Repo.insert!()

    article =
      %Article{}
      |> Article.changeset(%{title: "[e2e-thread03b] Quick-fix article", status: :draft})
      |> Repo.insert!()

    # Build the ArticleSuggestion in the AFTER-APPROVAL state:
    # article_id + entrypoint_id both set so originating_conversation_id/2 can find it.
    # Use Ecto.Changeset.change/2 to bypass the creation-only anchor rule
    # (validate_anchor_rules rejects article_id for new :article/:conversation_quick_fix
    # pairs — the production flow back-fills it after approval, so this is the correct
    # end-state for a fixture asserting the RENDER path, not the creation path).
    %ArticleSuggestion{}
    |> Ecto.Changeset.change(%{
      stable_key: "e2e-thread03b-#{conv.id}-#{article.id}",
      suggestion_type: :article,
      status: :ready,
      tenant_scope: :host_user_scoped,
      host_user_id: "demo_operator",
      entrypoint_type: :conversation_quick_fix,
      entrypoint_id: conv.id,
      article_id: article.id,
      proposed_markdown: "# Placeholder\n\nE2E fixture content.",
      grounding_metadata: %{"quick_fix_outcome" => "ready", "status" => "strong"}
    })
    |> Repo.insert!()

    %{article_id: article.id, conv_id: conv.id}
  end

  @doc """
  Inserts an agent message into the conversation and broadcasts the same `:message_created`
  PubSub event the production reply path emits, forcing `ConversationLive` to
  `reload_conversation_with_context/2` and re-render the rail. Returns the message content.

  Used to prove a rail panel survives a real server-driven re-render (phx-update="ignore"),
  without going through the operator reply form (which depends on host-app schema the demo's
  own migrations may not carry).
  """
  def inject_message_and_broadcast(conv_id, content) do
    %Message{}
    |> Message.changeset(%{
      role: :agent,
      metadata: %{},
      conversation_id: conv_id,
      content: content
    })
    |> Repo.insert!()

    Phoenix.PubSub.broadcast(Cairnloop.PubSub, "conversation:#{conv_id}", {:message_created, nil})
    content
  end
end
