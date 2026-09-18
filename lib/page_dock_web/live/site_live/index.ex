defmodule PageDockWeb.SiteLive.Index do
  use PageDockWeb, :live_view

  alias PageDock.Sites

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center justify-between gap-4 mb-6">
        <div>
          <h1 class="text-xl font-medium tracking-[-0.02em] text-text">Your sites</h1>
          <p class="mt-1 text-[14px] text-muted">
            Repositories linked to Pagedock, each served at its own address.
          </p>
        </div>
        <.link navigate={~p"/sites/new"} class="btn-primary h-9 px-3 no-underline shrink-0">
          New site
        </.link>
      </div>

      <div
        :if={@site_count == 0}
        class="card p-10 text-center"
        id="sites-empty"
      >
        <p class="text-text font-medium">No sites yet</p>
        <p class="mt-1 text-[14px] text-muted">
          Link a GitHub repository to publish your first site.
        </p>
        <.link navigate={~p"/sites/new"} class="btn-primary h-9 px-3 no-underline inline-flex mt-4">
          Link a repository
        </.link>
      </div>

      <div :if={@site_count > 0} id="sites" phx-update="stream" class="grid gap-3">
        <div :for={{dom_id, site} <- @streams.sites} id={dom_id} class="card p-5">
          <div class="flex items-center justify-between gap-4">
            <div class="min-w-0">
              <.link
                navigate={~p"/sites/#{site}"}
                class="text-text font-medium hover:underline no-underline"
              >
                {site.name}
              </.link>
              <p class="text-[13px] text-muted truncate">
                {site.repo_owner}/{site.repo_name} · {site.default_branch}
              </p>
            </div>
            <div class="flex items-center gap-3 shrink-0">
              <span class="text-[13px] text-faint font-mono">{site.slug}.pagedock.eu</span>
              <.link
                phx-click={JS.push("delete", value: %{id: site.id})}
                data-confirm={"Delete #{site.name}? This cannot be undone."}
                class="text-[13px] text-muted hover:text-text cursor-pointer"
                id={"delete-#{site.id}"}
              >
                Delete
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    sites = Sites.list_sites(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Sites")
     |> assign(:site_count, length(sites))
     |> stream(:sites, sites)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    site = Sites.get_site!(scope, id)
    {:ok, _} = Sites.delete_site(scope, site)

    {:noreply,
     socket
     |> update(:site_count, &(&1 - 1))
     |> stream_delete(:sites, site)
     |> put_flash(:info, "Deleted #{site.name}.")}
  end
end
