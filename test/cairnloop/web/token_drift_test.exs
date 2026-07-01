defmodule Cairnloop.Web.TokenDriftTest do
  @moduledoc """
  Pure token drift and contrast verifier for Phase 48.

  The test reads static files only: no Repo, no Phoenix endpoint, no DB.
  """
  use ExUnit.Case, async: true

  @canonical_path "priv/static/cairnloop.css"
  @app_path "examples/cairnloop_example/assets/css/app.css"
  @tokens_path "prompts/cairnloop.tokens.json"

  @expected_cl_tokens ~w(
    --cl-ai --cl-ai-border --cl-ai-surface --cl-ai-text --cl-bg --cl-border
    --cl-border-strong --cl-color-basalt --cl-color-copper-glow
    --cl-color-deep-lichen --cl-color-ember --cl-color-fault-clay
    --cl-color-glacier-mist --cl-color-granite --cl-color-heather
    --cl-color-lichen --cl-color-moss-ink --cl-color-path-copper
    --cl-color-slate-lichen --cl-color-trailpaper --cl-color-warm-stone
    --cl-color-waypoint-blue --cl-content-max --cl-control-h-lg
    --cl-control-h-md --cl-control-h-sm --cl-control-px-lg --cl-control-px-md
    --cl-control-px-sm --cl-danger --cl-danger-border
    --cl-danger-button-text --cl-danger-soft --cl-danger-surface --cl-danger-text
    --cl-dur-exit --cl-dur-instant --cl-dur-micro --cl-dur-panel
    --cl-dur-route --cl-dur-ui --cl-ease-drawer --cl-ease-in-out
    --cl-ease-linear --cl-ease-out --cl-focus --cl-focus-ring --cl-font-body
    --cl-font-code --cl-font-display --cl-font-micro --cl-font-mono
    --cl-font-panel --cl-font-sans --cl-font-small --cl-font-title --cl-info
    --cl-info-border --cl-info-surface --cl-info-text --cl-leading-body
    --cl-leading-code --cl-leading-micro --cl-leading-panel --cl-leading-small
    --cl-leading-title --cl-neutral-border --cl-neutral-surface --cl-neutral-text
    --cl-on-primary --cl-overlay --cl-page-gutter --cl-primary
    --cl-primary-hover --cl-primary-text --cl-radius-full --cl-radius-lg
    --cl-radius-md --cl-radius-sm --cl-radius-xs --cl-rail-width --cl-shadow
    --cl-shadow-1 --cl-shadow-2 --cl-shadow-3 --cl-shadow-4 --cl-shadow-card
    --cl-shadow-modal --cl-shadow-overlay --cl-shadow-raised --cl-space-0
    --cl-space-1 --cl-space-10 --cl-space-11 --cl-space-2 --cl-space-3
    --cl-space-4 --cl-space-5 --cl-space-6 --cl-space-7 --cl-space-8
    --cl-space-9 --cl-space-gutter --cl-space-inline --cl-space-stack
    --cl-stagger --cl-success --cl-success-border --cl-success-surface
    --cl-success-text --cl-surface --cl-surface-raised --cl-surface-sunken
    --cl-text --cl-text-muted --cl-text-soft --cl-warning --cl-warning-bg
    --cl-warning-border --cl-warning-surface --cl-warning-text --cl-weight-medium
    --cl-weight-regular --cl-weight-semibold --cl-z-base --cl-z-dropdown
    --cl-z-modal --cl-z-overlay --cl-z-popover --cl-z-sticky --cl-z-toast
  )

  @selected_root_values %{
    "--cl-color-basalt" => "#141B19",
    "--cl-color-trailpaper" => "#F4EEE2",
    "--cl-color-warm-stone" => "#FAF5EB",
    "--cl-color-path-copper" => "#A8492A",
    "--cl-color-slate-lichen" => "#5E665D",
    "--cl-primary" => "#A8492A",
    "--cl-focus" => "#A8492A",
    "--cl-danger-button-text" => "#FFFFFF"
  }

  @selected_dark_values %{
    "--cl-primary" => "#D98A4A",
    "--cl-focus" => "#D98A4A",
    "--cl-danger" => "#C96A55",
    "--cl-danger-button-text" => "#141B19"
  }

  @primitive_pairs %{
    "basalt" => "--cl-color-basalt",
    "moss_ink" => "--cl-color-moss-ink",
    "trailpaper" => "--cl-color-trailpaper",
    "warm_stone" => "--cl-color-warm-stone",
    "granite" => "--cl-color-granite",
    "slate_lichen" => "--cl-color-slate-lichen",
    "path_copper" => "--cl-color-path-copper",
    "copper_glow" => "--cl-color-copper-glow",
    "lichen" => "--cl-color-lichen",
    "deep_lichen" => "--cl-color-deep-lichen",
    "glacier_mist" => "--cl-color-glacier-mist",
    "waypoint_blue" => "--cl-color-waypoint-blue",
    "heather" => "--cl-color-heather",
    "ember" => "--cl-color-ember",
    "fault_clay" => "--cl-color-fault-clay"
  }

  @semantic_pairs %{
    "bg" => "--cl-bg",
    "surface" => "--cl-surface",
    "surface_raised" => "--cl-surface-raised",
    "text" => "--cl-text",
    "text_muted" => "--cl-text-muted",
    "border" => "--cl-border",
    "primary" => "--cl-primary",
    "primary_text" => "--cl-primary-text",
    "success" => "--cl-success",
    "info" => "--cl-info",
    "ai" => "--cl-ai",
    "warning" => "--cl-warning",
    "danger" => "--cl-danger",
    "focus" => "--cl-focus"
  }

  describe "TOKEN-02 canonical token contract" do
    test "all sealed --cl-* token names remain present and additive danger text token exists" do
      canonical = canonical_css()
      actual_tokens = declared_cl_tokens(canonical)
      missing = @expected_cl_tokens -- actual_tokens

      assert missing == [],
             """
             Missing sealed/additive token names in #{@canonical_path}: #{inspect(missing)}
             Next action: preserve existing --cl-* declarations and add only --cl-danger-button-text.
             """
    end

    test "canonical source contains selected Refined values" do
      root = canonical_root_tokens()
      dark = canonical_dark_tokens()

      for {token, expected} <- @selected_root_values do
        assert resolved(root, token) == expected,
               mismatch(
                 "selected Refined root token",
                 @canonical_path,
                 token,
                 expected,
                 resolved(root, token)
               )
      end

      for {token, expected} <- @selected_dark_values do
        assert resolved(dark, token) == expected,
               mismatch(
                 "selected Refined dark token",
                 @canonical_path,
                 token,
                 expected,
                 resolved(dark, token)
               )
      end
    end

    test "danger button reads the semantic danger text token" do
      css = canonical_css()

      assert css =~ ~r/\.cl-button--danger\s*\{[^}]*color:\s*var\(--cl-danger-button-text/s,
             """
             #{@canonical_path} .cl-button--danger still bypasses --cl-danger-button-text.
             Next action: use color: var(--cl-danger-button-text, #FFFFFF) so dark #C96A55 is not paired with white.
             """
    end
  end

  describe "TOKEN-03 derivative parity" do
    test "app.css @theme primitive values match canonical values exactly" do
      canonical = canonical_root_tokens()
      theme = app_theme_tokens()

      for canonical_token <- Map.values(@primitive_pairs) do
        derivative_token = String.replace(canonical_token, "--cl-color-", "--color-cl-")
        expected = resolved(canonical, canonical_token)

        assert theme[derivative_token] == expected,
               mismatch(
                 "@theme primitive drift",
                 @app_path,
                 derivative_token,
                 expected,
                 theme[derivative_token]
               )
      end
    end

    test "app.css expressed light and dark --cl-* values match canonical exactly" do
      assert_derivative_css_parity(app_root_tokens(), canonical_root_tokens(), @app_path)
      assert_derivative_css_parity(app_dark_tokens(), canonical_dark_tokens(), @app_path)
    end

    test "tokens.json primitive and semantic values match canonical resolved values exactly" do
      root = canonical_root_tokens()
      dark = canonical_dark_tokens()
      tokens = tokens_json()

      for {json_key, canonical_token} <- @primitive_pairs do
        expected = resolved(root, canonical_token)
        actual = get_in(tokens, ["color", "primitive", json_key, "value"])

        assert actual == expected,
               mismatch("tokens.json primitive drift", @tokens_path, json_key, expected, actual)
      end

      for {json_key, canonical_token} <- @semantic_pairs do
        expected = resolved(root, canonical_token)
        actual = get_in(tokens, ["color", "semantic_light", json_key])

        assert actual == expected,
               mismatch(
                 "tokens.json light semantic drift",
                 @tokens_path,
                 json_key,
                 expected,
                 actual
               )
      end

      for {json_key, canonical_token} <- @semantic_pairs do
        expected = resolved(dark, canonical_token)
        actual = get_in(tokens, ["color", "semantic_dark", json_key])

        assert actual == expected,
               mismatch(
                 "tokens.json dark semantic drift",
                 @tokens_path,
                 json_key,
                 expected,
                 actual
               )
      end
    end

    test "app.css closes Phase 46 shadow drift" do
      assert app_root_tokens()["--cl-shadow-raised"] == "var(--cl-shadow-1)",
             """
             #{@app_path} still carries Phase 46 shadow drift for --cl-shadow-raised.
             Expected: var(--cl-shadow-1)
             Actual:   #{inspect(app_root_tokens()["--cl-shadow-raised"])}
             Next action: replace the derivative literal with the canonical alias.
             """
    end
  end

  describe "TOKEN-04 Phase 46 contrast rows" do
    test "meaningful text rows meet AA and route markers/focus indicators meet UI threshold" do
      root = canonical_root_tokens()
      dark = canonical_dark_tokens()

      rows = [
        {"Row 4 Light", root, "--cl-text-muted", "--cl-bg", 4.5, "normal text"},
        {"Row 13 Light", root, "--cl-danger-button-text", "--cl-danger", 4.5,
         "danger button text"},
        {"Row 13 Dark", dark, "--cl-danger-button-text", "--cl-danger", 4.5,
         "dark danger button text"},
        {"Row 14 Light", root, "--cl-text-muted", "--cl-surface-sunken", 4.5,
         "ghost/nav muted text"},
        {"Row 22 Light", root, "--cl-neutral-text", "--cl-neutral-surface", 4.5,
         "neutral chip text"},
        {"Row 24 Light", root, "--cl-border", "--cl-surface-raised", 3.0, "input boundary"},
        {"Row 25 Dark", dark, "--cl-border-strong", "--cl-surface", 3.0, "hover boundary"},
        {"Row 29 Light", root, "--cl-focus", "--cl-surface", 3.0, "focus ring"},
        {"Row 29 Dark", dark, "--cl-focus", "--cl-surface", 3.0, "focus ring"},
        {"CU-L-3", root, "--cl-color-path-copper", "--cl-bg", 3.0, "copper UI route-marker"},
        {"CU-L-4.5", root, "--cl-color-path-copper", "--cl-bg", 4.5, "copper text route-marker"},
        {"CU-D-3", dark, "--cl-primary", "--cl-bg", 3.0, "dark copper UI route-marker"},
        {"CU-D-4.5", dark, "--cl-primary", "--cl-bg", 4.5, "dark copper text route-marker"}
      ]

      for {row_id, tokens, fg_token, bg_token, threshold, role} <- rows do
        assert_contrast(row_id, tokens, fg_token, bg_token, threshold, role)
      end
    end
  end

  defp assert_derivative_css_parity(derivative, canonical, file) do
    for {token, actual} <- derivative,
        String.starts_with?(token, "--cl-color-") or
          MapSet.member?(MapSet.new(Map.values(@semantic_pairs)), token) do
      expected = resolved(canonical, token)

      assert actual == canonical[token] or actual == expected,
             mismatch(
               "app.css expressed value drift",
               file,
               token,
               canonical[token] || expected,
               actual
             )
    end
  end

  defp assert_contrast(row_id, tokens, fg_token, bg_token, threshold, role) do
    fg = resolved(tokens, fg_token)
    bg = resolved(tokens, bg_token)
    ratio = contrast(fg, bg)

    assert ratio >= threshold,
           """
           #{row_id} contrast failure (#{role})
           File: #{@canonical_path}
           FG: #{fg_token} #{inspect(fg)}
           BG: #{bg_token} #{inspect(bg)}
           Ratio: #{Float.round(ratio, 2)}
           Threshold: #{threshold}
           Next action: adjust the token pair or document the row as decorative if it is not meaningful UI/text.
           """
  end

  defp declared_cl_tokens(css) do
    ~r/--cl-[a-z0-9-]+\s*:/
    |> Regex.scan(css)
    |> List.flatten()
    |> Enum.map(&String.trim_trailing(&1, ":"))
    |> Enum.sort()
    |> Enum.uniq()
  end

  defp canonical_css, do: File.read!(Path.join(File.cwd!(), @canonical_path))
  defp app_css, do: File.read!(Path.join(File.cwd!(), @app_path))

  defp canonical_root_tokens, do: canonical_css() |> css_block(":root") |> declarations()

  defp canonical_dark_tokens,
    do: canonical_css() |> css_block(~s([data-theme="dark"])) |> declarations()

  defp app_root_tokens, do: app_css() |> css_block(":root") |> declarations()
  defp app_dark_tokens, do: app_css() |> css_block(~s([data-theme="dark"])) |> declarations()
  defp app_theme_tokens, do: app_css() |> css_block("@theme") |> declarations()

  defp css_block(css, selector) do
    pattern = ~r/#{Regex.escape(selector)}\s*\{(?<block>.*?)^\s*\}/ms

    captures = Regex.named_captures(pattern, css) || flunk("Missing CSS block #{selector}")

    Map.fetch!(captures, "block")
  end

  defp declarations(block) do
    ~r/(--(?:cl|color-cl)-[a-z0-9-]+)\s*:\s*([^;]+);/
    |> Regex.scan(block)
    |> Map.new(fn [_match, token, value] -> {token, String.trim(value)} end)
  end

  defp resolved(tokens, token), do: resolved(tokens, token, MapSet.new())

  defp resolved(tokens, token, seen) do
    value = Map.fetch!(tokens, token)

    case Regex.run(~r/^var\((--cl-[a-z0-9-]+)\)$/, value) do
      [_, alias_token] ->
        if MapSet.member?(seen, alias_token) do
          flunk("Circular token alias while resolving #{token}: #{inspect(MapSet.to_list(seen))}")
        else
          resolved(tokens, alias_token, MapSet.put(seen, token))
        end

      _ ->
        value
    end
  end

  defp tokens_json do
    @tokens_path
    |> then(&Path.join(File.cwd!(), &1))
    |> File.read!()
    |> Jason.decode!()
  end

  defp contrast(fg, bg) do
    fg_lum = luminance(fg)
    bg_lum = luminance(bg)
    (max(fg_lum, bg_lum) + 0.05) / (min(fg_lum, bg_lum) + 0.05)
  end

  defp luminance("#" <> hex) do
    hex
    |> String.graphemes()
    |> Enum.chunk_every(2)
    |> Enum.map(fn pair ->
      pair
      |> Enum.join()
      |> String.to_integer(16)
      |> Kernel./(255)
      |> linearized_channel()
    end)
    |> then(fn [r, g, b] -> 0.2126 * r + 0.7152 * g + 0.0722 * b end)
  end

  defp linearized_channel(channel) when channel <= 0.03928, do: channel / 12.92
  defp linearized_channel(channel), do: :math.pow((channel + 0.055) / 1.055, 2.4)

  defp mismatch(kind, file, token, expected, actual) do
    """
    #{kind}
    File: #{file}
    Token/key: #{token}
    Expected: #{inspect(expected)}
    Actual:   #{inspect(actual)}
    Next action: update the derivative or canonical token so Phase 48 has zero drift.
    """
  end
end
