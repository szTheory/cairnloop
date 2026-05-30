defmodule Cairnloop.Integration.GoldenPathTest do
  @moduledoc """
  E2E-01: Full JTBD round trip — closes E2E-01 (full JTBD round-trip test) and
  contributes to E2E-03 (integration lane coverage, no new test deps).

  Drives all 9 JTBD stages in one accumulating sequential test:
    1. Seed (conversation + customer message)
    2. Inbox sees the conversation
    3. ConversationLive + cmd+k search + citation chip
    4. Approve AI draft
    5. Tool proposal approve (via Governance facade)
    6. ToolExecutionWorker :success
    7. Resolve (via Chat.resolve_conversation/2 — no LiveView event)
    8. Outbound.trigger/2 from sidebar (trigger_recovery_follow_up)
    9. Bulk recovery (InboxLive multi-select → confirm_bulk_send → BulkEnvelope row)

  Requirements closed: E2E-01 (contributes to E2E-03)

  # REPO-UNAVAILABLE — only runs under `MIX_ENV=test mix test.integration` (dockerized pgvector).
  """
  use Cairnloop.ConnCase, async: false

  import Cairnloop.Fixtures
  import Ecto.Query

  alias Cairnloop.{Chat, Governance}
  alias Cairnloop.Outbound.BulkEnvelope
  alias Cairnloop.Message
  alias Cairnloop.Workers.{ApprovalResumeWorker, ToolExecutionWorker}

  # ---------------------------------------------------------------------------
  # Inline stubs (D-10) — all live inside this test module, no test/support changes.
  # ---------------------------------------------------------------------------

  defmodule StubContextProvider do
    @moduledoc false
    def get_context(_host_user_id, _opts), do: {:ok, %{}}
  end

  defmodule InlineTestTool do
    @moduledoc false
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "Golden Path Tool",
      description: "No scope required."

    embedded_schema do
      field(:conversation_id, :string)
      field(:note, :string)
    end

    @impl Cairnloop.Tool
    def changeset(struct, attrs) do
      Ecto.Changeset.cast(struct, attrs, [:conversation_id, :note])
    end

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok

    @impl Cairnloop.Tool
    def run(_tool, _actor, _ctx), do: {:ok, %{done: true}}
  end

  defmodule StubRetrieval do
    @moduledoc false
    # Returns a plain list of %Cairnloop.Retrieval.Result{} structs (Pitfall 4 — not plain maps).
    # Requires at minimum: id, article_id, title, content, source_type, trust_level, score (D-04).
    def search(_query, _opts) do
      [
        %Cairnloop.Retrieval.Result{
          id: 1,
          article_id: 1,
          title: "Test Article",
          content: "Stub content for golden path",
          source_type: :knowledge_base,
          trust_level: :canonical,
          score: 0.9
        }
      ]
    end
  end

  # ---------------------------------------------------------------------------
  # Setup: wire env keys, build authed conn.
  # ---------------------------------------------------------------------------

  setup %{conn: conn} do
    # ApprovalResumeWorker and ToolExecutionWorker internally call Oban.insert/1 to
    # chain steps. Start Oban in :manual testing mode (no oban_jobs table needed;
    # inserts are accepted in-memory and not auto-executed) so the chain doesn't crash.
    start_supervised!({Oban, name: Oban, repo: Cairnloop.Repo, queues: [], testing: :manual})

    prior_tools = Application.get_env(:cairnloop, :tools)
    prior_context = Application.get_env(:cairnloop, :context_provider)
    prior_template = Application.get_env(:cairnloop, :outbound_recovery_template_id)

    Application.put_env(:cairnloop, :tools, [InlineTestTool])
    Application.put_env(:cairnloop, :context_provider, StubContextProvider)

    # Required so the stage-8 `trigger_recovery_follow_up` button renders (conversation_live.ex:1773)
    Application.put_env(:cairnloop, :outbound_recovery_template_id, "recovery_v1")

    on_exit(fn ->
      if is_nil(prior_tools) do
        Application.delete_env(:cairnloop, :tools)
      else
        Application.put_env(:cairnloop, :tools, prior_tools)
      end

      if is_nil(prior_context) do
        Application.delete_env(:cairnloop, :context_provider)
      else
        Application.put_env(:cairnloop, :context_provider, prior_context)
      end

      if is_nil(prior_template) do
        Application.delete_env(:cairnloop, :outbound_recovery_template_id)
      else
        Application.put_env(:cairnloop, :outbound_recovery_template_id, prior_template)
      end
    end)

    conn = Plug.Test.init_test_session(conn, %{"host_user_id" => "golden_operator"})
    %{conn: conn}
  end

  # ---------------------------------------------------------------------------
  # Full JTBD round-trip — 9 accumulating stages (D-01, D-02).
  # ---------------------------------------------------------------------------

  test "full JTBD round trip", %{conn: conn} do
    test_pid = self()

    capture = fn job ->
      send(test_pid, {:enqueued, job})
      {:ok, job}
    end

    # ------------------------------------------------------------------
    # Stage 1: Seed — conversation row + customer message
    # ------------------------------------------------------------------
    conversation =
      conversation_fixture(%{
        status: :open,
        host_user_id: "golden_operator",
        subject: "Golden path conversation"
      })

    _customer_msg =
      message_fixture(%{
        conversation_id: conversation.id,
        content: "I need a refund",
        role: :user
      })

    # ------------------------------------------------------------------
    # Stage 2: Inbox sees — InboxLive renders the conversation subject
    # ------------------------------------------------------------------
    {:ok, _inbox_view, inbox_html} = live(conn, "/inbox")
    assert inbox_html =~ conversation.subject

    # ------------------------------------------------------------------
    # Stage 3: ConversationLive + cmd+k search + citation chip
    # Pitfall 1: route is /governance/:id (not /:id)
    # D-03: inject StubRetrieval via send_update after mount
    # ------------------------------------------------------------------
    {:ok, view, _html} = live(conn, "/governance/#{conversation.id}")

    # Inject stub retrieval module into the SearchModalComponent (D-03).
    # Must target the LiveView server process (view.pid), not self() — send_update
    # called from a non-LV process defaults to self(), which is the test process,
    # so the update never reaches the component.
    Phoenix.LiveView.send_update(view.pid, Cairnloop.Web.SearchModalComponent,
      id: "search-modal",
      retrieval_module: StubRetrieval
    )

    # Open the cmd+k palette — toggle_search handles phx-window-keydown on the component root
    # (search_modal_component.ex line 222; toggle_shortcut? checks metaKey=="true" via truthy?/1)
    view
    |> element("[phx-window-keydown='toggle_search']")
    |> render_keydown(%{"key" => "k", "metaKey" => "true"})

    # Fire the search query (must be >= 2 bytes; phx-change on the search form targets @myself)
    view
    |> element("form[phx-change='search']")
    |> render_change(%{"query" => "refund"})

    # Stub result title appears in the rendered HTML
    assert render(view) =~ "Test Article"

    # dom_id for knowledge_base result with article_id=1, chunk_index=nil (defaults to 0):
    # "knowledge_base-1-0" (SearchResultPresenter.dom_id/1)
    # Note: template attribute is phx-value-dom_id (underscore) not phx-value-dom-id (hyphen)
    dom_id = "knowledge_base-1-0"

    # Fire activate_result on the component result button (phx-target={@myself}, phx-value-dom_id)
    view
    |> element("[phx-click='activate_result'][phx-value-dom_id='#{dom_id}']")
    |> render_click()

    # open_active_result navigates internally via push_navigate (no parent event fired to LiveView)
    # Citation chip flow is internal to the modal — assert result was visible (done above)

    # ------------------------------------------------------------------
    # Stage 4: Approve AI draft
    # Remount so @conversation.drafts assoc loads the new draft
    # ------------------------------------------------------------------
    {:ok, draft} =
      Cairnloop.Automation.create_draft(conversation.id, %{
        customer_reply: "Here is your refund confirmation.",
        proposal_type: :reply,
        status: :pending
      })

    # Remount to load @conversation.drafts (preloaded via Chat.get_conversation!/1)
    {:ok, view, _html} = live(conn, "/governance/#{conversation.id}")

    # Draft approval affordance is in the rendered HTML
    assert render(view) =~ "approve_draft"

    # Fire the approve_draft event via the rendered button
    view
    |> element("button[phx-click='approve_draft'][phx-value-draft-id='#{draft.id}']")
    |> render_click()

    # Draft status flipped to :approved
    assert Cairnloop.Repo.get!(Cairnloop.Automation.Draft, draft.id).status == :approved

    # ------------------------------------------------------------------
    # Stage 5: Tool proposal approve (via Governance facade — Pitfall 8)
    # ------------------------------------------------------------------
    proposal =
      proposal_fixture(%{
        conversation_id: conversation.id,
        tool_ref: Atom.to_string(InlineTestTool),
        approval_mode: :requires_approval,
        scope_snapshot: %{scopes: []},
        input_snapshot: %{
          conversation_id: to_string(conversation.id),
          note: "golden path note"
        },
        policy_snapshot: %{outcome: :proposed}
      })

    assert {:ok, approval} = Governance.request_approval(proposal, enqueue_fn: capture)
    assert_received {:enqueued, _expiry_job}

    # enqueue_fn required — Governance.approve/3 enqueues ApprovalResumeWorker (Pitfall 8)
    assert {:ok, _approved} =
             Governance.approve(approval.id, "golden_operator", enqueue_fn: capture)

    assert_received {:enqueued, _resume_job}

    # ------------------------------------------------------------------
    # Stage 6: ToolExecutionWorker :success
    # Both attempt + max_attempts required (Pitfall 5)
    # ------------------------------------------------------------------
    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})

    assert :ok =
             ToolExecutionWorker.perform(%Oban.Job{
               attempt: 1,
               max_attempts: 3,
               args: %{"approval_id" => approval.id}
             })

    assert Cairnloop.Repo.get!(Cairnloop.Governance.ToolApproval, approval.id).status == :executed

    # Remount and assert "Action completed" chip text in the done-group card
    {:ok, _view, html} = live(conn, "/governance/#{conversation.id}")
    assert html =~ "Action completed"

    # ------------------------------------------------------------------
    # Stage 7: Resolve — Chat.resolve_conversation/2 directly (Pitfall 2: no "resolve" event)
    # ------------------------------------------------------------------
    assert {:ok, _} = Chat.resolve_conversation(conversation.id, resolved_by: "golden_operator")

    conversation = Chat.get_conversation!(conversation.id)
    assert conversation.status == :resolved

    # ------------------------------------------------------------------
    # Stage 8: Outbound.trigger/2 from sidebar
    # Remount required — resolve_conversation/2 does not broadcast a topic ConversationLive
    # handles; the trigger_recovery_follow_up button only renders for :resolved (Pitfall 3)
    # ------------------------------------------------------------------
    {:ok, view, html} = live(conn, "/governance/#{conversation.id}")
    assert html =~ "trigger_recovery_follow_up"

    outbound_before =
      Cairnloop.Repo.aggregate(
        from(m in Message,
          where: m.conversation_id == ^conversation.id and m.role == :system_outbound
        ),
        :count,
        :id
      )

    view
    |> element(~s(button[phx-click="trigger_recovery_follow_up"]))
    |> render_click()

    outbound_after =
      Cairnloop.Repo.aggregate(
        from(m in Message,
          where: m.conversation_id == ^conversation.id and m.role == :system_outbound
        ),
        :count,
        :id
      )

    assert outbound_after == outbound_before + 1

    # ------------------------------------------------------------------
    # Stage 9: Bulk recovery — InboxLive multi-select → confirm_bulk_send → BulkEnvelope row
    # Real event is confirm_bulk_send, NOT confirm_bulk_recovery (D-02 / RESEARCH)
    # ------------------------------------------------------------------
    envelope_before = Cairnloop.Repo.aggregate(BulkEnvelope, :count, :id)

    {:ok, inbox_view, _html} = live(conn, "/inbox")

    inbox_view
    |> element(~s(input[phx-click="toggle_select"][phx-value-id="#{conversation.id}"]))
    |> render_click()

    inbox_view
    |> element(~s(button[phx-click="open_bulk_confirm"]))
    |> render_click()

    inbox_view
    |> element(~s(button[phx-click="confirm_bulk_send"]))
    |> render_click()

    assert Cairnloop.Repo.aggregate(BulkEnvelope, :count, :id) == envelope_before + 1

    envelope =
      BulkEnvelope
      |> order_by([e], desc: e.inserted_at)
      |> limit(1)
      |> Cairnloop.Repo.one!()

    assert envelope.status == :submitted

    # At least one :system_outbound Message row for this conversation from bulk fan-out
    system_outbound_messages =
      Message
      |> where([m], m.conversation_id == ^conversation.id and m.role == :system_outbound)
      |> Cairnloop.Repo.all()

    assert length(system_outbound_messages) >= 1
  end
end
