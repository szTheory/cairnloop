defmodule Cairnloop.Web.DashboardPath do
  @moduledoc false

  def from_session(session) when is_map(session) do
    session["cairnloop_dashboard_path"] || session[:cairnloop_dashboard_path] || ""
  end

  def from_session(_session), do: ""

  def to(prefix, path) when is_binary(path) do
    prefix = normalize_prefix(prefix)

    cond do
      prefix == "" -> path
      String.starts_with?(path, "/") -> prefix <> path
      true -> prefix <> "/" <> path
    end
  end

  def to(_prefix, path), do: path

  def scope_items(items, prefix) when is_list(items) do
    Enum.map(items, fn
      %{href: href} = item when is_binary(href) ->
        %{item | href: to(prefix, href)}

      item ->
        item
    end)
  end

  def scope_items(items, _prefix), do: items

  defp normalize_prefix(nil), do: ""
  defp normalize_prefix(""), do: ""
  defp normalize_prefix("/"), do: ""

  defp normalize_prefix(prefix) when is_binary(prefix) do
    prefix
    |> String.trim_trailing("/")
    |> case do
      "" -> ""
      "/" -> ""
      value -> value
    end
  end

  defp normalize_prefix(_prefix), do: ""
end
