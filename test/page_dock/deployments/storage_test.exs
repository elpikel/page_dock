defmodule PageDock.Deployments.StorageTest do
  use ExUnit.Case, async: true

  import PageDock.DeploymentsFixtures

  alias PageDock.Deployments.Storage

  setup do
    slug = "storage-#{System.unique_integer([:positive])}"
    on_exit(fn -> Storage.delete(slug) end)
    %{slug: slug}
  end

  test "publishes a tarball, stripping the top-level directory", %{slug: slug} do
    tar =
      tarball([
        {"index.html", "<h1>home</h1>"},
        {"css/app.css", "body{}"}
      ])

    assert :ok = Storage.publish(slug, tar)
    assert Storage.published?(slug)
    assert File.read!(Path.join(Storage.site_dir(slug), "index.html")) == "<h1>home</h1>"
    assert File.read!(Path.join(Storage.site_dir(slug), "css/app.css")) == "body{}"
  end

  test "ignores path-traversal entries", %{slug: slug} do
    tar = tarball([{"index.html", "ok"}, {"../escape.txt", "nope"}])

    assert :ok = Storage.publish(slug, tar)
    assert Storage.published?(slug)
    refute File.exists?(Path.join(Path.dirname(Storage.site_dir(slug)), "escape.txt"))
  end

  test "replaces previous contents atomically", %{slug: slug} do
    assert :ok = Storage.publish(slug, tarball([{"index.html", "v1"}, {"old.html", "gone"}]))
    assert :ok = Storage.publish(slug, tarball([{"index.html", "v2"}]))

    assert File.read!(Path.join(Storage.site_dir(slug), "index.html")) == "v2"
    refute File.exists?(Path.join(Storage.site_dir(slug), "old.html"))
  end

  test "returns an error for a non-tarball payload", %{slug: slug} do
    assert {:error, _} = Storage.publish(slug, "not a tarball")
  end
end
