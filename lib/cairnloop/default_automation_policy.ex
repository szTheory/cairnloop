defmodule Cairnloop.DefaultAutomationPolicy do
  @moduledoc """
  Default implementation of Cairnloop.AutomationPolicy.
  Always returns :draft_only to ensure AI generated outputs are treated safely by default.
  """

  @behaviour Cairnloop.AutomationPolicy

  @impl true
  def decide(_proposal, _opts) do
    :draft_only
  end
end
