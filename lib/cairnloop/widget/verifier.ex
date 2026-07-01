defmodule Cairnloop.Widget.Verifier do
  @moduledoc """
  Behaviour for host-owned widget customer/session token verification.

  Cairnloop does not own customer auth. Host applications configure a verifier
  that translates an untrusted widget token into a bounded customer reference.
  """

  @type token_or_params :: binary() | map()
  @type customer_identity :: %{required(:customer_ref) => String.t()}

  @callback verify(token_or_params(), keyword()) ::
              {:ok, customer_identity()} | {:error, term()}
end
