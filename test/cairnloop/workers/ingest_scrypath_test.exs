defmodule Cairnloop.Workers.IngestScrypathTest do
  use ExUnit.Case, async: false
  use Oban.Testing, repo: Cairnloop.Repo

  alias Cairnloop.{Conversation, Message}
  alias Cairnloop.ScrypathConfig
  alias Cairnloop.Workers.IngestScrypath

  defmodule MockRepo do
    def get!(Conversation, 42) do
      %Conversation{
        id: 42,
        subject: "Refund export fixed",
        host_user_id: "operator_123",
        customer_ref: "customer_abc",
        resolved_at: DateTime.utc_now()
      }
    end

    def get!(schema, id, _opts), do: get!(schema, id)

    def preload(%Conversation{} = conversation, preloads) when is_list(preloads) do
      if Keyword.has_key?(preloads, :messages) do
        %{
          conversation
          | messages: [
              %Message{
                id: 10,
                role: :user,
                content: "The refund export was empty.",
                inserted_at: DateTime.utc_now()
              },
              %Message{
                id: 11,
                role: :agent,
                content: "Regenerated the export and confirmed delivery.",
                inserted_at: DateTime.utc_now()
              }
            ]
        }
      else
        conversation
      end
    end
  end

  setup do
    original_enabled = Application.get_env(:cairnloop, :scrypath_automation_enabled)
    original_api_url = Application.get_env(:cairnloop, :scrypath_api_url)
    original_api_key = Application.get_env(:cairnloop, :scrypath_api_key)
    original_req_options = Application.get_env(:cairnloop, :scrypath_req_options)
    original_repo = Application.get_env(:cairnloop, :repo)

    on_exit(fn ->
      restore_env(:scrypath_automation_enabled, original_enabled)
      restore_env(:scrypath_api_url, original_api_url)
      restore_env(:scrypath_api_key, original_api_key)
      restore_env(:scrypath_req_options, original_req_options)
      restore_env(:repo, original_repo)
    end)

    :ok
  end

  describe "ScrypathConfig.status/1" do
    test "reports disabled when config is absent or explicitly false" do
      Application.delete_env(:cairnloop, :scrypath_automation_enabled)

      assert :disabled = ScrypathConfig.status()
      assert :disabled = ScrypathConfig.status(scrypath_automation_enabled: false)
    end

    test "reports ready config when enabled with real URL and key" do
      assert {:ready, config} =
               ScrypathConfig.status(
                 scrypath_automation_enabled: true,
                 scrypath_api_url: "https://scrypath.example.test/v1/index",
                 scrypath_api_key: "scrypath_live_key",
                 scrypath_req_options: [plug: {Req.Test, Cairnloop.ScrypathApi}]
               )

      assert config == %{
               api_url: "https://scrypath.example.test/v1/index",
               api_key: "scrypath_live_key",
               req_options: [plug: {Req.Test, Cairnloop.ScrypathApi}]
             }
    end

    test "reports bounded reasons for missing or unsafe enabled config" do
      assert {:misconfigured, missing_reasons} =
               ScrypathConfig.status(scrypath_automation_enabled: true)

      assert :missing_api_url in missing_reasons
      assert :missing_api_key in missing_reasons
      assert Enum.all?(missing_reasons, &is_atom/1)

      assert {:misconfigured, unsafe_reasons} =
               ScrypathConfig.status(
                 scrypath_automation_enabled: true,
                 scrypath_api_url: "https://api.scrypath.local/v1/index",
                 scrypath_api_key: "dummy"
               )

      assert :unsafe_api_url in unsafe_reasons
      assert :unsafe_api_key in unsafe_reasons
      assert Enum.all?(unsafe_reasons, &is_atom/1)
    end
  end

  describe "perform/1" do
    test "discards disabled config before issuing HTTP" do
      test_pid = self()

      Req.Test.stub(Cairnloop.ScrypathApi, fn conn ->
        send(test_pid, :scrypath_http_called)
        Req.Test.json(conn, %{success: true})
      end)

      Application.put_env(:cairnloop, :scrypath_req_options,
        plug: {Req.Test, Cairnloop.ScrypathApi}
      )

      assert {:discard, :scrypath_disabled} =
               IngestScrypath.perform(%Oban.Job{args: %{"conversation_id" => 42}})

      refute_received :scrypath_http_called
    end

    test "discards misconfigured config before issuing HTTP" do
      test_pid = self()

      Req.Test.stub(Cairnloop.ScrypathApi, fn conn ->
        send(test_pid, :scrypath_http_called)
        Req.Test.json(conn, %{success: true})
      end)

      Application.put_env(:cairnloop, :scrypath_automation_enabled, true)

      Application.put_env(:cairnloop, :scrypath_req_options,
        plug: {Req.Test, Cairnloop.ScrypathApi}
      )

      assert {:discard, {:scrypath_misconfigured, reasons}} =
               IngestScrypath.perform(%Oban.Job{args: %{"conversation_id" => 42}})

      assert :missing_api_url in reasons
      assert :missing_api_key in reasons
      refute_received :scrypath_http_called
    end

    test "posts ready Scrypath payload from durable conversation data" do
      test_pid = self()

      Req.Test.stub(Cairnloop.ScrypathApi, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        send(
          test_pid,
          {:scrypath_request, Jason.decode!(body),
           Plug.Conn.get_req_header(conn, "authorization")}
        )

        Req.Test.json(conn, %{success: true})
      end)

      Application.put_env(:cairnloop, :repo, MockRepo)
      Application.put_env(:cairnloop, :scrypath_automation_enabled, true)
      Application.put_env(:cairnloop, :scrypath_api_url, "https://scrypath.example.test/v1/index")
      Application.put_env(:cairnloop, :scrypath_api_key, "scrypath_live_key")

      Application.put_env(:cairnloop, :scrypath_req_options,
        plug: {Req.Test, Cairnloop.ScrypathApi}
      )

      job = %Oban.Job{args: %{"conversation_id" => 42, "text" => "job text is ignored"}}

      assert :ok = IngestScrypath.perform(job)

      assert_received {:scrypath_request, payload, ["Bearer scrypath_live_key"]}

      assert payload["conversation_id"] == 42
      assert payload["subject"] == "Refund export fixed"

      assert payload["messages"] == [
               %{"role" => "user", "content" => "The refund export was empty."},
               %{
                 "role" => "agent",
                 "content" => "Regenerated the export and confirmed delivery."
               }
             ]

      refute inspect(payload) =~ "job text is ignored"
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:cairnloop, key)
  defp restore_env(key, value), do: Application.put_env(:cairnloop, key, value)
end
