defmodule Cairnloop.Chimeway.OutboundNotifier do
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "cairnloop.outbound_message"

  @impl true
  def version, do: 1

  @impl true
  def recipients(params) do
    # Usually the recipient is linked to the conversation or host_user_id.
    # We expect the recipient to be passed in params or derived.
    # For now, we return the recipient from params if available.
    case Map.get(params, :recipient) do
      nil -> {:ok, []}
      recipient -> {:ok, [recipient]}
    end
  end

  @impl true
  def build(params, _recipient) do
    # Use template_id from params to determine content, or use content directly.
    content = Map.get(params, :content)
    template_id = Map.get(params, :template_id)

    {:ok,
     %{
       subject: "Follow-up: #{params.conversation_id}",
       body: content || "Outbound message for template #{template_id}",
       metadata: %{
         "template_id" => template_id,
         "conversation_id" => params.conversation_id
       }
     }}
  end
end
