defmodule CairnloopExample.RailFixtures do
  @moduledoc """
  Test fixtures for the evidence-rail browser E2E suite.

  Builds a conversation carrying a single PENDING governed action so `/support/:id` renders the
  full rail: the three Tier-2 `<details data-tier="2">` disclosure groups (Inputs & scope /
  History / Policy explanation), the Tier-3 "Identifiers & trace" group, and the Tier-1 safety
  quartet + Approve/Reject/Defer footer. Mirrors the seed `showcase_action_pending/0` exactly,
  but runs inside the caller's Ecto sandbox transaction (no committed seed dependency).
  """
  alias CairnloopExample.Repo
  alias Cairnloop.{Conversation, Governance, Message}

  @internal_note_ref Atom.to_string(Cairnloop.Tools.InternalNote)
  @operator "demo_operator"

  @doc """
  Inserts a conversation + two user messages + a pending internal-note governed action.
  Returns `%{conv_id: id, proposal_id: id}`.
  """
  def pending_governed_action_conversation(attrs \\ %{}) do
    conv =
      %Conversation{}
      |> Conversation.changeset(
        Map.merge(
          %{
            status: :open,
            subject: "[e2e] CI pipeline stuck — needs an internal escalation note",
            host_user_id: "e2e_operator"
          },
          attrs
        )
      )
      |> Repo.insert!()

    for content <- [
          "Our CI has skipped three runs in a row and I can't tell why.",
          "This is blocking a hotfix deploy — can someone take a closer look?"
        ] do
      %Message{}
      |> Message.changeset(%{
        role: :user,
        metadata: %{},
        conversation_id: conv.id,
        content: content
      })
      |> Repo.insert!()
    end

    {:ok, proposal} =
      Governance.propose(@internal_note_ref, @operator, %{
        conversation_id: to_string(conv.id),
        scopes: [],
        tool_params: %{
          conversation_id: to_string(conv.id),
          content: "Escalating to platform on-call: 3 consecutive skipped runs for umbrella."
        }
      })

    {:ok, _approval} = Governance.request_approval(proposal, enqueue_fn: fn _ -> :ok end)

    %{conv_id: conv.id, proposal_id: proposal.id}
  end

  @doc """
  Inserts an agent message into the conversation and broadcasts the same `:message_created`
  PubSub event the production reply path emits, forcing `ConversationLive` to
  `reload_conversation_with_context/2` and re-render the rail. Returns the message content.

  Used to prove a rail panel survives a real server-driven re-render (phx-update="ignore"),
  without going through the operator reply form (which depends on host-app schema the demo's
  own migrations may not carry).
  """
  def inject_message_and_broadcast(conv_id, content) do
    %Message{}
    |> Message.changeset(%{
      role: :agent,
      metadata: %{},
      conversation_id: conv_id,
      content: content
    })
    |> Repo.insert!()

    Phoenix.PubSub.broadcast(Cairnloop.PubSub, "conversation:#{conv_id}", {:message_created, nil})
    content
  end
end
