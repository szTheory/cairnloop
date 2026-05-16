defmodule Cairnloop.Chimeway.SLABreachNotifier do
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "cairnloop.sla_breach"

  @impl true
  def version, do: 1

  @impl true
  def recipients(_params) do
    # For a system-level SLA breach, the recipient might be configured generically.
    # Return an empty list or a default system recipient
    {:ok, []}
  end

  @impl true
  def build(params, _recipient) do
    {:ok, %{
      subject: "SLA Breach on #{params.conversation_id}",
      body: "SLA #{params.sla_type} breached at #{params.breached_at}"
    }}
  end
end
