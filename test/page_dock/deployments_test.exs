defmodule PageDock.DeploymentsTest do
  use PageDock.DataCase, async: true
  use Oban.Testing, repo: PageDock.Repo

  import PageDock.AccountsFixtures
  import PageDock.SitesFixtures
  import PageDock.DeploymentsFixtures

  alias PageDock.Deployments
  alias PageDock.Deployments.DeployWorker

  setup do
    %{site: site_fixture(user_fixture())}
  end

  test "create_deployment/2 records a pending deployment", %{site: site} do
    assert {:ok, deployment} =
             Deployments.create_deployment(site, %{commit_sha: "deadbeef", ref: "main"})

    assert deployment.status == "pending"
    assert deployment.site_id == site.id
  end

  test "list_deployments/1 returns newest first", %{site: site} do
    _first = deployment_fixture(site, commit_sha: "aaa")
    second = deployment_fixture(site, commit_sha: "bbb")

    assert [%{commit_sha: "bbb"} = newest | _] = Deployments.list_deployments(site)
    assert newest.id == second.id
  end

  test "update_status/3 transitions and stores errors", %{site: site} do
    deployment = deployment_fixture(site)

    assert {:ok, updated} = Deployments.update_status(deployment, "failed", "boom")
    assert updated.status == "failed"
    assert updated.error == "boom"
  end

  test "deploy/2 records a deployment and enqueues the worker", %{site: site} do
    assert {:ok, deployment} = Deployments.deploy(site, %{commit_sha: "cafe", ref: "main"})

    assert deployment.status == "pending"
    assert_enqueued(worker: DeployWorker, args: %{deployment_id: deployment.id})
  end
end
