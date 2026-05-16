defmodule Cairnloop.NotifierTest do
  use ExUnit.Case, async: true

  test "callbacks are defined" do
    # We can check if the behaviour has the required callbacks
    callbacks = Cairnloop.Notifier.behaviour_info(:callbacks)
    assert {:on_conversation_resolved, 2} in callbacks
    assert {:on_sla_breach, 3} in callbacks
  end
end
