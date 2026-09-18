defmodule PageDock.Deployments.Deployment do
  @moduledoc """
  A single deploy attempt for a site, triggered by a push to its branch.

  Lifecycle: `pending` → `building` → `success` | `failed`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending building success failed)

  schema "deployments" do
    field :commit_sha, :string
    field :ref, :string
    field :status, :string, default: "pending"
    field :error, :string

    belongs_to :site, PageDock.Sites.Site

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  @doc "Changeset for creating a deployment. `site_id` is set explicitly."
  def create_changeset(deployment, attrs) do
    deployment
    |> cast(attrs, [:commit_sha, :ref, :status])
    |> validate_required([:commit_sha])
    |> validate_inclusion(:status, @statuses)
    |> assoc_constraint(:site)
  end

  @doc "Changeset for updating a deployment's status (and optional error)."
  def status_changeset(deployment, status, error \\ nil) do
    deployment
    |> change(status: status, error: error)
    |> validate_inclusion(:status, @statuses)
  end
end
