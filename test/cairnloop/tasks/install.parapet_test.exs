defmodule Mix.Tasks.Cairnloop.Install.ParapetTest do
  use ExUnit.Case
  import Igniter.Test

  test "scaffolds HostApp.CairnloopInstrumenter with proper metrics" do
    igniter = test_project() |> Igniter.compose_task("cairnloop.install.parapet")

    assert_creates(igniter, "lib/test/cairnloop_instrumenter.ex")
    
    # We can inspect the igniter struct
    rewrite = igniter.rewrite
    source = Rewrite.source!(rewrite, "lib/test/cairnloop_instrumenter.ex")
    content = source.content
    
    assert content =~ "defmodule Test.CairnloopInstrumenter do"
    assert content =~ "import Telemetry.Metrics"
    assert content =~ "def metrics do"
    
    assert content =~ "summary(\"cairnloop.support_resolution_time\""
    assert content =~ "summary(\"cairnloop.support_reply_time\""
    assert content =~ "summary(\"cairnloop.support_csat_score\""

    refute content =~ "tags: [:conversation_id"
    refute content =~ "tags: [:user_id"
    refute content =~ "tags: [:message_id"

    assert content =~ "measurement: fn _measurements, metadata ->"
    assert content =~ "Map.get(metadata, :business_duration_seconds"
    assert content =~ "Map.get(metadata, :rating"
  end
end
