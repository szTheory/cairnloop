defmodule Cairnloop.Tool do
  @moduledoc """
  Behaviour for defining an actionable tool in Cairnloop.

  Tools are independent modules that provide a specific action, potentially with
  inputs defined via Ecto embedded schemas.
  """

  @type actor_id :: String.t()
  @type context :: map()

  @doc """
  Determines if the given actor is authorized to execute this tool within
  the provided context.
  """
  @callback can_execute?(actor_id(), context()) :: boolean()

  @doc """
  Executes the tool logic with the populated struct.
  Returns `{:ok, result}` or `{:error, reason}`.
  """
  @callback execute(tool :: struct(), actor_id(), context()) :: {:ok, any()} | {:error, any()}

  @doc """
  Returns an Ecto changeset for the tool's inputs.
  """
  @callback changeset(tool :: struct(), attrs :: map()) :: Ecto.Changeset.t()

  @doc """
  Optional callback to provide a custom UI module (e.g. a LiveView module)
  that should be rendered instead of the auto-generated form.
  """
  @callback custom_ui() :: module() | nil

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      @behaviour Cairnloop.Tool

      @impl Cairnloop.Tool
      def custom_ui, do: nil

      defoverridable custom_ui: 0
    end
  end
end
