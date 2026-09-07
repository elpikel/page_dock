defmodule PageDock.Repo do
  use Ecto.Repo,
    otp_app: :page_dock,
    adapter: Ecto.Adapters.Postgres
end
