defmodule Cairnloop.Notifier.ChimewayTest do
  use ExUnit.Case

  defmodule DummyChimeway do
    def trigger(namespace, payload, opts) do
      send(self(), {:chimeway_triggered, namespace, payload, opts})
    end
  end

  setup do
    on_exit(fn -> Application.delete_env(:cairnloop, :chimeway_client) end)
    :ok
  end

  test "implements Cairnloop.Notifier behaviour" do
    assert Cairnloop.Notifier in behaviour_modules(Cairnloop.Notifier.Chimeway)
  end

  test "returns error when Chimeway dependency is missing" do
    Application.put_env(:cairnloop, :chimeway_client, SomeMissingModule)

    conversation = %{id: "conv_123"}
    sla = %{target_type: "first_response", completed_at: DateTime.utc_now()}

    assert {:error, :missing_chimeway_dependency} = Cairnloop.Notifier.Chimeway.on_sla_breach(conversation, sla, %{})
  end

  test "on_sla_breach sends correct payload and idempotency key" do
    Application.put_env(:cairnloop, :chimeway_client, DummyChimeway)

    conversation = %{id: "conv_123"}
    completed_at = DateTime.utc_now()
    sla = %{target_type: "first_response", completed_at: completed_at}

    assert :ok = Cairnloop.Notifier.Chimeway.on_sla_breach(conversation, sla, %{})

    assert_received {:chimeway_triggered, Cairnloop.Chimeway.SLABreachNotifier, payload, opts}
    
    assert payload.conversation_id == "conv_123"
    assert payload.sla_type == "first_response"
    assert payload.breached_at == completed_at
    
    assert opts[:idempotency_key] == "sla_breach_conv_123_first_response"
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
