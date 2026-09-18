defmodule PageDock.Sites do
  @moduledoc """
  The Sites context: a user's linked GitHub repositories, each served at
  `<slug>.pagedock.eu`. All functions are scoped to a `PageDock.Accounts.Scope`
  so a user can only ever see or touch their own sites.
  """
  import Ecto.Query, warn: false

  alias PageDock.Accounts.Scope
  alias PageDock.Github
  alias PageDock.Github.GithubAccount
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

  @doc """
  Fetches a site by id, unscoped. Only for the webhook endpoint, whose
  authenticity is established by the per-site HMAC signature, not by a session.
  """
  def get_site_by_id(id), do: Repo.get(Site, id)

  @doc "Fetches a site by its public slug (subdomain), unscoped. For serving."
  def get_site_by_slug(slug) when is_binary(slug), do: Repo.get_by(Site, slug: slug)

  @doc "The base host that sites are served under (env-dependent)."
  def public_host, do: Application.get_env(:page_dock, :sites, [])[:host] || "pagedock.eu"

  @doc "A site's full public host, e.g. `my-site.pagedock.eu`."
  def public_domain(%Site{slug: slug}), do: "#{slug}.#{public_host()}"
  def public_domain(slug) when is_binary(slug), do: "#{slug}.#{public_host()}"

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

  @doc """
  Registers a GitHub push webhook for the site, delivering to `callback_url`,
  and stores the returned hook id. Returns `{:ok, site}` or `{:error, reason}`.
  """
  def register_webhook(%Site{} = site, %GithubAccount{} = account, callback_url) do
    with {:ok, hook_id} <-
           Github.create_push_webhook(
             account,
             site.repo_owner,
             site.repo_name,
             callback_url,
             site.webhook_secret
           ) do
      site
      |> Ecto.Changeset.change(webhook_id: hook_id)
      |> Repo.update()
    end
  end

  @doc "Removes the site's GitHub webhook, if one is registered. Best-effort."
  def deregister_webhook(%Site{webhook_id: nil}, _account), do: :ok

  def deregister_webhook(%Site{} = site, %GithubAccount{} = account) do
    Github.delete_webhook(account, site.repo_owner, site.repo_name, site.webhook_id)
  end

  def deregister_webhook(%Site{}, nil), do: :ok
end
