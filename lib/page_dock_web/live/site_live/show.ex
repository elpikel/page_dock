defmodule PageDockWeb.SiteLive.Show do
  use PageDockWeb, :live_view

  alias PageDock.Deployments
  alias PageDock.Deployments.Storage
  alias PageDock.Github
  alias PageDock.Sites

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      active={:sites}
      title={@site.name}
      breadcrumb={Sites.public_domain(@site)}
    >
      <:actions>
        <.button
          phx-click="deploy"
          phx-disable-with="Queuing..."
          class="btn-primary h-7 px-3 text-[12.5px]"
          id="deploy-now"
        >
          Deploy now
        </.button>
      </:actions>

      <div class="max-w-[820px]">
        <.link navigate={~p"/sites"} class="text-[13px] text-muted hover:text-text no-underline">
          ← Back to sites
        </.link>

        <div class="card divide-y divide-border mt-4">
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
            <span class="text-muted">Webhook</span>
            <span class={["font-medium", if(@site.webhook_id, do: "text-ok", else: "text-muted")]}>
              {if @site.webhook_id, do: "Active — pushes deploy automatically", else: "Not set up"}
            </span>
          </div>
        </div>

        <div class="mt-8">
          <h2 class="text-[15px] font-medium text-text mb-3">Deployments</h2>
          <div :if={@deployments == []} class="card p-6 text-[14px] text-muted" id="deployments-empty">
            No deployments yet. Push to <span class="font-mono">{@site.default_branch}</span>
            to trigger one.
          </div>
          <div :if={@deployments != []} class="card divide-y divide-border" id="deployments">
            <div
              :for={deployment <- @deployments}
              id={"deployment-#{deployment.id}"}
              class="flex items-center justify-between gap-4 p-4 text-[14px]"
            >
              <div class="min-w-0">
                <span class="font-mono text-text">{String.slice(deployment.commit_sha, 0, 7)}</span>
                <span class="text-muted"> ·    {deployment.ref}</span>
              </div>
              <span class={["text-[13px] font-medium", status_color(deployment.status)]}>
                {deployment.status}
              </span>
            </div>
          </div>
        </div>

        <div class="mt-6">
          <.link
            phx-click="delete"
            data-confirm={"Delete #{@site.name}? This cannot be undone."}
            class="text-[13px] text-muted hover:text-bad cursor-pointer"
            id="delete-site"
          >
            Delete this site
          </.link>
        </div>
      </div>
    </Layouts.dashboard>
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
        {:ok,
         socket
         |> assign(:page_title, site.name)
         |> assign(:site, site)
         |> assign(:deployments, Deployments.list_deployments(site))}
    end
  end

  defp status_color("success"), do: "text-ok"
  defp status_color("failed"), do: "text-error"
  defp status_color(_), do: "text-muted"

  @impl true
  def handle_event("deploy", _params, socket) do
    site = socket.assigns.site

    case Deployments.deploy(site, %{commit_sha: site.default_branch, ref: site.default_branch}) do
      {:ok, _deployment} ->
        {:noreply,
         socket
         |> put_flash(:info, "Deploy queued for #{site.default_branch}.")
         |> assign(:deployments, Deployments.list_deployments(site))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Couldn't queue the deploy. Please try again.")}
    end
  end

  def handle_event("delete", _params, socket) do
    scope = socket.assigns.current_scope
    site = socket.assigns.site

    Sites.deregister_webhook(site, Github.get_connected_account(scope))
    {:ok, _} = Sites.delete_site(scope, site)
    Storage.delete(site.slug)

    {:noreply,
     socket
     |> put_flash(:info, "Deleted #{site.name}.")
     |> push_navigate(to: ~p"/sites")}
  end
end
