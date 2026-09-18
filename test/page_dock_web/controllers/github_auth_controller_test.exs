defmodule PageDockWeb.GithubAuthControllerTest do
  use PageDockWeb.ConnCase, async: true

  import PageDock.GithubFixtures

  alias PageDock.Github

  setup :register_and_log_in_user

  describe "GET /auth/github (authorize)" do
    test "redirects to GitHub and stores a state in the session", %{conn: conn} do
      conn = get(conn, ~p"/auth/github")

      assert redirected_to(conn) =~ "https://github.com/login/oauth/authorize?"
      assert get_session(conn, "github_oauth_state")
    end

    test "requires an authenticated user" do
      conn = get(build_conn(), ~p"/auth/github")
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "GET /auth/github/callback" do
    test "links the account on a valid callback", %{conn: conn, scope: scope} do
      Req.Test.stub(PageDock.Github, &github_stub/1)

      conn = get(conn, ~p"/auth/github")
      state = get_session(conn, "github_oauth_state")

      conn = get(conn, ~p"/auth/github/callback?#{[code: "abc", state: state]}")

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "octocat"
      assert Github.connected?(scope)
      # state is single-use
      assert get_session(conn, "github_oauth_state") == nil
    end

    test "rejects a mismatched state (CSRF)", %{conn: conn, scope: scope} do
      conn = get(conn, ~p"/auth/github")
      conn = get(conn, ~p"/auth/github/callback?#{[code: "abc", state: "tampered"]}")

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "could not be verified"
      refute Github.connected?(scope)
    end

    test "surfaces a denied authorization back to settings for a link attempt", %{conn: conn} do
      conn = get(conn, ~p"/auth/github")

      conn =
        get(
          conn,
          ~p"/auth/github/callback?#{[error: "access_denied", error_description: "denied"]}"
        )

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "denied"
    end
  end

  describe "Sign in with GitHub (login)" do
    test "GET /auth/github/login redirects to GitHub and stores login purpose" do
      conn = get(build_conn(), ~p"/auth/github/login")

      assert redirected_to(conn) =~ "https://github.com/login/oauth/authorize?"
      assert get_session(conn, "github_oauth_purpose") == "login"
    end

    test "callback creates and logs in a new user" do
      Req.Test.stub(PageDock.Github, &github_stub_with_email/1)

      conn = get(build_conn(), ~p"/auth/github/login")
      state = get_session(conn, "github_oauth_state")

      conn = get(conn, ~p"/auth/github/callback?#{[code: "abc", state: state]}")

      assert redirected_to(conn) == ~p"/"
      assert get_session(conn, :user_token)
      assert PageDock.Accounts.get_user_by_email("octocat@example.com")
    end

    test "callback refuses to take over an existing email account" do
      import PageDock.AccountsFixtures
      existing = user_fixture()

      Req.Test.stub(PageDock.Github, fn conn ->
        case conn.request_path do
          "/login/oauth/access_token" ->
            Req.Test.json(conn, %{"access_token" => "gho_x", "scope" => "user:email"})

          "/user" ->
            Req.Test.json(conn, %{"id" => 555, "login" => "someone", "email" => existing.email})
        end
      end)

      conn = get(build_conn(), ~p"/auth/github/login")
      state = get_session(conn, "github_oauth_state")

      conn = get(conn, ~p"/auth/github/callback?#{[code: "abc", state: state]}")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "already exists"
      refute get_session(conn, :user_token)
    end

    test "callback failure redirects to the login page" do
      Req.Test.stub(PageDock.Github, fn conn ->
        Req.Test.json(conn, %{"error" => "bad_verification_code"})
      end)

      conn = get(build_conn(), ~p"/auth/github/login")
      state = get_session(conn, "github_oauth_state")

      conn = get(conn, ~p"/auth/github/callback?#{[code: "bad", state: state]}")

      assert redirected_to(conn) == ~p"/users/log-in"
      refute get_session(conn, :user_token)
    end
  end

  describe "DELETE /auth/github (disconnect)" do
    test "removes the connected account", %{conn: conn, user: user, scope: scope} do
      github_account_fixture(user)
      assert Github.connected?(scope)

      conn = delete(conn, ~p"/auth/github")

      assert redirected_to(conn) == ~p"/users/settings"
      refute Github.connected?(scope)
    end
  end

  defp github_stub(conn) do
    case conn.request_path do
      "/login/oauth/access_token" ->
        Req.Test.json(conn, %{
          "access_token" => "gho_test_token",
          "scope" => "repo,admin:repo_hook"
        })

      "/user" ->
        Req.Test.json(conn, %{"id" => 12_345, "login" => "octocat", "avatar_url" => nil})
    end
  end

  defp github_stub_with_email(conn) do
    case conn.request_path do
      "/login/oauth/access_token" ->
        Req.Test.json(conn, %{"access_token" => "gho_test_token", "scope" => "user:email,repo"})

      "/user" ->
        Req.Test.json(conn, %{
          "id" => 12_345,
          "login" => "octocat",
          "email" => "octocat@example.com",
          "avatar_url" => nil
        })
    end
  end
end
