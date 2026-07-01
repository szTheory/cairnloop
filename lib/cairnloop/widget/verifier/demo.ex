defmodule Cairnloop.Widget.Verifier.Demo do
  @moduledoc """
  Explicit demo/test widget verifier.

  This verifier accepts non-empty binary tokens and maps them to `:customer_ref`.
  It is intentionally useful for local demos only and is never selected unless a
  host configures it with `:widget_token_verifier`.
  """

  @behaviour Cairnloop.Widget.Verifier

  @impl true
  def verify(token, opts) when is_binary(token) do
    token = String.trim(token)

    if token == "" do
      {:error, :empty_token}
    else
      {:ok, %{customer_ref: customer_ref(token, opts)}}
    end
  end

  def verify(%{"token" => token}, opts), do: verify(token, opts)
  def verify(%{token: token}, opts), do: verify(token, opts)
  def verify(_token_or_params, _opts), do: {:error, :invalid_token}

  defp customer_ref(token, opts) do
    case Keyword.get(opts, :customer_ref_prefix) || Keyword.get(opts, :prefix) do
      prefix when is_binary(prefix) and prefix != "" -> prefix <> token
      _ -> token
    end
  end
end
