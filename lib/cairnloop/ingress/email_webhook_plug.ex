defmodule Cairnloop.Ingress.EmailWebhookPlug do
  @behaviour Plug

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    enqueue = Keyword.get(opts, :enqueue, &Oban.insert/1)

    with {:ok, body, conn} <- read_verified_body(conn),
         {:ok, payload} <- Jason.decode(body) do
      content =
        payload
        |> extract_email_body()
        |> Cairnloop.Ingress.EmailParser.parse()

      %{channel: "email", content: content}
      |> Cairnloop.Workers.ProcessMessage.new()
      |> enqueue_email(conn, enqueue)
    else
      {:error, :unauthorized} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
        |> halt()

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "Bad Request"}))
    end
  end

  defp read_verified_body(conn) do
    if Cairnloop.Ingress.EmailWebhookVerifier.requires_body?() do
      read_body_then_verify(conn)
    else
      verify_then_read_body(conn)
    end
  end

  defp read_body_then_verify(conn) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} ->
        with {:ok, :verified} <- Cairnloop.Ingress.EmailWebhookVerifier.verify(conn, body) do
          {:ok, body, conn}
        end

      other ->
        other
    end
  end

  defp verify_then_read_body(conn) do
    with {:ok, :verified} <- Cairnloop.Ingress.EmailWebhookVerifier.verify(conn) do
      Plug.Conn.read_body(conn)
    end
  end

  defp enqueue_email(changeset, conn, enqueue) do
    case enqueue.(changeset) do
      {:ok, _job} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{status: "ok"}))

      {:error, _reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(503, Jason.encode!(%{error: "Queue unavailable"}))
        |> halt()

      _other ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(503, Jason.encode!(%{error: "Queue unavailable"}))
        |> halt()
    end
  end

  defp extract_email_body(payload) do
    # This varies heavily by provider. E.g. Postmark uses "TextBody", Sendgrid uses "text"
    Map.get(payload, "TextBody") || Map.get(payload, "text") || ""
  end
end
