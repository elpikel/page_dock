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
              <.theme_toggle />
              <%= if @current_scope do %>
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
