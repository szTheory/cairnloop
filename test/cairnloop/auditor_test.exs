defmodule Cairnloop.AuditorTest do
  use ExUnit.Case, async: true

  alias Cairnloop.Auditor.NoOp

  test "NoOp.audit/4 returns the given multi unmodified" do
    multi = Ecto.Multi.new()
    assert ^multi = NoOp.audit(multi, :test_action, "test_actor", %{})
  end

  test "NoOp.list_events/1 returns an empty list" do
    assert [] = NoOp.list_events([])
  end
end
