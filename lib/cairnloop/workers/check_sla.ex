defmodule Cairnloop.Workers.CheckSLA do
  use Oban.Worker, queue: :default

  def perform(%Oban.Job{args: %{"conversation_id" => conversation_id, "sla" => sla_map}}) do
    conversation = %{id: conversation_id}
    
    sla = %{
      target_type: Map.get(sla_map, "target_type"),
      completed_at: case Map.get(sla_map, "completed_at") do
        nil -> nil
        iso8601 -> 
          case DateTime.from_iso8601(iso8601) do
            {:ok, datetime, _offset} -> datetime
            _ -> iso8601
          end
      end
    }

    case Application.get_env(:cairnloop, :notifier) do
      notifier when is_atom(notifier) and not is_nil(notifier) ->
        notifier.on_sla_breach(conversation, sla, %{})

      _ ->
        # Gracefully default to :ok if no notifier is configured
        :ok
    end
    
    :ok
  end
end
