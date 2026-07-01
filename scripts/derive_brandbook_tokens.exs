defmodule Cairnloop.BrandbookTokens do
  @moduledoc false

  @source_path "priv/static/cairnloop.css"
  @tokens_path "brandbook/assets/css/tokens.css"
  @swatches_path "brandbook/color/swatches.json"
  @generate_command "mix run scripts/derive_brandbook_tokens.exs"
  @check_command "mix run scripts/derive_brandbook_tokens.exs --check"

  @semantic_tokens ~w(
    --cl-bg --cl-surface --cl-surface-raised --cl-surface-sunken --cl-text
    --cl-text-muted --cl-text-soft --cl-border --cl-border-strong --cl-primary
    --cl-primary-hover --cl-primary-text --cl-on-primary --cl-danger-button-text
    --cl-success --cl-info --cl-ai --cl-warning --cl-danger --cl-focus
    --cl-overlay --cl-success-surface --cl-success-border --cl-success-text
    --cl-info-surface --cl-info-border --cl-info-text --cl-warning-surface
    --cl-warning-border --cl-warning-text --cl-warning-bg --cl-danger-surface
    --cl-danger-border --cl-danger-text --cl-danger-soft --cl-ai-surface
    --cl-ai-border --cl-ai-text --cl-neutral-surface --cl-neutral-border
    --cl-neutral-text
  )

  @primitive_descriptions %{
    "--cl-color-basalt" => "core text / dark surface",
    "--cl-color-moss-ink" => "secondary dark / deep UI",
    "--cl-color-trailpaper" => "main canvas",
    "--cl-color-warm-stone" => "card surface",
    "--cl-color-granite" => "quiet border",
    "--cl-color-slate-lichen" => "muted text / disabled",
    "--cl-color-path-copper" => "primary action / active route",
    "--cl-color-copper-glow" => "decorative accent only",
    "--cl-color-lichen" => "success accent / safe sourced answer",
    "--cl-color-deep-lichen" => "success text / positive state",
    "--cl-color-glacier-mist" => "info surface / retrieval panel",
    "--cl-color-waypoint-blue" => "info text / links when needed",
    "--cl-color-heather" => "AI/eval accent",
    "--cl-color-ember" => "warning text / budget risk",
    "--cl-color-fault-clay" => "danger text / blocked policy"
  }

  @semantic_descriptions %{
    "--cl-bg" => "page canvas",
    "--cl-surface" => "default surface",
    "--cl-surface-raised" => "raised surface",
    "--cl-surface-sunken" => "sunken surface",
    "--cl-text" => "primary text",
    "--cl-text-muted" => "secondary text",
    "--cl-text-soft" => "soft metadata text",
    "--cl-border" => "default boundary",
    "--cl-border-strong" => "emphasized boundary",
    "--cl-primary" => "primary copper route marker",
    "--cl-primary-hover" => "primary hover",
    "--cl-primary-text" => "text on primary",
    "--cl-on-primary" => "alias for text on primary",
    "--cl-danger-button-text" => "text on danger button",
    "--cl-success" => "success state",
    "--cl-info" => "information state",
    "--cl-ai" => "AI/evaluation state",
    "--cl-warning" => "warning state",
    "--cl-danger" => "danger state",
    "--cl-focus" => "focus indicator",
    "--cl-overlay" => "overlay scrim",
    "--cl-success-surface" => "success surface",
    "--cl-success-border" => "success boundary",
    "--cl-success-text" => "success text",
    "--cl-info-surface" => "info surface",
    "--cl-info-border" => "info boundary",
    "--cl-info-text" => "info text",
    "--cl-warning-surface" => "warning surface",
    "--cl-warning-border" => "warning boundary",
    "--cl-warning-text" => "warning text",
    "--cl-warning-bg" => "legacy warning surface alias",
    "--cl-danger-surface" => "danger surface",
    "--cl-danger-border" => "danger boundary",
    "--cl-danger-text" => "danger text",
    "--cl-danger-soft" => "legacy danger surface alias",
    "--cl-ai-surface" => "AI surface",
    "--cl-ai-border" => "AI boundary",
    "--cl-ai-text" => "AI text",
    "--cl-neutral-surface" => "neutral surface",
    "--cl-neutral-border" => "neutral boundary",
    "--cl-neutral-text" => "neutral text"
  }

  def run(argv) do
    check? = "--check" in argv
    outputs = build_outputs()

    if check? do
      check_outputs!(outputs)
    else
      write_outputs!(outputs)
    end
  end

  def build_outputs do
    css = File.read!(repo_path(@source_path))
    root_entries = css |> css_block(":root") |> declarations()
    dark_entries = css |> css_block(~s([data-theme="dark"])) |> declarations()

    root_tokens = Map.new(root_entries)
    dark_tokens = Map.new(dark_entries)
    merged_tokens = Map.merge(root_tokens, dark_tokens)

    validate_groups!(root_entries, dark_entries, root_tokens, dark_tokens)

    %{
      @tokens_path => tokens_css(root_entries, dark_entries),
      @swatches_path => swatches_json(root_entries, dark_entries, root_tokens, merged_tokens)
    }
  end

  defp css_block(css, selector) do
    pattern = ~r/#{Regex.escape(selector)}\s*\{(?<block>.*?)^\s*\}/ms

    case Regex.named_captures(pattern, css) do
      %{"block" => block} -> block
      _ -> raise "Missing required CSS block #{selector} in #{@source_path}"
    end
  end

  defp declarations(block) do
    ~r/(--cl-[a-z0-9-]+)\s*:\s*([^;]+);/
    |> Regex.scan(block)
    |> Enum.map(fn [_match, token, value] -> {token, value |> String.trim() |> compact_ws()} end)
  end

  defp compact_ws(value), do: Regex.replace(~r/\s+/, value, " ")

  defp validate_groups!(root_entries, dark_entries, root_tokens, dark_tokens) do
    primitive = Enum.filter(root_entries, fn {token, _value} -> String.starts_with?(token, "--cl-color-") end)
    semantic_light = Enum.filter(root_entries, fn {token, _value} -> token in @semantic_tokens end)
    semantic_dark = Enum.filter(dark_entries, fn {token, _value} -> token in @semantic_tokens end)

    if primitive == [], do: raise("No primitive --cl-color-* tokens found in #{@source_path} :root")
    if semantic_light == [], do: raise("No required semantic --cl-* tokens found in #{@source_path} :root")
    if semantic_dark == [], do: raise(~s(No required semantic --cl-* tokens found in #{@source_path} [data-theme="dark"]))

    for {tokens, label} <- [{root_tokens, ":root"}, {dark_tokens, ~s([data-theme="dark"])}],
        {token, value} <- tokens,
        String.starts_with?(value, "var(") do
      _ = resolve_display(tokens, token, MapSet.new(), label)
    end
  end

  defp tokens_css(root_entries, dark_entries) do
    """
    /*
      Generated from #{@source_path}.
      Regenerate with: #{@generate_command}
      Check drift with: #{@check_command}
      Do not edit by hand.
    */

    :root {
    #{format_declarations(root_entries)}
    }

    [data-theme="dark"] {
    #{format_declarations(dark_entries)}
    }
    """
  end

  defp format_declarations(entries) do
    entries
    |> Enum.map_join("\n", fn {token, value} -> "  #{String.pad_trailing(token <> ":", 26)} #{value};" end)
  end

  defp swatches_json(root_entries, dark_entries, root_tokens, merged_tokens) do
    primitive =
      root_entries
      |> Enum.filter(fn {token, _value} -> String.starts_with?(token, "--cl-color-") end)
      |> Enum.map(fn {token, value} ->
        swatch_row(token, value, "primitive", "light", root_tokens, @primitive_descriptions)
      end)

    semantic_light =
      root_entries
      |> Enum.filter(fn {token, _value} -> token in @semantic_tokens end)
      |> Enum.map(fn {token, value} ->
        swatch_row(token, value, "semantic_light", "light", root_tokens, @semantic_descriptions)
      end)

    semantic_dark =
      dark_entries
      |> Enum.filter(fn {token, _value} -> token in @semantic_tokens end)
      |> Enum.map(fn {token, value} ->
        swatch_row(token, value, "semantic_dark", "dark", merged_tokens, @semantic_descriptions)
      end)

    %{
      schema_version: 1,
      source_file: @source_path,
      generated_by: @generate_command,
      check_command: @check_command,
      groups: %{
        primitive: primitive,
        semantic_light: semantic_light,
        semantic_dark: semantic_dark
      }
    }
    |> Jason.encode!(pretty: true)
    |> Kernel.<>("\n")
  end

  defp swatch_row(token, value, group, theme, tokens, descriptions) do
    %{
      token: token,
      value: value,
      group: group,
      role: Map.get(descriptions, token, token |> String.trim_leading("--cl-") |> String.replace("-", " ")),
      theme: theme,
      display_hex: display_hex(tokens, token)
    }
  end

  defp display_hex(tokens, token) do
    resolved = resolve_display(tokens, token, MapSet.new(), "swatches.json")

    if Regex.match?(~r/^#[0-9a-fA-F]{6}$/, resolved), do: String.upcase(resolved), else: nil
  end

  defp resolve_display(tokens, token, seen, label) do
    value = Map.fetch!(tokens, token)

    case Regex.run(~r/^var\((--cl-[a-z0-9-]+)\)$/, value) do
      [_, alias_token] ->
        cond do
          MapSet.member?(seen, token) ->
            raise "Circular token alias while resolving #{token} in #{label}: #{inspect(MapSet.to_list(seen))}"

          not Map.has_key?(tokens, alias_token) ->
            raise "Unresolved token alias #{token} -> #{alias_token} in #{label}"

          true ->
            resolve_display(tokens, alias_token, MapSet.put(seen, token), label)
        end

      _ ->
        value
    end
  end

  defp write_outputs!(outputs) do
    for {path, bytes} <- outputs do
      full_path = repo_path(path)
      full_path |> Path.dirname() |> File.mkdir_p!()
      File.write!(full_path, bytes)
      Mix.shell().info("wrote #{path}")
    end
  end

  defp check_outputs!(outputs) do
    for {path, expected} <- outputs do
      full_path = repo_path(path)

      unless File.exists?(full_path) do
        raise """
        Missing generated output: #{path}
        Next action: run #{@generate_command}, then rerun #{@check_command}.
        """
      end

      actual = File.read!(full_path)

      unless actual == expected do
        raise """
        Generated output drift: #{path}
        Expected bytes do not match committed bytes.
        Next action: run #{@generate_command}, review the diff, then rerun #{@check_command}.
        """
      end
    end

    Mix.shell().info("brandbook token outputs are current")
  end

  defp repo_path(path), do: Path.join(File.cwd!(), path)
end

Cairnloop.BrandbookTokens.run(System.argv())
