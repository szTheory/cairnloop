defmodule Cairnloop.Workers.NotifyResolvedWorker do
  use Oban.Worker, queue: :default

  def perform(%Oban.Job{args: %{"conversation_id" => conversation_id, "metadata" => metadata}}) do
    conversation = Cairnloop.Chat.get_conversation!(conversation_id)

    case Application.get_env(:cairnloop, :notifier) do
      notifier when is_atom(notifier) and not is_nil(notifier) ->
        notifier.on_conversation_resolved(conversation, Enum.into(metadata, %{}))

      _ ->
        :ok
    end
  end
end
