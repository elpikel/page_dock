defmodule PageDockWeb.SiteLive.FormTest do
  # async: false because we use Req.Test in shared mode so the LiveView process
  # (separate from the test process) sees the stubbed GitHub responses.
  use PageDockWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PageDock.GithubFixtures

  alias PageDock.Sites

  setup :register_and_log_in_user

  setup do
    Req.Test.set_req_test_to_shared()
    :ok
  end

  test "prompts to connect GitHub when no account is linked", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/sites/new")
    assert has_element?(lv, "#connect-prompt")
    refute has_element?(lv, "#site-form")
  end

  test "lists repositories and links one as a new site", %{conn: conn, user: user, scope: scope} do
    github_account_fixture(user)

    Req.Test.stub(PageDock.Github, fn conn ->
      case conn.request_path do
        "/user/repos" ->
          Req.Test.json(conn, [
            %{
              "id" => 7,
              "name" => "blog",
              "full_name" => "me/blog",
              "owner" => %{"login" => "me"},
              "default_branch" => "main",
              "private" => false
            }
          ])

        "/repos/me/blog/hooks" ->
          conn |> Plug.Conn.put_status(201) |> Req.Test.json(%{"id" => 999})
      end
    end)

    {:ok, lv, _html} = live(conn, ~p"/sites/new")
    assert has_element?(lv, "#site-form")
    assert render(lv) =~ "me/blog"

    lv
    |> form("#site-form", site: %{repo_id: "7", name: "My Blog", slug: "my-blog"})
    |> render_submit()

    assert [site] = Sites.list_sites(scope)
    assert site.repo_owner == "me"
    assert site.repo_name == "blog"
    assert site.slug == "my-blog"
    assert site.webhook_id == 999
    assert_redirect(lv, ~p"/sites/#{site}")
  end
end
