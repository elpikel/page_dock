defmodule PageDock.Deployments.DeployWorker do
  @moduledoc """
  Fetches a site's repository at the pushed commit and publishes its files.

  Enqueued by `PageDock.Deployments.deploy/2` (from the GitHub webhook). Drives
  the deployment through `building` → `success`/`failed`.
  """
  use Oban.Worker, queue: :deploys, max_attempts: 3

  alias PageDock.Deployments
  alias PageDock.Deployments.Storage
  alias PageDock.Github
  alias PageDock.Github.GithubAccount
  alias PageDock.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"deployment_id" => id}}) do
    case Deployments.get_deployment(id) do
      nil -> {:cancel, :deployment_not_found}
      deployment -> run(deployment)
    end
  end

  defp run(deployment) do
    site = deployment.site
    {:ok, _} = Deployments.update_status(deployment, "building")

    with {:ok, account} <- fetch_account(site),
         {:ok, tarball} <-
           Github.fetch_tarball(account, site.repo_owner, site.repo_name, deployment.commit_sha),
         :ok <- Storage.publish(site.slug, tarball) do
      {:ok, _} = Deployments.update_status(deployment, "success")
      :ok
    else
      {:error, reason} ->
        {:ok, _} = Deployments.update_status(deployment, "failed", inspect(reason))
        {:error, reason}
    end
  end

  defp fetch_account(site) do
    case Repo.get_by(GithubAccount, user_id: site.user_id) do
      nil -> {:error, :github_not_connected}
      account -> {:ok, account}
    end
  end
end
