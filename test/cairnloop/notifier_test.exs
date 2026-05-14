defmodule Cairnloop.NotifierTest do
  use ExUnit.Case

  test "defines expected callbacks" do
    callbacks = Cairnloop.Notifier.behaviour_info(:callbacks)
    
    assert {:on_conversation_resolved, 2} in callbacks
    assert {:on_sla_breach, 3} in callbacks
  end
end
