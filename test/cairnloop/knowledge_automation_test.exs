defmodule Cairnloop.KnowledgeAutomationTest do
  use ExUnit.Case, async: false

  alias Cairnloop.KnowledgeAutomation
  alias Cairnloop.KnowledgeAutomation.{ArticleSuggestion, GapCandidate}

  defmodule MockRepo do
    def one!(%Ecto.Query{}) do
      case Process.get(:gap_lookup) do
        :raise -> raise Ecto.NoResultsError, queryable: GapCandidate
        record -> record
      end
    end

    def preload(record, _associations) do
      record
    end

    def update(changeset) do
      applied = Ecto.Changeset.apply_changes(changeset)
      send(self(), {:updated, applied, changeset.changes})
      {:ok, applied}
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
    end)

    :ok
  end

  describe "get_gap_candidate/2" do
    test "returns nil when the underlying get_gap_candidate!/2 raises Ecto.NoResultsError" do
      Process.put(:gap_lookup, :raise)
      assert KnowledgeAutomation.get_gap_candidate(999, []) == nil
    end
  end

  describe "ArticleSuggestion.manual_edit_changeset/2" do
    test "casts only :manual_edit_opened_at and produces a valid changeset" do
      suggestion = %ArticleSuggestion{id: 15, manual_edit_opened_at: nil}
      ts = ~U[2026-05-28 12:00:00.000000Z]

      changeset = ArticleSuggestion.manual_edit_changeset(suggestion, ts)

      assert changeset.valid?
      assert changeset.changes == %{manual_edit_opened_at: ts}
    end

    test "overwrites an existing manual_edit_opened_at (refresh-to-latest idempotency)" do
      older_ts = ~U[2026-05-27 10:00:00.000000Z]
      newer_ts = ~U[2026-05-28 12:00:00.000000Z]
      suggestion = %ArticleSuggestion{id: 15, manual_edit_opened_at: older_ts}

      changeset = ArticleSuggestion.manual_edit_changeset(suggestion, newer_ts)

      assert changeset.valid?
      assert changeset.changes == %{manual_edit_opened_at: newer_ts}
    end
  end

  describe "record_editor_handoff/2" do
    test "writes the now_fn timestamp via manual_edit_changeset and returns {:ok, suggestion}" do
      # Set up MockRepo.one!/1 to return a fixture suggestion (get_article_suggestion! uses one!)
      pinned_ts = ~U[2026-05-28 12:00:00.000000Z]
      fixture = %ArticleSuggestion{id: 15, manual_edit_opened_at: nil}
      Process.put(:gap_lookup, fixture)

      result =
        KnowledgeAutomation.record_editor_handoff(15, now_fn: fn -> pinned_ts end)

      assert {:ok, applied} = result
      assert applied.manual_edit_opened_at == pinned_ts

      assert_received {:updated, _applied, changes}
      assert changes.manual_edit_opened_at == pinned_ts
    end

    # REPO-UNAVAILABLE: Live Postgres round-trip (actual DB write + re-read) requires a running
    # database. The changeset-write path above proves the functional contract; the Postgres write
    # itself is proven by the integration harness (MIX_ENV=test mix test.integration) once
    # Cairnloop.Repo is available.
  end
end
