defmodule PageDockWeb.GithubWebhookControllerTest do
  use PageDockWeb.ConnCase, async: true
  use Oban.Testing, repo: PageDock.Repo

  import PageDock.AccountsFixtures
  import PageDock.SitesFixtures

  alias PageDock.Deployments.DeployWorker

  setup do
    %{site: site_fixture(user_fixture())}
  end

  defp sign(secret, body) do
    "sha256=" <> (:hmac |> :crypto.mac(:sha256, secret, body) |> Base.encode16(case: :lower))
  end

  defp push_body(sha \\ "abc123def", ref \\ "refs/heads/main") do
    Jason.encode!(%{"ref" => ref, "after" => sha, "deleted" => false})
  end

  defp deliver(conn, site_id, body, event, signature) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-github-event", event)
    |> put_req_header("x-hub-signature-256", signature)
    |> post(~p"/webhooks/github/#{site_id}", body)
  end

  test "a valid push enqueues a deploy", %{conn: conn, site: site} do
    body = push_body()
    conn = deliver(conn, site.id, body, "push", sign(site.webhook_secret, body))

    assert response(conn, 202)
    assert_enqueued(worker: DeployWorker)
  end

  test "rejects an invalid signature", %{conn: conn, site: site} do
    body = push_body()
    conn = deliver(conn, site.id, body, "push", "sha256=deadbeef")

    assert response(conn, 401)
    refute_enqueued(worker: DeployWorker)
  end

  test "returns 404 for an unknown site", %{conn: conn} do
    body = push_body()
    conn = deliver(conn, 0, body, "push", sign("whatever", body))

    assert response(conn, 404)
    refute_enqueued(worker: DeployWorker)
  end

  test "responds to a ping without deploying", %{conn: conn, site: site} do
    body = Jason.encode!(%{"zen" => "Keep it simple"})
    conn = deliver(conn, site.id, body, "ping", sign(site.webhook_secret, body))

    assert response(conn, 200)
    refute_enqueued(worker: DeployWorker)
  end

  test "ignores pushes to other branches", %{conn: conn, site: site} do
    body = push_body("abc", "refs/heads/feature")
    conn = deliver(conn, site.id, body, "push", sign(site.webhook_secret, body))

    assert response(conn, 202)
    refute_enqueued(worker: DeployWorker)
  end

  test "ignores branch deletions", %{conn: conn, site: site} do
    body = Jason.encode!(%{"ref" => "refs/heads/main", "after" => "0000", "deleted" => true})
    conn = deliver(conn, site.id, body, "push", sign(site.webhook_secret, body))

    assert response(conn, 202)
    refute_enqueued(worker: DeployWorker)
  end
end
