defmodule PageDock.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PageDockWeb.Telemetry,
      PageDock.Repo,
      {DNSCluster, query: Application.get_env(:page_dock, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PageDock.PubSub},
      # Start a worker by calling: PageDock.Worker.start_link(arg)
      # {PageDock.Worker, arg},
      # Start to serve requests, typically the last entry
      PageDockWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PageDock.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PageDockWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
