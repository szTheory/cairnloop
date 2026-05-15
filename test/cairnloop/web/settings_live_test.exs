defmodule Cairnloop.Web.SettingsLiveTest do
  use ExUnit.Case

  alias Cairnloop.Web.SettingsLive

  test "module exists" do
    Code.ensure_loaded?(SettingsLive)
    assert function_exported?(SettingsLive, :mount, 3)
    assert function_exported?(SettingsLive, :handle_event, 3)
  end
end
