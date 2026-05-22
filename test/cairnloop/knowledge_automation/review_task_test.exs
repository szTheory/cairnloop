defmodule Cairnloop.KnowledgeAutomation.ReviewTaskTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeAutomation.{ReviewTask, ReviewTaskEvent}
  alias Cairnloop.KnowledgeAutomation.{ArticleSuggestion, ArticleSuggestionEvidence}

  defmodule MockRepo do
    def all(%Ecto.Query{} = query) do
      case query.from.source do
        {"cairnloop_review_tasks", _module} ->
          Process.get(:review_tasks, [])
          |> filter_scope(query)
          |> filter_status(query)
          |> sort_review_tasks()

        {"cairnloop_review_task_events", _module} ->
          Process.get(:review_task_events, [])
          |> Enum.sort_by(fn event -> {event.inserted_at, event.id || 0} end, :asc)

        _ ->
          []
      end
    end

    def one!(%Ecto.Query{} = query) do
      case query.from.source do
        {"cairnloop_review_tasks", _module} ->
          case Process.get(:review_task_detail_lookup) do
            lookup when is_function(lookup, 1) ->
              lookup.(query)

            _ ->
              Process.get(:review_tasks, [])
              |> filter_scope(query)
              |> List.first()
          end

        {"cairnloop_article_suggestions", _module} ->
          Process.get(:article_suggestions, [])
          |> Enum.find(fn suggestion ->
            Enum.all?(List.wrap(query.wheres), fn %{expr: expr, params: params} ->
              eval_condition(suggestion, expr, params)
            end)
          end)

        _ ->
          nil
      end
      |> case do
        nil -> raise Ecto.NoResultsError, queryable: query
        record -> record
      end
    end

    def insert(%Ecto.Changeset{} = changeset) do
      if changeset.valid? do
        struct =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> maybe_put_id()
          |> Map.put_new(:inserted_at, DateTime.utc_now())
          |> Map.put_new(:updated_at, DateTime.utc_now())

        Process.put(:last_inserted, struct)
        {:ok, struct}
      else
        {:error, changeset}
      end
    end

    def update(%Ecto.Changeset{} = changeset) do
      if changeset.valid? do
        struct =
          changeset
          |> Ecto.Changeset.apply_changes()
          |> Map.put(:updated_at, DateTime.utc_now())

        Process.put(:last_updated, struct)
        {:ok, struct}
      else
        {:error, changeset}
      end
    end

    def preload(struct_or_structs, preloads)

    def preload(structs, preloads) when is_list(structs) do
      Enum.map(structs, &preload(&1, preloads))
    end

    def preload(%{__struct__: module} = task, preloads)
        when module == ReviewTask do
      preload_map = Map.new(List.wrap(preloads), &normalize_preload/1)

      task
      |> maybe_preload_suggestion(preload_map)
      |> maybe_preload_events(preload_map)
    end

    def preload(struct, _preloads), do: struct

    defp normalize_preload({key, nested}), do: {key, List.wrap(nested)}
    defp normalize_preload(key), do: {key, []}

    defp maybe_preload_suggestion(task, preload_map) do
      case Map.fetch(preload_map, :article_suggestion) do
        :error ->
          task

        {:ok, nested} ->
          suggestion =
            Process.get(:article_suggestions, [])
            |> Enum.find(&(&1.id == task.article_suggestion_id))
            |> maybe_preload_suggestion_evidence(nested)

          %{task | article_suggestion: suggestion}
      end
    end

    defp maybe_preload_suggestion_evidence(nil, _nested), do: nil
    defp maybe_preload_suggestion_evidence(suggestion, _nested), do: suggestion

    defp maybe_preload_events(task, preload_map) do
      if Map.has_key?(preload_map, :events) do
        events =
          Process.get(:review_task_events, [])
          |> Enum.filter(&(&1.review_task_id == task.id))
          |> Enum.sort_by(fn event -> {event.inserted_at, event.id || 0} end, :asc)

        %{task | events: events}
      else
        task
      end
    end

    defp maybe_put_id(%{id: nil} = struct), do: %{struct | id: System.unique_integer([:positive])}
    defp maybe_put_id(struct), do: struct

    defp sort_review_tasks(tasks) do
      urgency_rank = %{
        pending_review: 0,
        review_needed: 1,
        approved_ready_to_publish: 2,
        deferred: 3,
        rejected: 4,
        published: 5
      }

      Enum.sort_by(
        tasks,
        fn task ->
          {Map.fetch!(urgency_rank, task.status),
           -(task.inserted_at |> DateTime.to_unix(:microsecond)), -(task.id || 0)}
        end
      )
    end

    defp filter_scope(tasks, query) do
      conditions = List.wrap(query.wheres)

      Enum.filter(tasks, fn task ->
        Enum.all?(conditions, fn %{expr: expr, params: params} ->
          eval_condition(task, expr, params)
        end)
      end)
    end

    defp filter_status(tasks, %Ecto.Query{}), do: tasks

    defp eval_condition(
           task,
           {:==, [], [{{:., [], [{:&, [], [0]}, field]}, [], []}, {:^, [], [index]}]},
           params
         ) do
      {value, _} = Enum.at(params, index)
      Map.get(task, field) == value
    end

    defp eval_condition(_task, _expr, _params), do: true
  end

  setup do
    original_repo = Application.get_env(:cairnloop, :repo)
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      [
        :review_tasks,
        :review_task_events,
        :review_task_detail_lookup,
        :article_suggestions,
        :last_inserted,
        :last_updated
      ]
      |> Enum.each(&Process.delete/1)

      if original_repo do
        Application.put_env(:cairnloop, :repo, original_repo)
      else
        Application.delete_env(:cairnloop, :repo)
      end
    end)

    :ok
  end

  test "review task changeset accepts linked suggestion state and rejects missing structured workflow fields" do
    changeset = ReviewTask.changeset(%ReviewTask{}, valid_review_task_attrs())

    assert changeset.valid?

    invalid =
      ReviewTask.changeset(%ReviewTask{}, %{
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :approved_ready_to_publish
      })

    refute invalid.valid?
    assert "can't be blank" in errors_on(invalid).article_suggestion_id
    assert "can't be blank" in errors_on(invalid).last_decision
    assert "can't be blank" in errors_on(invalid).last_actor_id
    assert "can't be blank" in errors_on(invalid).last_decided_at
  end

  test "review task preserves proposal reference, decision metadata, and canonical publish outcome separately" do
    changeset =
      ReviewTask.changeset(%ReviewTask{}, %{
        article_suggestion_id: 42,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :published,
        last_decision: :approved,
        last_reason: :ready_to_publish,
        last_actor_id: "operator-7",
        last_decided_at: ~U[2026-05-22 09:00:00Z],
        staged_article_id: 10,
        staged_revision_id: 11,
        published_revision_id: 12,
        published_at: ~U[2026-05-22 10:00:00Z],
        publish_status: :published,
        reindex_status: :queued,
        needs_re_review: false
      })

    assert changeset.valid?
    task = Ecto.Changeset.apply_changes(changeset)
    assert task.article_suggestion_id == 42
    assert task.last_decision == :approved
    assert task.published_revision_id == 12
  end

  test "reject, defer, and review-needed states require bounded reasons while notes stay optional" do
    rejected =
      ReviewTask.changeset(%ReviewTask{}, %{
        article_suggestion_id: 42,
        tenant_scope: :public_only,
        status: :rejected,
        last_decision: :rejected,
        last_actor_id: "operator-7",
        last_decided_at: ~U[2026-05-22 09:00:00Z]
      })

    refute rejected.valid?
    assert "can't be blank" in errors_on(rejected).last_reason

    valid_review_needed =
      ReviewTask.changeset(%ReviewTask{}, %{
        article_suggestion_id: 42,
        tenant_scope: :public_only,
        status: :review_needed,
        last_decision: :review_needed,
        last_reason: :freshness_invalidated,
        last_actor_id: "operator-7",
        last_decided_at: ~U[2026-05-22 09:00:00Z]
      })

    assert valid_review_needed.valid?
    assert is_nil(Ecto.Changeset.get_change(valid_review_needed, :notes))
  end

  test "review task event changeset is append-only and requires structured actor metadata" do
    changeset =
      ReviewTaskEvent.changeset(%ReviewTaskEvent{}, %{
        review_task_id: 9,
        event_type: :decision_recorded,
        from_status: :pending_review,
        to_status: :approved_ready_to_publish,
        decision: :approved,
        reason: :ready_to_publish,
        actor_id: "operator-7",
        metadata: %{publish_status: "queued"}
      })

    assert changeset.valid?

    invalid =
      ReviewTaskEvent.changeset(%ReviewTaskEvent{}, %{
        review_task_id: 9,
        event_type: :decision_recorded
      })

    refute invalid.valid?
    assert "can't be blank" in errors_on(invalid).to_status
    assert "can't be blank" in errors_on(invalid).actor_id
  end

  test "migration creates one active task index and append-only events table" do
    [migration] = Path.wildcard("priv/repo/migrations/*_add_review_tasks_and_events.exs")
    content = File.read!(migration)

    assert content =~ "create table(:cairnloop_review_tasks)"
    assert content =~ "create table(:cairnloop_review_task_events)"

    assert content =~
             "status IN ('pending_review', 'review_needed', 'approved_ready_to_publish', 'deferred')"

    assert content =~ "index(:cairnloop_review_tasks, [:status, :inserted_at])"
    assert content =~ "index(:cairnloop_review_task_events, [:review_task_id, :inserted_at])"
    assert content =~ "timestamps(type: :utc_datetime_usec, updated_at: false)"
  end

  test "list_review_tasks orders by queue urgency and filters by status while preserving scope" do
    Process.put(:review_tasks, [
      review_task_fixture(%{
        id: 1,
        article_suggestion_id: 10,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :published,
        inserted_at: ~U[2026-05-22 08:00:00Z]
      }),
      review_task_fixture(%{
        id: 2,
        article_suggestion_id: 11,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :approved_ready_to_publish,
        inserted_at: ~U[2026-05-22 09:00:00Z]
      }),
      review_task_fixture(%{
        id: 3,
        article_suggestion_id: 12,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :pending_review,
        inserted_at: ~U[2026-05-22 10:00:00Z]
      }),
      review_task_fixture(%{
        id: 4,
        article_suggestion_id: 13,
        tenant_scope: :host_user_scoped,
        host_user_id: "other-host",
        status: :review_needed,
        inserted_at: ~U[2026-05-22 11:00:00Z]
      })
    ])

    tasks = KnowledgeAutomation.list_review_tasks(host_user_id: "host-1")
    assert Enum.map(tasks, & &1.id) == [3, 2, 1]

    filtered =
      KnowledgeAutomation.list_review_tasks(
        host_user_id: "host-1",
        status: :approved_ready_to_publish
      )

    assert Enum.map(filtered, & &1.id) == [2]
  end

  test "get_review_task! preloads linked suggestion and task history" do
    suggestion = suggestion_fixture(%{id: 55, status: :ready})

    task =
      review_task_fixture(%{
        id: 77,
        article_suggestion_id: suggestion.id,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1"
      })

    events = [
      review_task_event_fixture(%{
        id: 1,
        review_task_id: task.id,
        inserted_at: ~U[2026-05-22 08:00:00Z]
      }),
      review_task_event_fixture(%{
        id: 2,
        review_task_id: task.id,
        event_type: :decision_recorded,
        from_status: :pending_review,
        to_status: :approved_ready_to_publish,
        decision: :approved,
        reason: :ready_to_publish,
        inserted_at: ~U[2026-05-22 09:00:00Z]
      })
    ]

    Process.put(:article_suggestions, [suggestion])
    Process.put(:review_task_events, events)
    Process.put(:review_task_detail_lookup, fn _query -> task end)

    loaded = KnowledgeAutomation.get_review_task!(77, host_user_id: "host-1")
    assert loaded.article_suggestion.id == suggestion.id
    assert Enum.map(loaded.events, & &1.id) == [1, 2]
    assert loaded.article_suggestion.proposed_markdown =~ "Proposed KB update"
  end

  test "ensure_review_task_for_suggestion creates one active task and appends a task_created event" do
    suggestion = suggestion_fixture(%{id: 88, status: :ready, host_user_id: "host-1"})
    Process.put(:article_suggestions, [suggestion])
    Process.put(:review_tasks, [])
    Process.put(:review_task_events, [])

    {:ok, task} =
      KnowledgeAutomation.ensure_review_task_for_suggestion(suggestion.id,
        host_user_id: "host-1",
        actor_id: "operator-7"
      )

    assert task.article_suggestion_id == suggestion.id
    assert task.status == :pending_review

    event = Process.get(:last_inserted)
    assert Map.get(event, :__struct__) == ReviewTaskEvent
    assert event.event_type == :task_created
  end

  test "ensure_review_task_for_suggestion returns the existing active task without duplicating rows" do
    suggestion = suggestion_fixture(%{id: 91, status: :failed, host_user_id: "host-1"})

    existing_task =
      review_task_fixture(%{
        id: 44,
        article_suggestion_id: suggestion.id,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :review_needed
      })

    Process.put(:article_suggestions, [suggestion])
    Process.put(:review_tasks, [existing_task])

    {:ok, task} =
      KnowledgeAutomation.ensure_review_task_for_suggestion(suggestion.id,
        host_user_id: "host-1",
        actor_id: "operator-7"
      )

    assert task.id == existing_task.id
    assert Process.get(:last_inserted) == nil
  end

  test "ensure_review_task_for_suggestion rejects non-reviewable suggestions and does not mutate suggestion workflow state" do
    dismissed = suggestion_fixture(%{id: 92, status: :dismissed, host_user_id: "host-1"})
    Process.put(:article_suggestions, [dismissed])

    assert {:error, :suggestion_not_reviewable} =
             KnowledgeAutomation.ensure_review_task_for_suggestion(dismissed.id,
               host_user_id: "host-1",
               actor_id: "operator-7"
             )

    assert Process.get(:last_updated) == nil
  end

  test "approve_review_task stages a draft, records structured decision metadata, and moves the task to approved_ready_to_publish" do
    suggestion =
      suggestion_fixture(%{
        id: 101,
        suggestion_type: :revision,
        entrypoint_type: :article_revision,
        entrypoint_id: 21,
        article_id: 21,
        base_revision_id: 301
      })

    task =
      review_task_fixture(%{
        id: 501,
        article_suggestion_id: suggestion.id,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :pending_review
      })

    staged_revision = %Cairnloop.KnowledgeBase.Revision{
      id: 401,
      article_id: 21,
      version: 3,
      state: :draft,
      content: suggestion.proposed_markdown
    }

    now = ~U[2026-05-22 12:00:00Z]

    Process.put(:article_suggestions, [suggestion])
    Process.put(:review_task_detail_lookup, fn _query -> task end)
    Process.put(:review_task_events, [])

    {:ok, updated_task} =
      KnowledgeAutomation.approve_review_task(task.id,
        host_user_id: "host-1",
        actor_id: "operator-7",
        note: "Ready after review",
        now_fn: fn -> now end,
        load_article_fn: fn 21 -> {:ok, %Cairnloop.KnowledgeBase.Article{id: 21, title: "Exports"}} end,
        latest_revision_fn: fn 21 -> %Cairnloop.KnowledgeBase.Revision{id: 301, article_id: 21, version: 2, state: :published} end,
        save_draft_fn: fn article, attrs ->
          assert article.id == 21
          assert attrs.content == suggestion.proposed_markdown
          {:ok, staged_revision}
        end
      )

    assert updated_task.status == :approved_ready_to_publish
    assert updated_task.staged_article_id == 21
    assert updated_task.staged_revision_id == staged_revision.id
    assert updated_task.last_decision == :approved
    assert updated_task.last_reason == :ready_to_publish
    assert updated_task.last_actor_id == "operator-7"
    assert DateTime.truncate(updated_task.last_decided_at, :second) == now
    assert updated_task.notes == "Ready after review"

    event = Process.get(:last_inserted)
    assert event.event_type == :decision_recorded
    assert event.review_task_id == task.id
    assert event.from_status == :pending_review
    assert event.to_status == :approved_ready_to_publish
    assert event.decision == :approved
    assert event.reason == :ready_to_publish
    assert event.notes == "Ready after review"
    assert event.metadata.staged_revision_id == staged_revision.id
  end

  test "approve_review_task fails closed when another active draft would be overwritten" do
    suggestion =
      suggestion_fixture(%{
        id: 102,
        suggestion_type: :revision,
        entrypoint_type: :article_revision,
        entrypoint_id: 21,
        article_id: 21,
        base_revision_id: 301
      })

    task =
      review_task_fixture(%{
        id: 502,
        article_suggestion_id: suggestion.id,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :pending_review
      })

    conflicting_draft = %Cairnloop.KnowledgeBase.Revision{
      id: 999,
      article_id: 21,
      version: 3,
      state: :draft,
      content: "Somebody else's draft"
    }

    now = ~U[2026-05-22 12:05:00Z]

    Process.put(:article_suggestions, [suggestion])
    Process.put(:review_task_detail_lookup, fn _query -> task end)
    Process.put(:review_task_events, [])

    assert {:error, {:draft_conflict, updated_task}} =
             KnowledgeAutomation.approve_review_task(task.id,
               host_user_id: "host-1",
               actor_id: "operator-7",
               now_fn: fn -> now end,
               load_article_fn: fn 21 ->
                 {:ok, %Cairnloop.KnowledgeBase.Article{id: 21, title: "Exports"}}
               end,
               latest_revision_fn: fn 21 -> conflicting_draft end,
               save_draft_fn: fn _article, _attrs -> flunk("should not save when unrelated draft exists") end
             )

    assert updated_task.status == :review_needed
    assert updated_task.last_decision == :review_needed
    assert updated_task.last_reason == :draft_conflict
    assert updated_task.last_actor_id == "operator-7"
    assert DateTime.truncate(updated_task.last_decided_at, :second) == now
    assert updated_task.notes =~ "draft"

    event = Process.get(:last_inserted)
    assert event.event_type == :decision_recorded
    assert event.to_status == :review_needed
    assert event.reason == :draft_conflict
    assert event.metadata.conflicting_revision_id == conflicting_draft.id
  end

  test "reject_review_task and defer_review_task require bounded reasons and append structured history" do
    suggestion = suggestion_fixture(%{id: 103})

    task =
      review_task_fixture(%{
        id: 503,
        article_suggestion_id: suggestion.id,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :pending_review
      })

    Process.put(:article_suggestions, [suggestion])
    Process.put(:review_task_detail_lookup, fn _query -> task end)

    assert {:error, :invalid_reason} =
             KnowledgeAutomation.reject_review_task(task.id,
               host_user_id: "host-1",
               actor_id: "operator-7",
               reason: :ready_to_publish
             )

    now = ~U[2026-05-22 12:10:00Z]

    {:ok, rejected_task} =
      KnowledgeAutomation.reject_review_task(task.id,
        host_user_id: "host-1",
        actor_id: "operator-7",
        reason: :policy_rejected,
        note: "Needs policy rewrite",
        now_fn: fn -> now end
      )

    assert rejected_task.status == :rejected
    assert rejected_task.last_decision == :rejected
    assert rejected_task.last_reason == :policy_rejected
    assert rejected_task.notes == "Needs policy rewrite"

    rejection_event = Process.get(:last_inserted)
    assert rejection_event.event_type == :decision_recorded
    assert rejection_event.to_status == :rejected
    assert rejection_event.reason == :policy_rejected
    assert rejection_event.notes == "Needs policy rewrite"

    defer_now = ~U[2026-05-22 12:11:00Z]

    {:ok, deferred_task} =
      KnowledgeAutomation.defer_review_task(task.id,
        host_user_id: "host-1",
        actor_id: "operator-8",
        reason: :operator_deferred,
        now_fn: fn -> defer_now end
      )

    assert deferred_task.status == :deferred
    assert deferred_task.last_decision == :deferred
    assert deferred_task.last_reason == :operator_deferred
    assert deferred_task.notes == nil
  end

  test "repeated approve_review_task updates only the task-owned staged draft" do
    suggestion =
      suggestion_fixture(%{
        id: 104,
        suggestion_type: :revision,
        entrypoint_type: :article_revision,
        entrypoint_id: 21,
        article_id: 21,
        base_revision_id: 301,
        proposed_markdown: "# Revised export KB\n\nUse the export endpoint with a tenant filter."
      })

    task =
      review_task_fixture(%{
        id: 504,
        article_suggestion_id: suggestion.id,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :approved_ready_to_publish,
        staged_article_id: 21,
        staged_revision_id: 401,
        last_decision: :approved,
        last_reason: :ready_to_publish,
        last_actor_id: "operator-6",
        last_decided_at: ~U[2026-05-22 11:00:00Z]
      })

    owned_draft = %Cairnloop.KnowledgeBase.Revision{
      id: 401,
      article_id: 21,
      version: 3,
      state: :draft,
      content: "Old task-owned draft"
    }

    Process.put(:article_suggestions, [suggestion])
    Process.put(:review_task_detail_lookup, fn _query -> task end)
    Process.put(:review_task_events, [])

    {:ok, updated_task} =
      KnowledgeAutomation.approve_review_task(task.id,
        host_user_id: "host-1",
        actor_id: "operator-7",
        load_article_fn: fn 21 -> {:ok, %Cairnloop.KnowledgeBase.Article{id: 21, title: "Exports"}} end,
        latest_revision_fn: fn 21 -> owned_draft end,
        save_draft_fn: fn _article, attrs ->
          assert attrs.content == suggestion.proposed_markdown
          {:ok, %{owned_draft | content: attrs.content}}
        end
      )

    assert updated_task.staged_revision_id == owned_draft.id
    assert updated_task.status == :approved_ready_to_publish
  end

  test "publish_review_task publishes the staged draft for approved tasks and records canonical linkage" do
    suggestion =
      suggestion_fixture(%{
        id: 105,
        suggestion_type: :revision,
        entrypoint_type: :article_revision,
        entrypoint_id: 21,
        article_id: 21,
        base_revision_id: 301
      })

    task =
      review_task_fixture(%{
        id: 505,
        article_suggestion_id: suggestion.id,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :approved_ready_to_publish,
        staged_article_id: 21,
        staged_revision_id: 401,
        last_decision: :approved,
        last_reason: :ready_to_publish,
        last_actor_id: "operator-7",
        last_decided_at: ~U[2026-05-22 12:00:00Z]
      })

    staged_revision = %Cairnloop.KnowledgeBase.Revision{
      id: 401,
      article_id: 21,
      version: 3,
      state: :draft,
      content: suggestion.proposed_markdown
    }

    published_revision = %{staged_revision | state: :published}
    now = ~U[2026-05-22 12:20:00Z]

    Process.put(:article_suggestions, [suggestion])
    Process.put(:review_task_detail_lookup, fn _query -> task end)
    Process.put(:review_task_events, [])

    {:ok, published_task} =
      KnowledgeAutomation.publish_review_task(task.id,
        host_user_id: "host-1",
        actor_id: "operator-9",
        now_fn: fn -> now end,
        get_revision_fn: fn 401 -> staged_revision end,
        latest_active_revision_fn: fn 21 ->
          %Cairnloop.KnowledgeBase.Revision{id: 301, article_id: 21, version: 2, state: :published}
        end,
        publish_revision_fn: fn revision ->
          assert revision.id == staged_revision.id
          {:ok, published_revision}
        end
      )

    assert published_task.status == :published
    assert published_task.published_revision_id == published_revision.id
    assert DateTime.truncate(published_task.published_at, :second) == now
    assert published_task.publish_status == :published
    assert published_task.reindex_status == :queued

    event = Process.get(:last_inserted)
    assert event.event_type == :publish_recorded
    assert event.from_status == :approved_ready_to_publish
    assert event.to_status == :published
    assert event.metadata.staged_revision_id == staged_revision.id
    assert event.metadata.published_revision_id == published_revision.id
  end

  test "publish_review_task fails stale revision tasks closed and returns them to review_needed" do
    suggestion =
      suggestion_fixture(%{
        id: 106,
        suggestion_type: :revision,
        entrypoint_type: :article_revision,
        entrypoint_id: 21,
        article_id: 21,
        base_revision_id: 301
      })

    task =
      review_task_fixture(%{
        id: 506,
        article_suggestion_id: suggestion.id,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :approved_ready_to_publish,
        staged_article_id: 21,
        staged_revision_id: 402,
        last_decision: :approved,
        last_reason: :ready_to_publish,
        last_actor_id: "operator-7",
        last_decided_at: ~U[2026-05-22 12:00:00Z]
      })

    staged_revision = %Cairnloop.KnowledgeBase.Revision{
      id: 402,
      article_id: 21,
      version: 3,
      state: :draft,
      content: suggestion.proposed_markdown
    }

    latest_active_revision = %Cairnloop.KnowledgeBase.Revision{
      id: 999,
      article_id: 21,
      version: 4,
      state: :published,
      content: "Newer published content"
    }

    now = ~U[2026-05-22 12:25:00Z]

    Process.put(:article_suggestions, [suggestion])
    Process.put(:review_task_detail_lookup, fn _query -> task end)
    Process.put(:review_task_events, [])

    assert {:error, {:stale_base, updated_task}} =
             KnowledgeAutomation.publish_review_task(task.id,
               host_user_id: "host-1",
               actor_id: "operator-9",
               now_fn: fn -> now end,
               get_revision_fn: fn 402 -> staged_revision end,
               latest_active_revision_fn: fn 21 -> latest_active_revision end,
               publish_revision_fn: fn _revision -> flunk("should not publish a stale draft") end
             )

    assert updated_task.status == :review_needed
    assert updated_task.last_decision == :review_needed
    assert updated_task.last_reason == :freshness_invalidated
    assert updated_task.publish_status == :not_started
    assert updated_task.notes =~ "latest active revision"

    event = Process.get(:last_inserted)
    assert event.event_type == :publish_recorded
    assert event.to_status == :review_needed
    assert event.reason == :freshness_invalidated
    assert event.metadata.latest_active_revision_id == latest_active_revision.id
  end

  test "publish_review_task publishes article-creation tasks through the same canonical path" do
    suggestion =
      suggestion_fixture(%{
        id: 107,
        suggestion_type: :article,
        entrypoint_type: :gap_candidate,
        entrypoint_id: 88,
        article_id: nil,
        base_revision_id: nil
      })

    task =
      review_task_fixture(%{
        id: 507,
        article_suggestion_id: suggestion.id,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :approved_ready_to_publish,
        staged_article_id: 77,
        staged_revision_id: 403,
        last_decision: :approved,
        last_reason: :ready_to_publish,
        last_actor_id: "operator-7",
        last_decided_at: ~U[2026-05-22 12:00:00Z]
      })

    staged_revision = %Cairnloop.KnowledgeBase.Revision{
      id: 403,
      article_id: 77,
      version: 1,
      state: :draft,
      content: suggestion.proposed_markdown
    }

    Process.put(:article_suggestions, [suggestion])
    Process.put(:review_task_detail_lookup, fn _query -> task end)
    Process.put(:review_task_events, [])

    {:ok, published_task} =
      KnowledgeAutomation.publish_review_task(task.id,
        host_user_id: "host-1",
        actor_id: "operator-9",
        get_revision_fn: fn 403 -> staged_revision end,
        publish_revision_fn: fn revision ->
          assert revision.id == staged_revision.id
          {:ok, %{staged_revision | state: :published}}
        end
      )

    assert published_task.status == :published
    assert published_task.published_revision_id == staged_revision.id
  end

  test "publish_review_task rejects tasks that are not approved_ready_to_publish" do
    suggestion = suggestion_fixture(%{id: 108})

    task =
      review_task_fixture(%{
        id: 508,
        article_suggestion_id: suggestion.id,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :pending_review
      })

    Process.put(:article_suggestions, [suggestion])
    Process.put(:review_task_detail_lookup, fn _query -> task end)

    assert {:error, :invalid_publish_state} =
             KnowledgeAutomation.publish_review_task(task.id,
               host_user_id: "host-1",
               actor_id: "operator-9"
             )
  end

  defp valid_review_task_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        article_suggestion_id: 42,
        tenant_scope: :host_user_scoped,
        host_user_id: "host-1",
        status: :pending_review
      },
      overrides
    )
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)
  end

  defp review_task_fixture(overrides) do
    struct!(
      ReviewTask,
      Map.merge(
        %{
          id: System.unique_integer([:positive]),
          article_suggestion_id: 42,
          tenant_scope: :public_only,
          host_user_id: nil,
          status: :pending_review,
          last_decision: nil,
          last_reason: nil,
          last_actor_id: nil,
          last_decided_at: nil,
          notes: nil,
          publish_status: :not_started,
          reindex_status: :not_started,
          needs_re_review: false,
          inserted_at: ~U[2026-05-22 08:00:00Z],
          updated_at: ~U[2026-05-22 08:00:00Z]
        },
        overrides
      )
    )
  end

  defp review_task_event_fixture(overrides) do
    struct!(
      ReviewTaskEvent,
      Map.merge(
        %{
          id: System.unique_integer([:positive]),
          review_task_id: 42,
          event_type: :task_created,
          from_status: nil,
          to_status: :pending_review,
          decision: nil,
          reason: nil,
          actor_id: "operator-7",
          notes: nil,
          metadata: %{},
          inserted_at: ~U[2026-05-22 08:00:00Z]
        },
        overrides
      )
    )
  end

  defp suggestion_fixture(overrides) do
    evidence =
      struct!(ArticleSuggestionEvidence, %{
        source_type: :knowledge_base,
        trust_level: :canonical,
        title: "Billing export",
        excerpt: "Use the export endpoint with a date range.",
        citation_target: %{article_id: 7, revision_id: 11, chunk_index: 2},
        metadata: %{destination: %{article_id: 7, revision_id: 11}},
        match_reasons: ["canonical_match"]
      })

    struct!(
      ArticleSuggestion,
      Map.merge(
        %{
          id: System.unique_integer([:positive]),
          stable_key: "suggestion:#{System.unique_integer([:positive])}",
          suggestion_type: :article,
          status: :ready,
          tenant_scope: :host_user_scoped,
          host_user_id: "host-1",
          entrypoint_type: :gap_candidate,
          entrypoint_id: 10,
          proposed_markdown: "# Proposed KB update\n\nUse the export endpoint with a date range.",
          grounding_metadata: %{"status" => "strong"},
          evidence_snapshot: [evidence]
        },
        overrides
      )
    )
  end
end
