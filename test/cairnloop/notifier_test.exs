defmodule Cairnloop.NotifierTest do
  use ExUnit.Case, async: true

  describe "Cairnloop.Notifier behaviour" do
    test "defines required callbacks" do
      # In Elixir, we can check if a module defines a behaviour by checking its callbacks
      # However, since it's just a behaviour, the compiler checks the implementers.
      # To test the behaviour itself, we can define a dummy module and ensure it complains
      # if it's missing the callbacks, but the easiest way to assert the behaviour exists
      # is to just check its module info or manually implement it.
      
      # Let's ensure the callbacks are defined
      assert {:on_conversation_resolved, 2} in Cairnloop.Notifier.behaviour_info(:callbacks)
      assert {:on_sla_breach, 3} in Cairnloop.Notifier.behaviour_info(:callbacks)
    end
  end
end
