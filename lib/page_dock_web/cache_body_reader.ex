defmodule PageDockWeb.CacheBodyReader do
  @moduledoc """
  A `Plug.Parsers` body reader that stashes the raw request body for webhook
  paths, so the JSON parser can still run while the controller retains the exact
  bytes needed to verify an HMAC signature.
  """

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)

    conn =
      if String.starts_with?(conn.request_path, "/webhooks/") do
        update_in(conn.assigns[:raw_body], fn chunks -> [body | chunks || []] end)
      else
        conn
      end

    {:ok, body, conn}
  end

  @doc "Returns the cached raw body for a webhook request, or nil."
  def raw_body(conn) do
    case conn.assigns[:raw_body] do
      nil -> nil
      chunks -> chunks |> Enum.reverse() |> IO.iodata_to_binary()
    end
  end
end
