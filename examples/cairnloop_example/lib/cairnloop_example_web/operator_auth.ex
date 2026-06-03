defmodule CairnloopExampleWeb.OperatorAuth do
  @moduledoc """
  Demonstrates how a host app injects its **signed-in operator** into the Cairnloop dashboard.

  Cairnloop is host-owned and embeds no auth — it only needs to know *who the operator is* on each
  request, via the `host_user_id` value in the dashboard live session. That value is the audit
  actor recorded on governed events and the scope key for operator search, so it must be the real
  signed-in operator, not a hardcoded placeholder.

  This module stands in for the `MyAppWeb.UserAuth` module a real adopter already has (e.g. the one
  `mix phx.gen.auth` generates). In a real app:

    * `fetch_current_operator/2` would be your existing `fetch_current_user/2` plug, loading the
      operator from the session token / database.
    * `cairnloop_session/1` is the per-request seam: wired as
      `session: {CairnloopExampleWeb.OperatorAuth, :cairnloop_session, []}` on
      `Cairnloop.Router.cairnloop_dashboard/2`, Phoenix invokes it with the live `conn` for each
      request that establishes the dashboard live session.

  This example has no login screen, so `fetch_current_operator/2` falls back to a demo operator
  when the session carries none. That keeps the example runnable while still exercising the
  *dynamic* MFA seam — swap the fallback for a real auth lookup and nothing else changes.

  See the "Auth & Operator Identity" guide in the Cairnloop docs for the full pattern.
  """

  import Plug.Conn

  # Stand-in for "the operator resolved from a real session". A production app loads this from its
  # users table; the example uses a fixed id so the seeded demo data lines up.
  @demo_operator_id "demo_operator"

  @doc """
  Plug that assigns the current operator to the connection.

  Reads an `"operator_id"` from the session (where a real login flow would have placed it) and
  assigns it as `:current_operator`, falling back to the demo operator when absent. Add this to the
  `:browser` pipeline so `current_operator` is available before the dashboard live session is built.
  """
  def fetch_current_operator(conn, _opts) do
    operator_id = get_session(conn, "operator_id") || @demo_operator_id
    assign(conn, :current_operator, operator_id)
  end

  @doc """
  Builds the Cairnloop dashboard live session for the current request.

  Returns the session map Cairnloop reads `host_user_id` from. Values are kept to JSON-friendly
  primitives (the operator id is already a string here; `to_string/1` your integer/UUID ids in a
  real app) because the live session is serialized across the websocket connect.
  """
  def cairnloop_session(conn) do
    %{"host_user_id" => to_string(conn.assigns.current_operator)}
  end
end
