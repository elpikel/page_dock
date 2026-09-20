defmodule PageDockWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use PageDockWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="font-sans text-[15px] leading-[1.6] text-muted bg-bg antialiased min-h-screen">
      <div class="glow">
        <div class="max-w-[1080px] mx-auto px-6">
          <header class="flex items-center justify-between h-16">
            <.link
              navigate={~p"/"}
              class="inline-flex items-center gap-2 text-text font-medium text-[15px] no-underline"
            >
              <svg class="w-5 h-5" viewBox="0 0 20 20" fill="none" aria-hidden="true">
                <rect x="2" y="11" width="16" height="3" rx="1" fill="#0D0E10" />
                <rect x="4.5" y="4" width="11" height="7" rx="1.5" fill="#5E6AD2" />
                <rect x="2" y="15.5" width="16" height="1.5" rx="0.75" fill="#9A9EA5" />
              </svg>
              Pagedock
            </.link>
            <nav class="flex items-center gap-2">
              <%= if @current_scope do %>
                <.link
                  navigate={~p"/sites"}
                  class="hidden sm:inline px-3 py-1.5 rounded-md text-[14px] text-muted hover:text-text hover:bg-black/[0.04] no-underline transition-colors"
                >
                  Sites
                </.link>
                <span class="hidden sm:inline text-[13px] text-muted max-w-[180px] truncate">
                  {@current_scope.user.email}
                </span>
                <.link navigate={~p"/users/settings"} class="btn-secondary h-8 px-3 no-underline">
                  Settings
                </.link>
                <.link
                  href={~p"/users/log-out"}
                  method="delete"
                  class="btn-secondary h-8 px-3 no-underline"
                >
                  Log out
                </.link>
              <% else %>
                <.link navigate={~p"/users/log-in"} class="btn-secondary h-8 px-3 no-underline">
                  Log in
                </.link>
                <.link navigate={~p"/users/register"} class="btn-primary h-8 px-3 no-underline">
                  Sign up
                </.link>
              <% end %>
            </nav>
          </header>

          <main class="py-16 md:py-24">
            <div class="mx-auto max-w-md space-y-4">
              {render_slot(@inner_block)}
            </div>
          </main>
        </div>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders the authenticated app shell: a left sidebar with navigation and a
  scrollable main area with a sticky top bar.

  ## Examples

      <Layouts.dashboard flash={@flash} current_scope={@current_scope} active={:sites} title="Sites">
        <:actions>
          <.link navigate={~p"/sites/new"} class="btn-primary h-7 text-[12.5px]">New site</.link>
        </:actions>
        ...content...
      </Layouts.dashboard>
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :active, :atom, default: nil, doc: "which nav item is active (:sites, :deploys, ...)"
  attr :title, :string, default: nil, doc: "top-bar page title"
  attr :breadcrumb, :string, default: nil, doc: "optional secondary label after the title"
  slot :actions, doc: "top-bar right-aligned actions"
  slot :inner_block, required: true

  def dashboard(assigns) do
    ~H"""
    <div class="font-sans text-[14px] text-text bg-bg antialiased h-screen overflow-hidden">
      <div class="flex h-full">
        <aside class="w-[236px] shrink-0 h-full border-r border-border flex flex-col px-3 pt-3.5 pb-3 bg-[linear-gradient(180deg,#F6F6FB_0%,#FBFBFD_40%,#FFFFFF_100%)]">
          <.link
            navigate={~p"/sites"}
            class="flex items-center gap-2.5 h-[34px] px-2 rounded-lg font-semibold text-[14px] tracking-[-0.01em] text-text no-underline hover:bg-black/[0.04] transition-colors"
          >
            <span class="w-[22px] h-[22px] rounded-md flex items-center justify-center bg-[linear-gradient(135deg,#5B5FE8,#8A63F0)]">
              <svg class="w-3.5 h-3.5" viewBox="0 0 20 20" fill="none" aria-hidden="true">
                <rect x="2" y="11" width="16" height="3" rx="1" fill="#fff" />
                <rect x="4.5" y="4" width="11" height="7" rx="1.5" fill="#fff" fill-opacity=".85" />
                <rect x="2" y="15.5" width="16" height="1.5" rx=".75" fill="#fff" fill-opacity=".6" />
              </svg>
            </span>
            Pagedock
          </.link>

          <div class="flex items-center h-[34px] my-2.5 px-2.5 rounded-lg border border-border bg-white text-muted text-[13px] shadow-[0_1px_2px_rgba(15,18,32,0.04)]">
            <.icon name="hero-magnifying-glass" class="size-3.5 mr-2 text-faint" /> Search
            <span class="kbd ml-auto">⌘K</span>
          </div>

          <nav class="flex flex-col gap-0.5">
            <.link navigate={~p"/sites"} class={["nav-item", @active == :sites && "active"]}>
              <svg viewBox="0 0 16 16" fill="none">
                <rect
                  x="2"
                  y="3"
                  width="12"
                  height="10"
                  rx="2"
                  stroke="currentColor"
                  stroke-width="1.4"
                />
                <path d="M2 6.5h12" stroke="currentColor" stroke-width="1.4" />
              </svg>
              Sites
            </.link>
            <.link navigate={~p"/deploys"} class={["nav-item", @active == :deploys && "active"]}>
              <svg viewBox="0 0 16 16" fill="none">
                <path
                  d="M3 8h10M9 4l4 4-4 4"
                  stroke="currentColor"
                  stroke-width="1.4"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
              Deploys
            </.link>
            <.link navigate={~p"/domains"} class={["nav-item", @active == :domains && "active"]}>
              <svg viewBox="0 0 16 16" fill="none">
                <circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="1.4" />
                <path
                  d="M2 8h12M8 2c2 2 2 10 0 12M8 2c-2 2-2 10 0 12"
                  stroke="currentColor"
                  stroke-width="1.4"
                />
              </svg>
              Domains
            </.link>
          </nav>

          <div class="mt-5">
            <div class="px-2.5 mb-1.5 text-[11px] font-semibold uppercase tracking-[0.04em] text-faint">
              Workspace
            </div>
            <nav class="flex flex-col gap-0.5">
              <.link
                navigate={~p"/users/settings"}
                class={["nav-item", @active == :settings && "active"]}
              >
                <svg viewBox="0 0 16 16" fill="none">
                  <circle cx="8" cy="8" r="2.2" stroke="currentColor" stroke-width="1.4" />
                  <path
                    d="M8 1.8v1.6M8 12.6v1.6M1.8 8h1.6M12.6 8h1.6M3.6 3.6l1.1 1.1M11.3 11.3l1.1 1.1M3.6 12.4l1.1-1.1M11.3 4.7l1.1-1.1"
                    stroke="currentColor"
                    stroke-width="1.4"
                    stroke-linecap="round"
                  />
                </svg>
                Settings
              </.link>
              <.link navigate={~p"/billing"} class={["nav-item", @active == :billing && "active"]}>
                <svg viewBox="0 0 16 16" fill="none">
                  <rect
                    x="2"
                    y="4"
                    width="12"
                    height="9"
                    rx="2"
                    stroke="currentColor"
                    stroke-width="1.4"
                  />
                  <path d="M2 7.5h12" stroke="currentColor" stroke-width="1.4" />
                </svg>
                Billing<span class="ml-auto pill bg-accent-soft text-accent">Beta</span>
              </.link>
            </nav>
          </div>

          <div class="mt-auto">
            <div class="rounded-[10px] p-3.5 mb-3 text-white bg-[linear-gradient(135deg,#5B5FE8_0%,#8A63F0_60%,#B07CF5_100%)]">
              <div class="text-[12px] opacity-85">Beta plan</div>
              <div class="text-[15px] font-semibold mt-0.5 mb-2.5">Free during beta</div>
              <div class="h-[5px] rounded-full bg-white/30 overflow-hidden">
                <i class="block h-full w-3/5 bg-white rounded-full"></i>
              </div>
            </div>
            <div class="flex items-center gap-2.5 h-10 px-1.5 rounded-lg hover:bg-black/[0.04] transition-colors">
              <span class="w-[26px] h-[26px] rounded-full text-white text-[11px] font-semibold flex items-center justify-center shrink-0 bg-[linear-gradient(135deg,#0FA37F,#2C8CE0)]">
                {user_initial(@current_scope)}
              </span>
              <span class="min-w-0 flex-1">
                <span class="block text-[11.5px] text-faint truncate">
                  {user_email(@current_scope)}
                </span>
              </span>
              <.link
                href={~p"/users/log-out"}
                method="delete"
                class="btn-ghost"
                aria-label="Log out"
                title="Log out"
              >
                <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" />
              </.link>
            </div>
          </div>
        </aside>

        <main class="flex-1 min-w-0 h-full overflow-y-auto">
          <header class="sticky top-0 z-10 bg-bg/90 backdrop-blur border-b border-border h-12 px-6 flex items-center gap-3">
            <h1 :if={@title} class="text-[14px] font-medium text-text">{@title}</h1>
            <span :if={@breadcrumb} class="text-faint">/</span>
            <span :if={@breadcrumb} class="text-[13px] text-muted">{@breadcrumb}</span>
            <div :if={@actions != []} class="ml-auto flex items-center gap-2">
              {render_slot(@actions)}
            </div>
          </header>

          <div class="px-6 py-5">
            {render_slot(@inner_block)}
          </div>
        </main>
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  defp user_email(%{user: %{email: email}}), do: email
  defp user_email(_), do: ""

  defp user_initial(%{user: %{email: <<first::utf8, _rest::binary>>}}),
    do: String.upcase(<<first::utf8>>)

  defp user_initial(_), do: "?"

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
