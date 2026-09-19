defmodule PageDockWeb.OpsControllerTest do
  use PageDockWeb.ConnCase, async: true

  import PageDock.AccountsFixtures
  import PageDock.SitesFixtures

  test "GET /healthz returns ok", %{conn: conn} do
    conn = get(conn, ~p"/healthz")
    assert response(conn, 200) == "ok"
  end

  describe "GET /internal/tls-check" do
    test "allows the product apex host", %{conn: conn} do
      conn = get(conn, ~p"/internal/tls-check?#{[domain: "pagedock.test"]}")
      assert response(conn, 200) == "ok"
    end

    test "allows an existing site's subdomain", %{conn: conn} do
      site = site_fixture(user_fixture())
      conn = get(conn, ~p"/internal/tls-check?#{[domain: "#{site.slug}.pagedock.test"]}")
      assert response(conn, 200) == "ok"
    end

    test "rejects an unknown host", %{conn: conn} do
      conn = get(conn, ~p"/internal/tls-check?#{[domain: "nope.pagedock.test"]}")
      assert response(conn, 403)
    end

    test "rejects a foreign domain", %{conn: conn} do
      conn = get(conn, ~p"/internal/tls-check?#{[domain: "evil.example.com"]}")
      assert response(conn, 403)
    end

    test "400 when domain is missing", %{conn: conn} do
      conn = get(conn, ~p"/internal/tls-check")
      assert response(conn, 400)
    end
  end
end
