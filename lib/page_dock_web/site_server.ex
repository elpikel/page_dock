defmodule PageDockWeb.SiteServer do
  @moduledoc """
  Serves published site files for requests to `<slug>.<sites_host>`.

  Runs early in the endpoint: if the host is a site subdomain it serves the
  file (or index.html) from the site's deploy dir and halts; otherwise the
  request falls through to the normal application router untouched.
  """
  @behaviour Plug

  import Plug.Conn

  alias PageDock.Deployments.Storage
  alias PageDock.Sites

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case slug_from_host(conn.host) do
      nil -> conn
      slug -> serve(conn, slug)
    end
  end

  defp slug_from_host(host) do
    base = Sites.public_host()
    suffix = "." <> base

    with true <- String.ends_with?(host, suffix),
         slug = String.replace_suffix(host, suffix, ""),
         true <- slug != "" and not String.contains?(slug, ".") do
      slug
    else
      _ -> nil
    end
  end

  defp serve(conn, slug) do
    cond do
      is_nil(Sites.get_site_by_slug(slug)) ->
        halt_text(conn, 404, "Site not found")

      not Storage.published?(slug) ->
        halt_text(conn, 404, "This site hasn't been deployed yet")

      true ->
        serve_file(conn, Storage.site_dir(slug))
    end
  end

  defp serve_file(conn, dir) do
    rel =
      case Enum.join(conn.path_info, "/") do
        "" -> "index.html"
        path -> path
      end

    case Path.safe_relative(rel) do
      {:ok, safe} -> send_resolved(conn, dir, safe)
      :error -> halt_text(conn, 400, "Bad path")
    end
  end

  defp send_resolved(conn, dir, safe) do
    full = Path.join(dir, safe)

    target =
      cond do
        File.dir?(full) -> Path.join(full, "index.html")
        File.regular?(full) -> full
        File.regular?(full <> ".html") -> full <> ".html"
        true -> nil
      end

    if target && File.regular?(target) do
      conn
      |> put_resp_content_type(MIME.from_path(target))
      |> send_file(200, target)
      |> halt()
    else
      not_found(conn, dir)
    end
  end

  defp not_found(conn, dir) do
    custom = Path.join(dir, "404.html")

    if File.regular?(custom) do
      conn
      |> put_resp_content_type("text/html")
      |> send_file(404, custom)
      |> halt()
    else
      halt_text(conn, 404, "Not found")
    end
  end

  defp halt_text(conn, status, body) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(status, body)
    |> halt()
  end
end
