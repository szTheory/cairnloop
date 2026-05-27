defmodule Cairnloop.Integration.OutboundBulkEnvelopesMigrationTest do
  @moduledoc """
  Integration coverage for Phase 25 human-verification item 1 (Plan 25-01 Task 4):
  proves the `AddOutboundBulkEnvelopes` migration applies cleanly under
  `mix test.integration` and produces the documented physical shape — 12 columns
  in the documented order, plus the two B-tree indexes that back OBS-02 queries
  ("show me bulk attempts ordered by time" / "show me bulk attempts for
  template X").

  This is a structural lock: any future migration that drops, renames, or
  reorders a column on `cairnloop_outbound_bulk_envelopes` will fail this test
  before it reaches an operator's host. The expected column list mirrors
  `lib/cairnloop/outbound/bulk_envelope.ex` and
  `priv/repo/migrations/20260527063000_add_outbound_bulk_envelopes.exs`.
  """
  use Cairnloop.DataCase, async: true

  describe "cairnloop_outbound_bulk_envelopes physical shape (D-15)" do
    test "table has the 12 documented columns in the documented order" do
      %{rows: rows} =
        Repo.query!(
          """
          SELECT column_name
          FROM information_schema.columns
          WHERE table_name = 'cairnloop_outbound_bulk_envelopes'
          ORDER BY ordinal_position
          """,
          []
        )

      column_names = Enum.map(rows, fn [name] -> name end)

      assert column_names == [
               "id",
               "template_id",
               "rendered_body",
               "recipient_conversation_ids",
               "count",
               "effective_cap",
               "requested_by",
               "requested_at",
               "status",
               "refused_reason",
               "inserted_at",
               "updated_at"
             ]
    end

    test "both OBS-02 indexes exist (requested_at + template_id)" do
      %{rows: rows} =
        Repo.query!(
          """
          SELECT indexname
          FROM pg_indexes
          WHERE tablename = 'cairnloop_outbound_bulk_envelopes'
          ORDER BY indexname
          """,
          []
        )

      index_names = Enum.map(rows, fn [name] -> name end)

      assert "cairnloop_outbound_bulk_envelopes_requested_at_index" in index_names
      assert "cairnloop_outbound_bulk_envelopes_template_id_index" in index_names
    end
  end
end
