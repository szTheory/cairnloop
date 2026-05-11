defmodule SupportOS.ContextProviderTest do
  use ExUnit.Case, async: true

  alias SupportOS.DefaultContextProvider

  describe "DefaultContextProvider" do
    test "get_context/2 returns {:ok, %{}} for any actor_id" do
      actor_id = "user_123"
      opts = []

      assert {:ok, %{}} == DefaultContextProvider.get_context(actor_id, opts)
    end
  end
end
