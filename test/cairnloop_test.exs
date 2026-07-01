defmodule CairnloopTest do
  use ExUnit.Case
  doctest Cairnloop

  test "root module stays as public documentation entry point" do
    assert Code.ensure_loaded?(Cairnloop)

    {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(Cairnloop)
    assert %{"en" => docs} = module_doc
    assert docs =~ "guides/01-quickstart.md"
  end
end
