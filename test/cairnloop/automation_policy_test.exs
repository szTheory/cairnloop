defmodule Cairnloop.AutomationPolicyTest do
  use ExUnit.Case, async: true

  alias Cairnloop.DefaultAutomationPolicy

  describe "DefaultAutomationPolicy" do
    test "decide/2 returns :draft_only for any proposal" do
      proposal = %{content: "This is a proposal", conversation_id: "conv_123"}
      opts = %{}

      assert :draft_only == DefaultAutomationPolicy.decide(proposal, opts)
    end
  end
end
