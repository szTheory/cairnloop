defmodule Cairnloop.Web.KnowledgeBaseLive.SuggestionReviewTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestionEvidence
  alias Cairnloop.KnowledgeAutomation.GapCandidate
  alias Cairnloop.KnowledgeAutomation.ReviewTask
  alias Cairnloop.KnowledgeAutomation.ReviewTaskEvent
  alias Cairnloop.KnowledgeBase.Article
  alias Cairnloop.KnowledgeBase.Revision
  alias Cairnloop.Web.KnowledgeBaseLive.{Gaps, Index}
  alias Cairnloop.Web.KnowledgeBaseLive.SuggestionReview

  defmodule MockKnowledgeAutomation do
    def list_article_suggestions(_opts) do
      Process.get(:mock_suggestion_ids, [])
      |> Enum.map(&get_article_suggestion!(&1))
    end

    def get_article_suggestion!(id, _opts \\ []) do
      Process.get(:mock_suggestion_map, %{}) |> Map.fetch!(id)
    end

    def list_review_tasks(opts) do
      status = Keyword.get(opts, :status)

      Process.get(:mock_review_task_ids, [])
      |> Enum.map(&get_review_task!(&1))
      |> Enum.filter(fn task -> is_nil(status) || task.status == status end)
    end

    def get_review_task!(id, _opts \\ []) do
      Process.get(:mock_review_task_map, %{}) |> Map.fetch!(id)
    end

    def dismiss_article_suggestion(id, _opts) do
      {:ok, get_article_suggestion!(id)}
    end

    def regenerate_article_suggestion(id, _opts) do
      {:ok, get_article_suggestion!(id)}
    end

    def create_or_reuse_authoring_article_for_suggestion(_id, _opts) do
      {:ok, 91}
    end

    def ensure_review_task_for_suggestion(suggestion_id, _opts \\ []) do
      task =
        Process.get(:mock_review_task_map, %{})
        |> Map.values()
        |> Enum.find(fn task -> task.article_suggestion_id == suggestion_id end)

      {:ok, task}
    end

    def list_gap_candidates(_opts) do
      [get_gap_candidate!(101)]
    end

    def get_gap_candidate!(id, _opts \\ []) do
      Process.get(:mock_gap_candidate_map, %{}) |> Map.fetch!(id)
    end

    def approve_review_task(id, _opts) do
      task =
        get_review_task!(id)
        |> Map.merge(%{
          status: :approved_ready_to_publish,
          last_decision: :approved,
          last_reason: :ready_to_publish,
          last_actor_id: "reviewer-1",
          last_decided_at: ~U[2026-05-22 09:00:00Z],
          staged_revision_id: 45,
          notes: "Grounded and ready.",
          events:
            get_review_task!(id).events ++
              [
                review_task_event(%{
                  review_task_id: id,
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

      put_review_task(task)
      {:ok, task}
    end

    def reject_review_task(id, _opts) do
      task =
        get_review_task!(id)
        |> Map.merge(%{
          status: :rejected,
          last_decision: :rejected,
          last_reason: :insufficient_evidence,
          last_actor_id: "reviewer-2",
          last_decided_at: ~U[2026-05-22 09:10:00Z],
          notes: "One citation anchor needs work."
        })

      put_review_task(task)
      {:ok, task}
    end

    def defer_review_task(id, _opts) do
      task =
        get_review_task!(id)
        |> Map.merge(%{
          status: :deferred,
          last_decision: :deferred,
          last_reason: :needs_manual_edit,
          last_actor_id: "reviewer-3",
          last_decided_at: ~U[2026-05-22 09:20:00Z],
          notes: "Send this through the editor."
        })

      put_review_task(task)
      {:ok, task}
    end

    def publish_review_task(id, _opts) do
      task =
        get_review_task!(id)
        |> Map.merge(%{
          status: :published,
          published_revision_id: 88,
          published_at: ~U[2026-05-22 09:30:00Z],
          publish_status: :published,
          reindex_status: :queued,
          events:
            get_review_task!(id).events ++
              [
                review_task_event(%{
                  review_task_id: id,
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

      put_review_task(task)
      {:ok, task}
    end

    def suggest_article(_attrs) do
      {:ok, get_article_suggestion!(10)}
    end

    def suggest_revision(_attrs) do
      {:ok, get_article_suggestion!(11)}
    end

    defp put_review_task(task) do
      task_map = Process.get(:mock_review_task_map, %{})
      Process.put(:mock_review_task_map, Map.put(task_map, task.id, task))
    end

    defp review_task_event(attrs) do
      struct(ReviewTaskEvent, attrs)
    end
  end

  defmodule MockRepo do
    def all(Article) do
      [%Article{id: 77, title: "Billing export guide", status: :published}]
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
    Application.put_env(:cairnloop, :repo, MockRepo)

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

    Process.put(:mock_suggestion_ids, [10, 11, 12])
    Process.put(:mock_suggestion_map, %{10 => ready_article, 11 => ready_revision, 12 => failed_revision})
    Process.put(:mock_review_task_ids, Enum.map(review_tasks, & &1.id))
    Process.put(:mock_review_task_map, Map.new(review_tasks, &{&1.id, &1}))
    Process.put(:mock_gap_candidate_map, %{
      101 =>
        struct(GapCandidate, %{
          id: 101,
          stable_key: "gap-101-key",
          status: :open,
          candidate_type: :mixed,
          title: "Billing export guide",
          seed_excerpt: "Customers cannot find billing exports.",
          tenant_scope: :host_user_scoped,
          host_user_id: "user-1",
          ui_surface: :inbox,
          first_seen_at: ~U[2026-05-22 07:00:00Z],
          last_seen_at: ~U[2026-05-22 08:00:00Z],
          evidence_count: 3,
          manual_case_count: 1,
          retrieval_gap_events: [],
          manual_handling_evidence: []
        })
    })

    on_exit(fn ->
      Process.delete(:mock_suggestion_ids)
      Process.delete(:mock_suggestion_map)
      Process.delete(:mock_review_task_ids)
      Process.delete(:mock_review_task_map)
      Process.delete(:mock_gap_candidate_map)
      Application.delete_env(:cairnloop, :knowledge_automation)
      Application.delete_env(:cairnloop, :knowledge_base)
      Application.delete_env(:cairnloop, :repo)
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

  test "task actions call review-task commands, reload detail, and keep publish gated to approved work" do
    {:ok, socket} = SuggestionReview.mount(%{}, %{}, %Phoenix.LiveView.Socket{})
    {:noreply, socket} = SuggestionReview.handle_params(%{"task" => "21"}, "", socket)

    pending_html = render_html(socket.assigns)
    refute pending_html =~ ">Publish<"

    {:noreply, approved_socket} = SuggestionReview.handle_event("approve", %{"id" => "21"}, socket)
    approved_html = render_html(approved_socket.assigns)

    assert approved_socket.assigns.selected_task.status == :approved_ready_to_publish
    assert approved_html =~ "Publish"
    assert approved_html =~ "Approved by reviewer-1"

    {:noreply, published_socket} =
      SuggestionReview.handle_event("publish", %{"id" => "21"}, approved_socket)

    published_html = render_html(published_socket.assigns)
    assert published_socket.assigns.selected_task.status == :published
    assert published_html =~ "Published revision #88. Reindex queued."
  end

  test "open_for_edit preserves review task context in the editor handoff" do
    {:ok, socket} = SuggestionReview.mount(%{}, %{}, %Phoenix.LiveView.Socket{})
    {:noreply, socket} = SuggestionReview.handle_params(%{"task" => "22"}, "", socket)
    {:noreply, edit_socket} = SuggestionReview.handle_event("open_for_edit", %{"id" => "22"}, socket)

    assert {:live, :redirect, %{to: path}} = edit_socket.redirected
    assert path =~ "/knowledge-base/77/edit?suggestion_id=11"
    assert path =~ "review_task_id=22"
    assert path =~ "return_to=%2Fknowledge-base%2Fsuggestions%3Ftask%3D22"
  end

  test "gap and article entrypoints deep-link into the shared review task lane" do
    {:ok, gaps_socket} = Gaps.mount(%{}, %{}, %Phoenix.LiveView.Socket{})
    {:noreply, gaps_socket} = Gaps.handle_params(%{"candidate" => "101"}, "", gaps_socket)
    {:noreply, gaps_redirected} = Gaps.handle_event("suggest_article", %{"candidate_id" => "101"}, gaps_socket)

    assert {:live, :redirect, %{to: "/knowledge-base/suggestions?task=21"}} =
             gaps_redirected.redirected

    {:ok, index_socket} = Index.mount(%{}, %{}, %Phoenix.LiveView.Socket{})
    {:noreply, index_redirected} = Index.handle_event("suggest_revision", %{"article_id" => "77"}, index_socket)

    assert {:live, :redirect, %{to: "/knowledge-base/suggestions?task=22"}} =
             index_redirected.redirected
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
