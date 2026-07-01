defmodule Cairnloop.ChatTelemetryTest do
  use ExUnit.Case, async: false

  alias Cairnloop.{Chat, Conversation}

  @conversation_events [
    [:cairnloop, :conversation, :resolve, :start],
    [:cairnloop, :conversation, :resolve, :stop],
    [:cairnloop, :conversation, :resolved]
  ]

  @allowed_metadata_keys [:conversation_id, :operation, :outcome, :telemetry_span_context]

  @forbidden_metadata_keys [
    :conversation,
    :metadata,
    :host_user_id,
    :actor,
    :text,
    :content,
    :payload,
    :raw_body,
    :secret,
    :api_key,
    :customer_ref,
    :customer_id,
    :operator_id
  ]

  defmodule MockRepo do
    def get!(Conversation, 1) do
      %Conversation{
        id: 1,
        status: :open,
        subject: "Private billing export",
        host_user_id: "host-operator-raw-id",
        customer_ref: "customer-session-raw-id",
        inserted_at: DateTime.utc_now() |> DateTime.add(-120, :second)
      }
    end

    def get!(schema, id, _opts), do: get!(schema, id)

    def transaction(multi), do: execute_multi(multi, %{})

    defp execute_multi(multi, acc) do
      multi
      |> Ecto.Multi.to_list()
      |> Enum.reduce_while({:ok, acc}, fn
        {name, {:insert, %Ecto.Changeset{} = changeset, _opts}}, {:ok, results} ->
          result = Ecto.Changeset.apply_changes(changeset) |> Map.put(:id, 999)
          {:cont, {:ok, Map.put(results, name, result)}}

        {name, {:update, %Ecto.Changeset{} = changeset, _opts}}, {:ok, results} ->
          result = Ecto.Changeset.apply_changes(changeset)
          {:cont, {:ok, Map.put(results, name, result)}}

        {name, %Oban.Job{} = job}, {:ok, results} ->
          {:cont, {:ok, Map.put(results, name, job)}}

        {_name, {:merge, merge_fn}}, {:ok, results} ->
          case execute_multi(merge_fn.(results), results) do
            {:ok, merged_results} -> {:cont, {:ok, merged_results}}
            error -> {:halt, error}
          end
      end)
    end

    def one(_query), do: nil
  end

  setup do
    test_pid = self()
    handler_id = "conversation-telemetry-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      @conversation_events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:conversation_telemetry, event, measurements, metadata})
      end,
      nil
    )

    original_repo = Application.get_env(:cairnloop, :repo)
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      :telemetry.detach(handler_id)
      restore_env(:repo, original_repo)
    end)

    :ok
  end

  test "conversation resolve telemetry is bounded and excludes unsafe support metadata" do
    actor = %{type: "operator", id: "operator-raw-id"}

    assert {:ok, _results} =
             Chat.resolve_conversation(1,
               resolved_by: actor,
               text: "customer body should stay private",
               content: "support content should stay private",
               payload: %{raw_body: "provider payload should stay private"},
               raw_body: "raw email body should stay private",
               secret: "sk_test_secret_should_not_leak",
               arbitrary_metadata: %{customer_id: "customer-session-raw-id"}
             )

    events = receive_conversation_events(3)

    assert Enum.map(events, fn {event, _measurements, _metadata} -> event end) |> Enum.sort() ==
             Enum.sort(@conversation_events)

    for {_event, _measurements, metadata} <- events do
      assert_bounded_metadata(metadata)
    end

    assert Enum.any?(events, fn {event, _measurements, metadata} ->
             event == [:cairnloop, :conversation, :resolved] and
               metadata.conversation_id == 1 and
               metadata.operation == :resolve
           end)
  end

  defp receive_conversation_events(count) do
    for _ <- 1..count do
      assert_receive {:conversation_telemetry, event, measurements, metadata}, 500
      {event, measurements, metadata}
    end
  end

  defp assert_bounded_metadata(metadata) do
    assert Map.keys(metadata) -- @allowed_metadata_keys == []

    for key <- @forbidden_metadata_keys do
      refute Map.has_key?(metadata, key), "#{inspect(key)} must not be emitted"
    end

    assert is_integer(metadata.conversation_id)
    assert metadata.operation == :resolve

    inspected = inspect(metadata)

    for sensitive <- [
          "customer body should stay private",
          "support content should stay private",
          "provider payload should stay private",
          "raw email body should stay private",
          "sk_test_secret_should_not_leak",
          "host-operator-raw-id",
          "operator-raw-id",
          "customer-session-raw-id",
          "Private billing export"
        ] do
      refute inspected =~ sensitive
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:cairnloop, key)
  defp restore_env(key, value), do: Application.put_env(:cairnloop, key, value)
end
