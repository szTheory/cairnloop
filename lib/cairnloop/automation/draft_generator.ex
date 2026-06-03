defmodule Cairnloop.Automation.DraftGenerator do
  @moduledoc """
  Behaviour for the host-swappable reply-draft engine.

  A draft generator turns a retrieval **grounding bundle** (see
  `Cairnloop.Retrieval.ground_for_draft/2`) into a structured, operator-reviewable
  proposal. The host selects an implementation via application config:

      config :cairnloop, :draft_generator, Cairnloop.Automation.DraftGenerator.Anthropic

  The library default is `Cairnloop.Automation.ScoriaEngine` — a deterministic,
  zero-dependency engine that needs no API key and never calls out to a model. It is
  the fail-closed baseline: every implementation must honour the same contract so the
  rest of the pipeline (`DraftWorker` → policy → `Draft` record → operator approval)
  is unchanged.

  ## Contract

  `generate_draft/2` receives the conversation id and the grounding bundle and returns
  `{:ok, proposal}` where `proposal` is a map carrying **at least**:

    * `:proposal_type` — `:reply | :clarification | :escalation`
    * `:operator_summary` — calm, humanized one-liner explaining the decision
    * `:customer_reply` — the drafted reply text (the operator reviews before sending)
    * `:content` — mirrors `:customer_reply` (the `Draft` schema's required column)
    * `:evidence` — the serialized retrieval evidence the proposal is grounded in
    * `:grounding_metadata` — `%{grounding_status:, reason:, query:}` snapshotted at
      decision time (never re-read live at render)
    * `:clarification_attempts` — non-negative integer
    * `:conversation_id` — the conversation the draft belongs to

  ## Trust posture (carried decisions)

  Implementations MUST stay fail-closed: only compose a customer-facing reply when the
  bundle's `grounding_assessment.status` is `:strong`. For `:clarification` / `:escalation`
  the engine asks for the missing detail or recommends a human handoff — it never lets a
  model guess past the available grounding. Drafts are always human-in-the-loop: the
  proposal lands as a `:pending` `Draft` an operator must approve. Returning anything other
  than `{:ok, proposal}` causes `DraftWorker` to skip drafting (no partial/ungrounded send).
  """

  @callback generate_draft(conversation_id :: String.t(), grounding_bundle :: map()) ::
              {:ok, proposal :: map()} | {:error, term()}
end
