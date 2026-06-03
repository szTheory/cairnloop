defmodule Cairnloop.Web.Nav do
  @moduledoc """
  The single source of truth for the operator dashboard's top-level navigation.

  Every dashboard screen renders the same persistent nav shell from this list, so
  "you are here" stays consistent and no screen invents its own chrome. Labels use
  the operator's words (not internal jargon); ~5 destinations keeps the IA legible
  (GDS "do less"). Counts are intentionally omitted here — the Cockpit Home owns the
  live "needs-you" numbers so each screen's nav stays a cheap, query-free constant.
  """

  @destinations [
    %{key: :home, label: "Home", href: "/", icon: "home"},
    %{key: :inbox, label: "Inbox", href: "/inbox", icon: "inbox"},
    %{key: :knowledge, label: "Knowledge", href: "/knowledge-base", icon: "book"},
    %{key: :audit, label: "Audit", href: "/audit-log", icon: "shield"},
    %{key: :settings, label: "Settings", href: "/settings", icon: "gear"}
  ]

  @doc "The ordered top-level destinations for the persistent nav shell."
  @spec destinations() :: [map()]
  def destinations, do: @destinations
end
