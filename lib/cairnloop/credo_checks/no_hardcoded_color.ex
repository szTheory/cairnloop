defmodule Cairnloop.CredoChecks.NoHardcodedColor do
  @moduledoc """
  Advisory Credo check for hardcoded color literals in render `.ex` files.

  Mirrors the ExUnit brand-token gate (GATE-01, Phase 40) as a dev-time signal.
  The ExUnit gate is the CI source of truth; this check is complementary only
  and does NOT raise a hard exit status of its own (D-07).

  Suppress a known-intentional exception with `# cl-allow-color` on the same
  line or the immediately-preceding line.
  """

  use Credo.Check,
    id: "CL_NoHardcodedColor",
    base_priority: :low,
    category: :warning,
    explanations: [
      check: """
      Hardcoded color literals (#hex, rgba(), hsl()) must not appear in render
      `.ex` files. Use `var(--cl-<token>)` or a `.cl-` utility class instead.

      The ExUnit brand-token gate (brand_token_gate_test.exs) is the authoritative
      CI source of truth; this Credo check is a complementary dev-time signal.

      Suppress a known-intentional exception with a `# cl-allow-color` comment on
      the same line or the immediately-preceding line.
      """
    ]

  # Same patterns as the ExUnit gate — must stay in sync.
  @hex_color ~r/#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b/
  @func_color ~r/\b(?:rgba?|hsla?)\(/
  @allow_sentinel "cl-allow-color"

  # Render dirs mirroring the ExUnit gate scope (D-06).
  @render_dir_patterns ["lib/cairnloop/web/", "lib/cairnloop_example_web/live/"]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    ctx = Context.build(source_file, params, __MODULE__)

    if render_file?(source_file.filename) do
      # SourceFile.lines/1 returns [{line_no, line_text}, ...] (1-indexed)
      lines = SourceFile.lines(source_file)
      allowed = allowed_line_numbers(lines)

      lines
      |> Enum.reject(fn {line_no, line_text} ->
        line_no in allowed or color_free_comment?(line_text)
      end)
      |> Enum.flat_map(fn {line_no, line_text} ->
        scrubbed = strip_interpolation(line_text)

        if Regex.match?(@hex_color, scrubbed) or Regex.match?(@func_color, scrubbed) do
          [issue_for(ctx, line_no, String.trim(line_text))]
        else
          []
        end
      end)
    else
      []
    end
  end

  # ── Private helpers ────────────────────────────────────────────────────────

  defp render_file?(filename) do
    Enum.any?(@render_dir_patterns, &String.contains?(filename, &1))
  end

  defp strip_interpolation(line),
    do: String.replace(line, ~r/\#\{[^}]*\}/, "")

  defp color_free_comment?(line) do
    trimmed = String.trim_leading(line)

    String.starts_with?(trimmed, "#") and
      not (trimmed =~ ~r/style=|color|background|rgba|hsl/i)
  end

  # lines is [{line_no, line_text}, ...] — SourceFile.lines/1 format.
  defp allowed_line_numbers(lines) do
    lines
    |> Enum.flat_map(fn {no, line_text} ->
      if String.contains?(line_text, @allow_sentinel) do
        [no, no + 1]
      else
        []
      end
    end)
    |> MapSet.new()
  end

  defp issue_for(ctx, line_no, trigger) do
    format_issue(
      ctx,
      message:
        "Hardcoded color literal in render file. Use var(--cl-<token>) or a .cl- utility class. Suppress with `# cl-allow-color`.",
      trigger: trigger,
      line_no: line_no
    )
  end
end
