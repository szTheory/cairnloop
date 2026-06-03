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
  """

  use Phoenix.Component

  attr(:current, :atom, required: true)

  def kb_nav(assigns) do
    ~H"""
    <nav
      aria-label="Knowledge base"
      class="cl-tabs"
      style="padding: 0 24px; background: var(--cl-surface);"
    >
      <.kb_nav_link to="/knowledge-base" label="Knowledge base" active={@current == :index} />
      <.kb_nav_link to="/knowledge-base/suggestions" label="Suggestions" active={@current == :suggestions} />
      <.kb_nav_link to="/knowledge-base/gaps" label="Gaps" active={@current == :gaps} />
    </nav>
    """
  end

  attr(:to, :string, required: true)
  attr(:label, :string, required: true)
  attr(:active, :boolean, default: false)

  defp kb_nav_link(assigns) do
    ~H"""
    <.link
      navigate={@to}
      aria-current={if @active, do: "page"}
      aria-selected={to_string(@active)}
      class="cl-tab"
    >
      {@label}
    </.link>
    """
  end
end
