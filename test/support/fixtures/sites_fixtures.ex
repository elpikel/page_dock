defmodule PageDock.SitesFixtures do
  @moduledoc "Test helpers for creating sites."

  alias PageDock.Accounts.Scope
  alias PageDock.Sites

  def site_fixture(user, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    attrs =
      Enum.into(attrs, %{
        "name" => "My Site #{unique}",
        "slug" => "my-site-#{unique}",
        "repo_owner" => "octocat",
        "repo_name" => "repo-#{unique}",
        "repo_id" => unique,
        "default_branch" => "main"
      })

    {:ok, site} = Sites.create_site(Scope.for_user(user), attrs)
    site
  end
end
