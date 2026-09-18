defmodule PageDock.Repo.Migrations.EncryptGithubAccessToken do
  use Ecto.Migration

  # `access_token` moves from plaintext varchar to a bytea column holding
  # Cloak-encrypted ciphertext. Any pre-existing plaintext tokens become
  # unreadable and must be re-linked (there is no production data yet).
  def up do
    execute """
    ALTER TABLE github_accounts
    ALTER COLUMN access_token TYPE bytea USING access_token::bytea
    """
  end

  def down do
    execute """
    ALTER TABLE github_accounts
    ALTER COLUMN access_token TYPE varchar USING encode(access_token, 'escape')
    """
  end
end
