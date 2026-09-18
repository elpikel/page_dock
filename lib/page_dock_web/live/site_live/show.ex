defmodule PageDockWeb.SiteLive.Show do
  use PageDockWeb, :live_view

  alias PageDock.Sites

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mb-6">
        <.link navigate={~p"/sites"} class="text-[13px] text-muted hover:text-text no-underline">
          ← Back to sites
        </.link>
        <h1 class="text-xl font-medium tracking-[-0.02em] text-text mt-2">{@site.name}</h1>
        <p class="mt-1 text-[14px] text-muted font-mono">{@site.slug}.pagedock.eu</p>
      </div>

      <div class="card divide-y divide-border">
        <div class="grid grid-cols-[160px_1fr] gap-4 p-5 text-[14px]">
          <span class="text-muted">Repository</span>
          <a
            href={"https://github.com/#{@site.repo_owner}/#{@site.repo_name}"}
            class="text-accent hover:underline"
            target="_blank"
            rel="noopener"
          >
            {@site.repo_owner}/{@site.repo_name}
          </a>
        </div>
        <div class="grid grid-cols-[160px_1fr] gap-4 p-5 text-[14px]">
          <span class="text-muted">Branch</span>
          <span class="text-text font-mono">{@site.default_branch}</span>
        </div>
        <div class="grid grid-cols-[160px_1fr] gap-4 p-5 text-[14px]">
          <span class="text-muted">Deploys</span>
          <span class="text-muted">
            Automatic deploys on push are coming soon.
          </span>
        </div>
      </div>

      <div class="mt-6">
        <.link
          phx-click="delete"
          data-confirm={"Delete #{@site.name}? This cannot be undone."}
          class="text-[13px] text-muted hover:text-text cursor-pointer"
          id="delete-site"
        >
          Delete this site
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Sites.get_site(socket.assigns.current_scope, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Site not found.")
         |> push_navigate(to: ~p"/sites")}

      site ->
        {:ok, socket |> assign(:page_title, site.name) |> assign(:site, site)}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    scope = socket.assigns.current_scope
    {:ok, _} = Sites.delete_site(scope, socket.assigns.site)

    {:noreply,
     socket
     |> put_flash(:info, "Deleted #{socket.assigns.site.name}.")
     |> push_navigate(to: ~p"/sites")}
  end
end
