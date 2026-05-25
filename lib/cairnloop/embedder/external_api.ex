defmodule Cairnloop.Embedder.ExternalApi do
  @moduledoc """
  Implementation of Embedder behaviour using an external API.
  Uses OpenAI's text-embedding-ada-002 as default.
  """

  @behaviour Cairnloop.Embedder

  @impl true
  def generate_embeddings(chunks, _opts \\ []) do
    api_key = System.get_env("OPENAI_API_KEY")

    if is_nil(api_key) or api_key == "" do
      # Return mock embeddings for development safety if no API key
      mock_embeddings =
        Enum.map(chunks, fn _chunk ->
          # Default OpenAI dimension size
          List.duplicate(0.0, 1536)
        end)

      {:ok, mock_embeddings}
    else
      req_body = %{
        input: chunks,
        model: "text-embedding-ada-002"
      }

      req =
        Req.new(
          base_url: "https://api.openai.com",
          auth: {:bearer, api_key},
          json: req_body
        )

      case Req.post(req, url: "/v1/embeddings") do
        {:ok, %Req.Response{status: 200, body: %{"data" => data}}} ->
          embeddings =
            data
            |> Enum.sort_by(& &1["index"])
            |> Enum.map(& &1["embedding"])

          {:ok, embeddings}

        {:ok, %Req.Response{status: status, body: body}} ->
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
