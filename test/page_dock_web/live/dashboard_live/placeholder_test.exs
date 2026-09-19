defmodule PageDockWeb.DashboardLive.PlaceholderTest do
  use PageDockWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "deploys page renders in the dashboard shell", %{conn: conn} do
    {:ok, lv, html} = live(conn, ~p"/deploys")
    assert html =~ "Deploys"
    assert has_element?(lv, "a.nav-item", "Sites")
  end

  test "domains page renders", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/domains")
    assert html =~ "Custom domains"
  end

  test "billing page renders the plans", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/billing")
    assert html =~ "Beta plan"
  end

  test "the nav pages require authentication" do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(build_conn(), ~p"/deploys")
  end

  test "the sidebar links to the other sections", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/sites")
    assert has_element?(lv, "a.nav-item", "Settings")
    assert has_element?(lv, "a.nav-item", "Domains")
  end
end
