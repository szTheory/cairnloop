defmodule Cairnloop.KnowledgeBase do
  import Ecto.Query
  alias Cairnloop.KnowledgeBase.{Article, Revision}

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  defp support_prefix, do: Cairnloop.SchemaPrefix.configured()
  defp repo_opts, do: Cairnloop.SchemaPrefix.repo_opts()

  defp prefixed(queryable),
    do: queryable |> Ecto.Queryable.to_query() |> put_query_prefix(support_prefix())

  def get_latest_active_revision(article_id) do
    Revision
    |> prefixed()
    |> where([r], r.article_id == ^article_id and r.state == :published)
    |> order_by([r], desc: r.version)
    |> limit(1)
    |> repo().one()
  end

  def get_revision(id) do
    Revision
    |> prefixed()
    |> where([r], r.id == ^id)
    |> limit(1)
    |> repo().one()
  end

  def get_article(id) do
    Article
    |> prefixed()
    |> where([article], article.id == ^id)
    |> limit(1)
    |> repo().one()
  end

  def get_article!(id) do
    Article
    |> prefixed()
    |> where([article], article.id == ^id)
    |> limit(1)
    |> repo().one!()
  end

  def get_latest_revision(article_id) do
    Revision
    |> prefixed()
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
        |> Ecto.Multi.update(:revision, Revision.changeset(latest, attrs), repo_opts())
      else
        # Create new draft version N+1
        version = if latest, do: latest.version + 1, else: 1
        new_attrs = Map.merge(attrs, %{article_id: article.id, version: version, state: :draft})

        Ecto.Multi.new()
        |> Ecto.Multi.insert(:revision, Revision.changeset(%Revision{}, new_attrs), repo_opts())
      end

    multi
    |> repo().transaction()
    |> case do
      {:ok, %{revision: revision}} -> {:ok, revision}
      {:error, :revision, changeset, _changes} -> {:error, changeset}
    end
  end

  def create_article(attrs) do
    %Article{}
    |> Article.changeset(attrs)
    |> repo().insert(repo_opts())
  end

  def list_articles(opts \\ []) do
    Article
    |> prefixed()
    |> maybe_filter_article_status(opts)
    |> order_by([a], desc: a.inserted_at, desc: a.id)
    |> repo().all()
  end

  defp maybe_filter_article_status(query, opts) do
    case Keyword.get(opts, :status, :all) do
      :all -> query
      nil -> query
      status -> where(query, [a], a.status == ^status)
    end
  end

  def publish_revision(revision) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(
      :revision,
      Revision.changeset(revision, %{state: :published}),
      repo_opts()
    )
    |> Ecto.Multi.run(:article, fn repo, %{revision: rev} ->
      article = repo.get!(Article, rev.article_id, repo_opts())

      article
      |> Article.changeset(%{status: :published})
      |> repo.update(repo_opts())
    end)
    |> Ecto.Multi.insert(
      :chunk_job,
      Cairnloop.KnowledgeBase.Workers.ChunkRevision.new(%{revision_id: revision.id})
    )
    |> repo().transaction()
    |> case do
      {:ok, %{revision: published_revision}} -> {:ok, published_revision}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end

  def search_chunks(embedding_vector, limit \\ 5) do
    Cairnloop.KnowledgeBase.Chunk
    |> prefixed()
    |> order_by([c], fragment("? <-> ?", c.embedding, ^Pgvector.new(embedding_vector)))
    |> limit(^limit)
    |> repo().all()
  end
end
