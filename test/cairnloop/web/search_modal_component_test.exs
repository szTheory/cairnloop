defmodule Cairnloop.Web.SearchModalComponentTest do
  use ExUnit.Case, async: true

  alias Cairnloop.Retrieval.Result
  alias Cairnloop.Web.SearchModalComponent

  defmodule MockRetrieval do
    def search("policy", opts) do
      send(self(), {:retrieval_search, "policy", opts})

      [
        %Result{
          id: 101,
          title: "Refund policy",
          content:
            "Agents should honor the documented refund window and cite the article revision.",
          source_type: :knowledge_base,
          trust_level: :canonical,
          article_id: 55,
          revision_id: 89,
          chunk_index: 0,
          updated_at: DateTime.utc_now(),
          citation_target: %{article_id: 55, revision_id: 89, chunk_index: 0},
          metadata: %{
            heading: "Refund eligibility",
            destination: %{
              type: :knowledge_base_article,
              article_id: 55,
              revision_id: 89,
              chunk_index: 0
            }
          }
        },
        %Result{
          id: 202,
          title: "Refund request from enterprise account",
          content: "The prior case used the same approval path and documented every credit step.",
          source_type: :resolved_case,
          trust_level: :assistive,
          conversation_id: 99,
          chunk_index: 1,
          resolved_at: DateTime.utc_now(),
          issue_summary: "Customer requested a refund outside the self-serve window.",
          resolution_note: "Agent matched the KB policy before escalating for approval.",
          actions_taken: ["Verified purchase date", "Escalated to finance"],
          outcome: "Refund approved with policy citation.",
          citation_target: %{conversation_id: 99, chunk_index: 1},
          metadata: %{
            destination: %{type: :resolved_case, conversation_id: 99, chunk_index: 1}
          }
        }
      ]
    end

    def search("boom", opts) do
      send(self(), {:retrieval_search, "boom", opts})
      {:error, :unavailable}
    end

    def search("assistive", opts) do
      send(self(), {:retrieval_search, "assistive", opts})

      [
        %Result{
          id: 303,
          title: "Resolved billing export workaround",
          content: "A prior operator used escalation after manual review.",
          source_type: :resolved_case,
          trust_level: :assistive,
          conversation_id: 88,
          chunk_index: 0,
          resolved_at: DateTime.utc_now(),
          issue_summary: "Billing export still failed after retry.",
          resolution_note: "Escalated after confirming no KB article covered the case.",
          actions_taken: ["Reviewed account", "Escalated to support"],
          outcome: "Escalation completed.",
          citation_target: %{conversation_id: 88, chunk_index: 0},
          metadata: %{
            destination: %{type: :resolved_case, conversation_id: 88, chunk_index: 0}
          }
        }
      ]
    end

    def search(query, opts) do
      send(self(), {:retrieval_search, query, opts})
      []
    end
  end

  defmodule MockGapRecorder do
    def record(attrs) do
      send(self(), {:gap_recorded, attrs})
      {:ok, attrs}
    end
  end

  test "renders closed by default and opens only on the shortcut contract" do
    socket = fresh_socket()

    refute rendered_html(socket) =~ "Search knowledge and resolved cases"

    {:noreply, socket} =
      SearchModalComponent.handle_event(
        "toggle_search",
        %{"key" => "p", "metaKey" => true},
        socket
      )

    refute socket.assigns.open

    {:noreply, socket} =
      SearchModalComponent.handle_event(
        "toggle_search",
        %{"key" => "k", "metaKey" => true},
        socket
      )

    html = rendered_html(socket)

    assert socket.assigns.open
    assert html =~ "Search knowledge and resolved cases"
    assert html =~ "Knowledge Base"
    assert html =~ "Similar resolved cases"
  end

  test "queries shorter than 2 characters keep results empty" do
    socket = opened_socket()

    {:noreply, socket} = SearchModalComponent.handle_event("search", %{"query" => "r"}, socket)

    html = rendered_html(socket)

    assert html =~ "Type at least 2 characters"
    refute html =~ "Refund policy"
    refute_received {:retrieval_search, _query}
  end

  test "active-row movement updates preview locally without a fresh search request" do
    socket = searched_socket()
    assert_received {:retrieval_search, "policy", _opts}

    {:noreply, socket} =
      SearchModalComponent.handle_event(
        "handle_palette_key",
        %{"key" => "ArrowDown"},
        socket
      )

    assert socket.assigns.active_dom_id == "resolved_case-99-1"
    assert socket.assigns.preview.title == "Refund request from enterprise account"

    html = rendered_html(socket)

    assert html =~ "Issue summary: Customer requested a refund outside the self-serve window."
    assert html =~ "Resolution note: Agent matched the KB policy before escalating for approval."
    assert html =~ "Actions taken: Verified purchase date, Escalated to finance"
    assert html =~ "Outcome: Refund approved with policy citation."
    refute_received {:retrieval_search, _query}
  end

  test "enter opens the active result while movement alone does not navigate" do
    socket = searched_socket()

    {:noreply, moved_socket} =
      SearchModalComponent.handle_event(
        "handle_palette_key",
        %{"key" => "ArrowDown"},
        socket
      )

    assert navigation_target(moved_socket) == nil

    {:noreply, opened_socket} =
      SearchModalComponent.handle_event(
        "handle_palette_key",
        %{"key" => "Enter"},
        moved_socket
      )

    assert navigation_target(opened_socket) == "/99"
  end

  test "escape clears the query first and then closes the palette" do
    socket = searched_socket()

    {:noreply, socket} =
      SearchModalComponent.handle_event(
        "handle_palette_key",
        %{"key" => "Escape"},
        socket
      )

    assert socket.assigns.open
    assert socket.assigns.query == ""
    assert socket.assigns.preview == nil

    {:noreply, socket} =
      SearchModalComponent.handle_event(
        "handle_palette_key",
        %{"key" => "Escape"},
        socket
      )

    refute socket.assigns.open
  end

  test "retrieval-backed searches render both sections in fixed order with source and trust labels" do
    socket = searched_socket()
    html = rendered_html(socket)

    assert html =~ "Refund policy"
    assert html =~ "Refund request from enterprise account"
    assert html =~ "Canonical guidance"
    assert html =~ "Supporting evidence"

    kb_index = :binary.match(html, "Knowledge Base") |> elem(0)
    resolved_index = :binary.match(html, "Similar resolved cases") |> elem(0)

    assert kb_index < resolved_index
    assert html =~ "Open article"
    assert html =~ "Open resolved case"
  end

  test "retrieval errors surface a non-destructive error state" do
    socket = opened_socket()

    {:noreply, socket} = SearchModalComponent.handle_event("search", %{"query" => "boom"}, socket)

    html = rendered_html(socket)

    assert html =~ "Search is unavailable right now"
    assert html =~ "Preview results here"
    assert_received {:gap_recorded, %{outcome_class: :retrieval_error, reason: :unexpected_error}}
  end

  test "search passes scope metadata into retrieval and records no-hit gaps synchronously" do
    socket = opened_socket()

    {:noreply, socket} =
      SearchModalComponent.handle_event("search", %{"query" => "missing"}, socket)

    assert_received {:retrieval_search, "missing",
                     [
                       surface: :search_modal,
                       host_surface: "conversation",
                       host_user_id: "user_42"
                     ]}

    assert_received {:gap_recorded,
                     %{
                       query: "missing",
                       surface: :search_modal,
                       outcome_class: :empty_recall,
                       reason: :no_canonical_results,
                       host_user_id: "user_42",
                       tenant_scope: :host_user_scoped,
                       ui_surface: "conversation"
                     }}

    html = rendered_html(socket)

    assert html =~ "No verified guidance matched this search yet"
    assert html =~ "No Knowledge Base matches yet"
  end

  test "non-conversation surfaces fail closed when host scope is missing" do
    socket = opened_socket(host_surface: "inbox", host_user_id: nil)

    {:noreply, socket} =
      SearchModalComponent.handle_event("search", %{"query" => "policy"}, socket)

    refute_received {:retrieval_search, _query, _opts}
    refute_received {:gap_recorded, _attrs}

    html = rendered_html(socket)

    assert socket.assigns.search_state == :scoped_unavailable
    assert html =~ "Scoped search is unavailable on this surface"
  end

  test "assistive-only search persists one weak-grounding gap with separated scope semantics" do
    socket = opened_socket()

    {:noreply, socket} =
      SearchModalComponent.handle_event("search", %{"query" => "assistive"}, socket)

    assert_received {:gap_recorded,
                     %{
                       query: "assistive",
                       surface: :search_modal,
                       outcome_class: :weak_grounding,
                       reason: :assistive_only_results,
                       host_user_id: "user_42",
                       tenant_scope: :host_user_scoped,
                       ui_surface: "conversation"
                     }}

    html = rendered_html(socket)

    assert html =~ "Resolved billing export workaround"
    refute html =~ "No verified guidance matched this search yet"
  end

  test "mixed search results stay durable-gap silent because canonical evidence is present" do
    socket = opened_socket()

    {:noreply, _socket} =
      SearchModalComponent.handle_event("search", %{"query" => "policy"}, socket)

    refute_received {:gap_recorded, %{reason: :assistive_only_results}}
    refute_received {:gap_recorded, %{reason: :mixed_results}}
    refute_received {:gap_recorded, %{reason: :canonical_results}}
  end

  defp fresh_socket(overrides \\ []) do
    {:ok, socket} = SearchModalComponent.mount(%Phoenix.LiveView.Socket{})

    {:ok, socket} =
      SearchModalComponent.update(
        Enum.into(overrides, %{
          id: "search-modal",
          retrieval_module: MockRetrieval,
          gap_recorder: MockGapRecorder,
          host_surface: "conversation",
          host_user_id: "user_42",
          current_path: "/99",
          preserve_reply_form: true
        }),
        socket
      )

    %{socket | assigns: Map.put(socket.assigns, :myself, "search-modal")}
  end

  defp opened_socket(overrides \\ []) do
    socket = fresh_socket(overrides)

    {:noreply, socket} =
      SearchModalComponent.handle_event(
        "toggle_search",
        %{"key" => "k", "metaKey" => true},
        socket
      )

    socket
  end

  defp searched_socket do
    socket = opened_socket()

    {:noreply, socket} =
      SearchModalComponent.handle_event("search", %{"query" => "policy"}, socket)

    socket
  end

  defp rendered_html(socket) do
    socket.assigns
    |> SearchModalComponent.render()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp navigation_target(socket) do
    case Map.get(socket, :redirected) do
      {:live, :redirect, %{to: to}} -> to
      {:live, :patch, %{to: to}} -> to
      _ -> nil
    end
  end
end
