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

    def insert(changeset) do
      applied = Ecto.Changeset.apply_changes(changeset)
      # mock id if needed
      applied = Map.put(applied, :id, 999)
      send(self(), {:inserted, applied, changeset.changes})
      {:ok, applied}
    end

    def all(_query) do
      []
    end

    def one(_query) do
      nil
    end
  end

  setup do
    Application.put_env(:cairnloop, :repo, MockRepo)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :repo)
    end)

    :ok
  end

  defmodule MockKB do
    def get_article("published_id"), do: %{id: "published_id", status: :published}
    def get_article("draft_id"), do: %{id: "draft_id", status: :draft}
    def get_article(_), do: nil

    def create_article(attrs) do
      send(self(), {:create_article, attrs})
      {:ok, %{id: "new_draft_id", status: :draft, title: attrs.title}}
    end
  end

  describe "create_or_reuse_authoring_article_for_suggestion/2 (SEC-01)" do
    test "Given a suggestion with a published authoring_article_id, it rejects reuse and safely creates a new draft article" do
      Process.put(:gap_lookup, %ArticleSuggestion{
        id: 1,
        suggestion_type: :article,
        title: "Test Suggestion",
        grounding_metadata: %{"authoring_article_id" => "published_id"}
      })

      result =
        KnowledgeAutomation.create_or_reuse_authoring_article_for_suggestion(1,
          knowledge_base_module: MockKB
        )

      assert {:ok, "new_draft_id"} = result
      assert_received {:create_article, %{status: :draft, title: "Test Suggestion"}}
      assert_received {:updated, _applied, changes}
      assert changes.grounding_metadata["authoring_article_id"] == "new_draft_id"
    end

    test "Given a suggestion with a valid draft authoring_article_id, it reuses the target" do
      Process.put(:gap_lookup, %ArticleSuggestion{
        id: 2,
        suggestion_type: :article,
        title: "Test Suggestion",
        grounding_metadata: %{"authoring_article_id" => "draft_id"}
      })

      assert {:ok, "draft_id"} =
               KnowledgeAutomation.create_or_reuse_authoring_article_for_suggestion(2,
                 knowledge_base_module: MockKB
               )
    end
  end

  defmodule MockRetrieval do
    def ground_for_draft(_params, _opts) do
      %{
        evidence: [
          %{
            source_type: :knowledge_base,
            trust_level: :canonical,
            content: "Mocked candidate evidence"
          }
        ],
        metadata: %{"hydrated" => true}
      }
    end
  end

  defmodule MockStaleSignal do
    def build_revision_gate(article_id, base_revision_id, opts) do
      # Track what opts were passed so we can assert on them
      send(self(), {:build_revision_gate, article_id, base_revision_id, opts})

      %{
        ready?: true,
        blocked_reason: nil,
        signal_count: 1,
        reason: :mock_reason,
        fresh_canonical_snapshot?: true
      }
    end
  end

  describe "suggest_article/2 (SEC-02)" do
    test "gap candidate suggestions disregard caller-supplied evidence and grounding_bundle" do
      candidate = %GapCandidate{
        id: 99,
        host_user_id: "host_1",
        title: "Gap Title",
        retrieval_gap_events: [],
        memberships: []
      }

      Process.put(:gap_lookup, candidate)

      attrs = %{
        gap_candidate_id: 99,
        title: "Caller Title",
        evidence: [%{source_type: :knowledge_base, trust_level: :canonical, content: "SPOOFED"}],
        evidence_snapshot: [
          %{source_type: :knowledge_base, trust_level: :canonical, content: "SPOOFED_SNAPSHOT"}
        ],
        grounding_metadata: %{"spoofed" => true}
      }

      opts = [
        enqueue_fn: fn _job -> {:ok, :job} end,
        retrieval_module: MockRetrieval,
        grounding_bundle: %{evidence: [%{content: "SPOOFED_BUNDLE"}], metadata: %{}}
      ]

      assert {:ok, _suggestion} = KnowledgeAutomation.suggest_article(attrs, opts)

      assert_received {:inserted, _applied, changes}

      # The caller title can be preserved or gap candidate title, but evidence MUST be from hydration
      snapshot = changes.evidence_snapshot
      assert length(snapshot) == 1
      assert Ecto.Changeset.get_field(hd(snapshot), :excerpt) == "Mocked candidate evidence"

      metadata = changes.grounding_metadata
      refute Map.has_key?(metadata, "spoofed")
    end
  end

  describe "suggest_revision/2 (SEC-03)" do
    test "ignores spoofed gap_events or grounding_bundle in opts" do
      # Mock the latest revision lookup
      opts = [
        enqueue_fn: fn _job -> {:ok, :job} end,
        retrieval_module: MockRetrieval,
        stale_article_signal_module: MockStaleSignal,
        latest_revision_fn: fn _id -> %{id: 10, article_id: "article_1"} end,
        # SPOOFED inputs!
        gap_events: [:SPOOFED_EVENT],
        grounding_bundle: %{evidence: [:SPOOFED_EVIDENCE]}
      ]

      attrs = %{article_id: "article_1"}

      assert {:ok, _suggestion} = KnowledgeAutomation.suggest_revision(attrs, opts)

      # Ensure build_revision_gate received the internally hydrated inputs, NOT the spoofed ones
      assert_received {:build_revision_gate, "article_1", 10, gate_opts}

      # gap_events from article_linked_gap_events/3 (which queries DB, empty since mock repo returns [])
      assert gate_opts[:gap_events] == []

      # grounding_bundle from fresh_revision_grounding_bundle
      bundle = gate_opts[:grounding_bundle]
      assert length(bundle.evidence) == 1
      assert hd(bundle.evidence).content == "Mocked candidate evidence"

      # Now check the inserted suggestion to ensure grounding came from the fresh bundle
      assert_received {:inserted, _applied, changes}
      snapshot = changes.evidence_snapshot
      assert length(snapshot) == 1
      assert Ecto.Changeset.get_field(hd(snapshot), :excerpt) == "Mocked candidate evidence"
    end
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
    test "writes the now_fn timestamp via manual_edit_changeset and returns {:ok, suggestion, iso_string}" do
      # Set up MockRepo.one!/1 to return a fixture suggestion (get_article_suggestion! uses one!)
      pinned_ts = ~U[2026-05-28 12:00:00.000000Z]
      fixture = %ArticleSuggestion{id: 15, manual_edit_opened_at: nil}
      Process.put(:gap_lookup, fixture)

      result =
        KnowledgeAutomation.record_editor_handoff(15, now_fn: fn -> pinned_ts end)

      assert {:ok, applied, opened_at_iso} = result
      assert applied.manual_edit_opened_at == pinned_ts
      assert opened_at_iso == DateTime.to_iso8601(pinned_ts)

      assert_received {:updated, _applied, changes}
      assert changes.manual_edit_opened_at == pinned_ts
    end

    # REPO-UNAVAILABLE: Live Postgres round-trip (actual DB write + re-read) requires a running
    # database. The changeset-write path above proves the functional contract; the Postgres write
    # itself is proven by the integration harness (MIX_ENV=test mix test.integration) once
    # Cairnloop.Repo is available.
  end
end
