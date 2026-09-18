defmodule PageDock.Deployments.DeployWorkerTest do
  use PageDock.DataCase, async: true
  use Oban.Testing, repo: PageDock.Repo

  import PageDock.AccountsFixtures
  import PageDock.GithubFixtures
  import PageDock.SitesFixtures
  import PageDock.DeploymentsFixtures

  alias PageDock.Deployments
  alias PageDock.Deployments.DeployWorker
  alias PageDock.Deployments.Storage

  test "fetches the tarball, publishes the files, and marks success" do
    user = user_fixture()
    github_account_fixture(user)
    site = site_fixture(user)
    deployment = deployment_fixture(site, commit_sha: "abc123")
    on_exit(fn -> Storage.delete(site.slug) end)

    Req.Test.stub(PageDock.Github, fn conn ->
      assert conn.request_path =~ "/tarball/"
      Plug.Conn.resp(conn, 200, tarball([{"index.html", "<h1>deployed</h1>"}]))
    end)

    assert :ok = perform_job(DeployWorker, %{deployment_id: deployment.id})

    assert Storage.published?(site.slug)
    assert File.read!(Path.join(Storage.site_dir(site.slug), "index.html")) == "<h1>deployed</h1>"
    assert Deployments.get_deployment(deployment.id).status == "success"
  end

  test "marks the deployment failed when the fetch fails" do
    user = user_fixture()
    github_account_fixture(user)
    site = site_fixture(user)
    deployment = deployment_fixture(site)

    Req.Test.stub(PageDock.Github, fn conn -> Plug.Conn.resp(conn, 404, "nope") end)

    assert {:error, _} = perform_job(DeployWorker, %{deployment_id: deployment.id})

    updated = Deployments.get_deployment(deployment.id)
    assert updated.status == "failed"
    assert updated.error
  end

  test "cancels when the deployment no longer exists" do
    assert {:cancel, _} = perform_job(DeployWorker, %{deployment_id: 0})
  end

  test "fails when the user has no connected GitHub account" do
    site = site_fixture(user_fixture())
    deployment = deployment_fixture(site)

    assert {:error, _} = perform_job(DeployWorker, %{deployment_id: deployment.id})
    assert Deployments.get_deployment(deployment.id).status == "failed"
  end
end
