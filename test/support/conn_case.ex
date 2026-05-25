defmodule Cairnloop.ConnCase do
  @moduledoc """
  ExUnit case template for LiveView/conn integration tests. Builds a test conn pointed at
  `Cairnloop.Web.Endpoint`, checks out a sandbox connection (shared for `async: false` so
  the LiveView process can borrow it), and tags the module `:integration`.
  Test-only (`elixirc_paths(:test)`).
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :integration

      @endpoint Cairnloop.Web.Endpoint

      alias Cairnloop.Repo

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Cairnloop.DataCase, only: [errors_on: 1]
    end
  end

  setup tags do
    Cairnloop.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
