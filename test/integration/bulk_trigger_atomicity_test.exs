defmodule Cairnloop.Integration.BulkTriggerAtomicityTest do
  @moduledoc """
  Integration coverage for Phase 25 human-verification item 2(a): proves
  `Cairnloop.Outbound.bulk_trigger/2` is atomic under `Ecto.Multi` semantics.

  When any step in the merged transaction fails (envelope insert + per-recipient
  Message inserts + auditor step), the whole transaction rolls back — leaving
  zero `BulkEnvelope` rows and zero per-recipient `Message` rows behind. That
  guarantee is the load-bearing claim behind D-13 ("one durable audit row per
  bulk attempt"): a partial fan-out that left envelopes referring to
  half-inserted recipients would corrupt OBS-02 reads.

  We force the rollback by injecting a custom auditor that returns
  `{:error, :forced_rollback}` from its `Multi.run` step — cleaner than relying
  on a Postgrex FK raise (which depends on whether the changeset declared
  `foreign_key_constraint`).
  """
  use Cairnloop.DataCase, async: false

  alias Cairnloop.Outbound
  alias Cairnloop.Outbound.BulkEnvelope
  alias Cairnloop.Message

  import Cairnloop.Fixtures

  defmodule FailingAuditor do
    @impl true
    def list_events(_opts), do: []

    @behaviour Cairnloop.Auditor

    @impl true
    def audit(multi, _action, _actor, _metadata) do
      Ecto.Multi.run(multi, :forced_failure, fn _repo, _changes ->
        {:error, :forced_rollback}
      end)
    end
  end

  describe "bulk_trigger/2 atomicity (D-13 / Phase 25 UAT item 2(a))" do
    test "happy path: writes one BulkEnvelope + N system_outbound Message rows; envelope correlates each Message" do
      c1 = conversation_fixture(%{status: :resolved, subject: "Atomic happy 1"})
      c2 = conversation_fixture(%{status: :resolved, subject: "Atomic happy 2"})

      envelope_count_before = Repo.aggregate(BulkEnvelope, :count, :id)

      assert {:ok, _changes} =
               Outbound.bulk_trigger([c1.id, c2.id],
                 template_id: "recovery_v1",
                 rendered_body: "Atomic-test body"
               )

      assert Repo.aggregate(BulkEnvelope, :count, :id) == envelope_count_before + 1

      envelope =
        BulkEnvelope
        |> order_by([e], desc: e.inserted_at)
        |> limit(1)
        |> Repo.one!()

      assert envelope.count == 2
      assert envelope.status == :submitted
      assert envelope.recipient_conversation_ids == [c1.id, c2.id]
      assert envelope.template_id == "recovery_v1"
      assert envelope.rendered_body == "Atomic-test body"
      refute is_nil(envelope.effective_cap)

      # Every per-recipient Message carries the envelope correlation key (D-A).
      messages =
        Message
        |> where([m], m.conversation_id in ^[c1.id, c2.id] and m.role == :system_outbound)
        |> Repo.all()

      assert length(messages) == 2
      assert Enum.all?(messages, &(&1.metadata["bulk_envelope_id"] == envelope.id))
    end

    test "rollback path: a failing audit step rolls back BOTH the envelope AND the per-recipient Message rows" do
      c1 = conversation_fixture(%{status: :resolved, subject: "Atomic rollback 1"})
      c2 = conversation_fixture(%{status: :resolved, subject: "Atomic rollback 2"})

      envelope_count_before = Repo.aggregate(BulkEnvelope, :count, :id)
      message_count_before = Repo.aggregate(Message, :count, :id)

      # The auditor's failing Multi step returns {:error, :forced_rollback}.
      # Ecto.Multi treats this as transaction-wide failure: envelope + per-
      # recipient messages MUST be rolled back.
      assert {:error, :forced_failure, :forced_rollback, _changes_so_far} =
               Outbound.bulk_trigger([c1.id, c2.id],
                 template_id: "recovery_v1",
                 rendered_body: "Should not persist",
                 auditor: FailingAuditor
               )

      # Atomicity: zero net new envelope rows.
      assert Repo.aggregate(BulkEnvelope, :count, :id) == envelope_count_before

      # Atomicity: zero net new Message rows for these conversations.
      assert Repo.aggregate(Message, :count, :id) == message_count_before
    end
  end
end
