defmodule Cairnloop.DefaultContextProvider do
  @moduledoc """
  Default implementation of Cairnloop.ContextProvider.
  Returns an empty context `{:ok, %{}}` for any input to ensure a safe default.
  """

  @behaviour Cairnloop.ContextProvider

  @impl true
  def get_context(_actor_id, _opts \\ []) do
    {:ok, %{}}
  end
end
