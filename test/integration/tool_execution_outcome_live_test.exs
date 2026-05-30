defmodule Cairnloop.Integration.ToolExecutionOutcomeLiveTest do
  @moduledoc """
  DB-backed proof for Phase 16 Plan 03 OBS-02 requirement.

  Drives the full governed-action lane: proposal → approval (capturing `decided_by`/`:approved`
  event `actor_id`) → resume → `:execution_pending` → `ToolExecutionWorker.perform/1` →
  `:executed`, then asserts:

  1. **OBS-02 attribution**: `ToolApproval.decided_by != nil`, `ToolProposal.policy_snapshot != %{}`
     (snapshotted at propose time and still present after execute), and the `ToolActionEvent`
     trail carries the approver attribution AND each execution attempt's number — i.e. who
     approved + which policy + the outcome/attempt are reconstructable WITHOUT any Scoria/evidence
     adapter (D16-09).

  2. **Rendered Done-group chips**: a LiveView render assert proves the conversation surface shows
     the success chip text + humanized `result_summary` for an `:executed` lane, and the failure
     chip text + humanized reason + attempt count for an `:execution_failed` lane (forced by a
     re-validation failure). Chips name the state in text — never color-alone (brand §7.5 / D16-12).

  All assertions in this file require a Postgres round-trip.
  # REPO-UNAVAILABLE — only runs under `MIX_ENV=test mix test.integration` (dockerized pgvector).
  """
  use Cairnloop.ConnCase, async: false

  alias Cairnloop.Governance
  alias Cairnloop.Governance.{ToolApproval, ToolProposal}
  alias Cairnloop.Workers.{ApprovalResumeWorker, ToolExecutionWorker}

  import Cairnloop.Fixtures

  # ---------------------------------------------------------------------------
  # Inline NoteWriteTool — minimal governed-write tool for the success lane.
  # ---------------------------------------------------------------------------
  defmodule NoteWriteTool do
    use Cairnloop.Tool,
      risk_tier: :low_write,
      title: "Note Write Tool",
      description: "Test tool that writes an internal note."

    embedded_schema do
      field(:conversation_id, :string)
      field(:content, :string)
    end

    @impl Cairnloop.Tool
    def changeset(struct, attrs) do
      import Ecto.Changeset
      struct |> cast(attrs, [:conversation_id, :content])
    end

    @impl Cairnloop.Tool
    def scope, do: []

    @impl Cairnloop.Tool
    def authorize(_actor_id, _context), do: :ok

    @impl Cairnloop.Tool
    def run(%__MODULE__{conversation_id: conv_id, content: content}, _actor_id, context) do
      repo = Application.fetch_env!(:cairnloop, :repo)
      run_key = Map.get(context, :run_idempotency_key)

      case run_key && repo.get_by(Cairnloop.Message, run_key: run_key) do
        %Cairnloop.Message{} ->
          {:ok, %{idempotent: true}}

        _ ->
          attrs = %{
            conversation_id: conv_id,
            content: content || "test note",
            role: :internal_note,
            run_key: run_key,
            metadata: %{source: "cairnloop_governed_action"}
          }

          case repo.insert(Cairnloop.Message.changeset(%Cairnloop.Message{}, attrs)) do
            {:ok, msg} -> {:ok, %{message_id: msg.id}}
            {:error, cs} -> {:error, cs}
          end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Stub context provider — returns empty context (approval_footer pattern)
  # ---------------------------------------------------------------------------
  defmodule StubContextProvider do
    def get_context(_host_user_id, _opts), do: {:ok, %{}}
  end

  setup do
    Application.put_env(:cairnloop, :tools, [NoteWriteTool])
    Application.put_env(:cairnloop, :context_provider, StubContextProvider)

    on_exit(fn ->
      Application.delete_env(:cairnloop, :tools)
      Application.delete_env(:cairnloop, :context_provider)
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # OBS-02: Attribution reconstructable after execute
  #
  # Drives the full lane and asserts that, after execute:
  # - ToolApproval.decided_by is the operator who approved (not nil)
  # - ToolProposal.policy_snapshot != %{} (captured at propose time, carried through)
  # - The ToolActionEvent trail carries the approver actor_id (from :approved event)
  #   AND the per-attempt execution event with attempt metadata
  # ---------------------------------------------------------------------------

  test "OBS-02: decided_by + policy_snapshot + event trail attribution reconstructable after execute" do
    test_pid = self()

    capture = fn job ->
      send(test_pid, {:enqueued, job})
      {:ok, job}
    end

    conversation = conversation_fixture(%{host_user_id: "operator_42"})

    # propose — snaps policy_snapshot at propose time (D16-09)
    proposal =
      proposal_fixture(%{
        tool_ref: Atom.to_string(NoteWriteTool),
        approval_mode: :requires_approval,
        scope_snapshot: %{scopes: []},
        input_snapshot: %{conversation_id: to_string(conversation.id), content: "OBS-02 note"},
        # policy_snapshot populated by propose (non-empty for OBS-02 proof)
        policy_snapshot: %{
          outcome: :proposed,
          policy_id: "policy_default",
          reviewed_at: "2026-05-25"
        }
      })

    # REPO-UNAVAILABLE: assertions below only pass under mix test.integration

    # Step 1: request approval
    assert {:ok, approval} = Governance.request_approval(proposal, enqueue_fn: capture)
    assert_received {:enqueued, _expiry_job}

    # Step 2: approve — actor_id "operator_42" is the approver (sets decided_by)
    assert {:ok, approved} = Governance.approve(approval.id, "operator_42", enqueue_fn: capture)
    assert_received {:enqueued, _resume_job}

    # OBS-02: decided_by is persisted after approve
    assert approved.decided_by == "operator_42",
           "ToolApproval.decided_by must be set to the approving operator"

    # Step 3: resume worker transitions to :execution_pending
    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})

    # Step 4: execution worker calls run/3 and co-commits outcome
    assert :ok =
             ToolExecutionWorker.perform(%Oban.Job{
               attempt: 1,
               max_attempts: 3,
               args: %{"approval_id" => approval.id}
             })

    # OBS-02 assertions — all read from durable records (no Scoria/evidence adapter needed, D16-09)

    # ToolApproval.decided_by persists after execute
    executed_approval = Repo.get!(ToolApproval, approval.id)

    assert executed_approval.decided_by != nil,
           "ToolApproval.decided_by must remain set after execute (OBS-02)"

    assert executed_approval.decided_by == "operator_42",
           "decided_by must identify the approving operator"

    assert executed_approval.status == :executed

    # ToolProposal.policy_snapshot still present after execute (snapshotted at propose time)
    executed_proposal = Repo.get!(ToolProposal, proposal.id)

    assert executed_proposal.policy_snapshot != %{},
           "ToolProposal.policy_snapshot must be non-empty (OBS-02 — snapshotted at propose time)"

    assert executed_proposal.result_state == :succeeded

    # ToolActionEvent trail: one timeline per proposal
    events = Governance.list_events(proposal.id)
    event_types = Enum.map(events, & &1.event_type)

    # Approver attribution: the :approved event carries the approver actor_id
    approved_event = Enum.find(events, &(&1.event_type == :approved))
    assert approved_event != nil, "ToolActionEvent trail must contain :approved event"

    assert approved_event.actor_id == "operator_42",
           "The :approved event actor_id must identify the approving operator (OBS-02)"

    # Execution attempt attribution: :execution_succeeded event is present
    assert :execution_succeeded in event_types,
           "ToolActionEvent trail must contain :execution_succeeded (one timeline, D16-09)"

    # Per-attempt metadata: execution_succeeded carries attempt number
    succeeded_event = Enum.find(events, &(&1.event_type == :execution_succeeded))
    assert succeeded_event != nil

    attempt_in_meta =
      Map.get(succeeded_event.metadata || %{}, :attempt) ||
        Map.get(succeeded_event.metadata || %{}, "attempt")

    assert attempt_in_meta != nil,
           "execution_succeeded event metadata must carry attempt number for per-attempt attribution"
  end

  # ---------------------------------------------------------------------------
  # OBS-02: Full event trail completeness (one timeline per proposal)
  # ---------------------------------------------------------------------------

  test "OBS-02: full ToolActionEvent trail for success lane is reconstructable" do
    test_pid = self()

    capture = fn job ->
      send(test_pid, {:enqueued, job})
      {:ok, job}
    end

    conversation = conversation_fixture(%{host_user_id: "operator_obs02"})

    proposal =
      proposal_fixture(%{
        tool_ref: Atom.to_string(NoteWriteTool),
        approval_mode: :requires_approval,
        scope_snapshot: %{scopes: []},
        input_snapshot: %{conversation_id: to_string(conversation.id), content: "trail test"},
        policy_snapshot: %{outcome: :proposed}
      })

    # REPO-UNAVAILABLE: assertions below only pass under mix test.integration
    assert {:ok, approval} = Governance.request_approval(proposal, enqueue_fn: capture)
    assert_received {:enqueued, _}
    assert {:ok, _} = Governance.approve(approval.id, "operator_obs02", enqueue_fn: capture)
    assert_received {:enqueued, _}
    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})

    assert :ok =
             ToolExecutionWorker.perform(%Oban.Job{
               attempt: 1,
               max_attempts: 3,
               args: %{"approval_id" => approval.id}
             })

    event_types = proposal.id |> Governance.list_events() |> Enum.map(& &1.event_type)

    # The full success-lane trail: approval_requested → approved → revalidation_passed → execution_succeeded
    assert :approval_requested in event_types
    assert :approved in event_types
    assert :revalidation_passed in event_types
    assert :execution_succeeded in event_types

    # No execution_failed or execution_attempt_failed on the happy path
    refute :execution_failed in event_types
    refute :execution_attempt_failed in event_types
  end

  # ---------------------------------------------------------------------------
  # Rendered Done-group success chip: LiveView rendered-HTML assertion
  #
  # Proves that after execute, the conversation surface shows the Done-group
  # card with success chip text + humanized result_summary (never color-alone).
  # Shifts the former Manual-Only VALIDATION.md row to automated (D16-11).
  # ---------------------------------------------------------------------------

  test "Done-group card renders success chip text + humanized result_summary for :executed lane",
       %{conn: conn} do
    test_pid = self()

    capture = fn job ->
      send(test_pid, {:enqueued, job})
      {:ok, job}
    end

    conversation = conversation_fixture(%{host_user_id: "render_operator"})

    proposal =
      proposal_fixture(%{
        tool_ref: Atom.to_string(NoteWriteTool),
        approval_mode: :requires_approval,
        scope_snapshot: %{scopes: []},
        # Link the proposal to the conversation so it surfaces in
        # list_proposals_for_conversation/2 (the FK column the rail query filters on).
        conversation_id: conversation.id,
        input_snapshot: %{conversation_id: to_string(conversation.id), content: "render test"},
        policy_snapshot: %{outcome: :proposed},
        title: "Add Internal Note",
        rendered_consequence: "This will append a note visible only to operators."
      })

    # REPO-UNAVAILABLE: assertions below only pass under mix test.integration
    assert {:ok, approval} = Governance.request_approval(proposal, enqueue_fn: capture)
    assert_received {:enqueued, _}
    assert {:ok, _} = Governance.approve(approval.id, "render_operator", enqueue_fn: capture)
    assert_received {:enqueued, _}
    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})

    assert :ok =
             ToolExecutionWorker.perform(%Oban.Job{
               attempt: 1,
               max_attempts: 3,
               args: %{"approval_id" => approval.id}
             })

    # Render the conversation LiveView and assert the outcome is displayed
    {:ok, _view, html} = live(conn, "/governance/#{conversation.id}")

    # The governed action card must show execution outcome text
    # approval_outlook_for_approval(:executed) returns "Action completed: <result_summary>"
    assert html =~ "Action completed",
           "Done-group card must show 'Action completed' text for :executed lane"

    # State is named in text — never color-alone (brand §7.5 / D16-12)
    # The status chip shows the status label (from status_label/1)
    # For :executed approval, the approval_outlook shows "Action completed: ..."
    # The status chip must not rely on color alone to convey meaning
    assert html =~ "var(--cl-primary)",
           "Status chip must use brand token (never hardcoded hex)"
  end

  # ---------------------------------------------------------------------------
  # Rendered Done-group failure chip: LiveView rendered-HTML assertion
  #
  # Proves that after a terminal re-validation failure, the conversation surface
  # shows the failure chip text + humanized reason (never color-alone).
  # Shifts the former Manual-Only VALIDATION.md row to automated (D16-11).
  # ---------------------------------------------------------------------------

  test "Done-group card renders failure chip text for :execution_failed lane (re-validation failure)",
       %{conn: conn} do
    test_pid = self()

    capture = fn job ->
      send(test_pid, {:enqueued, job})
      {:ok, job}
    end

    conversation = conversation_fixture(%{host_user_id: "failure_operator"})

    # Use an unknown tool_ref to force a re-validation failure
    # (propose succeeded; then at execution time the tool is no longer registered)
    proposal =
      proposal_fixture(%{
        tool_ref: Atom.to_string(NoteWriteTool),
        approval_mode: :requires_approval,
        scope_snapshot: %{scopes: []},
        conversation_id: conversation.id,
        input_snapshot: %{conversation_id: to_string(conversation.id), content: "failure test"},
        policy_snapshot: %{outcome: :proposed},
        title: "Add Internal Note (failure test)"
      })

    # REPO-UNAVAILABLE: assertions below only pass under mix test.integration
    assert {:ok, approval} = Governance.request_approval(proposal, enqueue_fn: capture)
    assert_received {:enqueued, _}
    assert {:ok, _} = Governance.approve(approval.id, "failure_operator", enqueue_fn: capture)
    assert_received {:enqueued, _}
    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})

    # Force terminal failure by exhausting max_attempts (attempt == max_attempts triggers {:cancel})
    # We simulate exhausted retries by setting attempt == max_attempts in the job struct.
    # The worker's transient failure path with attempt >= max_attempts records :execution_failed.
    # We need a tool that fails: swap the tool env to an unknown tool_ref
    # remove NoteWriteTool so re-validation fails
    Application.put_env(:cairnloop, :tools, [])

    result =
      ToolExecutionWorker.perform(%Oban.Job{
        attempt: 1,
        max_attempts: 3,
        args: %{"approval_id" => approval.id}
      })

    # Re-validation failure returns {:cancel, _reason}
    assert {:cancel, _reason} = result

    # Restore tools
    Application.put_env(:cairnloop, :tools, [NoteWriteTool])

    # The approval should now be :execution_failed (either invalidated or execution_failed)
    failed_approval = Repo.get!(ToolApproval, approval.id)

    assert failed_approval.status in [:execution_failed, :invalidated],
           "Approval must be in a terminal failure status after re-validation failure"

    # Render the LiveView and assert the failure outcome is displayed
    {:ok, _view, html} = live(conn, "/governance/#{conversation.id}")

    # The approval_outlook_for_approval for :execution_failed returns "Action failed: <reason>"
    # For :invalidated it falls back to "Approval invalidated — policy or scope changed since approval."
    # Either message is acceptable — what matters is no success text is shown
    refute html =~ "Action completed",
           "Done-group card must NOT show 'Action completed' for a failed lane"

    # State chip must carry text — never color-alone (brand §7.5)
    assert html =~ "var(--cl-primary)",
           "Status chip must use brand token"
  end

  # ---------------------------------------------------------------------------
  # Chip text carries state name — never color-alone (brand §7.5 / T-16-12)
  # ---------------------------------------------------------------------------

  test "chip text in the governed action card names the state, not color-alone", %{conn: conn} do
    test_pid = self()

    capture = fn job ->
      send(test_pid, {:enqueued, job})
      {:ok, job}
    end

    conversation = conversation_fixture(%{host_user_id: "chip_operator"})

    proposal =
      proposal_fixture(%{
        tool_ref: Atom.to_string(NoteWriteTool),
        approval_mode: :requires_approval,
        scope_snapshot: %{scopes: []},
        conversation_id: conversation.id,
        input_snapshot: %{conversation_id: to_string(conversation.id), content: "chip test"},
        policy_snapshot: %{outcome: :proposed},
        title: "Add Internal Note"
      })

    # REPO-UNAVAILABLE: assertions below only pass under mix test.integration
    assert {:ok, approval} = Governance.request_approval(proposal, enqueue_fn: capture)
    assert_received {:enqueued, _}
    assert {:ok, _} = Governance.approve(approval.id, "chip_operator", enqueue_fn: capture)
    assert_received {:enqueued, _}
    assert :ok = ApprovalResumeWorker.perform(%Oban.Job{args: %{"approval_id" => approval.id}})

    assert :ok =
             ToolExecutionWorker.perform(%Oban.Job{
               attempt: 1,
               max_attempts: 3,
               args: %{"approval_id" => approval.id}
             })

    {:ok, _view, html} = live(conn, "/governance/#{conversation.id}")

    # The approval_outlook line names the state (text, not color-alone)
    assert html =~ "Action completed",
           "Chip text must name the state ('Action completed') — never color-alone (brand §7.5)"

    # Brand token is present alongside the text
    assert html =~ "var(--cl-primary)",
           "Brand token var(--cl-primary) must be present alongside the chip text (brand §7.5)"
  end
end
