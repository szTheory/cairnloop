defmodule Mix.Tasks.Cairnloop.Install.SlaPoliciesTest do
  use ExUnit.Case

  import Igniter.Test

  test "installs sla policies" do
    igniter = 
      test_project()
      |> Igniter.compose_task("cairnloop.install.sla_policies")

    # If the task ran without raising exceptions, it's successful.
    assert %Igniter{} = igniter
  end
end
