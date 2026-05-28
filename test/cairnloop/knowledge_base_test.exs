defmodule Cairnloop.KnowledgeBaseTest do
  use ExUnit.Case, async: false
  alias Cairnloop.KnowledgeBase
  alias Cairnloop.KnowledgeBase.{Article, Revision}

  defmodule MockRepo do
    def all(%Ecto.Query{} = q) do
      send(self(), {:list_query, q})
      Process.get(:mock_articles, [])
    end

    def one(%Ecto.Query{}) do
      Process.get(:mock_repo_one_result)
    end

    def get!(Article, id) do
      if id == 42 do
        %Article{id: 42, title: "Test Article", status: :draft}
      else
        raise Ecto.NoResultsError, queryable: Article
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
            inserted = Ecto.Changeset.apply_changes(changeset)
            send(self(), {:multi_insert, name, inserted})
            Map.put(acc, name, inserted)

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

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
    end)

    :ok
  end

  describe "get_latest_active_revision/1" do
    test "returns the latest published revision" do
      mock_rev = %Revision{id: 1, article_id: 42, version: 3, state: :published}
      Process.put(:mock_repo_one_result, mock_rev)

      assert ^mock_rev = KnowledgeBase.get_latest_active_revision(42)
    end
  end

  describe "save_draft/2" do
    test "creates a new revision with version N+1 if latest revision is published" do
      Process.put(:mock_repo_one_result, %Revision{
        id: 1,
        article_id: 42,
        version: 1,
        state: :published
      })

      assert {:ok, revision} =
               KnowledgeBase.save_draft(%Article{id: 42}, %{content: "new content"})

      assert revision.version == 2
      assert revision.state == :draft
      assert revision.content == "new content"
    end

    test "updates the existing draft if latest revision is a draft" do
      Process.put(:mock_repo_one_result, %Revision{
        id: 1,
        article_id: 42,
        version: 2,
        state: :draft,
        content: "old"
      })

      assert {:ok, revision} =
               KnowledgeBase.save_draft(%Article{id: 42}, %{content: "new content"})

      assert revision.id == 1
      assert revision.version == 2
      assert revision.state == :draft
      assert revision.content == "new content"
    end
  end

  describe "publish_revision/1" do
    test "sets state to :published and updates article status" do
      revision = %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "content"}

      assert {:ok, published_revision} = KnowledgeBase.publish_revision(revision)
      assert published_revision.state == :published
    end

    test "enqueues the chunk indexing job transactionally" do
      revision = %Revision{id: 1, article_id: 42, version: 1, state: :draft, content: "content"}

      assert {:ok, _published_revision} = KnowledgeBase.publish_revision(revision)
      assert_received {:multi_insert, :chunk_job, chunk_job}
      assert chunk_job.worker == "Cairnloop.KnowledgeBase.Workers.ChunkRevision"
      assert chunk_job.args == %{revision_id: 1}
    end
  end

  describe "list_articles/1" do
    test "returns the MockRepo-seeded article list" do
      articles = [
        %Article{id: 2, title: "Newer", status: :published},
        %Article{id: 1, title: "Older", status: :draft}
      ]

      Process.put(:mock_articles, articles)

      result = KnowledgeBase.list_articles([])
      assert result == articles
    end

    test "query has desc order_bys on inserted_at and id" do
      KnowledgeBase.list_articles([])
      assert_received {:list_query, q}

      order_bys = q.order_bys
      assert length(order_bys) == 1
      [order_by_expr] = order_bys
      # The expr is a list of {direction, field_ast} tuples
      fields = order_by_expr.expr
      directions = Enum.map(fields, fn {dir, _field} -> dir end)
      assert directions == [:desc, :desc]
    end

    test "list_articles(status: :draft) adds a where clause to the query" do
      KnowledgeBase.list_articles(status: :draft)
      assert_received {:list_query, q}
      assert q.wheres != []
    end

    test "list_articles(status: :all) does not add a where clause" do
      KnowledgeBase.list_articles(status: :all)
      assert_received {:list_query, q}
      assert q.wheres == []
    end

    test "list_articles([]) does not add a where clause" do
      KnowledgeBase.list_articles([])
      assert_received {:list_query, q}
      assert q.wheres == []
    end
  end
end
