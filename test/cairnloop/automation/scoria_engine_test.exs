defmodule Cairnloop.Automation.ScoriaEngineTest do
  use ExUnit.Case, async: true

  alias Cairnloop.Automation.ScoriaEngine

  describe "ScoriaEngine" do
    test "generate_draft/1 returns a simulated draft map" do
      conversation_id = "conv_987"
      assert {:ok, proposal} = ScoriaEngine.generate_draft(conversation_id)
      
      assert proposal.conversation_id == conversation_id
      assert Map.has_key?(proposal, :content)
      assert is_binary(proposal.content)
    end
  end
end
