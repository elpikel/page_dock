defmodule PageDock.Deployments.Storage do
  @moduledoc """
  On-disk storage for deployed site files.

  Each site's published files live under `<deploy_root>/<slug>/`. Publishing
  extracts a GitHub tarball into a temp dir and atomically swaps it into place,
  so a site is never served half-written.
  """

  @doc "Root directory holding all sites' published files."
  def root do
    Application.get_env(:page_dock, :sites, [])[:deploy_root] || "priv/deploys"
  end

  @doc "Directory holding a single site's published files."
  def site_dir(slug), do: Path.join(root(), slug)

  @doc "Whether a site currently has published files."
  def published?(slug), do: File.dir?(site_dir(slug))

  @doc """
  Extracts a gzipped tarball (as produced by the GitHub tarball API) and
  atomically publishes it as the site's current files. Returns `:ok` or
  `{:error, reason}`.
  """
  def publish(slug, tar_gz) when is_binary(tar_gz) do
    with {:ok, files} <- extract(tar_gz) do
      tmp = site_dir(slug) <> ".tmp-#{System.unique_integer([:positive])}"

      try do
        write_all(tmp, files)
        swap_into_place(slug, tmp)
        :ok
      rescue
        e ->
          File.rm_rf(tmp)
          {:error, {:publish, Exception.message(e)}}
      end
    end
  end

  @doc "Removes a site's published files, if any."
  def delete(slug), do: File.rm_rf(site_dir(slug))

  defp extract(tar_gz) do
    case :erl_tar.extract({:binary, tar_gz}, [:memory, :compressed]) do
      {:ok, entries} -> {:ok, strip_top_level(entries)}
      {:error, reason} -> {:error, {:extract, reason}}
    end
  end

  # GitHub tarballs nest everything under a single `owner-repo-<sha>/` dir; drop
  # that leading segment so files land at the site root.
  defp strip_top_level(entries) do
    Enum.flat_map(entries, fn {name, content} ->
      case Path.split(to_string(name)) do
        [_top | []] -> []
        [_top | rest] -> [{Path.join(rest), content}]
      end
    end)
  end

  defp write_all(tmp, files) do
    File.mkdir_p!(tmp)

    Enum.each(files, fn {rel, content} ->
      case Path.safe_relative(rel) do
        {:ok, safe} ->
          dest = Path.join(tmp, safe)
          File.mkdir_p!(Path.dirname(dest))
          File.write!(dest, content)

        :error ->
          # Ignore entries that try to escape the site dir (path traversal).
          :ok
      end
    end)
  end

  defp swap_into_place(slug, tmp) do
    dir = site_dir(slug)
    File.mkdir_p!(root())
    File.rm_rf!(dir)
    File.rename!(tmp, dir)
  end
end
