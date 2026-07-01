defmodule Cairnloop.Ingress.EmailWebhookVerifier do
  @moduledoc """
  Verifies inbound email webhook requests before body parsing.

  Hosts may configure `:email_webhook_verifier` as a one-arity function, a
  two-arity raw-body function, a module exporting `verify/1` or `verify/2`, or
  `{module, function}` with the same arities. If no verifier is configured,
  Cairnloop falls back to the simple shared-token seam at `:email_webhook_token`.
  """

  import Plug.Conn

  @spec verify(Plug.Conn.t()) :: {:ok, :verified} | {:error, :unauthorized}
  def verify(%Plug.Conn{} = conn) do
    case Application.get_env(:cairnloop, :email_webhook_verifier) do
      nil ->
        verify_shared_token(conn)

      verifier when is_function(verifier, 1) ->
        verifier
        |> apply_verifier(conn)
        |> normalize_result()

      verifier when is_function(verifier, 2) ->
        {:error, :unauthorized}

      {module, function} when is_atom(module) and is_atom(function) ->
        module
        |> apply_verifier(function, conn)
        |> normalize_result()

      module when is_atom(module) ->
        module
        |> apply_verifier(:verify, conn)
        |> normalize_result()

      _invalid ->
        {:error, :unauthorized}
    end
  rescue
    _ -> {:error, :unauthorized}
  catch
    _, _ -> {:error, :unauthorized}
  end

  @spec verify(Plug.Conn.t(), binary()) :: {:ok, :verified} | {:error, :unauthorized}
  def verify(%Plug.Conn{} = conn, body) when is_binary(body) do
    case Application.get_env(:cairnloop, :email_webhook_verifier) do
      verifier when is_function(verifier, 2) ->
        verifier
        |> apply_verifier(conn, body)
        |> normalize_result()

      {module, function} when is_atom(module) and is_atom(function) ->
        module
        |> apply_verifier(function, conn, body)
        |> normalize_result()

      module when is_atom(module) ->
        module
        |> apply_verifier(:verify, conn, body)
        |> normalize_result()

      _other ->
        verify(conn)
    end
  rescue
    _ -> {:error, :unauthorized}
  catch
    _, _ -> {:error, :unauthorized}
  end

  @spec requires_body?() :: boolean()
  def requires_body? do
    case Application.get_env(:cairnloop, :email_webhook_verifier) do
      verifier when is_function(verifier, 2) ->
        true

      {module, function} when is_atom(module) and is_atom(function) ->
        exported?(module, function, 2)

      module when is_atom(module) ->
        exported?(module, :verify, 2)

      _other ->
        false
    end
  end

  defp apply_verifier(verifier, conn) when is_function(verifier, 1), do: verifier.(conn)

  defp apply_verifier(verifier, conn, body) when is_function(verifier, 2) do
    verifier.(conn, body)
  end

  defp apply_verifier(module, function, conn) do
    if exported?(module, function, 1) do
      apply(module, function, [conn])
    else
      {:error, :unauthorized}
    end
  end

  defp apply_verifier(module, function, conn, body) do
    cond do
      exported?(module, function, 2) ->
        apply(module, function, [conn, body])

      exported?(module, function, 1) ->
        apply(module, function, [conn])

      true ->
        {:error, :unauthorized}
    end
  end

  defp exported?(module, function, arity) do
    Code.ensure_loaded?(module) and function_exported?(module, function, arity)
  end

  defp verify_shared_token(conn) do
    configured_token = Application.get_env(:cairnloop, :email_webhook_token)

    with token when is_binary(token) and byte_size(token) > 0 <- configured_token,
         [provided_token] <- get_req_header(conn, "x-webhook-token"),
         true <- secure_match?(provided_token, token) do
      {:ok, :verified}
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp secure_match?(provided_token, configured_token)
       when byte_size(provided_token) == byte_size(configured_token) do
    Plug.Crypto.secure_compare(provided_token, configured_token)
  end

  defp secure_match?(_provided_token, _configured_token), do: false

  defp normalize_result({:ok, :verified}), do: {:ok, :verified}
  defp normalize_result(:ok), do: {:ok, :verified}
  defp normalize_result(true), do: {:ok, :verified}
  defp normalize_result(_other), do: {:error, :unauthorized}
end
