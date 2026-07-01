defmodule Cairnloop.Integration.PublicSchemaCompatibilityTest do
  @moduledoc """
  DB-backed Phase 59 proof for explicit public-schema compatibility.

  This file is intended to run under:

      CAIRNLOOP_SCHEMA_PREFIX=public MIX_ENV=test mix do clean, compile --force --warnings-as-errors, test --include integration test/integration/public_schema_compatibility_test.exs --warnings-as-errors

  The compile-time assertion below prevents runtime-only `Application.put_env/3`
  from pretending to prove public compatibility after schemas were compiled for
  the dedicated prefix.
  """
  use Cairnloop.DataCase, async: true

  @compiled_schema_prefix Application.compile_env(:cairnloop, :schema_prefix, "cairnloop")

  unless @compiled_schema_prefix == "public" do
    @moduletag skip:
                 "requires CAIRNLOOP_SCHEMA_PREFIX=public compile mode; run the explicit public compatibility command"
  end

  @public_tables [
    "cairnloop_conversations",
    "cairnloop_messages",
    "cairnloop_drafts",
    "cairnloop_articles",
    "cairnloop_revisions",
    "cairnloop_chunks",
    "cairnloop_tool_proposals",
    "cairnloop_tool_approvals",
    "cairnloop_mcp_tokens",
    "cairnloop_outbound_bulk_envelopes"
  ]

  describe "DB-02/DB-06 explicit public compatibility" do
    test "the test module was compiled in explicit public compatibility mode" do
      assert @compiled_schema_prefix == "public",
             "Expected public compatibility compile mode via CAIRNLOOP_SCHEMA_PREFIX=public, got #{inspect(@compiled_schema_prefix)}"

      assert Application.get_env(:cairnloop, :schema_prefix) == "public"
      assert Cairnloop.SchemaPrefix.configured() == "public"

      assert Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks") ==
               ~s("public"."cairnloop_chunks")
    end

    test "public compatibility has real public support-domain tables" do
      present = tables_in_schema("public", @public_tables)
      missing = @public_tables -- present

      assert missing == [],
             "Expected DB-02 public compatibility tables in table_schema=public, missing: #{inspect(missing)}"
    end

    test "legacy nil compatibility remains a separate supported mode" do
      assert Cairnloop.SchemaPrefix.configured(schema_prefix: nil) == nil
      assert Cairnloop.SchemaPrefix.configured(schema_prefix: "") == nil

      assert Cairnloop.SchemaPrefix.quoted_table("cairnloop_chunks", schema_prefix: nil) ==
               ~s("cairnloop_chunks")
    end

    test "Oban remains host-owned in public compatibility mode" do
      assert "oban_jobs" in tables_in_schema("public", ["oban_jobs"])
      refute "oban_jobs" in tables_in_schema("cairnloop", ["oban_jobs"])
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
end
