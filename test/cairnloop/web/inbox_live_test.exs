defmodule Cairnloop.Web.InboxLiveTest do
  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest

  alias Cairnloop.Web.InboxLive

  # ---------------------------------------------------------------------------
  # Existing Phase 22 test (search-modal scope plumbing). Stays green.
  # ---------------------------------------------------------------------------
  test "renders the inbox and mounts the search modal with explicit scope context" do
    assigns = %{
      host_user_id: "user_42",
      conversations: [
        %Cairnloop.Conversation{id: 7, subject: "Refund request", status: :open}
      ],
      selected_ids: MapSet.new(),
      bulk_modal_open: false,
      bulk_preview: nil,
      bulk_refusal: nil
    }

    html = render_html(assigns)

    assert html =~ "Inbox"
    assert html =~ "Refund request"
    assert html =~ "data-host-surface=\"inbox\""
    assert html =~ "data-host-user-id=\"user_42\""
    assert html =~ "data-current-path=\"/\""
  end

  # ---------------------------------------------------------------------------
  # Task 1 — selection state + sticky bottom bulk action bar (D-03, D-04, D-05).
  # ---------------------------------------------------------------------------

  describe "mount/3 (Task 1 — D-04 selection assign)" do
    defmodule EmptyRepo do
      # Stub Repo for the mount/3 test — `Chat.list_conversations/0` calls
      # `repo().all/1`; we return [] so the LiveView mount completes without
      # needing a real Postgres connection (D-16 REPO-UNAVAILABLE).
      def all(_query), do: []
    end

    test "Test 1: mount populates selected_ids with an empty MapSet" do
      prior = Application.get_env(:cairnloop, :repo)
      Application.put_env(:cairnloop, :repo, EmptyRepo)

      try do
        {:ok, socket} = InboxLive.mount(%{}, %{"host_user_id" => "u1"}, build_socket())
        assert socket.assigns.selected_ids == MapSet.new()
        assert socket.assigns.bulk_modal_open == false
        assert socket.assigns.bulk_preview == nil
        assert socket.assigns.bulk_refusal == nil
        assert socket.assigns.host_user_id == "u1"
        assert socket.assigns.conversations == []
      after
        if prior do
          Application.put_env(:cairnloop, :repo, prior)
        else
          Application.delete_env(:cairnloop, :repo)
        end
      end
    end
  end

  describe "handle_event toggle_select (Task 1 — D-03)" do
    test "Test 2: toggle_select adds an unselected id, removes a selected id" do
      socket = base_socket(selected_ids: MapSet.new())
      {:noreply, socket} = InboxLive.handle_event("toggle_select", %{"id" => "5"}, socket)
      assert MapSet.member?(socket.assigns.selected_ids, 5)

      {:noreply, socket} = InboxLive.handle_event("toggle_select", %{"id" => "5"}, socket)
      refute MapSet.member?(socket.assigns.selected_ids, 5)
    end
  end

  describe "checkbox visibility (Task 1 — D-01 / D-03)" do
    test "Test 3: only resolved rows render a checkbox; open rows have no checkbox" do
      assigns = build_assigns(
        conversations: [
          %Cairnloop.Conversation{id: 1, subject: "Resolved A", status: :resolved},
          %Cairnloop.Conversation{id: 2, subject: "Open B", status: :open}
        ]
      )

      html = render_html(assigns)

      assert html =~ ~s(phx-value-id="1")
      refute html =~ ~s(phx-value-id="2")
      # a11y label exists for the resolved row's checkbox
      assert html =~ "Select conversation:"
    end
  end

  describe "handle_event toggle_select_all_visible (Task 1 — D-03)" do
    test "Test 4a: selects all visible eligible ids when none are currently selected" do
      socket =
        base_socket(
          selected_ids: MapSet.new(),
          conversations: [
            %Cairnloop.Conversation{id: 1, status: :resolved},
            %Cairnloop.Conversation{id: 2, status: :resolved},
            %Cairnloop.Conversation{id: 3, status: :open}
          ]
        )

      {:noreply, socket} =
        InboxLive.handle_event("toggle_select_all_visible", %{}, socket)

      assert socket.assigns.selected_ids == MapSet.new([1, 2])
    end

    test "Test 4b: un-selects all visible eligible ids when all are already selected (toggle)" do
      socket =
        base_socket(
          selected_ids: MapSet.new([1, 2]),
          conversations: [
            %Cairnloop.Conversation{id: 1, status: :resolved},
            %Cairnloop.Conversation{id: 2, status: :resolved},
            %Cairnloop.Conversation{id: 3, status: :open}
          ]
        )

      {:noreply, socket} =
        InboxLive.handle_event("toggle_select_all_visible", %{}, socket)

      assert socket.assigns.selected_ids == MapSet.new()
    end
  end

  describe "handle_event clear_selection (Task 1)" do
    test "Test 5: clear_selection resets selected_ids without affecting other assigns" do
      socket =
        base_socket(
          selected_ids: MapSet.new([1, 2, 3]),
          host_user_id: "u_clear",
          bulk_modal_open: true
        )

      {:noreply, socket} = InboxLive.handle_event("clear_selection", %{}, socket)

      assert socket.assigns.selected_ids == MapSet.new()
      # Other assigns untouched
      assert socket.assigns.host_user_id == "u_clear"
      assert socket.assigns.bulk_modal_open == true
    end
  end

  describe "sticky bulk action bar (Task 1 — D-05, research OQ4)" do
    test "Test 6a: bar is absent when selection is empty" do
      assigns = build_assigns(selected_ids: MapSet.new())

      html = render_html(assigns)

      refute html =~ ~s(aria-label="Bulk actions")
    end

    test "Test 6b: bar is present when selection is non-empty" do
      assigns =
        build_assigns(
          selected_ids: MapSet.new([1, 2, 3]),
          conversations: [
            %Cairnloop.Conversation{id: 1, subject: "A", status: :resolved},
            %Cairnloop.Conversation{id: 2, subject: "B", status: :resolved},
            %Cairnloop.Conversation{id: 3, subject: "C", status: :resolved}
          ]
        )

      html = render_html(assigns)

      assert html =~ ~s(aria-label="Bulk actions")
    end

    test "Test 7: bar shows count, Clear selection, primary brand-token button" do
      assigns =
        build_assigns(
          selected_ids: MapSet.new([1, 2, 3]),
          conversations: [
            %Cairnloop.Conversation{id: 1, subject: "A", status: :resolved},
            %Cairnloop.Conversation{id: 2, subject: "B", status: :resolved},
            %Cairnloop.Conversation{id: 3, subject: "C", status: :resolved}
          ]
        )

      html = render_html(assigns)

      assert html =~ "3 selected"
      assert html =~ "Clear selection"
      assert html =~ "Send recovery follow-up to 3"
      # Brand token assertion (D-D)
      assert html =~ "var(--cl-primary"
    end

    test "Test 8: bar is bottom-anchored (position: sticky; bottom: 0)" do
      assigns =
        build_assigns(
          selected_ids: MapSet.new([1]),
          conversations: [
            %Cairnloop.Conversation{id: 1, subject: "A", status: :resolved}
          ]
        )

      html = render_html(assigns)

      assert html =~ "position: sticky"
      assert html =~ "bottom: 0"
    end
  end

  # ---------------------------------------------------------------------------
  # Task 2 — confirmation modal, refusal banner, bulk_trigger submit.
  # ---------------------------------------------------------------------------

  defmodule StubGovernance do
    @moduledoc """
    Deterministic Governance stub for Task 2 tests. Builds a preview map shaped
    exactly like Cairnloop.Governance.preview_bulk_recovery_cohort/1 returns.
    """
    def preview_bulk_recovery_cohort(ids) when is_list(ids) do
      sample =
        ids
        |> Enum.take(5)
        |> Enum.map(fn id -> "Conversation ##{id}" end)

      total = length(ids)
      more = max(total - 5, 0)

      %{
        eligible_ids: ids,
        sample: sample,
        more: more,
        total: total
      }
    end
  end

  defmodule StubOutbound do
    @moduledoc """
    Records bulk_trigger/2 calls via send(self_pid, …). Response is configurable via
    Process.put(:stub_outbound_response, …) so individual tests can pin :ok / :error.
    """
    def bulk_trigger(ids, opts) do
      pid = Process.get(:stub_outbound_test_pid)
      if pid, do: send(pid, {:bulk_trigger, ids, opts})

      case Process.get(:stub_outbound_response, :ok) do
        :ok ->
          {:ok, %{envelope: %{id: "stub-envelope-uuid"}}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  describe "open_bulk_confirm (Task 2 — D-07)" do
    setup do
      Application.put_env(:cairnloop, :outbound_module, StubOutbound)
      Application.put_env(:cairnloop, :governance_module, StubGovernance)
      Application.put_env(:cairnloop, :outbound_recovery_template_id, "recovery_v1")
      Process.put(:stub_outbound_test_pid, self())
      Process.put(:stub_outbound_response, :ok)

      on_exit(fn ->
        Application.delete_env(:cairnloop, :outbound_module)
        Application.delete_env(:cairnloop, :governance_module)
        Application.delete_env(:cairnloop, :outbound_recovery_template_id)
        Application.delete_env(:cairnloop, :max_batch_size)
        Process.delete(:stub_outbound_test_pid)
        Process.delete(:stub_outbound_response)
      end)

      :ok
    end

    test "Test 1: open_bulk_confirm populates bulk_preview with count, sample, rendered_body; no +N more for cohort of 3" do
      socket =
        base_socket(
          selected_ids: MapSet.new([1, 2, 3]),
          conversations: resolved_conversations([1, 2, 3])
        )

      {:noreply, socket} = InboxLive.handle_event("open_bulk_confirm", %{}, socket)

      assert socket.assigns.bulk_modal_open == true
      assert socket.assigns.bulk_refusal == nil
      preview = socket.assigns.bulk_preview
      assert preview.count == 3
      assert length(preview.sample) == 3
      assert preview.more == 0
      assert is_binary(preview.rendered_body)
      assert preview.template_id == "recovery_v1"

      html = render_html(socket.assigns)
      assert html =~ "aria-modal=\"true\""
      assert html =~ "3"
      assert html =~ preview.rendered_body
      assert html =~ "Conversation #1"
      refute html =~ "more"
    end

    test "Test 2: +N more renders as `+ 3 more` for a cohort of 8" do
      ids = Enum.to_list(1..8)

      socket =
        base_socket(
          selected_ids: MapSet.new(ids),
          conversations: resolved_conversations(ids)
        )

      {:noreply, socket} = InboxLive.handle_event("open_bulk_confirm", %{}, socket)

      assert socket.assigns.bulk_preview.more == 3
      html = render_html(socket.assigns)
      assert html =~ "+ 3 more"
    end

    test "Test 3: oversized cohort renders refusal banner with icon + danger token; Confirm send is disabled" do
      Application.put_env(:cairnloop, :max_batch_size, 3)
      on_exit(fn -> Application.delete_env(:cairnloop, :max_batch_size) end)

      ids = Enum.to_list(1..5)

      socket =
        base_socket(
          selected_ids: MapSet.new(ids),
          conversations: resolved_conversations(ids)
        )

      {:noreply, socket} = InboxLive.handle_event("open_bulk_confirm", %{}, socket)

      assert socket.assigns.bulk_modal_open == true
      assert socket.assigns.bulk_refusal != nil
      # bulk_trigger/2 MUST NOT have been called.
      refute_receive {:bulk_trigger, _, _}, 50

      html = render_html(socket.assigns)
      assert html =~ "This batch exceeds the safe send limit of 3"
      assert html =~ "<svg"
      assert html =~ "var(--cl-danger"
      # Confirm send is either absent or disabled.
      cond do
        String.contains?(html, "Confirm send") ->
          assert html =~ ~r/Confirm send[^<]*<[^>]*disabled/i or html =~ ~r/disabled[^>]*>[^<]*Confirm send/i

        true ->
          :ok
      end
    end

    test "Test 4: cancel_bulk_confirm closes modal and PRESERVES selected_ids (D-08, Pitfall 6)" do
      socket =
        base_socket(
          selected_ids: MapSet.new([1, 2, 3]),
          bulk_modal_open: true,
          bulk_preview: %{count: 3, sample: [], more: 0, rendered_body: "body", template_id: "t"}
        )

      {:noreply, socket} = InboxLive.handle_event("cancel_bulk_confirm", %{}, socket)

      assert socket.assigns.bulk_modal_open == false
      assert socket.assigns.bulk_preview == nil
      assert socket.assigns.bulk_refusal == nil
      # The critical regression assertion for Pitfall 6.
      assert socket.assigns.selected_ids == MapSet.new([1, 2, 3])

      html = render_html(socket.assigns)
      refute html =~ "aria-modal=\"true\""
    end

    test "Test 5: <.focus_wrap> markup is present when the modal is open (UI-03 accessibility)" do
      socket =
        base_socket(
          selected_ids: MapSet.new([1]),
          conversations: resolved_conversations([1])
        )

      {:noreply, socket} = InboxLive.handle_event("open_bulk_confirm", %{}, socket)

      html = render_html(socket.assigns)
      # Phoenix.Component.focus_wrap/1 always renders a wrapper with the
      # phx-hook="Phoenix.FocusWrap" attribute on a div whose id we supplied.
      assert html =~ "Phoenix.FocusWrap"
    end

    test "Test 6: confirm_bulk_send calls outbound_module().bulk_trigger/2 with snapshotted body + actor" do
      socket =
        base_socket(
          selected_ids: MapSet.new([1, 2]),
          host_user_id: "operator_u1",
          conversations: resolved_conversations([1, 2])
        )

      # Open modal first to populate the snapshot.
      {:noreply, socket} = InboxLive.handle_event("open_bulk_confirm", %{}, socket)
      snapshotted_body = socket.assigns.bulk_preview.rendered_body

      {:noreply, _socket} = InboxLive.handle_event("confirm_bulk_send", %{}, socket)

      assert_received {:bulk_trigger, ids, opts}
      assert ids == [1, 2]
      assert Keyword.fetch!(opts, :template_id) == "recovery_v1"
      assert Keyword.fetch!(opts, :rendered_body) == snapshotted_body
      assert Keyword.fetch!(opts, :actor) == "operator_u1"
    end

    test "Test 7: confirm with {:ok, _} sets info flash and resets selected_ids" do
      socket =
        base_socket(
          selected_ids: MapSet.new([1, 2]),
          conversations: resolved_conversations([1, 2])
        )

      {:noreply, socket} = InboxLive.handle_event("open_bulk_confirm", %{}, socket)
      {:noreply, socket} = InboxLive.handle_event("confirm_bulk_send", %{}, socket)

      assert socket.assigns.selected_ids == MapSet.new()
      assert socket.assigns.bulk_modal_open == false
      assert flash_value(socket, :info) =~ "Bulk recovery queued"
      assert flash_value(socket, :info) =~ "2"
    end

    test "Test 8: confirm with {:error, :batch_too_large} sets fail-closed flash and PRESERVES selected_ids (no raw Elixir terms)" do
      Process.put(:stub_outbound_response, {:error, :batch_too_large})

      socket =
        base_socket(
          selected_ids: MapSet.new([1, 2]),
          conversations: resolved_conversations([1, 2])
        )

      {:noreply, socket} = InboxLive.handle_event("open_bulk_confirm", %{}, socket)
      {:noreply, socket} = InboxLive.handle_event("confirm_bulk_send", %{}, socket)

      # selected_ids preserved so operator can narrow.
      assert socket.assigns.selected_ids == MapSet.new([1, 2])
      assert socket.assigns.bulk_modal_open == false
      msg = flash_value(socket, :error)
      assert msg =~ "exceeds the safe send limit"
      # No raw Elixir term leakage.
      refute msg =~ ":batch_too_large"
      refute msg =~ "{:error"
    end

    test "Test 9: confirm with template missing shows calm operator copy and does NOT call bulk_trigger/2" do
      Application.delete_env(:cairnloop, :outbound_recovery_template_id)

      socket =
        base_socket(
          selected_ids: MapSet.new([1, 2]),
          conversations: resolved_conversations([1, 2])
        )

      # open_bulk_confirm should still succeed (preview is independent of template config)
      # but confirm_bulk_send should refuse cleanly.
      {:noreply, socket} = InboxLive.handle_event("open_bulk_confirm", %{}, socket)
      {:noreply, socket} = InboxLive.handle_event("confirm_bulk_send", %{}, socket)

      refute_received {:bulk_trigger, _, _}
      assert flash_value(socket, :error) =~ "Recovery follow-up template is not configured"
      # selected_ids preserved (operator can fix config and retry).
      assert socket.assigns.selected_ids == MapSet.new([1, 2])
    end
  end

  # ---------------------------------------------------------------------------
  # D-14 invariant gate — no direct Ecto query in InboxLive.
  # ---------------------------------------------------------------------------

  describe "D-14 invariants (no direct Ecto from web layer)" do
    test "no `Conversation |> where` substring exists in lib/cairnloop/web/inbox_live.ex" do
      source = File.read!("lib/cairnloop/web/inbox_live.ex")
      refute source =~ "Conversation |> where"
    end

    test "no `inspect(` exists in InboxLive operator-visible strings" do
      source = File.read!("lib/cairnloop/web/inbox_live.ex")
      # Filter out comment lines before checking.
      non_comment =
        source
        |> String.split("\n")
        |> Enum.reject(&String.starts_with?(String.trim_leading(&1), "#"))
        |> Enum.join("\n")

      refute non_comment =~ "inspect("
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers.
  # ---------------------------------------------------------------------------

  defp render_html(assigns) do
    # Ensure the test-only assign defaults are present so renders don't crash if a
    # caller forgets to thread them through (matches the LiveView's mount/3 shape).
    assigns =
      assigns
      |> Map.put_new(:selected_ids, MapSet.new())
      |> Map.put_new(:bulk_modal_open, false)
      |> Map.put_new(:bulk_preview, nil)
      |> Map.put_new(:bulk_refusal, nil)
      |> Map.put_new(:host_user_id, nil)
      |> Map.put_new(:conversations, [])
      |> Map.put_new(:flash, %{})

    render_component(&InboxLive.render/1, assigns)
  end

  defp build_assigns(overrides) do
    base = %{
      host_user_id: "u_test",
      conversations: [],
      selected_ids: MapSet.new(),
      bulk_modal_open: false,
      bulk_preview: nil,
      bulk_refusal: nil,
      flash: %{}
    }

    Map.merge(base, Map.new(overrides))
  end

  defp build_socket do
    %Phoenix.LiveView.Socket{}
  end

  defp base_socket(overrides) do
    assigns =
      %{
        host_user_id: nil,
        conversations: [],
        selected_ids: MapSet.new(),
        bulk_modal_open: false,
        bulk_preview: nil,
        bulk_refusal: nil,
        flash: %{},
        __changed__: %{}
      }
      |> Map.merge(Map.new(overrides))

    %Phoenix.LiveView.Socket{assigns: assigns}
  end

  defp resolved_conversations(ids) do
    Enum.map(ids, fn id ->
      %Cairnloop.Conversation{id: id, subject: "Conversation ##{id}", status: :resolved}
    end)
  end

  defp flash_value(socket, key) do
    Map.get(socket.assigns.flash || %{}, to_string(key))
  end
end
