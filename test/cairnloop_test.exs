defmodule CairnloopTest do
  use ExUnit.Case
  doctest Cairnloop

  test "greets the world" do
    assert Cairnloop.hello() == :world
  end
end
