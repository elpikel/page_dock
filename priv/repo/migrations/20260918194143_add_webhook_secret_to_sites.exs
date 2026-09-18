defmodule PageDock.Repo.Migrations.AddWebhookSecretToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      # Per-site secret used to verify GitHub webhook HMAC signatures.
      add :webhook_secret, :string
    end
  end
end
