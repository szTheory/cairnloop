defmodule Cairnloop.Web.ResponsiveMarkupTest do
  @moduledoc """
  Responsive-markup drift-proofing test — RESP-02 (Phase 43 D3-04 / D3-05 / D3-06 / D3-07).

  Asserts that all four `.cl-table` render sites carry an accessible scroll
  wrapper (`class="cl-table-scroll"` + `role="region"` + `tabindex="0"` +
  `aria-label`) and that the conversation two-column layout is authored
  mobile-first (base `flex-direction: column` + `min-width: 1024px` row).

  Also asserts inbox tap targets ≥44px (D3-07): both checkboxes carry
  `class="cl-checkbox"`, both bulk-bar buttons carry `size="lg"`, and the
  inbox list reserves bottom clearance so the sticky bulk-bar never occludes
  the last row.

  This test is DB-free (pure File.read! source scan).
  # REPO-UNAVAILABLE: no assertions require a Postgres round-trip.

  Source-scan is the deliberate approach: the wrappers render behind
  `<%= if ... do %>` emptiness guards, so a LiveViewTest render with empty data
  will NOT emit them. File.read! pins the contract without needing a live DB or
  seeded rows. (Rendered-geometry facts — tap-target pixels, sticky-bar
  occlusion — are pinned by the gated Playwright E2E
  `examples/cairnloop_example/test/e2e/inbox_geometry_test.exs`; this file only
  proves the source attributes/CSS rules are PRESENT.)
  """

  use ExUnit.Case, async: true

  @web_dir Path.expand("../../../lib/cairnloop/web", __DIR__)
  @css_file Path.expand("../../../priv/static/cairnloop.css", __DIR__)
  @inbox_file "inbox_live.ex"

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

  # ── Tap targets ≥44px (D3-07 / RESP-02) ──────────────────────────────────

  describe "tap targets >= 44px (D3-07 / RESP-02)" do
    test "both inbox checkboxes carry class=\"cl-checkbox\" (≥44×44px hit area)" do
      src = File.read!(Path.join(@web_dir, @inbox_file))

      occurrences = src |> String.split("cl-checkbox") |> length() |> Kernel.-(1)

      assert occurrences >= 2,
             "inbox_live.ex must have at least 2 occurrences of cl-checkbox (select-all + per-row); found #{occurrences}"
    end

    test "both bulk-bar buttons carry size=\"lg\" (44px height via .cl-button--lg)" do
      src = File.read!(Path.join(@web_dir, @inbox_file))

      occurrences = src |> String.split(~s(size="lg")) |> length() |> Kernel.-(1)

      assert occurrences >= 2,
             "inbox_live.ex must have at least 2 occurrences of size=\"lg\" (both bulk-bar buttons); found #{occurrences}"
    end

    test "inbox list carries the bottom-clearance class so sticky bulk-bar does not occlude last row" do
      src = File.read!(Path.join(@web_dir, @inbox_file))

      assert src =~ "cl-inbox-list--bulk-clearance",
             "inbox_live.ex must apply cl-inbox-list--bulk-clearance to the inbox <ul> (D3-06 bottom clearance)"
    end

    test "cairnloop.css defines .cl-inbox-list--bulk-clearance with padding-bottom (bulk-bar clearance pinned)" do
      css = File.read!(@css_file)

      assert css =~ ".cl-inbox-list--bulk-clearance",
             "cairnloop.css must define the .cl-inbox-list--bulk-clearance rule for sticky bulk-bar clearance"

      # The reserve must cover the FULL bar height (44px control + 24px bar padding ≈ 68px),
      # not a partial token step — otherwise a fully-scrolled list can still occlude the last row.
      assert css =~ "padding-bottom: calc(var(--cl-control-h-lg",
             "cairnloop.css .cl-inbox-list--bulk-clearance must reserve the full bar height via calc(var(--cl-control-h-lg, 44px) + var(--cl-space-7, 24px)) so the last row clears the sticky bulk-bar"
    end

    test "var(--cl-primary) literal is still present in inbox_live.ex (integration test contract preserved)" do
      src = File.read!(Path.join(@web_dir, @inbox_file))

      assert src =~ "var(--cl-primary)",
             "inbox_live.ex must retain the var(--cl-primary) inline style on the primary bulk-bar button (four integration tests assert this literal)"
    end
  end

  describe "geometry E2E is wired into the gated lane (D3-06/D3-07 zero-UAT guard)" do
    # The inbox rendered-geometry facts are verified by a gated Playwright E2E, NOT a human-verify
    # checkpoint (STATE.md "Verification policy"). `mix test` excludes :e2e, so a green lib suite
    # says nothing about that file. This cheap source-scan guards against a silent regression — a
    # @moduletag typo or a deleted file would re-open the human-verify gap the E2E was meant to
    # close. It pins existence + the :e2e tag + that real geometry (getBoundingClientRect) is asserted.
    @geometry_e2e Path.expand(
                    "../../../examples/cairnloop_example/test/e2e/inbox_geometry_test.exs",
                    __DIR__
                  )

    test "inbox_geometry_test.exs exists, is tagged :e2e, and measures rendered geometry" do
      assert File.exists?(@geometry_e2e),
             "the inbox geometry E2E must exist at examples/cairnloop_example/test/e2e/inbox_geometry_test.exs " <>
               "(it is the automated replacement for the former 43-03 human-verify checkpoint)"

      src = File.read!(@geometry_e2e)

      assert src =~ "@moduletag :e2e",
             "inbox_geometry_test.exs must carry @moduletag :e2e so the gated `mix test.e2e` lane picks it up"

      assert src =~ "getBoundingClientRect",
             "inbox_geometry_test.exs must measure rendered geometry (getBoundingClientRect) — a source scan cannot prove pixel sizes"
    end
  end
end
