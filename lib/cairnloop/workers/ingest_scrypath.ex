defmodule Cairnloop.Workers.IngestScrypath do
  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"conversation_id" => id, "text" => text}}) do
    api_url = Application.get_env(:cairnloop, :scrypath_api_url, "https://api.scrypath.local/v1/index")
    api_key = Application.get_env(:cairnloop, :scrypath_api_key, "dummy")
    
    req_options = Application.get_env(:cairnloop, :scrypath_req_options, [])
    
    req = 
      Req.new(
        url: api_url,
        auth: {:bearer, api_key}
      )
      |> Req.merge(req_options)

    case Req.post(req, json: %{conversation_id: id, text: text}) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, response} ->
        {:error, "API returned status #{response.status}"}

      {:error, exception} ->
        {:error, exception}
    end
  end
end
