defmodule Cairnloop.Workers.IngestScrypath do
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"conversation_id" => id}}) do
    case Cairnloop.ScrypathConfig.status() do
      :disabled ->
        {:discard, :scrypath_disabled}

      {:misconfigured, reasons} ->
        {:discard, {:scrypath_misconfigured, reasons}}

      {:ready, config} ->
        post_conversation(id, config)
    end
  end

  def perform(%Oban.Job{args: _args}), do: {:discard, :missing_conversation_id}

  defp post_conversation(id, config) do
    req =
      Req.new(
        url: config.api_url,
        auth: {:bearer, config.api_key}
      )
      |> Req.merge(config.req_options)

    case Req.post(req, json: build_payload(Cairnloop.Chat.get_conversation!(id))) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, response} ->
        {:error, "API returned status #{response.status}"}

      {:error, exception} ->
        {:error, exception}
    end
  rescue
    Ecto.NoResultsError ->
      {:discard, :conversation_not_found}
  end

  defp build_payload(conversation) do
    %{
      conversation_id: conversation.id,
      subject: conversation.subject,
      messages: Enum.map(conversation.messages || [], &message_payload/1)
    }
  end

  defp message_payload(message) do
    %{
      role: to_string(message.role),
      content: message.content
    }
  end
end
