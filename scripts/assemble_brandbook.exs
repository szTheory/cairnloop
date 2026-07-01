defmodule Cairnloop.BrandbookAssembly do
  @moduledoc false

  @index_path "brandbook/index.html"
  @swatches_path "brandbook/color/swatches.json"
  @tokens_path "brandbook/assets/css/tokens.css"
  @logo_usage_path "logo/USAGE.md"
  @contrast_path ".planning/phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md"
  @archived_contrast_path ".planning/milestones/vM017-phases/48-token-evolution-lock-propagate/48-CONTRAST-REVERIFY.md"
  @prompt_path "prompts/cairnloop_brand_book.md"
  @generate_command "mix run scripts/assemble_brandbook.exs"
  @check_command "mix run scripts/assemble_brandbook.exs --check"
  @input_fallbacks %{@contrast_path => @archived_contrast_path}

  @required_inputs [
    @swatches_path,
    @tokens_path,
    @logo_usage_path,
    @contrast_path,
    @prompt_path
  ]

  @required_logo_assets ~w(
    cairnloop-lockup-horizontal.svg
    cairnloop-lockup-stacked.svg
    cairnloop-mark.svg
    cairnloop-lockup-horizontal-mono.svg
    cairnloop-lockup-horizontal-reverse.svg
    cairnloop-lockup-tagline.svg
    favicon.svg
    favicon-16.png
    favicon-32.png
    favicon.ico
    cairnloop-og.svg
    cairnloop-og.png
  )

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
    validate_inputs!()

    swatches = @swatches_path |> read!() |> Jason.decode!()
    logo_usage = read!(@logo_usage_path)
    contrast = read!(@contrast_path)

    validate_logo_assets!(logo_usage)
    validate_contrast_evidence!(contrast)

    tokens = @tokens_path |> read!() |> token_declarations()

    %{@index_path => index_html(swatches, tokens, logo_usage)}
  end

  defp validate_inputs! do
    for path <- @required_inputs do
      unless Enum.any?(candidate_paths(path), &File.exists?(repo_path(&1))) do
        raise """
        Missing required local input: #{path}
        Checked: #{Enum.join(candidate_paths(path), ", ")}
        Next action: restore the file, then run #{@generate_command}.
        """
      end
    end
  end

  defp validate_logo_assets!(usage) do
    for asset <- @required_logo_assets do
      unless usage =~ "`#{asset}`" and File.exists?(repo_path("logo/#{asset}")) do
        raise """
        Missing approved logo asset or inventory row: logo/#{asset}
        Next action: restore logo/#{asset} and its #{Path.basename(@logo_usage_path)} entry, then run #{@generate_command}.
        """
      end
    end
  end

  defp validate_contrast_evidence!(contrast) do
    for label <- ["PASS", "EXEMPT"] do
      unless contrast =~ label do
        raise "Missing Phase 48 contrast evidence label #{label} in #{@contrast_path}"
      end
    end
  end

  defp index_html(swatches, tokens, logo_usage) do
    primitive = swatches |> get_in(["groups", "primitive"]) |> Enum.take(12)
    semantic_light = swatches |> get_in(["groups", "semantic_light"]) |> Enum.take(16)
    semantic_dark = swatches |> get_in(["groups", "semantic_dark"]) |> Enum.take(16)

    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Cairnloop brand book</title>
        <link rel="stylesheet" href="./assets/css/tokens.css">
        <link rel="stylesheet" href="./assets/css/brandbook.css">
      </head>
      <body>
        <script>
          (function () {
            try {
              var saved = localStorage.getItem("cairnloop-brandbook-theme");
              if (saved === "dark") document.documentElement.dataset.theme = "dark";
            } catch (_error) {}
          })();
        </script>
        <main class="brandbook-shell">
          <header class="brandbook-header">
            <div class="brandbook-header__main">
              <div class="brandbook-kicker">Canonical source: priv/static/cairnloop.css :root</div>
              <h1 class="brandbook-title">Cairnloop brand book</h1>
              <p class="brandbook-display">Support that leaves a trail.</p>
              <p class="brandbook-copy">
                A standalone, file-ready reference for Cairnloop tokens, logo usage, copy patterns,
                imagery rules, motion guidance, and local downloads.
              </p>
            </div>
            <div class="brandbook-theme-toggle" aria-label="Theme">
              <button type="button" class="brandbook-theme-toggle__button" data-theme-choice="light" aria-pressed="true">Light</button>
              <button type="button" class="brandbook-theme-toggle__button" data-theme-choice="dark" aria-pressed="false">Dark</button>
            </div>
            <div class="brandbook-status-grid brandbook-status-grid--four" aria-label="Brand book status">
              <div class="brandbook-cell"><strong>Token status: derived from canonical CSS</strong><span>Generated from #{@tokens_path}</span></div>
              <div class="brandbook-cell"><strong>Network dependency: none</strong><span>Required content is committed HTML, CSS, SVG, PNG, ICO, and JSON.</span></div>
              <div class="brandbook-cell"><strong>Brandbook is git-tracked and unshipped</strong><span>Package boundary remains outside the Hex files allowlist.</span></div>
              <div class="brandbook-cell"><strong>Logo-family sign-off remains before Phase 52 wiring</strong><span>Phase 51 documents the assets; Phase 52 wires shipped surfaces.</span></div>
            </div>
          </header>

          <nav class="brandbook-section brandbook-contents" aria-label="Contents">
            <h2>Contents</h2>
            <ol class="brandbook-list">
              <li><a href="#color">Color</a></li>
              <li><a href="#typography">Typography</a></li>
              <li><a href="#tokens">Spacing, Radius, Shadow, Motion tokens</a></li>
              <li><a href="#logo">Logo system</a></li>
              <li><a href="#voice">Voice and Microcopy</a></li>
              <li><a href="#microcopy">Microcopy</a></li>
              <li><a href="#imagery">Imagery</a></li>
              <li><a href="#motion">Motion guidance</a></li>
              <li><a href="#downloads">Downloads</a></li>
            </ol>
          </nav>

          <section class="brandbook-section" id="color" aria-labelledby="color-heading">
            <h2 id="color-heading">Color</h2>
            <p>Canonical source: priv/static/cairnloop.css :root. Token status: derived from canonical CSS.</p>
            #{swatch_group("Primitive tokens", primitive, "Light")}
            #{swatch_group("Semantic light tokens", semantic_light, "Light")}
            #{swatch_group("Semantic dark tokens", semantic_dark, "Dark")}
            <div class="brandbook-status-grid">
              <div class="brandbook-cell"><strong>AA pass</strong><span>Meaningful text pairings from Phase 48 meet 4.5:1.</span></div>
              <div class="brandbook-cell"><strong>UI pass</strong><span>Focus, route-marker, and boundary pairings meet the UI threshold.</span></div>
              <div class="brandbook-cell"><strong>Decorative exempt</strong><span>Status chip outlines are decorative because text carries state.</span></div>
            </div>
          </section>

          <section class="brandbook-section" id="typography" aria-labelledby="typography-heading">
            <h2 id="typography-heading">Typography</h2>
            <p>Source: #{@tokens_path}. The committed SVG wordmark is the only logo wordmark rendering source.</p>
            <div class="brandbook-specimen-grid">
              #{type_specimen("--cl-font-display", "Title specimen", "Support that leaves a trail.", "Display/tagline specimens")}
              #{type_specimen("--cl-font-sans", "Panel specimen", "Review needed before sending.", "Panels, body, labels, and navigation")}
              #{type_specimen("--cl-font-mono", "Code specimen", "mix run scripts/assemble_brandbook.exs --check", "Token names, commands, and file paths")}
            </div>
          </section>

          <section class="brandbook-section" id="tokens" aria-labelledby="tokens-heading">
            <h2 id="tokens-heading">Spacing, Radius, Shadow, Motion tokens</h2>
            <p>Source: #{@tokens_path}. Use the token name, not copied raw values, when building Cairnloop UI.</p>
            #{token_table("Spacing", token_rows(tokens, "--cl-space-"), "brandbook-ruler")}
            #{token_table("Radius", token_rows(tokens, "--cl-radius-"), "brandbook-radius-chip")}
            #{token_table("Shadow", token_rows(tokens, "--cl-shadow-"), "brandbook-shadow-sample")}
            #{token_table("Motion", token_rows(tokens, "--cl-duration-") ++ token_rows(tokens, "--cl-ease-"), "brandbook-motion-sample")}
          </section>

          <section class="brandbook-section" id="logo" aria-labelledby="logo-heading">
            <h2 id="logo-heading">Logo system</h2>
            <p>Source: #{@logo_usage_path}. Use committed files as assets; do not redraw, recolor, or recreate the wordmark with live text.</p>
            <div class="brandbook-logo-gallery">
              #{logo_cards()}
            </div>
            <div class="brandbook-status-grid">
              <div class="brandbook-cell"><strong>Do</strong><span>#{usage_points(logo_usage, "## Do", "## Do not")}</span></div>
              <div class="brandbook-cell brandbook-cell--danger"><strong>Do not</strong><span>No rectangular cage. No chat bubble. No infinity symbol. No robot/headset trope. No loose icon-left-of-plain-text spacing. No subtitle on primary lockup. No live-text wordmark recreation.</span></div>
              <div class="brandbook-cell"><strong>Clearspace</strong><span>Use 1x where x = top stone/ring height.</span><span class="brandbook-clearspace">1x</span></div>
              <div class="brandbook-cell"><strong>Minimum sizes</strong><span>Icon 24px digital; favicon 16px digital; horizontal lockup 112px width digital; print icon 0.35in height.</span></div>
            </div>
            <div class="brandbook-size-row" aria-label="Logo size proofs">
              <img class="brandbook-logo-proof brandbook-logo-proof--16" src="../logo/favicon.svg" alt="16px favicon proof">
              <img class="brandbook-logo-proof brandbook-logo-proof--24" src="../logo/cairnloop-mark.svg" alt="24px mark proof">
              <img class="brandbook-logo-proof brandbook-logo-proof--48" src="../logo/cairnloop-mark.svg" alt="48px mark proof">
              <img class="brandbook-logo-proof brandbook-logo-proof--112" src="../logo/cairnloop-lockup-horizontal.svg" alt="112px lockup proof">
              <img class="brandbook-logo-proof brandbook-logo-proof--256" src="../logo/cairnloop-mark.svg" alt="256px mark proof">
            </div>
          </section>

          <section class="brandbook-section" id="voice" aria-labelledby="voice-heading">
            <h2 id="voice-heading">Voice</h2>
            <p>Source: #{@prompt_path}. Voice should be calm, specific, protective, and OSS-native.</p>
            <div class="brandbook-status-grid">
              <div class="brandbook-cell"><strong>Precise</strong><span>Use: Draft saved with source trail. Avoid: Your AI agent crushed it.</span></div>
              <div class="brandbook-cell"><strong>Calm</strong><span>Use: Review needed before sending. Avoid: Something went wrong!</span></div>
              <div class="brandbook-cell"><strong>Protective</strong><span>Use: Escalated because policy confidence is low. Avoid: Send anyway.</span></div>
              <div class="brandbook-cell"><strong>OSS-native</strong><span>Use: Regenerate tokens locally. Avoid: Configure the design cloud.</span></div>
            </div>
          </section>

          <section class="brandbook-section" id="microcopy" aria-labelledby="microcopy-heading">
            <h2 id="microcopy-heading">Microcopy</h2>
            <div class="brandbook-status-grid">
              <div class="brandbook-cell"><strong>CTA</strong><span>Download logo assets</span></div>
              <div class="brandbook-cell"><strong>Empty</strong><span>Brand book section unavailable. The source file for this section is missing.</span></div>
              <div class="brandbook-cell brandbook-cell--danger"><strong>Error</strong><span>Brandbook asset failed to load. Check relative paths, regenerate tokens from priv/static/cairnloop.css, and rerun the file-load verification.</span></div>
              <div class="brandbook-cell"><strong>Success</strong><span>AA pass. UI pass. Decorative exempt.</span></div>
            </div>
          </section>

          <section class="brandbook-section" id="imagery" aria-labelledby="imagery-heading">
            <h2 id="imagery-heading">Imagery</h2>
            <div class="brandbook-status-grid">
              <div class="brandbook-cell"><strong>Do</strong><span>Trail markers, topographic routes, material textures, operator workspace, product UI composites, abstract support loops.</span></div>
              <div class="brandbook-cell"><strong>Do not</strong><span>No headset agents, call centers, chat bubbles, robots, purple neural gradients, wellness pebble stacks, fantasy maps, or generic SaaS people.</span></div>
            </div>
          </section>

          <section class="brandbook-section" id="motion" aria-labelledby="motion-heading">
            <h2 id="motion-heading">Motion guidance</h2>
            <p>Use route, state, and progress motion sparingly. Transform and opacity only; honor reduced motion; avoid bouncy, chatbot, glowing, or layout-shifting motion.</p>
            <div class="brandbook-route-specimen" aria-label="Static route progress specimen">
              <span>Ask</span><span>Retrieve</span><span>Draft</span><span>Handoff</span><span>Improve</span>
            </div>
          </section>

          <section class="brandbook-section" id="downloads" aria-labelledby="downloads-heading">
            <h2 id="downloads-heading">Downloads</h2>
            <p><a href="../logo/cairnloop-lockup-horizontal.svg" download>Download logo assets</a></p>
            <ul class="brandbook-list">
              #{download_rows()}
            </ul>
          </section>

          <footer class="brandbook-footer" id="footer">
            <strong>Footer</strong>
            <span>Regenerate with: #{@generate_command}. Check drift with: #{@check_command}. Brandbook is git-tracked and unshipped. Phase 52 owns README, example app, favicon, and OG wiring.</span>
          </footer>
        </main>
        <script>
          (function () {
            var buttons = document.querySelectorAll("[data-theme-choice]");
            function setTheme(theme) {
              document.documentElement.dataset.theme = theme;
              buttons.forEach(function (button) {
                button.setAttribute("aria-pressed", String(button.dataset.themeChoice === theme));
              });
              try { localStorage.setItem("cairnloop-brandbook-theme", theme); } catch (_error) {}
            }
            buttons.forEach(function (button) {
              button.addEventListener("click", function () { setTheme(button.dataset.themeChoice); });
            });
            setTheme(document.documentElement.dataset.theme === "dark" ? "dark" : "light");
          })();
        </script>
      </body>
    </html>
    """
  end

  defp swatch_group(title, rows, fallback_theme) do
    """
    <h3>#{escape(title)}</h3>
    <div class="brandbook-token-grid">
      #{Enum.map_join(rows, "\n", &swatch_card(&1, fallback_theme))}
    </div>
    """
  end

  defp token_declarations(css) do
    ~r/(--cl-[a-z0-9-]+)\s*:\s*([^;]+);/
    |> Regex.scan(css)
    |> Enum.map(fn [_match, token, value] -> {token, value |> String.trim() |> compact_ws()} end)
    |> Enum.uniq_by(fn {token, _value} -> token end)
  end

  defp compact_ws(value), do: Regex.replace(~r/\s+/, value, " ")

  defp token_rows(tokens, prefix) do
    tokens
    |> Enum.filter(fn {token, _value} -> String.starts_with?(token, prefix) end)
    |> Enum.take(8)
  end

  defp token_table(title, rows, sample_class) do
    """
    <div class="brandbook-table-wrap">
      <h3>#{escape(title)}</h3>
      <table class="brandbook-table">
        <thead><tr><th>Specimen</th><th>Token</th><th>Value</th><th>Usage rule</th></tr></thead>
        <tbody>
          #{Enum.map_join(rows, "\n", fn {token, value} -> token_row(token, value, sample_class) end)}
        </tbody>
      </table>
    </div>
    """
  end

  defp token_row(token, value, sample_class) do
    """
    <tr>
      <td><span class="#{sample_class}" style="#{sample_style(sample_class, token)}"></span></td>
      <td><code>#{escape(token)}</code></td>
      <td><code>#{escape(value)}</code></td>
      <td>Use the token for Cairnloop UI; do not copy this value into a new palette.</td>
    </tr>
    """
  end

  defp sample_style("brandbook-ruler", token), do: "width: var(#{token});"
  defp sample_style("brandbook-radius-chip", token), do: "border-radius: var(#{token});"
  defp sample_style("brandbook-shadow-sample", token), do: "box-shadow: var(#{token});"
  defp sample_style("brandbook-motion-sample", _token), do: ""

  defp type_specimen(token, label, sample, usage) do
    """
    <div class="brandbook-type-card">
      <strong>#{escape(label)}</strong>
      <p style="font-family: var(#{token});">#{escape(sample)}</p>
      <code>#{escape(token)}</code>
      <span>#{escape(usage)}</span>
    </div>
    """
  end

  defp swatch_card(row, fallback_theme) do
    token = row["token"]
    value = row["display_hex"] || row["value"]
    role = row["role"]
    theme = row["theme"] || fallback_theme

    """
    <div class="brandbook-token">
      <div class="brandbook-swatch" style="background: var(#{escape(token)});"></div>
      <code>#{escape(token)}</code>
      <span>#{escape(value)}</span>
      <span>#{escape(role)}</span>
      <strong>#{escape(String.capitalize(to_string(theme)))}</strong>
    </div>
    """
  end

  defp logo_cards do
    Enum.with_index(@required_logo_assets)
    |> Enum.map_join("\n", fn {asset, index} ->
      size_class =
        case asset do
          "favicon-16.png" -> "brandbook-logo-card--16"
          "favicon-32.png" -> "brandbook-logo-card--24"
          "cairnloop-mark.svg" -> "brandbook-logo-card--48"
          "cairnloop-lockup-horizontal.svg" -> "brandbook-logo-card--112"
          _ when index > 8 -> "brandbook-logo-card--256"
          _ -> "brandbook-logo-card--112"
        end

      """
      <div class="brandbook-logo-card #{size_class}">
        <img src="../logo/#{asset}" alt="#{asset}" loading="lazy">
        <code>#{asset}</code>
        <a href="../logo/#{asset}" download>Download</a>
      </div>
      """
    end)
  end

  defp download_rows do
    Enum.map_join(@required_logo_assets, "\n", fn asset ->
      ~s(<li><a href="../logo/#{asset}" download>../logo/#{asset}</a><span>approved local asset</span></li>)
    end)
  end

  defp usage_points(usage, from, until_heading) do
    usage
    |> String.split(from, parts: 2)
    |> List.last()
    |> String.split(until_heading, parts: 2)
    |> List.first()
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "- "))
    |> Enum.take(3)
    |> Enum.map_join(" ", fn "- " <> point -> point end)
    |> escape()
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

    Mix.shell().info("brandbook assembled output is current")
  end

  defp read!(path), do: path |> existing_repo_path!() |> File.read!()

  defp existing_repo_path!(path) do
    path
    |> candidate_paths()
    |> Enum.find(&File.exists?(repo_path(&1)))
    |> case do
      nil -> repo_path(path)
      found -> repo_path(found)
    end
  end

  defp candidate_paths(path),
    do: [path, Map.get(@input_fallbacks, path)] |> Enum.reject(&is_nil/1)

  defp repo_path(path), do: Path.join(File.cwd!(), path)

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace(~s("), "&quot;")
  end
end

Cairnloop.BrandbookAssembly.run(System.argv())
