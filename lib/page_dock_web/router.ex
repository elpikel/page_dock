defmodule PageDockWeb.Router do
  use PageDockWeb, :router

  import PageDockWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PageDockWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Inbound GitHub webhooks: no session/CSRF; verified by per-site HMAC.
  scope "/webhooks", PageDockWeb do
    pipe_through :api

    post "/github/:site_id", GithubWebhookController, :create
  end

  scope "/", PageDockWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", PageDockWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:page_dock, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PageDockWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", PageDockWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{PageDockWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

      live "/sites", SiteLive.Index, :index
      live "/sites/new", SiteLive.Form, :new
      live "/sites/:id", SiteLive.Show, :show
    end

    post "/users/update-password", UserSessionController, :update_password

    ## GitHub account linking (OAuth) — requires an authenticated user
    get "/auth/github", GithubAuthController, :authorize
    delete "/auth/github", GithubAuthController, :disconnect
  end

  scope "/", PageDockWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{PageDockWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete

    ## Sign in with GitHub (OAuth) — public; callback is shared with linking
    get "/auth/github/login", GithubAuthController, :login
    get "/auth/github/callback", GithubAuthController, :callback
  end
end
