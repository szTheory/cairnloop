defmodule Cairnloop.Ingress.EmailParser do
  @doc """
  Parses an email body to strictly isolate new reply text from quoted history.
  """
  def parse(email_body) when is_binary(email_body) do
    # Plan assumed Mailglass had a parse function, but it is for outbound email.
    # Fallback to standard regex to split new replies from quoted history.
    email_body
    |> String.split(~r/(?i)(^On\s.*wrote:$|^>)/m)
    |> List.first()
    |> String.trim()
  end

  def parse(_), do: ""
end
