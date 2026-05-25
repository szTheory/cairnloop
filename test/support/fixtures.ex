defmodule Cairnloop.Fixtures do
  @moduledoc """
  Plain builder functions that persist real rows through `Cairnloop.Repo` for the
  integration suite. Matches the repo's inline-fixture idiom (no ex_machina).
  Test-only (`elixirc_paths(:test)`).
  """
  alias Cairnloop.Repo
  alias Cairnloop.Conversation
  alias Cairnloop.Governance.{ToolApproval, ToolProposal}
  alias Cairnloop.Message

  def conversation_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    {:ok, conversation} =
      %Conversation{}
      |> Conversation.changeset(
        Map.merge(
          %{status: :open, subject: "Integration conversation", host_user_id: "test_operator"},
          attrs
        )
      )
      |> Repo.insert()

    conversation
  end

  def proposal_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    defaults = %{
      tool_ref: "Cairnloop.Test.UnknownTool",
      idempotency_key: "idem-#{System.unique_integer([:positive])}",
      status: :proposed,
      risk_tier: :low_write,
      approval_mode: :requires_approval,
      actor_id: "operator_1",
      input_snapshot: %{},
      scope_snapshot: %{scopes: []},
      policy_snapshot: %{}
    }

    {:ok, proposal} =
      %ToolProposal{}
      |> ToolProposal.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    proposal
  end

  def approval_fixture(proposal, attrs \\ %{}) do
    attrs = Map.new(attrs)

    {:ok, approval} =
      %ToolApproval{}
      |> ToolApproval.changeset(Map.merge(%{tool_proposal_id: proposal.id, status: :pending}, attrs))
      |> Repo.insert()

    approval
  end

  @doc """
  Inserts a `Cairnloop.Message` row directly via `Repo`.

  Default role is `"internal_note"` (the governed-write role added in Phase 16).
  Pass `run_key:` to set the idempotency key column (nil by default = no idempotency check).

  # REPO-UNAVAILABLE — requires a Postgres round-trip; only runs under `mix test.integration`.
  """
  def message_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)

    defaults = %{
      content: "Test internal note",
      role: :internal_note,
      run_key: nil,
      metadata: %{}
    }

    {:ok, message} =
      %Message{}
      |> Message.changeset(Map.merge(defaults, attrs))
      |> Repo.insert()

    message
  end
end
