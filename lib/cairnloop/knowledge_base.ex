defmodule Cairnloop.KnowledgeBase do
  import Ecto.Query
  alias Cairnloop.KnowledgeBase.{Article, Revision}

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def get_latest_active_revision(article_id) do
    Revision
    |> where([r], r.article_id == ^article_id and r.state == :published)
    |> order_by([r], desc: r.version)
    |> limit(1)
    |> repo().one()
  end

  def get_latest_revision(article_id) do
    Revision
    |> where([r], r.article_id == ^article_id)
    |> order_by([r], desc: r.version)
    |> limit(1)
    |> repo().one()
  end

  def save_draft(article, content_attrs) do
    latest = get_latest_revision(article.id)
    attrs = Enum.into(content_attrs, %{})

    multi =
      if latest && latest.state == :draft do
        # Update existing draft
        Ecto.Multi.new()
        |> Ecto.Multi.update(:revision, Revision.changeset(latest, attrs))
      else
        # Create new draft version N+1
        version = if latest, do: latest.version + 1, else: 1
        new_attrs = Map.merge(attrs, %{article_id: article.id, version: version, state: :draft})

        Ecto.Multi.new()
        |> Ecto.Multi.insert(:revision, Revision.changeset(%Revision{}, new_attrs))
      end

    multi
    |> repo().transaction()
    |> case do
      {:ok, %{revision: revision}} -> {:ok, revision}
      {:error, :revision, changeset, _changes} -> {:error, changeset}
    end
  end

  def publish_revision(revision) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:revision, Revision.changeset(revision, %{state: :published}))
    |> Ecto.Multi.update(:article, fn %{revision: rev} ->
      Article.changeset(repo().get!(Article, rev.article_id), %{status: :published})
    end)
    |> repo().transaction()
    |> case do
      {:ok, %{revision: published_revision}} -> {:ok, published_revision}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end
end
