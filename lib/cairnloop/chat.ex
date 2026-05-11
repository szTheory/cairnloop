defmodule Cairnloop.Chat do
  import Ecto.Query
  alias Cairnloop.{Conversation, Message}

  defp repo do
    Application.fetch_env!(:cairnloop, :repo)
  end

  def list_conversations do
    Conversation
    |> order_by(desc: :updated_at)
    |> repo().all()
  end

  def get_conversation!(id) do
    Conversation
    |> repo().get!(id)
    |> repo().preload(
      messages: from(m in Message, order_by: [asc: m.inserted_at]),
      drafts: from(d in Cairnloop.Automation.Draft, order_by: [asc: d.inserted_at])
    )
  end

  def reply_to_conversation(conversation_id, content, role \\ :agent) do
    conversation = repo().get!(Conversation, conversation_id)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :message,
        Message.changeset(%Message{}, %{
          conversation_id: conversation.id,
          content: content,
          role: role
        })
      )
      |> Ecto.Multi.update(:conversation, Ecto.Changeset.change(conversation, %{status: :open}))

    multi =
      if role == :user do
        Ecto.Multi.insert(
          multi,
          :draft_job,
          Cairnloop.Automation.Workers.DraftWorker.new(
            %{"conversation_id" => conversation.id},
            schedule_in: 5
          )
        )
      else
        multi
      end

    repo().transaction(multi)
  end

  def resolve_conversation(conversation_id, opts) when is_list(opts) do
    {actor, metadata} = Keyword.pop!(opts, :resolved_by)
    conversation = repo().get!(Conversation, conversation_id)
    resolved_at = DateTime.utc_now()
    
    # Safely handle missing inserted_at for old rows or test mock edge cases
    inserted_at = conversation.inserted_at || resolved_at
    duration_seconds = DateTime.diff(resolved_at, inserted_at, :second)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:conversation, Ecto.Changeset.change(conversation, %{status: :resolved, resolved_at: resolved_at}))
    |> repo().transaction()
    |> case do
      {:ok, %{conversation: updated_conversation}} ->
        notify_resolved(updated_conversation, opts)

        :telemetry.execute(
          [:cairnloop, :conversation, :resolved],
          %{count: 1, duration_seconds: duration_seconds},
          %{
            conversation_id: updated_conversation.id,
            host_user_id: updated_conversation.host_user_id,
            actor: actor,
            metadata: Enum.into(metadata, %{})
          }
        )

        {:ok, updated_conversation}

      error ->
        error
    end
  end

  defp notify_resolved(conversation, metadata) do
    case Application.get_env(:cairnloop, :notifier) do
      notifier when is_atom(notifier) and not is_nil(notifier) ->
        notifier.on_conversation_resolved(conversation, metadata)

      _ ->
        :ok
    end
  end
end
