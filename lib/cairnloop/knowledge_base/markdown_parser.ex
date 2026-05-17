defmodule Cairnloop.KnowledgeBase.MarkdownParser do
  @moduledoc """
  Parses markdown into chunks for vector embeddings.
  """
  
  @max_chunk_size 4000

  def parse(markdown) when is_binary(markdown) do
    case Earmark.as_ast(markdown) do
      {:ok, ast, _messages} ->
        ast
        |> extract_sections()
        |> Enum.flat_map(&split_large_chunks/1)

      _ ->
        []
    end
  end

  defp extract_sections(ast) do
    # Group nodes under the latest h2 or h3
    {sections, current_section, current_nodes} =
      Enum.reduce(ast, {[], nil, []}, fn node, {acc_sections, current_section, current_nodes} ->
        case node do
          {"h2", _, children, _} ->
            new_acc = maybe_add_section(acc_sections, current_section, current_nodes)
            {new_acc, extract_text(children), []}
            
          {"h3", _, children, _} ->
            new_acc = maybe_add_section(acc_sections, current_section, current_nodes)
            {new_acc, extract_text(children), []}
            
          other_node ->
            {acc_sections, current_section, [other_node | current_nodes]}
        end
      end)
      
    final_sections = maybe_add_section(sections, current_section, current_nodes)
    
    Enum.reverse(final_sections)
  end
  
  defp maybe_add_section(sections, nil, []) do
    sections
  end
  defp maybe_add_section(sections, nil, nodes) do
    text = extract_text(Enum.reverse(nodes))
    if String.trim(text) == "" do
      sections
    else
      [String.trim(text) | sections]
    end
  end
  defp maybe_add_section(sections, header, nodes) do
    text = extract_text(Enum.reverse(nodes))
    combined = 
      if String.trim(text) == "" do
        header
      else
        "#{header}\n#{text}"
      end
      
    [String.trim(combined) | sections]
  end

  defp extract_text(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&extract_text/1)
    |> Enum.join(" ")
  end
  defp extract_text(text) when is_binary(text), do: text
  defp extract_text({_tag, _attrs, children, _meta}) do
    # Simple extraction of text, could be improved to reconstruct HTML if needed
    extract_text(children)
  end
  defp extract_text(_), do: ""

  defp split_large_chunks(text) do
    if String.length(text) <= @max_chunk_size do
      [text]
    else
      text
      |> String.codepoints()
      |> Enum.chunk_every(@max_chunk_size)
      |> Enum.map(&Enum.join/1)
    end
  end
end
