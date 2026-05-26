defmodule Cairnloop.Workers.OutboundWorker do
  use Oban.Worker, queue: :default

  alias Cairnloop.{Chat, Message}

  def perform(%Oban.Job{args: %{"message_id" => message_id}}) do
    repo = Application.fetch_env!(:cairnloop, :repo)
    message = repo.get!(Message, message_id)
    conversation = Chat.get_conversation!(message.conversation_id)

    case Application.get_env(:cairnloop, :notifier) do
      notifier when is_atom(notifier) and not is_nil(notifier) ->
        case notifier.on_outbound_triggered(message, conversation) do
          :ok ->
            update_message_status(message, "sent")

          {:ok, _} ->
            update_message_status(message, "sent")

          error ->
            update_message_status(message, "failed")
            {:error, error}
        end

      _ ->
        update_message_status(message, "sent")
        :ok
    end
  end

  defp update_message_status(message, status) do
    repo = Application.fetch_env!(:cairnloop, :repo)
    metadata = Map.put(message.metadata || %{}, "status", status)
    
    message
    |> Ecto.Changeset.change(%{metadata: metadata})
    |> repo.update()
  end
end
