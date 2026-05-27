defmodule Cairnloop.Workers.OutboundWorker do
  @moduledoc """
  Oban worker that performs the per-recipient outbound delivery for a `system_outbound`
  message previously inserted by `Cairnloop.Outbound.trigger/2` (sealed, Phase 22/23).

  ## Job args shape (Phase 25 expanded — sealed-additive, WR-01)

  As of Phase 25, EVERY job enqueued by `Cairnloop.Outbound.trigger/2` (including
  Phase 24 single-recipient callers) carries the following args map:

      %{
        "message_id"       => integer(),       # carried over from Phase 22/23
        "conversation_id"  => integer(),       # ADDED in Phase 25 for dedup
        "template_id"      => binary(),        # ADDED in Phase 25 for dedup
        "bulk_envelope_id" => binary() | nil   # ADDED in Phase 25; `nil` for Phase 24 callers
      }

  This shape is **additively required** by D-11 — the three new keys form the Oban
  `unique:` dedup tuple (see "Idempotency" below). Pre-Phase-25 callers enqueued
  jobs with `args: %{"message_id" => id}` only; the new keys are now ALWAYS present,
  even on the Phase 24 single-conversation lane (`bulk_envelope_id` is `nil` there).

  **Host-side compatibility note.** A host with a custom Oban consumer (e.g., a
  bespoke retry policy, an `Oban.Telemetry` handler that introspects args, or a
  notifier that pattern-matches `args` strictly) will OBSERVE the new keys.
  Subset-matching patterns like `%{"message_id" => id} = args` still succeed (map
  pattern matching is subset-based). Hosts that treat the job args as an opaque
  pass-through are unaffected.

  ## Idempotency (Phase 25 D-11)

  Per-recipient at-most-once delivery is enforced at the Oban job-uniqueness layer:

      unique: [
        period: :infinity,
        fields: [:worker, :args],
        keys: [:conversation_id, :template_id, :bulk_envelope_id]
      ]

  This is the same `unique:` shape used by `Cairnloop.Workers.ApprovalResumeWorker` and
  `Cairnloop.Workers.ToolExecutionWorker`. The three keys form the dedup tuple:

  - `:conversation_id` — recipient identity.
  - `:template_id`     — the outbound template that was rendered.
  - `:bulk_envelope_id` — the `Cairnloop.Outbound.BulkEnvelope` correlation key
    for bulk fan-out (Phase 25). Phase 24 single-conversation callers (e.g.
    `ConversationLive`'s "Send recovery follow-up" handler) pass `nil` for this
    key — Oban treats `nil` as a valid dedup value, so two same-template
    Phase 24 recoveries for the same conversation in quick succession will be
    deduped. This is the documented desired behavior per D-11
    ("at-most-once delivery") and was a locked decision in Phase 25's
    research Open Question 2.

  ## Backwards compat (Phase 24)

  `perform/1` pattern-matches only on `"message_id"`. Phase 24 callers that do NOT
  include `"bulk_envelope_id"` (or `"conversation_id"` / `"template_id"`) in their job
  args still run successfully; the missing args are simply unused at perform time.
  The dedup keys are only consulted by Oban at INSERT time when constructing the
  uniqueness fingerprint — a Phase 24 caller that omits a key behaves identically to
  one that passes `nil`.
  """

  use Oban.Worker,
    queue: :default,
    unique: [period: :infinity, fields: [:worker, :args], keys: [:conversation_id, :template_id, :bulk_envelope_id]]

  alias Cairnloop.{Chat, Message}

  def perform(%Oban.Job{args: %{"message_id" => message_id}}) do
    repo = Application.fetch_env!(:cairnloop, :repo)
    message = repo.get!(Message, message_id)
    conversation = Chat.get_conversation!(message.conversation_id)

    case Application.get_env(:cairnloop, :notifier) do
      notifier when is_atom(notifier) and not is_nil(notifier) ->
        case notifier.on_outbound_triggered(message, conversation) do
          :ok ->
            update_message_status(message, "sent")

          {:ok, _} ->
            update_message_status(message, "sent")

          error ->
            update_message_status(message, "failed")
            {:error, error}
        end

      _ ->
        update_message_status(message, "sent")
        :ok
    end
  end

  defp update_message_status(message, status) do
    repo = Application.fetch_env!(:cairnloop, :repo)
    metadata = Map.put(message.metadata || %{}, "status", status)
    
    message
    |> Ecto.Changeset.change(%{metadata: metadata})
    |> repo.update()
  end
end
