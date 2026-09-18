defmodule PageDockWeb.GithubAuthController do
  @moduledoc """
  Drives the GitHub OAuth flows.

  Two entry points share one callback, distinguished by a `purpose` stashed in
  the session alongside a CSRF `state`:

    * `:login`  — public "Sign in with GitHub" (find-or-create a user, log in)
    * `:link`   — authenticated "Connect GitHub" (attach a repo-capable token)
  """
  use PageDockWeb, :controller

  alias PageDock.Github
  alias PageDockWeb.UserAuth

  @state_key "github_oauth_state"
  @purpose_key "github_oauth_purpose"

  @doc "Public: begins the 'Sign in with GitHub' flow."
  def login(conn, _params), do: start_oauth(conn, "login")

  @doc "Authenticated: begins the 'Connect GitHub' (account linking) flow."
  def authorize(conn, _params), do: start_oauth(conn, "link")

  defp start_oauth(conn, purpose) do
    state = random_state()

    conn
    |> put_session(@state_key, state)
    |> put_session(@purpose_key, purpose)
    |> redirect(external: Github.authorize_url(state))
  end

  @doc "Handles GitHub's redirect back after the user authorizes (or denies)."
  def callback(conn, params) do
    purpose = get_session(conn, @purpose_key)
    expected = get_session(conn, @state_key)

    conn = conn |> delete_session(@state_key) |> delete_session(@purpose_key)

    cond do
      params["error"] ->
        fail(conn, purpose, params["error_description"] || "GitHub authorization was cancelled.")

      is_nil(params["code"]) or not valid_state?(expected, params["state"]) ->
        fail(conn, purpose, "GitHub sign-in could not be verified. Please try again.")

      purpose == "login" ->
        handle_login(conn, params["code"])

      true ->
        handle_link(conn, params["code"])
    end
  end

  @doc "Authenticated: removes the connected GitHub account for the signed-in user."
  def disconnect(conn, _params) do
    :ok = Github.disconnect(conn.assigns.current_scope)

    conn
    |> put_flash(:info, "Disconnected your GitHub account.")
    |> redirect(to: ~p"/users/settings")
  end

  ## Flow handlers

  defp handle_login(conn, code) do
    case Github.login_or_register_user(code) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Signed in with GitHub.")
        |> UserAuth.log_in_user(user)

      {:error, {:email_taken, email}} ->
        conn
        |> put_flash(
          :error,
          "An account for #{email} already exists. Log in with that account, " <>
            "then connect GitHub from your settings."
        )
        |> redirect(to: ~p"/users/log-in")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Could not sign in with GitHub. Please try again.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  defp handle_link(conn, code) do
    case Github.connect_user(conn.assigns.current_scope, code) do
      {:ok, account} ->
        conn
        |> put_flash(:info, "Connected GitHub account @#{account.login}.")
        |> redirect(to: ~p"/users/settings")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Could not connect your GitHub account. Please try again.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  ## Helpers

  # On failure, send link attempts back to settings and login attempts back to log-in.
  defp fail(conn, "link", message) do
    conn |> put_flash(:error, message) |> redirect(to: ~p"/users/settings")
  end

  defp fail(conn, _purpose, message) do
    conn |> put_flash(:error, message) |> redirect(to: ~p"/users/log-in")
  end

  defp random_state, do: :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)

  defp valid_state?(expected, got) when is_binary(expected) and is_binary(got),
    do: Plug.Crypto.secure_compare(expected, got)

  defp valid_state?(_, _), do: false
end
