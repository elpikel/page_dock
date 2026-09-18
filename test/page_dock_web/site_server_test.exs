defmodule PageDockWeb.SiteServerTest do
  use PageDockWeb.ConnCase, async: true

  import PageDock.AccountsFixtures
  import PageDock.SitesFixtures
  import PageDock.DeploymentsFixtures

  alias PageDock.Deployments.Storage

  defp publish_site(files) do
    site = site_fixture(user_fixture())
    on_exit(fn -> Storage.delete(site.slug) end)
    :ok = Storage.publish(site.slug, tarball(files))
    site
  end

  defp host_conn(conn, slug), do: %{conn | host: "#{slug}.pagedock.test"}

  test "serves index.html at the root for a published site", %{conn: conn} do
    site = publish_site([{"index.html", "<h1>live</h1>"}])

    conn = conn |> host_conn(site.slug) |> get("/")

    assert response(conn, 200) =~ "<h1>live</h1>"
    assert response_content_type(conn, :html)
  end

  test "serves a nested asset", %{conn: conn} do
    site = publish_site([{"index.html", "home"}, {"css/app.css", "body{color:red}"}])

    conn = conn |> host_conn(site.slug) |> get("/css/app.css")

    assert response(conn, 200) =~ "color:red"
  end

  test "returns 404 for an unknown slug", %{conn: conn} do
    conn = conn |> host_conn("does-not-exist") |> get("/")
    assert response(conn, 404)
  end

  test "returns 404 when the site exists but has no deploy", %{conn: conn} do
    site = site_fixture(user_fixture())
    conn = conn |> host_conn(site.slug) |> get("/")
    assert response(conn, 404) =~ "deployed"
  end

  test "passes non-site hosts through to the application", %{conn: conn} do
    # default ConnTest host is not a *.pagedock.test subdomain
    conn = get(conn, ~p"/")
    assert response(conn, 200) =~ "Pagedock"
  end
end
