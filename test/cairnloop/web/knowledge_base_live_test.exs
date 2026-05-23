defmodule Cairnloop.Web.KnowledgeBaseLiveTest do
  use ExUnit.Case, async: false
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion
  alias Cairnloop.KnowledgeBase.{Article, Revision}
  alias Cairnloop.Web.KnowledgeBaseLive.EditorHandoff

  defmodule MockRepo do
    def all(Article) do
      [%Article{id: 42, title: "Test Article", status: :draft}]
    end

    def get!(Article, id) do
      if to_string(id) == "42" do
        %Article{id: 42, title: "Test Article", status: :draft}
      else
        raise Ecto.NoResultsError, queryable: Article
      end
    end

    def one(%Ecto.Query{} = query) do
      case Process.get(:mock_repo_one_lookup) do
        lookup when is_function(lookup, 1) -> lookup.(query)
        _ -> Process.get(:mock_repo_one_result)
      end
    end
    
    def insert(changeset, _opts \\ []) do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end

    def update(changeset, _opts \\ []) do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end
    
    def transaction(multi) do
      operations = Ecto.Multi.to_list(multi)

      results =
        Enum.reduce(operations, %{}, fn
          {name, {:insert, changeset, _}}, acc ->
            Map.put(acc, name, Ecto.Changeset.apply_changes(changeset))

          {name, {:update, changeset, _}}, acc when is_map(changeset) ->
            Map.put(acc, name, Ecto.Changeset.apply_changes(changeset))

          {name, {:update, run_fn, _}}, acc when is_function(run_fn) ->
            {:ok, result} = run_fn.(__MODULE__, acc)
            Map.put(acc, name, result)

          {name, {:run, run_fn}}, acc ->
            {:ok, result} = run_fn.(__MODULE__, acc)
            Map.put(acc, name, result)
        end)

      {:ok, results}
    end
  end

  defmodule MockKnowledgeAutomation do
    def get_article_suggestion!(id, opts \\ [])

    def get_article_suggestion!(15, _opts) do
      %ArticleSuggestion{
        id: 15,
        proposed_markdown: "# Suggested copy\n\nPrepared from review.",
        title: "Test Article"
      }
    end

    def get_article_suggestion!(16, _opts) do
      %ArticleSuggestion{
        id: 16,
        article_id: 999,
        proposed_markdown: "# Wrong article\n\nThis should not preload.",
        title: "Other Article"
      }
    end

    def get_article_suggestion!(17, _opts) do
      %ArticleSuggestion{
        id: 17,
        proposed_markdown: "# New KB draft\n\nPrepared from review.",
        title: "New Article",
        grounding_metadata: %{"authoring_article_id" => 42}
      }
    end

    def get_review_task!(id, opts \\ [])

    def get_review_task!(27, _opts) do
      Process.get(:mock_review_task)
    end

    def get_review_task!(28, _opts) do
      %{Process.get(:mock_review_task) | id: 28, article_suggestion_id: 16}
    end

    def mark_review_task_material_edit(review_task_id, attrs, _opts \\ []) do
      send(self(), {:material_edit, review_task_id, attrs})
      {:ok, Process.get(:mock_review_task)}
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    Application.put_env(:cairnloop, :knowledge_automation, MockKnowledgeAutomation)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      Application.delete_env(:cairnloop, :knowledge_automation)
      Process.delete(:mock_repo_one_lookup)
      Process.delete(:mock_review_task)
    end)

    :ok
  end

  test "Editor renders preview side-by-side using Earmark when Markdown is input" do
    Process.put(:mock_repo_one_result, %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "# Hello"})
    
    {:ok, socket} = Cairnloop.Web.KnowledgeBaseLive.Editor.mount(%{"id" => "42"}, %{}, %Phoenix.LiveView.Socket{})

    assigns = socket.assigns
    html = render_html(assigns)

    assert html =~ "<h1>\nHello</h1>"

    # Test phx-change updates the preview
    {:noreply, socket} = Cairnloop.Web.KnowledgeBaseLive.Editor.handle_event("change", %{"content" => "**Bold** text"}, socket)
    
    html = render_html(socket.assigns)
    assert html =~ "<strong>Bold</strong> text"
  end

  test "Editor handles debounced phx-change events properly to avoid excessive parsing" do
    {:ok, socket} = Cairnloop.Web.KnowledgeBaseLive.Editor.mount(%{"id" => "42"}, %{}, %Phoenix.LiveView.Socket{})
    
    assigns = socket.assigns
    html = render_html(assigns)
    
    assert html =~ "phx-debounce=\"300\""
  end

  test "Editor preloads reviewed suggestion markdown only for a signed handoff" do
    Process.put(:mock_repo_one_result, %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "# Hello"})
    handoff = EditorHandoff.sign(15, 42, nil, nil)

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "suggestion_id" => "15", "handoff" => handoff},
        %{},
        %Phoenix.LiveView.Socket{}
      )

    assert socket.assigns.content == "# Suggested copy\n\nPrepared from review."

    html = render_html(socket.assigns)
    assert html =~ "Suggested copy"
  end

  test "review-origin editor shows review context, return path, and suppresses direct publish" do
    Process.put(:mock_repo_one_result, %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "# Hello"})

    Process.put(:mock_review_task, %{
      id: 27,
      status: :approved_ready_to_publish,
      article_suggestion: %ArticleSuggestion{
        id: 15,
        proposed_markdown: "# Suggested copy\n\nPrepared from review.",
        operator_summary: "Tighten the billing export steps.",
        evidence_snapshot: [%{}, %{}, %{}]
      }
    })

    handoff = EditorHandoff.sign(15, 42, 27, "/knowledge-base/suggestions?task=27")

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{
          "id" => "42",
          "suggestion_id" => "15",
          "review_task_id" => "27",
          "return_to" => "/knowledge-base/suggestions?task=27",
          "handoff" => handoff
        },
        %{},
        %Phoenix.LiveView.Socket{}
      )

    html = render_html(socket.assigns)

    assert html =~ "Return to review task"
    assert html =~ "Tighten the billing export steps."
    assert html =~ "3 evidence sources"
    refute html =~ ">Publish<"
  end

  test "editor rejects bare suggestion ids without a signed handoff" do
    Process.put(:mock_repo_one_result, %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "# Hello"})

    assert_raise Ecto.NoResultsError, fn ->
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "suggestion_id" => "15"},
        %{},
        %Phoenix.LiveView.Socket{}
      )
    end
  end

  test "editor rejects suggestion ids that do not belong to the route article" do
    Process.put(:mock_repo_one_result, %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "# Hello"})
    handoff = EditorHandoff.sign(16, 42, nil, nil)

    assert_raise Ecto.NoResultsError, fn ->
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "suggestion_id" => "16", "handoff" => handoff},
        %{},
        %Phoenix.LiveView.Socket{}
      )
    end
  end

  test "editor rejects review tasks that do not belong to the selected suggestion" do
    Process.put(:mock_repo_one_result, %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "# Hello"})
    Process.put(:mock_review_task, %{
      id: 27,
      article_suggestion_id: 15,
      article_suggestion: %ArticleSuggestion{id: 15, evidence_snapshot: []},
      status: :pending_review
    })
    handoff = EditorHandoff.sign(15, 42, 28, nil)

    assert_raise Ecto.NoResultsError, fn ->
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "suggestion_id" => "15", "review_task_id" => "28", "handoff" => handoff},
        %{},
        %Phoenix.LiveView.Socket{}
      )
    end
  end

  test "editor rejects bare review_task ids that target a different article" do
    Process.put(:mock_repo_one_result, %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "# Hello"})
    Process.put(:mock_review_task, %{
      id: 27,
      article_suggestion_id: 16,
      article_suggestion: %ArticleSuggestion{id: 16, article_id: 999, evidence_snapshot: []},
      status: :pending_review
    })

    assert_raise Ecto.NoResultsError, fn ->
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "review_task_id" => "27"},
        %{},
        %Phoenix.LiveView.Socket{}
      )
    end
  end

  test "editor forwards scope filters to suggestion and review-task lookups" do
    Process.put(:mock_repo_one_result, %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "# Hello"})
    Process.put(:mock_review_task, %{
      id: 27,
      article_suggestion_id: 15,
      article_suggestion: %ArticleSuggestion{id: 15, evidence_snapshot: []},
      status: :pending_review
    })
    handoff = EditorHandoff.sign(15, 42, 27, nil)

    original = Application.get_env(:cairnloop, :knowledge_automation)

    defmodule ScopedKnowledgeAutomation do
      def get_article_suggestion!(id, opts) do
        send(self(), {:scoped_suggestion_lookup, id, opts})
        Cairnloop.Web.KnowledgeBaseLiveTest.MockKnowledgeAutomation.get_article_suggestion!(id, opts)
      end

      def get_review_task!(id, opts) do
        send(self(), {:scoped_review_task_lookup, id, opts})
        Cairnloop.Web.KnowledgeBaseLiveTest.MockKnowledgeAutomation.get_review_task!(id, opts)
      end

      def mark_review_task_material_edit(review_task_id, attrs, opts \\ []) do
        Cairnloop.Web.KnowledgeBaseLiveTest.MockKnowledgeAutomation.mark_review_task_material_edit(review_task_id, attrs, opts)
      end
    end

    Application.put_env(:cairnloop, :knowledge_automation, ScopedKnowledgeAutomation)

    try do
      {:ok, _socket} =
        Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
          %{"id" => "42", "suggestion_id" => "15", "review_task_id" => "27", "handoff" => handoff},
          %{"host_user_id" => "user-1"},
          %Phoenix.LiveView.Socket{}
        )

      assert_received {:scoped_suggestion_lookup, 15, [tenant_scope: :host_user_scoped, host_user_id: "user-1"]}
      assert_received {:scoped_review_task_lookup, 27, [tenant_scope: :host_user_scoped, host_user_id: "user-1"]}
    after
      Application.put_env(:cairnloop, :knowledge_automation, original)
    end
  end

  test "article suggestions can reopen the editor through authoring_article_id metadata" do
    Process.put(:mock_repo_one_result, %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "# Hello"})
    handoff = EditorHandoff.sign(17, 42, nil, nil)

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "suggestion_id" => "17", "handoff" => handoff},
        %{},
        %Phoenix.LiveView.Socket{}
      )

    assert socket.assigns.content == "# New KB draft\n\nPrepared from review."
  end

  test "review-origin save marks approved tasks back to review_needed after material edits" do
    latest_revision = %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "# Hello"}
    staged_revision = %Revision{id: 9, article_id: 42, version: 2, state: :draft, content: "# Suggested copy\n\nPrepared from review."}

    Process.put(:mock_repo_one_lookup, fn query ->
      cond do
        query.from.source == {"cairnloop_knowledge_base_revisions", Revision} and
            Enum.any?(query.wheres, &Macro.to_string(&1.expr) =~ "article_id") ->
          latest_revision

        query.from.source == {"cairnloop_knowledge_base_revisions", Revision} ->
          staged_revision

        true ->
          latest_revision
      end
    end)

    Process.put(:mock_review_task, %{
      id: 27,
      status: :approved_ready_to_publish,
      staged_revision_id: 9,
      article_suggestion: %ArticleSuggestion{
        id: 15,
        proposed_markdown: "# Suggested copy\n\nPrepared from review.",
        operator_summary: "Tighten the billing export steps.",
        evidence_snapshot: [%{}]
      }
    })
    handoff = EditorHandoff.sign(15, 42, 27, nil)

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{
          "id" => "42",
          "suggestion_id" => "15",
          "review_task_id" => "27",
          "handoff" => handoff
        },
        %{},
        %Phoenix.LiveView.Socket{}
      )

    edited_socket =
      %{
        socket
        | assigns:
            socket.assigns
            |> Map.put(:content, "# Suggested copy\n\nPrepared from review.\n\nExtra operator edits.")
            |> Map.put(:flash, %{})
      }

    assert {:noreply, saved_socket} =
             Cairnloop.Web.KnowledgeBaseLive.Editor.handle_event("save_draft", %{}, edited_socket)

    assert saved_socket.assigns.revision.content =~ "Extra operator edits."
    assert_received {:material_edit, 27, attrs}
    assert Keyword.get(attrs, :saved_revision_id) == 1
    assert Keyword.get(attrs, :content) =~ "Extra operator edits."
  end

  test "non-review editor sessions keep direct publish available" do
    Process.put(:mock_repo_one_result, %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "# Hello"})

    {:ok, socket} = Cairnloop.Web.KnowledgeBaseLive.Editor.mount(%{"id" => "42"}, %{}, %Phoenix.LiveView.Socket{})

    html = render_html(socket.assigns)
    assert html =~ ">Publish<"
  end

  defp render_html(assigns) do
    assigns
    |> Cairnloop.Web.KnowledgeBaseLive.Editor.render()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
