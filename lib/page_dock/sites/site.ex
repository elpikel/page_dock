defmodule PageDock.Sites.Site do
  @moduledoc """
  A site is a GitHub repository linked to a user and served at
  `<slug>.pagedock.eu`. Pushes to `default_branch` will trigger deploys (Phase 4).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @slug_format ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/

  schema "sites" do
    field :name, :string
    field :slug, :string
    field :repo_owner, :string
    field :repo_name, :string
    field :repo_id, :integer
    field :default_branch, :string, default: "main"
    field :webhook_id, :integer

    belongs_to :user, PageDock.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a site.

  `user_id` is set explicitly by the caller (not cast). When `slug` is blank it
  is derived from `name`.
  """
  def changeset(site, attrs) do
    site
    |> cast(attrs, [:name, :slug, :repo_owner, :repo_name, :repo_id, :default_branch])
    |> update_change(:slug, &normalize_slug/1)
    |> maybe_derive_slug()
    |> validate_required([:name, :slug, :repo_owner, :repo_name, :repo_id, :default_branch])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:slug, min: 2, max: 63)
    |> validate_format(:slug, @slug_format,
      message: "only lowercase letters, numbers, and hyphens"
    )
    |> unique_constraint(:slug)
    |> unique_constraint(:repo_id,
      name: :sites_user_id_repo_id_index,
      message: "this repository is already linked"
    )
    |> assoc_constraint(:user)
  end

  @doc "Turns an arbitrary string into a slug candidate."
  def slugify(string) when is_binary(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp maybe_derive_slug(changeset) do
    name = get_field(changeset, :name)
    slug = get_field(changeset, :slug)

    if (is_nil(slug) or slug == "") and is_binary(name) do
      put_change(changeset, :slug, slugify(name))
    else
      changeset
    end
  end

  defp normalize_slug(nil), do: nil
  defp normalize_slug(slug), do: slugify(slug)
end
