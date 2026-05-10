defmodule SupportOS.DefaultAutomationPolicy do
  @moduledoc """
  Default implementation of SupportOS.AutomationPolicy.
  Always returns :draft_only to ensure AI generated outputs are treated safely by default.
  """

  @behaviour SupportOS.AutomationPolicy

  @impl true
  def decide(_proposal, _opts) do
    :draft_only
  end
end
