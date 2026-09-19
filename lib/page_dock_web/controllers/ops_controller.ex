defmodule PageDockWeb.OpsController do
  @moduledoc """
  Operational endpoints for the reverse proxy and monitoring.

    * `GET /healthz` — liveness probe, always 200 when the app is up.
    * `GET /internal/tls-check?domain=...` — Caddy on-demand TLS "ask" endpoint;
      returns 200 only for hosts this app actually serves, so certificates are
      never issued for arbitrary hostnames.
  """
  use PageDockWeb, :controller

  alias PageDock.Sites

  def healthz(conn, _params), do: send_resp(conn, 200, "ok")

  def tls_check(conn, %{"domain" => domain}) do
    if Sites.servable_host?(domain) do
      send_resp(conn, 200, "ok")
    else
      send_resp(conn, 403, "unknown host")
    end
  end

  def tls_check(conn, _params), do: send_resp(conn, 400, "missing domain")
end
