defmodule PageDockWeb.PageController do
  use PageDockWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
