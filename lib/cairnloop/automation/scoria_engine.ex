defmodule Cairnloop.Automation.ScoriaEngine do
  @moduledoc """
  Mock execution engine for Scoria integration.
  Generates simulated AI drafts for given conversations.
  """

  @doc """
  Generates a simulated draft for a given conversation.
  Returns `{:ok, proposal}` where proposal is a map containing the draft content.
  """
  def generate_draft(conversation_id) do
    proposal = %{
      content: "Simulated Scoria AI Draft",
      conversation_id: conversation_id
    }

    {:ok, proposal}
  end
end
