defmodule PageDockWeb.SiteLive.Index do
  use PageDockWeb, :live_view

  alias PageDock.Deployments
  alias PageDock.Deployments.Storage
  alias PageDock.Github
  alias PageDock.Sites

  # Per-site tile/stripe gradients, chosen deterministically from the slug.
  @tiles [
    "bg-[linear-gradient(135deg,#5B5FE8,#8A63F0)]",
    "bg-[linear-gradient(135deg,#0FA37F,#38C89F)]",
    "bg-[linear-gradient(135deg,#E08A15,#F5B54A)]",
    "bg-[linear-gradient(135deg,#E0457B,#F07CA3)]",
    "bg-[linear-gradient(135deg,#2C8CE0,#62B3F5)]"
  ]
  @stripes [
    "bg-[linear-gradient(180deg,#5B5FE8,#8A63F0)]",
    "bg-[linear-gradient(180deg,#0FA37F,#38C89F)]",
    "bg-[linear-gradient(180deg,#E08A15,#F5B54A)]",
    "bg-[linear-gradient(180deg,#E0457B,#F07CA3)]",
    "bg-[linear-gradient(180deg,#2C8CE0,#62B3F5)]"
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      active={:sites}
      title="Sites"
      breadcrumb="All"
    >
      <:actions>
        <.link navigate={~p"/sites/new"} class="btn-primary h-7 px-3 text-[12.5px] no-underline">
          New site
        </.link>
      </:actions>

      <div class="flex items-end mb-5">
        <div>
          <h2 class="text-[22px] font-semibold tracking-[-0.02em] text-text">Your sites</h2>
          <p class="mt-0.5 text-[13.5px] text-muted">
            Every push to a linked repository redeploys the site.
          </p>
        </div>
      </div>

      <div :if={@site_count == 0} class="card p-10 text-center" id="sites-empty">
        <p class="text-text font-medium">No sites yet</p>
        <p class="mt-1 text-[13px] text-muted">
          Link a GitHub repository to publish your first site.
        </p>
        <.link navigate={~p"/sites/new"} class="btn-primary h-8 px-3 no-underline inline-flex mt-4">
          Link a repository
        </.link>
      </div>

      <div :if={@site_count > 0} id="sites" phx-update="stream" class="flex flex-col gap-2.5">
        <div
          :for={{dom_id, site} <- @streams.sites}
          id={dom_id}
          class="card flex items-center h-[72px] overflow-hidden hover:border-border2 transition-colors"
        >
          <span class={["w-1 self-stretch shrink-0", stripe_gradient(site.slug)]}></span>

          <.link
            navigate={~p"/sites/#{site}"}
            class="flex items-center gap-3.5 pl-3.5 min-w-0 basis-[34%] shrink-0 no-underline"
          >
            <span class={[
              "w-10 h-10 rounded-[10px] flex items-center justify-center text-white font-mono text-[12px] font-semibold shrink-0",
              tile_gradient(site.slug)
            ]}>
              {slug_badge(site.slug)}
            </span>
            <span class="min-w-0">
              <span class="flex items-center text-[14.5px] font-semibold tracking-[-0.01em] text-text truncate">
                {site.name}
                <span class={["pill ml-2.5", pill_class(@statuses[site.id])]}>
                  <i></i>{pill_label(@statuses[site.id])}
                </span>
              </span>
              <span class="block text-[12.5px] font-mono text-muted truncate">
                {Sites.public_domain(site)}
              </span>
            </span>
          </.link>

          <span class="flex items-center min-w-0 basis-[30%] shrink-0 px-4 text-[12.5px] font-mono text-muted truncate">
            <svg class="w-3.5 h-3.5 mr-2 shrink-0 text-faint" viewBox="0 0 16 16" fill="currentColor">
              <path d="M8 0C3.58 0 0 3.58 0 8a8 8 0 005.47 7.59c.4.07.55-.17.55-.38v-1.33c-2.23.48-2.7-1.07-2.7-1.07-.36-.92-.89-1.17-.89-1.17-.73-.5.06-.49.06-.49.8.06 1.23.83 1.23.83.71 1.22 1.87.87 2.33.66.07-.52.28-.87.5-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82A7.6 7.6 0 018 3.87c.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.28.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48v2.2c0 .21.15.46.55.38A8 8 0 0016 8c0-4.42-3.58-8-8-8z" />
            </svg>
            <span class="truncate">{site.repo_owner}/{site.repo_name}</span>
            <span class="ml-2 shrink-0 px-1.5 py-px rounded-[5px] bg-raised border border-border text-muted text-[11.5px]">
              {site.default_branch}
            </span>
          </span>

          <span class="basis-[12%] shrink-0 text-[13px] text-muted">
            {last_deploy_label(@statuses[site.id])}
          </span>

          <span class="flex-1 flex justify-end items-center gap-1 pr-4">
            <a
              href={"https://#{Sites.public_domain(site)}"}
              target="_blank"
              rel="noopener"
              title="Open site"
              class="w-[30px] h-[30px] rounded-md text-faint hover:text-text hover:bg-raised inline-flex items-center justify-center"
            >
              <.icon name="hero-arrow-top-right-on-square" class="size-4" />
            </a>
            <.link
              phx-click={JS.push("delete", value: %{id: site.id})}
              data-confirm={"Delete #{site.name}? This cannot be undone."}
              id={"delete-#{site.id}"}
              title="Delete site"
              class="w-[30px] h-[30px] rounded-md text-faint hover:text-bad hover:bg-raised inline-flex items-center justify-center cursor-pointer"
            >
              <.icon name="hero-trash" class="size-4" />
            </.link>
          </span>
        </div>
      </div>

      <.link
        :if={@site_count > 0}
        navigate={~p"/sites/new"}
        class="flex items-center justify-center h-[60px] mt-2.5 rounded-[10px] border border-dashed border-border2 text-muted text-[13.5px] font-medium hover:text-accent hover:border-accent hover:bg-accent-soft transition-colors no-underline"
      >
        <span class={[
          "w-6 h-6 rounded-[7px] mr-2.5 text-white inline-flex items-center justify-center text-[16px] leading-none",
          "bg-[linear-gradient(135deg,#5B5FE8,#8A63F0)]"
        ]}>
          +
        </span>
        Add a site from a GitHub repository
      </.link>
    </Layouts.dashboard>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    sites = Sites.list_sites(socket.assigns.current_scope)
    statuses = Deployments.latest_by_site_ids(Enum.map(sites, & &1.id))

    {:ok,
     socket
     |> assign(:page_title, "Sites")
     |> assign(:site_count, length(sites))
     |> assign(:statuses, statuses)
     |> stream(:sites, sites)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    site = Sites.get_site!(scope, id)

    Sites.deregister_webhook(site, Github.get_connected_account(scope))
    {:ok, _} = Sites.delete_site(scope, site)
    Storage.delete(site.slug)

    {:noreply,
     socket
     |> update(:site_count, &(&1 - 1))
     |> stream_delete(:sites, site)
     |> put_flash(:info, "Deleted #{site.name}.")}
  end

  ## Presentation helpers

  defp slug_badge(slug), do: slug |> String.replace("-", "") |> String.slice(0, 2)

  defp color_index(slug), do: rem(:erlang.phash2(slug), 5)
  defp tile_gradient(slug), do: Enum.at(@tiles, color_index(slug))
  defp stripe_gradient(slug), do: Enum.at(@stripes, color_index(slug))

  defp pill_label(nil), do: "No deploys"
  defp pill_label(%{status: "success"}), do: "Live"
  defp pill_label(%{status: "failed"}), do: "Failed"
  defp pill_label(_), do: "Deploying"

  defp pill_class(nil), do: "text-muted bg-raised border border-border"
  defp pill_class(%{status: "success"}), do: "text-[#0F8A5F] bg-[#E6F7EF] border border-[#B7E8CF]"
  defp pill_class(%{status: "failed"}), do: "text-[#C8333F] bg-[#FDEBEC] border border-[#F5C2C6]"
  defp pill_class(_), do: "text-[#4F52D4] bg-[#ECEDFD] border border-[#C9CCF7]"

  defp last_deploy_label(nil), do: "—"
  defp last_deploy_label(%{inserted_at: at}), do: time_ago(at)

  defp time_ago(%DateTime{} = at) do
    seconds = DateTime.diff(DateTime.utc_now(), at)

    cond do
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds < 86_400 -> "#{div(seconds, 3600)}h ago"
      true -> "#{div(seconds, 86_400)}d ago"
    end
  end
end
