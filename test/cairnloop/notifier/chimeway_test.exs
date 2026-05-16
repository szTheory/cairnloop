defmodule Cairnloop.Notifier.ChimewayTest do
  use ExUnit.Case, async: true

  # We don't have Chimeway fully loaded or mocked yet, but we can verify it implements the behaviour.
  # For TDD RED, this will fail because Cairnloop.Notifier.Chimeway does not exist.
  
  describe "Cairnloop.Notifier.Chimeway" do
    test "implements Notifier behaviour" do
      assert Cairnloop.Notifier.Chimeway.__info__(:attributes)[:behaviour] == [Cairnloop.Notifier]
    end
    
    test "defines on_sla_breach/3" do
      assert {:on_sla_breach, 3} in Cairnloop.Notifier.Chimeway.__info__(:functions)
    end
    
    test "defines on_conversation_resolved/2" do
      assert {:on_conversation_resolved, 2} in Cairnloop.Notifier.Chimeway.__info__(:functions)
    end
  end
end
