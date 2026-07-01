defmodule CairnloopExample.DemoNotifier do
  @moduledoc """
  No-op notifier for the example application.

  The demo needs Cairnloop notifier callbacks to be configured, but it should not
  send real outbound notifications or require Chimeway delivery tables.
  """

  @behaviour Cairnloop.Notifier

  @impl true
  def on_conversation_resolved(_conversation, _metadata), do: :ok

  @impl true
  def on_sla_breach(_conversation, _sla, _metadata), do: :ok

  @impl true
  def on_outbound_triggered(_message, _conversation), do: :ok
end
