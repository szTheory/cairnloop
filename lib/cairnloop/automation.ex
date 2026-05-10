defmodule Cairnloop.Automation do
  alias Cairnloop.{Automation.Draft, Message}

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def create_draft(conversation_id, attrs) do
    attrs =
      attrs
      |> Enum.into(%{})
      |> Map.put(:conversation_id, conversation_id)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :draft,
      Draft.changeset(%Draft{}, attrs)
    )
    |> repo().transaction()
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

  def approve_draft(draft_id) do
    draft = repo().get!(Draft, draft_id)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :message,
      Message.changeset(%Message{}, %{
        conversation_id: draft.conversation_id,
        content: draft.content,
        role: :agent
      })
    )
    |> Ecto.Multi.update(:draft, Ecto.Changeset.change(draft, %{status: :approved}))
    |> repo().transaction()
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

  def discard_draft(draft_id) do
    draft = repo().get!(Draft, draft_id)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:draft, Ecto.Changeset.change(draft, %{status: :discarded}))
    |> repo().transaction()
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

  def mark_draft_edited(draft_id) do
    draft = repo().get!(Draft, draft_id)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:draft, Ecto.Changeset.change(draft, %{status: :edited}))
    |> repo().transaction()
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
