defmodule Cairnloop.Web.KnowledgeBaseLive.EditorTest do
  @moduledoc """
  Headless render test for the KB editor LiveView. Exercises `render/1` directly
  with built assigns — no Repo needed. The DB-backed mount path (including
  KnowledgeAutomation.originating_conversation_id/2 resolution) is covered by the
  integration suite (# REPO-UNAVAILABLE).

  Phase 42 additions test THREAD-03b: origin-conversation crumb in the editor breadcrumb.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Cairnloop.KnowledgeBase.Article
  alias Cairnloop.Web.KnowledgeBaseLive.Editor

  # ---------------------------------------------------------------------------
  # Base assigns builder — all fields required by render/1
  # ---------------------------------------------------------------------------

  defp base_article do
    %Article{
      id: 42,
      title: "How to reset your password",
      status: :draft,
      inserted_at: ~N[2026-01-01 00:00:00],
      updated_at: ~N[2026-01-01 00:00:00]
    }
  end

  defp base_review_context do
    %{
      review_task: nil,
      return_to: nil,
      operator_summary: nil,
      evidence_count: 0
    }
  end

  defp base_assigns(overrides \\ %{}) do
    Map.merge(
      %{
        article: base_article(),
        revision: nil,
        content: "# Draft content",
        preview_html: "<h1>Draft content</h1>",
        review_context: base_review_context(),
        review_origin?: false,
        gap_candidate: nil,
        origin_conversation_id: nil,
        __changed__: nil
      },
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # Phase 42 THREAD-03b — origin-conversation breadcrumb crumb
  # ---------------------------------------------------------------------------

  describe "Phase 42 THREAD-03b — origin-conversation crumb (present id)" do
    test "breadcrumb contains 'From conversation' when origin_conversation_id is present" do
      assigns = base_assigns(%{origin_conversation_id: 99})
      html = rendered_to_string(Editor.render(assigns))

      assert html =~ "From conversation",
             "expected 'From conversation' crumb in breadcrumb when origin id is present"
    end

    test "breadcrumb link targets /id (scope-root-relative) for origin crumb" do
      assigns = base_assigns(%{origin_conversation_id: 99})
      html = rendered_to_string(Editor.render(assigns))

      # Phoenix <.link navigate={...}> renders as <a href="..."> in headless renders
      assert html =~ ~s(href="/99"),
             "expected href=\"/99\" for origin conversation crumb"
    end

    test "origin crumb href has no /support mount prefix" do
      assigns = base_assigns(%{origin_conversation_id: 99})
      html = rendered_to_string(Editor.render(assigns))

      refute html =~ ~s(href="/support/99"),
             "origin crumb href must not include /support mount prefix (Pitfall 3)"
    end
  end

  describe "Phase 42 THREAD-03b — origin-conversation crumb (nil id — honest absence)" do
    test "breadcrumb does NOT contain 'From conversation' when origin_conversation_id is nil" do
      assigns = base_assigns(%{origin_conversation_id: nil})
      html = rendered_to_string(Editor.render(assigns))

      refute html =~ "From conversation",
             "expected no 'From conversation' crumb when origin id is nil (honest absence, D-12)"
    end
  end

  # ---------------------------------------------------------------------------
  # Phase 38 shell migration — cl_page sanity (non-regression)
  # ---------------------------------------------------------------------------

  describe "Phase 38 SHELL-01 — cl_page shell render" do
    test "rendered HTML contains cl-page cl-page--wide" do
      html = rendered_to_string(Editor.render(base_assigns()))

      assert html =~ ~s(cl-page cl-page--wide),
             "expected class=\"cl-page cl-page--wide\" in rendered HTML"
    end

    test "rendered HTML contains article title" do
      html = rendered_to_string(Editor.render(base_assigns()))

      assert html =~ "How to reset your password",
             "expected article title in rendered HTML"
    end
  end
end
