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
    |> repo().preload(messages: (from m in Message, order_by: [asc: m.inserted_at]))
  end

  def reply_to_conversation(conversation_id, content, role \\ :agent) do
    conversation = repo().get!(Conversation, conversation_id)
    
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:message, Message.changeset(%Message{}, %{
      conversation_id: conversation.id,
      content: content,
      role: role
    }))
    |> Ecto.Multi.update(:conversation, Ecto.Changeset.change(conversation, %{status: :open}))
    |> repo().transaction()
  end
end
