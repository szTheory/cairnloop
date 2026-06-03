defmodule Cairnloop.Web.BrandTokenGateTest do
  @moduledoc """
  BRAND-04 negative-grep gate — Phase 29 D-10 closure.

  Asserts that no `var(--cl-<token>, #<hex>)` hex-fallback strings remain in
  `lib/cairnloop/web/` or `examples/cairnloop_example/lib/cairnloop_example_web/live/`.

  The canonical token definitions live in the shipped, self-contained
  `priv/static/cairnloop.css` (the hex-packaged design system; the example app
  imports it via `examples/cairnloop_example/assets/css/app.css`). All sealed
  render files must use bare `var(--cl-<token>)` form. Re-introducing a hex
  fallback will fail this test and therefore fail the default `mix test` build.

  Non-hex rgba(...) fallbacks (e.g., `var(--cl-shadow, rgba(...))`) are
  explicitly out of scope for this gate — the regex requires `#` after the
  comma. Those deferred tokens are tracked for vM015.
  """

  use ExUnit.Case, async: true

  # Regex matches var(--cl-<token>, # — deliberately does NOT match rgba(
  @hex_fallback_pattern ~r/var\(--cl-[a-z-]+,\s*#/

  @web_dir Path.expand("../../../lib/cairnloop/web", __DIR__)
  @example_live_dir Path.expand(
                      "../../../examples/cairnloop_example/lib/cairnloop_example_web/live",
                      __DIR__
                    )

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
end
