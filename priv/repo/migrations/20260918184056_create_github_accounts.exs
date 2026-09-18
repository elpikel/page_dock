defmodule PageDock.Repo.Migrations.CreateGithubAccounts do
  use Ecto.Migration

  def change do
    create table(:github_accounts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :github_uid, :bigint, null: false
      add :login, :string, null: false
      add :access_token, :string, null: false
      add :scopes, {:array, :string}, null: false, default: []
      add :avatar_url, :string

      timestamps(type: :utc_datetime)
    end

    # One GitHub identity maps to at most one local user, and each user connects
    # at most one GitHub account.
    create unique_index(:github_accounts, [:github_uid])
    create unique_index(:github_accounts, [:user_id])
  end
end
