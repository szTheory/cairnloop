defmodule Cairnloop.KnowledgeBase.MarkdownParserTest do
  use ExUnit.Case, async: true
  alias Cairnloop.KnowledgeBase.MarkdownParser

  describe "parse/1" do
    test "parses markdown with H2 headers into separate text chunks" do
      markdown = """
      ## Section 1
      Content 1
      
      ## Section 2
      Content 2
      """
      
      chunks = MarkdownParser.parse(markdown)
      assert length(chunks) == 2
      assert Enum.any?(chunks, &String.contains?(&1, "Section 1"))
      assert Enum.any?(chunks, &String.contains?(&1, "Content 1"))
      assert Enum.any?(chunks, &String.contains?(&1, "Section 2"))
    end

    test "parses markdown with H3 headers into separate text chunks" do
      markdown = """
      ### Subsection 1
      Details A
      
      ### Subsection 2
      Details B
      """
      
      chunks = MarkdownParser.parse(markdown)
      assert length(chunks) == 2
      assert Enum.any?(chunks, &String.contains?(&1, "Subsection 1"))
      assert Enum.any?(chunks, &String.contains?(&1, "Subsection 2"))
    end

    test "falls back gracefully if chunk length exceeds token limits (splits)" do
      long_text = String.duplicate("a", 5000)
      markdown = "## Big Section\n\n#{long_text}"
      
      chunks = MarkdownParser.parse(markdown)
      assert length(chunks) >= 2
      # Max length should be respected
      assert Enum.all?(chunks, &(String.length(&1) <= 4000))
    end
    
    test "groups layout HTML correctly using Earmark.as_ast/1" do
      markdown = """
      ## Section
      <div class="custom">HTML content</div>
      More text.
      """
      chunks = MarkdownParser.parse(markdown)
      assert length(chunks) == 1
      chunk = hd(chunks)
      assert String.contains?(chunk, "Section")
      assert String.contains?(chunk, "HTML content") || String.contains?(chunk, "<div class=\"custom\">HTML content</div>")
    end
  end
end
