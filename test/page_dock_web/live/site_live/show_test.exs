defmodule PageDockWeb.SiteLive.ShowTest do
  use PageDockWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import PageDock.AccountsFixtures
  import PageDock.SitesFixtures

  setup :register_and_log_in_user

  test "renders the site details", %{conn: conn, user: user} do
    site = site_fixture(user)

    {:ok, _lv, html} = live(conn, ~p"/sites/#{site}")

    assert html =~ site.name
    assert html =~ "#{site.repo_owner}/#{site.repo_name}"
    assert html =~ site.default_branch
  end

  test "redirects when the site does not belong to the user", %{conn: conn} do
    other = site_fixture(user_fixture())

    assert {:error, {:live_redirect, %{to: "/sites"}}} = live(conn, ~p"/sites/#{other}")
  end

  test "deletes the site", %{conn: conn, user: user, scope: scope} do
    site = site_fixture(user)

    {:ok, lv, _html} = live(conn, ~p"/sites/#{site}")
    lv |> element("#delete-site") |> render_click()

    assert_redirect(lv, ~p"/sites")
    assert PageDock.Sites.get_site(scope, site.id) == nil
  end
end
