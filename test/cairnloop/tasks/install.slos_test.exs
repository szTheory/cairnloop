defmodule Mix.Tasks.Cairnloop.Install.SlosTest do
  use ExUnit.Case
  import Igniter.Test

  test "scaffolds HostApp.Cairnloop.SLOs and HostApp.Cairnloop.Doctor" do
    igniter = test_project() |> Igniter.compose_task("cairnloop.install.slos")

    # Verify SLOs module creation
    assert_creates(igniter, "lib/cairnloop/slos.ex")
    
    rewrite = igniter.rewrite
    source = Rewrite.source!(rewrite, "lib/cairnloop/slos.ex")
    content = source.content
    
    assert content =~ "defmodule Cairnloop.SLOs do"
    assert content =~ "Parapet.SLO.define"
    assert content =~ "TTFR"
    assert content =~ "Resolution Time"
    assert content =~ "System Health"

    # Verify Doctor module creation
    assert_creates(igniter, "lib/cairnloop/doctor.ex")

    source = Rewrite.source!(rewrite, "lib/cairnloop/doctor.ex")
    content = source.content
    
    assert content =~ "defmodule Cairnloop.Doctor do"

    # Verify Runbook creation
    assert_creates(igniter, "priv/runbooks/cairnloop_system_health.md")
    assert_creates(igniter, "priv/runbooks/cairnloop_ttfr_breach.md")
    assert_creates(igniter, "priv/runbooks/cairnloop_resolution_breach.md")
  end
end
