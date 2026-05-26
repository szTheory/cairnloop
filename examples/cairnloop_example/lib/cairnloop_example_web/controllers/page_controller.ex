defmodule CairnloopExampleWeb.PageController do
  use CairnloopExampleWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
