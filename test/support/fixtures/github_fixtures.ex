defmodule PageDock.GithubFixtures do
  @moduledoc """
  Test helpers for creating connected GitHub accounts.
  """

  alias PageDock.Github.GithubAccount
  alias PageDock.Repo

  def github_account_fixture(user, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        github_uid: System.unique_integer([:positive]),
        login: "octocat#{System.unique_integer([:positive])}",
        access_token: "gho_test_token",
        scopes: ["repo", "admin:repo_hook"],
        avatar_url: "https://avatars.githubusercontent.com/u/1"
      })

    %GithubAccount{user_id: user.id}
    |> GithubAccount.connect_changeset(attrs)
    |> Repo.insert!()
  end
end
