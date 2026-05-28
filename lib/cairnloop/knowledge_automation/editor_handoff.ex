defmodule Cairnloop.KnowledgeAutomation.EditorHandoff do
  @moduledoc false

  @salt "knowledge-base-editor-handoff"
  @max_age 1800

  def sign(attrs) when is_map(attrs) do
    Plug.Crypto.sign(secret_key_base(), @salt, normalize(attrs), max_age: @max_age)
  end

  def decode(token) do
    Plug.Crypto.verify(secret_key_base(), @salt, token, max_age: @max_age)
  end

  def verify(token, attrs) when is_map(attrs) do
    expected = normalize(attrs)

    with {:ok, payload} <- Plug.Crypto.verify(secret_key_base(), @salt, token, max_age: @max_age),
         true <- payload == expected do
      :ok
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :mismatch}
    end
  end

  defp normalize(attrs) do
    %{
      "article_id" =>
        normalize_integer(Map.get(attrs, :article_id) || Map.get(attrs, "article_id")),
      "manual_edit_opened_at" =>
        Map.get(attrs, :manual_edit_opened_at) || Map.get(attrs, "manual_edit_opened_at"),
      "review_task_id" =>
        normalize_integer(Map.get(attrs, :review_task_id) || Map.get(attrs, "review_task_id")),
      "return_to" => Map.get(attrs, :return_to) || Map.get(attrs, "return_to"),
      "suggestion_id" =>
        normalize_integer(Map.get(attrs, :suggestion_id) || Map.get(attrs, "suggestion_id"))
    }
  end

  defp normalize_integer(nil), do: nil
  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} -> id
      _ -> value
    end
  end

  defp normalize_integer(value), do: value

  defp secret_key_base do
    case Application.get_env(:cairnloop, __MODULE__, [])[:secret_key_base] do
      value when is_binary(value) and byte_size(value) > 0 ->
        value

      _ ->
        if Mix.env() == :test do
          # test-only: stable per-process random key
          key = {__MODULE__, :secret_key_base}

          case :persistent_term.get(key, nil) do
            nil ->
              value = Base.url_encode64(:crypto.strong_rand_bytes(48), padding: false)
              :persistent_term.put(key, value)
              value

            value ->
              value
          end
        else
          raise """
          Cairnloop.KnowledgeAutomation.EditorHandoff requires a stable secret_key_base.
          Configure it in config/runtime.exs:
            config :cairnloop, Cairnloop.KnowledgeAutomation.EditorHandoff,
              secret_key_base: System.fetch_env!("CAIRNLOOP_HANDOFF_SECRET_KEY_BASE")
          """
        end
    end
  end
end
