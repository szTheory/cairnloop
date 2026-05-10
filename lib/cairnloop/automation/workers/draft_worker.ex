defmodule Cairnloop.Automation.Workers.DraftWorker do
  use Oban.Worker,
    queue: :default,
    unique: [period: 60, states: [:scheduled]],
    replace: [scheduled: [:scheduled_at]]

  def perform(%Oban.Job{args: %{"conversation_id" => conversation_id}}) do
    Process.sleep(1000)

    case Cairnloop.Automation.create_draft(conversation_id, %{content: "This is a mocked AI draft."}) do
      {:ok, draft} ->
        Phoenix.PubSub.broadcast(Cairnloop.PubSub, "conversation:#{conversation_id}", {:draft_created, draft.id})
        :ok

      {:error, _changeset} ->
        :error
    end
  end
end
