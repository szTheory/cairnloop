defmodule Cairnloop.Markdown do
  @moduledoc false

  @inline_tags ~w(a code em strong del)
  @block_tags ~w(blockquote h1 h2 h3 h4 h5 h6 li ol p pre table tbody td th thead tr ul)
  @void_tags ~w(br hr)
  @allowed_tags MapSet.new(@inline_tags ++ @block_tags ++ @void_tags)

  def to_ast(markdown) when is_binary(markdown), do: EarmarkParser.as_ast(markdown)

  def to_html(nil), do: ""

  def to_html(markdown) when is_binary(markdown) do
    case EarmarkParser.as_ast(markdown) do
      {:ok, ast, _messages} -> render_nodes(ast)
      {:error, ast, _messages} -> render_nodes(ast)
      _ -> escape(markdown)
    end
    |> IO.iodata_to_binary()
  end

  defp render_nodes(nodes) when is_list(nodes), do: Enum.map(nodes, &render_node/1)

  defp render_node(text) when is_binary(text), do: escape(text)

  defp render_node({tag, attrs, _children, _meta}) when tag in @void_tags do
    ["<", tag, render_attrs(tag, attrs), ">"]
  end

  defp render_node({tag, attrs, children, _meta}) when tag in @inline_tags do
    ["<", tag, render_attrs(tag, attrs), ">", render_nodes(children), "</", tag, ">"]
  end

  defp render_node({tag, attrs, children, _meta}) when tag in @block_tags do
    ["<", tag, render_attrs(tag, attrs), ">\n", render_nodes(children), "</", tag, ">"]
  end

  defp render_node({tag, _attrs, children, _meta}) when is_binary(tag) do
    tag = String.downcase(tag)

    if MapSet.member?(@allowed_tags, tag) do
      render_node({tag, [], children, %{}})
    else
      render_nodes(children)
    end
  end

  defp render_node(_node), do: []

  defp render_attrs("a", attrs) do
    attrs
    |> Enum.flat_map(fn
      {"href", value} -> [{"href", safe_href(value)}]
      {"title", value} -> [{"title", value}]
      _ -> []
    end)
    |> attrs_to_iodata()
  end

  defp render_attrs("code", attrs) do
    attrs
    |> Enum.flat_map(fn
      {"class", value} -> [{"class", value}]
      _ -> []
    end)
    |> attrs_to_iodata()
  end

  defp render_attrs(_tag, _attrs), do: []

  defp attrs_to_iodata(attrs) do
    Enum.map(attrs, fn {name, value} ->
      [" ", name, "=\"", escape(to_string(value)), "\""]
    end)
  end

  defp safe_href(value) do
    value = to_string(value)
    normalized = value |> String.trim_leading() |> String.downcase()

    if String.starts_with?(normalized, ["javascript:", "data:", "vbscript:"]) do
      "#"
    else
      value
    end
  end

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end
end
