defmodule Cairnloop.AutomationPolicy do
  @moduledoc """
  Behaviour for providing host application AI policy boundaries.
  Allows host applications to dictate how AI drafts are handled.
  """

  @doc """
  Decides how a given AI proposal should be handled.
  Returns :allow, :draft_only, :require_approval, or :deny.
  """
  @callback decide(proposal :: map(), opts :: map()) ::
              :allow | :draft_only | :require_approval | :deny
end
