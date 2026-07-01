defmodule CairnloopExample.SchemaPrefixContractTest do
  use CairnloopExample.DataCase, async: true

  @support_tables [
    "cairnloop_conversations",
    "cairnloop_messages",
    "cairnloop_drafts"
  ]

  test "example support tables live in the configured Cairnloop schema" do
    assert Application.fetch_env!(:cairnloop, :schema_prefix) == "cairnloop"

    present = tables_in_schema("cairnloop", @support_tables)
    missing = @support_tables -- present

    assert missing == [],
           "Expected example support tables in table_schema=cairnloop, missing: #{inspect(missing)}"

    public_hits = tables_in_schema("public", @support_tables)

    assert public_hits == [],
           "Expected example setup not to create public Cairnloop support tables, got: #{inspect(public_hits)}"
  end

  test "example run-key alteration is applied in the dedicated schema" do
    assert column_exists?("cairnloop", "cairnloop_messages", "run_key")
    refute column_exists?("public", "cairnloop_messages", "run_key")
  end

  test "example Oban table remains host-owned" do
    assert table_exists?("public", "oban_jobs")
    refute table_exists?("cairnloop", "oban_jobs")
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

  defp table_exists?(schema, table) do
    %{rows: [[count]]} =
      Repo.query!(
        """
        SELECT count(*)
        FROM information_schema.tables
        WHERE table_schema = $1
          AND table_name = $2
        """,
        [schema, table]
      )

    count == 1
  end

  defp column_exists?(schema, table, column) do
    %{rows: [[count]]} =
      Repo.query!(
        """
        SELECT count(*)
        FROM information_schema.columns
        WHERE table_schema = $1
          AND table_name = $2
          AND column_name = $3
        """,
        [schema, table, column]
      )

    count == 1
  end
end
