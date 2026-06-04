defmodule Cairnloop.Web.KnowledgeBaseLiveTest do
  use ExUnit.Case, async: false
  alias Cairnloop.KnowledgeAutomation.ArticleSuggestion
  alias Cairnloop.KnowledgeAutomation.GapCandidate
  alias Cairnloop.KnowledgeBase.{Article, Revision}
  alias Cairnloop.Web.KnowledgeBaseLive.EditorHandoff

  defmodule MockRepo do
    def all(Article) do
      [%Article{id: 42, title: "Test Article", status: :draft}]
    end

    def all(%Ecto.Query{}) do
      case Process.get(:mock_repo_all_result) do
        nil -> [%Article{id: 42, title: "Test Article", status: :draft}]
        result -> result
      end
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

    def one!(%Ecto.Query{from: %{source: {_table, Article}}} = _query) do
      case Process.get(:mock_article_result) do
        nil -> %Article{id: 42, title: "Test Article", status: :draft}
        result -> result
      end
    end

    def one!(%Ecto.Query{} = query) do
      case one(query) do
        nil -> raise Ecto.NoResultsError, queryable: query
        result -> result
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

    def get_article_suggestion!(18, _opts) do
      %ArticleSuggestion{
        id: 18,
        proposed_markdown: "# Gap-originated copy\n\nPrepared from gap candidate.",
        title: "Gap Article",
        entrypoint_type: :gap_candidate,
        entrypoint_id: 7
      }
    end

    def get_article_suggestion!(19, _opts) do
      %ArticleSuggestion{
        id: 19,
        proposed_markdown: "# Revision copy\n\nPrepared from revision.",
        title: "Revision Article",
        entrypoint_type: :article_revision,
        entrypoint_id: 5
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

    def get_gap_candidate(id, _opts \\ [])

    def get_gap_candidate(7, _opts) do
      %GapCandidate{
        id: 7,
        title: "Billing export gap",
        seed_excerpt: "Customers cannot export billing data",
        candidate_type: :manual_handling,
        evidence_count: 2,
        last_seen_at: DateTime.utc_now()
      }
    end

    def get_gap_candidate(_id, _opts), do: nil
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)
    Application.put_env(:cairnloop, :knowledge_automation, MockKnowledgeAutomation)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
      Application.delete_env(:cairnloop, :knowledge_automation)
      Process.delete(:mock_repo_one_lookup)
      Process.delete(:mock_repo_all_result)
      Process.delete(:mock_review_task)
    end)

    :ok
  end

  # Build a socket with flash initialized (required for put_flash/3 in mount rescue
  # and handle_event error paths, which read assigns.flash to update it).
  defp socket_with_flash do
    %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}}}
  end

  test "Editor renders preview side-by-side using Earmark when Markdown is input" do
    Process.put(:mock_repo_one_result, %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42"},
        %{},
        %Phoenix.LiveView.Socket{}
      )

    assigns = socket.assigns
    html = render_html(assigns)

    assert html =~ "<h1>\nHello</h1>"

    # Test phx-change updates the preview
    {:noreply, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.handle_event(
        "change",
        %{"content" => "**Bold** text"},
        socket
      )

    html = render_html(socket.assigns)
    assert html =~ "<strong>Bold</strong> text"
  end

  test "Editor handles debounced phx-change events properly to avoid excessive parsing" do
    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42"},
        %{},
        %Phoenix.LiveView.Socket{}
      )

    assigns = socket.assigns
    html = render_html(assigns)

    assert html =~ "phx-debounce=\"300\""
  end

  test "Editor preloads reviewed suggestion markdown only for a signed handoff" do
    Process.put(:mock_repo_one_result, %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    handoff =
      EditorHandoff.sign(15, 42, nil, nil,
        manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
      )

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
    Process.put(:mock_repo_one_result, %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

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

    handoff =
      EditorHandoff.sign(15, 42, 27, "/knowledge-base/suggestions?task=27",
        manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
      )

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
    # The Publish button is suppressed in the review lane. Match it by its unique
    # phx-click (whitespace-independent now that it renders via the cl_button component).
    refute html =~ ~s(phx-click="publish")
  end

  test "editor rejects bare suggestion ids without a signed handoff — returns calm flash + redirect" do
    Process.put(:mock_repo_one_result, %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "suggestion_id" => "15"},
        %{},
        socket_with_flash()
      )

    assert socket.assigns.flash["error"] ==
             "This editor can only be opened from the review queue. Return to Suggestions and use 'Open for manual edit' to begin editing."
  end

  test "editor rejects suggestion ids that do not belong to the route article — returns calm flash + redirect" do
    Process.put(:mock_repo_one_result, %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    handoff =
      EditorHandoff.sign(16, 42, nil, nil,
        manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
      )

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "suggestion_id" => "16", "handoff" => handoff},
        %{},
        socket_with_flash()
      )

    assert socket.assigns.flash["error"] ==
             "This editor can only be opened from the review queue. Return to Suggestions and use 'Open for manual edit' to begin editing."
  end

  test "editor rejects review tasks that do not belong to the selected suggestion — returns calm flash + redirect" do
    Process.put(:mock_repo_one_result, %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    Process.put(:mock_review_task, %{
      id: 27,
      article_suggestion_id: 15,
      article_suggestion: %ArticleSuggestion{id: 15, evidence_snapshot: []},
      status: :pending_review
    })

    handoff =
      EditorHandoff.sign(15, 42, 28, nil,
        manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
      )

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "suggestion_id" => "15", "review_task_id" => "28", "handoff" => handoff},
        %{},
        socket_with_flash()
      )

    assert socket.assigns.flash["error"] ==
             "This editor can only be opened from the review queue. Return to Suggestions and use 'Open for manual edit' to begin editing."
  end

  test "editor rejects bare review_task ids that target a different article — returns calm flash + redirect" do
    Process.put(:mock_repo_one_result, %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    Process.put(:mock_review_task, %{
      id: 27,
      article_suggestion_id: 16,
      article_suggestion: %ArticleSuggestion{id: 16, article_id: 999, evidence_snapshot: []},
      status: :pending_review
    })

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "review_task_id" => "27"},
        %{},
        socket_with_flash()
      )

    assert socket.assigns.flash["error"] ==
             "This editor can only be opened from the review queue. Return to Suggestions and use 'Open for manual edit' to begin editing."
  end

  test "editor forwards scope filters to suggestion and review-task lookups" do
    Process.put(:mock_repo_one_result, %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    Process.put(:mock_review_task, %{
      id: 27,
      article_suggestion_id: 15,
      article_suggestion: %ArticleSuggestion{id: 15, evidence_snapshot: []},
      status: :pending_review
    })

    handoff =
      EditorHandoff.sign(15, 42, 27, nil,
        manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
      )

    original = Application.get_env(:cairnloop, :knowledge_automation)

    defmodule ScopedKnowledgeAutomation do
      def get_article_suggestion!(id, opts) do
        send(self(), {:scoped_suggestion_lookup, id, opts})

        Cairnloop.Web.KnowledgeBaseLiveTest.MockKnowledgeAutomation.get_article_suggestion!(
          id,
          opts
        )
      end

      def get_review_task!(id, opts) do
        send(self(), {:scoped_review_task_lookup, id, opts})
        Cairnloop.Web.KnowledgeBaseLiveTest.MockKnowledgeAutomation.get_review_task!(id, opts)
      end

      def mark_review_task_material_edit(review_task_id, attrs, opts \\ []) do
        Cairnloop.Web.KnowledgeBaseLiveTest.MockKnowledgeAutomation.mark_review_task_material_edit(
          review_task_id,
          attrs,
          opts
        )
      end

      def get_gap_candidate(id, opts) do
        Cairnloop.Web.KnowledgeBaseLiveTest.MockKnowledgeAutomation.get_gap_candidate(id, opts)
      end
    end

    Application.put_env(:cairnloop, :knowledge_automation, ScopedKnowledgeAutomation)

    try do
      {:ok, _socket} =
        Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
          %{
            "id" => "42",
            "suggestion_id" => "15",
            "review_task_id" => "27",
            "handoff" => handoff
          },
          %{"host_user_id" => "user-1"},
          %Phoenix.LiveView.Socket{}
        )

      assert_received {:scoped_suggestion_lookup, 15,
                       [tenant_scope: :host_user_scoped, host_user_id: "user-1"]}

      assert_received {:scoped_review_task_lookup, 27,
                       [tenant_scope: :host_user_scoped, host_user_id: "user-1"]}
    after
      Application.put_env(:cairnloop, :knowledge_automation, original)
    end
  end

  test "article suggestions can reopen the editor through authoring_article_id metadata" do
    Process.put(:mock_repo_one_result, %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    handoff =
      EditorHandoff.sign(17, 42, nil, nil,
        manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
      )

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "suggestion_id" => "17", "handoff" => handoff},
        %{},
        %Phoenix.LiveView.Socket{}
      )

    assert socket.assigns.content == "# New KB draft\n\nPrepared from review."
  end

  test "review-origin save marks approved tasks back to review_needed after material edits" do
    latest_revision = %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    }

    staged_revision = %Revision{
      id: 9,
      article_id: 42,
      version: 2,
      state: :draft,
      content: "# Suggested copy\n\nPrepared from review."
    }

    Process.put(:mock_repo_one_lookup, fn query ->
      cond do
        query.from.source == {"cairnloop_knowledge_base_revisions", Revision} and
            Enum.any?(query.wheres, &(Macro.to_string(&1.expr) =~ "article_id")) ->
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

    handoff =
      EditorHandoff.sign(15, 42, 27, nil,
        manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
      )

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
            |> Map.put(
              :content,
              "# Suggested copy\n\nPrepared from review.\n\nExtra operator edits."
            )
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
    Process.put(:mock_repo_one_result, %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42"},
        %{},
        %Phoenix.LiveView.Socket{}
      )

    html = render_html(socket.assigns)
    # Publish button present outside the review lane — matched by its unique phx-click.
    assert html =~ ~s(phx-click="publish")
  end

  test "Editor renders Source gap sidebar when suggestion has entrypoint_type :gap_candidate" do
    Process.put(:mock_repo_one_result, %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    handoff =
      EditorHandoff.sign(18, 42, nil, nil,
        manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
      )

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "suggestion_id" => "18", "handoff" => handoff},
        %{},
        %Phoenix.LiveView.Socket{}
      )

    html = render_html(socket.assigns)

    assert html =~ "Source gap"
    assert html =~ "Billing export gap"
    assert html =~ "2 evidence"
    assert html =~ "Seen today"
  end

  test "Editor does not render Source gap sidebar for non-gap suggestions" do
    Process.put(:mock_repo_one_result, %Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    handoff =
      EditorHandoff.sign(19, 42, nil, nil,
        manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
      )

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42", "suggestion_id" => "19", "handoff" => handoff},
        %{},
        %Phoenix.LiveView.Socket{}
      )

    html = render_html(socket.assigns)

    refute html =~ "Source gap"
  end

  test "KB Editor renders inside cl-page--wide with title, subnav, and breadcrumb in slot" do
    Process.put(:mock_repo_one_result, %Cairnloop.KnowledgeBase.Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42"},
        %{},
        %Phoenix.LiveView.Socket{}
      )

    html = render_html(socket.assigns)

    assert html =~ ~s(cl-page cl-page--wide)
    assert html =~ ~s(cl-page__title)
    assert html =~ "Editing: "
    assert html =~ ~s(cl-page__subnav)
    assert html =~ ~s(cl-breadcrumb)
    assert html =~ ~s(aria-current="page")
  end

  test "KB Editor breadcrumb contains static Knowledge crumb and current Editing crumb" do
    Process.put(:mock_repo_one_result, %Cairnloop.KnowledgeBase.Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42"},
        %{},
        %Phoenix.LiveView.Socket{}
      )

    html = render_html(socket.assigns)

    assert html =~ "Knowledge"
    assert html =~ "/knowledge-base"
    assert html =~ ~s(aria-current="page")
    assert html =~ "Editing: "
  end

  test "KB Index renders inside cl-page--wide with title, subnav, and actions" do
    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Index.mount(
        %{},
        %{},
        %Phoenix.LiveView.Socket{}
      )

    html =
      socket.assigns
      |> Cairnloop.Web.KnowledgeBaseLive.Index.render()
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    assert html =~ ~s(cl-page cl-page--wide)
    assert html =~ ~s(cl-page__title)
    assert html =~ "Knowledge Base"
    assert html =~ ~s(cl-page__subnav)
    assert html =~ "New article"
  end

  test "Index new_article event creates an article and push_navigates to its editor" do
    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Index.mount(
        %{},
        %{},
        socket_with_flash()
      )

    {:noreply, result_socket} =
      Cairnloop.Web.KnowledgeBaseLive.Index.handle_event("new_article", %{}, socket)

    # MockRepo.insert returns {:ok, apply_changes(changeset)} — article gets id: nil
    # push_navigate sets socket.redirected to {:live, :redirect, %{to: path}}
    assert match?({:live, :redirect, %{to: path}} when is_binary(path), result_socket.redirected)
    {:live, :redirect, %{to: path}} = result_socket.redirected
    assert path =~ "/knowledge-base/"
    assert path =~ "/edit"
  end

  test "Index new_article event flashes calm error when create_article fails" do
    defmodule FailingRepo do
      def all(_), do: []

      def insert(_changeset, _opts \\ []) do
        {:error,
         Ecto.Changeset.add_error(
           Ecto.Changeset.change(%Cairnloop.KnowledgeBase.Article{}),
           :title,
           "some error"
         )}
      end
    end

    Application.put_env(:cairnloop, :repo, FailingRepo)

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Index.mount(
        %{},
        %{},
        socket_with_flash()
      )

    {:noreply, result_socket} =
      Cairnloop.Web.KnowledgeBaseLive.Index.handle_event("new_article", %{}, socket)

    assert result_socket.assigns.flash["error"] ==
             "Unable to create the article right now. Try again."

    Application.put_env(:cairnloop, :repo, MockRepo)
  end

  # --- Task 38-04: origin-aware breadcrumb via BreadcrumbPresenter ---

  test "editor breadcrumb from a conversation: ≥2 crumbs, back link, humanized label, aria-current" do
    # return_to = "/42" → origin label "Conversation", not the raw path as label
    Process.put(:mock_repo_one_result, %Cairnloop.KnowledgeBase.Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    Process.put(:mock_review_task, %{
      id: 27,
      article_suggestion_id: 15,
      status: :pending_review,
      article_suggestion: %Cairnloop.KnowledgeAutomation.ArticleSuggestion{
        id: 15,
        article_id: 42,
        proposed_markdown: "# Suggested copy\n\nPrepared from review.",
        operator_summary: "Improve billing export steps.",
        evidence_snapshot: []
      }
    })

    handoff =
      EditorHandoff.sign(15, 42, 27, "/42",
        manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
      )

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{
          "id" => "42",
          "suggestion_id" => "15",
          "review_task_id" => "27",
          "return_to" => "/42",
          "handoff" => handoff
        },
        %{},
        socket_with_flash()
      )

    html = render_html(socket.assigns)

    # Must have breadcrumb container
    assert html =~ ~s(cl-breadcrumb)
    # Must have a back link to the conversation
    assert html =~ ~s(navigate="/42") or html =~ ~s(href="/42")
    # Must have a separator (≥2 crumbs ⇒ ≥1 separator)
    assert html =~ ~s(cl-breadcrumb__sep)
    # Must have aria-current on the last crumb
    assert html =~ ~s(aria-current="page")
    # Origin label must be "Conversation" (humanized), not the raw "/42" as crumb text
    assert html =~ "Conversation"
    # The raw path "/42" must NOT appear as a crumb label (it may appear only in href)
    refute html =~ ">/42<"
  end

  test "editor breadcrumb from the suggestion lane: origin label is Suggestions with back link" do
    Process.put(:mock_repo_one_result, %Cairnloop.KnowledgeBase.Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    Process.put(:mock_review_task, %{
      id: 27,
      article_suggestion_id: 15,
      status: :pending_review,
      article_suggestion: %Cairnloop.KnowledgeAutomation.ArticleSuggestion{
        id: 15,
        article_id: 42,
        proposed_markdown: "# Suggested copy\n\nPrepared from review.",
        operator_summary: "Lane origin draft.",
        evidence_snapshot: []
      }
    })

    handoff =
      EditorHandoff.sign(15, 42, 27, "/knowledge-base/suggestions?task=27",
        manual_edit_opened_at: DateTime.utc_now() |> DateTime.to_iso8601()
      )

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
        socket_with_flash()
      )

    html = render_html(socket.assigns)

    assert html =~ ~s(cl-breadcrumb)
    # Origin label is "Suggestions" (humanized from the path shape)
    assert html =~ "Suggestions"
    # Back link to the suggestion lane
    assert html =~ ~s(navigate="/knowledge-base/suggestions?task=27") or
             html =~ ~s(href="/knowledge-base/suggestions?task=27")
    assert html =~ ~s(aria-current="page")
  end

  test "editor breadcrumb with no return_to: static fallback Knowledge + current Editing crumb" do
    Process.put(:mock_repo_one_result, %Cairnloop.KnowledgeBase.Revision{
      id: 1,
      article_id: 42,
      version: 1,
      state: :draft,
      content: "# Hello"
    })

    {:ok, socket} =
      Cairnloop.Web.KnowledgeBaseLive.Editor.mount(
        %{"id" => "42"},
        %{},
        %Phoenix.LiveView.Socket{}
      )

    html = render_html(socket.assigns)

    assert html =~ ~s(cl-breadcrumb)
    # Static Knowledge back link
    assert html =~ ~s(navigate="/knowledge-base") or html =~ ~s(href="/knowledge-base")
    assert html =~ "Knowledge"
    # Current Editing crumb
    assert html =~ "Editing:"
    assert html =~ ~s(aria-current="page")
  end

  defp render_html(assigns) do
    assigns
    |> Cairnloop.Web.KnowledgeBaseLive.Editor.render()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
