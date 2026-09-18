defmodule PageDock.Sites do
  @moduledoc """
  The Sites context: a user's linked GitHub repositories, each served at
  `<slug>.pagedock.eu`. All functions are scoped to a `PageDock.Accounts.Scope`
  so a user can only ever see or touch their own sites.
  """
  import Ecto.Query, warn: false

  alias PageDock.Accounts.Scope
  alias PageDock.Repo
  alias PageDock.Sites.Site

  @doc "Lists the scope user's sites, newest first."
  def list_sites(%Scope{user: user}) do
    Repo.all(from s in Site, where: s.user_id == ^user.id, order_by: [desc: s.inserted_at])
  end

  @doc "Fetches one of the scope user's sites by id. Raises if not found/owned."
  def get_site!(%Scope{user: user}, id) do
    Repo.get_by!(Site, id: id, user_id: user.id)
  end

  @doc "Fetches one of the scope user's sites by id, or nil."
  def get_site(%Scope{user: user}, id) do
    Repo.get_by(Site, id: id, user_id: user.id)
  end

  @doc "Creates a site owned by the scope user."
  def create_site(%Scope{user: user}, attrs) do
    %Site{user_id: user.id}
    |> Site.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates one of the scope user's sites."
  def update_site(%Scope{user: user}, %Site{user_id: user_id} = site, attrs)
      when user_id == user.id do
    site
    |> Site.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes one of the scope user's sites."
  def delete_site(%Scope{user: user}, %Site{user_id: user_id} = site)
      when user_id == user.id do
    Repo.delete(site)
  end

  @doc "Returns a changeset for tracking site changes in forms."
  def change_site(%Scope{}, %Site{} = site, attrs \\ %{}) do
    Site.changeset(site, attrs)
  end
end
