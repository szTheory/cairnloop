defmodule Cairnloop.Web.CairnloopCssTest do
  @moduledoc """
  Machine-verification that the required CSS literals are present in `priv/static/cairnloop.css`.

  This is a pure file-content test — no DB, no Repo, no `# REPO-UNAVAILABLE` marker needed.
  It verifies UIC-05's CSS half: three layout tokens, three inert utilities, the table-scroll
  wrapper, and the four primitive class markers introduced in Phase 37.
  """
  use ExUnit.Case, async: true

  setup_all do
    css_path = Path.join(File.cwd!(), "priv/static/cairnloop.css")
    css = File.read!(css_path)
    {:ok, css: css}
  end

  describe "layout tokens (D-09 / UIC-05)" do
    test "defines --cl-content-max", %{css: css} do
      assert css =~ "--cl-content-max"
    end

    test "defines --cl-rail-width", %{css: css} do
      assert css =~ "--cl-rail-width"
    end

    test "defines --cl-page-gutter", %{css: css} do
      assert css =~ "--cl-page-gutter"
    end
  end

  describe "inert utility escape hatches (D-10 / UIC-05)" do
    test "defines .cl-gap-2", %{css: css} do
      assert css =~ ".cl-gap-2"
    end

    test "defines .cl-align-center", %{css: css} do
      assert css =~ ".cl-align-center"
    end

    test "defines .cl-justify-between", %{css: css} do
      assert css =~ ".cl-justify-between"
    end
  end

  describe "accessible table scroll wrapper (D-11 / UIC-05)" do
    test "defines .cl-table-scroll", %{css: css} do
      assert css =~ ".cl-table-scroll"
    end
  end

  describe "primitive visual CSS classes (Phase 37 UIC-01..04)" do
    test "defines .cl-hero__count (UIC-02 hero count at Fraunces 48px)", %{css: css} do
      assert css =~ ".cl-hero__count"
    end

    test "defines .cl-fact-list (UIC-04 dedicated label/value list)", %{css: css} do
      assert css =~ ".cl-fact-list"
    end

    test "defines .cl-source-card--success (UIC-04 variant triplet)", %{css: css} do
      assert css =~ ".cl-source-card--success"
    end

    test "defines .cl-switch__track (UIC-04 toggle control track)", %{css: css} do
      assert css =~ ".cl-switch__track"
    end
  end
end
