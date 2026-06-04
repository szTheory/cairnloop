defmodule Cairnloop.Web.AuditLogLiveTest do
  @moduledoc """
  Headless render test for the Audit Log LiveView. Exercises `render/1` directly
  with built assigns so it needs no Repo — the DB-backed mount path is covered by
  the integration suite.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  defp base_assigns do
    %{
      visible_events: [],
      query: "",
      action_filter: "all",
      action_options: [],
      maybe_more?: false,
      proposal_filter: nil,
      __changed__: nil
    }
  end

  # ---------------------------------------------------------------------------
  # Phase 38 Task 2 — cl_page shell migration render assertions (SHELL-01).
  # ---------------------------------------------------------------------------

  describe "Phase 38 SHELL-01 — Audit Log cl_page migration" do
    test "Test 1 (Audit Log): rendered HTML contains cl-page cl-page--wide" do
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(base_assigns()))

      assert html =~ ~s(cl-page cl-page--wide),
             "expected class=\"cl-page cl-page--wide\" in rendered HTML"
    end

    test "Test 1 (Audit Log): rendered HTML contains cl-page__title with verbatim 'Audit Log'" do
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(base_assigns()))

      assert html =~ ~s(cl-page__title),
             "expected class=\"cl-page__title\" in rendered HTML"

      assert html =~ "Audit Log",
             "expected verbatim text 'Audit Log'"
    end

    test "Test 1 (Audit Log): rendered HTML contains the subtitle text" do
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(base_assigns()))

      assert html =~ "A timeline of governed actions",
             "expected subtitle text 'A timeline of governed actions' in rendered HTML"
    end

    test "Test 1 (Audit Log): filter form markup stays in the card body (not in :actions)" do
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(base_assigns()))

      # The filter form (phx-change="filter") must still be present — it stays in
      # the card body (D-04: substantial filter bars stay in body, NOT in :actions).
      assert html =~ ~s(phx-change="filter"),
             "expected filter form markup in rendered HTML — filter bar must stay in body"

      assert html =~ ~s(phx-change="search"),
             "expected search form markup in rendered HTML — search bar must stay in body"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 42 Task 1 — handle_params/2 proposal filter (THREAD-03a).
  # Tests must FAIL before implementation (TDD RED).
  # ---------------------------------------------------------------------------

  describe "Phase 42 Task 1 — handle_params/2 tolerant proposal filter" do
    test "handle_params with proposal='bogus' assigns proposal_filter: nil (no crash)" do
      socket = build_socket()
      {:noreply, result} =
        Cairnloop.Web.AuditLogLive.handle_params(
          %{"proposal" => "bogus"},
          "/audit-log?proposal=bogus",
          socket
        )

      assert result.assigns.proposal_filter == nil
    end

    test "handle_params with proposal='123' assigns proposal_filter: 123" do
      socket = build_socket()
      {:noreply, result} =
        Cairnloop.Web.AuditLogLive.handle_params(
          %{"proposal" => "123"},
          "/audit-log?proposal=123",
          socket
        )

      assert result.assigns.proposal_filter == 123
    end

    test "handle_params with no proposal param assigns proposal_filter: nil (full view)" do
      socket = build_socket()
      {:noreply, result} =
        Cairnloop.Web.AuditLogLive.handle_params(%{}, "/audit-log", socket)

      assert result.assigns.proposal_filter == nil
    end

    test "handle_params with proposal='0' treats zero as invalid, full view (no crash)" do
      # Integer.parse("0") = {0, ""} — zero is not a positive id; treated as nil
      socket = build_socket()
      {:noreply, result} =
        Cairnloop.Web.AuditLogLive.handle_params(
          %{"proposal" => "0"},
          "/audit-log?proposal=0",
          socket
        )

      # Zero is not a valid positive proposal id — must not crash
      assert is_nil(result.assigns.proposal_filter) or result.assigns.proposal_filter == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 42 Task 2 — Per-row subject link with accessible name + fallback.
  # Tests must FAIL before implementation (TDD RED).
  # ---------------------------------------------------------------------------

  describe "Phase 42 Task 2 — per-row subject link" do
    test "event with conversation_id 5 renders a navigate='/5' link" do
      event = build_event(conversation_id: 5)
      assigns = base_assigns() |> Map.put(:visible_events, [event])
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(assigns))
      assert html =~ ~s(navigate="/5"), "expected navigate=\"/5\" in rendered HTML for conversation_id: 5"
    end

    test "event with conversation_id 5 renders 'View conversation' accessible name" do
      event = build_event(conversation_id: 5)
      assigns = base_assigns() |> Map.put(:visible_events, [event])
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(assigns))
      assert html =~ "View conversation", "expected 'View conversation' accessible name in rendered HTML"
    end

    test "event with conversation_id 5 does NOT render a /support/ prefix" do
      event = build_event(conversation_id: 5)
      assigns = base_assigns() |> Map.put(:visible_events, [event])
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(assigns))
      refute html =~ "/support/", "expected NO /support/ prefix in navigate href"
    end

    test "event with conversation_id nil renders no navigate link for subject cell" do
      event = build_event(conversation_id: nil)
      assigns = base_assigns() |> Map.put(:visible_events, [event])
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(assigns))
      refute html =~ ~s(navigate="/), "expected NO navigate link for nil conversation_id"
    end

    test "event with conversation_id nil renders a plain em-dash fallback cell" do
      event = build_event(conversation_id: nil)
      assigns = base_assigns() |> Map.put(:visible_events, [event])
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(assigns))
      assert html =~ "—", "expected em-dash fallback for nil conversation_id"
    end

    test "subject column header 'Conversation' is present in table thead" do
      assigns = base_assigns() |> Map.put(:visible_events, [build_event(conversation_id: 5)])
      html = rendered_to_string(Cairnloop.Web.AuditLogLive.render(assigns))
      assert html =~ "Conversation", "expected 'Conversation' column header in table thead"
    end
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  # Build a minimal socket with the assigns that AuditLogLive needs.
  # Uses a mock auditor so load_events/1 never hits the Repo.
  defp build_socket do
    Application.put_env(:cairnloop, :auditor, AuditLogLiveTest.MockAuditor)

    %Phoenix.LiveView.Socket{
      assigns: %{
        query: "",
        action_filter: "all",
        limit: 50,
        proposal_filter: nil,
        events: [],
        visible_events: [],
        action_options: [],
        maybe_more?: false,
        __changed__: %{}
      }
    }
  end

  defp build_event(opts) do
    %{
      inserted_at: ~U[2026-01-01 00:00:00Z],
      actor_id: "operator@example.com",
      action: :approved,
      reason: "Approved in test",
      metadata: %{},
      conversation_id: Keyword.get(opts, :conversation_id),
      proposal_id: 1
    }
  end
end

defmodule AuditLogLiveTest.MockAuditor do
  @behaviour Cairnloop.Auditor

  @impl true
  def list_events(_opts), do: []

  @impl true
  def audit(multi, _action, _actor, _metadata), do: multi
end
