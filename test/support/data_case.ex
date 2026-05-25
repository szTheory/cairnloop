defmodule Cairnloop.DataCase do
  @moduledoc """
  ExUnit case template for DB-backed integration tests.

  Checks out an `Ecto.Adapters.SQL.Sandbox` connection per test and injects the real
  `Cairnloop.Repo` as `:cairnloop, :repo`. Every module using this template is tagged
  `:integration`, so the fast headless suite (which excludes `:integration`) never runs it.
  Test-only (`elixirc_paths(:test)`).
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :integration

      alias Cairnloop.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Cairnloop.DataCase
    end
  end

  setup tags do
    Cairnloop.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Checks out a sandbox connection. `async: false` cases use a shared connection so
  spawned processes (e.g. a LiveView pid) can borrow it. Injects the real repo.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Cairnloop.Repo, shared: not tags[:async])
    Application.put_env(:cairnloop, :repo, Cairnloop.Repo)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  Translates changeset errors into a `%{field => [messages]}` map (standard Phoenix helper).
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
