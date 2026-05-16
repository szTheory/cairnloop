defmodule Cairnloop.NotifierTest do
  use ExUnit.Case, async: true

  test "defines expected callbacks" do
    callbacks = Cairnloop.Notifier.behaviour_info(:callbacks)
    
    assert Keyword.has_key?(callbacks, :on_conversation_resolved)
    assert Keyword.has_key?(callbacks, :on_sla_breach)
  end
end
