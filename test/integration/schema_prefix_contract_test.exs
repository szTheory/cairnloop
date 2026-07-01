defmodule Cairnloop.Integration.SchemaPrefixContractTest do
  @moduledoc """
  DB-backed Phase 59 contract tests for the dedicated `cairnloop` schema.

  These tests intentionally query Postgres catalogs with `table_schema`, `schemaname`,
  and namespace filters so stale `public.cairnloop_*` objects cannot satisfy the
  dedicated-schema contract.
  """
  use Cairnloop.DataCase, async: true

  @kb_retrieval_tables [
    "cairnloop_articles",
    "cairnloop_revisions",
    "cairnloop_chunks",
    "cairnloop_resolved_case_evidences",
    "cairnloop_resolved_case_chunks",
    "cairnloop_retrieval_gap_events",
    "cairnloop_gap_candidates",
    "cairnloop_gap_candidate_memberships",
    "cairnloop_article_suggestions"
  ]

  @governance_mcp_outbound_tables [
    "cairnloop_review_tasks",
    "cairnloop_review_task_events",
    "cairnloop_tool_proposals",
    "cairnloop_tool_action_events",
    "cairnloop_tool_approvals",
    "cairnloop_mcp_tokens",
    "cairnloop_outbound_bulk_envelopes"
  ]

  @dedicated_tables @kb_retrieval_tables ++ @governance_mcp_outbound_tables

  @expected_indexes [
    {"cairnloop_revisions", "cairnloop_revisions_article_id_index"},
    {"cairnloop_revisions", "cairnloop_revisions_state_index"},
    {"cairnloop_chunks", "cairnloop_chunks_revision_id_index"},
    {"cairnloop_chunks", "cairnloop_chunks_revision_id_chunk_index_index"},
    {"cairnloop_chunks", "cairnloop_chunks_search_vector_index"},
    {"cairnloop_retrieval_gap_events", "cairnloop_retrieval_gap_events_occurred_at_index"},
    {"cairnloop_gap_candidates", "cairnloop_gap_candidates_stable_key_index"},
    {"cairnloop_gap_candidate_memberships",
     "cairnloop_gap_candidate_memberships_source_unique_index"},
    {"cairnloop_article_suggestions", "cairnloop_article_suggestions_stable_key_index"},
    {"cairnloop_review_tasks", "cairnloop_review_tasks_status_inserted_at_index"},
    {"cairnloop_review_tasks", "cairnloop_review_tasks_article_suggestion_id_index"},
    {"cairnloop_review_tasks", "cairnloop_review_tasks_host_user_id_status_index"},
    {"cairnloop_review_tasks", "cairnloop_review_tasks_staged_article_id_index"},
    {"cairnloop_review_tasks", "cairnloop_review_tasks_staged_revision_id_index"},
    {"cairnloop_review_tasks", "cairnloop_review_tasks_published_revision_id_index"},
    {"cairnloop_review_tasks", "cairnloop_review_tasks_one_active_task_per_suggestion_index"},
    {"cairnloop_review_task_events",
     "cairnloop_review_task_events_review_task_id_inserted_at_index"},
    {"cairnloop_review_task_events", "cairnloop_review_task_events_event_type_inserted_at_index"},
    {"cairnloop_tool_proposals", "cairnloop_tool_proposals_idempotency_key_index"},
    {"cairnloop_tool_proposals", "cairnloop_tool_proposals_status_inserted_at_index"},
    {"cairnloop_tool_proposals", "cairnloop_tool_proposals_actor_id_status_index"},
    {"cairnloop_tool_proposals", "cairnloop_tool_proposals_tool_ref_inserted_at_index"},
    {"cairnloop_tool_proposals", "cairnloop_tool_proposals_conversation_id_inserted_at_index"},
    {"cairnloop_tool_action_events",
     "cairnloop_tool_action_events_tool_proposal_id_inserted_at_index"},
    {"cairnloop_tool_action_events", "cairnloop_tool_action_events_event_type_inserted_at_index"},
    {"cairnloop_tool_approvals", "cairnloop_tool_approvals_tool_proposal_id_status_index"},
    {"cairnloop_tool_approvals", "cairnloop_tool_approvals_status_expires_at_index"},
    {"cairnloop_tool_approvals", "cairnloop_tool_approvals_one_active_lane_index"},
    {"cairnloop_tool_approvals", "cairnloop_tool_approvals_execution_outcome_index"},
    {"cairnloop_mcp_tokens", "cairnloop_mcp_tokens_token_hash_index"},
    {"cairnloop_outbound_bulk_envelopes", "cairnloop_outbound_bulk_envelopes_requested_at_index"},
    {"cairnloop_outbound_bulk_envelopes", "cairnloop_outbound_bulk_envelopes_template_id_index"}
  ]

  @expected_foreign_keys [
    {"cairnloop_revisions", "cairnloop_articles"},
    {"cairnloop_chunks", "cairnloop_revisions"},
    {"cairnloop_resolved_case_evidences", "cairnloop_conversations"},
    {"cairnloop_resolved_case_chunks", "cairnloop_resolved_case_evidences"},
    {"cairnloop_gap_candidate_memberships", "cairnloop_gap_candidates"},
    {"cairnloop_article_suggestions", "cairnloop_articles"},
    {"cairnloop_article_suggestions", "cairnloop_revisions"},
    {"cairnloop_review_tasks", "cairnloop_article_suggestions"},
    {"cairnloop_review_tasks", "cairnloop_articles"},
    {"cairnloop_review_tasks", "cairnloop_revisions"},
    {"cairnloop_review_task_events", "cairnloop_review_tasks"},
    {"cairnloop_tool_proposals", "cairnloop_conversations"},
    {"cairnloop_tool_action_events", "cairnloop_tool_proposals"},
    {"cairnloop_tool_approvals", "cairnloop_tool_proposals"}
  ]

  @expected_trigger_functions [
    "cairnloop_chunks_search_vector_update",
    "cairnloop_resolved_case_chunks_search_vector_update"
  ]

  describe "DB-01/DB-03 dedicated schema object placement" do
    test "KB and retrieval-family tables exist in the cairnloop schema" do
      present = tables_in_schema("cairnloop", @kb_retrieval_tables)
      missing = @kb_retrieval_tables -- present

      assert missing == [],
             "Expected DB-03 KB/retrieval tables in table_schema=cairnloop, missing: #{inspect(missing)}"
    end

    test "governance, MCP, and outbound tables exist in the cairnloop schema" do
      present = tables_in_schema("cairnloop", @governance_mcp_outbound_tables)
      missing = @governance_mcp_outbound_tables -- present

      assert missing == [],
             "Expected DB-03 governance/MCP/outbound tables in table_schema=cairnloop, missing: #{inspect(missing)}"
    end

    test "same-name public tables do not satisfy the dedicated-schema contract" do
      locations = table_locations(@dedicated_tables)
      public_hits = Map.get(locations, "public", [])
      dedicated_hits = Map.get(locations, "cairnloop", [])

      assert Enum.sort(dedicated_hits) == Enum.sort(@dedicated_tables),
             "Expected every dedicated support table under table_schema=cairnloop, got: #{inspect(locations)}"

      assert public_hits == [],
             "Expected no public collision masking for dedicated mode, got public tables: #{inspect(public_hits)}"
    end

    test "indexes are created in the dedicated schema" do
      actual = indexes_in_schema("cairnloop")

      missing =
        Enum.reject(@expected_indexes, fn {table, index} ->
          MapSet.member?(actual, {table, index})
        end)

      assert missing == [],
             "Expected DB-03 indexes in schemaname=cairnloop, missing: #{inspect(missing)}"
    end

    test "foreign keys connect Cairnloop support tables inside the dedicated schema" do
      actual = foreign_key_pairs("cairnloop")

      missing =
        Enum.reject(@expected_foreign_keys, fn pair ->
          MapSet.member?(actual, pair)
        end)

      assert missing == [],
             "Expected DB-03 foreign keys with both table schemas=cairnloop, missing: #{inspect(missing)}"
    end

    test "trigger functions live in the dedicated schema" do
      actual = functions_in_schema("cairnloop", @expected_trigger_functions)
      missing = @expected_trigger_functions -- actual

      assert missing == [],
             "Expected DB-03 trigger functions in namespace cairnloop, missing: #{inspect(missing)}"
    end
  end

  defp tables_in_schema(schema, table_names) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = $1
          AND table_name = ANY($2::text[])
        ORDER BY table_name
        """,
        [schema, table_names]
      )

    Enum.map(rows, fn [table] -> table end)
  end

  defp table_locations(table_names) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema IN ('public', 'cairnloop')
          AND table_name = ANY($1::text[])
        ORDER BY table_schema, table_name
        """,
        [table_names]
      )

    rows
    |> Enum.group_by(fn [schema, _table] -> schema end, fn [_schema, table] -> table end)
  end

  defp indexes_in_schema(schema) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT tablename, indexname
        FROM pg_indexes
        WHERE schemaname = $1
        ORDER BY tablename, indexname
        """,
        [schema]
      )

    rows
    |> Enum.map(fn [table, index] -> {table, index} end)
    |> MapSet.new()
  end

  defp foreign_key_pairs(schema) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT source.relname, target.relname
        FROM pg_constraint constraint_row
        JOIN pg_class source ON source.oid = constraint_row.conrelid
        JOIN pg_namespace source_ns ON source_ns.oid = source.relnamespace
        JOIN pg_class target ON target.oid = constraint_row.confrelid
        JOIN pg_namespace target_ns ON target_ns.oid = target.relnamespace
        WHERE constraint_row.contype = 'f'
          AND source_ns.nspname = $1
          AND target_ns.nspname = $1
        ORDER BY source.relname, target.relname
        """,
        [schema]
      )

    rows
    |> Enum.map(fn [source, target] -> {source, target} end)
    |> MapSet.new()
  end

  defp functions_in_schema(schema, function_names) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT proc.proname
        FROM pg_proc proc
        JOIN pg_namespace ns ON ns.oid = proc.pronamespace
        WHERE ns.nspname = $1
          AND proc.proname = ANY($2::text[])
        ORDER BY proc.proname
        """,
        [schema, function_names]
      )

    Enum.map(rows, fn [name] -> name end)
  end
end
