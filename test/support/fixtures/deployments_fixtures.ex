defmodule PageDock.DeploymentsFixtures do
  @moduledoc "Test helpers for deployments and tarball payloads."

  alias PageDock.Deployments

  @doc """
  Builds a gzipped tarball binary from `{path, content}` entries, mimicking the
  GitHub tarball layout where everything is nested under a top-level dir.
  """
  def tarball(entries, top \\ "octocat-repo-abc123") do
    files =
      Enum.map(entries, fn {path, content} ->
        {String.to_charlist(Path.join(top, path)), content}
      end)

    tmp = Path.join(System.tmp_dir!(), "pd-tar-#{System.unique_integer([:positive])}.tar.gz")
    :ok = :erl_tar.create(String.to_charlist(tmp), files, [:compressed])
    data = File.read!(tmp)
    File.rm(tmp)
    data
  end

  def deployment_fixture(site, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        commit_sha: "abc123",
        ref: "main",
        status: "pending"
      })

    {:ok, deployment} = Deployments.create_deployment(site, attrs)
    deployment
  end
end
