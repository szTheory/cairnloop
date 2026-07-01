defmodule CairnloopExampleWeb.LiveAcceptance do
  @moduledoc """
  Ecto-sandbox `on_mount` hook for browser E2E (test env only).

  When `config :cairnloop_example, :sql_sandbox, true` is set, the example router injects this
  hook into the `cairnloop_dashboard/2` `live_session` so the LiveView process (including the
  library-owned `Cairnloop.Web.ConversationLive`) joins the shared Ecto sandbox connection the
  test checked out — reading the metadata `phoenix_test_playwright` ships in the User-Agent header
  (declared via `connect_info: [:user_agent, ...]` on the live socket).

  This is the standard `Phoenix.Ecto.SQL.Sandbox` LiveView acceptance pattern. It lets the rail
  E2E build its governed-action fixtures inside the test's transaction and have the rendered
  LiveView see them — no seed dependency, fully isolated. Compiled out of dev/prod.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    socket =
      assign_new(socket, :phoenix_ecto_sandbox, fn ->
        if connected?(socket), do: get_connect_info(socket, :user_agent)
      end)

    Phoenix.Ecto.SQL.Sandbox.allow(socket.assigns.phoenix_ecto_sandbox, Ecto.Adapters.SQL.Sandbox)

    {:cont, socket}
  end
end
