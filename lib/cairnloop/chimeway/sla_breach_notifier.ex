defmodule Cairnloop.Chimeway.SLABreachNotifier do
  use Chimeway.Notifier

  @impl true
  def notification_key, do: "cairnloop.sla_breach"
  
  @impl true
  def version, do: 1

  @impl true
  def build(_payload, _opts) do
    # Placeholder implementation
    %{subject: "SLA Breach", body: "SLA Breached"}
  end

  @impl true
  def recipients(_payload) do
    []
  end
end
