defmodule PageDockWeb.PageControllerTest do
  use PageDockWeb.ConnCase

  test "GET / renders the landing page", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "Pagedock"
    assert response =~ "From prompt"
  end

  test "GET / links to auth routes", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ ~p"/users/register"
    assert response =~ ~p"/users/log-in"
  end
end
