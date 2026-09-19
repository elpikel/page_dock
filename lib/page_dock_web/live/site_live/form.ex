defmodule PageDockWeb.SiteLive.Form do
  use PageDockWeb, :live_view

  alias PageDock.Github
  alias PageDock.Sites
  alias PageDock.Sites.Site

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.dashboard
      flash={@flash}
      current_scope={@current_scope}
      active={:sites}
      title="New site"
    >
      <div class="max-w-[520px]">
        <.link navigate={~p"/sites"} class="text-[13px] text-muted hover:text-text no-underline">
          ← Back to sites
        </.link>
        <h1 class="text-[22px] font-semibold tracking-[-0.02em] text-text mt-2">
          Link a repository
        </h1>
        <p class="mt-1 text-[13.5px] text-muted">
          Choose a GitHub repository to publish as a site.
        </p>

        <%= if @github_account do %>
          <div class="card p-6 md:p-8 mt-5">
            <p :if={@repos_error} class="mb-4 text-[13px] text-error">{@repos_error}</p>

            <.form for={@form} id="site-form" phx-change="validate" phx-submit="save">
              <.input
                field={@form[:repo_id]}
                type="select"
                label="Repository"
                prompt="Choose a repository"
                options={Enum.map(@repos, &{&1.full_name, &1.id})}
              />
              <.input field={@form[:name]} type="text" label="Site name" phx-mounted={JS.focus()} />
              <div>
                <.input field={@form[:slug]} type="text" label="Address" />
                <p class="mt-1 text-[13px] text-faint">
                  {Sites.public_domain(@form[:slug].value || "your-site")}
                </p>
              </div>

              <.button phx-disable-with="Linking..." class="btn-primary w-full mt-6">
                Link repository
              </.button>
            </.form>
          </div>
        <% else %>
          <div class="card p-8 text-center" id="connect-prompt">
            <p class="text-text font-medium">Connect GitHub first</p>
            <p class="mt-1 text-[14px] text-muted">
              Pagedock needs access to your repositories before you can link one.
            </p>
            <.link
              href={~p"/auth/github"}
              class="btn-primary h-9 px-3 no-underline inline-flex mt-4"
            >
              Connect GitHub
            </.link>
          </div>
        <% end %>
      </div>
    </Layouts.dashboard>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    account = Github.get_connected_account(socket.assigns.current_scope)

    socket =
      socket
      |> assign(:page_title, "New site")
      |> assign(:github_account, account)
      |> assign(:repos, [])
      |> assign(:repos_error, nil)
      |> assign_form(Sites.change_site(socket.assigns.current_scope, %Site{}))

    socket =
      if account && connected?(socket) do
        load_repos(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"site" => params}, socket) do
    params = put_repo_fields(params, socket.assigns.repos)

    changeset =
      socket.assigns.current_scope
      |> Sites.change_site(%Site{}, params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"site" => params}, socket) do
    scope = socket.assigns.current_scope
    params = put_repo_fields(params, socket.assigns.repos)

    case Sites.create_site(scope, params) do
      {:ok, site} ->
        {:noreply,
         socket
         |> put_flash(:info, webhook_flash(site, socket.assigns.github_account))
         |> push_navigate(to: ~p"/sites/#{site}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  # Register the push webhook so future pushes deploy. Best-effort: if GitHub
  # rejects it, the site is still created and the user is told to reconnect.
  defp webhook_flash(site, account) do
    case Sites.register_webhook(site, account, webhook_url(site)) do
      {:ok, _site} ->
        "Linked #{site.name}. Pushes to #{site.default_branch} will deploy automatically."

      {:error, _reason} ->
        "Linked #{site.name}, but couldn't set up automatic deploys. " <>
          "Check your GitHub permissions and try reconnecting."
    end
  end

  defp webhook_url(site) do
    case Application.get_env(:page_dock, :sites, [])[:webhook_base_url] do
      nil -> url(~p"/webhooks/github/#{site.id}")
      base -> base <> ~p"/webhooks/github/#{site.id}"
    end
  end

  defp load_repos(socket) do
    case Github.list_repos(socket.assigns.github_account) do
      {:ok, repos} ->
        assign(socket, repos: repos, repos_error: nil)

      {:error, _reason} ->
        assign(socket,
          repos: [],
          repos_error: "Couldn't load your repositories from GitHub. Please try again."
        )
    end
  end

  # Fill owner/name/default_branch from the chosen repo so they're never trusted
  # from the client; if no name was entered yet, default it to the repo name.
  defp put_repo_fields(params, repos) do
    case Enum.find(repos, &(to_string(&1.id) == to_string(params["repo_id"]))) do
      nil ->
        params

      repo ->
        params
        |> Map.merge(%{
          "repo_owner" => repo.owner,
          "repo_name" => repo.name,
          "default_branch" => repo.default_branch
        })
        |> Map.update("name", repo.name, fn
          "" -> repo.name
          name -> name
        end)
    end
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))
end
