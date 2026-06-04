defmodule Cairnloop.Web.ResponsiveMarkupTest do
  @moduledoc """
  Responsive-markup drift-proofing test — RESP-02 (Phase 43 D3-04 / D3-05).

  Asserts that all four `.cl-table` render sites carry an accessible scroll
  wrapper (`class="cl-table-scroll"` + `role="region"` + `tabindex="0"` +
  `aria-label`) and that the conversation two-column layout is authored
  mobile-first (base `flex-direction: column` + `min-width: 1024px` row).

  This test is DB-free (pure File.read! source scan).
  # REPO-UNAVAILABLE: no assertions require a Postgres round-trip.

  Source-scan is the deliberate approach: the wrappers render behind
  `:if={@... != []}` guards, so a LiveViewTest render with empty data will NOT
  emit them. File.read! pins the contract without needing a live DB or seeded rows.
  """

  use ExUnit.Case, async: true

  @web_dir Path.expand("../../../lib/cairnloop/web", __DIR__)
  @css_file Path.expand("../../../priv/static/cairnloop.css", __DIR__)

  # ── Table wrapper accessibility (D3-04 / RESP-02) ──────────────────────────

  @table_files ~w(
    audit_log_live.ex
    settings_live.ex
    knowledge_base_live/index.ex
    knowledge_base_live/suggestion_review.ex
  )

  describe "accessible table scroll regions (D3-04 / RESP-02)" do
    for file <- @table_files do
      test "#{file}: cl-table is wrapped in an accessible cl-table-scroll region" do
        src = File.read!(Path.join(@web_dir, unquote(file)))

        assert src =~ ~s(class="cl-table-scroll"),
               "#{unquote(file)} is missing the cl-table-scroll wrapper"

        assert src =~ ~s(role="region"),
               "#{unquote(file)} is missing role=\"region\" on the scroll wrapper"

        assert src =~ ~s(tabindex="0"),
               "#{unquote(file)} is missing tabindex=\"0\" on the scroll wrapper"

        assert src =~ "aria-label",
               "#{unquote(file)} is missing a non-empty aria-label on the scroll wrapper"
      end
    end
  end

  # ── Conversation layout stacks below lg (D3-05 / RESP-02) ─────────────────

  describe "conversation layout stacks below lg (D3-05 / RESP-02)" do
    test "conversation-layout base rule is flex-direction: column (mobile-first stacked)" do
      css = File.read!(@css_file)

      assert css =~ "flex-direction: column",
             "cairnloop.css must have a base flex-direction: column rule (conversation-layout stacks on mobile)"
    end

    test "conversation-layout becomes a row at min-width: 1024px (desktop side-by-side)" do
      css = File.read!(@css_file)

      assert css =~ "min-width: 1024px",
             "cairnloop.css must have a @media (min-width: 1024px) block for the conversation two-column layout"

      assert css =~ "flex-direction: row",
             "cairnloop.css must contain flex-direction: row inside the min-width: 1024px block"
    end
  end
end
