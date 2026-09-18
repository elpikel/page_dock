defmodule PageDock.Repo.Migrations.CreateDeployments do
  use Ecto.Migration

  def change do
    create table(:deployments) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :commit_sha, :string, null: false
      add :ref, :string
      add :status, :string, null: false, default: "pending"
      add :error, :text

      timestamps(type: :utc_datetime)
    end

    create index(:deployments, [:site_id])
    create index(:deployments, [:site_id, :inserted_at])
  end
end
