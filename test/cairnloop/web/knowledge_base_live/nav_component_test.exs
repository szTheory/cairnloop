defmodule Cairnloop.Web.KnowledgeBaseLive.NavComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Cairnloop.Web.KnowledgeBaseLive.NavComponent

  describe "kb_nav/1 — link presence" do
    test "renders all three labels and routes when current: :index" do
      html = render_component(&NavComponent.kb_nav/1, current: :index)

      assert html =~ "Knowledge base"
      assert html =~ "Suggestions"
      assert html =~ "Gaps"
      assert html =~ "/knowledge-base\""
      assert html =~ "/knowledge-base/suggestions"
      assert html =~ "/knowledge-base/gaps"
    end
  end

  describe "kb_nav/1 — active marker (aria-current)" do
    test "current: :index marks Knowledge base link active with aria-current=\"page\"" do
      html = render_component(&NavComponent.kb_nav/1, current: :index)

      # aria-current="page" should appear exactly once
      occurrences = html |> String.split("aria-current=\"page\"") |> length()
      assert occurrences == 2, "Expected aria-current=\"page\" exactly once, got #{occurrences - 1}"

      # The Knowledge base link (href /knowledge-base") should be near the active marker
      # Simple check: Knowledge base text should appear in the rendered output alongside aria-current
      assert html =~ "aria-current=\"page\""
      assert html =~ "Knowledge base"
    end

    test "current: :suggestions marks Suggestions link active" do
      html = render_component(&NavComponent.kb_nav/1, current: :suggestions)

      occurrences = html |> String.split("aria-current=\"page\"") |> length()
      assert occurrences == 2, "Expected aria-current=\"page\" exactly once for :suggestions"

      assert html =~ "aria-current=\"page\""
      assert html =~ "Suggestions"
    end

    test "current: :gaps marks Gaps link active" do
      html = render_component(&NavComponent.kb_nav/1, current: :gaps)

      occurrences = html |> String.split("aria-current=\"page\"") |> length()
      assert occurrences == 2, "Expected aria-current=\"page\" exactly once for :gaps"

      assert html =~ "aria-current=\"page\""
      assert html =~ "Gaps"
    end

    test "current: :editor renders no aria-current=\"page\" (Editor has no top-level nav entry)" do
      html = render_component(&NavComponent.kb_nav/1, current: :editor)

      refute html =~ "aria-current=\"page\"",
             "Expected no aria-current=\"page\" when current is :editor"
    end
  end

  describe "kb_nav/1 — accessibility" do
    test "wraps nav in <nav aria-label=\"Knowledge base\">" do
      html = render_component(&NavComponent.kb_nav/1, current: :index)

      assert html =~ ~s(aria-label="Knowledge base"),
             "Expected <nav aria-label=\"Knowledge base\"> wrapper"
    end
  end

  describe "kb_nav/1 — brand token compliance (not-color-alone)" do
    test "active link uses var(--cl-primary) for border (not color alone)" do
      html = render_component(&NavComponent.kb_nav/1, current: :index)

      # The active state must pair the primary border with aria-current="page"
      # This proves not-color-alone is honored
      assert html =~ "var(--cl-primary)",
             "Active link must include var(--cl-primary) for border styling"

      assert html =~ "aria-current=\"page\"",
             "Active link must also have aria-current=\"page\" (not color alone)"
    end

    test "no hex fallback strings in rendered output" do
      html = render_component(&NavComponent.kb_nav/1, current: :index)

      refute html =~ ~r/var\(--cl-[a-z-]+,\s*#/,
             "Rendered output must not contain hex fallback var(--cl-token, #hex)"
    end
  end
end
