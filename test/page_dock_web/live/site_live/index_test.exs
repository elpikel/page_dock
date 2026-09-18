defmodule PageDockWeb.SiteLive.IndexTest do
  use PageDockWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PageDock.SitesFixtures

  setup :register_and_log_in_user

  test "shows an empty state with no sites", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/sites")
    assert has_element?(lv, "#sites-empty")
    refute has_element?(lv, "#sites")
  end

  test "lists the user's sites", %{conn: conn, user: user} do
    site = site_fixture(user)

    {:ok, lv, html} = live(conn, ~p"/sites")

    assert has_element?(lv, "#sites")
    assert html =~ site.name
    assert html =~ "#{site.slug}.pagedock.eu"
  end

  test "requires authentication", %{conn: _conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(build_conn(), ~p"/sites")
  end

  test "deletes a site", %{conn: conn, user: user} do
    site = site_fixture(user)

    {:ok, lv, _html} = live(conn, ~p"/sites")
    assert has_element?(lv, "#sites-#{site.id}")

    lv |> element("#delete-#{site.id}") |> render_click()

    refute has_element?(lv, "#sites-#{site.id}")
    assert has_element?(lv, "#sites-empty")
  end
end
