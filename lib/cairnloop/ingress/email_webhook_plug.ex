defmodule Cairnloop.Ingress.EmailWebhookPlug do
  @behaviour Plug

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # T-M001-02 Mitigation: Require webhook signature verification or secret token.
    with {:ok, :verified} <- verify_signature(conn),
         {:ok, body, conn} <- Plug.Conn.read_body(conn),
         {:ok, payload} <- Jason.decode(body) do
      content =
        payload
        |> extract_email_body()
        |> Cairnloop.Ingress.EmailParser.parse()

      %{channel: "email", content: content}
      |> Cairnloop.Workers.ProcessMessage.new()
      |> Oban.insert()

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{status: "ok"}))
    else
      {:error, :unauthorized} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))

      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "Bad Request"}))
    end
  end

  defp verify_signature(conn) do
    # In a real implementation, we would verify the signature of the provider.
    case get_req_header(conn, "x-webhook-token") do
      ["secret-token"] -> {:ok, :verified}
      # For the sake of development and simple passing of this, 
      # we assume the request is valid if it has any token or we just allow it if no token checking is enforced yet.
      # To be secure, let's strictly require the header.
      _ -> {:error, :unauthorized}
    end
  end

  defp extract_email_body(payload) do
    # This varies heavily by provider. E.g. Postmark uses "TextBody", Sendgrid uses "text"
    Map.get(payload, "TextBody") || Map.get(payload, "text") || ""
  end
end
