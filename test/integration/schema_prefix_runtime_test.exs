defmodule Cairnloop.Integration.SchemaPrefixRuntimeTest do
  @moduledoc """
  Runtime/collision coverage for Phase 59.

  The tests create or inspect misleading `public.cairnloop_*` objects while the
  configured prefix is `cairnloop`. Passing requires runtime facades, worker
  substrates, raw SQL checks, and doctor/readiness checks to use the configured
  support prefix instead of accidentally succeeding against public collisions.
  """
  use Cairnloop.DataCase, async: false

  defmodule GovernancePrefixProbeTool do
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "Governance Prefix Probe"

    embedded_schema do
      field(:target, :string)
    end

    @impl Cairnloop.Tool
    def changeset(struct, attrs) do
      struct
      |> Ecto.Changeset.cast(attrs, [:target])
      |> Ecto.Changeset.validate_required([:target])
    end

    @impl Cairnloop.Tool
    def run(_tool, _actor, _context), do: {:ok, %{}}

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok
  end

  describe "DB-05 runtime prefix coverage" do
    test "Chat writes to cairnloop even when a public conversation table exists" do
      ensure_public_conversation_collision!()
      before_public = count_public("cairnloop_conversations")

      assert {:ok, conversation} =
               Cairnloop.Chat.create_customer_conversation(%{
                 subject: "schema prefix collision probe",
                 customer_ref: "customer-runtime-prefix"
               })

      assert row_exists?("cairnloop", "cairnloop_conversations", conversation.id),
             "Expected Chat to write conversation #{conversation.id} into schema prefix cairnloop"

      assert count_public("cairnloop_conversations") == before_public,
             "Expected Chat runtime path to ignore public.cairnloop_conversations collision"
    end

    test "KnowledgeBase and Retrieval substrates are present in the configured prefix" do
      assert_tables_exist!("cairnloop", [
        "cairnloop_articles",
        "cairnloop_revisions",
        "cairnloop_chunks",
        "cairnloop_resolved_case_evidences",
        "cairnloop_resolved_case_chunks",
        "cairnloop_retrieval_gap_events"
      ])

      assert {:ok, "Healthy"} = Cairnloop.Retrieval.system_health()
    end

    test "Retrieval health ignores public chunk collisions while Oban stays host-owned" do
      ensure_public_chunk_collision!()

      assert table_exists?("public", "cairnloop_chunks")
      assert table_exists?("cairnloop", "cairnloop_chunks")
      assert {:ok, "Healthy"} = Cairnloop.Retrieval.system_health()

      assert table_exists?("public", "oban_jobs")
      refute table_exists?("cairnloop", "oban_jobs")
    end

    test "KnowledgeBase writes and reads use cairnloop despite public collisions" do
      ensure_public_knowledge_base_collisions!()
      before_public_articles = count_public("cairnloop_articles")

      assert {:ok, article} =
               Cairnloop.KnowledgeBase.create_article(%{
                 title: "dedicated KB runtime prefix probe"
               })

      assert row_exists?("cairnloop", "cairnloop_articles", article.id)
      assert count_public("cairnloop_articles") == before_public_articles

      insert_public_article_collision!(article.id)

      assert %{title: "dedicated KB runtime prefix probe"} =
               Cairnloop.KnowledgeBase.get_article(article.id)

      before_public_revisions = count_public("cairnloop_revisions")

      assert {:ok, revision} =
               Cairnloop.KnowledgeBase.save_draft(article, %{
                 content: "dedicated revision runtime prefix probe"
               })

      assert row_exists?("cairnloop", "cairnloop_revisions", revision.id)
      assert count_public("cairnloop_revisions") == before_public_revisions

      insert_public_revision_collision!(revision.id, article.id)

      assert %{content: "dedicated revision runtime prefix probe"} =
               Cairnloop.KnowledgeBase.get_revision(revision.id)
    end

    test "Governance, Outbound, and MCP runtime tables are present in the configured prefix" do
      assert_tables_exist!("cairnloop", [
        "cairnloop_tool_proposals",
        "cairnloop_tool_action_events",
        "cairnloop_tool_approvals",
        "cairnloop_mcp_tokens",
        "cairnloop_outbound_bulk_envelopes"
      ])

      assert {:ok, _token, _raw} = Cairnloop.MCP.issue_token(%{name: "runtime prefix probe"})
    end

    test "Governance and Outbound writes use cairnloop despite public collisions" do
      ensure_public_governance_outbound_collisions!()

      original_tools = Application.get_env(:cairnloop, :tools)
      Application.put_env(:cairnloop, :tools, [GovernancePrefixProbeTool])
      on_exit(fn -> restore_env(:tools, original_tools) end)

      before_public = %{
        proposals: count_public("cairnloop_tool_proposals"),
        events: count_public("cairnloop_tool_action_events"),
        approvals: count_public("cairnloop_tool_approvals"),
        messages: count_public("cairnloop_messages"),
        envelopes: count_public("cairnloop_outbound_bulk_envelopes")
      }

      before_cairnloop_events = count_table("cairnloop", "cairnloop_tool_action_events")

      assert {:ok, conversation} =
               Cairnloop.Chat.create_customer_conversation(%{
                 subject: "governance outbound schema prefix probe",
                 customer_ref: "customer-governance-outbound-prefix"
               })

      assert {:ok, proposal} =
               Cairnloop.Governance.propose(
                 Atom.to_string(GovernancePrefixProbeTool),
                 "actor-prefix",
                 %{
                   tool_params: %{target: "case-1"},
                   scopes: [],
                   idempotency_token: Ecto.UUID.generate(),
                   conversation_id: conversation.id
                 }
               )

      assert row_exists?("cairnloop", "cairnloop_tool_proposals", proposal.id)

      assert {:ok, approval} =
               Cairnloop.Governance.request_approval(proposal, enqueue_fn: fn _job -> :ok end)

      assert row_exists?("cairnloop", "cairnloop_tool_approvals", approval.id)

      assert count_table("cairnloop", "cairnloop_tool_action_events") >=
               before_cairnloop_events + 2

      assert {:ok, trigger_results} =
               Cairnloop.Outbound.trigger(conversation.id, template_id: "runtime_prefix")

      assert row_exists?("cairnloop", "cairnloop_messages", trigger_results.message.id)

      assert {:ok, bulk_results} =
               Cairnloop.Outbound.bulk_trigger([conversation.id],
                 template_id: "runtime_prefix_bulk",
                 rendered_body: "Runtime prefix probe",
                 actor: "actor-prefix"
               )

      assert uuid_row_exists?(
               "cairnloop",
               "cairnloop_outbound_bulk_envelopes",
               bulk_results.envelope.id
             )

      assert count_public("cairnloop_tool_proposals") == before_public.proposals
      assert count_public("cairnloop_tool_action_events") == before_public.events
      assert count_public("cairnloop_tool_approvals") == before_public.approvals
      assert count_public("cairnloop_messages") == before_public.messages
      assert count_public("cairnloop_outbound_bulk_envelopes") == before_public.envelopes

      assert table_exists?("public", "oban_jobs")
      refute table_exists?("cairnloop", "oban_jobs")
    end

    test "MCP token flows use cairnloop despite public token collisions" do
      ensure_public_mcp_token_collision!()
      before_public_tokens = count_public("cairnloop_mcp_tokens")

      assert {:ok, token, raw} =
               Cairnloop.MCP.issue_token(%{name: "dedicated MCP runtime prefix probe"})

      assert row_exists?("cairnloop", "cairnloop_mcp_tokens", token.id)
      assert count_public("cairnloop_mcp_tokens") == before_public_tokens

      public_token_id = Ecto.UUID.generate()
      insert_public_mcp_token_collision!(public_token_id, token.token_hash)

      assert {:ok, validated_token} = Cairnloop.MCP.validate_token(raw)
      assert validated_token.id == token.id

      active_token_ids = Cairnloop.MCP.list_active_tokens() |> Enum.map(& &1.id)
      assert token.id in active_token_ids
      refute public_token_id in active_token_ids

      assert {:ok, revoked_token} = Cairnloop.MCP.revoke_token(token)
      assert revoked_token.revoked_at

      assert mcp_token_revoked?("cairnloop", token.id)
      refute mcp_token_revoked?("public", public_token_id)
    end

    test "worker bulk-operation substrates are present in the configured prefix" do
      assert_tables_exist!("cairnloop", [
        "cairnloop_chunks",
        "cairnloop_resolved_case_chunks",
        "cairnloop_gap_candidates",
        "cairnloop_gap_candidate_memberships",
        "cairnloop_review_tasks",
        "cairnloop_review_task_events"
      ])
    end

    test "doctor/readiness checks report the configured prefix while Oban stays public" do
      assert_tables_exist!("public", ["oban_jobs"])
      refute table_exists?("cairnloop", "oban_jobs")

      findings = Cairnloop.Doctor.checks(nil, repo: Cairnloop.Repo)
      rendered = Enum.map_join(findings, "\n", fn {_level, message} -> message end)

      assert rendered =~ "cairnloop",
             "Expected doctor checks to name the configured schema prefix, got: #{rendered}"
    end
  end

  defp ensure_public_conversation_collision! do
    Repo.query!(
      """
      CREATE TABLE IF NOT EXISTS public.cairnloop_conversations (
        id bigserial PRIMARY KEY,
        status varchar(255) NOT NULL DEFAULT 'open',
        subject text,
        host_user_id varchar(255),
        customer_ref varchar(255),
        resolved_at timestamp(0),
        csat_rating varchar(255),
        inserted_at timestamp(0) NOT NULL DEFAULT now(),
        updated_at timestamp(0) NOT NULL DEFAULT now()
      )
      """,
      []
    )
  end

  defp ensure_public_knowledge_base_collisions! do
    Repo.query!(
      """
      CREATE TABLE IF NOT EXISTS public.cairnloop_articles (
        id bigserial PRIMARY KEY,
        title varchar(255) NOT NULL,
        status varchar(255) NOT NULL DEFAULT 'draft',
        inserted_at timestamp(0) NOT NULL DEFAULT now(),
        updated_at timestamp(0) NOT NULL DEFAULT now()
      )
      """,
      []
    )

    Repo.query!(
      """
      CREATE TABLE IF NOT EXISTS public.cairnloop_revisions (
        id bigserial PRIMARY KEY,
        article_id bigint NOT NULL,
        content text NOT NULL,
        version integer NOT NULL DEFAULT 1,
        state varchar(255) NOT NULL DEFAULT 'draft',
        inserted_at timestamp(0) NOT NULL DEFAULT now(),
        updated_at timestamp(0) NOT NULL DEFAULT now()
      )
      """,
      []
    )
  end

  defp ensure_public_chunk_collision! do
    Repo.query!(
      """
      CREATE TABLE IF NOT EXISTS public.cairnloop_chunks (
        id bigserial PRIMARY KEY
      )
      """,
      []
    )
  end

  defp ensure_public_mcp_token_collision! do
    Repo.query!(
      """
      CREATE TABLE IF NOT EXISTS public.cairnloop_mcp_tokens (
        id uuid PRIMARY KEY,
        name varchar(255) NOT NULL,
        token_hash bytea NOT NULL,
        expires_at timestamp(6),
        revoked_at timestamp(6),
        inserted_at timestamp(6) NOT NULL DEFAULT now(),
        updated_at timestamp(6) NOT NULL DEFAULT now()
      )
      """,
      []
    )
  end

  defp ensure_public_governance_outbound_collisions! do
    Repo.query!(
      """
      CREATE TABLE IF NOT EXISTS public.cairnloop_tool_proposals (
        id bigserial PRIMARY KEY
      )
      """,
      []
    )

    Repo.query!(
      """
      CREATE TABLE IF NOT EXISTS public.cairnloop_tool_action_events (
        id bigserial PRIMARY KEY
      )
      """,
      []
    )

    Repo.query!(
      """
      CREATE TABLE IF NOT EXISTS public.cairnloop_tool_approvals (
        id bigserial PRIMARY KEY
      )
      """,
      []
    )

    Repo.query!(
      """
      CREATE TABLE IF NOT EXISTS public.cairnloop_messages (
        id bigserial PRIMARY KEY
      )
      """,
      []
    )

    Repo.query!(
      """
      CREATE TABLE IF NOT EXISTS public.cairnloop_outbound_bulk_envelopes (
        id uuid PRIMARY KEY
      )
      """,
      []
    )
  end

  defp insert_public_article_collision!(id) do
    Repo.query!(
      """
      INSERT INTO public.cairnloop_articles (id, title, status, inserted_at, updated_at)
      VALUES ($1, 'public KB collision', 'published', now(), now())
      ON CONFLICT (id) DO UPDATE
      SET title = EXCLUDED.title,
          status = EXCLUDED.status,
          updated_at = now()
      """,
      [id]
    )
  end

  defp insert_public_revision_collision!(id, article_id) do
    Repo.query!(
      """
      INSERT INTO public.cairnloop_revisions
        (id, article_id, content, version, state, inserted_at, updated_at)
      VALUES ($1, $2, 'public revision collision', 99, 'published', now(), now())
      ON CONFLICT (id) DO UPDATE
      SET article_id = EXCLUDED.article_id,
          content = EXCLUDED.content,
          version = EXCLUDED.version,
          state = EXCLUDED.state,
          updated_at = now()
      """,
      [id, article_id]
    )
  end

  defp insert_public_mcp_token_collision!(id, token_hash) do
    Repo.query!(
      """
      INSERT INTO public.cairnloop_mcp_tokens
        (id, name, token_hash, revoked_at, inserted_at, updated_at)
      VALUES ($1::text::uuid, 'public MCP collision', $2::bytea, NULL, now(), now())
      ON CONFLICT (id) DO UPDATE
      SET name = EXCLUDED.name,
          token_hash = EXCLUDED.token_hash,
          revoked_at = NULL,
          updated_at = now()
      """,
      [id, token_hash]
    )
  end

  defp assert_tables_exist!(schema, table_names) do
    present =
      table_names
      |> Enum.filter(&table_exists?(schema, &1))
      |> Enum.sort()

    missing = Enum.sort(table_names) -- present

    assert missing == [],
           "Expected runtime schema prefix #{schema} to contain tables, missing: #{inspect(missing)}"
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

  defp row_exists?(schema, table, id) do
    qualified = Cairnloop.SchemaPrefix.quoted_table(table, schema_prefix: schema)

    id_expr = if is_binary(id), do: "id::text = $1", else: "id = $1"

    %{rows: [[count]]} =
      Repo.query!(
        "SELECT count(*) FROM #{qualified} WHERE #{id_expr}",
        [id]
      )

    count == 1
  end

  defp count_public(table) do
    count_table("public", table)
  end

  defp count_table(schema, table) do
    qualified = Cairnloop.SchemaPrefix.quoted_table(table, schema_prefix: schema)

    %{rows: [[count]]} =
      Repo.query!(
        "SELECT count(*) FROM #{qualified}",
        []
      )

    count
  end

  defp uuid_row_exists?(schema, table, id) do
    qualified = Cairnloop.SchemaPrefix.quoted_table(table, schema_prefix: schema)

    %{rows: [[count]]} =
      Repo.query!(
        "SELECT count(*) FROM #{qualified} WHERE id::text = $1",
        [id]
      )

    count == 1
  end

  defp mcp_token_revoked?(schema, id) do
    qualified = Cairnloop.SchemaPrefix.quoted_table("cairnloop_mcp_tokens", schema_prefix: schema)

    %{rows: rows} =
      Repo.query!(
        "SELECT revoked_at IS NOT NULL FROM #{qualified} WHERE id::text = $1",
        [id]
      )

    case rows do
      [[revoked?]] -> revoked?
      [] -> false
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:cairnloop, key)
  defp restore_env(key, value), do: Application.put_env(:cairnloop, key, value)
end
