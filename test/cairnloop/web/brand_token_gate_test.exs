defmodule Cairnloop.Web.BrandTokenGateTest do
  @moduledoc """
  Brand-token CI gate — BRAND-04 (Phase 29 D-10) + GATE-01 (Phase 40).

  Asserts that render `.ex` files under `lib/cairnloop/web/` and the example
  app live dir contain NO hardcoded color literals:
    - var(--cl-<token>, #<hex>) fallback hex strings (BRAND-04)
    - inline `style="…#rrggbb…"` or `style="…#rgb…"` bare hex (GATE-01 a)
    - raw `rgba()`/`rgb()`/`hsla()`/`hsl()` function-color literals (GATE-01 b)
    - helper-returned hex strings like `"#8b1a1a"` (GATE-01 c)

  Opt-in allowlist: a `# cl-allow-color` comment on the SAME line OR the
  immediately-preceding line suppresses a violation for that line.  Use
  sparingly — every exception is visible in `grep -rn cl-allow-color`.

  Scope: `lib/cairnloop/web/**/*.ex` + example app live dir.  `.css` is
  excluded structurally (only `.ex` globbed) — D-05/D-06.

  This test is DB-free (pure File.read!/string scan).
  # REPO-UNAVAILABLE: no assertions require a Postgres round-trip.
  """

  use ExUnit.Case, async: true

  # ── Patterns ──────────────────────────────────────────────────────────────

  # BRAND-04: var(--cl-<token>, #hex) fallback form
  @hex_fallback_pattern ~r/var\(--cl-[a-z-]+,\s*#/

  # GATE-01 (a)+(c): bare #rrggbb or #rgb literal in source text.
  # \b after the hex digits prevents matching longer IDs or 8-digit rgba-hex.
  @hex_color ~r/#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b/

  # GATE-01 (b): raw rgba()/rgb()/hsla()/hsl() function-color literals.
  @func_color ~r/\b(?:rgba?|hsla?)\(/

  # Sentinel for the opt-in allowlist.
  @allow_sentinel "cl-allow-color"

  # ── Dirs (unchanged from BRAND-04 — D-06) ─────────────────────────────────

  @web_dir Path.expand("../../../lib/cairnloop/web", __DIR__)
  @example_live_dir Path.expand(
                      "../../../examples/cairnloop_example/lib/cairnloop_example_web/live",
                      __DIR__
                    )

  # ── Helpers ───────────────────────────────────────────────────────────────

  # Strip #{...} EEx interpolation so it never trips the 3/6-hex rule.
  defp strip_interpolation(line),
    do: String.replace(line, ~r/\#\{[^}]*\}/, "")

  # True when a trimmed line is a pure comment with no color context.
  # Such lines are skipped to avoid flagging `# see issue #1234`.
  defp color_free_comment?(line) do
    trimmed = String.trim_leading(line)

    String.starts_with?(trimmed, "#") and
      not (trimmed =~ ~r/style=|color|background|rgba|hsl/i)
  end

  # Build the set of allowed line numbers for a file's lines (1-indexed list).
  # A line containing the sentinel grants suppression for itself AND line+1.
  defp allowed_line_numbers(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, no} ->
      if String.contains?(line, @allow_sentinel) do
        # sentinel line itself and the next line (prev-line block comment case)
        [no, no + 1]
      else
        []
      end
    end)
    |> MapSet.new()
  end

  # Collect hardcoded-color violations from an in-memory list of {line, line_no}.
  # Returns [{line_no, trimmed_line}] for each violation not covered by the allowlist.
  defp collect_violations(lines_with_index, allowed) do
    for {line, line_no} <- lines_with_index,
        line_no not in allowed,
        not color_free_comment?(line),
        scrubbed = strip_interpolation(line),
        Regex.match?(@hex_color, scrubbed) or Regex.match?(@func_color, scrubbed) do
      {line_no, String.trim(line)}
    end
  end

  # ── Tests ──────────────────────────────────────────────────────────────────

  test "GATE-01 fixtures: bare hex, rgba/hsl flagged; tokens, anchors, interpolation, comments pass; allowlist suppresses" do
    fail_cases = [
      # GATE-01 (a) inline 3-digit hex in style
      ~s|<div style="color:#abc">|,
      # GATE-01 (a) inline 6-digit hex in style
      ~s|<div style="color: #4A6238;">|,
      # GATE-01 (b) raw rgba in helper return string
      ~s|  "background: rgba(0,0,0,0.5);"|,
      # GATE-01 (b) raw hsl in helper return string
      ~s|  "color: hsl(20, 50%, 40%);"|,
      # GATE-01 (c) helper-returned bare hex
      ~s|  defp badge, do: "#8b1a1a"|,
      # GATE-01 (b) raw rgba in attribute value
      ~s|<div style="border:1px solid rgba(64,51,43,0.08)">|
    ]

    pass_cases = [
      # token-valued inline style → PASS
      ~s|<div style="color: var(--cl-text)">|,
      # utility class → PASS
      ~s|<button class="cl-button cl-button--primary">|,
      # anchor href — non-hex char follows # → no 3/6-hex match → PASS
      ~s|<a href="#supporting-evidence">|,
      # no # at all (phx binding) → PASS
      ~s|phx-value-dom_id={presenter.dom_id}|,
      # comment: #1234 is only 4 digits, and "issue" has no color context → PASS
      ~s|# a comment mentioning issue #1234|
    ]

    # Every FAIL case must produce a violation when tested in isolation.
    for line <- fail_cases do
      lines_with_index = [{line, 1}]
      allowed = MapSet.new()

      violations = collect_violations(lines_with_index, allowed)

      assert violations != [],
             "Expected FAIL case to be flagged but it was not:\n  #{inspect(line)}"
    end

    # Every PASS case must produce NO violation.
    for line <- pass_cases do
      lines_with_index = [{line, 1}]
      allowed = MapSet.new()

      violations = collect_violations(lines_with_index, allowed)

      assert violations == [],
             "Expected PASS case to be clean but it was flagged:\n  #{inspect(line)}\n  violations: #{inspect(violations)}"
    end

    # Allowlist (same-line comment): violation suppressed when sentinel on same line.
    allow_same_line = ~s|<div style="color:#abc"> <%!-- cl-allow-color --%>|
    lines_with_index = [{allow_same_line, 1}]
    # Line 1 contains the sentinel → line 1 and 2 are allowed.
    allowed = allowed_line_numbers([allow_same_line])

    assert collect_violations(lines_with_index, allowed) == [],
           "Expected same-line cl-allow-color to suppress violation"

    # Allowlist (prev-line comment): violation on line 2 suppressed when sentinel on line 1.
    prev_line_sentinel = "# cl-allow-color"
    allow_prev_line = ~s|<div style="color:#abc">|
    lines = [prev_line_sentinel, allow_prev_line]
    lines_with_index2 = Enum.with_index(lines, 1)
    allowed2 = allowed_line_numbers(lines)

    assert collect_violations(lines_with_index2, allowed2) == [],
           "Expected prev-line cl-allow-color to suppress violation on next line"
  end

  test "no hex-fallback strings remain in lib/cairnloop/web/ or examples/cairnloop_example/lib/cairnloop_example_web/live/ (BRAND-04, Phase 29 D-10 closure)" do
    files =
      Path.wildcard(Path.join(@web_dir, "**/*.ex")) ++
        Path.wildcard(Path.join(@example_live_dir, "**/*.ex"))

    refute files == [],
           "Expected to find .ex files in both #{@web_dir} and #{@example_live_dir}; got empty list — check path resolution"

    violations =
      for file <- files,
          {line, line_no} <- file |> File.read!() |> String.split("\n") |> Enum.with_index(1),
          Regex.match?(@hex_fallback_pattern, line) do
        {Path.basename(file), line_no, String.trim(line)}
      end

    assert violations == [],
           """
           BRAND-04 contract violated — hex fallbacks found in sealed render files.

           Phase 29 D-10 closure requires bare var(--cl-<token>) form.
           Canonical token source: priv/static/cairnloop.css
                                   (imported by examples/.../assets/css/app.css)

           Violations:
           #{Enum.map_join(violations, "\n", fn {file, line_no, line} -> "  #{file}:#{line_no} — #{line}" end)}

           To fix: remove the `, #<hex>` suffix from each var() call above.
           rgba(...) fallbacks are NOT flagged by this gate (deferred to vM015).
           """
  end

  test "GATE-01 hardened scan: no bare hex or raw rgba/hsl in lib/cairnloop/web/ or example live dir" do
    files =
      Path.wildcard(Path.join(@web_dir, "**/*.ex")) ++
        Path.wildcard(Path.join(@example_live_dir, "**/*.ex"))

    refute files == [],
           "Expected to find .ex files in scan dirs; got empty list — check path resolution"

    all_violations =
      for file <- files do
        content = File.read!(file)
        lines = String.split(content, "\n")
        lines_with_index = Enum.with_index(lines, 1)
        allowed = allowed_line_numbers(lines)
        file_violations = collect_violations(lines_with_index, allowed)

        Enum.map(file_violations, fn {line_no, trimmed} ->
          {Path.relative_to(file, File.cwd!()), line_no, trimmed}
        end)
      end
      |> List.flatten()

    assert all_violations == [],
           """
           GATE-01 violated — hardcoded color literals found in render files.

           Files must use var(--cl-<token>) or .cl- utility classes.
           Suppress a known-intentional exception with `# cl-allow-color` on the
           same line or the immediately-preceding line.

           Violations:
           #{Enum.map_join(all_violations, "\n", fn {file, line_no, line} -> "  #{file}:#{line_no} — #{line}" end)}
           """
  end
end
