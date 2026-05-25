defmodule Cairnloop.Web.TestLayouts do
  @moduledoc """
  Minimal root layout for the integration test Endpoint so `Phoenix.LiveViewTest.live/2`
  can render a mounted LiveView. Test-only (`elixirc_paths(:test)`).
  """
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <title>Cairnloop Test Host</title>
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """
  end
end
