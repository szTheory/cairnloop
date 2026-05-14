defmodule Cairnloop.Notifier.Chimeway do
  @behaviour Cairnloop.Notifier

  @impl true
  def on_sla_breach(conversation, sla, _metadata) do
    payload = %{
      conversation_id: conversation.id,
      sla_type: sla.target_type,
      breached_at: sla.completed_at
    }

    opts = [
      idempotency_key: "sla_breach_#{conversation.id}_#{sla.target_type}"
    ]

    chimeway_client = Application.get_env(:cairnloop, :chimeway_client, Chimeway)

    if Code.ensure_loaded?(chimeway_client) do
      _ = chimeway_client.trigger(Cairnloop.Chimeway.SLABreachNotifier, payload, opts)
      :ok
    else
      {:error, :missing_chimeway_dependency}
    end
  end

  @impl true
  def on_conversation_resolved(_conversation, _metadata) do
    :ok
  end
end
