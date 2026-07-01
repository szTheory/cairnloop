defmodule Cairnloop.Workers.ProcessMessage do
  @moduledoc """
  Oban worker that dispatches inbound messages to the correct handler by channel.

  ## Two-channel dispatch (Phase 28 D-07)

  The `perform/1` function uses two clauses, matched on the `"channel"` arg:

  - **`"widget"`** — delegates to `Cairnloop.Chat.ingest_widget_message/2`, which
    creates a `:user`-role Message row and broadcasts `{:message_created, message.id}`
    on `"conversation:\#{id}"` plus `{:conversations_changed}` on `"conversations"`.
    Follows the canonical "Worker → context facade → broadcast" pattern established by
    `Cairnloop.Automation.Workers.DraftWorker` (lines 101-114).

  - **`"email"`** — preserves the sealed unhandled-email stub from before Phase 28. The
    `Cairnloop.Ingress.EmailWebhookPlug` is a silent secondary caller that enqueues
    `ProcessMessage.new(%{channel: "email", content: content})`. The email branch must
    keep that arg shape working (Pitfall 2 / OQ-2). Full email-to-Conversation wiring
    is deferred to a future host-integration phase.

  ## Idempotency (D-07)

  The `unique:` option deduplicates jobs within a 30-second window for the same
  `(conversation_id, content)` pair. This guards against duplicate message inserts
  caused by channel-reconnect retry storms (Pitfall 5 partial mitigation).
  """

  use Oban.Worker,
    queue: :default,
    unique: [period: 30, fields: [:worker, :args], keys: [:conversation_id, :content]]

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"channel" => "widget", "conversation_id" => id, "content" => content}
      }) do
    # D-07: widget branch — delegate to Chat facade (ingest_widget_message/2 creates
    # the Message row and fires two PubSub broadcasts post-commit).
    # Does NOT call reply_to_conversation/4 — D-06 explicit prohibition (that function
    # triggers DraftWorker for :user role, which is wrong for raw customer ingress).
    # WR-02 fix: return {:cancel, reason} for permanent Ecto changeset failures.
    # Returning :error signals Oban to retry (up to 20x) — wrong for deterministic
    # changeset errors that will never succeed on retry. {:cancel, reason} marks
    # the job discarded immediately without exhausting retry budget.
    case Cairnloop.Chat.ingest_widget_message(id, content) do
      {:ok, _message} -> :ok
      {:error, changeset} -> {:cancel, "changeset error: #{inspect(changeset.errors)}"}
    end
  end

  def perform(%Oban.Job{args: %{"channel" => "email", "content" => _content}}) do
    # Pitfall 2 / OQ-2: email branch — sealed stub from before Phase 28.
    # Cairnloop.Ingress.EmailWebhookPlug (lib/cairnloop/ingress/email_webhook_plug.ex:18-20)
    # calls ProcessMessage.new(%{channel: "email", content: content}) — this clause exists
    # specifically to keep that secondary caller working under D-07's arg reshape.
    # Full email ingress wiring into a Conversation row is deferred to a future phase.
    Logger.warning(
      "Received email ingress message but no email conversation handler is configured"
    )

    :ok
  end
end
