defmodule Cairnloop.KnowledgeAutomation.ReviewTaskTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation.{ReviewTask, ReviewTaskEvent}

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
      Process.get(:review_task_detail_lookup).(query)
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
end
