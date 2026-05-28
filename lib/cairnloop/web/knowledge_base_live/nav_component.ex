defmodule Cairnloop.Web.KnowledgeBaseLive.NavComponent do
  @moduledoc """
  Shared editorial nav function component for all four KB LiveViews.

  Renders a persistent horizontal sub-navigation with three links:
  Knowledge base, Suggestions, Gaps.

  Usage:
    <.kb_nav current={:index} />
    <.kb_nav current={:suggestions} />
    <.kb_nav current={:gaps} />
    <.kb_nav current={:editor} />

  The `:editor` value renders no active marker — Editor has no top-level nav entry.

  All CSS uses bare `var(--cl-<token>)` — no hex fallbacks (BRAND-04 gate).
  Active route is paired with `aria-current="page"` AND a primary border-bottom
  (never color alone — brand §7.5).
  """

  use Phoenix.Component

  attr :current, :atom, required: true

  def kb_nav(assigns) do
    ~H"""
    <nav
      aria-label="Knowledge base"
      style="background: var(--cl-surface); border-bottom: 1px solid var(--cl-border); padding: 0 24px; height: 48px; display: flex; align-items: center; gap: 8px;"
    >
      <.kb_nav_link to="/knowledge-base" label="Knowledge base" active={@current == :index} />
      <.kb_nav_link to="/knowledge-base/suggestions" label="Suggestions" active={@current == :suggestions} />
      <.kb_nav_link to="/knowledge-base/gaps" label="Gaps" active={@current == :gaps} />
    </nav>
    """
  end

  attr :to, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp kb_nav_link(assigns) do
    ~H"""
    <.link
      navigate={@to}
      aria-current={if @active, do: "page"}
      style={nav_link_style(@active)}
    >
      {@label}
    </.link>
    """
  end

  defp nav_link_style(true) do
    "padding: 12px 16px; font-size: 13px; font-weight: 600; color: var(--cl-text); text-decoration: none; border-bottom: 2px solid var(--cl-primary); letter-spacing: 0.015em;"
  end

  defp nav_link_style(false) do
    "padding: 12px 16px; font-size: 13px; font-weight: 600; color: var(--cl-text-muted); text-decoration: none; border-bottom: 2px solid transparent; letter-spacing: 0.015em;"
  end
end
