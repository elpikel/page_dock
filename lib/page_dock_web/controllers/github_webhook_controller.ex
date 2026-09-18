defmodule PageDockWeb.GithubWebhookController do
  @moduledoc """
  Receives GitHub push webhooks at `/webhooks/github/:site_id`.

  Each site has its own webhook secret, so the URL identifies the site and the
  `X-Hub-Signature-256` HMAC proves the delivery is genuine. A push to the
  site's default branch enqueues a deploy.
  """
  use PageDockWeb, :controller

  require Logger

  alias PageDock.Deployments
  alias PageDock.Sites
  alias PageDockWeb.CacheBodyReader

  def create(conn, %{"site_id" => site_id} = params) do
    with %{} = site <- Sites.get_site_by_id(site_id),
         :ok <- verify_signature(conn, site) do
      handle_event(conn, site, params)
    else
      nil ->
        send_resp(conn, 404, "unknown site")

      {:error, :bad_signature} ->
        send_resp(conn, 401, "invalid signature")
    end
  end

  defp handle_event(conn, site, params) do
    case event_type(conn) do
      "ping" ->
        send_resp(conn, 200, "pong")

      "push" ->
        handle_push(conn, site, params)

      _other ->
        send_resp(conn, 202, "ignored")
    end
  end

  defp handle_push(conn, site, params) do
    branch = String.replace_prefix(params["ref"] || "", "refs/heads/", "")
    deleted = params["deleted"] == true
    sha = params["after"]

    if branch == site.default_branch and not deleted and is_binary(sha) do
      case Deployments.deploy(site, %{commit_sha: sha, ref: branch}) do
        {:ok, _deployment} ->
          send_resp(conn, 202, "queued")

        {:error, _reason} ->
          send_resp(conn, 500, "could not queue deploy")
      end
    else
      send_resp(conn, 202, "ignored")
    end
  end

  defp verify_signature(conn, site) do
    with [header] <- get_req_header(conn, "x-hub-signature-256"),
         raw when is_binary(raw) <- CacheBodyReader.raw_body(conn),
         expected = "sha256=" <> hmac(site.webhook_secret, raw),
         true <- Plug.Crypto.secure_compare(header, expected) do
      :ok
    else
      _ -> {:error, :bad_signature}
    end
  end

  defp hmac(secret, body) do
    :hmac |> :crypto.mac(:sha256, secret, body) |> Base.encode16(case: :lower)
  end

  defp event_type(conn) do
    case get_req_header(conn, "x-github-event") do
      [type | _] -> type
      [] -> nil
    end
  end
end
