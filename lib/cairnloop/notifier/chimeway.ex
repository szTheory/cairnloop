defmodule Cairnloop.Notifier.Chimeway do
  @behaviour Cairnloop.Notifier

  alias Cairnloop.Chimeway.SLABreachNotifier

  @impl true
  def on_conversation_resolved(_conversation, _metadata) do
    :ok
  end

  @impl true
  def on_sla_breach(conversation, sla, _metadata) do
    payload = %{
      conversation_id: conversation.id,
      account_id: Map.get(conversation, :account_id),
      sla_type: sla.target_type,
      breached_at: Map.get(sla, :completed_at)
    }

    idempotency_key = "sla_breach_#{conversation.id}_#{sla.target_type}"

    Chimeway.trigger(SLABreachNotifier, payload, idempotency_key: idempotency_key)
  end

  @impl true
  def on_outbound_triggered(message, conversation) do
    payload = %{
      conversation_id: conversation.id,
      message_id: message.id,
      template_id: message.metadata["template_id"],
      content: message.content,
      recipient: conversation.host_user_id
    }

    idempotency_key = "outbound_message_#{message.id}"

    Chimeway.trigger(Cairnloop.Chimeway.OutboundNotifier, payload,
      idempotency_key: idempotency_key
    )
  end
end
