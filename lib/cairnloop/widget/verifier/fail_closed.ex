defmodule Cairnloop.Widget.Verifier.FailClosed do
  @moduledoc """
  Default widget verifier that rejects every token.

  Hosts must explicitly configure `:widget_token_verifier` before browser widget
  identity can enter Cairnloop.
  """

  @behaviour Cairnloop.Widget.Verifier

  @impl true
  def verify(_token_or_params, _opts), do: {:error, :not_configured}
end
