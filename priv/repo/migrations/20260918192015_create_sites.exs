defmodule PageDock.Repo.Migrations.CreateSites do
  use Ecto.Migration

  def change do
    create table(:sites) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :repo_owner, :string, null: false
      add :repo_name, :string, null: false
      add :repo_id, :bigint, null: false
      add :default_branch, :string, null: false, default: "main"
      # Set in Phase 4 when the push webhook is registered on the repo.
      add :webhook_id, :bigint

      timestamps(type: :utc_datetime)
    end

    # slug is the site's public subdomain (slug.pagedock.eu) — globally unique.
    create unique_index(:sites, [:slug])
    create index(:sites, [:user_id])
    # A user can't link the same repo twice.
    create unique_index(:sites, [:user_id, :repo_id])
  end
end
