defmodule PageDockWeb.PageController do
  use PageDockWeb, :controller

  def home(conn, _params) do
    render(conn, :home, page_title: "Pagedock — push a repo, get a site, hosted in Europe")
  end
end
