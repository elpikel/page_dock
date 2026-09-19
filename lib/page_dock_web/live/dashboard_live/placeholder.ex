defmodule PageDockWeb.DashboardLive.Placeholder do
  @moduledoc """
  Simple "coming soon" pages for nav destinations that aren't built yet
  (Deploys, Domains, Billing). Keeps the sidebar fully navigable.
  """
  use PageDockWeb, :live_view

  @impl true
  def render(%{live_action: :billing} = assigns) do
    ~H"""
    <Layouts.dashboard flash={@flash} current_scope={@current_scope} active={:billing} title="Billing">
      <div class="max-w-[720px] grid gap-4">
        <div class="card p-5 flex items-center gap-4">
          <div>
            <div class="text-[13.5px] font-medium text-text">Beta plan</div>
            <p class="text-[12.5px] text-muted mt-0.5">
              Free while Pagedock is in beta. 5 sites, pagedock.eu addresses, EU hosting.
            </p>
          </div>
          <span class="ml-auto pill bg-accent-soft text-accent">Current</span>
        </div>
        <div class="card p-5 flex items-center gap-4 opacity-70">
          <div>
            <div class="text-[13.5px] font-medium text-text">Pro</div>
            <p class="text-[12.5px] text-muted mt-0.5">
              Unlimited sites, custom domains, private repos. Available when beta ends.
            </p>
          </div>
          <button class="btn-secondary ml-auto" disabled>Coming soon</button>
        </div>
      </div>
    </Layouts.dashboard>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      active={@live_action}
      title={@title}
    >
      <div class="max-w-[720px]">
        <div class="card p-8 text-center">
          <div class="text-[14px] font-medium text-text mb-1">{@heading}</div>
          <p class="text-[13px] text-muted max-w-[46ch] mx-auto">{@body}</p>
        </div>
      </div>
    </Layouts.dashboard>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_content(socket, socket.assigns.live_action)}
  end

  defp assign_content(socket, :deploys) do
    socket
    |> assign(:page_title, "Deploys")
    |> assign(:title, "Deploys")
    |> assign(:heading, "A unified deploy timeline is coming")
    |> assign(:body, "For now, open a site to see its deployment history.")
  end

  defp assign_content(socket, :domains) do
    socket
    |> assign(:page_title, "Domains")
    |> assign(:title, "Domains")
    |> assign(:heading, "Custom domains are coming")
    |> assign(
      :body,
      "Point a CNAME at Pagedock and we'll issue the certificate. Until then every site is served at its pagedock.eu address."
    )
  end

  defp assign_content(socket, :billing) do
    assign(socket, :page_title, "Billing")
  end
end
