defmodule Cairnloop.Automation.ScoriaEngineTest do
  use ExUnit.Case, async: true

  alias Cairnloop.Automation.ScoriaEngine

  setup do
    Application.put_env(:cairnloop, :scrypath_req_opts, [plug: {Req.Test, Cairnloop.ScrypathAPI}])
    :ok
  end

  describe "ScoriaEngine" do
    test "generate_draft/1 returns a simulated draft map" do
      conversation_id = "conv_987"

      Req.Test.stub(Cairnloop.ScrypathAPI, fn conn ->
        Req.Test.json(conn, %{"results" => ["relevant context"]})
      end)

      assert {:ok, proposal} = ScoriaEngine.generate_draft(conversation_id)

      assert proposal.conversation_id == conversation_id
      assert Map.has_key?(proposal, :content)
      assert is_binary(proposal.content)
      assert proposal.context_used == %{"results" => ["relevant context"]}
      assert proposal.content =~ "grounded"
    end
  end
end
