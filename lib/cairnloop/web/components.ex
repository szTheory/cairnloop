defmodule Cairnloop.Web.Components do
  @moduledoc """
  Cairnloop's shared operator-UI component library.

  Stateless `Phoenix.Component` function components that render the design
  system's `.cl-*` classes. The styling itself ships in `priv/static/cairnloop.css`
  (self-contained, token-driven, themeable) — these components only emit markup, so
  the CSS file is the single source of visual truth.

  Import into a LiveView with `import Cairnloop.Web.Components` and compose:

      <.cl_button variant="primary" phx-click="save">Save policy</.cl_button>
      <.cl_chip variant="warning" label="Needs review" />
      <.cl_card>…</.cl_card>

  Design rules enforced here (so screens can't re-introduce drift):

    * **Never state-by-color-alone** (brand §7.5) — `cl_chip`/`cl_banner` always pair
      a status color with a distinct-silhouette icon and a text label.
    * **Self-contained icons** — `cl_icon` is an inline SVG set, so the library never
      requires the host to install heroicons or an icon font.
    * **Tokens only** — components carry semantic `.cl-*` classes; spacing/color/motion
      come from `--cl-*` custom properties, never inline hex.
  """
  use Phoenix.Component

  @status_variants ~w(success info warning danger ai neutral)

  @doc "Primary/secondary/danger/ghost button. Buttons and inputs share token heights."
  attr(:variant, :string, default: "default", values: ~w(default primary danger ghost))
  attr(:size, :string, default: "md", values: ~w(sm md lg))
  attr(:type, :string, default: "button")
  attr(:class, :string, default: nil)

  attr(:rest, :global,
    include: ~w(disabled form name value phx-click phx-value-id phx-disable-with data-confirm)
  )

  slot(:inner_block, required: true)

  def cl_button(assigns) do
    ~H"""
    <button type={@type} class={["cl-button", variant_class("cl-button", @variant), size_class("cl-button", @size), @class]} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc "Surface card. Optional `:header` slot renders a bordered title row; `route_active` adds the copper rail marker."
  attr(:class, :string, default: nil)
  attr(:route_active, :boolean, default: false)
  attr(:rest, :global)
  slot(:header)
  slot(:inner_block, required: true)

  def cl_card(assigns) do
    ~H"""
    <section class={["cl-card", @route_active && "cl-route-active", @class]} {@rest}>
      <header :if={@header != []} class="cl-card__header">{render_slot(@header)}</header>
      <div class="cl-card__body">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  @doc """
  Status chip — color + icon + text together (never color alone). `label` or an
  inner block supplies the text; the icon is chosen from the variant unless overridden.
  """
  attr(:variant, :string, default: "neutral", values: @status_variants)
  attr(:label, :string, default: nil)
  attr(:icon, :string, default: nil)
  attr(:class, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block)

  def cl_chip(assigns) do
    assigns =
      assign_new(assigns, :resolved_icon, fn -> assigns.icon || status_icon(assigns.variant) end)

    ~H"""
    <span class={["cl-chip", "cl-chip--#{@variant}", @class]} {@rest}>
      <.cl_icon name={@resolved_icon} class="cl-chip__icon" />
      <span>{@label}{render_slot(@inner_block)}</span>
    </span>
    """
  end

  @doc "Persistent, region-level status banner (use for actionable status, not transient confirmations)."
  attr(:variant, :string, default: "neutral", values: @status_variants)
  attr(:icon, :string, default: nil)
  attr(:class, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def cl_banner(assigns) do
    assigns =
      assign_new(assigns, :resolved_icon, fn -> assigns.icon || status_icon(assigns.variant) end)

    ~H"""
    <div class={["cl-banner", "cl-banner--#{@variant}", @class]} role="status" {@rest}>
      <.cl_icon name={@resolved_icon} class="cl-banner__icon" />
      <div>{render_slot(@inner_block)}</div>
    </div>
    """
  end

  @doc "Calm, reassuring empty state. `:icon` slot optional; `title` + inner block carry the copy."
  attr(:title, :string, required: true)
  attr(:icon, :string, default: "compass")
  attr(:class, :string, default: nil)
  slot(:inner_block)

  def cl_empty(assigns) do
    ~H"""
    <div class={["cl-empty", @class]}>
      <.cl_icon name={@icon} size="28" class="cl-empty__icon" />
      <p class="cl-empty__title">{@title}</p>
      <div :if={@inner_block != []}>{render_slot(@inner_block)}</div>
    </div>
    """
  end

  @doc """
  Cockpit Home job card — a verb-led job, ONE actionable "needs-you" count, and a CTA.
  `calm?` renders the count in the success hue (used for the all-caught-up zero state).
  """
  attr(:job, :string, required: true)
  attr(:count, :integer, required: true)
  attr(:meta, :string, default: nil)
  attr(:href, :string, default: nil)
  attr(:cta, :string, default: nil)
  attr(:icon, :string, default: nil)
  attr(:calm?, :boolean, default: false)
  attr(:rest, :global)
  slot(:inner_block)

  def cl_stat(assigns) do
    ~H"""
    <.link navigate={@href} class="cl-stat cl-focusable" {@rest}>
      <span class="cl-stat__job">
        <.cl_icon :if={@icon} name={@icon} class="cl-chip__icon" /> {@job}
      </span>
      <span class={["cl-stat__count", @calm? && "cl-stat__count--calm"]}>{@count}</span>
      <span :if={@meta} class="cl-stat__meta">{@meta}</span>
      <span :if={@cta} class="cl-stat__meta">{@cta} &rarr;</span>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Persistent navigation shell. Pass `current` (a destination key) so the active link
  gets a 3-cue "you are here" state (weight + copper underline + fill, never color alone).
  `destinations` is a list of `%{key, label, href, icon, count}` maps.
  """
  attr(:current, :atom, default: nil)
  attr(:destinations, :list, required: true)
  attr(:brand, :string, default: "Cairnloop")
  slot(:inner_block, required: true)

  def cl_shell(assigns) do
    ~H"""
    <div class="cl-app">
      <div class="cl-shell">
        <nav class="cl-nav" aria-label="Cairnloop sections">
          <span class="cl-nav__brand">
            <.cl_icon name="cairn" class="cl-nav__brand-mark" /> {@brand}
          </span>
          <div class="cl-nav__links">
            <.link
              :for={d <- @destinations}
              navigate={d.href}
              class="cl-nav__link"
              aria-current={@current == d.key && "page"}
            >
              <.cl_icon :if={d[:icon]} name={d.icon} class="cl-chip__icon" />
              {d.label}
              <.cl_chip :if={d[:count] && d.count > 0} variant="neutral" label={to_string(d.count)} />
            </.link>
          </div>
        </nav>
        <main class="cl-main">{render_slot(@inner_block)}</main>
      </div>
    </div>
    """
  end

  @doc "Breadcrumb trail (renders after the user goes a level deep)."
  attr(:items, :list,
    required: true,
    doc: "list of %{label, href} (last item is current, no href)"
  )

  def cl_breadcrumb(assigns) do
    ~H"""
    <nav class="cl-breadcrumb" aria-label="Breadcrumb">
      <%= for {item, idx} <- Enum.with_index(@items) do %>
        <span :if={idx > 0} class="cl-breadcrumb__sep" aria-hidden="true">/</span>
        <.link :if={item[:href]} navigate={item.href}>{item.label}</.link>
        <span :if={is_nil(item[:href])} aria-current="page">{item.label}</span>
      <% end %>
    </nav>
    """
  end

  @doc """
  Self-contained inline-SVG icon. Distinct silhouettes so status reads without color
  (colorblind-safe, grayscale-safe). 16px default; `size` overrides.
  """
  attr(:name, :string, required: true)
  attr(:size, :string, default: "16")
  attr(:class, :string, default: nil)
  attr(:rest, :global)

  def cl_icon(assigns) do
    ~H"""
    <svg
      class={["cl-icon", @class]}
      width={@size}
      height={@size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
      focusable="false"
      {@rest}
    >
      {Phoenix.HTML.raw(icon_paths(@name))}
    </svg>
    """
  end

  # ---- helpers ------------------------------------------------------------

  defp variant_class(_base, "default"), do: nil
  defp variant_class(base, variant), do: "#{base}--#{variant}"

  defp size_class(_base, "md"), do: nil
  defp size_class(base, size), do: "#{base}--#{size}"

  # Distinct-silhouette icon per status (triangle vs circle vs octagon-ish).
  defp status_icon("success"), do: "check-circle"
  defp status_icon("info"), do: "info"
  defp status_icon("warning"), do: "alert-triangle"
  defp status_icon("danger"), do: "x-circle"
  defp status_icon("ai"), do: "waypoint"
  defp status_icon(_), do: "clock"

  # Minimal stroke-icon set (feather-style). Distinct silhouettes for a11y.
  defp icon_paths("check-circle"),
    do:
      ~s(<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>)

  defp icon_paths("x-circle"),
    do:
      ~s(<circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>)

  defp icon_paths("alert-triangle"),
    do:
      ~s(<path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>)

  defp icon_paths("info"),
    do:
      ~s(<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>)

  defp icon_paths("clock"),
    do: ~s(<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>)

  # waypoint / route marker (brand motif) — a pin on a path
  defp icon_paths("waypoint"),
    do:
      ~s(<circle cx="12" cy="10" r="3"/><path d="M12 2a8 8 0 0 0-8 8c0 5.4 8 12 8 12s8-6.6 8-12a8 8 0 0 0-8-8z"/>)

  # cairn (brand mark) — stacked stones
  defp icon_paths("cairn"),
    do:
      ~s(<ellipse cx="12" cy="19" rx="6" ry="2"/><rect x="8" y="12" width="8" height="4" rx="1.5"/><rect x="9.5" y="7.5" width="5" height="3.5" rx="1.3"/><rect x="10.5" y="4" width="3" height="3" rx="1"/>)

  defp icon_paths("compass"),
    do:
      ~s(<circle cx="12" cy="12" r="10"/><polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"/>)

  defp icon_paths("home"),
    do:
      ~s(<path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>)

  defp icon_paths("inbox"),
    do:
      ~s(<polyline points="22 12 16 12 14 15 10 15 8 12 2 12"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/>)

  defp icon_paths("book"),
    do:
      ~s(<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>)

  defp icon_paths("shield"),
    do: ~s(<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>)

  defp icon_paths("gear"),
    do:
      ~s(<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>)

  defp icon_paths("search"),
    do: ~s(<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>)

  defp icon_paths("chevron-right"), do: ~s(<polyline points="9 18 15 12 9 6"/>)

  defp icon_paths("arrow-right"),
    do: ~s(<line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>)

  defp icon_paths("external"),
    do:
      ~s(<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/>)

  defp icon_paths("dot"), do: ~s(<circle cx="12" cy="12" r="4"/>)
  defp icon_paths(_unknown), do: icon_paths("dot")
end
