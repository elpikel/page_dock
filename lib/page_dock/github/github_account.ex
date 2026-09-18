defmodule PageDock.Github.GithubAccount do
  @moduledoc """
  A GitHub identity connected to a local user via OAuth.

  Holds the user's OAuth access token and the scopes it was granted, which the
  rest of the app uses to call the GitHub API on the user's behalf (listing
  repos, registering webhooks, and so on).
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "github_accounts" do
    field :github_uid, :integer
    field :login, :string
    field :access_token, PageDock.Encrypted.Binary, redact: true
    field :scopes, {:array, :string}, default: []
    field :avatar_url, :string

    belongs_to :user, PageDock.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for connecting (or reconnecting) a GitHub account.

  `user_id` is set explicitly by the caller and is intentionally not cast.
  """
  def connect_changeset(github_account, attrs) do
    github_account
    |> cast(attrs, [:github_uid, :login, :access_token, :scopes, :avatar_url])
    |> validate_required([:github_uid, :login, :access_token])
    |> assoc_constraint(:user)
    |> unique_constraint(:github_uid)
    |> unique_constraint(:user_id)
  end
end
