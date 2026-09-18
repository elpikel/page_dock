defmodule PageDock.GithubTest do
  use PageDock.DataCase, async: true

  import PageDock.AccountsFixtures
  import PageDock.GithubFixtures

  alias PageDock.Accounts.Scope
  alias PageDock.Github

  describe "authorize_url/1" do
    test "includes client_id, requested scopes and state" do
      url = Github.authorize_url("state-123")

      assert String.starts_with?(url, "https://github.com/login/oauth/authorize?")
      assert url =~ "client_id=test-client-id"
      assert url =~ "state=state-123"
      # scopes are www-form encoded (space -> +, : -> %3A)
      assert url =~ "scope=user%3Aemail+repo+admin%3Arepo_hook"
    end
  end

  describe "login_or_register_user/1" do
    test "creates a new confirmed user from the GitHub profile" do
      Req.Test.stub(PageDock.Github, &github_stub/1)

      assert {:ok, user} = Github.login_or_register_user("code")
      assert user.email == "octocat@example.com"
      assert user.confirmed_at
      account = Github.get_connected_account(Scope.for_user(user))
      assert account.login == "octocat"
      assert account.github_uid == 12_345
    end

    test "refuses to merge into an existing account with the same email" do
      existing = user_fixture()

      Req.Test.stub(PageDock.Github, fn conn ->
        case conn.request_path do
          "/login/oauth/access_token" ->
            Req.Test.json(conn, %{"access_token" => "gho_x", "scope" => "user:email,repo"})

          "/user" ->
            Req.Test.json(conn, %{"id" => 999, "login" => "someuser", "email" => existing.email})
        end
      end)

      assert {:error, {:email_taken, email}} = Github.login_or_register_user("code")
      assert email == existing.email
      # the existing account is untouched — no GitHub account attached
      refute Github.connected?(Scope.for_user(existing))
    end

    test "returns the account's user when the GitHub uid is already linked" do
      user = user_fixture()
      github_account_fixture(user, github_uid: 12_345, login: "octocat")

      Req.Test.stub(PageDock.Github, &github_stub/1)

      assert {:ok, resolved} = Github.login_or_register_user("code")
      assert resolved.id == user.id
    end

    test "falls back to /user/emails when the profile email is private" do
      Req.Test.stub(PageDock.Github, fn conn ->
        case conn.request_path do
          "/login/oauth/access_token" ->
            Req.Test.json(conn, %{"access_token" => "gho_x", "scope" => "user:email"})

          "/user" ->
            Req.Test.json(conn, %{"id" => 42, "login" => "priv", "email" => nil})

          "/user/emails" ->
            Req.Test.json(conn, [
              %{"email" => "secondary@example.com", "primary" => false, "verified" => true},
              %{"email" => "primary@example.com", "primary" => true, "verified" => true}
            ])
        end
      end)

      assert {:ok, user} = Github.login_or_register_user("code")
      assert user.email == "primary@example.com"
    end

    test "errors when no verified email is available" do
      Req.Test.stub(PageDock.Github, fn conn ->
        case conn.request_path do
          "/login/oauth/access_token" ->
            Req.Test.json(conn, %{"access_token" => "gho_x", "scope" => "user:email"})

          "/user" ->
            Req.Test.json(conn, %{"id" => 7, "login" => "noemail", "email" => nil})

          "/user/emails" ->
            Req.Test.json(conn, [
              %{"email" => "x@example.com", "primary" => true, "verified" => false}
            ])
        end
      end)

      assert {:error, :no_verified_email} = Github.login_or_register_user("code")
    end
  end

  describe "access token encryption" do
    test "stores the token as ciphertext but reads it back in plaintext" do
      scope = Scope.for_user(user_fixture())
      Req.Test.stub(PageDock.Github, &github_stub/1)

      assert {:ok, account} = Github.connect_user(scope, "code")
      # struct/loaded value is transparently decrypted
      assert Github.get_connected_account(scope).access_token == "gho_test_token"

      # the raw column holds encrypted bytes, not the plaintext token
      raw =
        PageDock.Repo.query!(
          "SELECT access_token FROM github_accounts WHERE id = $1",
          [account.id]
        )

      [[stored]] = raw.rows
      assert is_binary(stored)
      refute stored == "gho_test_token"
      refute String.contains?(stored, "gho_test_token")
    end
  end

  describe "connect_user/2" do
    setup do
      %{scope: Scope.for_user(user_fixture())}
    end

    test "exchanges the code and stores the account", %{scope: scope} do
      Req.Test.stub(PageDock.Github, &github_stub/1)

      assert {:ok, account} = Github.connect_user(scope, "the-code")
      assert account.github_uid == 12_345
      assert account.login == "octocat"
      assert account.access_token == "gho_test_token"
      assert account.avatar_url == "https://avatars/1"
      assert account.scopes == ["repo", "admin:repo_hook"]
      assert account.user_id == scope.user.id
    end

    test "reconnecting updates the existing account rather than duplicating", %{scope: scope} do
      Req.Test.stub(PageDock.Github, &github_stub/1)
      assert {:ok, first} = Github.connect_user(scope, "code-1")

      Req.Test.stub(PageDock.Github, fn conn ->
        case conn.request_path do
          "/login/oauth/access_token" ->
            Req.Test.json(conn, %{"access_token" => "gho_rotated", "scope" => "repo"})

          "/user" ->
            Req.Test.json(conn, %{"id" => 12_345, "login" => "octocat", "avatar_url" => nil})
        end
      end)

      assert {:ok, second} = Github.connect_user(scope, "code-2")
      assert second.id == first.id
      assert second.access_token == "gho_rotated"
      assert second.scopes == ["repo"]
    end

    test "returns an error when GitHub rejects the code", %{scope: scope} do
      Req.Test.stub(PageDock.Github, fn conn ->
        Req.Test.json(conn, %{"error" => "bad_verification_code", "error_description" => "nope"})
      end)

      assert {:error, {:oauth, "nope"}} = Github.connect_user(scope, "bad")
      refute Github.connected?(scope)
    end

    test "returns an error when the profile fetch fails", %{scope: scope} do
      Req.Test.stub(PageDock.Github, fn conn ->
        case conn.request_path do
          "/login/oauth/access_token" ->
            Req.Test.json(conn, %{"access_token" => "gho_x", "scope" => "repo"})

          "/user" ->
            conn |> Plug.Conn.put_status(401) |> Req.Test.json(%{"message" => "Bad credentials"})
        end
      end)

      assert {:error, {:profile, 401}} = Github.connect_user(scope, "code")
      refute Github.connected?(scope)
    end
  end

  describe "get_connected_account/1 and connected?/1" do
    test "returns the account for the scope's user" do
      user = user_fixture()
      scope = Scope.for_user(user)
      account = github_account_fixture(user)

      assert Github.connected?(scope)
      assert Github.get_connected_account(scope).id == account.id
    end

    test "returns nil / false when nothing is connected" do
      scope = Scope.for_user(user_fixture())
      refute Github.connected?(scope)
      assert Github.get_connected_account(scope) == nil
    end

    test "handles a nil scope" do
      refute Github.connected?(nil)
      assert Github.get_connected_account(nil) == nil
    end
  end

  describe "disconnect/1" do
    test "removes the connected account" do
      user = user_fixture()
      scope = Scope.for_user(user)
      github_account_fixture(user)

      assert :ok = Github.disconnect(scope)
      refute Github.connected?(scope)
    end

    test "is a no-op when nothing is connected" do
      scope = Scope.for_user(user_fixture())
      assert :ok = Github.disconnect(scope)
    end
  end

  defp github_stub(conn) do
    case conn.request_path do
      "/login/oauth/access_token" ->
        Req.Test.json(conn, %{
          "access_token" => "gho_test_token",
          "scope" => "repo,admin:repo_hook",
          "token_type" => "bearer"
        })

      "/user" ->
        Req.Test.json(conn, %{
          "id" => 12_345,
          "login" => "octocat",
          "email" => "octocat@example.com",
          "avatar_url" => "https://avatars/1"
        })
    end
  end
end
