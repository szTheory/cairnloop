defmodule Cairnloop.Notifier.ChimewayTest do
  use ExUnit.Case

  test "implements Cairnloop.Notifier behaviour" do
    assert Cairnloop.Notifier in behaviour_modules(Cairnloop.Notifier.Chimeway)
  end

  test "on_sla_breach calls Chimeway" do
    # Simply check it doesn't crash given valid structs
    conversation = %{id: "conv_123"}
    sla = %{target_type: "first_response", completed_at: DateTime.utc_now()}
    
    # We might not be able to assert Chimeway's side effects easily without Mox,
    # but we can verify it executes without errors.
    assert :ok = Cairnloop.Notifier.Chimeway.on_sla_breach(conversation, sla, %{})
  end

  test "on_conversation_resolved is implemented" do
    assert :ok = Cairnloop.Notifier.Chimeway.on_conversation_resolved(%{}, %{})
  end

  defp behaviour_modules(module) do
    module.module_info(:attributes)
    |> Keyword.get_values(:behaviour)
    |> List.flatten()
  end
end
