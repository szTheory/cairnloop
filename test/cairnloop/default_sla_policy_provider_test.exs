defmodule Cairnloop.DefaultSLAPolicyProviderTest do
  use ExUnit.Case
  alias Cairnloop.DefaultSLAPolicyProvider

  describe "get_active_policies/0" do
    test "returns default policies" do
      assert {:ok, policies} = DefaultSLAPolicyProvider.get_active_policies()
      assert is_list(policies)
      assert length(policies) == 4
      assert Enum.find(policies, &(&1.priority == :normal))
    end
  end

  describe "set_policy/2" do
    test "returns a read-only error" do
      assert {:error, message} = DefaultSLAPolicyProvider.set_policy(:normal, %{target_first_response_minutes: 30})
      assert message =~ "read-only"
    end
  end
end
