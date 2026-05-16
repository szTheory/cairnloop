defmodule Cairnloop.Web.KnowledgeBaseLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest
  alias Cairnloop.KnowledgeBase.{Article, Revision}

  @endpoint Cairnloop.Web.Endpoint

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

    def one(%Ecto.Query{}) do
      Process.get(:mock_repo_one_result)
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

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
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

  defp render_html(assigns) do
    assigns
    |> Cairnloop.Web.KnowledgeBaseLive.Editor.render()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end