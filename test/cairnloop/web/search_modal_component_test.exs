defmodule Cairnloop.Web.SearchModalComponentTest do
  use ExUnit.Case, async: true

  alias Cairnloop.Retrieval.Result
  alias Cairnloop.Web.SearchModalComponent

  defmodule MockRetrieval do
    def search("policy", []) do
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

    def search("boom", []), do: {:error, :unavailable}
    def search(_query, []), do: []
  end

  test "renders closed by default and opens with cmd+k" do
    socket = fresh_socket()

    refute rendered_html(socket) =~ "Search knowledge and resolved cases"

    {:noreply, socket} =
      SearchModalComponent.handle_event(
        "toggle_search",
        %{"key" => "k", "metaKey" => true},
        socket
      )

    html = rendered_html(socket)

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
  end

  test "retrieval-backed searches render both sections in fixed order with source and trust labels" do
    socket = opened_socket()

    {:noreply, socket} =
      SearchModalComponent.handle_event("search", %{"query" => "policy"}, socket)

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

    {:noreply, socket} =
      SearchModalComponent.handle_event(
        "activate_result",
        %{"dom_id" => "resolved_case-99-1"},
        socket
      )

    html = rendered_html(socket)

    assert html =~ "Issue summary:"
    assert html =~ "Resolution note:"
  end

  test "retrieval errors surface a non-destructive error state" do
    socket = opened_socket()

    {:noreply, socket} = SearchModalComponent.handle_event("search", %{"query" => "boom"}, socket)

    html = rendered_html(socket)

    assert html =~ "Search is unavailable right now"
    assert html =~ "Preview results here"
  end

  defp fresh_socket do
    {:ok, socket} = SearchModalComponent.mount(%Phoenix.LiveView.Socket{})

    {:ok, socket} =
      SearchModalComponent.update(
        %{id: "search-modal", retrieval_module: MockRetrieval},
        socket
      )

    %{socket | assigns: Map.put(socket.assigns, :myself, "search-modal")}
  end

  defp opened_socket do
    socket = fresh_socket()

    {:noreply, socket} =
      SearchModalComponent.handle_event(
        "toggle_search",
        %{"key" => "k", "metaKey" => true},
        socket
      )

    socket
  end

  defp rendered_html(socket) do
    socket.assigns
    |> SearchModalComponent.render()
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
