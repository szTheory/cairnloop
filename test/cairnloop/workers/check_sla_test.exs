defmodule Cairnloop.Workers.CheckSLATest do
  use ExUnit.Case

  defmodule DummyNotifier do
    @behaviour Cairnloop.Notifier
    def on_sla_breach(conversation, sla, metadata) do
      send(self(), {:sla_breached, conversation, sla, metadata})
      :ok
    end

    def on_conversation_resolved(_conversation, _metadata), do: :ok
  end

  defmodule ErrorNotifier do
    @behaviour Cairnloop.Notifier
    def on_sla_breach(_conversation, _sla, _metadata) do
      raise "Notifier failed"
    end

    def on_conversation_resolved(_conversation, _metadata), do: :ok
  end

  setup do
    Application.put_env(:cairnloop, :notifier, DummyNotifier)
    on_exit(fn -> Application.delete_env(:cairnloop, :notifier) end)
    :ok
  end

  test "worker handles notifier exception, logs error, emits telemetry, and does not crash" do
    Application.put_env(:cairnloop, :notifier, ErrorNotifier)

    parent = self()

    handler = fn [:cairnloop, :notifier, :failed], _measurements, metadata, _config ->
      send(parent, {:telemetry_event, metadata})
    end

    :telemetry.attach("notifier-error-test", [:cairnloop, :notifier, :failed], handler, nil)

    args = %{
      "conversation_id" => "123",
      "sla" => %{
        "target_type" => "first_response",
        "completed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    # Should not crash, returns :ok
    assert :ok = Cairnloop.Workers.CheckSLA.perform(%Oban.Job{args: args})

    # Should emit telemetry event
    assert_receive {:telemetry_event, metadata}
    assert metadata.error.__struct__ == RuntimeError
    assert metadata.error.message == "Notifier failed"

    :telemetry.detach("notifier-error-test")
  end

  test "worker executes on_sla_breach when SLA is breached" do
    args = %{
      "conversation_id" => "123",
      "sla" => %{
        "target_type" => "first_response",
        "completed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    assert :ok = Cairnloop.Workers.CheckSLA.perform(%Oban.Job{args: args})

    assert_received {:sla_breached, conversation, sla, _metadata}
    assert conversation.id == "123"
    assert sla.target_type == "first_response"
  end

  test "worker gracefully defaults to :ok when notifier is not configured" do
    Application.delete_env(:cairnloop, :notifier)

    args = %{
      "conversation_id" => "123",
      "sla" => %{
        "target_type" => "first_response",
        "completed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    assert :ok = Cairnloop.Workers.CheckSLA.perform(%Oban.Job{args: args})
    refute_received {:sla_breached, _, _, _}
  end
end
