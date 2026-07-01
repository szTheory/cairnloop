defmodule Cairnloop.ApplicationTest do
  use ExUnit.Case, async: false

  setup do
    original = Application.get_env(:cairnloop, :scrypath_automation_enabled)
    original_api_url = Application.get_env(:cairnloop, :scrypath_api_url)
    original_api_key = Application.get_env(:cairnloop, :scrypath_api_key)

    on_exit(fn ->
      restore_env(:scrypath_automation_enabled, original)
      restore_env(:scrypath_api_url, original_api_url)
      restore_env(:scrypath_api_key, original_api_key)
    end)

    :ok
  end

  test "conversation resolved Scrypath bridge is inert by default" do
    Application.delete_env(:cairnloop, :scrypath_automation_enabled)

    assert :ok =
             Cairnloop.Application.handle_conversation_resolved(
               [:cairnloop, :conversation, :resolved],
               %{},
               %{conversation_id: 123, text: "support body"},
               nil
             )
  end

  test "conversation resolved Scrypath bridge must be explicitly enabled" do
    Application.put_env(:cairnloop, :scrypath_automation_enabled, false)

    assert :ok =
             Cairnloop.Application.handle_conversation_resolved(
               [:cairnloop, :conversation, :resolved],
               %{},
               %{conversation_id: 123, text: "support body"},
               nil
             )
  end

  test "conversation resolved Scrypath bridge skips enabled but misconfigured config" do
    Application.put_env(:cairnloop, :scrypath_automation_enabled, true)
    Application.delete_env(:cairnloop, :scrypath_api_url)
    Application.delete_env(:cairnloop, :scrypath_api_key)

    enqueue_fn = fn job ->
      send(self(), {:scrypath_enqueued, job})
      {:ok, job}
    end

    assert :ok =
             Cairnloop.Application.handle_conversation_resolved(
               [:cairnloop, :conversation, :resolved],
               %{},
               %{conversation_id: 123, text: "support body"},
               enqueue_fn: enqueue_fn
             )

    refute_received {:scrypath_enqueued, _job}
  end

  test "conversation resolved Scrypath bridge enqueues only conversation id when ready" do
    enqueue_fn = fn job ->
      send(self(), {:scrypath_enqueued, job})
      {:ok, job}
    end

    assert :ok =
             Cairnloop.Application.handle_conversation_resolved(
               [:cairnloop, :conversation, :resolved],
               %{},
               %{
                 conversation_id: 123,
                 text: "raw support body",
                 metadata: %{unsafe: "ignored"}
               },
               scrypath_automation_enabled: true,
               scrypath_api_url: "https://scrypath.example.test/v1/index",
               scrypath_api_key: "scrypath_live_key",
               enqueue_fn: enqueue_fn
             )

    assert_received {:scrypath_enqueued, job}
    assert job_args(job) == %{"conversation_id" => 123}
  end

  defp restore_env(key, nil), do: Application.delete_env(:cairnloop, key)
  defp restore_env(key, value), do: Application.put_env(:cairnloop, key, value)

  defp job_args(%Ecto.Changeset{} = changeset), do: Ecto.Changeset.get_field(changeset, :args)
  defp job_args(%Oban.Job{} = job), do: job.args
end
