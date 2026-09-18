defmodule PageDock.Github do
  @moduledoc """
  The GitHub context: OAuth account linking and the low-level GitHub API calls
  used to act on a connected user's behalf.

  HTTP is performed with `Req`. Requests merge the options under
  `config :page_dock, :github, req_options: [...]`, which lets tests inject a
  `Req.Test` stub instead of hitting github.com.
  """
  import Ecto.Query, warn: false

  alias PageDock.Accounts
  alias PageDock.Accounts.Scope
  alias PageDock.Accounts.User
  alias PageDock.Github.GithubAccount
  alias PageDock.Repo

  @authorize_url "https://github.com/login/oauth/authorize"
  @token_url "https://github.com/login/oauth/access_token"
  @api_url "https://api.github.com"

  # Scopes we ask for: the user's verified email (for login), read/write repo
  # contents, and repo webhooks so a push can trigger a deploy (Phase 4).
  @scopes ["user:email", "repo", "admin:repo_hook"]

  @doc "The OAuth scopes requested during the authorize step."
  def requested_scopes, do: @scopes

  ## Account lookups

  @doc "Returns the GitHub account connected to the scope's user, or nil."
  def get_connected_account(%Scope{user: %User{id: user_id}}) do
    Repo.get_by(GithubAccount, user_id: user_id)
  end

  def get_connected_account(nil), do: nil

  @doc "Whether the scope's user has a connected GitHub account."
  def connected?(%Scope{} = scope), do: get_connected_account(scope) != nil
  def connected?(nil), do: false

  @doc """
  Disconnects (deletes) the GitHub account linked to the scope's user.

  Returns `:ok` whether or not an account existed.
  """
  def disconnect(%Scope{user: %User{id: user_id}}) do
    from(g in GithubAccount, where: g.user_id == ^user_id)
    |> Repo.delete_all()

    :ok
  end

  ## OAuth flow

  @doc """
  Builds the GitHub authorize URL the browser is redirected to.

  `state` is an opaque CSRF token the caller must also stash in the session and
  verify on callback.
  """
  def authorize_url(state) when is_binary(state) do
    query =
      URI.encode_query(
        client_id: config!(:client_id),
        redirect_uri: config!(:redirect_uri),
        scope: Enum.join(@scopes, " "),
        state: state,
        allow_signup: "false"
      )

    @authorize_url <> "?" <> query
  end

  @doc """
  Completes the OAuth flow for `scope`'s user given the `code` from the callback.

  Exchanges the code for an access token, fetches the GitHub profile, and
  upserts the `GithubAccount`. Returns `{:ok, account}` or `{:error, reason}`.
  """
  def connect_user(%Scope{user: %User{} = user}, code) when is_binary(code) do
    with {:ok, %{token: token, scopes: scopes}} <- exchange_code(code),
         {:ok, profile} <- fetch_profile(token) do
      upsert_account(user, account_attrs(profile, token, scopes))
    end
  end

  @doc """
  Completes the "Sign in with GitHub" flow for the `code` from the callback.

  Resolves the user by connected GitHub account first, then by verified email
  (creating a confirmed, passwordless account if none exists), and upserts the
  GitHub account. Returns `{:ok, %User{}}` or `{:error, reason}`.
  """
  def login_or_register_user(code) when is_binary(code) do
    with {:ok, %{token: token, scopes: scopes}} <- exchange_code(code),
         {:ok, profile} <- fetch_profile(token),
         {:ok, email} <- resolve_email(token, profile),
         {:ok, user} <- resolve_user(profile, email) do
      case upsert_account(user, account_attrs(profile, token, scopes)) do
        {:ok, _account} -> {:ok, user}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  # Resolve the user for a GitHub sign-in. Priority:
  #   1. an account already linked to this GitHub uid -> log that user in
  #   2. otherwise, only create a brand-new user. If the verified email already
  #      belongs to an account, refuse (`:email_taken`) rather than silently
  #      merging — the user must log in and link GitHub from settings.
  defp resolve_user(profile, email) do
    case Repo.get_by(GithubAccount, github_uid: profile["id"]) do
      %GithubAccount{user_id: user_id} ->
        {:ok, Repo.get!(User, user_id)}

      nil ->
        if Accounts.get_user_by_email(email) do
          {:error, {:email_taken, email}}
        else
          Accounts.register_github_user(%{email: email})
        end
    end
  end

  defp resolve_email(token, profile) do
    case profile["email"] do
      email when is_binary(email) and email != "" -> {:ok, email}
      _ -> fetch_primary_email(token)
    end
  end

  defp account_attrs(profile, token, scopes) do
    %{
      github_uid: profile["id"],
      login: profile["login"],
      avatar_url: profile["avatar_url"],
      access_token: token,
      scopes: scopes
    }
  end

  defp exchange_code(code) do
    response =
      [
        url: @token_url,
        json: %{
          client_id: config!(:client_id),
          client_secret: config!(:client_secret),
          code: code,
          redirect_uri: config!(:redirect_uri)
        },
        headers: [accept: "application/json"]
      ]
      |> request()
      |> Req.post()

    case response do
      {:ok, %{status: 200, body: %{"access_token" => token} = body}} ->
        {:ok, %{token: token, scopes: parse_scopes(body["scope"])}}

      {:ok, %{status: 200, body: %{"error" => error} = body}} ->
        {:error, {:oauth, body["error_description"] || error}}

      {:ok, %{status: status}} ->
        {:error, {:token_exchange, status}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  @doc "Fetches the authenticated user's GitHub profile for the given token."
  def fetch_profile(token) when is_binary(token) do
    case [url: @api_url <> "/user"] |> auth_request(token) |> Req.get() do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, {:profile, status}}
      {:error, exception} -> {:error, exception}
    end
  end

  @doc """
  Fetches the user's primary verified email via the GitHub API.

  Needed because `/user` only returns an email when the user has a public one.
  Falls back to any verified email; errors if none is verified.
  """
  def fetch_primary_email(token) when is_binary(token) do
    case [url: @api_url <> "/user/emails"] |> auth_request(token) |> Req.get() do
      {:ok, %{status: 200, body: emails}} when is_list(emails) ->
        primary = Enum.find(emails, &(&1["primary"] && &1["verified"]))
        verified = primary || Enum.find(emails, & &1["verified"])

        if verified, do: {:ok, verified["email"]}, else: {:error, :no_verified_email}

      {:ok, %{status: status}} ->
        {:error, {:emails, status}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  ## Persistence

  defp upsert_account(%User{} = user, attrs) do
    account =
      Repo.get_by(GithubAccount, user_id: user.id) ||
        %GithubAccount{user_id: user.id}

    account
    |> GithubAccount.connect_changeset(attrs)
    |> Repo.insert_or_update()
  end

  ## Helpers

  defp parse_scopes(nil), do: []

  defp parse_scopes(scope) when is_binary(scope) do
    scope
    |> String.split(~r/[,\s]+/, trim: true)
    |> Enum.uniq()
  end

  defp auth_request(opts, token) do
    opts
    |> Keyword.update(:headers, [authorization: "Bearer " <> token], fn headers ->
      [{:authorization, "Bearer " <> token} | headers]
    end)
    |> request()
  end

  defp request(opts) do
    # Req decodes JSON responses to string-keyed maps by default.
    base = [headers: [user_agent: "PageDock", accept: "application/vnd.github+json"]]

    base
    |> Keyword.merge(opts, fn
      :headers, v1, v2 -> Keyword.merge(v1, v2)
      _key, _v1, v2 -> v2
    end)
    |> Keyword.merge(req_options())
    |> Req.new()
  end

  defp req_options, do: Keyword.get(github_config(), :req_options, [])

  defp config!(key) do
    github_config()[key] ||
      raise """
      missing GitHub OAuth config `#{inspect(key)}`.
      Set it via `config :page_dock, :github, #{key}: ...` (see config/runtime.exs).
      """
  end

  defp github_config, do: Application.get_env(:page_dock, :github, [])
end
