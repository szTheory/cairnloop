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
    url = Application.get_env(:cairnloop, :scrypath_api_url, "https://api.scrypath.local/v1/search")
    req_opts = Application.get_env(:cairnloop, :scrypath_req_opts, [])
    
    context_used =
      case Req.get([url: url, params: [q: conversation_id]] ++ req_opts) do
        {:ok, %Req.Response{status: 200, body: body}} -> body
        _ -> nil
      end

    proposal = %{
      content: "Simulated Scoria AI Draft (grounded)",
      conversation_id: conversation_id,
      context_used: context_used
    }

    {:ok, proposal}
  end
end
