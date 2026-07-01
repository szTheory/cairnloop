defmodule CairnloopExample.Tools.HighRiskDemoAction do
  @moduledoc """
  Example-only governed tool for showing an approval-required high-risk boundary.

  The tool is intentionally harmless: `run/3` records no external side effect and
  only returns a small demo result. It exists so the example app can display a
  higher-risk pending approval state without widening the Cairnloop library API.
  """

  use Cairnloop.Tool,
    risk_tier: :high_write,
    title: "High-risk demo action",
    description:
      "Shows an approval-required boundary state without performing a destructive side effect."

  embedded_schema do
    field(:conversation_id, :string)
    field(:reason, :string)
  end

  @impl Cairnloop.Tool
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:conversation_id, :reason])
    |> validate_required([:conversation_id, :reason])
    |> validate_length(:reason, min: 1, max: 500)
  end

  @impl Cairnloop.Tool
  def scope, do: []

  @impl Cairnloop.Tool
  def authorize(_actor_id, _context), do: :ok

  @impl Cairnloop.Tool
  def run(%__MODULE__{conversation_id: conversation_id, reason: reason}, _actor_id, _context) do
    {:ok, %{demo: true, conversation_id: conversation_id, reason: reason}}
  end
end
