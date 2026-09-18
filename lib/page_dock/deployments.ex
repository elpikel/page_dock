defmodule PageDock.Deployments do
  @moduledoc """
  The Deployments context: records deploy attempts and enqueues the background
  job that fetches and publishes a site's files.
  """
  import Ecto.Query, warn: false

  alias PageDock.Deployments.Deployment
  alias PageDock.Deployments.DeployWorker
  alias PageDock.Repo
  alias PageDock.Sites.Site

  @doc "Lists a site's deployments, newest first."
  def list_deployments(%Site{id: site_id}, limit \\ 20) do
    Repo.all(
      from d in Deployment,
        where: d.site_id == ^site_id,
        order_by: [desc: d.inserted_at, desc: d.id],
        limit: ^limit
    )
  end

  @doc "Fetches a deployment by id (with its site preloaded), or nil."
  def get_deployment(id) do
    case Repo.get(Deployment, id) do
      nil -> nil
      deployment -> Repo.preload(deployment, :site)
    end
  end

  @doc "Creates a deployment record for a site."
  def create_deployment(%Site{id: site_id}, attrs) do
    %Deployment{site_id: site_id}
    |> Deployment.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a deployment's status (and optional error message)."
  def update_status(%Deployment{} = deployment, status, error \\ nil) do
    deployment
    |> Deployment.status_changeset(status, error)
    |> Repo.update()
  end

  @doc """
  Records a pending deployment for `site` at the given commit and enqueues the
  background deploy job. Returns `{:ok, deployment}` or `{:error, reason}`.
  """
  def deploy(%Site{} = site, %{commit_sha: sha} = attrs) do
    with {:ok, deployment} <-
           create_deployment(site, %{commit_sha: sha, ref: attrs[:ref], status: "pending"}),
         {:ok, _job} <- Oban.insert(DeployWorker.new(%{deployment_id: deployment.id})) do
      {:ok, deployment}
    end
  end
end
