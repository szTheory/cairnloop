defmodule Cairnloop.Automation do
  import Ecto.Query

  alias Cairnloop.{Automation.Draft, Message}

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  defp repo_opts, do: Cairnloop.SchemaPrefix.repo_opts()

  defp prefixed(queryable) do
    query = Ecto.Queryable.to_query(queryable)
    put_query_prefix(query, Cairnloop.SchemaPrefix.configured())
  end

  def create_draft(conversation_id, attrs) do
    attrs =
      attrs
      |> Enum.into(%{})
      |> Map.put(:conversation_id, conversation_id)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :draft,
      Draft.changeset(%Draft{}, attrs),
      repo_opts()
    )
    |> repo().transaction(repo_opts())
    |> case do
      {:ok, %{draft: draft}} ->
        :telemetry.execute(
          [:cairnloop, :automation, :draft, :created],
          %{count: 1},
          %{draft_id: draft.id}
        )

        {:ok, draft}

      {:error, :draft, changeset, _changes} ->
        {:error, changeset}
    end
  end

  def latest_draft_for_conversation(conversation_id) do
    Draft
    |> prefixed()
    |> where([draft], draft.conversation_id == ^conversation_id)
    |> order_by([draft], desc: draft.inserted_at, desc: draft.id)
    |> limit(1)
    |> repo().one(repo_opts())
  end

  def approve_draft(draft_id, opts \\ []) do
    draft = repo().get!(Draft, draft_id, repo_opts())
    actor = Keyword.get(opts, :actor)

    auditor =
      Keyword.get(
        opts,
        :auditor,
        Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp)
      )

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :message,
      Message.changeset(%Message{}, %{
        conversation_id: draft.conversation_id,
        content: Draft.reply_content(draft),
        role: :agent
      }),
      repo_opts()
    )
    |> Ecto.Multi.update(:draft, Ecto.Changeset.change(draft, %{status: :approved}), repo_opts())
    |> auditor.audit(:approve_draft, actor, %{draft_id: draft_id})
    |> repo().transaction(repo_opts())
    |> case do
      {:ok, _result} = success ->
        :telemetry.execute(
          [:cairnloop, :automation, :draft, :approved],
          %{count: 1},
          %{draft_id: draft.id}
        )

        success

      error ->
        error
    end
  end

  def discard_draft(draft_id, opts \\ []) do
    draft = repo().get!(Draft, draft_id, repo_opts())
    actor = Keyword.get(opts, :actor)

    auditor =
      Keyword.get(
        opts,
        :auditor,
        Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp)
      )

    Ecto.Multi.new()
    |> Ecto.Multi.update(:draft, Ecto.Changeset.change(draft, %{status: :discarded}), repo_opts())
    |> auditor.audit(:discard_draft, actor, %{draft_id: draft_id})
    |> repo().transaction(repo_opts())
    |> case do
      {:ok, _result} = success ->
        :telemetry.execute(
          [:cairnloop, :automation, :draft, :discarded],
          %{count: 1},
          %{draft_id: draft.id}
        )

        success

      error ->
        error
    end
  end

  def mark_draft_edited(draft_id, opts \\ []) do
    draft = repo().get!(Draft, draft_id, repo_opts())
    actor = Keyword.get(opts, :actor)

    auditor =
      Keyword.get(
        opts,
        :auditor,
        Application.get_env(:cairnloop, :auditor, Cairnloop.Auditor.NoOp)
      )

    Ecto.Multi.new()
    |> Ecto.Multi.update(:draft, Ecto.Changeset.change(draft, %{status: :edited}), repo_opts())
    |> auditor.audit(:mark_draft_edited, actor, %{draft_id: draft_id})
    |> repo().transaction(repo_opts())
    |> case do
      {:ok, _result} = success ->
        :telemetry.execute(
          [:cairnloop, :automation, :draft, :edited],
          %{count: 1},
          %{draft_id: draft.id}
        )

        success

      error ->
        error
    end
  end
end
