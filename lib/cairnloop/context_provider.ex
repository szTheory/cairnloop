defmodule Cairnloop.ContextProvider do
  @moduledoc """
  Behaviour for providing host application context to Cairnloop.

  Cairnloop uses this behaviour to achieve a zero-API-sync design. Host applications
  implement this behaviour to directly return a map containing their internal domain
  data (like billing status, lifetime value, etc.) bound to a support ticket's actor.

  The returned map should be a deeply nested map of simple Elixir terms (strings,
  numbers, booleans, dates) that Cairnloop will recursively render as categorized
  UI sections. This "Zero-Config UI" allows the host developer to instantly receive
  a beautifully structured UI in the dashboard without writing any frontend code.

  ## Examples of Returned Context

      {:ok, %{
        "User Details" => %{name: "Alice", lifetime_value: "$450"},
        "Active Plan" => %{tier: "Pro", status: "past_due"}
      }}

  Callbacks return tagged tuples (`{:ok, map()} | {:error, term()}`) rather than
  raising exceptions on failure. This ensures the Cairnloop UI can degrade gracefully
  if the host application's database or external service is unavailable, rendering a
  "Context Unavailable" state without crashing the support operator's dashboard.
  """

  @doc """
  Retrieves context details for a given identity.

  The `actor_id` is a raw string from the Cairnloop ticket. The host application is
  responsible for mapping this string to their internal domain (e.g., resolving integer
  IDs, UUIDs, or emails).
  """
  @callback get_context(actor_id :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}
end
