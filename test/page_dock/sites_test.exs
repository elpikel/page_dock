defmodule PageDock.SitesTest do
  use PageDock.DataCase, async: true

  import PageDock.AccountsFixtures
  import PageDock.SitesFixtures

  alias PageDock.Accounts.Scope
  alias PageDock.Sites

  setup do
    user = user_fixture()
    %{user: user, scope: Scope.for_user(user)}
  end

  defp valid_attrs(overrides \\ %{}) do
    Enum.into(overrides, %{
      "name" => "My Cool Site",
      "repo_owner" => "octocat",
      "repo_name" => "cool",
      "repo_id" => 100,
      "default_branch" => "main"
    })
  end

  describe "create_site/2" do
    test "derives a slug from the name and sets the owner", %{scope: scope} do
      assert {:ok, site} = Sites.create_site(scope, valid_attrs())
      assert site.slug == "my-cool-site"
      assert site.user_id == scope.user.id
    end

    test "requires a repository", %{scope: scope} do
      assert {:error, changeset} = Sites.create_site(scope, %{"name" => "X"})
      errors = errors_on(changeset)
      assert errors[:repo_id]
      assert errors[:repo_owner]
    end

    test "normalizes a messy slug into a valid one", %{scope: scope} do
      assert {:ok, site} = Sites.create_site(scope, valid_attrs(%{"slug" => "Bad Slug!!"}))
      assert site.slug == "bad-slug"
    end

    test "enforces a globally unique slug", %{scope: scope} do
      assert {:ok, _} =
               Sites.create_site(scope, valid_attrs(%{"slug" => "taken", "repo_id" => 1}))

      assert {:error, changeset} =
               Sites.create_site(scope, valid_attrs(%{"slug" => "taken", "repo_id" => 2}))

      assert "has already been taken" in errors_on(changeset).slug
    end

    test "a user cannot link the same repo twice", %{scope: scope} do
      assert {:ok, _} =
               Sites.create_site(scope, valid_attrs(%{"slug" => "site-a", "repo_id" => 42}))

      assert {:error, changeset} =
               Sites.create_site(scope, valid_attrs(%{"slug" => "site-b", "repo_id" => 42}))

      assert "this repository is already linked" in errors_on(changeset).repo_id
    end
  end

  describe "scoping" do
    test "list_sites/1 only returns the scope's own sites", %{user: user, scope: scope} do
      mine = site_fixture(user)
      other = site_fixture(user_fixture())

      ids = Enum.map(Sites.list_sites(scope), & &1.id)
      assert mine.id in ids
      refute other.id in ids
    end

    test "get_site!/2 raises for another user's site", %{scope: scope} do
      other = site_fixture(user_fixture())
      assert_raise Ecto.NoResultsError, fn -> Sites.get_site!(scope, other.id) end
    end

    test "get_site/2 returns nil for another user's site", %{scope: scope} do
      other = site_fixture(user_fixture())
      assert Sites.get_site(scope, other.id) == nil
    end
  end

  describe "delete_site/2" do
    test "removes the site", %{user: user, scope: scope} do
      site = site_fixture(user)
      assert {:ok, _} = Sites.delete_site(scope, site)
      assert Sites.get_site(scope, site.id) == nil
    end
  end
end
