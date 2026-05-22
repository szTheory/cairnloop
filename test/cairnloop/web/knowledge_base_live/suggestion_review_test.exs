defmodule Cairnloop.Web.KnowledgeBaseLive.SuggestionReviewTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestionEvidence
  alias Cairnloop.KnowledgeAutomation.ReviewTask
  alias Cairnloop.KnowledgeAutomation.ReviewTaskEvent
  alias Cairnloop.KnowledgeBase.Revision
  alias Cairnloop.Web.KnowledgeBaseLive.SuggestionReview

  defmodule MockKnowledgeAutomation do
    def list_article_suggestions(_opts) do
      Process.get(:mock_suggestions, [])
    end

    def get_article_suggestion!(id, _opts \\ []) do
      Process.get(:mock_suggestion_lookup).(id)
    end

    def list_review_tasks(_opts) do
      Process.get(:mock_review_tasks, [])
    end

    def get_review_task!(id, _opts \\ []) do
      Process.get(:mock_review_task_lookup).(id)
    end

    def dismiss_article_suggestion(id, _opts) do
      {:ok, Process.get(:mock_suggestion_lookup).(id)}
    end

    def regenerate_article_suggestion(id, _opts) do
      {:ok, Process.get(:mock_suggestion_lookup).(id)}
    end

    def create_or_reuse_authoring_article_for_suggestion(_id, _opts) do
      {:ok, 91}
    end
  end

  defmodule MockKnowledgeBase do
    def get_revision(44) do
      %Revision{id: 44, article_id: 77, content: "# Before\n\nOld copy"}
    end

    def get_revision(_), do: nil
  end

  setup do
    Application.put_env(:cairnloop, :knowledge_automation, MockKnowledgeAutomation)
    Application.put_env(:cairnloop, :knowledge_base, MockKnowledgeBase)

    ready_article =
      suggestion_fixture(%{
        id: 10,
        suggestion_type: :article,
        entrypoint_type: :gap_candidate,
        entrypoint_id: 101,
        status: :ready,
        title: "Billing export guide"
      })

    ready_revision =
      suggestion_fixture(%{
        id: 11,
        suggestion_type: :revision,
        entrypoint_type: :article_revision,
        entrypoint_id: 77,
        article_id: 77,
        base_revision_id: 44,
        status: :ready,
        title: "Billing export guide",
        proposed_markdown: "# After\n\nNew copy",
        grounding_metadata: %{"stale_signal" => %{"signal_count" => 3}}
      })

    failed_revision =
      suggestion_fixture(%{
        id: 12,
        suggestion_type: :revision,
        entrypoint_type: :article_revision,
        entrypoint_id: 77,
        article_id: 77,
        base_revision_id: 44,
        status: :failed,
        title: "Billing export guide",
        grounding_metadata: %{"failure_reason" => "missing_canonical_citations"}
      })

    pending_task =
      review_task_fixture(%{
        id: 21,
        status: :pending_review,
        article_suggestion_id: ready_article.id,
        article_suggestion: ready_article,
        events: [
          review_task_event_fixture(%{
            review_task_id: 21,
            event_type: :task_created,
            to_status: :pending_review,
            actor_id: "user-1",
            metadata: %{article_suggestion_id: ready_article.id}
          })
        ]
      })

    approved_task =
      review_task_fixture(%{
        id: 22,
        status: :approved_ready_to_publish,
        last_decision: :approved,
        last_reason: :ready_to_publish,
        last_actor_id: "reviewer-1",
        last_decided_at: ~U[2026-05-22 08:00:00Z],
        staged_article_id: 77,
        staged_revision_id: 45,
        article_suggestion_id: ready_revision.id,
        article_suggestion: ready_revision,
        events: [
          review_task_event_fixture(%{
            review_task_id: 22,
            event_type: :task_created,
            to_status: :pending_review,
            actor_id: "user-1",
            metadata: %{article_suggestion_id: ready_revision.id}
          }),
          review_task_event_fixture(%{
            review_task_id: 22,
            event_type: :decision_recorded,
            from_status: :pending_review,
            to_status: :approved_ready_to_publish,
            decision: :approved,
            reason: :ready_to_publish,
            actor_id: "reviewer-1",
            notes: "Grounded and ready.",
            metadata: %{staged_revision_id: 45}
          })
        ]
      })

    review_needed_task =
      review_task_fixture(%{
        id: 23,
        status: :review_needed,
        last_decision: :review_needed,
        last_reason: :draft_conflict,
        last_actor_id: "system",
        last_decided_at: ~U[2026-05-22 08:10:00Z],
        notes: "Another draft is already active.",
        article_suggestion_id: ready_revision.id,
        article_suggestion: ready_revision
      })

    rejected_task =
      review_task_fixture(%{
        id: 24,
        status: :rejected,
        last_decision: :rejected,
        last_reason: :insufficient_evidence,
        last_actor_id: "reviewer-2",
        last_decided_at: ~U[2026-05-22 08:20:00Z],
        notes: "One citation anchor needs work.",
        article_suggestion_id: failed_revision.id,
        article_suggestion: failed_revision
      })

    deferred_task =
      review_task_fixture(%{
        id: 25,
        status: :deferred,
        last_decision: :deferred,
        last_reason: :needs_manual_edit,
        last_actor_id: "reviewer-3",
        last_decided_at: ~U[2026-05-22 08:30:00Z],
        notes: "Send this through the editor.",
        article_suggestion_id: ready_article.id,
        article_suggestion: ready_article
      })

    published_task =
      review_task_fixture(%{
        id: 26,
        status: :published,
        last_decision: :approved,
        last_reason: :ready_to_publish,
        last_actor_id: "reviewer-1",
        last_decided_at: ~U[2026-05-22 08:40:00Z],
        published_revision_id: 88,
        published_at: ~U[2026-05-22 08:42:00Z],
        publish_status: :published,
        reindex_status: :queued,
        article_suggestion_id: ready_revision.id,
        article_suggestion: ready_revision,
        events: [
          review_task_event_fixture(%{
            review_task_id: 26,
            event_type: :publish_recorded,
            from_status: :approved_ready_to_publish,
            to_status: :published,
            decision: :approved,
            reason: :ready_to_publish,
            actor_id: "reviewer-1",
            metadata: %{published_revision_id: 88, publish_status: :published, reindex_status: :queued}
          })
        ]
      })

    review_tasks = [
      pending_task,
      approved_task,
      review_needed_task,
      rejected_task,
      deferred_task,
      published_task
    ]

    Process.put(:mock_suggestions, [ready_article, ready_revision, failed_revision])
    Process.put(:mock_review_tasks, review_tasks)

    Process.put(:mock_suggestion_lookup, fn
      10 -> ready_article
      11 -> ready_revision
      12 -> failed_revision
    end)

    Process.put(:mock_review_task_lookup, fn
      21 -> pending_task
      22 -> approved_task
      23 -> review_needed_task
      24 -> rejected_task
      25 -> deferred_task
      26 -> published_task
    end)

    on_exit(fn ->
      Process.delete(:mock_suggestions)
      Process.delete(:mock_suggestion_lookup)
      Process.delete(:mock_review_tasks)
      Process.delete(:mock_review_task_lookup)
      Application.delete_env(:cairnloop, :knowledge_automation)
      Application.delete_env(:cairnloop, :knowledge_base)
    end)

    :ok
  end

  test "review inbox lists task queue states and keeps approved or published work visible" do
    {:ok, socket} = SuggestionReview.mount(%{}, %{}, %Phoenix.LiveView.Socket{})
    html = render_html(socket.assigns)

    assert html =~ "Review inbox"
    assert html =~ "Pending review"
    assert html =~ "Approved-ready-to-publish"
    assert html =~ "Rejected"
    assert html =~ "Deferred"
    assert html =~ "Review needed"
    assert html =~ "Published"
    assert html =~ "Ready to publish when you are."
    assert html =~ "Published and queued for reindex follow-through."
  end

  test "task detail keeps evidence, citation anchors, proposal state, task state, and history together" do
    {:ok, socket} = SuggestionReview.mount(%{}, %{}, %Phoenix.LiveView.Socket{})
    {:noreply, socket} = SuggestionReview.handle_params(%{"task" => "22"}, "", socket)
    html = render_html(socket.assigns)

    assert html =~ "AI proposal status"
    assert html =~ "Ready for review"
    assert html =~ "Task status"
    assert html =~ "Approved-ready-to-publish"
    assert html =~ "Publish outcome"
    assert html =~ "Not published yet"
    assert html =~ "Canonical guidance"
    assert html =~ "/knowledge-base/77/edit"
    assert html =~ "Derived diff summary"
    assert html =~ "Structured history"
    assert html =~ "Approved by reviewer-1"
  end

  defp review_task_fixture(overrides) do
    base = %{
      status: :pending_review,
      tenant_scope: :host_user_scoped,
      host_user_id: "user-1",
      publish_status: :not_started,
      reindex_status: :not_started,
      needs_re_review: false,
      events: []
    }

    struct(ReviewTask, Map.merge(base, overrides))
  end

  defp review_task_event_fixture(overrides) do
    base = %{
      event_type: :decision_recorded,
      actor_id: "reviewer-1",
      metadata: %{}
    }

    struct(ReviewTaskEvent, Map.merge(base, overrides))
  end

  defp suggestion_fixture(overrides) do
    base = %{
      stable_key: "stable-key-#{System.unique_integer([:positive])}",
      suggestion_type: :article,
      status: :ready,
      tenant_scope: :host_user_scoped,
      host_user_id: "user-1",
      entrypoint_type: :gap_candidate,
      entrypoint_id: 101,
      title: "Billing export guide",
      operator_summary: "Prepared from article-linked evidence.",
      proposed_markdown: "# Billing export\n\nSuggested update",
      evidence_snapshot: [
        struct(ArticleSuggestionEvidence, %{
          source_type: :knowledge_base,
          trust_level: :canonical,
          title: "Billing export reference",
          excerpt: "Use the export endpoint with a date range.",
          citation_target: %{article_id: 77, revision_id: 44, chunk_index: 2},
          metadata: %{destination: %{article_id: 77, revision_id: 44}},
          match_reasons: ["matched export settings"]
        })
      ],
      grounding_metadata: %{"status" => "strong"}
    }

    struct(ArticleSuggestion, Map.merge(base, overrides))
  end

  defp render_html(assigns) do
    assigns
    |> SuggestionReview.render()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
